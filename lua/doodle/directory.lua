local DBUtil = require("doodle.utils.db_util")

---@class DoodleDirectory
---@field id integer
---@field uuid string
---@field project string
---@field branch string
---@field parent string
---@field name string
---@field status integer
---@field created_at integer
---@field updated_at integer
---@field synced_at integer
local DoodleDirectory = {}
DoodleDirectory.__index = DoodleDirectory

local table_name = "directory"

local columns = {
    "uuid",
    "project",
    "branch",
    "parent",
    "name",
    "status",
    "created_at",
    "updated_at",
    "synced_at"
}

---@param dict table
---@return DoodleDirectory
function DoodleDirectory:new(dict)
    return setmetatable({
        id = dict["id"],
        uuid = dict["uuid"],
        project = dict["project"],
        branch = dict["branch"],
        parent = dict["parent"],
        name = dict["name"],
        status = dict["status"],
        created_at = dict["created_at"],
        updated_at = dict["updated_at"],
        synced_at = dict["synced_at"]
    }, self)
end

---@param uuid string
---@param parent string
---@param db DoodleDB
---@return DoodleDirectory
function DoodleDirectory.deep_copy(uuid, parent, db)
    local copy_id = db:deep_copy_directory(uuid, parent)

    return DoodleDirectory:new({
        uuid = copy_id,
        status = 1
    })
end

---@param dict table
---@param db DoodleDB
---@return DoodleDirectory
function DoodleDirectory.create(dict, db)
    local directory = DoodleDirectory:new(dict)

    local uuid = db:create_directory(directory)
    directory.uuid = uuid
    directory.status = 1

    return directory
end

---@param uuid string
---@param db DoodleDB
---@return DoodleDirectory
function DoodleDirectory.get(uuid, db)
    local dict = db:get_directory(uuid)

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

---@param db DoodleDB
---@return DoodleDirectory[]
function DoodleDirectory.get_unsynced(db)
    local directories = db:get_unsynced(table_name)

    return DoodleDirectory.from_list(directories)
end

---@param db DoodleDB
---@return DoodleDirectory[]
function DoodleDirectory.get_all(db)
    local directories = db:get_all(table_name)

    return DoodleDirectory.from_list(directories)
end

---@param dict table
---@param now integer
---@param db DoodleDB
function DoodleDirectory.mark_synced(dict, now, db)
    local uuids = DBUtil.get_uuids(dict)

    db:mark_synced(table_name, uuids, now)
end

---@param directories DoodleDirectory[]
---@param now integer
function DoodleDirectory.update_synced_at(directories, now)
    for _, dir in pairs(directories) do
        dir.synced_at = now
    end
end

---@param dict table
---@param db DoodleDB
---@param where string
function DoodleDirectory.bulk_upsert(dict, where, db)
    local values_dict = {}
    for _, dir in pairs(dict) do
        table.insert(values_dict, DBUtil.format_values({
            dir.uuid,
            dir.project,
            dir.branch or vim.NIL,
            dir.parent or vim.NIL,
            dir.name,
            dir.status,
            dir.created_at or DBUtil.now(),
            dir.updated_at or DBUtil.now(),
            dir.synced_at or vim.NIL
        }))
    end

    if #values_dict == 0 then
        return
    end

    local values = table.concat(values_dict, ",")
    db:bulk_upsert(table_name, columns, values, where)
end

---@param dict table
---@param db DoodleDB
function DoodleDirectory.update(dict, db)
    local where = ("%s.updated_at < excluded.updated_at"):format(table_name)
    return DoodleDirectory.bulk_upsert(dict, where, db)
end

---@param dict table
---@param db DoodleDB
function DoodleDirectory.save(dict, db)
    local where = DBUtil.create_is_distinct(table_name, columns)
    return DoodleDirectory.bulk_upsert(dict, where, db)
end

return DoodleDirectory
