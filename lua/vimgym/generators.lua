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

-- Macro drills: the same edit on every line. `line` returns a start/target pair,
-- `body` is the reference recording (it must end on the next line, ready to
-- replay). Par = qa + body + q + {n-1}@a. Keys are counted one per character.
local MACROS = {
  { name = "quote", title = "Quote and comma", hint = 'Wrap each line as "word",',
    line = function() local w = pick(WORDS) return w, '"' .. w .. '",' end,
    body = 'I"\27A",\27j' },
  { name = "semicolon", title = "Semicolons", hint = "Add ; to the end of every line",
    line = function()
      local s = "local " .. pick(WORDS) .. " = " .. math.random(1, 99)
      return s, s .. ";"
    end,
    body = "A;\27j" },
  { name = "bullet", title = "Bullet list", hint = "Turn every line into a '- ' bullet",
    line = function() local s = table.concat(sentence(2), " ") return s, "- " .. s end,
    body = "I- \27j" },
  { name = "upper", title = "Uppercase", hint = "Uppercase the first word of every line",
    line = function() local w = sentence(2) return table.concat(w, " "), w[1]:upper() .. " " .. w[2] end,
    body = "gUiwj" },
  { name = "label", title = "Strip labels", hint = "Delete the 'key: ' label from every line",
    line = function() local k, v = pick(WORDS), pick(WORDS) return k .. ": " .. v, v end,
    body = "dWj" },
  { name = "call", title = "Wrap in a call", hint = "Wrap every line in print(...)",
    line = function() local w = pick(WORDS) return w, "print(" .. w .. ")" end,
    body = "Iprint(\27A)\27j" },
  { name = "comment", title = "Strip comments", hint = "Remove the trailing -- comment from every line",
    line = function()
      local s = pick(WORDS) .. " = " .. math.random(1, 99)
      return s .. " -- " .. pick(WORDS), s
    end,
    body = "0f-hDj" },
}
M.MACROS = MACROS

local function count_prefix(n, motion)
  if n <= 0 then return "" elseif n == 1 then return motion else return n .. motion end
end

function KINDS.macro()
  local v = math.random(#MACROS + 1)
  if v > #MACROS then
    -- Numbered list: copy the line down and increment, building it up from one line
    local n = math.random(5, 9)
    local word = pick(WORDS)
    local target = {}
    for i = 1, n do target[i] = word .. " " .. i end
    return { title = "Macro: Numbered list", variant = "increment",
      hint = "Build the list from line 1 (yyp, <C-a>), record once, replay with a count",
      start = { word .. " 1" }, cursor = { 1, 0 }, target = target,
      par = 7 + cost(n - 2, 2), _solution = "qayyp\1q" .. count_prefix(n - 2, "@a") }
  end
  local m = MACROS[v]
  local n = math.random(5, 9)
  local start, target = {}, {}
  for i = 1, n do start[i], target[i] = m.line() end
  return { title = "Macro: " .. m.title, variant = m.name,
    hint = m.hint .. " (record on line 1, replay with a count)",
    start = start, cursor = { 1, 0 }, target = target,
    par = 3 + #m.body + cost(n - 1, 2), _solution = "qa" .. m.body .. "q" .. count_prefix(n - 1, "@a") }
end

function M.drill(mod)
  local kind = pick(mod.drills)
  local ex = KINDS[kind]()
  ex.id = "gen:" .. kind .. (ex.variant and (":" .. ex.variant) or "")
  ex.kind = kind
  return ex
end

function M.batch(mod, n)
  local out = {}
  for i = 1, n do out[i] = M.drill(mod) end
  return out
end

return M
