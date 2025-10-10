local sqlite = require("sqlite")
local FileUtil = require("doodle.utils.file_util")
local DBUtil = require("doodle.utils.db_util")
local SyncUtil = require("doodle.utils.sync_util")
local DoodleNote = require("doodle.note")
local DoodleDirectory = require("doodle.directory")
local NoteTag = require("doodle.tags.note_tag")
local FormatUtil = require("doodle.utils.format_util")

---@class DoodleDB
---@field config DoodleConfig
---@field _conn table
local DoodleDB = {}
DoodleDB.__index = DoodleDB

local function _db_path()
    FileUtil.create_data_path_if_not_exists()
    return FileUtil.data_path .. ("/doodle.sqlite3")
end

local function connect()
    return sqlite:open(_db_path())
end

function DoodleDB:new(config)
    local ok, _conn = pcall(connect)

    if not ok then
        error([[
	    Error occurred while establishing connection to sqlite.
	    Ensure dependency is added and sqlite is installed on your system.
	]])
    end

    return setmetatable({
        config = config,
        _conn = _conn
    }, self)
end

function DoodleDB:ensure_schema()
    self._conn:execute "pragma foreign_keys = ON"

    local create_note_sql = [[
        CREATE TABLE IF NOT EXISTS note (
            id         INTEGER PRIMARY KEY,
            uuid       TEXT UNIQUE,
            project    TEXT,
            branch     TEXT,
            parent     TEXT REFERENCES directory(uuid) ON DELETE CASCADE,
            title      TEXT,
            path       TEXT,
            path_ids   TEXT,
            template   BOOLEAN DEFAULT 0,
            created_at INTEGER,
            updated_at INTEGER,
            synced_at  INTEGER,
            status     INTEGER DEFAULT 1
        );
    ]]

    local create_directory_sql = [[
        CREATE TABLE IF NOT EXISTS directory (
            id         INTEGER PRIMARY KEY,
            uuid       TEXT UNIQUE,
            project    TEXT,
            branch     TEXT,
            parent     TEXT REFERENCES directory(uuid) ON DELETE CASCADE,
            name       TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            synced_at  INTEGER,
            status     INTEGER DEFAULT 1
        );
    ]]

    local create_blob_sql = [[
        CREATE TABLE IF NOT EXISTS blob (
            id         INTEGER PRIMARY KEY,
            uuid       TEXT UNIQUE,
            note_id    TEXT REFERENCES note(uuid) ON DELETE CASCADE,
            content    TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            synced_at  INTEGER
        );
    ]]

    local create_tag_sql = [[
        CREATE TABLE IF NOT EXISTS tag (
            id         INTEGER PRIMARY KEY,
            uuid       TEXT UNIQUE,
            name       TEXT,
            created_at INTEGER,
            updated_at INTEGER,
            synced_at  INTEGER,
            status     INTEGER DEFAULT 1
        );
    ]]

    local create_note_tag_sql = [[
        CREATE TABLE IF NOT EXISTS note_tag (
            tag_id     TEXT NOT NULL REFERENCES tag(uuid) ON DELETE CASCADE,
            note_id    TEXT NOT NULL REFERENCES note(uuid) ON DELETE CASCADE,
            created_at INTEGER,
            updated_at INTEGER,
            synced_at  INTEGER,
            status     INTEGER DEFAULT 1,
            PRIMARY KEY (note_id, tag_id)
        );
    ]]

    local create_link_sql = [[
        CREATE TABLE IF NOT EXISTS link (
            id         INTEGER PRIMARY KEY,
            uuid       TEXT UNIQUE,
            src        TEXT,
            dest       TEXT,
            link_str   TEXT,
            to_note    BOOLEAN,
            created_at INTEGER,
            updated_at INTEGER,
            synced_at  INTEGER,
            status     INTEGER DEFAULT 1
        );
    ]]

    self._conn:eval(create_note_sql)
    self._conn:eval(create_directory_sql)
    self._conn:eval(create_blob_sql)
    self._conn:eval(create_tag_sql)
    self._conn:eval(create_note_tag_sql)
    self._conn:eval(create_link_sql)
end

function DoodleDB:setup()
    self:ensure_schema()
end

---@param parent string
---@return DoodleNote[]
---@return DoodleDirectory[]
function DoodleDB:load_finder(parent)
    local notes_sql = ([[
    SELECT * FROM note
    WHERE parent = '%s' AND status < 2 AND template != 1
    ORDER BY title ASC, created_at ASC;
    ]]):format(parent)
    local notes = self._conn:eval(notes_sql)
    if not notes or type(notes) == "boolean" or #notes == 0 then
        notes = {}
    end

    local dirs_sql = ([[
    SELECT * FROM directory
    WHERE parent = '%s' AND status < 2
    ORDER BY name ASC, created_at ASC;
    ]]):format(parent)
    local directories = self._conn:eval(dirs_sql)
    if not directories or type(directories) == "boolean" or #directories == 0 then
        directories = {}
    end

    return DoodleNote.from_list(notes) or {}, DoodleDirectory.from_list(directories) or {}
