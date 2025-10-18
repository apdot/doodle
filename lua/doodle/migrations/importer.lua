local Path = require("plenary.path")
local ScanDir = require("plenary.scandir")
local DoodleDirectory = require("doodle.directory")
local DoodleNote = require("doodle.note")
local DoodleBlob = require("doodle.blob")
local SyncUtil = require("doodle.utils.sync_util")

local M = {}

local global_uuid

local function import_directory(dir_path, parent, project, path_str, path_ids, db)
    local ls = ScanDir.scan_dir(dir_path, { depth = 1, add_dirs = true })
    for _, path in pairs(ls) do
        local path_obj = Path:new(path)
        local path_name = vim.fn.fnamemodify(path_obj.filename, ":t")
        if path_obj:is_dir() then
            local dir = {}
            local uuid = nil

            if not parent then
                -- project directory
                uuid = SyncUtil.hash(path_name)
                dir = DoodleDirectory.get(uuid, db)
            end

            if not dir.status then
                dir = DoodleDirectory.create({
                    project = project or path_name,
                    parent = parent or vim.NIL,
                    name = path_name,
                    uuid = uuid
                }, db)
            end

            path_str = path_str and path_str .. "/" .. path_name or path_name
            path_ids = path_ids and path_ids .. "/" .. dir.uuid or dir.uuid
            import_directory(path, dir.uuid, project or path_name,
                path_str, path_ids, db)
        else
            if not parent then
                parent = global_uuid
                project = "__global"
            end
            local note = DoodleNote.create({
                project = project,
                path = path_str,
                path_ids = path_ids,
                parent = parent,
                title = path_name
            }, db)

            local content = path_obj:read()
            DoodleBlob.create({
                note_id = note.uuid,
                content = content
            }, db)
        end
    end
end

---@param import_path string
---@param db DoodleDB
function M.run(import_path, db)
    local import_path_obj = Path:new(import_path)
    if not import_path_obj:exists() or not import_path_obj:is_dir() then
        error("Import path does not exist or is not a directory: " .. import_path)
        return
    end

    local global_path = import_path_obj:joinpath("__global")
    global_path:mkdir({ parents = true, exist_ok = true })

    global_uuid = SyncUtil.hash("__global")
    local global_dir = DoodleDirectory.get(global_uuid, db)
    if not global_dir.status then
        DoodleDirectory.create({
            project = "__global",
            parent = vim.NIL,
            name = "__global",
            uuid = SyncUtil.hash("__global")
        }, db)
    end

    import_directory(import_path, nil, nil, nil, nil, db)
end

return M
