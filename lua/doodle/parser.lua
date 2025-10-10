local FormatUtil = require("doodle.utils.format_util")
local Static = require("doodle.static")

local M = {}

---@param line string
---@return DoodleFinderItem
function M.parse_finder_line(line)
    line = FormatUtil.trim(line)
    local parsed_line = {}
    local type, id, rest = line:match("^@@@([DN])(%S*)(.*)$")
    if not type then
        rest = line
    end
    parsed_line.id = id

    rest = rest:gsub("(" .. Static.FILE .. ")%s", ""):gsub("(" .. Static.DIRECTORY .. ")%s+", "")

    local path = {}
    for part in rest:gmatch("[^/]+") do
        part = FormatUtil.trim(part)
        table.insert(path, part)
    end

    if type == "N" and #path > 1 then
        vim.notify("Can't convert note to directory", vim.log.levels.ERROR)
    end

    if type == "D" then
        parsed_line.directory = path[1]
        table.remove(path, 1)
    end
    if line:sub(-1) ~= "/" then
        if type == "N" then
            parsed_line.note = path[#path]
        else
            parsed_line.new_note = path[#path]
        end
        table.remove(path)
    end
    parsed_line.new_directories = path

    return parsed_line
end

---@param lines string[]
---@return DoodleFinderItem[]
function M.parse_finder(lines)
    local parsed = {}

    for _, line in pairs(lines) do
        local parsed_line = M.parse_finder_line(line)
        table.insert(parsed, parsed_line)
    end

    return parsed
end

return M
