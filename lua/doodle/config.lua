local FileUtil = require("doodle.utils.file_util")
local ScanDir = require("plenary.scandir")
local Job = require("plenary.job")

---@class DoodleSettings
---@field auto_save boolean
---@field sync boolean
---@field git_repo string
---@field hide_hint boolean
---@field project fun(): string
---@field branch fun(): string
---@field global fun(): string

---@class DoodleHandlers
---@field encode fun(obj:any): string
---@field decode fun(obj:string): string
---@field snapshot_condition fun(obj:SyncConfig): boolean

---@class DoodleConfig
---@field settings DoodleSettings
---@field operations DoodleHandlers

local DoodleConfig = {}

function DoodleConfig.get_default()
    local settings = {
        auto_save = true,
        sync = true,
        git_repo = "/Users/anirudh/.local/share/nvim/doodle/doodle-sync",
        hide_hint = true,
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

        snapshot_condition = function(sync_config)
            local files_in_repo = ScanDir.scan_dir(settings.git_repo, { add_dirs = false })

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

return DoodleConfig
