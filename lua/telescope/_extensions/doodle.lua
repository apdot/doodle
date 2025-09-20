local has_telescope, telescope = pcall(require, "telescope")

if not has_telescope then
    error("doodle.nvim fuzzy-finder requires nvim-telescope/telescope.nvim")
end

return telescope.register_extension({
    exports = {
        find_notes = require("telescope._extensions.find").find_notes,
        find_files = require("telescope._extensions.find").find_files,
    }
})
