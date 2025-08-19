local FileUtil = require("doodle.utils.fileutil")

local DoodleDisc = {}
DoodleDisc.__index = DoodleDisc

---@field data string
---@field config DoodleConfig
local function write_disc(data, filename, config)
    FileUtil.create_data_path_if_not_exists()

    local path = FileUtil.getPath(filename)
    local encoded_data = config.operations.encode(data)

    path:write(encoded_data, "w")
end

---@field config DoodleConfig
---@return string
local function read_disc(filename, config)
    FileUtil.create_data_path_if_not_exists()

    local path = FileUtil.getPath(filename)
    if not path:exists() then
	write_disc({}, filename, config)
    end

    local data = path:read()
    if not data or data == "" then
	write_disc({}, filename, config)
	data = "{}"
    end

    local decoded_data = config.operations.decode(data)
    return decoded_data
end

---@field config DoodleConfig
---@return DoodleDisc
function DoodleDisc:new(config)
    local ok1, data = pcall(read_disc, config.settings.project(), config)
    local ok2, global_data = pcall(read_disc, config.settings.global(), config)
    return setmetatable({
	config = config,
	failed = not (ok1 and ok2),
	data = data,
	global = global_data
    }, self)
end

---@param project string
---@return string[]
function DoodleDisc:fetch_global(project)
    if self.failed then
	error("Error occurred while fetching Doodle data")
    end

    if not self.global[project] then
	self.global[project] = {}
    end

    return self.global[project][project] or {}
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
    pcall(write_disc, self.data, self.config.settings.project(), self.config)
    pcall(write_disc, self.global, self.config.settings.global(), self.config)
end

function DoodleDisc:update(project, branch, note)
    if not self.data[project] then
	self.data[project] = {}
    end

    self.data[project][branch] = note.body
end

function DoodleDisc:update_global(project, note)
    if not self.global[project] then
	self.global[project] = {}
    end

    self.global[project][project] = note.body
end

return DoodleDisc
