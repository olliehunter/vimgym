-- Headless test: every lesson and N random drills per generator must pass at exactly par.
-- Run from the repo root:  nvim --headless -u NONE --cmd "set rtp+=." -l tests/run.lua
local N = tonumber(os.getenv("VIMGYM_DRILLS") or "40")
vim.notify = function() end
require("vimgym").setup({ pass_delay = 0, data_path = vim.fn.tempname() .. ".json" })
local session = require("vimgym.session")
local gen = require("vimgym.generators")
local cur = require("vimgym.curriculum")

local function cnt(n, m) if n == 0 then return "" elseif n == 1 then return m else return n .. m end end

local function solve(ex)
  local k = ex.kind
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
  elseif k == "macro" then return 'qaI"\27A",\27jq' .. cnt(ex._n - 1, "@a")
  end
end

local fails, total = {}, 0
local function run(ex, keys)
  total = total + 1
  local res
  session._start({ ex }, "practice", function(r) res = r end)
  vim.api.nvim_feedkeys(keys, "xt", false)
  vim.wait(2000, function() return res ~= nil end, 10)
  if not res or not res[1] then
    table.insert(fails, ("NO PASS %s keys=%q"):format(ex.id, keys))
    session.stop()
  elseif res[1].keys ~= ex.par then
    table.insert(fails, ("PAR %s keys=%q counted=%d par=%d"):format(ex.id, keys, res[1].keys, ex.par))
  end
end

for _, m in ipairs(cur.modules) do
  for _, l in ipairs(m.lessons) do run(l, l.solution) end
end
for kind in pairs(gen.KINDS) do
  for _ = 1, N do
    local ex = gen.KINDS[kind]()
    ex.id, ex.kind = "gen:" .. kind, kind
    run(ex, solve(ex))
  end
end

for _, f in ipairs(fails) do print(f) end
print(("%d exercises, %d failures"):format(total, #fails))
os.exit(#fails == 0 and 0 or 1)
