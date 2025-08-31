---@class DoodleOplog
---@field directory DoodleDirectory[]
---@field note DoodleNote[]
---@field blob DoodleBlob[]
local DoodleOplog = {}
DoodleOplog.__index = DoodleOplog

function DoodleOplog:new()
    return setmetatable({
        directory = {},
        note = {},
        blob = {}
    }, self)
end

---@param data_str string
---@return DoodleOplog
function DoodleOplog.create(data_str)
    local oplog = DoodleOplog:new()

    if data_str and data_str ~= "" then
        for line in data_str:gmatch("([^\n]+)") do
            if line ~= "" then
                local obj = vim.json.decode(line)
                vim.list_extend(oplog.directory, obj.directory)
                vim.list_extend(oplog.note, obj.note)
                vim.list_extend(oplog.blob, obj.blob)
            end
        end
    end

    return oplog
end

return DoodleOplog
