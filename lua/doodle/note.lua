local DBUtil = require("doodle.utils.db_util")

---@class DoodleNote
---@field id integer
---@field project string
---@field branch string
---@field parent string
---@field title string
---@field status integer
---@field path string
---@field uuid string
---@field created_at integer
---@field updated_at integer
---@field synced_at integer
local DoodleNote = {}
DoodleNote.__index = DoodleNote

local table_name = "note"

local columns = {
    "uuid",
    "project",
    "branch",
    "parent",
    "title",
    "status",
    "path",
    "created_at",
    "updated_at",
    "synced_at"
}

---@param dict table
---@return DoodleNote
function DoodleNote:new(dict)
    return setmetatable({
        id = dict["id"],
        uuid = dict["uuid"],
        project = dict["project"],
        branch = dict["branch"],
        parent = dict["parent"],
        title = dict["title"],
        status = dict["status"],
        path = dict["path"],
        created_at = dict["created_at"],
        updated_at = dict["updated_at"],
        synced_at = dict["synced_at"]
    }, self)
end

---@param uuid string
---@param parent string
---@param db DoodleDB
---@return DoodleNote
function DoodleNote.copy(uuid, parent, db)
    local copy_id = db:copy_note(uuid, parent)
    return DoodleNote:new({
        uuid = copy_id,
        status = 1
    })
end

---@param dict table
---@param db DoodleDB
---@return DoodleNote
function DoodleNote.create(dict, db)
    local note = DoodleNote:new(dict)

    local uuid = db:create_note(note)
    note.uuid = uuid
    note.status = 1

    return note
end

---@param uuid string
---@param db DoodleDB
---@return DoodleNote
function DoodleNote.get(uuid, db)
    local dict = db:get_note(uuid)
    return DoodleNote:new(dict)
end

---@param list_dict table[]
---@return DoodleNote[]
function DoodleNote.from_list(list_dict)
    local notes = {}

    for _, dict in ipairs(list_dict) do
        local note = DoodleNote:new(dict)
        table.insert(notes, note)
    end

    return notes
end

---@param db DoodleDB
---@return DoodleNote[]
function DoodleNote.get_unsynced(db)
    local notes = db:get_unsynced(table_name)

    return DoodleNote.from_list(notes)
end

---@param db DoodleDB
---@param where table
---@return DoodleNote[]
function DoodleNote.get_all(db, where)
    local notes = db:get_all(table_name, where)

    return DoodleNote.from_list(notes)
end

---@param dict table
---@param now integer
---@param db DoodleDB
function DoodleNote.mark_synced(dict, now, db)
    local uuids = DBUtil.get_query_uuids(dict)

    db:mark_synced(table_name, uuids, now)
end

---@param notes DoodleNote[]
---@param now integer
function DoodleNote.update_synced_at(notes, now)
    for _, note in pairs(notes) do
        note.synced_at = now
    end
end

---@param dict table
---@param db DoodleDB
---@param where string
function DoodleNote.bulk_upsert(dict, where, db)
    local values_dict = {}
    for _, note in pairs(dict) do
        table.insert(values_dict, DBUtil.format_values({
            note.uuid,
            note.project,
            note.branch or vim.NIL,
            note.parent or vim.NIL,
            note.title,
            note.status,
            note.path,
            note.created_at or DBUtil.now(),
            note.updated_at or DBUtil.now(),
            note.synced_at or vim.NIL
        }))
    end

    if #values_dict == 0 then
        return
    end

    local values = table.concat(values_dict, ",")
    db:bulk_upsert(table_name, columns, values, "uuid", where)
end

---@param dict table
---@param db DoodleDB
function DoodleNote.update(dict, db)
    local where = ("%s.updated_at < excluded.updated_at"):format(table_name)
    return DoodleNote.bulk_upsert(dict, where, db)
end

---@param dict table<string, DoodleNote>
---@param db DoodleDB
function DoodleNote.save(dict, db)
    local where = DBUtil.create_is_distinct(table_name, columns)
    return DoodleNote.bulk_upsert(dict, where, db)
end

return DoodleNote