end

---@param table_name string
---@param field string
---@return table
function DoodleDB:get_all(table_name, field)
    local res = self._conn:select(table_name, {
        order_by = { asc = field }
    })

    if not res or #res == 0 then
        return {}
    end

    return res
end

---@param table_name string
---@param status integer
---@param field string
---@return table
function DoodleDB:get_all_with_status(table_name, status, field)
    local res = self._conn:select(table_name, {
        where = { status = status },
        order_by = { asc = field }
    })

    if not res or #res == 0 then
        return {}
    end

    return res
end

---@param field string
---@return table
function DoodleDB:get_templates(field)
    local res = self._conn:select("note", {
        where = {
            template = 1,
            status = "<" .. 2
        },
        order_by = { asc = field }
    })

    if not res or #res == 0 then
        return {}
    end

    return res
end

---@param blob DoodleBlob
---@return string
function DoodleDB:create_blob(blob)
    local now = DBUtil.now()
    local sql = [[
    INSERT INTO blob (uuid, note_id, content, created_at, updated_at)
    VALUES (:uuid, :note_id, :content, :created_at, :updated_at);
    ]]

    local uuid = blob.uuid and blob.uuid or SyncUtil.uuid()
    self._conn:eval(sql, DBUtil.dict({
        uuid = uuid,
        note_id = blob.note_id,
        content = blob.content,
        created_at = now,
        updated_at = now,
    }))

    NoteTag.bulk_map({ FormatUtil.get_date(now) }, { blob.note_id }, self)

    return uuid
end

---@param note_id string
---@return table
function DoodleDB:get_blob(note_id)
    local blob = self._conn:select("blob", {
        where = { note_id = note_id }
    })

    if not blob or #blob == 0 then
        return {}
    end

    return blob[1]
end

---@return table
function DoodleDB:get_unsynced_blob()
    local blob = self._conn:eval([[
	SELECT * FROM blob
	WHERE synced_at IS null OR updated_at > synced_at
	ORDER BY created_at ASC
    ]])

    if not blob or #blob == 0 then
        return {}
    end

    return blob
end

---@param blob DoodleBlob
function DoodleDB:update_blob(blob)
    self._conn:update("blob", {
        where = DBUtil.dict({
            uuid = blob.uuid
        }),
        set = DBUtil.dict({
            content = blob.content,
            updated_at = DBUtil.now()
        })
    })
end

---@param note DoodleNote
---@return string
function DoodleDB:create_note(note)
    local sql = [[
    INSERT INTO note (uuid, project, branch, title, parent, path, template, path_ids, created_at, updated_at)
    VALUES (:uuid, :project, :branch, :title, :parent, :path, :template, :path_ids, :created_at, :updated_at);
    ]]

    local uuid = note.uuid and note.uuid or SyncUtil.uuid()
    print("note title in create", note.title)
    self._conn:eval(sql, DBUtil.dict({
        uuid = uuid,
        project = note.project,
        branch = note.branch,
        title = note.title,
        parent = note.parent,
        path = note.path,
        template = note.template or 0,
        path_ids = note.path_ids,
        created_at = DBUtil.now(),
        updated_at = DBUtil.now(),
    }))

    return uuid
end

---@param uuid string
---@return table
function DoodleDB:get_note(uuid)
    local note = self._conn:select("note", {
        where = { uuid = uuid }
    })

    if not note or #note == 0 then
        return {}
    end

    return note[1]
end

---@param where string
function DoodleDB:get_all_notes_with_tags(where)
    local query = ([[
    SELECT
        note.*,
        GROUP_CONCAT('#' || tag.name) AS tags
    FROM note
    LEFT JOIN
        note_tag on note.uuid = note_tag.note_id AND note_tag.status < 2
    LEFT JOIN
        tag on note_tag.tag_id = tag.uuid
    WHERE %s
    GROUP BY note.uuid
    ]]):format(where)
    -- print(query)
    return self._conn:eval(query)
end

---@param note DoodleNote
function DoodleDB:update_note(note)
    self._conn:update("note", {
        where = { uuid = note.uuid },
        set = DBUtil.dict({
            project = note.project,
            branch = note.branch,
            parent = note.parent,
            title = note.title,
            status = note.status,
            updated_at = DBUtil.now()
        })
    })
