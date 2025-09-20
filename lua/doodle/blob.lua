local DBUtil = require("doodle.utils.db_util")

---@class DoodleBlob
---@field id integer
---@field uuid string
---@field note_id string
---@field content string
---@field created_at integer
---@field updated_at integer
---@field synced_at integer
local DoodleBlob = {}
DoodleBlob.__index = DoodleBlob

local primary_key = "uuid"

local table_name = "blob"

local columns = {
    "uuid",
    "note_id",
    "content",
    "created_at",
    "updated_at",
    "synced_at"
}

---@param dict table
---@return DoodleBlob
function DoodleBlob:new(dict)
    return setmetatable({
        id = dict["id"],
        uuid = dict["uuid"],
        note_id = dict["note_id"],
        content = dict["content"],
        created_at = dict["created_at"],
        updated_at = dict["updated_at"],
        synced_at = dict["synced_at"]
    }, self)
end

---@param dict table
---@param db DoodleDB
---@return DoodleBlob
function DoodleBlob.create(dict, db)
    local blob = DoodleBlob:new(dict)
    print("blobl values", blob.note_id, blob.content)

    local uuid = db:create_blob(blob)
    blob.uuid = uuid

    return blob
end

---@param note_id string
---@param db DoodleDB
---@return DoodleBlob
function DoodleBlob.get(note_id, db)
    local dict = db:get_blob(note_id)
    if not dict.id then
        dict = DoodleBlob:new({
            note_id = note_id,
            content = ""
        })
    end
    return DoodleBlob:new(dict)
end

---@param list_dict table[]
---@return DoodleBlob[]
function DoodleBlob.from_list(list_dict)
    local blobs = {}

    for _, dict in ipairs(list_dict) do
        local blob = DoodleBlob:new(dict)
        table.insert(blobs, blob)
    end

    return blobs
end

---@param db DoodleDB
---@return DoodleBlob[]
function DoodleBlob.get_unsynced(db)
    local blobs = db:get_unsynced(table_name)

    return DoodleBlob.from_list(blobs)
end

---@param db DoodleDB
---@return DoodleBlob[]
function DoodleBlob.get_all(db)
    local blobs = db:get_all(table_name)

    return DoodleBlob.from_list(blobs)
end

---@param dict table
---@param now integer
---@param db DoodleDB
function DoodleBlob.mark_synced(dict, now, db)
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
function DoodleBlob.bulk_upsert(dict, where, db)
    local values_dict = {}
    for _, blob in pairs(dict) do
        table.insert(values_dict, DBUtil.format_values({
            blob.uuid,
            blob.note_id,
            blob.content,
            blob.created_at or DBUtil.now(),
            blob.updated_at or DBUtil.now(),
            blob.synced_at or vim.NIL
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
function DoodleBlob.update(dict, db)
    local where = ("%s.updated_at < excluded.updated_at"):format(table_name)
    return DoodleBlob.bulk_upsert(dict, where, db)
end

---@param db DoodleDB
function DoodleBlob:save(db)
    if self.uuid then
        db:update_blob(self)
    else
        print(self.note_id, self.content)
        db:create_blob(self)
    end
end

return DoodleBlob
