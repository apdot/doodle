local sqlite = require("sqlite")
local FileUtil = require("doodle.utils.file_util")
local DBUtil = require("doodle.utils.db_util")
local SyncUtil = require("doodle.utils.sync_util")
local DoodleNote = require("doodle.note")
local DoodleDirectory = require("doodle.directory")

---@class DoodleDB
---@field config DoodleConfig
---@field _conn table
local DoodleDB = {}
DoodleDB.__index = DoodleDB

local function _db_path()
    FileUtil.create_data_path_if_not_exists()
    return FileUtil.data_path .. ("/doodle.sqlite3")
end

local function connect()
    return sqlite:open(_db_path())
end

function DoodleDB:new(config)
    local ok, _conn = pcall(connect)

    if not ok then
        error([[
	    Error occurred while establishing connection to sqlite.
	    Ensure dependency is added and sqlite is installed on your system.
	]])
    end

    return setmetatable({
        config = config,
        _conn = _conn
    }, self)
end

function DoodleDB:ensure_schema()
    self._conn:create("note", {
        id         = { "integer", "primary", "key" },
        uuid       = { "text", "unique" },
        project    = { "text" },
        branch     = { "text" },
        parent     = { "string", reference = "directory.uuid", on_delete = "cascade" },
        title      = { "text" },
        created_at = { "integer" },
        updated_at = { "integer" },
        synced_at  = { "integer" },
        status     = { "integer", default = 1 },
        ensure     = true
    })

    self._conn:create("directory", {
        id         = { "integer", "primary", "key" },
        uuid       = { "text", "unique" },
        project    = { "text" },
        branch     = { "text" },
        parent     = { "text", reference = "directory.uuid", on_delete = "cascade" },
        name       = { "text" },
        created_at = { "integer" },
        updated_at = { "integer" },
        synced_at  = { "integer" },
        status     = { "integer", default = 1 },
        ensure     = true
    })

    self._conn:create("blob", {
        id         = { "integer", "primary", "key" },
        uuid       = { "text", "unique" },
        note_id    = { "text", reference = "note.uuid", on_delete = "cascade" },
        content    = { "text" },
        created_at = { "integer" },
        updated_at = { "integer" },
        synced_at  = { "integer" },
        ensure     = true
    })
end

function DoodleDB:setup()
    self:ensure_schema()
end

---@param parent string
---@return DoodleNote[]
---@return DoodleDirectory[]
function DoodleDB:load_finder(parent)
    -- print("load_finder", parent)
    local notes = self._conn:select("note", {
        where = {
            parent = parent,
            status = "<" .. 2
        },
        order_by = { asc = { "title", "created_at" } }
    })

    for k, note in pairs(notes) do
        -- print(note.uuid, note.project, note.branch, note.title, note.created_at, note.updated_at)
    end

    local directories = self._conn:select("directory", {
        where = {
            parent = parent,
            status = "<" .. 2
        },
        order_by = { asc = { "name", "created_at" } }
    })

    for k, dir in pairs(directories) do
        -- print(dir.uuid, dir.project, dir.branch, dir.name, dir.created_at, dir.updated_at)
    end

    return DoodleNote.from_list(notes) or {}, DoodleDirectory.from_list(directories) or {}
end

---@param blob DoodleBlob
---@return string
function DoodleDB:create_blob(blob)
    local dict = DBUtil.dict({
        note_id = blob.note_id,
        content = blob.content,
        uuid = blob.uuid and blob.uuid or SyncUtil.uuid(),
        created_at = DBUtil.now(),
        updated_at = DBUtil.now()
    })

    self._conn:insert("blob", dict)

    return dict.uuid
end

---@param table_name string
---@return table
function DoodleDB:get_all(table_name)
    local res = self._conn:select(table_name)

    if not res or #res == 0 then
        return {}
    end

    return res
end

---@param note_id string
---@return table
function DoodleDB:get_blob(note_id)
    local blob = self._conn:select("blob", {
        where = { note_id = note_id }
    })

    if not blob or #blob == 0 then
        return {}
    end

    return blob[1]
