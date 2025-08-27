---@class DoodleNote
---@field id integer
---@field project string
---@field branch string
---@field parent integer
---@field title string
---@field status integer
---@field created_at integer
---@field updated_at integer
local DoodleNote = {}
DoodleNote.__index = DoodleNote

---@param dict table
---@return DoodleNote
function DoodleNote:new(dict)
    return setmetatable({
	id = dict["id"],
	project = dict["project"],
	branch = dict["branch"],
	parent = dict["parent"],
	title = dict["title"],
	status = dict["status"],
	created_at = dict["created_at"],
	updated_at = dict["updated_at"]
    }, self)
end

---@param id integer
---@param parent integer
---@param db DoodleDB
---@return DoodleNote
function DoodleNote.copy(id, parent, db)
    local copy_id = db:copy_note(id, parent)
    return DoodleNote:new({
	id = copy_id,
	status = 1
    })
end

---@param dict table
---@param db DoodleDB
---@return DoodleNote
function DoodleNote.create(dict, db)
    local note = DoodleNote:new(dict)

    local id = db:create_note(note)
    note.id = id
    note.status = 1

    return note
end

---@param id integer
---@param db DoodleDB
---@return DoodleNote
function DoodleNote.get(id, db)
    local dict = db:get_note(id)
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

return DoodleNote
