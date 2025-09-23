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

return Link