end

---@param uuid string
function DoodleDB:delete_note(uuid)
    self._conn:update("note", {
        where = { uuid = uuid },
        set = {
            status = 2,
            updated_at = DBUtil.now()
        }
    })
end

---@param uuid string
---@param parent string
---@return string
function DoodleDB:copy_note(uuid, parent)
    ---@type DoodleNote
    local notes = self._conn:select("note", {
        where = { uuid = uuid }
    })

    if not notes or #notes == 0 then
        return uuid
    end

    local note = notes[1]
    note.parent = parent
    note.uuid = nil
    local copy_id = self:create_note(note)

    ---@type DoodleBlob
    local blob = self._conn:select("blob", {
        where = { note_id = uuid }
    })

    if not blob or #blob == 0 then
        return copy_id
    end

    blob = blob[1]
    blob.note_id = copy_id
    blob.uuid = nil
    self:create_blob(blob)

    return copy_id
end

---@param note_id string
---@return integer, integer
function DoodleDB:get_note_links_count(note_id)
    local sql = [[
    SELECT
        COUNT(CASE WHEN src = :note_id THEN 1 END) as outgoing,
        COUNT(CASE WHEN dest = :note_id THEN 1 END) as incoming
    FROM
        link
    WHERE
        src = :note_id OR dest = :note_id;
    ]]

    local result = self._conn:eval(sql, { note_id = note_id })

    if result and result[1] then
        return result[1].outgoing or 0, result[1].incoming or 0
    end

    return 0, 0
end

---@param directory DoodleDirectory
---@return string
function DoodleDB:create_directory(directory)
    local sql = [[
    INSERT INTO directory (uuid, project, branch, parent, name, created_at, updated_at)
    VALUES (:uuid, :project, :branch, :parent, :name, :created_at, :updated_at);
    ]]

    local uuid = directory.uuid and directory.uuid or SyncUtil.uuid()
    self._conn:eval(sql, DBUtil.dict({
        uuid = uuid,
        project = directory.project,
        branch = directory.branch,
        parent = directory.parent,
        name = directory.name,
        created_at = DBUtil.now(),
        updated_at = DBUtil.now(),
    }))

    return uuid
end

---@param uuid string
---@return table
function DoodleDB:get_directory(uuid)
    local directory = self._conn:select("directory", {
        where = { uuid = uuid }
    })

    if not directory or #directory == 0 then
        return {}
    end

    return directory[1]
end

---@param table_name string
---@return table
function DoodleDB:get_unsynced(table_name)
    local directory = self._conn:eval(([[
	SELECT * FROM %s
	WHERE synced_at IS null OR updated_at > synced_at
	ORDER BY created_at ASC
    ]]):format(table_name))

    if not directory or type(directory) == "boolean" then
        return {}
    end

    return directory
end

---@param uuid string
function DoodleDB:delete_directory(uuid)
    local now = DBUtil.now()
    self._conn:update("directory", {
        where = { uuid = uuid },
        set = {
            status = 2,
            updated_at = now
        }
    })
    self._conn:update("note", {
        where = { parent = uuid },
        set = {
            status = 2,
            updated_at = now
        }
    })
    local sub_directories = self._conn:select("directory", {
        where = {
            parent = uuid,
            status = "<" .. 2
        }
    })
    for _, dir in ipairs(sub_directories) do
        self:delete_directory(dir.uuid)
    end
end

---@param uuid string
---@param parent string
---@return string
function DoodleDB:deep_copy_directory(uuid, parent)
    local dir = self._conn:select("directory", {
        where = { uuid = uuid }
    })

    if not dir or #dir == 0 then
        return uuid
    end

    dir = dir[1]
    dir.parent = parent
    dir.uuid = nil
    local copy_id = self:create_directory(dir)

    local sub_notes = self._conn:select("note", {
        where = {
            parent = uuid,
            status = "<" .. 2
        }
    })
    for _, note in ipairs(sub_notes) do
        self:copy_note(note.uuid, copy_id)
    end

    local sub_directories = self._conn:select("directory", {
        where = {
            parent = uuid,
            status = "<" .. 2
        }
    })
    for _, sub_directory in ipairs(sub_directories) do
        self:deep_copy_directory(sub_directory.uuid, copy_id)
    end

    return copy_id
end

---@param tag Tag
---@return string
function DoodleDB:create_tag(tag)
    local sql = [[
    INSERT INTO tag (uuid, name, created_at, updated_at)
    VALUES (:uuid, :name, :created_at, :updated_at);
    ]]

    local uuid = tag.uuid and tag.uuid or SyncUtil.uuid()
    self._conn:eval(sql, DBUtil.dict({
        uuid = uuid,
        name = tag.name,
        created_at = DBUtil.now(),
        updated_at = DBUtil.now(),
    }))

    return uuid
