local Job = require("plenary.job")

local M = {}

---@param cmd string[]
---@param cwd string
---@return boolean
---@return string
function M.run(cmd, cwd)
    local ok, result

    Job:new({
        command = cmd[1],
        args = vim.list_slice(cmd, 2),
        cwd = cwd,
        on_exit = function(j, return_val)
            ok = (return_val == 0)
            result = table.concat(j:result(), "\n")
        end,
    }):sync()

    return ok, result
end

math.randomseed(os.time())

---@param str string
---@return string
function M.hash(str)
    return vim.fn.sha256(str)
end

function M.uuid()
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

return M
