# Vim Gym

Practise Vim motions and operators inside Neovim, from `hjkl` to macros. Each exercise opens in a split with a target alongside it. Match the target and you pass. Your keystrokes are scored against a golf-style par.

- Seven modules: hjkl and counts, word motions, `^ $ f`, `dw`/`dd`, `ciw`, text objects, macros
- Hand-written lessons per module, then unlimited randomly generated practice drills
- Modules unlock in order; skip ahead with `:VimGym skip` or take the placement test
- Progress and best scores saved locally as JSON
- Pure Lua, no dependencies

## Requirements

Neovim 0.11 or later.

## Install with lazy.nvim

Minimal:

```lua
{ "<your-github-user>/vim-gym", cmd = "VimGym", opts = {} }
```

`cmd = "VimGym"` lazy-loads the plugin the first time you run the command. `opts = {}` makes lazy.nvim call `require("vimgym").setup({})`, so the defaults apply.

With every option set:

```lua
{
  "<your-github-user>/vim-gym",
  cmd = "VimGym",
  opts = {
    drills_per_practice = 10, -- generated drills per :VimGym practice
    par_slack = 0,            -- extra keystrokes allowed while still earning three stars
    pass_delay = 600,         -- ms pause after a pass before the next exercise
    data_path = nil,          -- progress file; nil = stdpath("data") .. "/vimgym.json"
  },
  keys = {
    { "<leader>vg", "<cmd>VimGym start<cr>", desc = "Vim Gym: continue" },
    { "<leader>vp", "<cmd>VimGym practice<cr>", desc = "Vim Gym: practice" },
    { "<leader>vm", "<cmd>VimGym menu<cr>", desc = "Vim Gym: modules" },
  },
}
```

Adding `keys` also lazy-loads the plugin on those mappings. The mappings are only suggestions; use whatever you like.

To develop from a local clone instead:

```lua
{ dir = "~/code/vim-gym", cmd = "VimGym", opts = {} }
```

### Options

| Option | Default | What it does |
| --- | --- | --- |
| `drills_per_practice` | `10` | Number of generated drills in one `:VimGym practice` run |
| `par_slack` | `0` | Keystrokes over par that still earn three stars |
| `pass_delay` | `600` | Milliseconds to show the result before the next exercise |
| `data_path` | `nil` | Where progress is stored. `nil` uses `stdpath("data")/vimgym.json` |

Scoring: at or under par plus slack earns three stars, up to twice par earns two, anything more earns one.

## Commands

| Command | What it does |
| --- | --- |
| `:VimGym` / `:VimGym start` | Run the lessons for your current module |
| `:VimGym practice [module]` | Generated drills for a module (default: current). Tab-completes module ids |
| `:VimGym menu` | Pick a module to practise. `[x]` done, `[ ]` unlocked, `[-]` locked |
| `:VimGym skip` | Mark the current module complete and move on |
| `:VimGym placement` | One drill per module, in order; stops at the first one over twice par. Passed modules unlock |
| `:VimGym reset` | Clear all progress and best scores |
| `:VimGym quit` | End the session and close its tab |

Module ids: `basics`, `words`, `line`, `operators`, `change`, `textobjects`, `macros`.

## How a session works

A new tab opens. Left: the drill buffer, where you type. Right: the title, hint, par and target text; for motion drills the goal character is highlighted. The check runs automatically whenever you're back in normal mode, so there's nothing to submit. Every key typed in the drill buffer counts, including `:` commands and `<Esc>`.

## Adding lessons

Lessons live in `lua/vimgym/curriculum.lua`. Each one is a table:

```lua
{
  id = "words:3",              -- unique; used for best scores
  title = "End of word",
  hint = "e",
  start = { "the quick brown fox" },
  cursor = { 1, 0 },           -- row 1-based, column 0-based
  target_cursor = { 1, 2 },    -- for motion drills
  -- target = { ... },         -- for edits: the expected buffer lines
  par = 1,
  solution = "e",              -- the test suite types this and expects exactly par
}
```

Generators for practice drills are in `lua/vimgym/generators.lua`. A module lists which generator kinds it uses in its `drills` field.

## Tests

From the repo root:

```sh
nvim --headless -u NONE --cmd "set rtp+=." -l tests/run.lua
```

This types the intended solution into every lesson and 40 random drills per generator, and checks each passes at exactly par. Set `VIMGYM_DRILLS=200` for a longer run. It exits non-zero on failure, so it drops straight into CI.

## Known limitations

- Pars assume the taught technique. A cleverer approach can beat par, which is fine.
- Progress is per machine; there's no sync.
