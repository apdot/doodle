local Present = {}

local ID = "@@@"

---@param notes { [string]: DoodleNote }
---@param directories { [string]: DoodleDirectory }
---@return string[]
function Present.get_finder_content(notes, directories)
    local display = {}

    table.insert(display, "")

    if notes then
        for id, note in pairs(notes) do
            if note.status ~= 2 then
                -- print("note id", ID .. "N" .. id .. " " .. note.title)
                table.insert(display, ID .. "N" .. id .. " " .. note.title)
                note.status = 0
            end
        end
    end
    if directories then
        for id, directory in pairs(directories) do
            if directory.status ~= 2 then
                table.insert(display, ID .. "D" .. id .. " " .. directory.name .. "/")
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
    vim.list_extend(display, vim.split(blob_content, "\n", { plain = true }))

    return display
end

---@param breadcrumbs table
---@return string[]
function Present.get_path(breadcrumbs)
    return vim.tbl_map(function(crumb)
        return crumb[2]
    end, breadcrumbs)
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

return Present
