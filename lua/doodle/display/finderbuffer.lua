local Parser = require("doodle.parser")
local DoodleBlob = require("doodle.blob")

local M = {}

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
        if not parsed_line or parsed_line.uuid == nil then
            vim.notify("Save buffer required")
            return
        end
        if parsed_line.directory then
            if ui.settings.auto_save then
                local parsed = get_content(bufnr)
                ui:update_finder(parsed)
            end
            ui:save()
            vim.schedule(function()
                table.insert(ui.breadcrumbs, { parsed_line.uuid, parsed_line.directory })
                ui:load_current_directory()
                ui:render_finder()
            end)
        elseif parsed_line.note then
            print("toggle finder CR")
            ui:toggle_finder()
            vim.schedule(function()
                ui:open_note(parsed_line.uuid, parsed_line.note)
            end)
        end
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "-", function()
        if ui.settings.auto_save then
            local parsed = get_content(bufnr)
            ui:update_finder(parsed)
        end
        if #ui.breadcrumbs > 1 then
            ui:save()
            table.remove(ui.breadcrumbs)
            ui:load_current_directory()
        end
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "_", function()
        if ui.settings.auto_save then
            local parsed = get_content(bufnr)
            ui:update_finder(parsed)
        end
        if #ui.breadcrumbs > 1 then
            ui:save()
            ui.breadcrumbs = { ui.breadcrumbs[1] }
            ui:load_current_directory()
        end
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<TAB>", function()
        local new_scope = clamp_scope(ui.current_scope + 1)
        ui.current_scope = new_scope
        if ui.settings.auto_save then
            local parsed = get_content(bufnr)
            ui:update_finder(parsed)
            ui:save()
        end
        ui:prepare_root()
        ui:load_current_directory()
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<S-TAB>", function()
        local new_scope = clamp_scope(ui.current_scope - 1)
        ui.current_scope = new_scope
        if ui.settings.auto_save then
            local parsed = get_content(bufnr)
            ui:update_finder(parsed)
            ui:save()
        end
        ui:prepare_root()
        ui:load_current_directory()
        ui:render_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "q", function()
        ui:toggle_finder()
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
end

return M
