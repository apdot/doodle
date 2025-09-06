local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")

local M = {}
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

function M.find_notes()
    local ui = require("doodle")._ui

    local notes = DoodleNote.get_all(ui.db)
    local previewer = create_previewer(ui)

    pickers.new({ previewer = previewer }, {
        prompt_title = "Doodle Notes",
        finder = finders.new_table({
            results = notes,
            entry_maker = function(entry)
                return {
                    value = entry,
                    display = entry.title,
                    ordinal = entry.title
                }
            end
        }),
        sorter = conf.generic_sorter(),
        attach_mappings = function(prompt_bufnr, map)
            actions.select_default:replace(function()
                actions.close(prompt_bufnr)
                local selection = action_state.get_selected_entry()
                ui:open_note(selection.value.uuid, selection.value.title)
            end)
            return true
        end
    }):find()
end

return M
