local DoodleConfig = require("doodle.config")
local DoodleDisc = require("doodle.disc")
local DoodleNote = require("doodle.note")
local DoodleUI = require("doodle.ui")

---@class Doodle
---@field config DoodleConfig
---@field disc DoodleDisc
---@field notes {[string]: DoodleNote}
---@field global DoodleNote
local Doodle = {}

Doodle.__index = Doodle

function Doodle:new()
    local config = DoodleConfig.get_default()

    local doodle = setmetatable({
	config = config,
	disc = DoodleDisc:new(config),
	notes = {},
	global = nil,
	ui = DoodleUI:new(config.settings),
	hooks_setup = false
    }, self)

    return doodle
end

function Doodle:load_global(project, key)
    if not key then
	return
    end

    local existing_note = self.global

    if existing_note then
	return existing_note
    end

    local disc_note = self.disc:fetch_global(project)
    local note = DoodleNote:new(key, disc_note, self.config.operations)
    self.global = note

    return note
end

function Doodle:load_note(project, key)
    if not key then
	return
    end

    local existing_note = self.notes[key]

    if existing_note then
	return existing_note
    end

    local disc_note = self.disc:fetch_note(project, key)
    local note = DoodleNote:new(key, disc_note, self.config.operations)
    self.notes[key] = note

    return note
end

function Doodle:note()
    local global = self.config.settings.global()
    local global_note = self:load_global(global, global)

    local project = self.config.settings.project()
    local branch = self.config.settings.branch()
    local branch_note = self:load_note(project, branch)
    local note = self:load_note(project, project)

    note.global_note = global_note
    note.branch_note = branch_note
    return note
end

function Doodle:sync()
    local project = self.config.settings.project()
    for branch, note in pairs(self.notes) do
	self.disc:update(project, branch, note)
    end

    local global = self.config.settings.global()
    self.disc:update_global(global, self.global)

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
