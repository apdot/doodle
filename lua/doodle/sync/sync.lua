local Path = require("plenary.path")
local ScanDir = require("plenary.scandir")
local SyncUtil = require("doodle.utils.sync_util")
local FileUtil = require("doodle.utils.file_util")
local GitUtil = require("doodle.utils.git_util")
local DBUtil = require("doodle.utils.db_util")
local SyncConfig = require("doodle.sync.sync_config")
local SyncLog = require("doodle.sync.synclog")
local DoodleOplog = require("doodle.sync.oplog")
local DoodleDirectory = require("doodle.directory")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local Tag = require("doodle.tags.tag")
local NoteTag = require("doodle.tags.note_tag")
local Link = require("doodle.link")

---@class DoodleSync
---@field ensure boolean
---@field settings DoodleSettings
---@field handlers DoodleHandlers
---@field db DoodleDB
---@field config SyncConfig
local DoodleSync = {}
DoodleSync.__index = DoodleSync

local oplog_file = "oplog.json"
local synclog_file = "synclog.json"

function DoodleSync:new(settings, handlers, db)
    return setmetatable({
        ensure = false,
        settings = settings,
        handlers = handlers,
        db = db
    }, self)
end

---@param settings DoodleSettings
---@return boolean
local function ensure_repo(settings)
    local repo = Path:new(settings.git_repo)

    if not repo:exists() or not repo:is_dir() then
        vim.notify("Repository folder not found at " .. settings.git_repo, vim.log.levels.ERROR)
    end

    local git_dir = repo:joinpath(".git")
    if not git_dir:exists() or not git_dir:is_dir() then
        vim.notify("Directory at " .. settings.git_repo .. " is not a Git Repository", vim.log.levels.ERROR)
    end

    local ok = GitUtil.ensure_main(settings.git_repo)
    if not ok then
        local oplog = repo:joinpath(oplog_file)
        if not oplog:exists() then
            oplog:write("[]", "w")
        end
        local synclog = repo:joinpath(synclog_file)
        if not synclog:exists() then
            synclog:write("[]", "w")
        end

        return GitUtil.push({ oplog_file, synclog }, "initial commit", settings.git_repo)
    end

    return true
end

---@param settings DoodleSettings
---@return SyncConfig
local function ensure_config(settings)
    local config_path = Path:new(settings.git_repo .. "/config")

    if config_path:exists() then
        return SyncConfig:new(vim.json.decode(config_path:read()))
    end

    local new_config = SyncConfig:new({
        device_id = SyncUtil.uuid(),
        last_sync = 0,
        bytes = 0
    })

    config_path:write(vim.json.encode(new_config), "w")

    return new_config
end

function DoodleSync:setup()
    if self.ensure then
        return
    end

    self.ensure = ensure_repo(self.settings)
    self.config = ensure_config(self.settings)
end

---@param oplog DoodleOplog
function DoodleSync:apply_operations(oplog)
    self.db:with_transaction(function()
        if #oplog.directory > 0 then
            DoodleDirectory.update(oplog.directory, self.db)
        end
        if #oplog.note > 0 then
            DoodleNote.update(oplog.note, self.db)
        end
        if #oplog.blob > 0 then
            DoodleBlob.update(oplog.blob, self.db)
        end
        if #oplog.tag > 0 then
            Tag.update(oplog.tag, self.db)
        end
        if #oplog.note_tag > 0 then
            NoteTag.update(oplog.note_tag, self.db)
        end
        if #oplog.link > 0 then
            Link.update(oplog.link, self.db)
        end
    end)
end

---@return boolean
function DoodleSync:apply_snapshot()
    local ok, files_in_repo = pcall(function()
        return ScanDir.scan_dir(self.settings.git_repo, { add_dirs = false })
    end)

    if not ok then
        return false
    end

    local snapshot, max_timestamp = FileUtil.find_snapshot(files_in_repo)
    if max_timestamp and max_timestamp > self.config.last_sync then
        local snapshot_path = Path:new(snapshot)
        if snapshot_path then
            local data_str = snapshot_path:read()
            local oplog = DoodleOplog.create(data_str)
            return pcall(self.apply_operations, self, oplog)
        end
    end

    return true
end

---@param settings DoodleSettings
---@param config SyncConfig
local function update_config(settings, config)
    local config_path = Path:new(settings.git_repo .. "/config")
    config_path:write(vim.json.encode(config), "w")
end

---@return boolean
function DoodleSync:apply_oplog()
    local oplogfile = self.settings.git_repo .. "/" .. oplog_file
    local oplog_path = Path:new(oplogfile)
    local ok, data_str = FileUtil.seek(oplog_path, self.config.bytes)

    if not ok then
        return false
    end

    local oplog = DoodleOplog.create(data_str)
    ok = pcall(self.apply_operations, self, oplog)

    if ok then
        self.config.bytes = oplog_path:_stat().size
        update_config(self.settings, self.config)
    end

    return ok
