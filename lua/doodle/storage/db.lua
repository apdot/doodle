local sqlite = require("sqlite")
local FileUtil = require("doodle.utils.fileutil")
local DBUtil = require("doodle.utils.dbutil")
local DoodleNote = require("doodle.note")
local DoodleDirectory = require("doodle.directory")

---@class DoodleDB
---@field config DoodleConfig
---@field _conn table
local DoodleDB = {}
DoodleDB.__index = DoodleDB

local function now() return os.time() end

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
	id 		= 	{ "integer", "primary", "key" },
	project 	= 	{ "text" },
	branch 		= 	{ "text" },
	parent	 	= 	{ "integer", reference = "directory.id", on_delete = "cascade" },
	title 		= 	{ "text" },
	created_at	= 	{ "integer" },
	updated_at 	= 	{ "integer" },
	status 		= 	{ "integer", default = 1 },
	ensure		= 	true
    })

    self._conn:create("directory", {
	id 		= 	{ "integer", "primary", "key" },
	project 	= 	{ "text" },
	branch 		= 	{ "text" },
	parent	 	= 	{ "integer", reference = "directory.id", on_delete = "cascade" },
	name 		= 	{ "text" },
	created_at 	= 	{ "integer" },
	updated_at 	= 	{ "integer" },
	status 		= 	{ "integer", default = 1 },
	ensure		= 	true
    })

    self._conn:create("blob", {
	id 		= 	{ "integer", "primary", "key" },
	note_id	 	= 	{ "integer", reference = "note.id", on_delete = "cascade" },
	content 	= 	{ "text" },
	created_at 	= 	{ "integer" },
	updated_at 	= 	{ "integer" },
	ensure		= 	true
    })
end

function DoodleDB:setup()
    self:ensure_schema()
end

---@param parent integer 
---@return DoodleNote[]
---@return DoodleDirectory[]
function DoodleDB:load_finder(parent)
    print("load_finder", parent)
    local notes = self._conn:select("note", {
	where = {
	    parent = parent,
	    status = "<" .. 2
	},
	order_by = { asc = { "title" , "created_at" } }
    })

    for k, note in pairs(notes) do
	print(note.id, note.project, note.branch, note.title, note.created_at, note.updated_at)
    end

    local directories = self._conn:select("directory", {
	where = {
	    parent = parent,
	    status = "<" .. 2
	},
	order_by = { asc = { "name" , "created_at" } }
    })

    for k, dir in pairs(directories) do
	print(dir.id, dir.project, dir.branch, dir.name, dir.created_at, dir.updated_at)
    end

    return DoodleNote.from_list(notes) or {}, DoodleDirectory.from_list(directories) or {}
end

---@param blob DoodleBlob
---@return integer
function DoodleDB:create_blob(blob)
    local ok, id = self._conn:insert("blob", {
	note_id = blob.note_id,
	content = blob.content,
	created_at = now(),
	updated_at = now()
    })
    return id
end

---@param note_id integer
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

---@param blob DoodleBlob
function DoodleDB:update_blob(blob)
    self._conn:update("blob", {
	where = DBUtil.dict({
	    id = blob.id
	}),
	set = DBUtil.dict({
	    content = blob.content,
	    updated_at = now()
	})
    })
end

---@param note DoodleNote
---@return integer
function DoodleDB:create_note(note)
    local ok, id = self._conn:insert("note", DBUtil.dict({
	project = note.project,
	branch = note.branch,
	title = note.title,
	parent = note.parent,
	created_at = now(),
	updated_at = now()
    }))
    return id
end

---@param id integer
---@return table
function DoodleDB:get_note(id)
    local note = self._conn:select("note", {
	where = { id = id }
    })

    if not note or #note == 0 then
	return {}
    end

    return note[1]
end

---@param note DoodleNote
function DoodleDB:update_note(note)
    self._conn:update("note", {
	where = { id = note.id },
	set = DBUtil.dict({
	    project = note.project,
	    branch = note.branch,
	    parent = note.parent,
	    title = note.title,
	    status = note.status,
	    updated_at = now()
	})
    })
end


---@param id integer
function DoodleDB:delete_note(id)
    self._conn:update("note", {
	where = { id = id },
	set = {
	    status = 2,
	    updated_at = now()
	}
    })
end

---@param id integer
---@param parent integer
---@return integer
function DoodleDB:copy_note(id, parent)
    ---@type DoodleNote
    local notes = self._conn:select("note", {
	where = { id = id }
    })

    if not notes or #notes == 0 then
	return id
    end

    local note = notes[1]
    note.parent = parent
    local copy_id = self:create_note(note)

    ---@type DoodleBlob
    local blob = self._conn:select("blob", {
	where = { note_id = id }
    })

    if not blob or #blob == 0 then
	return copy_id
    end

    blob = blob[1]
    blob.note_id = copy_id
    self:create_blob(blob)

    return copy_id
end

---@param directory DoodleDirectory
---@return integer
function DoodleDB:create_directory(directory)
    local ok, id = self._conn:insert("directory", DBUtil.dict({
	project = directory.project,
	branch = directory.branch,
	parent = directory.parent,
	name = directory.name,
	created_at = now(),
	updated_at = now()
    }))
    return id
end

---@param id integer
---@return table
function DoodleDB:get_directory(id)
    local directory = self._conn:select("directory", {
	where = { id = id }
    })

    if not directory or #directory == 0 then
	return {}
    end

    return directory[1]
end

---@param directory DoodleDirectory
function DoodleDB:update_directory(directory)
    self._conn:update("directory", {
	where = { id = directory.id },
	set = DBUtil.dict({
	    project = directory.project,
	    branch = directory.branch,
	    parent = directory.parent,
	    name = directory.name,
	    status = directory.status,
	    updated_at = now()
	})
    })
end

---@param id integer
function DoodleDB:delete_directory(id)
    self._conn:update("directory", {
	where = { id = id },
	set = { status = 2 }
    })
end

---@param id integer
---@param parent integer
---@return integer
function DoodleDB:deep_copy_directory(id, parent)
    local dir = self._conn:select("directory", {
	where = { id = id }
    })

    if not dir or #dir == 0 then
	return id
    end

    dir = dir[1]
    dir.parent = parent
    local copy_id = self:create_directory(dir)

    local sub_notes = self._conn:select("note", {
	where = { parent = id }
    })
    for _, note in ipairs(sub_notes) do
	self:copy_note(note.id, copy_id)
    end

    local sub_directories = self._conn:select("directory", {
	where = { parent = id }
    })
    for _, sub_directory in ipairs(sub_directories) do
	self:deep_copy_directory(sub_directory.id, copy_id)
    end

    return copy_id
end

---@param root string
---@param branch string
---@return integer
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
	    name = root
	}, self)

	DoodleNote.create({
	    project = root,
	    branch = branch,
	    parent = root_dir.id,
	    title = "Quick Note"
	}, self)

	return root_dir.id
    end

    return dir[1].id
end

function DoodleDB:garbage_collect()
    self._conn:delete("directory", {
	where = { status = 2 }
    })
    self._conn:delete("note", {
	where = { status = 2 }
    })
end

---@param notes DoodleNote[] 
---@param directories DoodleDirectory[]
function DoodleDB:save(notes, directories)
    for _, directory in pairs(directories) do
	if not directory.id then
	    self:create_directory(directory)
	else
	    self:update_directory(directory)
	end
    end
    for _, note in pairs(notes) do
	if not note.id then
	    self:create_note(note)
	else
	    self:update_note(note)
	end
    end
end

return DoodleDB
