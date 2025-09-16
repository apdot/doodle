local Present = require("doodle.display.present")
local NoteTag = require("doodle.tags.note_tag")

local M = {}

---@param bufnr integer
---@param blob DoodleBlob
---@param path string[]
---@param db DoodleDB
local function update_tags(bufnr, blob, path, db)
    local tag_line = vim.api.nvim_buf_get_lines(bufnr, 2, 3, false)[1] or ""
    local tags = Present.get_tags(tag_line)
    print("tags i got for present")
    for k, v in pairs(tags) do

        print(k, v)
    end
    NoteTag.clear(blob.note_id, db)
    NoteTag.bulk_map(tags, { blob.note_id }, db)
end

---@param bufnr integer
---@return string
local function get_content(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 3, -1, false)
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
            update_tags(args.buf, blob, path, ui.db)
            blob.content = get_content(args.buf)
            print("content in save", blob.content)
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
                    blob.content = get_content(args.buf)
                    blob:save(ui.db)
                    vim.api.nvim_set_option_value("modified", false, { buf = args.buf })
                end)
            end
        end
    })

    vim.bo[bufnr].omnifunc = "v:lua.doodle.completion.complete_tags"

    vim.keymap.set("i", "<C-l>", "<C-x><C-o>", {
        buffer = bufnr,
        remap = true,
        silent = true
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
