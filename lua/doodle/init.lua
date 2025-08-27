local DoodleConfig = require("doodle.config")
local DoodleUI = require("doodle.ui")
local DoodleDB = require("doodle.storage.db")

---@class Doodle
---@field config DoodleConfig
---@field db DoodleDB
---@field ui DoodleUI
---@field hooks_setup boolean
local Doodle = {}

Doodle.__index = Doodle

function Doodle:new()
    local config = DoodleConfig.get_default()
    local db = DoodleDB:new()

    local doodle = setmetatable({
	config = config,
	db = db,
	ui = DoodleUI:new(config.settings, db),
	hooks_setup = false
    }, self)

    return doodle
end

function Doodle:save()
    self.ui:save()
end

function Doodle:toggle_finder()
    self.ui:toggle_finder()
end

local doodle = Doodle:new()

---@param self Doodle
---@param partial_config DoodleConfig 
---@return Doodle
function Doodle.setup(self, partial_config)
    if self ~= doodle then
	---@diagnostic disable-next-line: cast-local-type
	partial_config = self
	self = doodle
    end

    self.db:setup()

    if not self.hooks_setup then
	vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
	    callback = function ()
		self:save()
		-- self.db:garbage_collect()
	    end
	})
	self.hooks_setup = true
    end

    return self
end

return doodle
