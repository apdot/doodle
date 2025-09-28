local M = {}

function M.trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

---@param timestamp integer
---@return string
function M.get_date_time(timestamp)
    local date_time

    if type(timestamp) == "number" then
        date_time = os.date("%Y-%m-%d %H:%M", timestamp)
    else
        date_time = "NA"
    end

    return date_time
end

---@param timestamp integer
---@return string
function M.get_date(timestamp)
    local date

    if type(timestamp) == "number" then
        date = os.date("%Y-%m-%d", timestamp)
    else
        date = "NA"
    end

    return date
end

---@param items DoodleNote[] | DoodleDirectory[]
---@return DoodleNote[] | DoodleDirectory[]
function M.sort_note_or_directories(items)
    table.sort(items, function(a, b)
        local a_name = a.title or a.name
        local b_name = b.title or b.name
        return a_name < b_name
    end)

    return items
end

---@param bufnr integer
---@return string
function M.get_content(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 3, -1, false)
    return table.concat(lines, "\n")
end

return M
