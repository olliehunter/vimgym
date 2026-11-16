local M = {}
local hl_ns = vim.api.nvim_create_namespace("vimgym")
local key_ns = vim.api.nvim_create_namespace("vimgym_keys")
local S -- active session

function M._state() return S end

local function stop_keys() vim.on_key(nil, key_ns) end
local function cfg() return require("vimgym").config end

function M.stop()
  if not S then return end
  local s = S
  S = nil
  stop_keys()
  if s.group then pcall(vim.api.nvim_del_augroup_by_id, s.group) end
  if vim.api.nvim_tabpage_is_valid(s.tab) and #vim.api.nvim_list_tabpages() > 1 then
    pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(s.tab))
  end
end

local function scratch()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  return buf
end

local function set_lines(buf, lines, fresh_undo)
  vim.bo[buf].modifiable = true
  local ul = vim.bo[buf].undolevels
  if fresh_undo then vim.bo[buf].undolevels = -1 end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if fresh_undo then vim.bo[buf].undolevels = ul end
  vim.bo[buf].modified = false
end

local function matches(ex)
  local lines = vim.api.nvim_buf_get_lines(S.buf, 0, -1, false)
  if not vim.deep_equal(lines, ex.target or ex.start) then return false end
  if ex.target_cursor then
    local c = vim.api.nvim_win_get_cursor(S.win)
    return c[1] == ex.target_cursor[1] and c[2] == ex.target_cursor[2]
  end
  return true
end

local function check(ex)
  if not S or S.done or S.queue[S.index] ~= ex then return end
  if vim.api.nvim_get_mode().mode ~= "n" then return end
  if matches(ex) then M._pass() end
end

local function show(ex)
  stop_keys()
  if S.group then pcall(vim.api.nvim_del_augroup_by_id, S.group) end
  S.done, S.keys = false, 0

  local header = {
    "Vim Gym: " .. ex.title,
    ex.hint or "",
    string.format("Par %d   (%d/%d)   :VimGym quit to exit", ex.par, S.index, #S.queue),
    string.rep("-", 40),
  }
  set_lines(S.tbuf, vim.list_extend(vim.deepcopy(header), ex.target or ex.start))
  vim.bo[S.tbuf].modifiable = false
  vim.api.nvim_buf_clear_namespace(S.tbuf, hl_ns, 0, -1)
  if ex.target_cursor then
    local row = #header + ex.target_cursor[1] - 1
    local col = ex.target_cursor[2]
    vim.api.nvim_buf_set_extmark(S.tbuf, hl_ns, row, col,
      { end_col = col + 1, hl_group = "IncSearch", strict = false })
  end

  set_lines(S.buf, ex.start, true)
  vim.api.nvim_set_current_win(S.win)
  vim.cmd("stopinsert")
  vim.api.nvim_win_set_cursor(S.win, ex.cursor)

  vim.on_key(function(_, typed)
    if not S or S.done or not typed or typed == "" then return end
    if vim.api.nvim_get_current_buf() ~= S.buf then return end
    S.keys = S.keys + 1
    if S.mode == "placement" and S.keys > ex.par * 2 then
      vim.schedule(M._fail)
      return
    end
    -- Check after every key; CursorMoved alone isn't reliable
    vim.schedule(function() check(ex) end)
  end, key_ns)

  S.group = vim.api.nvim_create_augroup("VimGymSession", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "ModeChanged" }, {
    group = S.group,
    buffer = S.buf,
    callback = function() vim.schedule(function() check(ex) end) end,
  })
end

local function finish()
  local s = S
  M.stop()
  if s and s.on_done then s.on_done(s.results) end
end

function M._next()
  if not S then return end
  S.index = S.index + 1
  if S.index > #S.queue then return finish() end
  show(S.queue[S.index])
end

function M._pass()
  if not S or S.done then return end
  S.done = true
  stop_keys()
  local ex = S.queue[S.index]
  local stars = S.keys <= ex.par + cfg().par_slack and "***"
    or (S.keys <= ex.par * 2 and "**" or "*")
  local best = require("vimgym.progress").record(ex.id, S.keys)
  vim.notify(string.format("%s  %d keys (par %d)%s", stars, S.keys, ex.par, best and "  new best" or ""))
  table.insert(S.results, { ex = ex, keys = S.keys, ok = true })
  vim.defer_fn(M._next, cfg().pass_delay)
end

function M._fail()
  if not S or S.done then return end
  S.done = true
  table.insert(S.results, { ex = S.queue[S.index], keys = S.keys, ok = false })
  vim.notify("Over twice par, placement stops here")
  vim.defer_fn(finish, cfg().pass_delay)
end

local function start(queue, mode, on_done)
  M.stop()
  if #queue == 0 then return vim.notify("Vim Gym: nothing to run") end
  local buf = scratch()
  vim.cmd("tab sbuffer " .. buf)
  S = {
    tab = vim.api.nvim_get_current_tabpage(), win = vim.api.nvim_get_current_win(),
    buf = buf, queue = queue, index = 1, mode = mode, on_done = on_done, results = {},
  }
  vim.cmd("rightbelow vsplit")
  S.tbuf = scratch()
  vim.api.nvim_win_set_buf(0, S.tbuf)
  vim.wo.number, vim.wo.relativenumber = false, false
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = buf, once = true, callback = function() vim.schedule(M.stop) end,
  })
  show(queue[1])
end
M._start = start

function M.run_lessons(mod)
  start(mod.lessons, "lesson", function(results)
    if #results == #mod.lessons then
      require("vimgym.progress").complete(mod.id)
      vim.notify("Vim Gym: " .. mod.title .. " complete. :VimGym start for the next module, or :VimGym practice " .. mod.id)
    end
  end)
end

function M.run_practice(mod, n)
  start(require("vimgym.generators").batch(mod, n), "practice", function(results)
    local hits = 0
    for _, r in ipairs(results) do if r.keys <= r.ex.par then hits = hits + 1 end end
    vim.notify(string.format("Vim Gym: %d/%d drills at or under par", hits, #results))
  end)
end

function M.run_placement()
  local gen = require("vimgym.generators")
  local queue = {}
  for _, mod in ipairs(require("vimgym.curriculum").modules) do
    local ex = gen.drill(mod)
    ex.module = mod.id
    table.insert(queue, ex)
  end
  start(queue, "placement", function(results)
    local progress, placed = require("vimgym.progress"), 0
    for _, r in ipairs(results) do
      if not r.ok then break end
      progress.complete(r.ex.module, "placed")
      placed = placed + 1
    end
    vim.notify(string.format("Vim Gym: placed past %d module(s). :VimGym start to continue", placed))
  end)
end

return M
