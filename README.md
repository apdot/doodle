<div align="center">
   <h1>Doodle</h1>
   <p><strong>🧠 Your second brain, inside Neovim. <strong></p>
   <p>Doodle is a powerful note-taking and knowledge-management plugin for Neovim, inspired by Obsidian. It provides an integrated environment to capture, organize, and connect your thoughts without ever leaving your editor.</p>
</div>

## ✨ Features
-   **Hierarchical & Scoped Notes:** Organize your notes in a familiar directory structure. Scope notes to a `Project`, `Branch` (from Git), or keep them `Global`.
-   **Powerful Finder:** A custom floating window to navigate, create, move, and rename your notes and directories with simple text edits.
-   **Git-based Synchronization:** Sync your notes across multiple devices using a private or public Git repository.
-   **Telescope Integration:** Fuzzy find your notes, files, and templates with the power of Telescope.
-   **Bi-directional Linking:** Effortlessly create links between notes or files, and view both outgoing and incoming connections.
-   **Tagging:** Use `#tags` to categorize your notes, with built-in autocompletion.
-   **Note Templates:** Create reusable templates for different types of notes.
-   **Graph View:** Visualize the connections between your notes in an interactive force-directed graph.

## ⚡️ Requirements
-   Neovim >= 0.8
-   [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
-   [sqlite.lua](https://github.com/kkharji/sqlite.lua) 
-   sqlite3 command-line tool

## ⚙️ Installation and Configuration
 **IMPORTANT**: `doodle.nvim` uses a local SQLite database to store your notes. This requires the `sqlite3` command-line tool to be installed on your system.

### 1. Plugin Configuration
Here is a minimal, real-world setup guide using `lazy.nvim`.
Add the following to your `lazy.nvim` plugin specifications. This example includes recommended keymaps.

```lua
return {
  "apdot/doodle",
  dependencies = {
      "kkharji/sqlite.lua",
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
  },
  config = function()
      require("doodle").setup({
          settings = {
              -- This is the only required setting for sync to work.
              -- Set it to the absolute path of your private notes repository.
              git_repo = "path/to/your/initialized/git/repository",
          }
      })
  end,
  keys = {
      {
          "<space>df",
          function() require("doodle"):toggle_finder() end,
          desc = "Doodle Finder"
      },
      {
          "<space>ds",
          function() require("doodle"):sync() end,
          desc = "Doodle Sync"
      },
      {
          "<space>dl",
          function() require("doodle"):toggle_links() end,
          desc = "Doodle Links"
      },
  },
}
````

### 2. Configure Telescope
To enable the powerful Telescope integration, you must load `doodle` as an extension in your Telescope
 config and set up your desired keymaps.
```lua
return {
  'nvim-telescope/telescope.nvim',
  dependencies = {
      'nvim-lua/plenary.nvim',
      'apdot/doodle', -- Ensure doodle is a dependency
  },
  config = function()
      local telescope = require('telescope')
      telescope.setup {
          extensions = {
              doodle = {} -- Enable the doodle extension
          }
      }
      -- Load the extension
      telescope.load_extension('doodle')

      -- Example keymaps for doodle's telescope pickers
      local keymap = vim.keymap.set
      keymap("n", "<space>dd", function()
          telescope.extensions.doodle.find_notes()
      end, { desc = "Doodle Find Notes" })

      keymap("n", "<space>ff", function()
          telescope.extensions.doodle.find_files()
      end, { desc = "Doodle Find Files" })

      keymap("n", "<space>dy", function()
          telescope.extensions.doodle.find_templates()
      end, { desc = "Doodle Find Templates" })
  end,
}
````
