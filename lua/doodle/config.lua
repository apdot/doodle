local Job = require("plenary.job")

---@field DoodleOperations
local DoodleConfig = {}

function DoodleConfig.get_default()
    return {
	settings = {
	    auto_save = true,
	    project = function ()
		return vim.loop.cwd()
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
