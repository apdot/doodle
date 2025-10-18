local DoodleConfig = require("doodle.config")
local DoodleUI = require("doodle.ui")
local DoodleDB = require("doodle.storage.db")
local DoodleSync = require("doodle.sync.sync")
local Completion = require("doodle.tags.completion")
local Exporter = require("doodle.migrations.exporter")
local Importer = require("doodle.migrations.importer")

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

function Doodle:graph_view()
    self._ui:graph_view()
end

function Doodle:find_notes(opts)
    local telescope = require("telescope._extensions.find")
    local arg = opts.fargs[1]
    if arg == 'n' then
        telescope.find_notes()
    elseif arg == 'f' then
        telescope.find_files()
    elseif arg == 't' then
        telescope.find_templates()
    else
        vim.notify("Invalid argument for DoodleFind: " .. arg .. ". Use 'n', 'f', or 't'.")
    end
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

    ---@diagnostic disable-next-line: param-type-mismatch
    self.config = DoodleConfig.merge_config(partial_config, self.config)
    self._db:setup()
    self._ui = DoodleUI:new(self.config.settings, self._db)
    self._sync = DoodleSync:new(self.config.settings, self.config.operations, self._db)

    if not self.hooks_setup then
        vim.api.nvim_create_autocmd({ "VimLeavePre" }, {
            callback = function()
                self:save()
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
        'DoodleFind',
        function(opts)
            doodle:find_notes(opts)
        end,
        {
            nargs = 1,
            complete = function(_, _, _)
                return { 'n', 'f', 't' }
            end
        }
    )

    vim.api.nvim_create_user_command(
        'DoodleCreateTemplate',
        function(opts)
            doodle:create_template(opts)
        end,
        { nargs = 1 }
    )

    vim.api.nvim_create_user_command(
        'DoodleGraphView',
        function()
            doodle:graph_view()
        end,
        { nargs = 0 }
    )

    vim.api.nvim_create_user_command(
        'DoodleExport',
        function(opts)
            if not opts.args or opts.args == "" then
                vim.notify("DoodleExport requires a path argument.", vim.log.levels.ERROR)
                return
            end

            vim.notify("Starting Doodle export")

            local success, msg = pcall(Exporter.run, opts.args, self._db)

            if success then
                vim.notify("Doodle export completed successfully to: " .. opts.args)
            else
                vim.notify("Doodle export failed: " .. msg, vim.log.levels.ERROR)
                print("Doodle Export Error: " .. msg)
            end
        end,
        {
            nargs = 1,
            complete = "dir"
        }
    )

    vim.api.nvim_create_user_command(
        'DoodleImport',
        function(opts)
            if not opts.args or opts.args == "" then
                vim.notify("DoodleImport requires a path argument.", vim.log.levels.ERROR)
                return
            end

            vim.notify("Starting Doodle import")

            local success, msg = pcall(Importer.run, opts.args, self._db)

            if success then
                vim.notify("Doodle import completed successfully from: " .. opts.args)
            else
                vim.notify("Doodle import failed: " .. msg, vim.log.levels.ERROR)
                print("Doodle Import Error: " .. msg)
            end
        end,
        {
            nargs = 1,
            complete = "dir"
        }
    )

    return self
end

return doodle
