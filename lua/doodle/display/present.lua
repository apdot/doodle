local Present = {}

local ID = "@@@"

function Present.get_finder_content(notes, directories)
    local display = {}

    table.insert(display, "")

    if notes then
	for id, note in pairs(notes) do
	    if note.status ~= 2 then
		table.insert(display, ID .. "N".. note.id .. " " .. note.title)
		note.status = 0
	    end
	end
    end
    if directories then
	for id, directory in pairs(directories) do
	    if directory.status ~= 2 then
		table.insert(display, ID .. "D" .. directory.id .. " " .. directory.name .. "/")
		directory.status = 0
	    end
	end
    end

    return display
end

return Present
