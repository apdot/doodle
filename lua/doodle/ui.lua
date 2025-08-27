local View = require("doodle.display.view")
local FinderBuffer = require("doodle.display.finderbuffer")
local NoteBuffer = require("doodle.display.notebuffer")
local Present = require("doodle.display.present")
local DoodleNote = require("doodle.note")
local DoodleDirectory = require("doodle.directory")

---@class DoodleFinderItem
---@field id integer
---@field note string
---@field directory string
---@field new_note string
---@field new_directories string[]

---@class DoodleUI
---@field win_id integer
---@field bufnr integer
---@field note_win_id integer
---@field note_bufnr integer
---@field blob DoodleBlob
---@field current_scope integer
---@field root string
---@field branch string
---@field breadcrumbs { [1]: integer, [2]: string }[]
---@field notes { [integer]: DoodleNote }
---@field directories { [integer]: DoodleDirectory }
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
	db = db,
	settings = settings
    }, self)
end

function DoodleUI:save()
    self.db:save(self.notes, self.directories)
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
		    dir = DoodleDirectory.get(line.id, self.db)
		end
		if dir.status == 1 then
		    dir = DoodleDirectory.deep_copy(line.id, curr_parent, self.db)
		end

		dir.name = line.directory
		dir.project = self.root
		dir.branch = self.branch
		dir.parent = curr_parent
		dir.status = 1

		self.directories[dir.id] = dir
		curr_parent = dir.id
	    elseif line.note ~= nil then
		local note = self.notes[line.id]
		if not note then
		    note = DoodleNote.get(line.id, self.db)
		end
		if note.status == 1 then
		    note = DoodleNote.copy(line.id, curr_parent, self.db)
		end

		note.title = line.note
		note.project = self.root
		note.branch = self.branch
		note.parent = curr_parent
		note.status = 1

		self.notes[note.id] = note
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
		self.directories[new_dir.id] = new_dir
	    end

	    curr_parent = new_dir.id
	end
	if line.new_note then
	    local new_note = DoodleNote.create({
		project = self.root,
		branch = self.branch,
		parent = curr_parent,
		title = line.new_note
	    }, self.db)

	    if curr_parent == self.breadcrumbs[#self.breadcrumbs][1] then
		self.notes[new_note.id] = new_note
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
    self.breadcrumbs = {{ dir_id, self.root }}
end

function DoodleUI:render()
    local content
    local bufnr, win_id

    if self.blob then
	content = Present.get_note_content(self.blob.content)
	bufnr, win_id = self.note_bufnr, self.note_win_id
    else
	content = Present.get_finder_content(self.notes, self.directories)
	bufnr, win_id = self.bufnr, self.win_id
    end

    View.render(bufnr, win_id, content, self.current_scope)
end

function DoodleUI:toggle_note()
    if self.note_win_id ~= nil then
	View.close(self.note_bufnr, self.note_win_id)
	self.note_bufnr, self.note_win_id = nil, nil
	return
    end

    self.note_bufnr, self.note_win_id = View.create_window()

    NoteBuffer.setup(self.note_bufnr)

    if not self.note_win_id then
	return
    end

    self:render()
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
