local M = {}

function M.where(dict)
    local where = {}
    for k, v in pairs(dict) do
	local cond;
	if v == vim.NIL then
	    cond = { k .. " is null" }
	else
	    cond = { k .. (" = '%s'"):format(v) }
	end
	table.insert(where, cond)
    end
    return where
end

function M.dict(dict)
    local opts = {}
    for k, v in pairs(dict) do
	if v ~= vim.NIL then
	    opts[k] = v
	end
    end
    return opts
end

return M

