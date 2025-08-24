local FinderBuffer = require("doodle.display.finderbuffer")
local View = {}

local scopes = { "Project", "Branch", "Global" }
local scope_marks = { "P", "B", "G" }
local ns = vim.api.nvim_create_namespace("doodle_ns")

function View.close(bufnr, win_id)
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
	vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
	vim.api.nvim_win_close(win_id, true)
    end
end

function View.create_window()
    local width = math.min(math.floor(vim.o.columns * 0.8), 64)
    local height = math.floor(vim.o.lines * 0.8)

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
	View.close()
	error("Failed to open note")
	return { bufnr }
    end

    vim.api.nvim_set_option_value("number", true, {
	win = win_id,
    })
    vim.api.nvim_set_option_value("concealcursor", "nivc", { win = win_id })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win_id })

    return bufnr, win_id
end

local function render_content(bufnr, content)
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    -- local body = note and note:display(bufnr, win_id) or {"", "<Git repository not found>"}
    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, content)
end

local function draw_virtual_hline(bufnr, win, lnum)
    local width = vim.api.nvim_win_get_width(win)
    local line = string.rep("─", width)
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
	virt_text = {{line, "Comment"}},
	virt_text_pos = "overlay",
    })
end

local function render_scope_line(bufnr, win_id, current_scope)
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

    draw_virtual_hline(bufnr, win_id, 1)
end

function View.render(bufnr, win_id, content, scope)
    render_content(bufnr, content)
    render_scope_line(bufnr, win_id, scope)
	--    if not note then
	-- vim.api.nvim_set_option_value("modifiable", false, { buf = self.bufnr })
	--    end
end

return View