end

---@return table
function DoodleDB:get_unsynced_blob()
    local blob = self._conn:eval([[
	SELECT * FROM blob
	WHERE synced_at IS null OR updated_at > synced_at
	ORDER BY created_at ASC
    ]])

    if not blob or #blob == 0 then
        return {}
    end

    return blob
end

---@param blob DoodleBlob
function DoodleDB:update_blob(blob)
    self._conn:update("blob", {
        where = DBUtil.dict({
            uuid = blob.uuid
        }),
        set = DBUtil.dict({
            content = blob.content,
            updated_at = DBUtil.now()
        })
    })
end

---@param note DoodleNote
---@return string
function DoodleDB:create_note(note)
    local dict = DBUtil.dict({
        project = note.project,
        branch = note.branch,
        title = note.title,
        parent = note.parent,
        uuid = note.uuid and note.uuid or SyncUtil.uuid(),
        created_at = DBUtil.now(),
        updated_at = DBUtil.now()
    })

    self._conn:insert("note", dict)

    return dict.uuid
end

---@param uuid string
---@return table
function DoodleDB:get_note(uuid)
    local note = self._conn:select("note", {
        where = { uuid = uuid }
    })

    if not note or #note == 0 then
        return {}
    end

    return note[1]
end

---@param note DoodleNote
function DoodleDB:update_note(note)
    self._conn:update("note", {
        where = { uuid = note.uuid },
        set = DBUtil.dict({
            project = note.project,
            branch = note.branch,
            parent = note.parent,
            title = note.title,
            status = note.status,
            updated_at = DBUtil.now()
        })
    })
end

---@param uuid string
function DoodleDB:delete_note(uuid)
    self._conn:update("note", {
        where = { uuid = uuid },
        set = {
            status = 2,
            updated_at = DBUtil.now()
        }
    })
end

---@param uuid string
---@param parent string
---@return string
function DoodleDB:copy_note(uuid, parent)
    ---@type DoodleNote
    local notes = self._conn:select("note", {
        where = { uuid = uuid }
    })

    if not notes or #notes == 0 then
        return uuid
    end

    local note = notes[1]
    note.parent = parent
    note.uuid = nil
    local copy_id = self:create_note(note)

    ---@type DoodleBlob
    local blob = self._conn:select("blob", {
        where = { note_id = uuid }
    })

    if not blob or #blob == 0 then
        return copy_id
    end

    blob = blob[1]
    blob.note_id = copy_id
    blob.uuid = nil
    self:create_blob(blob)

    return copy_id
end

---@param directory DoodleDirectory
---@return string
function DoodleDB:create_directory(directory)
    local dict = DBUtil.dict({
        project = directory.project,
        branch = directory.branch,
        parent = directory.parent,
        name = directory.name,
        uuid = directory.uuid and directory.uuid or SyncUtil.uuid(),
        created_at = DBUtil.now(),
        updated_at = DBUtil.now()
    })

    self._conn:insert("directory", dict)

    return dict.uuid
end

---@param uuid string
---@return table
function DoodleDB:get_directory(uuid)
    local directory = self._conn:select("directory", {
        where = { uuid = uuid }
    })

    if not directory or #directory == 0 then
        return {}
    end

    return directory[1]
end

---@param table_name string
---@return table
function DoodleDB:get_unsynced(table_name)
    local directory = self._conn:eval(([[
	SELECT * FROM %s
	WHERE synced_at IS null OR updated_at > synced_at
	ORDER BY created_at ASC
    ]]):format(table_name))

    if not directory or type(directory) == "boolean" then
        return {}
    end

    return directory
end

