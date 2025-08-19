local Path = require("plenary.path")
local Job = require("plenary.job")

local M = {}

local data_path = string.format("%s/doodle", vim.fn.stdpath("data"))
local path_exists = false

function M.create_data_path_if_not_exists()
    if path_exists then
	return
    end

    local path = Path:new(data_path)
    if not path:exists() then
	path:mkdir()
    end
    path_exists = true
end

---@field project string
---@return string
local function hash(str)
    return vim.fn.sha256(str)
end

---@field config DoodleConfig
---@return string
local function get_filename(str)
    return hash(str)
end

---@field config DoodleConfig
---@return string
local function get_fullpath(str)
    local filename = get_filename(str)
    return string.format("%s/%s", data_path, filename)
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

return M
