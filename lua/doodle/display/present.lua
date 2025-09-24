local Static = require("doodle.static")

local Present = {}

local ID = "@@@"

---@param notes { [string]: DoodleNote }
---@param directories { [string]: DoodleDirectory }
---@return string[]
function Present.get_finder_content(notes, directories)
    local display = {}

    table.insert(display, "")

    if notes then
        for _, note in pairs(notes) do
            if note.status ~= 2 then
                table.insert(display, ID .. "N" .. note.uuid .. " " .. Static.FILE .. " " .. note.title)
                note.status = 0
            end
        end
    end
    if directories then
        for _, directory in pairs(directories) do
            if directory.status ~= 2 then
                table.insert(display, ID .. "D" .. directory.uuid .. " " .. Static.DIRECTORY .. " " .. directory.name .. "/")
                directory.status = 0
            end
        end
    end

    return display
end

---@param tags Tag[]
---@return string
function Present.create_tags(tags)
    local formatted_tags = { "Tags:" }
    for _, tag in pairs(tags) do
        table.insert(formatted_tags, "#" .. tag.name)
    end

    return table.concat(formatted_tags, " ")
end

---@param blob_content string
---@param tags Tag[]
---@return string[]
function Present.get_note_content(blob_content, tags)
    local display = {}
    table.insert(display, "")
    table.insert(display, Present.create_tags(tags))
    if blob_content then
        vim.list_extend(display, vim.split(blob_content, "\n", { plain = true }))
    end

    return display
end

---@param breadcrumbs table
---@return string[]
function Present.get_path(breadcrumbs)
    return vim.tbl_map(function(crumb)
        return crumb[2]
    end, breadcrumbs)
end

---@param breadcrumbs table
---@return string[]
function Present.get_path_ids(breadcrumbs)
    return vim.tbl_map(function(crumb)
        return crumb[1]
    end, breadcrumbs)
end

---@param path string[]
---@param path_ids string[]
---@return { [1]: string, [2]: string }[]
function Present.create_breadcrumbs(path, path_ids)
    local breadcrumbs = {}
    for i = 1, #path do
        table.insert(breadcrumbs, { path_ids[i], path[i] })
    end

    return breadcrumbs
end

---@param tag_line string
---@return string[]
function Present.get_tags(tag_line)
    local tags = {}
    if tag_line and tag_line:lower():match("^tags:") then
        for tag in tag_line:gmatch("#(%S+)") do
            table.insert(tags, tag)
        end
    end

    return tags
end

---@param labels string[]
---@return string[]
function Present.get_labels(labels)
    local display = {}

    table.insert(display, "")

    for _, label in pairs(labels) do
        table.insert(display, Static.FILE .. " " .. label)
    end

    return display
end

local function format_time_ago(timestamp)
    if not timestamp or type(timestamp) ~= "number" then
        return ""
    end

    local now = os.time()
    local diff_seconds = now - timestamp
    local time_str
    if diff_seconds < 60 then
        time_str = diff_seconds .. "s ago"
    elseif diff_seconds < 3600 then
        time_str = math.floor(diff_seconds / 60) .. "m ago"
    elseif diff_seconds < 86400 then
        time_str = math.floor(diff_seconds / 3600) .. "h ago"
    else
        time_str = math.floor(diff_seconds / 86400) .. "d ago"
    end

    return ("(%s)"):format(time_str)
end

---@param adjacency table
---@return string[]
function Present.get_links(adjacency)
    local display = {}
    table.insert(display, "")

    table.insert(display, "# Outgoing: ()")
    local outgoing = adjacency.outgoing
    if outgoing and #outgoing > 0 then
        for _, note_data in pairs(outgoing) do
            table.insert(display, ("  - %s/%s %s"):format(note_data.note.path,
                note_data.link.link_str:sub(2, -2), format_time_ago(note_data.link.created_at)))
        end
    end

    table.insert(display, "")

    table.insert(display, "# Incoming: ()")
    local incoming = adjacency.incoming
    if incoming and #incoming > 0 then
        for _, note_data in pairs(incoming) do
            table.insert(display, ("  - %s/%s %s"):format(note_data.note.path,
                note_data.link.link_str:sub(2, -2), format_time_ago(note_data.link.created_at)))
        end
    else
        table.insert(display, "")
    end


    return display
end

return Present
