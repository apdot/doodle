local View = require("doodle.display.view")
local FinderBuffer = require("doodle.display.finderbuffer")
local NoteBuffer = require("doodle.display.notebuffer")
local Present = require("doodle.display.present")
local DoodleDirectory = require("doodle.directory")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local DBUtil = require("doodle.utils.db_util")
local Note = require("doodle.note")
local NoteTag = require("doodle.tags.note_tag")

---@class DoodleFinderItem
---@field uuid string
---@field note string
---@field directory string
---@field new_note string
---@field new_directories string[]

---@class DoodleUI
---@field win_id integer
---@field bufnr integer
---@field open_notes table<integer, { win_id: integer, title: string, blob: DoodleBlob }>
---@field current_scope integer
---@field root string
---@field branch string
---@field breadcrumbs { [1]: string, [2]: string }[]
---@field notes { [string]: DoodleNote }
---@field directories { [string]: DoodleDirectory }
---@field db DoodleDB
---@field settings DoodleSettings
local DoodleUI = {}
DoodleUI.__index = DoodleUI

---@param settings DoodleSettings
---@param db DoodleDB
---@return DoodleUI
function DoodleUI:new(settings, db)
    return setmetatable({
        win_id = nil,
        bufnr = nil,
        current_scope = 1,
        root = nil,
        branch = nil,
        breadcrumbs = nil,
        notes = {},
        directories = {},
        open_notes = {},
        db = db,
        settings = settings
    }, self)
end

function DoodleUI:save()
    NoteTag.bulk_map(Present.get_path(self.breadcrumbs),
        DBUtil.get_uuids(vim.tbl_values(self.notes)), self.db)
    DoodleDirectory.save(self.directories, self.db)
    DoodleNote.save(self.notes, self.db)
end

function DoodleUI:mark_deleted()
    for _, note in pairs(self.notes) do
        if note.status ~= 1 then
            note.status = 2
        end
    end
    for _, directory in pairs(self.directories) do
        if directory.status ~= 1 then
            directory.status = 2
        end
    end
end

