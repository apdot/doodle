local DoodleBuffer = {}
DoodleBuffer.__index = DoodleBuffer

function DoodleBuffer:get_contents(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, true)
    local body = {}

    for _, line in pairs(lines) do
	table.insert(body, line)
    end

    return body
end

function DoodleBuffer:setup(bufnr)
    if vim.api.nvim_buf_get_name(bufnr) == "" then
	vim.api.nvim_buf_set_name(bufnr, "__doodle_menu__")
    end

    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })

    vim.api.nvim_create_autocmd({"BufWriteCmd"}, {
	buffer = bufnr,
	callback = function ()
	    require("doodle").ui:save()
	    vim.schedule(function ()
		require("doodle").ui:toggle_view()
	    end)
	end
    })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
	buffer = bufnr,
	callback = function()
	    require("doodle").ui:toggle_view()
	end,
    })
end

return DoodleBuffer
