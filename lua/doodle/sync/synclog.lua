local SyncConfig = require("doodle.sync.sync_config")

---@class SyncLog
---@field data table<[string], SyncConfig>
local SyncLog = {}
SyncLog.__index = SyncLog

function SyncLog:new(dict)
    local data = {}

    if dict.data then
        for device_id, config in pairs(dict.data) do
            data[device_id] = SyncConfig:new(config)
        end
    end

    return setmetatable({
        data = data
    }, self)
end

return SyncLog
