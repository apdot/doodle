local M = {}

function M.trim(str)
    return str:gsub("^%s+", ""):gsub("%s+$", "")
end

return M
