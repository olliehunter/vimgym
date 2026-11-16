-- A session is one tab: drill buffer on the left, target on the right.
-- It runs a queue of exercises; when the queue runs out, S.more() can supply
-- the next batch (next module's lessons, another practice round), so the
-- session keeps going until there's nothing left or the user quits.
local M = {}
local hl_ns = vim.api.nvim_create_namespace("vimgym")
local key_ns = vim.api.nvim_create_namespace("vimgym_keys")
local S -- active session

function M._state() return S end

local function cfg() return require("vimgym").config end
local function stop_keys() vim.on_key(nil, key_ns) end

local function alive()
  return S ~= nil
    and vim.api.nvim_buf_is_valid(S.buf) and vim.api.nvim_win_is_valid(S.win)
    and vim.api.nvim_buf_is_valid(S.tbuf)
end

function M.stop()
  if not S then return end
  local s = S
  S = nil
  stop_keys()
  pcall(vim.api.nvim_del_augroup_by_id, s.group)
  pcall(vim.api.nvim_del_augroup_by_id, s.ex_group)
  if vim.api.nvim_tabpage_is_valid(s.tab) and #vim.api.nvim_list_tabpages() > 1 then
    pcall(vim.cmd, "tabclose " .. vim.api.nvim_tabpage_get_number(s.tab))
  end
  for _, b in ipairs({ s.buf, s.tbuf }) do
    if vim.api.nvim_buf_is_valid(b) then pcall(vim.api.nvim_buf_delete, b, { force = true }) end
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
  if not S or S.done or S.queue[S.index] ~= ex or not alive() then return end
  if vim.api.nvim_get_mode().mode ~= "n" then return end
  if vim.fn.reg_recording() ~= "" then return end -- finish recording first
  if matches(ex) then M._pass() end
end

local function show(ex)
  stop_keys()
  pcall(vim.api.nvim_del_augroup_by_id, S.ex_group)
  S.done, S.keys = false, 0

  local title = ex.section and (ex.section .. "  >  " .. ex.title) or ex.title
  local header = {
    "Vim Gym: " .. title,
    ex.hint or "",
    string.format("Par %d   (%d/%d)   :VimGym quit to exit", ex.par, ex.pos or S.index, ex.of or #S.queue),
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
    if ex.mode == "placement" and S.keys > ex.par * 2 then
      vim.schedule(M._fail)
      return
    end
    -- Check after every key; CursorMoved alone isn't reliable
    vim.schedule(function() check(ex) end)
  end, key_ns)

  S.ex_group = vim.api.nvim_create_augroup("VimGymExercise", { clear = true })
  vim.api.nvim_create_autocmd({ "CursorMoved", "TextChanged", "ModeChanged", "RecordingLeave" }, {
    group = S.ex_group,
    buffer = S.buf,
    callback = function() vim.schedule(function() check(ex) end) end,
  })
end

local function finish()
  local s = S
  M.stop()
  if s and s.on_done then s.on_done(s) end
end

function M._next()
  if not S then return end
  S.index = S.index + 1
  if S.index > #S.queue then
    local more = S.more and S.more(S)
    if not more or #more == 0 then return finish() end
    vim.list_extend(S.queue, more)
  end
  if not alive() then return M.stop() end
  show(S.queue[S.index])
end

function M._pass()
  if not S or S.done then return end
  S.done = true
  stop_keys()
  local ex = S.queue[S.index]
  local progress = require("vimgym.progress")
  local stars = S.keys <= ex.par + cfg().par_slack and "***"
    or (S.keys <= ex.par * 2 and "**" or "*")
  local best = progress.record(ex.id, S.keys)
  local msg = string.format("%s  %d keys (par %d)%s", stars, S.keys, ex.par, best and "  new best" or "")
  if ex.mode == "lesson" and ex.last_in_module then
    progress.complete(ex.module)
    msg = msg .. "   Module complete: " .. ex.section
  elseif ex.mode == "placement" then
    progress.complete(ex.module, "placed")
  end
  vim.notify(msg)
  table.insert(S.results, { ex = ex, keys = S.keys, ok = true })
  vim.defer_fn(M._next, cfg().pass_delay)
end

function M._fail()
  if not S or S.done then return end
  S.done = true
  stop_keys()
  table.insert(S.results, { ex = S.queue[S.index], keys = S.keys, ok = false })
  for i = #S.queue, S.index + 1, -1 do table.remove(S.queue, i) end
  vim.notify("Over twice par, placement stops here")
  vim.defer_fn(M._next, cfg().pass_delay)
end

-- Closing either window (:q, :close, :bd) ends the session cleanly.
local function on_closed()
  if not S then return end
  S.done = true
  stop_keys()
  vim.schedule(function()
    if S then
      M.stop()
      vim.notify("Vim Gym: session ended, progress saved")
    end
  end)
end

local function start(queue, more, on_done)
  M.stop()
  if #queue == 0 then return false end
  local buf = scratch()
  vim.cmd("tab sbuffer " .. buf)
  local win = vim.api.nvim_get_current_win()
  vim.cmd("rightbelow vsplit")
  local twin = vim.api.nvim_get_current_win()
  local tbuf = scratch()
  vim.api.nvim_win_set_buf(twin, tbuf)

  vim.wo[win].number = cfg().number
  vim.wo[win].relativenumber = cfg().relativenumber
  vim.wo[twin].number = false
  vim.wo[twin].relativenumber = false

  S = {
    tab = vim.api.nvim_get_current_tabpage(), win = win, twin = twin, buf = buf, tbuf = tbuf,
    queue = queue, index = 1, more = more, on_done = on_done, results = {},
  }
  S.group = vim.api.nvim_create_augroup("VimGymSession", { clear = true })
  vim.api.nvim_create_autocmd("WinClosed", {
    group = S.group, pattern = { tostring(win), tostring(twin) }, callback = on_closed,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = S.group, buffer = buf, callback = on_closed,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = S.group, buffer = tbuf, callback = on_closed,
  })
  show(queue[1])
  return true
end

-- Test hook: run a plain queue with no continuation.
function M._start(queue, on_done)
  for i, ex in ipairs(queue) do
    ex.mode = ex.mode or "practice"
    ex.pos, ex.of = ex.pos or i, ex.of or #queue
  end
  return start(queue, nil, on_done)
end

-- Lessons for every module not yet complete, in order.
local function lesson_queue()
  local progress = require("vimgym.progress")
  local q = {}
  for _, mod in ipairs(require("vimgym.curriculum").modules) do
    if not progress.is_complete(mod.id) then
      for i, l in ipairs(mod.lessons) do
        table.insert(q, vim.tbl_extend("force", {}, l, {
          mode = "lesson", module = mod.id, section = mod.title,
          pos = i, of = #mod.lessons, last_in_module = i == #mod.lessons,
        }))
      end
    end
  end
  return q
end

local function all_done()
  vim.notify("Vim Gym: all modules complete. :VimGym practice <module> to keep training")
end

-- Runs from the current module through to the end of the curriculum.
function M.run_lessons()
  return start(lesson_queue(), nil, function(s)
    if s.index > #s.queue then all_done() end
  end)
end

-- Endless practice in rounds of n drills, with a summary after each round.
function M.run_practice(mod, n)
  local gen = require("vimgym.generators")
  local round = 0
  local function batch()
    round = round + 1
    local out = gen.batch(mod, n)
    for i, ex in ipairs(out) do
      ex.mode, ex.section, ex.pos, ex.of = "practice", mod.title .. " (round " .. round .. ")", i, n
    end
    return out
  end
  return start(batch(), function(s)
    local hits = 0
    for i = #s.results - n + 1, #s.results do
      local r = s.results[i]
      if r and r.ok and r.keys <= r.ex.par then hits = hits + 1 end
    end
    vim.notify(string.format("Vim Gym: round %d done, %d/%d at or under par. Next round...", round, hits, n))
    return batch()
  end)
end

-- One drill per module; stops at the first one over twice par, then carries
-- straight on into the lessons for the first module not placed out of.
function M.run_placement()
  local gen = require("vimgym.generators")
  local mods = require("vimgym.curriculum").modules
  local queue = {}
  for i, mod in ipairs(mods) do
    local ex = gen.drill(mod)
    ex.mode, ex.module, ex.section, ex.pos, ex.of = "placement", mod.id, "Placement: " .. mod.title, i, #mods
    table.insert(queue, ex)
  end
  local continued = false
  return start(queue, function(s)
    if continued then return nil end
    continued = true
    local placed = 0
    for _, r in ipairs(s.results) do if r.ok then placed = placed + 1 end end
    vim.notify(string.format("Vim Gym: placed past %d module(s). Starting lessons", placed))
    return lesson_queue()
  end, function(s)
    if s.index > #s.queue then all_done() end
  end)
end

return M
