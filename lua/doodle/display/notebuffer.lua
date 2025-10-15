local Present = require("doodle.display.present")
local Note = require("doodle.note")
local Help = require("doodle.display.help")
local LinkUtil = require("doodle.utils.link_util")
local DBUtil = require("doodle.utils.db_util")
local TagUtil = require("doodle.utils.tag_util")
local FormatUtil = require("doodle.utils.format_util")
local DoodleNote = require("doodle.note")

local M = {}

local ns = vim.api.nvim_create_namespace("doodle_hint")

local keymaps = {
    { key = ":w",         description = "Save Note" },
    { key = "<CR>",       description = "Open link under cursor or search notes for tag" },
    { key = "-",          description = "Open finder at note location" },
    { key = "<C-x><C-o>", description = "Auto-complete tags" },
}

---@param bufnr integer
---@param blob DoodleBlob
---@param path string[]
function M.setup(bufnr, blob, path)
    local ui = require("doodle")._ui

    if vim.api.nvim_buf_get_name(bufnr) == "" then
        local bufname = table.concat(path, "/") .. ".doodle"
        local ok = pcall(vim.api.nvim_buf_set_name, bufnr, bufname)
        if not ok then
            local suffix = blob.uuid or DBUtil.now()
            bufname = bufname .. ":" .. suffix
            pcall(vim.api.nvim_buf_set_name, bufnr, bufname)
        end
    end

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

    vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
        buffer = bufnr,
        callback = function(args)
            TagUtil.update_tags(args.buf, blob, ui.db)
            blob.content = FormatUtil.get_content(args.buf)
            blob:save(ui.db)
            vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
        end
    })

    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

    vim.cmd([[
    syntax match TagHighlight /\%3lTags:\zs.*#\S\+/
    ]])
    vim.cmd("highlight default link TagHighlight Special")

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        buffer = bufnr,
        callback = function(args)
            local is_modified = vim.api.nvim_get_option_value("modified", { buf = args.buf })
            if ui.settings.auto_save and is_modified then
                vim.api.nvim_buf_call(args.buf, function()
                    blob.content = FormatUtil.get_content(args.buf)
                    blob:save(ui.db)
                    vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
                end)
            end
        end
    })

    vim.bo[bufnr].omnifunc = "v:lua.doodle.completion.complete_tags"

    vim.api.nvim_create_autocmd({ "BufUnload" }, {
        buffer = bufnr,
        callback = function()
            ui:close_note(bufnr)
        end
    })

    vim.keymap.set("n", "-", function()
        ui:save()
        local note = Note.get(blob.note_id, ui.db)
        ui.breadcrumbs = Present.create_breadcrumbs(vim.split(note.path, "/"),
            vim.split(note.path_ids, "/"))
        ui.current_scope = note:get_scope(ui.settings)
        ui:load_current_directory()
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "?", function()
        Help.show("Doodle Note Shortcuts", keymaps)
    end, { buffer = bufnr, silent = true })

    if not ui.settings.hide_hint then
        vim.schedule(function()
            vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

            vim.api.nvim_buf_set_extmark(bufnr, ns, 0, -1, {
                virt_text = { { "Press ? for help", "Comment" } },
                virt_text_pos = "right_align",
            })
        end)
    end

    vim.keymap.set("n", "<CR>", function()
        local cursor = vim.api.nvim_win_get_cursor(0)
        local line_num = cursor[1]
        local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ""
        if line_num == 3 and line:match("^Tags:") then
            local tag_found_at_cursor = TagUtil.go_to_tag(bufnr)
            if tag_found_at_cursor then return end
        end
        LinkUtil.go_to_link()
    end, { buffer = bufnr, silent = true })

    -- vim.keymap.set("n", "_", function()
    --     if #ui.breadcrumbs > 1 then
    --         ui.breadcrumbs = { ui.breadcrumbs[1] }
    --     end
    --     ui.root = nil
    --     ui:toggle_finder()
    -- end, { buffer = bufnr, silent = true })
    --
    -- vim.keymap.set("n", "<TAB>", function()
    --     local new_scope = clamp_scope(ui.current_scope + 1)
    --     ui.current_scope = new_scope
    --     ui:prepare_root()
    --     ui:load_current_directory()
    --     ui:toggle_finder()
    -- end, { buffer = bufnr, silent = true })
    -- --
    -- vim.keymap.set("n", "<S-TAB>", function()
    --     local new_scope = clamp_scope(ui.current_scope - 1)
    --     ui.current_scope = new_scope
    --     ui:prepare_root()
    --     ui:load_current_directory()
    --     ui:toggle_finder()
    -- end, { buffer = bufnr, silent = true })
end

return M
