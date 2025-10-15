local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local Help = require("doodle.display.help")
local Link = require("doodle.link")
local Static = require("doodle.static")

local preview_cache = {}

local help_keymaps = {
    { key = "<CR>",  description = "Open selected note" },
    { key = "<C-p>", description = "Switch scope to Project" },
    { key = "<C-b>", description = "Switch scope to Branch" },
    { key = "<C-g>", description = "Switch scope to Global" },
    { key = "<C-e>", description = "Switch scope to All" },
    { key = "<C-f>", description = "Switch to find files" },
    { key = "<C-y>", description = "Switch to find templates" },
    { key = "<C-l>", description = "Add link to the selected note" }
}

local find_notes
local find_files
local find_templates

local function map_scope_switches(map, prompt_bufnr, opts)
    local function switch_scope(scope)
        actions.close(prompt_bufnr)
        local new_opts = vim.tbl_deep_extend("force", opts or {}, { scope = scope })
        find_notes(new_opts)
    end

    map({ "i", "n" }, "<C-p>", function() switch_scope("Project") end)
    map({ "i", "n" }, "<C-b>", function() switch_scope("Branch") end)
    map({ "i", "n" }, "<C-g>", function() switch_scope("Global") end)
    map({ "i", "n" }, "<C-e>", function() switch_scope("all") end)
end

---@param ui DoodleUI
local function create_previewer(ui)
    return previewers.new_buffer_previewer({
        title = "Note Content",
        define_preview = function(self, entry)
            local content

            local note_id = entry.value.uuid
            if preview_cache[note_id] then
                content = preview_cache[note_id]
            else
                content = DoodleBlob.get(entry.value.uuid, ui.db).content
                preview_cache[note_id] = content
            end

            if not content or content == "" then
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
                return
            end

            local lines = vim.split(content, "\n")

            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
    })
end

local function make_display(entry)
    return Static.FILE .. " " .. entry.path .. "/" .. entry.title
end

local function make_ordinal(entry)
    local tags = entry.tags or ""
    return tags .. make_display(entry)
end

local function generate_finder(notes)
    return finders.new_table({
        results = notes,
        entry_maker = function(entry)
            return {
                value = entry,
                display = make_display(entry),
                ordinal = make_ordinal(entry)
            }
        end
    })
end

---@param display_text string
---@param path string
---@param to_note boolean
local function add_link(display_text, path, to_note)
    local ui = require("doodle")._ui

    local link_text = ("[%s](%s)"):format(display_text, path)
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_buf_set_text(0, pos[1] - 1, pos[2], pos[1] - 1, pos[2], { link_text })

    local bufnr = vim.api.nvim_get_current_buf()
    local note_info = ui.open_notes and ui.open_notes[bufnr]
    if note_info and note_info.id then
        Link.create({
            src = note_info.id,
            dest = path,
            link_str = link_text,
            to_note = to_note
        }, ui.db)
    end
end

find_files = function(opts)
    require("telescope.builtin").find_files({
        attach_mappings = function(ff_prompt_bufnr, ff_map)
            map_scope_switches(ff_map, ff_prompt_bufnr, opts)
            ff_map({ "i", "n" }, "<C-l>", function()
                actions.close(ff_prompt_bufnr)
                local selection = action_state.get_selected_entry()
                if not selection then return end
                vim.schedule(function()
                    add_link(vim.fn.fnamemodify(selection.value, ":t"), selection.value, false)
                end)
            end)
            ff_map({ "i", "n" }, "<C-y>", function()
                actions.close(ff_prompt_bufnr)
                vim.schedule(function()
                    find_templates(opts)
                end)
            end)
            return true
        end
    })
end

find_templates = function(opts)
    opts = opts or {}
    local ui = require("doodle")._ui

    local template_notes = DoodleNote.get_templates(ui.db)

    local previewer = create_previewer(ui)
    opts.previewer = opts.previewer or previewer

    pickers.new(opts, {
        prompt_title = "Doodle Templates",
        finder = generate_finder(template_notes),
        sorter = conf.generic_sorter(),
        attach_mappings = function(ft_prompt_bufnr, ft_map)
            map_scope_switches(ft_map, ft_prompt_bufnr, opts)
            actions.select_default:replace(function()
                actions.close(ft_prompt_bufnr)
                local selection = action_state.get_selected_entry()
                local blob = DoodleBlob.get(selection.value.uuid, ui.db)
                local content = vim.split(blob.content, "\n", { plain = true }) or {}
                local pos = vim.api.nvim_win_get_cursor(0)
                vim.api.nvim_buf_set_text(0, pos[1] - 1, pos[2], pos[1] - 1, pos[2], content)
            end)
            ft_map({ "i", "n" }, "<C-f>", function()
                actions.close(ft_prompt_bufnr)
                vim.schedule(function()
                    find_files(opts)
                end)
            end)
            return true
        end,
    }):find()
end

find_notes = function(opts)
    opts = opts or {}
    local ui = require("doodle")._ui

    if not ui.root then
        ui:init()
    end

    local where = {}
    if opts.scope == "Project" then
        where["project"] = ui.root
    elseif opts.scope == "Branch" then
        where["project"] = ui.root
        where["branch"] = ui.settings.branch()
    elseif opts.scope == "Global" then
        where["project"] = ui.settings.global()
    end

    local notes = DoodleNote.get_all_with_tags(ui.db, where)

    local previewer = create_previewer(ui)
    local scope_name;
    if opts.scope ~= nil and opts.scope ~= "all" then
        scope_name = ("[%s]"):format(opts.scope)
    end

    opts.previewer = opts.previewer or previewer
    pickers.new(opts, {
        prompt_title = "Doodle Notes" .. (scope_name or ""),
        finder = generate_finder(notes),
        sorter = conf.generic_sorter(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                ui:open_note(selection.value.uuid)
            end)

            map_scope_switches(map, prompt_bufnr, opts)
            map({ "i", "n" }, "?", function()
                Help.show("Doodle Picker Shortcuts", help_keymaps)
            end)
            map({ "i", "n" }, "<C-l>", function()
                local selection = action_state.get_selected_entry()
                if not selection then
                    return
                end
                actions.close(prompt_bufnr)
                vim.schedule(function()
                    add_link(selection.value.title, selection.value.uuid, true)
                end)
            end)
            map({ "i", "n" }, "<C-f>", function()
                actions.close(prompt_bufnr)
                vim.schedule(function()
                    find_files(opts)
                end)
            end)
            map({ "i", "n" }, "<C-y>", function()
                actions.close(prompt_bufnr)
                vim.schedule(function()
                    find_templates(opts)
                end)
            end)
            return true
        end
    }):find()
end

return {
    find_notes = find_notes,
    find_files = find_files,
    find_templates = find_templates
}
