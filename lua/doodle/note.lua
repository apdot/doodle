
---@class DoodleNote
local DoodleNote = {}
DoodleNote.__index = DoodleNote

---@field branch string
---@field body string
---@field operators DoodleConfig.operators
---@return DoodleNote
function DoodleNote:new(branch, body, operators)
    body = body or {}
    return setmetatable({
	branch = branch,
	body = body,
	operators = operators
    }, self)
end

function DoodleNote:update(body, length)
    self.body = body
end

function DoodleNote:get_body()
    return self.body
end

return DoodleNote
