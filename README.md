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

### Plugin Configuration
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
