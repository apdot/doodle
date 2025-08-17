local Path = require("plenary.path")

local data_path = string.format("%s/doodle", vim.fn.stdpath("data"))
local path_exists = false

local DoodleDisc = {}
DoodleDisc.__index = DoodleDisc

local function create_data_path_if_not_exists()
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
local function hash(project)
    return vim.fn.sha256(project)
end

---@field config DoodleConfig
---@return string
local function get_filename(config)
    return hash(config.settings.project())
end

---@field config DoodleConfig
---@return string
local function get_fullpath(config)
    local filename = get_filename(config)
    return string.format("%s/%s", data_path, filename)
end

---@field data string
---@field config DoodleConfig
local function write_disc(data, config)
    create_data_path_if_not_exists()

    local fullpath = get_fullpath(config)
    local path = Path:new(fullpath)
    local encoded_data = config.operations.encode(data)

    path:write(encoded_data, "w")
end

---@field config DoodleConfig
---@return string
local function read_disc(config)
    create_data_path_if_not_exists()

    local fullpath = get_fullpath(config)
    local path = Path:new(fullpath)
    if not path:exists() then
	write_disc({}, config)
    end

    local data = path:read()
    if not data or data == "" then
	write_disc({}, config)
	data = "{}"
    end

    local decoded_data = config.operations.decode(data)
    return decoded_data
end

---@param project string
---@param branch string
---@return string[]
function DoodleDisc:fetch_note(project, branch)
    if self.failed then
	error("Error occurred while fetching Doodle data")
    end

    if not self.data[project] then
	self.data[project] = {}
    end

    return self.data[project][branch] or {}
end

function DoodleDisc:sync()
   pcall(write_disc, self.data, self.config)
end

function DoodleDisc:update(project, branch, note)
    if not self.data[project] then
	self.data[project] = {}
    end

    self.data[project][branch] = note.body
end

---@field config DoodleConfig
---@return DoodleDisc
function DoodleDisc:new(config)
    local ok, data = pcall(read_disc, config)
    return setmetatable({
	config = config,
	failed = not ok,
	data = data
    }, self)
end

return DoodleDisc
