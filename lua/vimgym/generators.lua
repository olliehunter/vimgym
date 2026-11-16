-- Random drill generators. Each returns an exercise with par computed for the
-- intended technique, plus fields the test suite uses to build a solution.
local M = {}
math.randomseed(os.time())

local WORDS = {
  "alpha", "bravo", "charlie", "delta", "echo", "foxtrot", "golf", "hotel", "india", "juliet",
  "kilo", "lima", "mike", "november", "oscar", "papa", "quebec", "romeo", "sierra", "tango",
}

local function pick(t) return t[math.random(#t)] end
local function sentence(n) local w = {} for i = 1, n do w[i] = pick(WORDS) end return w end
local function word_starts(words)
  local cols, c = {}, 0
  for i, w in ipairs(words) do cols[i] = c; c = c + #w + 1 end
  return cols
end
-- Keystrokes for "{n}{motion}"; no count when n is 1
local function cost(n, motion_len)
  motion_len = motion_len or 1
  if n == 0 then return 0 end
  if n == 1 then return motion_len end
  return #tostring(n) + motion_len
end

local KINDS = {}
M.KINDS = KINDS

function KINDS.hjkl()
  local lines = {}
  for i = 1, 6 do lines[i] = table.concat(sentence(4), " ") end
  local r1, c1, r2, c2
  repeat
    r1, r2 = math.random(6), math.random(6)
    c1, c2 = math.random(0, #lines[r1] - 1), math.random(0, #lines[r2] - 1)
  until r1 ~= r2 or c1 ~= c2
  local landed = math.min(c1, #lines[r2] - 1) -- j/k keep the column, clamped
  return { title = "hjkl", hint = "Reach the highlight with hjkl and counts",
    start = lines, cursor = { r1, c1 }, target_cursor = { r2, c2 },
    par = cost(math.abs(r2 - r1)) + cost(math.abs(c2 - landed)) }
end

function KINDS.words()
  local w = sentence(8)
  local cols = word_starts(w)
  local i, j
  repeat i, j = math.random(8), math.random(8) until i ~= j
  return { title = "Word motions", hint = "w / b with counts",
    start = { table.concat(w, " ") }, cursor = { 1, cols[i] }, target_cursor = { 1, cols[j] },
    par = cost(math.abs(j - i)) }
end

function KINDS.find()
  local line = table.concat(sentence(6), " ")
  if math.random() < 0.25 then
    return { title = "End of line", hint = "$", start = { line }, cursor = { 1, 0 },
      target_cursor = { 1, #line - 1 }, par = 1, _eol = true }
  end
  local col, ch
  repeat
    col = math.random(math.floor(#line / 3), #line - 2)
    ch = line:sub(col + 1, col + 1)
  until ch ~= " " and not line:sub(2, col):find(ch, 1, true)
  return { title = "Find", hint = "f{char}", start = { line }, cursor = { 1, 0 },
    target_cursor = { 1, col }, par = 2 }
end

function KINDS.dw()
  local w = sentence(7)
  local i = math.random(1, 6) -- never the last word
  local out = vim.deepcopy(w)
  table.remove(out, i)
  return { title = "Delete a word", hint = "Delete '" .. w[i] .. "' (move, then dw)",
    start = { table.concat(w, " ") }, cursor = { 1, 0 }, target = { table.concat(out, " ") },
    par = cost(i - 1) + 2, _i = i }
end

function KINDS.dd()
  local lines = {}
  for i = 1, 8 do lines[i] = table.concat(sentence(3), " ") end
  local s, n = math.random(2, 6), math.random(1, 3)
  local out = {}
  for i, l in ipairs(lines) do
    if i < s or i >= s + n then table.insert(out, l) end
  end
  return { title = "Delete lines", hint = string.format("Delete lines %d-%d", s, s + n - 1),
    start = lines, cursor = { 1, 0 }, target = out, par = cost(s - 1) + cost(n, 2), _s = s, _n = n }
end

function KINDS.ciw()
  local w = sentence(6)
  local cols = word_starts(w)
  local i, new = math.random(6), nil
  repeat new = pick(WORDS) until new ~= w[i]
  local out = vim.deepcopy(w)
  out[i] = new
  return { title = "Change a word", hint = "'" .. w[i] .. "' -> '" .. new .. "' with ciw",
    start = { table.concat(w, " ") }, cursor = { 1, cols[i] + math.floor(#w[i] / 2) },
    target = { table.concat(out, " ") }, par = 3 + #new + 1, _new = new }
end

function KINDS.textobj()
  local p = pick({ { "(", ")" }, { "{", "}" }, { "[", "]" }, { '"', '"' } })
  local inner = table.concat(sentence(3), ", ")
  local pre = pick({ "call", "fn", "print", "run" })
  local open_col = #pre + 1
  return { title = "Text objects", hint = "Empty the " .. p[1] .. p[2] .. " (di" .. p[1] .. ")",
    start = { pre .. " " .. p[1] .. inner .. p[2] .. " end" },
    cursor = { 1, open_col + math.random(1, #inner) },
    target = { pre .. " " .. p[1] .. p[2] .. " end" }, par = 3, _open = p[1] }
end

function KINDS.macro()
  local n = math.random(5, 9)
  local start, target = {}, {}
  for i = 1, n do
    local w = pick(WORDS)
    start[i], target[i] = w, '"' .. w .. '",'
  end
  return { title = "Macro", hint = 'Wrap each line as "word", (record on line 1, replay with a count)',
    start = start, cursor = { 1, 0 }, target = target, par = 11 + cost(n - 1, 2), _n = n }
end

function M.drill(mod)
  local kind = pick(mod.drills)
  local ex = KINDS[kind]()
  ex.id = "gen:" .. kind
  ex.kind = kind
  return ex
end

function M.batch(mod, n)
  local out = {}
  for i = 1, n do out[i] = M.drill(mod) end
  return out
end

return M
