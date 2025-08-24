local View = require("doodle.display.view")
local FinderBuffer = require("doodle.display.finderbuffer")
local Present = require("doodle.display.present")
local DoodleBuffer = require("doodle.buffer")

local ns = vim.api.nvim_create_namespace("doodle_ns")

---@class DoodleFinderItem
---@field id integer
---@field note string
---@field directory string
---@field new_note string
---@field new_directories string[]

---@class DoodleUI
---@field win_id integer
---@field bufnr integer
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
	db = db,
	settings = settings
    }, self)
end

function DoodleUI:get_ui_content()
    return DoodleBuffer:get_contents(self.bufnr, ns)
end

function DoodleUI:get_current_note()
    if self.current_scope == 1 then
	return self.active_note
    elseif self.current_scope == 2 then
	return self.branch_note
    else
	return self.global_note
    end
end

-- function DoodleUI:save()
--     local p, b, g, unmarked = self:get_ui_content()
--
--     local current_note = self:get_current_note()
--     current_note:update(unmarked)
--
--     self.active_note:append(p)
--     self.global_note:append(g)
--     if self.branch_note then
-- 	self.branch_note:append(b)
--     end
-- end

function DoodleUI:toggle_view(note)
    if note == nil or self.win_id ~= nil then
	self:close()
	return
    end

    local win_id, bufnr = self:create_window()

    self.win_id = win_id
    self.bufnr = bufnr
    self.active_note = note
    self.global_note = note.global_noteui
    self.branch_note = note.branch_note

    self:render()
end

local function mark_scope(bufnr, current_scope, scope_idx, start_row, end_row)
    if scope_idx ~= current_scope then
	local mark = scope_marks[scope_idx]
	for i=start_row, end_row do
	    vim.api.nvim_buf_set_extmark(bufnr, ns, i-1, 0, {
		sign_text = mark,
		sign_hl_group = scope_idx == 1 and "Keyword" or scope_idx == 2 and "Identifier" or "Type",
		right_gravity = false,
		end_right_gravity = true,
	    })
	end
    end
end

local function get_start_and_end_row()
    local mode = vim.api.nvim_get_mode()["mode"]
    local start_row
    local end_row

    if mode == "V" then
	start_row = vim.fn.getpos("v")[2]
	end_row = vim.fn.getpos(".")[2]
    else
	start_row = vim.api.nvim_win_get_cursor(0)[1]
	end_row = start_row
    end

    return start_row, end_row
end

function DoodleUI:pin_project()
    if self.active_note == nil or self.win_id == nil or self.bufnr == nil then
	return
    end

    local start_row, end_row = get_start_and_end_row()
    mark_scope(self.bufnr, self.current_scope, 1, start_row, end_row)
end

function DoodleUI:pin_branch()
    if self.active_note == nil or self.win_id == nil or self.bufnr == nil then
	return
    end

    local start_row, end_row = get_start_and_end_row()
    mark_scope(self.bufnr, self.current_scope, 2, start_row, end_row)
end

function DoodleUI:pin_global()
    if self.active_note == nil or self.win_id == nil or self.bufnr == nil then
	return
    end

    local start_row, end_row = get_start_and_end_row()
    mark_scope(self.bufnr, self.current_scope, 3, start_row, end_row)
end

function DoodleUI:save()
    local parent = self.breadcrumbs[#self.breadcrumbs][1]
    print("parent in save", parent)
    self.db:save(self.root, self.branch, parent, self.notes, self.directories)
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
	if line.id ~= nil then
	    if line.directory ~= nil then
		local dir = self.directories[line.id]
		if not dir then
		    -- move operation
		    dir = { id = line.id }
		    self.directories[line.id] = dir
		elseif dir.status == 1 then
		    -- copy operation
		    print("deep copy", line.id, line.directory)
		    local copy_id = self.db:deep_copy_directory(line.id, self.root, self.branch, curr_parent)
		    dir = { id = copy_id }
		    self.directories[copy_id] = dir
		end
		dir.name = line.directory
		dir.parent = curr_parent
		dir.status = 1
		curr_parent = dir.id
	    elseif line.note ~= nil then
		local note = self.notes[line.id]
		if not note then
		    -- move operation
		    note = { id = line.id }
		    self.notes[line.id] = note
		elseif note.status == 1 then
		    -- copy operation
		    local copy_id = self.db:copy_note(line.id, self.root, self.branch, curr_parent)
		    note = { id = copy_id }
		    self.notes[copy_id] = note
		end
		note.title = line.note
		note.parent = curr_parent
		note.status = 1
	    end
	end

	for _, dir in ipairs(line.new_directories) do
	    local new_dir = self.db:create_directory(self.root, self.branch, curr_parent, dir)
	    if curr_parent == self.breadcrumbs[#self.breadcrumbs][1] then
		self.directories[new_dir] = { id = new_dir, name = dir, status = 1 }
	    end
	    curr_parent = new_dir
	end
	if line.new_note then
	    local new_note = self.db:create_note(self.root, self.branch, curr_parent, line.new_note)
	    if curr_parent == self.breadcrumbs[#self.breadcrumbs][1] then
		self.notes[new_note] = { id = new_note, title = line.new_note, status = 1 }
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
	self.notes[note.id] = note
    end
    for _, directory in ipairs(directories) do
	directory.status = 1
	self.directories[directory.id] = directory
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
    local dir_id = self.db:create_root_if_not_exists(self.root, self.branch)
    self.breadcrumbs = { { dir_id, self.root } }
end

function DoodleUI:render()
    local content = Present.get_finder_content(self.notes, self.directories)
    View.render(self.bufnr, self.win_id, content, self.current_scope)
end

function DoodleUI:toggle_finder()
    if self.win_id ~= nil then
	View.close(self.bufnr, self.win_id)
	self.bufnr, self.win_id = nil, nil
	return
    end

    self.bufnr, self.win_id = View.create_window()

    FinderBuffer.setup(self.bufnr)

    if not self.win_id then
	return
    end

    if not self.root then
	self:prepare_root()
	self:load_current_directory()
    end
    self:render()
end

return DoodleUI
