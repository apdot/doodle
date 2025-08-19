---@class DoodleNote
local DoodleNote = {}
DoodleNote.__index = DoodleNote

---@field branch string
---@field body string
---@field global_note DoodleNote
---@field branch_note DoodleNote
---@field operators DoodleConfig.operators
---@return DoodleNote
function DoodleNote:new(branch, body, operators)
    body = body or {}
    return setmetatable({
	branch = branch,
	body = body,
	global_note = nil,
	branch_note = nil,
	operators = operators
    }, self)
end

function DoodleNote:update(body)
    self.body = body
end

function DoodleNote:append(body)
  if not self.body then
    self.body = {}
  end
  vim.list_extend(self.body, body)
end

function DoodleNote:display()
    local display = {}
    table.insert(display, "")
    vim.list_extend(display, self.body)
    return display
end

function DoodleNote:get_length()
    return self.body and #self.body or 0
end

function DoodleNote:get_body()
    return self.body
end

return DoodleNote
