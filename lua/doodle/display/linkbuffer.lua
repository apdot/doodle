local LinkUtil = require("doodle.utils.link_util")

local M = {}

function M.setup_left(bufnr)
    local ui = require("doodle")._ui

    vim.keymap.set("n", "<CR>", function()
        print("left CR")
        local line_number = vim.api.nvim_win_get_cursor(0)[1]
        ui.link_idx = line_number - 2
        ui:render_links_refresh()
    end, { buffer = bufnr, silent = true })
end

---@param bufnr integer
function M.setup_right(bufnr)
    vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

    vim.keymap.set("n", "<CR>", function()
        LinkUtil.go_to_link()
    end, { buffer = bufnr, silent = true })
end

return M
