local FileUtil = require("doodle.utils.file_util")
local ScanDir = require("plenary.scandir")
local Job = require("plenary.job")

---@class DoodleSettings
---@field auto_save boolean
---@field sync boolean
---@field git_repo string
---@field git_remote string
---@field hide_hint boolean
---@field project fun(): string
---@field branch fun(): string
---@field global fun(): string
---@field finder_height_factor number
---@field finder_width_factor number

---@class DoodleHandlers
---@field encode fun(obj:any): string
---@field decode fun(obj:string): string
---@field snapshot_condition fun(obj:SyncConfig, obj:string): boolean

---@class DoodleConfig
---@field settings DoodleSettings
---@field operations DoodleHandlers

local DoodleConfig = {}

function DoodleConfig.get_default()
    local settings = {
        auto_save = false,
        sync = false,
        hide_hint = false,
        finder_height_factor = 0.4,
        finder_width_factor = 0.5,
        git_remote = "origin main",
        project = function()
            return vim.fs.basename(vim.loop.cwd())
        end,
        branch = function()
            return Job:new({
                command = "git",
                args = { "rev-parse", "--abbrev-ref", "HEAD" },
            }):sync()[1]
        end,
        global = function()
            return "__global"
        end
    }
    local operations = {
        encode = function(obj)
            return vim.json.encode(obj)
        end,

        decode = function(str)
            return vim.json.decode(str)
        end,

        snapshot_condition = function(sync_config, git_repo)
            local files_in_repo = ScanDir.scan_dir(git_repo, { add_dirs = false })

            local snapshot, _ = FileUtil.find_snapshot(files_in_repo)
            if not snapshot or sync_config.bytes > 1024 * 1024 then
                return true
            end

            return false
        end
    }
    return {
        settings = settings,
        operations = operations
    }
end

---@param partial_config DoodleConfig?
---@param latest_config DoodleConfig?
---@return DoodleConfig
function DoodleConfig.merge_config(partial_config, latest_config)
    partial_config = partial_config or {}
    local config = latest_config or DoodleConfig.get_default_config()

    for k, v in pairs(partial_config) do
        if k == "settings" then
            config.settings = vim.tbl_extend("force", config.settings, v)
        elseif k == "operations" then
            config.operations = vim.tbl_extend("force", config.operations, v)
        else
            config[k] = vim.tbl_extend("force", config[k] or {}, v)
        end
    end

    return config
end

return DoodleConfig
