<div align="center">
   <h1>Doodle</h1>
   <p><strong>🧠 Your second brain, inside Neovim. <strong></p>
   <p>Doodle is a powerful note-taking and knowledge-management plugin for Neovim, inspired by Obsidian. It provides an integrated environment to capture, organize, and connect your thoughts without ever leaving your editor.</p>
</div>

---
## ✨ Features
-   **Hierarchical & Scoped Notes:** Organize your notes in a familiar directory structure. Scope notes to a `Project`, `Branch` (from Git), or keep them `Global`.
-   **Powerful Finder:** A custom floating window to navigate, create, move, and rename your notes and directories with simple text edits.
-   **Git-based Synchronization:** Sync your notes across multiple devices using a private or public Git repository.
-   **Telescope Integration:** Fuzzy find your notes, files, and templates with the power of Telescope.
-   **Bi-directional Linking:** Effortlessly create links between notes or files, and view both outgoing and incoming connections.
-   **Tagging:** Use `#tags` to categorize your notes, with built-in autocompletion.
-   **Note Templates:** Create reusable templates for different types of notes.
-   **Graph View:** Visualize the connections between your notes in an interactive force-directed graph.
-   **Migrations:** Easily move your data in and out of Doodle using the Import and Export commands.

## ⚡️ Requirements
-   Neovim >= 0.8
-   Sqlite3 command-line tool
-   [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
-   [sqlite.lua](https://github.com/kkharji/sqlite.lua) 

---
## ⚙️ Installation and Configuration
 **IMPORTANT**: `doodle.nvim` uses a local SQLite database to store your notes metadata. This requires the `sqlite3` command-line tool to be installed on your system.

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
              sync = true,
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
---
## 🚀 Features In-Depth

### 🔍 The Finder: Your Editable Mission Control

The `:DoodleFinder` is the heart of Doodle's navigation. It's not just a file list; it's a **fully
editable Neovim buffer** that represents the structure of your notes. This text-based interface
means you can manage your entire note hierarchy with the full power of Vim's text editing capabilities.

-   **Create**: Add a new line. A line ending in `/` becomes a directory; otherwise, it's a note.
-   **Rename**: Use `cw` or any other edit command to rename a note or directory in-place.
-   **Move**: Use `dd` to cut a note and `p` to paste it under a new directory.
-   **Delete**: Delete the line (`dd`) to remove the note or directory.

All changes are applied when you save the buffer with `:w`.

<div align="center">
    <img alt="Finder Demo" height="400" src="/assets/finder_demo.gif" />
</div>

### 📝 Note Management: Capture, Connect, and Organize
Doodle enhances standard markdown with powerful features for organization and context.

#### Scoped Notes
Keep your thoughts organized. Notes can be scoped to:
 -  **Project**: Tied to your current working directory.
 -  **Branch**: Tied to the current Git branch (perfect for feature-specific research).
 -  **Global**: Available everywhere.

#### Linking
 - Bi-Directional Links: Create links to other notes using markdown syntax or to any code file on your system, including line numbers.
 - Connection Tracking: Doodle automatically tracks all incoming and outgoing links, which can be viewed in the Links View.
 - Quick Capture: Use `:DoodleHere` to instantly create a new note that links back to your current file and line, capturing the surrounding code for context.

<div align="center">
    <img alt="Linking Demo" height="400" src="/assets/linking_demo.gif" />
</div>

#### Tagging
 - Flexible Tagging: Add #tags to the `Tags:` line of your notes to categorize them for easy filtering and retrieval.
 - Autocompletion: Doodle provides omni-completion (<C-x><C-o>) for existing tags.

<div align="center">
    <img alt="Tagging Demo" height="400" src="/assets/tagging_demo.gif" />
</div>

#### Templating
 - Reusable Templates: Create reusable note structures for different purposes with the `:DoodleCreateTemplate <name>` command.
 - Telescope Integration: Use the Telescope picker to quickly find a template and create a new note from it, pre-filled with your content.

<div align="center">
    <img alt="Template Demo" height="400" src="/assets/template_demo.gif" />
</div>

#### Migrations
 - Export: Use the `:DoodleExport <path>` command to export your entire note database into structure of markdown files and directories, with metadata preserved in frontmatter.
 - Import: Use the `:DoodleImport <path>` command to import data into Doodle. Each top-level folder within the specified import path is treated as a distinct project scope.

### 🔭 Telescope Integration: Find Anything, Instantly

Doodle integrates deeply with `telescope.nvim` for a world-class fuzzy-finding experience.

-   **Find Notes (`doodle.find_notes`)**: Fuzzy find Doodle notes by title, path or `#tags`.
-   **Find Files (`doodle.find_files`)**: A wrapper around Telescope's native file finder, but with a powerful addition: press `<C-l>` to insert a markdown link to the selected file directly into your current note.
-   **Find Templates (`doodle.find_templates`)**: Quickly find a template and apply it to your current buffer.
-   **Dynamic Scope Switching**: While in the `find_notes` picker, use `<C-p>`, `<C-b>`, and `<C-g>` to dynamically filter your search to the Project, Branch, or Global scopes.

<div align="center">
    <img alt="Telescope Demo" height="400" src="/assets/telescope_demo.gif" />
</div>

### 🌐 Discovering Connections: Links View & Graph View

Doodle provides two powerful ways to understand the relationships between your notes.

-   **:DoodleLinks**: Opens a two-pane view. The left pane lists all your notes. The right pane shows all **incoming and outgoing links** for the selected note, giving you a precise, textual overview of its connections.
-   **:DoodleGraphView**: For a more visual exploration, this command opens a dynamic, force-directed graph of your entire knowledge base. It's a fantastic tool for discovering unexpected connections and getting a high-level overview of your thoughts.

<div align="center">
    <img alt="Link View Demo" height="400" src="/assets/link_view_demo.gif" />
</div>

### 🔄 Synchronization: Robust & Reliable

Doodle uses a Git repository to enable seamless syncing between systems.

-   **How it Works**: Doodle maintains an operation log (`oplog.json`) and periodic `SNAPSHOT` files in your designated Git repo. When you run `:DoodleSync`, it pulls the latest changes, applies them to your local SQLite database, and then pushes your local changes. This log-based approach is reliable and minimizes merge conflicts.
-   **Simple Setup**: Just create a private Git repository, clone it somewhere on your machine, and point the `git_repo` config option to it. Doodle handles the rest.

<div align="center">
    <img alt="Link View Demo" height="400" src="/assets/sync_demo.gif" />
</div>

---
