---@class DoodleBlob
---@field id integer
---@field note_id integer
---@field content string
---@field created_at integer
---@field updated_at integer
local DoodleBlob = {}
DoodleBlob.__index = DoodleBlob

---@param dict table
---@return DoodleBlob
function DoodleBlob:new(dict)
    return setmetatable({
	id = dict["id"],
	note_id = dict["note_id"],
	content = dict["content"],
	created_at = dict["created_at"],
	updated_at = dict["updated_at"]
    }, self)
end

---@param note_id integer
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

---@param db DoodleDB
function DoodleBlob:save(db)
    if self.id then
	db:update_blob(self)
    else
	db:create_blob(self)
    end
end

return DoodleBlob
