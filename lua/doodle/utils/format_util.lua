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

return M
