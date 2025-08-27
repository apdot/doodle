---@class DoodleDirectory
---@field id integer
---@field project string
---@field branch string
---@field parent integer
---@field name string
---@field status integer
---@field created_at integer
---@field updated_at integer
local DoodleDirectory = {}
DoodleDirectory.__index = DoodleDirectory

---@param dict table
---@return DoodleDirectory
function DoodleDirectory:new(dict)
    return setmetatable({
	id = dict["id"],
	project = dict["project"],
	branch = dict["branch"],
	parent = dict["parent"],
	name = dict["name"],
	status = dict["status"],
	created_at = dict["created_at"],
	updated_at = dict["updated_at"]
    }, self)
end

---@param id integer
---@param parent integer
---@param db DoodleDB
---@return DoodleDirectory
function DoodleDirectory.deep_copy(id, parent, db)
    local copy_id = db:deep_copy_directory(id, parent)
    return DoodleDirectory:new({
	id = copy_id,
	status = 1
    })
end

---@param dict table
---@param db DoodleDB
---@return DoodleDirectory
function DoodleDirectory.create(dict, db)
    local directory = DoodleDirectory:new(dict)

    local id = db:create_directory(directory)
    directory.id = id
    directory.status = 1

    return directory
end

---@param id integer
---@param db DoodleDB
---@return DoodleDirectory
function DoodleDirectory.get(id, db)
    local dict = db:get_directory(id)
    return DoodleDirectory:new(dict)
end

---@param list_dict table[]
---@return DoodleDirectory[]
function DoodleDirectory.from_list(list_dict)
    local directories = {}

    for _, dict in ipairs(list_dict) do
	local directory = DoodleDirectory:new(dict)
	table.insert(directories, directory)
    end

    return directories
end

return DoodleDirectory