---@param parsed DoodleFinderItem[]
function DoodleUI:update_finder(parsed)
    for _, line in ipairs(parsed) do
        local curr_parent = self.breadcrumbs[#self.breadcrumbs][1]
        local path = Present.get_path(self.breadcrumbs)
        local path_ids = Present.get_path_ids(self.breadcrumbs)
        if line.uuid ~= nil then
            if line.directory ~= nil then
                local dir = self.directories[line.uuid]
                if not dir then
                    dir = DoodleDirectory.get(line.uuid, self.db)
                end
                if dir.status == 1 then
                    dir = DoodleDirectory.deep_copy(line.uuid, curr_parent, self.db)
                end

                dir.name = line.directory
                dir.project = self.root
                dir.branch = self.branch
                dir.parent = curr_parent
                dir.status = 1
                dir.updated_at = DBUtil.now()

                self.directories[dir.uuid] = dir
                curr_parent = dir.uuid
                table.insert(path, dir.name)
                table.insert(path_ids, dir.uuid)
            elseif line.note ~= nil then
                local note = self.notes[line.uuid]
                if not note then
                    note = DoodleNote.get(line.uuid, self.db)
                end
                if note.status == 1 then
                    note = DoodleNote.copy(line.uuid, curr_parent, self.db)
                end

                note.title = line.note
                note.project = self.root
                note.branch = self.branch
                note.parent = curr_parent
                note.status = 1
                note.path = table.concat(path, "/")
                note.path_ids = table.concat(path_ids, "/")
                note.updated_at = DBUtil.now()

                self.notes[note.uuid] = note
            end
        end

        for _, dir in ipairs(line.new_directories) do
            local new_dir = DoodleDirectory.create({
                project = self.root,
                branch = self.branch,
                parent = curr_parent,
                name = dir
            }, self.db)

            if curr_parent == self.breadcrumbs[#self.breadcrumbs][1] then
                self.directories[new_dir.uuid] = new_dir
            end

            curr_parent = new_dir.uuid
            table.insert(path, new_dir.name)
            table.insert(path_ids, new_dir.uuid)
        end
        if line.new_note then
            local new_note = DoodleNote.create({
                project = self.root,
                branch = self.branch,
                parent = curr_parent,
                path = table.concat(path, "/"),
                path_ids = table.concat(path_ids, "/"),
                title = line.new_note
            }, self.db)

            if curr_parent == self.breadcrumbs[#self.breadcrumbs][1] then
                self.notes[new_note.uuid] = new_note
            end
        end
    end

    self:mark_deleted()
end

function DoodleUI:load_current_directory()
    local notes, directories = self.db:load_finder(self.breadcrumbs[#self.breadcrumbs][1])
    self.notes, self.directories = {}, {}
    for _, note in ipairs(notes) do
        note.status = 1
        self.notes[note.uuid] = note
    end
    for _, directory in ipairs(directories) do
        directory.status = 1
        self.directories[directory.uuid] = directory
    end
end

function DoodleUI:prepare_root()
    self.branch = nil
    if self.current_scope == 1 then
        self.root = self.settings.project()
    elseif self.current_scope == 2 then
        self.root = self.settings.project()
        self.branch = self.settings.branch()
    else
        self.root = self.settings.global()
    end
    local dir_uuid = self.db:create_root_if_not_exists(self.root, self.branch)
    self.breadcrumbs = { { dir_uuid, self.root } }
end

function DoodleUI:render_finder()
    local content = Present.get_finder_content(self.notes, self.directories)
    local bufnr, win_id = self.bufnr, self.win_id

    View.render(bufnr, win_id, content, View.scope_line(self.current_scope),
        Present.get_path(self.breadcrumbs))
end

---@param note_id string
---@param title string
function DoodleUI:open_note(note_id, title)
    print("note id", note_id)
    for bufnr, note_info in pairs(self.open_notes) do
        if note_info.blob.note_id == note_id and vim.api.nvim_win_is_valid(note_info.win_id) then
            print("existing note")
            vim.schedule(function()
                vim.api.nvim_win_set_buf(note_info.win_id, bufnr)
            end)
            return
        end
    end

    local blob = DoodleBlob.get(note_id, self.db)
    local bufnr, win_id = View.create_window()
    self.open_notes[bufnr] = {
        win_id = win_id,
        title = title,
        blob = blob
    }
    local note = Note.get(note_id, self.db)
    local path = vim.split(note.path, "/")
    table.insert(path, title)

    local content = Present.get_note_content(blob.content,
        NoteTag.get_for_note(note_id, self.db))

    View.render(bufnr, win_id, content,
        View.metadata_line(blob, title, path), path)

    NoteBuffer.setup(bufnr, blob, path)

    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })
end

---@param bufnr integer
function DoodleUI:close_note(bufnr)
    local note_info = self.open_notes[bufnr]
    if not note_info then
        return
    end
    print("closing notes")
    View.close(bufnr, self.open_notes[bufnr].win_id)
    self.open_notes[bufnr] = nil
end

function DoodleUI:init()
    if not self.root then
        self:prepare_root()
        self:load_current_directory()
    end
end

function DoodleUI:toggle_finder()
    print("win id in tf", self.win_id)
    if self.win_id ~= nil then
        print("toggle finder closing")
        View.close(self.bufnr, self.win_id)
        self.bufnr, self.win_id = nil, nil
        return
    end
    self.bufnr, self.win_id = View.create_floating_window()

    FinderBuffer.setup(self.bufnr)

    if not self.win_id then
        return
    end

    self:init()
    self:render_finder()
end

function DoodleUI:here()
    self:init()

    local file_path = vim.api.nvim_buf_get_name(0)
    if file_path == "" then
        return
    end

    local line_num = vim.api.nvim_win_get_cursor(0)[1]
    local filename = vim.fn.fnamemodify(file_path, ":t")
    local display_text = string.format("%s:%d", filename, line_num)
    local link_target = string.format("%s:%d", file_path, line_num)
    local link_string = string.format("[%s](%s)", display_text, link_target)

    local note = DoodleNote.create({
        project = self.root,
        path = self.root,
        path_ids = self.breadcrumbs[1][1],
        parent = self.breadcrumbs[1][1],
        title = display_text,
    }, self.db)

    local content = {}
    table.insert(content, "")
    table.insert(content, "# Source " .. link_string)
    local line_content = vim.api.nvim_buf_get_lines(0, line_num - 1, line_num, false)[1] or ""
    local filetype = vim.bo[0].filetype
    if vim.fn.trim(line_content) ~= "" then
        table.insert(content, "")
        table.insert(content, "# Context")
        table.insert(content, "```" .. filetype)
        table.insert(content, line_content)
        table.insert(content, "```")
    end
    table.insert(content, "---")

    DoodleBlob.create({
        note_id = note.uuid,
        content = table.concat(content, "\n")
    }, self.db)

    self:open_note(note.uuid, note.title)
end

return DoodleUI
