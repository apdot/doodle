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
---@param blob DoodleBlob
---@param path string[]
function M.setup(bufnr, blob, path)
    local ui = require("doodle")._ui

    if vim.api.nvim_buf_get_name(bufnr) == "" then
        vim.api.nvim_buf_set_name(bufnr, table.concat(path, "/") .. ".doodle")
    end

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

    vim.api.nvim_create_autocmd({ "BufWriteCmd" }, {
        buffer = bufnr,
        callback = function(args)
            blob.content = get_content(args.buf)
            print("content in save", blob.content)
            blob:save(ui.db)
            vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
        end
    })

    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        buffer = bufnr,
        callback = function(args)
            local is_modified = vim.api.nvim_get_option_value("modified", { buf = args.buf })
            if ui.settings.auto_save and is_modified then
                vim.api.nvim_buf_call(args.buf, function()
                    blob.content = get_content(args.buf)
                    blob:save(ui.db)
                    vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
                end)
            end
        end
    })

    -- vim.api.nvim_create_autocmd({ "BufUnload" }, {
    --     buffer = bufnr,
    --     callback = function()
    --         print("bufdelete closing note")
    --         vim.schedule(function()
    --             ui:close_note(bufnr)
    --         end)
    --     end
    -- })
    --
    -- vim.keymap.set("n", "-", function()
    --     ui:toggle_finder()
    -- end, { buffer = bufnr, silent = true })
    --
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
