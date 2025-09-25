local NoteTag = require("doodle.tags.note_tag")
local Present = require("doodle.display.present")

local M = {}

---@param bufnr integer
---@param blob DoodleBlob
---@param db DoodleDB
function M.update_tags(bufnr, blob, db)
    local tag_line = vim.api.nvim_buf_get_lines(bufnr, 2, 3, false)[1] or ""
    local tags = Present.get_tags(tag_line)
    NoteTag.clear(blob.note_id, db)
    NoteTag.bulk_map(tags, { blob.note_id }, db)
end

---@param bufnr integer
---@return boolean
function M.go_to_tag(bufnr)
    local cursor = vim.api.nvim_win_get_cursor(0)
    local line_num = cursor[1]
    local col = cursor[2]
    local line = vim.api.nvim_buf_get_lines(bufnr, line_num - 1, line_num, false)[1] or ""
    for tag in line:gmatch("#(%S+)") do
        local tag_pattern = "#" .. tag
        local start_idx, end_idx = line:find(tag_pattern, 1, true)
        if start_idx and col >= start_idx - 1 and col < end_idx then
            require('telescope').extensions.doodle.find_notes({
                default_text = tag_pattern
            })
            return true
        end
    end
            return false
end

return M
