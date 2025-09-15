local DBUtil = require("doodle.utils.db_util")

---@class Tag
---@field uuid string
---@field name string
---@field created_at integer
---@field updated_at integer
---@field synced_at integer
local Tag = {}
Tag.__index = Tag

local table_name = "tag"

local columns = {
    "uuid",
    "name",
    "created_at",
    "updated_at",
    "synced_at"
}

---@param dict table
---@return Tag
function Tag:new(dict)
    return setmetatable({
        id = dict["id"],
        uuid = dict["uuid"],
        name = dict["name"],
        created_at = dict["created_at"],
        updated_at = dict["updated_at"],
        synced_at = dict["synced_at"]
    }, self)
end

---@param prefix string
---@param db DoodleDB
function Tag.search(prefix, db)
    local tags = db:search_tag(prefix)

    local tag_names = {}
    if tags and type(tags) == "table" then
        for _, tag in pairs(tags) do
            table.insert(tag_names, tag.name)
        end
    end

    return tag_names
end

---@param dict table
---@param db DoodleDB
---@return Tag
function Tag.create(dict, db)
    local tag = Tag:new(dict)

    local uuid = db:create_tag(tag)
    tag.uuid = uuid

    return tag
end

---@param name string
---@param db DoodleDB
---@return Tag?
function Tag.get(name, db)
    local dict = db:get_tag(name)
    if dict.id then
        return Tag:new(dict)
    end

    return nil
end

---@param name string
---@param db DoodleDB
---@return Tag
function Tag.get_or_create(name, db)
    local tag = Tag.get(name, db)
    if tag then
        return tag
    end

    return Tag.create({
        name = name
    }, db)
end

---@param dict table
---@param db DoodleDB
---@param where string
function Tag.bulk_upsert(dict, where, db)
    local values_dict = {}
    for _, tag in pairs(dict) do
        table.insert(values_dict, DBUtil.format_values({
            tag.uuid,
            tag.name,
            tag.created_at or DBUtil.now(),
            tag.updated_at or DBUtil.now(),
            tag.synced_at or vim.NIL
        }))
    end

    if #values_dict == 0 then
        return
    end

    local values = table.concat(values_dict, ",")
    db:bulk_upsert(table_name, columns, values, "uuid", where)
end

---@param dict table
---@return Tag[]
function Tag.from_list(dict)
    local tags = {}

    for _, tag in pairs(dict) do
        table.insert(tags, Tag:new(tag))
    end

    return tags
end

---@param tag_names string[]
---@param db DoodleDB
---@return Tag[]
function Tag.save(tag_names, db)
    local tags = {}

    for _, name in pairs(tag_names) do
        local tag = Tag.get_or_create(name, db)
        table.insert(tags, tag)
    end

    return tags
end

return Tag
