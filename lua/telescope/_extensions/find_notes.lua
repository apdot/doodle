local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")

local preview_cache = {}

---@param ui DoodleUI
local function create_previewer(ui)
    return previewers.new_buffer_previewer({
        title = "Note Content",
        define_preview = function(self, entry, status)
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
    return entry.path .. "/" .. entry.title
end

local function generate_finder(notes)
    return finders.new_table({
        results = notes,
        entry_maker = function(entry)
            local display_text = make_display(entry)
            return {
                value = entry,
                display = display_text,
                ordinal = display_text
            }
        end
    })
end

local function find_notes(opts)
    opts = opts or {}
    local ui = require("doodle")._ui
    if not ui.root then
        ui:prepare_root()
        ui:load_current_directory()
    end

    local where = { status = "<" .. 2 }
    if opts.scope == "Project" then
        where["project"] = ui.root
    elseif opts.scope == "Branch" then
        where["project"] = ui.root
        where["branch"] = ui.settings.branch()
    elseif opts.scope == "Global" then
        where["project"] = ui.settings.global()
    end

    local notes = DoodleNote.get_all(ui.db, where)
    local previewer = create_previewer(ui)
    local scope_name;
    if opts.scope ~= nil and opts.scope ~= "all" then
        scope_name = ("[%s]"):format(opts.scope)
    end
    pickers.new({ previewer = previewer }, {
        prompt_title = "Doodle Notes" .. (scope_name or ""),
        finder = generate_finder(notes),
        sorter = conf.generic_sorter(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                ui:open_note(selection.value.uuid, selection.value.title)
            end)

            local function switch_scope(scope)
                actions.close(prompt_bufnr)
                find_notes({ scope = scope })
            end

            map("i", "<C-e>", function() switch_scope("all") end)
            map("i", "<C-p>", function() switch_scope("Project") end)
            map("i", "<C-b>", function() switch_scope("Branch") end)
            map("i", "<C-g>", function() switch_scope("Global") end)
            return true
        end
    }):find()
end

return find_notes