---@param directory DoodleDirectory
function DoodleDB:update_directory(directory)
    local query = [[
	UPDATE directory
	SET
	    project = :project,
	    branch = :branch,
	    parent = :parent,
	    name = :name,
	    status = :status,
	    updated_at = :updated_at
	WHERE
	    uuid = :uuid
	    AND (
		project IS DISTINCT FROM :project OR
		branch IS DISTINCT FROM :branch OR
		parent IS DISTINCT FROM :parent OR
		name IS DISTINCT FROM :name OR
		status IS DISTINCT FROM :status
	    )
    ]]

    local params = {
        uuid = directory.uuid,
        project = directory.project,
        branch = directory.branch,
        parent = directory.parent,
        name = directory.name,
        status = directory.status,
        updated_at = DBUtil.now()
    }

    local ok = self._conn:eval(query, params)
end

---@param uuid string
function DoodleDB:delete_directory(uuid)
    self._conn:update("directory", {
        where = { uuid = uuid },
        set = { status = 2 }
    })
end

---@param uuid string
---@param parent string
---@return string
function DoodleDB:deep_copy_directory(uuid, parent)
    local dir = self._conn:select("directory", {
        where = { uuid = uuid }
    })

    if not dir or #dir == 0 then
        return uuid
    end

    dir = dir[1]
    dir.parent = parent
    dir.uuid = nil
    local copy_id = self:create_directory(dir)

    local sub_notes = self._conn:select("note", {
        where = { parent = uuid }
    })
    for _, note in ipairs(sub_notes) do
        self:copy_note(note.uuid, copy_id)
    end

    local sub_directories = self._conn:select("directory", {
        where = { parent = uuid }
    })
    for _, sub_directory in ipairs(sub_directories) do
        self:deep_copy_directory(sub_directory.uuid, copy_id)
    end

    return copy_id
end

---@param table_name string
---@param uuids string[]
---@param now integer
function DoodleDB:mark_synced(table_name, uuids, now)
    local query = ([[
	UPDATE %s SET synced_at = %s
	WHERE uuid in (%s)
    ]]):format(table_name, now, table.concat(uuids, ","))

    -- print("query", query)
    self._conn:eval(query)
end

---@param table_name string
---@param columns string[]
---@param values string
---@param where string
function DoodleDB:bulk_upsert(table_name, columns, values, where)
    local query_parts = {}

    table.insert(query_parts, ("INSERT INTO %s (%s)"):format(table_name, table.concat(columns, ",")))
    table.insert(query_parts, ("VALUES %s"):format(values))
    table.insert(query_parts, "ON CONFLICT(uuid) DO UPDATE SET")
    table.insert(query_parts, DBUtil.create_on_conflict(columns))
    table.insert(query_parts, ("WHERE %s"):format(where))

    local query = table.concat(query_parts, "\n")
    -- print(query)
    local ok, err = self._conn:eval(query)
end

---@param root string
---@param branch string
---@return string
function DoodleDB:create_root_if_not_exists(root, branch)
    local dir = self._conn:select("directory", {
        where = DBUtil.where({
            project = root,
            branch = branch and branch or vim.NIL,
            parent = vim.NIL
        })
    })

    if not dir or #dir == 0 then
        local root_dir = DoodleDirectory.create({
            project = root,
            branch = branch,
            parent = vim.NIL,
            name = root,
            uuid = SyncUtil.hash(root .. (branch or ""))
        }, self)

        DoodleNote.create({
            project = root,
            branch = branch,
            parent = root_dir.uuid,
            title = "Quick Note",
            uuid = SyncUtil.hash(root_dir.uuid .. "Quick Note")
        }, self)

        return root_dir.uuid
    end

    return dir[1].uuid
end

function DoodleDB:garbage_collect()
    self._conn:delete("directory", {
        where = { status = 2 }
    })
    self._conn:delete("note", {
        where = { status = 2 }
    })
end

---@param func function
function DoodleDB:with_transaction(func)
    self._conn:eval("BEGIN TRANSACTION")
    local ok, err = pcall(func)

    if ok then
        self._conn:eval("COMMIT")
    else
        self._conn:eval("ROLLBACK")
        error(err)
    end
end

return DoodleDB
