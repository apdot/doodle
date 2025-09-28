local View = require("doodle.display.view")
local FinderBuffer = require("doodle.display.finderbuffer")
local NoteBuffer = require("doodle.display.notebuffer")
local LinkBuffer = require("doodle.display.linkbuffer")
local Present = require("doodle.display.present")
local DoodleDirectory = require("doodle.directory")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local DBUtil = require("doodle.utils.db_util")
local FormatUtil = require("doodle.utils.format_util")
local Note = require("doodle.note")
local NoteTag = require("doodle.tags.note_tag")
local Graph = require("doodle.graph")

---@class DoodleFinderItem
---@field id string
---@field note string
---@field directory string
---@field new_note string
---@field new_directories string[]

---@class DoodleUI
---@field win_id integer
---@field bufnr integer
---@field link_win_id { left: integer, right: integer }
---@field link_bufnr {left: integer, right: integer }
---@field link_idx integer
---@field graph table
---@field open_notes table<integer, { win_id: integer, title: string, id: string, blob: DoodleBlob }>
---@field current_scope integer
---@field uuid_to_idx table<string, integer>
---@field idx_to_uuid table<integer, string>
---@field root string
---@field branch string
---@field breadcrumbs { [1]: string, [2]: string }[]
---@field notes { [string]: DoodleNote }
---@field display_notes DoodleNote[]
---@field directories { [string]: DoodleDirectory }
---@field display_directories DoodleDirectory[]
---@field db DoodleDB
---@field settings DoodleSettings
local DoodleUI = {}
DoodleUI.__index = DoodleUI

local idx = 1

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
        uuid_to_idx = {},
        idx_to_uuid = {},
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

function DoodleUI:map_idx(uuid)
    if self.uuid_to_idx[uuid] == nil then
        self.uuid_to_idx[uuid] = idx
        self.idx_to_uuid[idx] = uuid
        idx = idx + 1
    end
end

function DoodleUI:mark_all_processed()
    for _, dir in pairs(self.directories) do
        if dir.status == 0 then
            dir.status = 1
        end
    end
    for _, note in pairs(self.notes) do
        if note.status == 0 then
            note.status = 1
        end
    end
end

