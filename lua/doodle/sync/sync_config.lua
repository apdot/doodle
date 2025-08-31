---@class SyncConfig
---@field device_id integer
---@field name string
---@field last_sync integer
---@field bytes integer
local SyncConfig = {}
SyncConfig.__index = SyncConfig

---@param dict table
---@return SyncConfig
function SyncConfig:new(dict)
    return setmetatable({
        device_id = dict["device_id"],
        name = dict["name"],
        last_sync = dict["last_sync"],
        bytes = dict["bytes"]
    }, self)
end

return SyncConfig
