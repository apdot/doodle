local FormatUtil = require("doodle.utils.formatutil")

local DoodleBuffer = {}
DoodleBuffer.__index = DoodleBuffer

function DoodleBuffer:get_contents(bufnr, ns)
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns, 2, -1, { details = true })

  local p, b, g, unmarked = {}, {}, {}, {}
  local mark_lookup = {}
  for _, m in pairs(marks) do
    local row, details = m[2], m[4]
    local scope = details.sign_text
    if scope then
	mark_lookup[row - 1] = FormatUtil.trim(scope)
    end
  end

  local all_lines = vim.api.nvim_buf_get_lines(bufnr, 2, -1, false)
  for row, line in pairs(all_lines) do
    local mark_text = mark_lookup[row]
    if mark_text == "G" then
      table.insert(g, line)
    elseif mark_text == "B" then
      table.insert(b, line)
    elseif mark_text == "P" then
      table.insert(p, line)
    else
      table.insert(unmarked, line)
    end
  end

  return p, b, g, unmarked
end

function DoodleBuffer:setup(bufnr)
    local ui = require("doodle").ui
    if vim.api.nvim_buf_get_name(bufnr) == "" then
	vim.api.nvim_buf_set_name(bufnr, "__doodle_menu__")
    end

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

    vim.api.nvim_create_autocmd({"BufWriteCmd"}, {
	buffer = bufnr,
	callback = function ()
	    ui:save()
	    vim.schedule(function ()
		ui:toggle_view()
	    end)
	end
    })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
	buffer = bufnr,
	callback = function()
	    ui:toggle_view()
	end
    })

    vim.keymap.set("n", "<TAB>", function()
	local current_scope = ui.current_scope
	current_scope = current_scope + 1
	if current_scope > 3 then
	    current_scope = 1
	end
	ui.current_scope = current_scope
	ui:render()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<S-TAB>", function()
	local current_scope = ui.current_scope
	current_scope = current_scope - 1
	if current_scope == 0 then
	    current_scope = 3
	end
	ui.current_scope = current_scope
	ui:render()
    end, { buffer = bufnr, silent = true })
end

return DoodleBuffer
