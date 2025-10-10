local Note = require("doodle.note")
local Link = require("doodle.link")

local M = {}

---@param db DoodleDB
---@return  { labels: {}, notes: {}, note_idx: {}, note_map: {}, adjacency: { outgoing: {}, incoming: {} } }
function M.build(db)
    local graph = { labels = {}, notes = {}, note_idx = {}, note_map = {}, adjacency = { outgoing = {}, incoming = {} } }

    local notes = Note.get_all_with_status(1, db)
    for k, note in pairs(notes) do
        if note.template ~= 1 then
            table.insert(graph.notes, note)
            graph.note_map[note.uuid] = note
            graph.note_idx[note.uuid] = k
            table.insert(graph.labels, note.path .. "/" .. note.title)
            graph.adjacency[note.uuid] = { outgoing = {}, incoming = {} }
        end
    end

    local links = Link.get_all(db)
    for _, link in pairs(links) do
        local src_note = graph.note_map[link.src]
        if src_note then
            local dest_note = graph.note_map[link.dest]
            if dest_note then
                local backlink = Link:new(link)
                local backlink_str = ("\"[%s](%s)\""):format(src_note.title, src_note.uuid)
                backlink.link_str = backlink_str
                table.insert(graph.adjacency[link.dest].incoming, { note = src_note, link = backlink })
            else
                dest_note = {
                    title = vim.fn.fnamemodify(link.dest, ":t"),
                    path = link.dest
                }
            end

            table.insert(graph.adjacency[link.src].outgoing, { note = dest_note, link = link })
        end
    end

    return graph
end

return M
