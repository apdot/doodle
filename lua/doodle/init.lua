local DoodleConfig = require("doodle.config")
local DoodleUI = require("doodle.ui")
local DoodleDB = require("doodle.storage.db")
local DoodleSync = require("doodle.sync.sync")
local Completion = require("doodle.tags.completion")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local FormatUtil = require("doodle.utils.format_util")

---@class Doodle
---@field config DoodleConfig
---@field _db DoodleDB
---@field _ui DoodleUI
---@field _sync DoodleSync
---@field hooks_setup boolean
local Doodle = {}

Doodle.__index = Doodle

function Doodle:new()
    local config = DoodleConfig.get_default()
    local db = DoodleDB:new()

    local doodle = setmetatable({
        config = config,
        _db = db,
        _ui = DoodleUI:new(config.settings, db),
        _sync = DoodleSync:new(config.settings, config.operations, db),
        completion = Completion,
        hooks_setup = false
    }, self)

    return doodle
end

function Doodle:save()
    self._ui:save()
end

function Doodle:toggle_finder()
    self._ui:toggle_finder()
end

function Doodle:toggle_links()
    self._ui:toggle_links()
end

function Doodle:sync()
    if self.config.settings.sync then
        self:save()
        self._sync:setup()
        self._sync:sync()
        self._ui:load_current_directory()
    end
end

function Doodle:here()
    self._ui:here()
end

---@param opts table
function Doodle:create_template(opts)
    self._ui:create_template(opts)
end

function Doodle.find_notes()
    require("telescope._extensions.find")()
end

local doodle = Doodle:new()
_G.doodle = doodle

---@param self Doodle
---@param partial_config DoodleConfig
---@return Doodle
function Doodle.setup(self, partial_config)
    if self ~= doodle then
        ---@diagnostic disable-next-line: cast-local-type
        partial_config = self
        self = doodle
    end

    self._db:setup()

    if not self.hooks_setup then
        vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
            callback = function()
                self:save()
                -- self.db:garbage_collect()
            end
        })
        self.hooks_setup = true
    end

    vim.api.nvim_create_user_command(
        "DoodleSync",
        function()
            doodle:sync()
        end,
        { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        "DoodleHere",
        function()
            doodle:here()
        end,
        { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        "DoodleFinder",
        function()
            doodle:toggle_finder()
        end,
        { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        "DoodleLinks",
        function()
            doodle:toggle_links()
        end,
        { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        "DoodleFind",
        Doodle.find_notes, {
            desc = "Find a doodle note with Telescope"
        })

    vim.api.nvim_create_user_command(
        'DoodleCreateTemplate',
        function(opts)
            doodle:create_template(opts)
        end,
        {
            nargs = 1
        }
    )

    return self
end

return doodle
