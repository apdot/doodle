---@field DoodleOperations
local DoodleConfig = {}

function DoodleConfig.get_default()
    return {
	settings = {
	    auto_save = true,
	    project = function ()
		return vim.loop.cwd()
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
