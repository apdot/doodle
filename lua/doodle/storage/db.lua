local sqlite = require("sqlite")
local FileUtil = require("doodle.utils.fileutil")
local DBUtil = require("doodle.utils.dbutil")

local DoodleDB = {}
DoodleDB.__index = DoodleDB

---@class DoodleDirectory
---@field id integer
---@field project string
---@field branch string
---@field parent integer
---@field name string
---@field created_at integer
---@field updated_at integer

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
	deleted 	= 	{ "boolean", default = "0" },
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
	deleted 	= 	{ "boolean", default = "0" },
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

function DoodleDB:load_finder(parent, branch)
    print("load_finder", parent, branch)
    local notes = self._conn:select("note", {
	where = {
	    parent = parent,
	    deleted = false
	},
	order_by = { asc = { "title" , "created_at" } }
    })

    for k, note in pairs(notes) do
	print(note.id, note.project, note.branch, note.title, note.created_at, note.updated_at)
    end

    local directories = self._conn:select("directory", {
	where = {
	    parent = parent,
	    deleted = false
	},
	order_by = { asc = { "name" , "created_at" } }
    })

    for k, dir in pairs(directories) do
	print(dir.id, dir.project, dir.branch, dir.name, dir.created_at, dir.updated_at)
    end

    return notes or {}, directories or {}
end

function DoodleDB:create_blob(note_id, content)
    local ok, id = self._conn:insert("blob", {
	note_id = note_id,
	content = content
    })
    return id
end

function DoodleDB:create_note(project, branch, parent, title)
    local ok, id = self._conn:insert("note", DBUtil.dict({
	project = project,
	branch = branch,
	title = title,
	parent = parent
    }))
    return id
end

function DoodleDB:update_note(id, project, branch, parent, title)
    self._conn:update("note", {
	where = { id = id },
	set = DBUtil.dict({
	    project = project,
	    branch = branch,
	    parent = parent,
	    title = title,
	    deleted = false
	})
    })
end

function DoodleDB:delete_note(id)
    self._conn:update("note", {
	where = { id = id },
	set = { deleted = true }
    })
end

function DoodleDB:copy_note(id, project, branch, parent)
    local notes = self._conn:select("note", {
	where = { id = id }
    })

    if not notes or #notes == 0 then
	return id
    end

    local note = notes[1]
    local copy_id = self:create_note(project, branch, parent, note.title)

    local blob = self._conn:select("blob", {
	where = { note_id = id }
    })

    if not blob or #blob == 0 then
	return copy_id
    end

    blob = blob[1]
    self:create_blob(copy_id, blob.content)

    return copy_id
end

function DoodleDB:create_directory(project, branch, parent, name)
    local ok, id = self._conn:insert("directory", DBUtil.dict({
	project = project,
	branch = branch,
	parent = parent,
	name = name
    }))
    return id
end

function DoodleDB:update_directory(id, project, branch, parent, name)
    self._conn:update("directory", {
	where = { id = id },
	set = DBUtil.dict({
	    project = project,
	    branch = branch,
	    parent = parent,
	    name = name,
	    deleted = false
	})
    })
end

function DoodleDB:delete_directory(id)
    self._conn:update("directory", {
	where = { id = id },
	set = { deleted = true }
    })
end

function DoodleDB:deep_copy_directory(id, project, branch, parent)
    local dir = self._conn:select("directory", {
	where = { id = id }
    })

    if not dir or #dir == 0 then
	return id
    end

    dir = dir[1]
    print("deep copy", id, project, branch, parent, dir.id, dir.name)
    local copy_id = self:create_directory(project, branch, parent, dir.name)

    local sub_notes = self._conn:select("note", {
	where = { parent = id }
    })
    for _, note in ipairs(sub_notes) do
	self:copy_note(note.id, project, branch, copy_id)
    end

    local sub_directories = self._conn:select("directory", {
	where = { parent = id }
    })
    for _, directory in ipairs(sub_directories) do
	self:deep_copy_directory(directory.id, project, branch, copy_id)
    end

    return copy_id
end

function DoodleDB:create_root_if_not_exists(root, branch)
    local dir_id
    local dir = self._conn:select("directory", {
	where = DBUtil.where({
	    project = root,
	    branch = branch and branch or vim.NIL,
	    parent = vim.NIL
	})
    })

    if not dir or #dir == 0 then
	print("root not found")
	dir_id = self:create_directory(root, branch, nil, root)
	self:create_note(root, branch, dir_id, "Quick Note")
    else
	dir_id = dir[1].id
    end

    return dir_id
end

function DoodleDB:garbage_collect()
    self._conn:delete("directory", {
	where = { deleted = true }
    })
    self._conn:delete("note", {
	where = { deleted = true }
    })
end

function DoodleDB:save(project, branch, parent, notes, directories)
    for _, directory in pairs(directories) do
	if not directory.id then
	    self:create_directory(project, branch, parent, directory.name)
	else
	    if directory.status == 2 then
		self:delete_directory(directory.id)
	    else
		self:update_directory(directory.id, project, branch, parent, directory.name)
	    end
	end
    end
    for _, note in pairs(notes) do
	if not note.id then
	    self:create_note(project, branch, parent, note.title)
	else
	    if note.status == 2 then
		self:delete_note(note.id)
	    else
		self:update_note(note.id, project, branch, parent, note.title)
	    end
	end
    end
end

local function now() return os.time() end

function DoodleDB:save_note()
    local p = "myproject"	
    local t = "mytitle"	
    local ts = now()

    self._conn:insert("notes", {
	project 	= 	p,
	title		= 	t,
	created_at 	= 	now(),
	updated_at	= 	now()
    })
end

function DoodleDB:load_note()
    local notes = self._conn:select("notes", {
	where = {
	    project = "myproject"
	}
    })

    for k, note in pairs(notes) do
	print(note.id, note.project, note.branch, note.title, note.created_at, note.updated_at)
    end
end

return DoodleDB
