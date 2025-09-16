---@class DoodleOplog
---@field directory DoodleDirectory[]
---@field note DoodleNote[]
---@field blob DoodleBlob[]
---@field tag Tag[]
---@field note_tag NoteTag[]
local DoodleOplog = {}
DoodleOplog.__index = DoodleOplog

function DoodleOplog:new()
    return setmetatable({
        directory = {},
        note = {},
        blob = {},
        tag = {},
        note_tag = {}
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
                if obj.directory then
                    vim.list_extend(oplog.directory, obj.directory)
                end
                if obj.directory then
                    vim.list_extend(oplog.note, obj.note)
                end
                if obj.directory then
                    vim.list_extend(oplog.blob, obj.blob)
                end
                if obj.directory then
                    vim.list_extend(oplog.tag, obj.tag)
                end
                if obj.directory then
                    vim.list_extend(oplog.note_tag, obj.note_tag)
                end
            end
        end
    end

    return oplog
end

return DoodleOplog
