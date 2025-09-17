local M = {}

--- @param title string
--- @param keymaps table
function M.show(title, keymaps)
    local body_lines = {}
    local max_key_width = 0
    for _, map in ipairs(keymaps) do
        if vim.fn.strwidth(map.key) > max_key_width then
            max_key_width = vim.fn.strwidth(map.key)
        end
    end

    local max_body_width = 0
    table.insert(body_lines, " ")
    for _, map in ipairs(keymaps) do
        local key_part = string.format("%-" .. (max_key_width + 2) .. "s", map.key)
        local line = string.format("   %s: %s", key_part, map.description)
        table.insert(body_lines, line)
        if vim.fn.strwidth(line) > max_body_width then
            max_body_width = vim.fn.strwidth(line)
        end
    end

    local win_width = math.max(max_body_width, vim.fn.strwidth(title)) + 4

    local title_padding_size = math.floor((win_width - vim.fn.strwidth(title)) / 2)
    local title_padding = string.rep(" ", title_padding_size)
    local header_lines = {
        title_padding .. title,
        title_padding .. string.rep("─", vim.fn.strwidth(title)),
    }

    local all_lines = {}
    for _, line in ipairs(header_lines) do table.insert(all_lines, line) end
    for _, line in ipairs(body_lines) do table.insert(all_lines, line) end

    local win_height = #all_lines + 2
    local screen_width = vim.o.columns
    local screen_height = vim.o.lines
    local win_col = math.floor((screen_width - win_width) / 2)
    local win_row = math.floor((screen_height - win_height) / 2)

    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, all_lines)

    local win = vim.api.nvim_open_win(buf, true, {
        relative = "editor",
        width = win_width,
        height = win_height,
        col = win_col,
        row = win_row,
        style = "minimal",
        border = "rounded",
    })

    vim.api.nvim_buf_set_keymap(buf, "n", "q", "<Cmd>q<CR>", { noremap = true, silent = true })
    vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "<Cmd>q<CR>", { noremap = true, silent = true })
end

return M
