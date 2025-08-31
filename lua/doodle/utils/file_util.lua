local Path = require("plenary.path")
local Job = require("plenary.job")
local With = require("plenary.context_manager").with
local Open = require("plenary.context_manager").open

local M = {}

M.data_path = string.format("%s/doodle", vim.fn.stdpath("data"))
local path_exists = false

function M.create_data_path_if_not_exists()
    if path_exists then
        return
    end

    local path = Path:new(M.data_path)
    if not path:exists() then
        path:mkdir()
    end
    path_exists = true
end

---@param str string
---@return string
local function hash(str)
    return vim.fn.sha256(str)
end

---@param str string
---@return string
local function get_filename(str)
    return hash(str)
end

---@param str string
---@return string
local function get_fullpath(str)
    local filename = get_filename(str)
    return string.format("%s/%s", M.data_path, filename)
end

function M.getPath(str)
    local fullpath = get_fullpath(str)
    return Path:new(fullpath)
end

function M.get_git_branch()
    return Job:new({
        command = "git",
        args = { "rev-parse", "--abbrev-ref", "HEAD" },
    }):sync()[1]
end

---@param path Path
---@param bytes integer
---@return boolean
---@return string
function M.seek(path, bytes)
    local data_str
    local ok, err = pcall(function()
        data_str = With(Open(path, "r"), function(reader)
            reader:seek("set", bytes)
            return reader:read("*a")
        end)
    end)

    return ok, data_str
end

---@param files_in_repo string[]
---@return string?
---@return number?
function M.find_snapshot(files_in_repo)
    local snapshot
    local max_timestamp = tonumber(0)
    for _, filename in ipairs(files_in_repo) do
        local timestamp_str = filename:match("/SNAPSHOT%-(%d+)")
        if timestamp_str then
            local timestamp = tonumber(timestamp_str)
            if timestamp > max_timestamp then
                max_timestamp = timestamp
                snapshot = filename
            end
        end
    end

    return snapshot, max_timestamp
end

return M