end

---@return boolean
function DoodleSync:pull()
    local ok, err = GitUtil.pull(self.settings.git_repo)
    if not ok then
        vim.notify("Git rebase failed with error: " .. err)
        return false
    end

    if not self:apply_snapshot() then
        vim.notify("Error occurred while applying SNAPSHOT.")
        return false
    end

    if not self:apply_oplog() then
        vim.notify("Error occurred while applying 'oplog.json'.")
        return false
    end

    return true
end

---@return DoodleOplog
---@return table
function DoodleSync:create_snapshot()
    -- clear oplog file
    local oplog_path = Path:new(self.settings.git_repo .. "/" .. oplog_file)
    oplog_path:write("", "w")
    self.config.bytes = 0

    local directories = DoodleDirectory.get_all(self.db)
    local notes = DoodleNote.get_all(self.db)
    local blobs = DoodleBlob.get_all(self.db)
    local tags = Tag.get_all(self.db)
    local note_tags = NoteTag.get_all(self.db)
    local links = Link.get_all(self.db)

    local oplog = DoodleOplog:new()
    oplog.directory = directories
    oplog.note = notes
    oplog.blob = blobs
    oplog.tag = tags
    oplog.note_tag = note_tags
    oplog.link = links

    local new_snapshot_path = Path:new(self.settings.git_repo .. "/SNAPSHOT-" .. DBUtil.now())

    return oplog, new_snapshot_path
end

---@return DoodleOplog
---@return table
function DoodleSync:append_oplog()
    local directories = DoodleDirectory.get_unsynced(self.db)
    local notes = DoodleNote.get_unsynced(self.db)
    local blobs = DoodleBlob.get_unsynced(self.db)
    local tags = Tag.get_unsynced(self.db)
    local note_tags = NoteTag.get_unsynced(self.db)
    local links = Link.get_unsynced(self.db)

    local oplog = DoodleOplog:new()
    oplog.directory = directories
    oplog.note = notes
    oplog.blob = blobs
    oplog.tag = tags
    oplog.note_tag = note_tags
    oplog.link = links

    local oplog_path = Path:new(self.settings.git_repo .. "/" .. oplog_file)
    self.config.bytes = oplog_path:_stat().size

    return oplog, oplog_path
end

---@param settings DoodleSettings
---@param config SyncConfig
local function update_synclog(settings, config)
    config.last_sync = DBUtil.now()

    local synclog_path = Path:new(settings.git_repo .. "/" .. synclog_file)
    local synclog = SyncLog:new(vim.json.decode(synclog_path:read()))
    synclog.data[config.device_id] = config

    synclog_path:write(vim.json.encode(synclog), "w")
end

---@param oplog DoodleOplog
---@param now integer
local function update_synced_at(oplog, now)
    DBUtil.update_synced_at(oplog.directory, now)
    DBUtil.update_synced_at(oplog.note, now)
    DBUtil.update_synced_at(oplog.blob, now)
    DBUtil.update_synced_at(oplog.tag, now)
    DBUtil.update_synced_at(oplog.note_tag, now)
    DBUtil.update_synced_at(oplog.link, now)
end

function DoodleSync:push()
    local files = { oplog_file, synclog_file }
    local now = DBUtil.now()

    local oplog, file_path
    local should_create_snapshot = self.handlers.snapshot_condition(self.config,
        self.settings.git_repo)
    if should_create_snapshot then
        oplog, file_path = self:create_snapshot()
        table.insert(files, file_path.filename)
    else
        oplog, file_path = self:append_oplog()
    end

    update_synced_at(oplog, now)

    file_path:write(vim.json.encode(oplog) .. "\n", "a")
    if not should_create_snapshot then
        self.config.bytes = file_path:_stat().size
    end

    update_synclog(self.settings, self.config)

    local ok = GitUtil.push(files, ("<%s>%s: update directories=%s notes=%s blobs=%s")
        :format(now, self.config.device_id, #oplog.directory, #oplog.note, #oplog.blob),
        self.settings.git_repo)

    if ok then
        update_config(self.settings, self.config)
        DoodleDirectory.mark_synced(oplog.directory, now, self.db)
        DoodleNote.mark_synced(oplog.note, now, self.db)
        DoodleBlob.mark_synced(oplog.blob, now, self.db)
        Tag.mark_synced(oplog.tag, now, self.db)
        NoteTag.mark_synced(oplog.note_tag, now, self.db)
        Link.mark_synced(oplog.link, now, self.db)
        vim.notify("Git Push completed successfully.")
    end
end

function DoodleSync:sync()
    local ok = self:pull()
    if ok then
        self:push()
    end
end

return DoodleSync
