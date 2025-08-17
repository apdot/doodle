local DoodleConfig = require("doodle.config")
local DoodleDisc = require("doodle.disc")
local DoodleNote = require("doodle.note")
local DoodleUI = require("doodle.ui")

---@class Doodle
---@field config DoodleConfig
---@field disc DoodleDisc
---@field notes {[string]: DoodleNote}
local Doodle = {}

Doodle.__index = Doodle

function Doodle:new()
    local config = DoodleConfig.get_default()

    local doodle = setmetatable({
	config = config,
	disc = DoodleDisc:new(config),
	notes = {},
	ui = DoodleUI:new(config.settings),
	hooks_setup = false
    }, self)

    return doodle
end

function Doodle:note()
    local project = self.config.settings.project()
    ---TODO dynamic branch
    local branch = "__global"
    local existing_note = self.notes["__global"]

    if existing_note then
	return existing_note
    end

    local disc_note = self.disc:fetch_note(project, "__global")
    local note = DoodleNote:new("__global", disc_note, self.config.operations)
    self.notes["__global"] = note

    return note
end

function Doodle:sync()
    local project = self.config.settings.project()
    for branch, note in pairs(self.notes) do
	self.disc:update(project, branch, note)
    end
    self.disc:sync()
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
    -- self.config = DoodleConfig.merge(partial_config, self.config)

    if not self.hooks_setup then
	vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
	    callback = function ()
		self:sync()
	    end
	})
	self.hooks_setup = true
    end

    return self
end

return doodle
