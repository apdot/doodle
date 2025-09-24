local FormatUtil = require("doodle.utils.format_util")

local View = {}

local scopes = { "Project", "Branch", "Global" }
local ns = vim.api.nvim_create_namespace("doodle_ns")

---@param bufnr integer
---@param win_id integer
---@param line integer
function View.place_cursor(bufnr, win_id, line)
    local line_count = vim.api.nvim_buf_line_count(bufnr)
    if line_count >= line then
        vim.api.nvim_win_set_cursor(win_id, { line, 0 })
    end
end

---@param bufnr integer
---@param win_id integer?
function View.close(bufnr, win_id)
    if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end

    if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
        vim.api.nvim_win_close(win_id, true)
    end
end

---@param height_factor number
---@param width_factor number
---@return integer, integer?
function View.create_finder_window(height_factor, width_factor)
    local width = math.min(math.floor(vim.o.columns * width_factor), 64)
    local height = math.floor(vim.o.lines * height_factor)
    local bufnr = vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(bufnr, true, {
        relative = "editor",
        row = math.floor(((vim.o.lines - height) / 2) - 1),
        col = math.floor((vim.o.columns - width) / 2),
        width = width,
        height = height,
        style = "minimal",
        border = "single",
        footer_pos = "right",
        footer = "doodle"
    })
    if win_id == 0 then
        View.close(bufnr, win_id)
        error("Failed to open finder")
        return bufnr, nil
    end

    vim.api.nvim_set_option_value("number", true, {
        win = win_id,
    })

    vim.api.nvim_set_option_value("cursorline", true, { win = win_id })
    vim.api.nvim_set_option_value("winbar", " %=Doodle%= ", { win = win_id })
    vim.api.nvim_set_option_value("concealcursor", "nivc", { win = win_id })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win_id })

    return bufnr, win_id
end

---@return { left: integer, right: integer }, { left: integer, right: integer }
function View.create_links_window()
    local right_buf, right_win = View.create_window()

    vim.api.nvim_set_current_win(right_win)
    vim.cmd("vsplit")
    local left_win = vim.api.nvim_get_current_win()
    local left_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(left_win, left_buf)

    local total_width = vim.api.nvim_win_get_width(left_win) + vim.api.nvim_win_get_width(right_win)
    vim.api.nvim_win_set_width(left_win, math.floor(total_width / 3))

    for _, buf in pairs({ left_buf, right_buf }) do
        vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
        vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
    end

    vim.api.nvim_set_option_value("cursorline", true, { win = left_win })

    for _, win in pairs({ left_win, right_win }) do
        vim.api.nvim_set_option_value("concealcursor", "nivc", { win = win })
        vim.api.nvim_set_option_value("conceallevel", 2, { win = win })
    end

    return { left = left_buf, right = right_buf }, { left = left_win, right = right_win }
end

function View.create_window()
    local bufnr = vim.api.nvim_create_buf(false, true)
    if vim.api.nvim_win_get_config(0).relative ~= "" then
        vim.cmd("wincmd p") -- jump back to last non-floating window
    end

    local win_id = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(win_id, bufnr)
    vim.api.nvim_set_option_value("concealcursor", "nivc", { win = win_id })
    vim.api.nvim_set_option_value("conceallevel", 2, { win = win_id })

    return bufnr, win_id
end

---@param bufnr integer
---@param content string[]
local function render_content(bufnr, content)
    vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
    print("content", content)
    for k, v in pairs(content) do
        print(k, v)
    end
    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, content)
end

---@param current_scope integer
---@return table
function View.scope_line(current_scope)
    local virt_text = {}
    for i, scope in ipairs(scopes) do
        if i == current_scope then
            table.insert(virt_text, { " " .. scope .. " ", "Keyword" }) -- active
        else
            table.insert(virt_text, { " " .. scope .. " ", "Comment" }) -- inactive
        end

        if i < #scopes then
            table.insert(virt_text, { "|", "Comment" })
        end
    end
    return virt_text
end

---@param blob DoodleBlob
---@param path string[]
function View.metadata_line(blob, title, path)
    local virt_text = {}

    table.insert(virt_text, { " Title: ", "Comment" })
    table.insert(virt_text, { title .. " ", "Keyword" })

    local created_at = FormatUtil.get_date_time(blob.created_at)
    table.insert(virt_text, { " Created: ", "Comment" })
    table.insert(virt_text, { created_at .. " ", "String" })

    table.insert(virt_text, { "| ", "Comment" })

    local updated_at = FormatUtil.get_date_time(blob.updated_at)
    table.insert(virt_text, { " Updated: ", "Comment" })
    table.insert(virt_text, { updated_at .. " ", "Type" })

    table.insert(virt_text, { "| ", "Comment" })

    table.insert(virt_text, { " Path: ", "Comment" })
    table.insert(virt_text, { table.concat(path, "/") .. " ", "Identifier" })

    return virt_text
end

function View.links_left_header()
    return { { " Notes", "Keyword" } }
end

---@param title string
function View.links_right_header(title)
    return { { (" Links: %s"):format(title), "Type" } }
end

---@param bufnr integer
---@param win integer
---@param lnum integer
local function draw_virtual_hline(bufnr, win, lnum)
    local width = vim.api.nvim_win_get_width(win)
    local line = string.rep("─", width)
    vim.api.nvim_buf_set_extmark(bufnr, ns, lnum, 0, {
        virt_text = { { line, "Comment" } },
        virt_text_pos = "overlay",
    })
end

---@param bufnr integer
---@param win_id integer
---@param header table
local function render_header(bufnr, win_id, header)
    vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    vim.api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
        virt_text = header,
        virt_text_pos = "overlay",
    })

    draw_virtual_hline(bufnr, win_id, 1)
end

---@param win_id integer
---@param path string[]
local function render_breadcrumbs(win_id, path)
    vim.api.nvim_win_set_config(win_id, {
        footer = table.concat(path, "/"),
    })
end

---@param bufnr integer
---@param win_id integer
---@param content string[]
---@param header table
---@param path string[]
function View.render(bufnr, win_id, content, header, path)
    render_content(bufnr, content)
    render_header(bufnr, win_id, header)
    render_breadcrumbs(win_id, path)
end

return View
