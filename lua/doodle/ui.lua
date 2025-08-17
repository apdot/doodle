local DoodleBuffer = require("doodle.buffer")

local DoodleUI = {}
DoodleUI.__index = DoodleUI

function DoodleUI:new(settings)
    return setmetatable({
	win_id = nil,
	bufnr = nil,
	active_note = nil,
	setttings = settings
    }, self)
end

function DoodleUI:close()
    if self.bufnr ~= nil and vim.api.nvim_buf_is_valid(self.bufnr) then
        vim.api.nvim_buf_delete(self.bufnr, { force = true })
    end

    if self.win_id ~= nil and vim.api.nvim_win_is_valid(self.win_id) then
        vim.api.nvim_win_close(self.win_id, true)
    end

    self.active_list = nil
    self.win_id = nil
    self.bufnr = nil
end

function DoodleUI:get_ui_content()
   local body = DoodleBuffer:get_contents(self.bufnr)
   local length = #body
   return body, length
end

function DoodleUI:save()
    local body, length = self:get_ui_content()
    self.active_note:update(body, length)
end

function DoodleUI:create_window()
    local width = math.min(math.floor(vim.o.columns * 0.8), 64)
    local height = math.floor(vim.o.lines * 0.8)

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(bufnr, true, {
	relative = "editor",
	title = "Doodle",
	row = math.floor(((vim.o.lines - height) / 2) - 1),
	col = math.floor((vim.o.columns - width) / 2),
	title_pos = "center",
	width = width,
	height = height,
	style = "minimal",
	border = "single"
    })

    if win_id == 0 then
	self.bufnr = bufnr
	self:close()
	error("Failed to open note")
    end

    DoodleBuffer:setup(bufnr)

    self.win_id = win_id
    vim.api.nvim_set_option_value("number", true, {
	win = win_id,
    })

    return win_id, bufnr
end

function DoodleUI:toggle_view(note)
    if note == nil or self.win_id ~= nil then
	self:close()
	return
    end

    local win_id, bufnr = self:create_window()

    self.win_id = win_id
    self.bufnr = bufnr
    self.active_note = note

    local body = self.active_note:get_body() or {}
    vim.api.nvim_buf_set_lines(self.bufnr, 0, -1, false, body)
end

return DoodleUI
