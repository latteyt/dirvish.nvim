# dirvish.nvim

A **minimal** directory browser for Neovim.

It automatically hijacks all directory buffers (`BufAdd`) and turns plain directory editing into a rich, metadata-enhanced file listing — inspired by the classic [vim-dirvish](https://github.com/justinmk/vim-dirvish), but rewritten entirely in Lua with modern Neovim APIs.

**Extra features beyond the original:**

- File marking system (`m`)
- Powerful batch shell command execution (`:Shdo`)
- Symlink real-path display (`-> ...`)
- File permissions, human-readable size, and modification time shown inline
- Automatic MRU (most recently used) file positioning

Zero external dependencies. Requires Neovim 0.10+ (uses `vim.uv`).

## Features

- **Auto-hijack**: Open any directory (`:e /path/to/dir`) and instantly get a beautiful file list
- **Rich metadata** on the right:
  - Symlinks show `-> realpath`
  - Permissions + human-readable size (B/K/M/G/T/P) + modification time
- **Marking system**:
  - `m` to toggle mark on current line
  - Visual mode `m` to toggle marks on selected lines
  - Marked files are highlighted with `Todo` highlight group
- **Quick actions**:
  - `-` to go to parent directory
  - `<leader>r` to manually refresh the view
- **Bulk shell commands**: `:Shdo` (with `!` to use all marked files)
- **netrw safety**: Automatically detects and warns if netrw is still enabled

## Preview

(What it actually looks like — adapts automatically to your colorscheme)

- Clean directory view with permissions, size, time, and symlink arrows
- Highlighted marked files
- `:Shdo` opens an editable `[HACKVIM]` buffer — edit commands then save to execute

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended)

```lua
{
  "latteyt/dirvish.nvim",   -- replace with your repo
  lazy = false,                  -- load early
  config = function()
    require("dirvish").setup()
  end,
},
```

### Other plugin managers

```lua
-- Packer
use { "latteyt/dirvish.nvim", config = function() require("dirvish").setup() end }

-- vim-plug
Plug 'latteyt/dirvish.nvim'
" Call require("dirvish").setup() at the end of your init.lua
```

## Usage

### 1. Disable netrw (required)

Put this at the very top of your `init.lua`:

```lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
```

### 2. Basic usage

```lua
-- Open a directory
:e /path/to/your/project

-- Inside a dirvish buffer:
m          -- toggle mark on current file
V + m      -- toggle marks on visual selection
-          -- go to parent directory (global mapping)
<leader>r  -- refresh current directory view
```

### 3. Bulk shell commands (the killer feature)

```vim
:Shdo rm -rf {}           " Run command on selected lines ({ } is replaced by path)
:Shdo! mv {} ../backup    " Use ! to run on ALL marked files (ignores selection)
```

After running `:Shdo`, a temporary `[HACKVIM]` buffer opens:

- Edit any command line
- Save (`:w`) → commands execute line by line
- On error you are prompted whether to continue

After execution, all directory views are automatically refreshed.

## Commands

| Command             | Description                                      |
|---------------------|--------------------------------------------------|
| `:Shdo {cmd}`       | Run shell command on selected lines              |
| `:Shdo! {cmd}`      | Run shell command on all marked files            |

## Configuration

`setup()` currently takes no arguments (minimalist design).

If you want to override the global `-` mapping:

```lua
require("dirvish").setup()

vim.keymap.set('n', '<leader>-', require("dirvish").toggle, { desc = "Toggle Dirvish" })
```

## FAQ

**Q: Why do I still see netrw when opening a directory?**
A: Make sure `vim.g.loaded_netrw = 1` and `vim.g.loaded_netrwPlugin = 1` are set **before** anything else in your config.

**Q: Marks disappear after restart?**
A: Yes — marks are buffer-local (`vim.b.mark_files`). They reset when you reopen a directory.

**Q: No symlink arrow?**
A: Ensure your `NonText` highlight group is visible (most colorschemes support it).

## Credits

- Original inspiration: [justinmk/vim-dirvish](https://github.com/justinmk/vim-dirvish)
- High-performance stats using `vim.uv`
- `:Shdo` design influenced by oil.nvim batch operations

---

**Enjoy!**
Feel free to open Issues or PRs — let's make dirvish.nvim the smoothest directory experience in Neovim ✨
```
