local Parser = require("doodle.parser")
local DoodleBlob = require("doodle.blob")
local Help = require("doodle.display.help")

local M = {}

local ns = vim.api.nvim_create_namespace("doodle_hint")

local keymaps = {
    { key = "<CR>",      description = "Open note or enter directory" },
    { key = "-",         description = "Go up one directory" },
    { key = "_",         description = "Go to root directory" },
    { key = "<TAB>",     description = "Cycle scope forward" },
    { key = "<S-TAB>",   description = "Cycle scope backward" },
    { key = "q, <ESC>",  description = "Close doodle finder" },
    { key = "Edit & :w", description = "Rename, move, copy, or delete items" },
}

---@param scope integer
---@return integer
local function clamp_scope(scope)
    if scope < 1 then
        return 3
    elseif scope > 3 then
        return 1
    else
        return scope
    end
end

---@param bufnr integer
---@return DoodleFinderItem[]
local function get_content(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 2, -1, false)
    return Parser.parse_finder(lines)
end

---@return DoodleFinderItem
local function get_line()
    local line = vim.api.nvim_get_current_line()
    return Parser.parse_finder_line(line)
end

local function skip_concealed_id()
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local line = vim.api.nvim_get_current_line()

    local s, e = line:find("^@@@.-%s")
    if s and col <= e then
        vim.api.nvim_win_set_cursor(0, { row, e })
    end
end

---@param ui DoodleUI
local function process_finder(ui, bufnr)
    if ui.settings.auto_save then
        local parsed = get_content(bufnr)
        ui:update_finder(parsed)
    else
        ui:mark_all_processed()
    end
    ui:save()
end

---@param bufnr integer
function M.setup(bufnr)
    local ui = require("doodle")._ui

    if vim.api.nvim_buf_get_name(bufnr) == "" then
        vim.api.nvim_buf_set_name(bufnr, "__doodle_menu__")
    end

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

    vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
        buffer = bufnr,
        callback = function()
            local parsed = get_content(bufnr)
            ui:update_finder(parsed)
            ui:render_finder()
        end
    })

    vim.api.nvim_buf_call(bufnr, function()
        vim.cmd([[syntax match DoodleConcealID /^@@@.\{-}\s/ conceal]])
    end)

    -- this is causing race-conditions
    -- vim.api.nvim_create_autocmd({ "BufLeave" }, {
    --     buffer = bufnr,
    --     callback = function()
    --         if ui.settings.auto_save then
    --             local parsed = get_content(bufnr)
    --             ui:update_finder(parsed)
    --         end
    --         vim.schedule(function()
    --             print("bufleave finder close")
    --             ui:toggle_finder()
    --         end)
    --     end
    -- })

    vim.keymap.set("n", "<CR>", function()
        local parsed_line = get_line()
        if not parsed_line or parsed_line.id == nil then
            vim.notify("Save buffer required")
            return
        end
        local uuid = ui.idx_to_uuid[tonumber(parsed_line.id)]
        if parsed_line.directory then
            process_finder(ui, bufnr)
            vim.schedule(function()
                table.insert(ui.breadcrumbs, { uuid, parsed_line.directory })
                ui:load_current_directory()
                ui:render_finder()
            end)
        elseif parsed_line.note then
            print("toggle finder CR")
            ui:toggle_finder()
            vim.schedule(function()
                ui:open_note(uuid)
            end)
        end
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "-", function()
        process_finder(ui, bufnr)
        if #ui.breadcrumbs > 1 then
            table.remove(ui.breadcrumbs)
            ui:load_current_directory()
        end
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "_", function()
        process_finder(ui, bufnr)
        if #ui.breadcrumbs > 1 then
            ui.breadcrumbs = { ui.breadcrumbs[1] }
            ui:load_current_directory()
        end
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<TAB>", function()
        local new_scope = clamp_scope(ui.current_scope + 1)
        ui.current_scope = new_scope
        process_finder(ui, bufnr)
        ui:init()
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<S-TAB>", function()
        local new_scope = clamp_scope(ui.current_scope - 1)
        ui.current_scope = new_scope
        process_finder(ui, bufnr)
        ui:init()
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "q", function()
        process_finder(ui, bufnr)
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<ESC>", function()
        process_finder(ui, bufnr)
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "?", function()
        Help.show("Doodle Finder Shortcuts", keymaps)
    end, { buffer = bufnr, silent = true })

    vim.api.nvim_create_autocmd({ "QuitPre" }, {
        buffer = bufnr,
        callback = function()
            vim.schedule(function()
                ui:toggle_finder()
            end)
        end,
    })

    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
        group = vim.api.nvim_create_augroup("DoodleSkipIDs", { clear = true }),
        callback = skip_concealed_id,
    })

    if not ui.settings.hide_hint then
        vim.schedule(function()
            vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

            vim.api.nvim_buf_set_extmark(bufnr, ns, 0, -1, {
                virt_text = { { "Press ? for help", "Comment" } },
                virt_text_pos = "right_align",
            })
        end)
    end
end

return M
