local DoodleBuffer = require("doodle.buffer")

local scopes = { "Project", "Branch", "Global" }
local scope_marks = { "P", "B", "G" }
local ns

local DoodleUI = {}
DoodleUI.__index = DoodleUI

function DoodleUI:new(settings)
    return setmetatable({
	win_id = nil,
	bufnr = nil,
	active_note = nil,
	branch_note = nil,
	global_note = nil,
	current_scope = 1,
	settings = settings
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
    return DoodleBuffer:get_contents(self.bufnr, ns)
end

function DoodleUI:get_current_note()
    if self.current_scope == 1 then
	return self.active_note
    elseif self.current_scope == 2 then
	return self.branch_note
    else
	return self.global_note
    end
end

function DoodleUI:save()
    local p, b, g, unmarked = self:get_ui_content()

    local current_note = self:get_current_note()
    current_note:update(unmarked)

    self.active_note:append(p)
    self.global_note:append(g)
    if self.branch_note then
	self.branch_note:append(b)
    end
end

function DoodleUI:create_window()
    local width = math.min(math.floor(vim.o.columns * 0.8), 64)
    local height = math.floor(vim.o.lines * 0.8)

    ns = vim.api.nvim_create_namespace("doodle_ns")

    local bufnr = vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(bufnr, true, {
	relative = "editor",
	-- title = "Doodle",
	-- title_pos = "right",
	row = math.floor(((vim.o.lines - height) / 2) - 1),
	col = math.floor((vim.o.columns - width) / 2),
	width = width,
	height = height,
	style = "minimal",
	border = "solid",
	footer = "doodle",
	footer_pos = "right"

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

local function render_scope_line(bufnr, current_scope)
    local virt_text = {}
    for i, scope in ipairs(scopes) do
	if i == current_scope then
	    table.insert(virt_text, { " " .. scope .. " ", "Keyword" })  -- active
	else
	    table.insert(virt_text, { " " .. scope .. " ", "Comment" })  -- inactive
	end

	if i < #scopes then
	    table.insert(virt_text, { "|", "Comment" })
	end
    end

    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
	virt_text = virt_text,
	virt_text_pos = "overlay",
    })
end

local function draw_virtual_hline(bufnr, win, lnum)
    local width = vim.api.nvim_win_get_width(win)
    local line = string.rep("─", width)
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
	virt_text = {{line, "Comment"}},
	virt_text_pos = "overlay",
    })
end

local function render_body(bufnr, win_id, note)
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    local body = note and note:display(bufnr, win_id) or {"", "<Git repository not found>"}
    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, body)
end

function DoodleUI:render()
    local note = self:get_current_note()
    render_body(self.bufnr, self.win_id, note)
    render_scope_line(self.bufnr, self.current_scope)
    draw_virtual_hline(self.bufnr, self.win_id, 1)
    if not note then
	vim.api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
    end
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
    self.global_note = note.global_note
    self.branch_note = note.branch_note

    self:render()
end

local function mark_scope(bufnr, current_scope, scope_idx, start_row, end_row)
    if scope_idx ~= current_scope then
	local mark = scope_marks[scope_idx]
	for i=start_row, end_row do
	    vim.api.nvim_buf_set_extmark(bufnr, ns, i-1, 0, {
		sign_text = mark,
		sign_hl_group = scope_idx == 1 and "Keyword" or scope_idx == 2 and "Identifier" or "Type",
	    })
	end
    end
end

local function get_start_and_end_row()
    local mode = vim.api.nvim_get_mode()["mode"]
    local start_row
    local end_row

    if mode == "V" then
	start_row = vim.fn.getpos("v")[2]
	end_row = vim.fn.getpos(".")[2]
    else
	start_row = vim.api.nvim_win_get_cursor(0)[1]
	end_row = start_row
    end

    return start_row, end_row
end

function DoodleUI:pin_project()
    if self.active_note == nil or self.win_id == nil or self.bufnr == nil then
	return
    end

    local start_row, end_row = get_start_and_end_row()
    mark_scope(self.bufnr, self.current_scope, 1, start_row, end_row)
end

function DoodleUI:pin_branch()
    if self.active_note == nil or self.win_id == nil or self.bufnr == nil then
	return
    end

    local start_row, end_row = get_start_and_end_row()
    mark_scope(self.bufnr, self.current_scope, 2, start_row, end_row)
end

function DoodleUI:pin_global()
    if self.active_note == nil or self.win_id == nil or self.bufnr == nil then
	return
    end

    local start_row, end_row = get_start_and_end_row()
    mark_scope(self.bufnr, self.current_scope, 3, start_row, end_row)
end

return DoodleUI
