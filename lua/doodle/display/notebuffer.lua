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
---@return string
local function get_content(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 2, -1, false)
    return table.concat(lines, "\n")
end

---@param bufnr integer
function M.setup(bufnr)
    local ui = require("doodle")._ui

    if vim.api.nvim_buf_get_name(bufnr) == "" then
        vim.api.nvim_buf_set_name(bufnr, "__doodle_note__")
    end

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

    vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
        buffer = bufnr,
        callback = function()
            ui.blob.content = get_content(bufnr)
        end
    })
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        buffer = bufnr,
        callback = function()
            if ui.settings.auto_save then
                ui.blob.content = get_content(bufnr)
                ui.blob:save(ui.db)
            end
            ui.blob = nil
            vim.schedule(function()
                ui:toggle_note()
            end)
        end
    })

    vim.keymap.set("n", "-", function()
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "_", function()
        if #ui.breadcrumbs > 1 then
            ui.breadcrumbs = { ui.breadcrumbs[1] }
        end
        ui.root = nil
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<TAB>", function()
        local new_scope = clamp_scope(ui.current_scope + 1)
        ui.current_scope = new_scope
        ui:prepare_root()
        ui:load_current_directory()
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })
    --
    vim.keymap.set("n", "<S-TAB>", function()
        local new_scope = clamp_scope(ui.current_scope - 1)
        ui.current_scope = new_scope
        ui:prepare_root()
        ui:load_current_directory()
        ui:toggle_finder()
    end, { buffer = bufnr, silent = true })
end

return M