end

---@param name string
---@return table
function DoodleDB:get_tag(name)
    local tag = self._conn:select("tag", {
        where = { name = name }
    })

    if not tag or #tag == 0 then
        return {}
    end

    return tag[1]
end

---@param note_id string
---@return table
function DoodleDB:get_tags_for_note(note_id)
    local tags = self._conn:eval(([[
    SELECT
        tag.uuid,
        tag.name,
        tag.created_at,
        tag.updated_at,
        tag.synced_at
    FROM note_tag
    INNER JOIN tag ON note_tag.tag_id = tag.uuid
    WHERE
        note_tag.note_id = '%s' AND note_tag.status < 2
    ORDER BY tag.name ASC
    ]]):format(note_id))

    if not tags or type(tags) == "boolean" or #tags == 0 then
        return {}
    end

    return tags
end

---@param prefix string
---@return table
function DoodleDB:search_tag(prefix)
    return self._conn:eval(([[
    SELECT * FROM tag WHERE name LIKE '%s'
    ORDER BY name
    ]]):format(prefix .. "%"))
end

---@param note_id string
function DoodleDB:clear_tag(note_id)
    self._conn:update("note_tag", {
        where = DBUtil.dict({
            note_id = note_id
        }),
        set = DBUtil.dict({
            status = 2,
            updated_at = DBUtil.now()
        })
    })
end

---@param link Link
---@return string
function DoodleDB:create_link(link)
    local sql = [[
    INSERT INTO link (src, dest, link_str, to_note, uuid, created_at, updated_at)
    VALUES (:src, :dest, :link_str, :to_note, :uuid, :created_at, :updated_at);
    ]]

    local uuid = link.uuid and link.uuid or SyncUtil.uuid()
    print("link str", link.link_str)
    self._conn:eval(sql, DBUtil.dict({
        src = link.src,
        dest = link.dest,
        link_str = "\"" .. link.link_str .. "\"",
        to_note = link.to_note and 1 or 0,
        uuid = uuid,
        created_at = DBUtil.now(),
        updated_at = DBUtil.now()
    }))

    return uuid
end

---@param table_name string
---@param primary_key string
---@param values string
---@param now integer
function DoodleDB:mark_synced(table_name, primary_key, values, now)
    local query = ([[
	UPDATE %s SET synced_at = %s
	WHERE (%s) IN ( VALUES %s )
    ]]):format(table_name, now, primary_key, values)

    -- print("query", query)
    self._conn:eval(query)
end

---@param table_name string
---@param columns string[]
---@param values string
---@param primary_key string
---@param where string
function DoodleDB:bulk_upsert(table_name, columns, values, primary_key, where)
    local query_parts = {}

    table.insert(query_parts, ("INSERT INTO %s (%s)"):format(table_name, table.concat(columns, ",")))
    table.insert(query_parts, ("VALUES %s"):format(values))
    table.insert(query_parts, ("ON CONFLICT(%s) DO UPDATE SET"):format(primary_key))
    table.insert(query_parts, DBUtil.create_on_conflict(columns))
    table.insert(query_parts, ("WHERE %s"):format(where))

    local query = table.concat(query_parts, "\n")
    -- print(query)
    local ok, err = self._conn:eval(query)
end

---@param root string
---@param branch string
---@return string
function DoodleDB:create_root_if_not_exists(root, branch)
    local dir = self._conn:select("directory", {
        where = DBUtil.where({
            project = root,
            branch = branch and branch or vim.NIL,
            parent = vim.NIL
        })
    })

    if not dir or #dir == 0 then
        local root_dir = DoodleDirectory.create({
            project = root,
            branch = branch,
            parent = vim.NIL,
            name = root,
            uuid = SyncUtil.hash(root .. (branch or ""))
        }, self)

        DoodleNote.create({
            project = root,
            path = root,
            path_ids = root_dir.uuid,
            branch = branch,
            parent = root_dir.uuid,
            title = "Quick Note"
        }, self)

        return root_dir.uuid
    end

    return dir[1].uuid
end

function DoodleDB:garbage_collect()
    self._conn:delete("directory", {
        where = { status = 2 }
    })
    self._conn:delete("note", {
        where = { status = 2 }
    })
end

---@param func function
function DoodleDB:with_transaction(func)
    self._conn:eval("BEGIN TRANSACTION")
    local ok, err = pcall(func)

    if ok then
        self._conn:eval("COMMIT")
    else
        self._conn:eval("ROLLBACK")
        error(err)
    end
end

return DoodleDB
