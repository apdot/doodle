local Job = require("plenary.job")

---@class DoodleSettings
---@field auto_save boolean
---@field project fun(): string
---@field branch fun(): string
---@field global fun(): string

---@class DoodleOperations
---@field encode fun(obj:any): string
---@field decode fun(obj:string): string

---@class DoodleConfig
---@field settings DoodleSettings
---@field operations DoodleOperations

local DoodleConfig = {}

function DoodleConfig.get_default()
    return {
	settings = {
	    auto_save = true,
	    project = function ()
		return vim.fs.basename(vim.loop.cwd())
	    end,
	    branch = function ()
		return Job:new({
		    command = "git",
		    args = { "rev-parse", "--abbrev-ref", "HEAD" },
		}):sync()[1]
	    end,
	    global = function ()
		return "__global"
	    end
	},
	operations = {
	    encode = function (obj)
		return vim.json.encode(obj)
	    end,

	    decode = function (str)
		return vim.json.decode(str)
	    end,
	}
    }
end

return DoodleConfig
