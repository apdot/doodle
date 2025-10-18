local Path = require("plenary.path")
local DoodleDirectory = require("doodle.directory")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local NoteTag = require("doodle.tags.note_tag")

local M = {}

local function format_frontmatter(note, tags)
    local lines = { "---" }
    table.insert(lines, "uuid: " .. note.uuid)
    table.insert(lines, "title: " .. note.title)
    table.insert(lines, "project: " .. note.project)
    if note.branch then
        table.insert(lines, "branch: " .. note.branch)
    end
    table.insert(lines, "created_at: " .. os.date("!%Y-%m-%dT%H:%M:%SZ", note.created_at))
    table.insert(lines, "updated_at: " .. os.date("!%Y-%m-%dT%H:%M:%SZ", note.updated_at))

    if #tags > 0 then
        table.insert(lines, "tags:")
        for _, tag in ipairs(tags) do
            table.insert(lines, "  - " .. tag.name)
        end
    end

    table.insert(lines, "---")

    return table.concat(lines, "\n") .. "\n\n"
end

local function export_directory(node, dir_path, blobs, db)
    dir_path:mkdir({ parents = true, exist_ok = true })

    if node.notes then
        for _, note in pairs(node.notes) do
            local file_path = dir_path:joinpath(note.title .. ".md")
            local blob = blobs[note.uuid]
            local tags = NoteTag.get_for_note(note.uuid, db)

            local frontmatter = format_frontmatter(note, tags)
            local content = frontmatter .. (blob and blob.content or "")

            file_path:write(content, "w")
        end
    end

    for _, dir in pairs(node.sub_dirs) do
        local sub_dir_path = dir_path:joinpath(dir.data.name)
        export_directory(dir, sub_dir_path, blobs, db)
    end
end

---@param export_path string
---@param db DoodleDB
function M.run(export_path, db)
    local all_dirs = DoodleDirectory.get_all(db)
    local all_notes = DoodleNote.get_all(db)
    local all_blobs = DoodleBlob.get_all(db)

    local blobs = {}
    for _, blob in pairs(all_blobs) do
        blobs[blob.note_id] = blob
    end

    local hierarchy = {}
    local roots = {}

    for _, dir in pairs(all_dirs) do
        if dir.status ~= 2 then
            hierarchy[dir.uuid] = { data = dir, notes = {}, sub_dirs = {} }
        end
    end

    for _, note in pairs(all_notes) do
        if note.status ~= 2 and note.parent and hierarchy[note.parent] then
            table.insert(hierarchy[note.parent].notes, note)
        end
    end

    for uuid, node in pairs(hierarchy) do
        local parent = node.data.parent
        if parent and hierarchy[parent] then
            hierarchy[parent].sub_dirs[uuid] = node
        else
            table.insert(roots, node)
        end
    end

    local export_path_obj = Path:new(export_path)
    for _, dir in pairs(roots) do
        local path = export_path_obj:joinpath(dir.data.name)
        export_directory(dir, path, blobs, db)
    end
end

return M
