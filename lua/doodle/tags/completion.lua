local Tags = require("doodle.tags.tag")

local M = {}

---@param findstart 0 | 1
---@param base string
---@return integer | string[]
function M.complete_tags(findstart, base)
    if findstart == 1 then
        -- wants to know the completion start
        local line = vim.api.nvim_get_current_line()
        local cursor_col = vim.api.nvim_win_get_cursor(0)[2]
        -- look backwards from the cursor for the '#' that starts a tag
        local start_col = line:sub(1, cursor_col):find("#%S+$")
        print("complete_tags", start_col)
        return start_col and start_col or -1
    else
        -- wants to know the list of matching words
        local ui = require("doodle")._ui
        print("base", base)
        if base and #base > 0 then
            return Tags.search(base, ui.db)
        end
        return {}
    end
end

return M
