local DBUtil = require("doodle.utils.db_util")
local Tag = require("doodle.tags.tag")

---@class NoteTag
---@field tag_id string
---@field note_id string
---@field status integer
---@field created_at integer
---@field updated_at integer
---@field synced_at integer
local NoteTag = {}
NoteTag.__index = NoteTag

local table_name = "note_tag"

local columns = {
    "tag_id",
    "note_id",
    "status",
    "created_at",
    "updated_at",
    "synced_at"
}

---@param dict table
---@return NoteTag
function NoteTag:new(dict)
    return setmetatable({
        id = dict["id"],
        tag_id = dict["tag_id"],
        note_id = dict["note_id"],
        status = dict["status"],
        created_at = dict["created_at"],
        updated_at = dict["updated_at"],
        synced_at = dict["synced_at"]
    }, self)
end

---@param note_id string
---@param db DoodleDB
function NoteTag.clear(note_id, db)
    db:clear_tag(note_id)
end

---@param dict table
---@param db DoodleDB
---@param where string
function NoteTag.bulk_upsert(dict, where, db)
    local values_dict = {}
    for _, note_tag in pairs(dict) do
        table.insert(values_dict, DBUtil.format_values({
            note_tag.tag_id,
            note_tag.note_id,
            note_tag.status,
            note_tag.created_at or DBUtil.now(),
            note_tag.updated_at or DBUtil.now(),
            note_tag.synced_at or vim.NIL
        }))
    end

    if #values_dict == 0 then
        return
    end

    local values = table.concat(values_dict, ",")
    db:bulk_upsert(table_name, columns, values, "tag_id, note_id", where)
end

---@param note_id string
---@param db DoodleDB
---@return Tag[]
function NoteTag.get_for_note(note_id, db)
    return Tag.from_list(db:get_tags_for_note(note_id))
end

---@param tags Tag[]
---@param note_id string
---@param db DoodleDB
function NoteTag.map(tags, note_id, db)
    local note_tags = {}
    for _, tag in pairs(tags) do
        table.insert(note_tags, {
            tag_id = tag.uuid,
            note_id = note_id,
            status = 1
        })
    end

    local where = DBUtil.create_is_distinct(table_name, columns)
    NoteTag.bulk_upsert(note_tags, where, db)
end

---@param tag_names string[]
---@param note_ids string[]
---@param db DoodleDB
function NoteTag.bulk_map(tag_names, note_ids, db)
    local tags = Tag.save(tag_names, db)

    for _, note_id in pairs(note_ids) do
        print("note_id", note_id)
        NoteTag.map(tags, note_id, db)
    end
end

return NoteTag