---@param parsed DoodleFinderItem[]
function DoodleUI:update_finder(parsed)
    for _, line in ipairs(parsed) do
        local curr_parent = self.breadcrumbs[#self.breadcrumbs][1]
        local path = Present.get_path(self.breadcrumbs)
        local path_ids = Present.get_path_ids(self.breadcrumbs)
        if line.id ~= nil then
            local uuid = self.idx_to_uuid[tonumber(line.id)]
            print("line id in update", line.id)
            print("uuid in update", uuid)
            if line.directory ~= nil then
                local dir = self.directories[uuid]
                if not dir then
                    dir = DoodleDirectory.get(uuid, self.db)
                    self.uuid_to_idx[uuid] = nil
                end
                if dir.status == 1 then
                    dir = DoodleDirectory.deep_copy(uuid, curr_parent, self.db)
                    dir.name = line.directory
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
                local note = self.notes[uuid]
                if not note then
                    note = DoodleNote.get(uuid, self.db)
                    self.uuid_to_idx[uuid] = nil
                end
                if note.status == 1 then
                    note = DoodleNote.copy(uuid, curr_parent, self.db)
                    print("note copy created ", uuid, note.uuid)
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

    for uuid, dir in pairs(self.directories) do
        if self.uuid_to_idx[uuid] == nil then
            self:map_idx(uuid)
            table.insert(self.display_directories, dir)
        end
    end
    for uuid, note in pairs(self.notes) do
        print("uuid in update ", uuid, self.uuid_to_idx[uuid])
        if self.uuid_to_idx[uuid] == nil then
            print("uuid in update nil ", uuid)
            self:map_idx(uuid)
            table.insert(self.display_notes, note)
        end
    end

    self.display_directories = FormatUtil.sort_note_or_directories(self.display_directories)
    self.display_notes = FormatUtil.sort_note_or_directories(self.display_notes)
end

function DoodleUI:load_current_directory()
    self.display_notes, self.display_directories =
        self.db:load_finder(self.breadcrumbs[#self.breadcrumbs][1])
    self.notes, self.directories = {}, {}
    for _, note in ipairs(self.display_notes) do
        note.status = 1
        self.notes[note.uuid] = note
        self:map_idx(note.uuid)
    end
    for _, directory in ipairs(self.display_directories) do
        directory.status = 1
        self.directories[directory.uuid] = directory
        self:map_idx(directory.uuid)
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

function DoodleUI:init()
    self:prepare_root()
    self:load_current_directory()
end

function DoodleUI:render_note(note, blob, bufnr, win_id)
    local path = vim.split(note.path, "/")
    table.insert(path, note.title)

    local content = Present.get_note_content(blob.content,
        NoteTag.get_for_note(note.uuid, self.db))

    View.render(bufnr, win_id, content,
        View.metadata_line(blob, note.title, path, Note.get_links_count(note.uuid, self.db)), path)

    NoteBuffer.setup(bufnr, blob, path)

    vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

    View.place_cursor(bufnr, win_id, 4)
end

---@param note_id string
function DoodleUI:open_note(note_id)
    if self.open_notes then
        print("in open notes")
        for bufnr, note_info in pairs(self.open_notes) do
            print("loop", bufnr, note_info.blob.note_id)
            if note_info.blob.note_id == note_id and vim.api.nvim_win_is_valid(note_info.win_id) then
                print("existing note")
                vim.schedule(function()
                    vim.api.nvim_win_set_buf(note_info.win_id, bufnr)
                end)
                return
            end
        end
    end

    local blob = DoodleBlob.get(note_id, self.db)
    local bufnr, win_id = View.create_window()
    local note = Note.get(note_id, self.db)

    self.open_notes[bufnr] = {
        win_id = win_id,
        title = note.title,
        id = note.uuid,
        blob = blob
    }

    self:render_note(note, blob, bufnr, win_id)
end

---@param bufnr integer
function DoodleUI:close_note(bufnr)
    local note_info = self.open_notes[bufnr]
    if not note_info then
        return
    end
    print("closing notes")
    self.open_notes[bufnr] = nil
end

function DoodleUI:render_finder()
    local content = Present.get_finder_content(self.display_notes,
        self.display_directories, self.uuid_to_idx)
    local bufnr, win_id = self.bufnr, self.win_id

    View.render(bufnr, win_id, content, View.scope_line(self.current_scope),
        Present.get_path(self.breadcrumbs))

    FinderBuffer.setup(self.bufnr)

    View.place_cursor(self.bufnr, self.win_id, 3)
end

function DoodleUI:toggle_finder()
    print("win id in tf", self.win_id)
    if self.win_id ~= nil then
        print("toggle finder closing")
        View.close(self.bufnr, self.win_id)
        self.bufnr, self.win_id = nil, nil
        return
    end

    local bufnr, win_id = View.create_finder_window(0.4, 0.5)

    if not win_id then
        return
    end

    self.bufnr = bufnr
    self.win_id = win_id

    if not self.root then
        self:init()
    end

    self:render_finder()
end

function DoodleUI:render_links_refresh()
    print("link_id", self.link_idx)
    local selected_note = self.graph.notes[self.link_idx]
    local current_win = vim.api.nvim_get_current_win()

    print("current_win", current_win)
    print("right win", self.link_win_id.right)
    print("left win", self.link_win_id.left)
    vim.api.nvim_win_set_buf(self.link_win_id.right, self.link_bufnr.right)
    -- if  current_win ~= self.link_bufnr.right then
    --     vim.api.nvim_win_set_buf(current_win, self.link_bufnr.right)
    --     self.link_win_id.right = current_win
    -- end
    View.render(self.link_bufnr.right, self.link_win_id.right,
        Present.get_links(self.graph.adjacency[selected_note.uuid]),
        View.links_right_header(selected_note.title), { "Links" })
end

---@param bufnr integer
function DoodleUI:render_links(bufnr)
    -- local content = Present.get_links_content(self.notes, self.directories)
    -- local bufnr, win_id = self.bufnr, self.win_id

    if not self.graph then
        self.graph = Graph.build(self.db)

        if self.open_notes then
            print("link open note, bufnr", bufnr)
            local open_note = self.open_notes[bufnr]
            print("link open", open_note)
            if open_note then
                print("idx", self.graph.note_idx[open_note.id])
                self.link_idx = self.graph.note_idx[open_note.id]
            end
        end

        if not self.link_idx then
            self.link_idx = 1
        end
    end

    -- for k, v in pairs(graph.adjacency) do
    --     print("note id", k)
    --     for _, note_data in pairs(v.outgoing) do
    --         print("outgoing ", note_data.note.title, note_data.link.link_str)
    --     end
    --     for _, note_data in pairs(v.incoming) do
    --         print("incoming ", note_data.note.title, note_data.link.link_str)
    --     end
    -- end

    View.render(self.link_bufnr.left, self.link_win_id.left,
        Present.get_labels(self.graph.labels), View.links_left_header(),
        { "Links" })

    self:render_links_refresh()

    LinkBuffer.setup_left(self.link_bufnr.left)
    LinkBuffer.setup_right(self.link_bufnr.right)

    View.place_cursor(self.link_bufnr.left, self.link_win_id.left, self.link_idx + 2)

    -- FinderBuffer.setup(self.bufnr)
end

function DoodleUI:toggle_links()
    local current_bufnr = vim.api.nvim_get_current_buf()
    self.link_bufnr, self.link_win_id = View.create_links_window()

    if not self.link_win_id then
        return
    end

    if not self.root then
        self:init()
    end

    self:render_links(current_bufnr)
end

function DoodleUI:here()
    if not self.root then
        self:init()
    end

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

    self:open_note(note.uuid)
end

---@param opts table
function DoodleUI:create_template(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local note_title = "Untitled"
    if opts.args and vim.fn.trim(opts.args) ~= "" then
        note_title = opts.args
    end
    local template_note = DoodleNote.create({
        title = note_title,
        path = "template",
        template = 1
    }, self.db)
    DoodleBlob.create({
        note_id = template_note.uuid,
        content = FormatUtil.get_content(bufnr)
    }, self.db)
end

return DoodleUI
