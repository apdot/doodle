local M = {}

function M.go_to_link()
    local ui = require("doodle")._ui

    local line = vim.api.nvim_get_current_line()
    local col = vim.api.nvim_win_get_cursor(0)[2]

    local link_found = false
    for text, dest in string.gmatch(line, "%[([^]]+)]%(([^)]+)%)") do
        local link_text = string.format("[%s](%s)", text, dest)
        local start_idx, end_idx = string.find(line, link_text, 1, true)

        if start_idx and col >= start_idx - 1 and col < end_idx then
            if dest:find("[/\\.]") then
                local file_path, line_num_str = dest:match("^([^:]+):?(%d*)$")
                file_path = file_path or dest

                vim.cmd("edit " .. vim.fn.fnameescape(file_path))

                local line_num = tonumber(line_num_str)
                if line_num and line_num > 0 then
                    vim.api.nvim_win_set_cursor(0, { line_num, 0 })
                else
                    vim.api.nvim_win_set_cursor(0, { 1, 0 })
                end
            else
                ui:open_note(dest)
            end

            link_found = true
            break
        end
    end
    if not link_found then
        vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), 'n', false)
    end
end

return M
