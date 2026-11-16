local M = {}

M.config = {
  drills_per_practice = 10, -- drills per practice round (practice runs until you quit)
  par_slack = 0,            -- extra keystrokes allowed while still earning three stars
  pass_delay = 600,         -- ms to pause after a pass before the next exercise
  number = true,            -- line numbers in the drill window
  relativenumber = true,    -- relative line numbers in the drill window
  data_path = nil,          -- progress file; nil = stdpath("data")/vimgym.json
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local function current_module()
  local progress = require("vimgym.progress")
  for i, mod in ipairs(require("vimgym.curriculum").modules) do
    if not progress.is_complete(mod.id) then return mod, i end
  end
end

function M.command(args)
  local sub = args[1] or "start"
  local progress = require("vimgym.progress")
  local curriculum = require("vimgym.curriculum")
  local session = require("vimgym.session")

  if sub == "start" then
    if not session.run_lessons() then
      vim.notify("Vim Gym: all modules complete. Try :VimGym practice <module>")
    end
  elseif sub == "practice" then
    local mod = args[2] and curriculum.get(args[2]) or current_module()
    if not mod then return vim.notify("Vim Gym: unknown module", vim.log.levels.WARN) end
    if not progress.is_unlocked(mod.id) then
      return vim.notify("Vim Gym: module locked. Use :VimGym skip or :VimGym placement.")
    end
    session.run_practice(mod, M.config.drills_per_practice)
  elseif sub == "skip" then
    local mod = current_module()
    if mod then
      progress.complete(mod.id, "skipped")
      vim.notify("Vim Gym: skipped " .. mod.title)
    end
  elseif sub == "placement" then
    session.run_placement()
  elseif sub == "menu" then
    local items = {}
    for _, mod in ipairs(curriculum.modules) do
      local mark = progress.is_complete(mod.id) and "[x] "
        or (progress.is_unlocked(mod.id) and "[ ] " or "[-] ")
      table.insert(items, mark .. mod.title)
    end
    vim.ui.select(items, { prompt = "Vim Gym modules" }, function(_, idx)
      if idx then M.command({ "practice", curriculum.modules[idx].id }) end
    end)
  elseif sub == "reset" then
    progress.reset()
    vim.notify("Vim Gym: progress reset")
  elseif sub == "quit" then
    session.stop()
  else
    vim.notify("Vim Gym: unknown command " .. sub, vim.log.levels.WARN)
  end
end

return M
