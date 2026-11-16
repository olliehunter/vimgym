-- Headless tests. Run from the repo root:
--   nvim --headless -u NONE --cmd "set rtp+=." -l tests/run.lua
-- 1. Every lesson, and N random drills per generator, pass at exactly par.
-- 2. Every macro variant passes at par.
-- 3. Session flow: lessons roll through every module, practice runs in rounds,
--    placement carries on into lessons, and :q ends a session without errors.
local N = tonumber(os.getenv("VIMGYM_DRILLS") or "40")
vim.notify = function() end
require("vimgym").setup({ pass_delay = 0, data_path = vim.fn.tempname() .. ".json" })
local session = require("vimgym.session")
local progress = require("vimgym.progress")
local gen = require("vimgym.generators")
local cur = require("vimgym.curriculum")

local function cnt(n, m) if n == 0 then return "" elseif n == 1 then return m else return n .. m end end

local function solve(ex)
  local k = ex.kind
  if ex._solution then return ex._solution end
  if k == "hjkl" then
    local dr = ex.target_cursor[1] - ex.cursor[1]
    local landed = math.min(ex.cursor[2], #ex.start[ex.target_cursor[1]] - 1)
    local dc = ex.target_cursor[2] - landed
    return cnt(math.abs(dr), dr > 0 and "j" or "k") .. cnt(math.abs(dc), dc > 0 and "l" or "h")
  elseif k == "words" then
    local starts, c = {}, 0
    for w in ex.start[1]:gmatch("%S+") do table.insert(starts, c); c = c + #w + 1 end
    local i, j
    for x, v in ipairs(starts) do
      if v == ex.cursor[2] then i = x end
      if v == ex.target_cursor[2] then j = x end
    end
    return cnt(math.abs(j - i), j > i and "w" or "b")
  elseif k == "find" then
    if ex._eol then return "$" end
    return "f" .. ex.start[1]:sub(ex.target_cursor[2] + 1, ex.target_cursor[2] + 1)
  elseif k == "dw" then return cnt(ex._i - 1, "w") .. "dw"
  elseif k == "dd" then return cnt(ex._s - 1, "j") .. cnt(ex._n, "dd")
  elseif k == "ciw" then return "ciw" .. ex._new .. "\27"
  elseif k == "textobj" then return "di" .. ex._open
  end
end

local fails, total = {}, 0
local function fail(msg) table.insert(fails, msg) end

local function run(ex, keys)
  total = total + 1
  local res
  session._start({ ex }, function(s) res = s.results end)
  vim.api.nvim_feedkeys(keys, "xt", false)
  vim.wait(2000, function() return res ~= nil end, 10)
  if not res or not res[1] then
    fail(("NO PASS %s keys=%q"):format(ex.id, keys))
    session.stop()
  elseif res[1].keys ~= ex.par then
    fail(("PAR %s keys=%q counted=%d par=%d"):format(ex.id, keys, res[1].keys, ex.par))
  end
end

-- 1. Lessons and random drills
for _, m in ipairs(cur.modules) do
  for _, l in ipairs(m.lessons) do run(vim.deepcopy(l), l.solution) end
end
for kind in pairs(gen.KINDS) do
  for _ = 1, N do
    local ex = gen.KINDS[kind]()
    ex.id, ex.kind = "gen:" .. kind .. ":" .. (ex.variant or ""), kind
    run(ex, solve(ex))
  end
end

-- 2. Every macro variant, at least 5 times each
local seen, want = {}, #gen.MACROS + 1
local tries = 0
while tries < 2000 do
  tries = tries + 1
  local ex = gen.KINDS.macro()
  seen[ex.variant] = (seen[ex.variant] or 0) + 1
  if seen[ex.variant] <= 5 then
    ex.id, ex.kind = "gen:macro:" .. ex.variant, "macro"
    run(ex, solve(ex))
  end
  local done = 0
  for _, c in pairs(seen) do if c >= 5 then done = done + 1 end end
  if done == want then break end
end
local nvariants = 0
for _ in pairs(seen) do nvariants = nvariants + 1 end
if nvariants ~= want then fail(("MACRO VARIANTS saw %d of %d"):format(nvariants, want)) end

-- 3. Session flow
local function current()
  local S = session._state()
  return S and not S.done and S.queue[S.index] or nil
end

local function wait_for(pred, what)
  if not vim.wait(3000, pred, 10) then fail("TIMEOUT waiting for " .. what) return false end
  return true
end

-- 3a. :VimGym start runs every lesson of every module in one session
total = total + 1
progress.reset()
session.run_lessons()
local tab = session._state().tab
local ran = 0
for _, m in ipairs(cur.modules) do
  for _, l in ipairs(m.lessons) do
    if not wait_for(function() local c = current() return c and c.id == l.id end, "lesson " .. l.id) then break end
    if session._state().tab ~= tab then fail("FLOW new tab opened at " .. l.id) end
    vim.api.nvim_feedkeys(l.solution, "xt", false)
    ran = ran + 1
  end
end
wait_for(function() return session._state() == nil end, "lessons session to finish")
for _, m in ipairs(cur.modules) do
  if not progress.is_complete(m.id) then fail("FLOW module not completed: " .. m.id) end
end

-- 3b. Practice runs in rounds and keeps going
total = total + 1
session.run_practice(cur.modules[2], 2)
for i = 1, 3 do
  if not wait_for(function() return current() ~= nil end, "practice drill " .. i) then break end
  vim.api.nvim_feedkeys(solve(current()), "xt", false)
  wait_for(function() local S = session._state() return S and S.index > i end, "practice to advance past " .. i)
end
local S = session._state()
if not S then fail("PRACTICE session ended after a round")
elseif not current() or not current().section:find("round 2", 1, true) then fail("PRACTICE no round 2") end
session.stop()

-- 3c. Placement stops at a failure and carries on into lessons
total = total + 1
progress.reset()
session.run_placement()
wait_for(function() return current() ~= nil end, "placement drill")
local first = current()
vim.api.nvim_feedkeys(string.rep("zz", first.par + 1), "xt", false) -- no-op keys, over twice par
wait_for(function() local c = current() return c and c.mode == "lesson" end, "lessons after placement")
local c = current()
if not c or c.module ~= cur.modules[1].id then fail("PLACEMENT did not continue into module 1 lessons") end
session.stop()

-- 3d. :q in the drill window ends the session cleanly
total = total + 1
progress.reset()
session.run_lessons()
wait_for(function() return current() ~= nil end, "lesson for :q test")
vim.v.errmsg = ""
local tabs_before = #vim.api.nvim_list_tabpages()
vim.api.nvim_feedkeys(":q\r", "xt", false)
wait_for(function() return session._state() == nil end, "session to end after :q")
vim.wait(100)
if vim.v.errmsg ~= "" then fail("QUIT error: " .. vim.v.errmsg) end
if #vim.api.nvim_list_tabpages() ~= tabs_before - 1 then fail("QUIT session tab left open") end

for _, f in ipairs(fails) do print(f) end
print(("%d exercises and flow tests, %d failures"):format(total, #fails))
os.exit(#fails == 0 and 0 or 1)
