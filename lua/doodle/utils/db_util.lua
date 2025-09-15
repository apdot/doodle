local M = {}

function M.now() return os.time() end

---@param dict table
---@return table
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

---@param dict table
---@return table
function M.dict(dict)
    local opts = {}
    for k, v in pairs(dict) do
        if v ~= vim.NIL then
            opts[k] = v
        end
    end

    return opts
end

---@param dict table
---@return string[]
function M.get_query_uuids(dict)
    local uuids = {}
    for _, obj in pairs(dict) do
        table.insert(uuids, ("'%s'"):format(obj.uuid))
    end

    return uuids
end

---@param dict table
---@return string[]
function M.get_uuids(dict)
    return vim.tbl_map(function(obj)
        print("obj.uuid", obj.uuid)
        return obj.uuid
    end, dict)
end

---@param value string
---@return string
local function format_data(value)
    if value == vim.NIL then
        return "NULL"
    elseif type(value) == "string" then
        return "'" .. value .. "'"
    else
        return tostring(value)
    end
end

---@param arr table
---@return string
function M.format_values(arr)
    local values = {}
    for _, value in pairs(arr) do
        table.insert(values, format_data(value))
    end

    return "(" .. table.concat(values, ",") .. ")"
end

---@param columns string[]
---@return string
function M.create_on_conflict(columns)
    local on_conflict = {}
    for _, column in pairs(columns) do
        table.insert(on_conflict, ("%s = excluded.%s"):format(column, column))
    end

    return table.concat(on_conflict, ",")
end

---@param table_name string
---@param columns string[]
---@return string
function M.create_is_distinct(table_name, columns)
    local is_distinct = {}
    for _, column in pairs(columns) do
        if column ~= "updated_at" and column ~= "synced_at" then
            table.insert(
                is_distinct,
                ("%s.%s IS DISTINCT FROM excluded.%s"):format(table_name, column, column)
            )
        end
    end

    return table.concat(is_distinct, " OR\n")
end

return M
