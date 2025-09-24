local DBUtil = require("doodle.utils.db_util")

---@class Link
---@field uuid string
---@field src string
---@field dest string
---@field link_str string
---@field to_note boolean
---@field created_at integer
---@field updated_at integer
---@field synced_at integer
local Link = {}
Link.__index = Link

local primary_key = "uuid"

local table_name = "link"

local columns = {
    "uuid",
    "src",
    "dest",
    "link_str",
    "to_note",
    "created_at",
    "updated_at",
    "synced_at"
}

---@param dict table
---@return Link
function Link:new(dict)
    return setmetatable({
        id = dict["id"],
        uuid = dict["uuid"],
        src = dict["src"],
        dest = dict["dest"],
        link_str = dict["link_str"],
        to_note = dict["to_note"],
        created_at = dict["created_at"],
        updated_at = dict["updated_at"],
        synced_at = dict["synced_at"]
    }, self)
end

---@param dict table
---@param db DoodleDB
---@return Link
function Link.create(dict, db)
    local link = Link:new(dict)

    local uuid = db:create_link(link)
    link.uuid = uuid

    return link
end

---@param list_dict table[]
---@return Link[]
function Link.from_list(list_dict)
    local links = {}

    for _, dict in ipairs(list_dict) do
        local link = Link:new(dict)
        table.insert(links, link)
    end

    return links
end

---@param db DoodleDB
---@return Link[]
function Link.get_all(db)
    local links = db:get_all(table_name, "created_at")

    return Link.from_list(links)
end

---@param db DoodleDB
---@return Link[]
function Link.get_unsynced(db)
    local links = db:get_unsynced(table_name)

    return Link.from_list(links)
end

---@param dict table
---@param now integer
---@param db DoodleDB
function Link.mark_synced(dict, now, db)
    local uuids = DBUtil.get_query_uuids(dict)
    local values = {}
    for _, uuid in pairs(uuids) do
        table.insert(values, ("(%s)"):format(uuid))
    end

    if uuids and #uuids > 0 then
        db:mark_synced(table_name, primary_key, table.concat(values, ","), now)
    end
end

---@param dict table
---@param db DoodleDB
---@param where string
function Link.bulk_upsert(dict, where, db)
    local values_dict = {}
    for _, link in pairs(dict) do
        table.insert(values_dict, DBUtil.format_values({
            link.uuid,
            link.src,
            link.dest,
            link.link_str,
            link.to_note,
            link.created_at or DBUtil.now(),
            link.updated_at or DBUtil.now(),
            link.synced_at or vim.NIL
        }))
    end

    if #values_dict == 0 then
        return
    end

    local values = table.concat(values_dict, ",")
    db:bulk_upsert(table_name, columns, values, primary_key, where)
end

---@param dict table
---@param db DoodleDB
function Link.update(dict, db)
    local where = ("%s.updated_at < excluded.updated_at"):format(table_name)
    return Link.bulk_upsert(dict, where, db)
end

return Link
