-- Lessons: start (lines), cursor {row 1-based, col 0-based}, target (lines) and/or
-- target_cursor, par (minimum keystrokes), solution (used by the test suite).
local M = {}

M.modules = {
  {
    id = "basics", title = "1. hjkl and counts", drills = { "hjkl" },
    lessons = {
      { id = "basics:1", title = "Down one line", hint = "j moves down",
        start = { "hello world", "second line" }, cursor = { 1, 0 }, target_cursor = { 2, 0 }, par = 1, solution = "j" },
      { id = "basics:2", title = "Counts", hint = "4l moves right four",
        start = { "hello world" }, cursor = { 1, 0 }, target_cursor = { 1, 4 }, par = 2, solution = "4l" },
    },
  },
  {
    id = "words", title = "2. Word motions", drills = { "words" },
    lessons = {
      { id = "words:1", title = "Forward by word", hint = "3w jumps three words",
        start = { "the quick brown fox jumps" }, cursor = { 1, 0 }, target_cursor = { 1, 16 }, par = 2, solution = "3w" },
      { id = "words:2", title = "Back by word", hint = "2b jumps back two",
        start = { "the quick brown fox jumps" }, cursor = { 1, 16 }, target_cursor = { 1, 4 }, par = 2, solution = "2b" },
    },
  },
  {
    id = "line", title = "3. Within a line: ^ $ f", drills = { "find" },
    lessons = {
      { id = "line:1", title = "First non-blank", hint = "^",
        start = { "  indented line here;" }, cursor = { 1, 10 }, target_cursor = { 1, 2 }, par = 1, solution = "^" },
      { id = "line:2", title = "End of line", hint = "$",
        start = { "  indented line here;" }, cursor = { 1, 2 }, target_cursor = { 1, 20 }, par = 1, solution = "$" },
      { id = "line:3", title = "Find a character", hint = "f* jumps to the next *",
        start = { "let total = price * qty" }, cursor = { 1, 0 }, target_cursor = { 1, 18 }, par = 2, solution = "f*" },
    },
  },
  {
    id = "operators", title = "4. Delete: dw and dd", drills = { "dw", "dd" },
    lessons = {
      { id = "operators:1", title = "Delete a word", hint = "dw",
        start = { "delete this word please" }, cursor = { 1, 7 }, target = { "delete word please" }, par = 2, solution = "dw" },
      { id = "operators:2", title = "Delete a line", hint = "dd",
        start = { "keep", "remove me", "keep too" }, cursor = { 2, 0 }, target = { "keep", "keep too" }, par = 2, solution = "dd" },
    },
  },
  {
    id = "change", title = "5. Change: ciw", drills = { "ciw" },
    lessons = {
      { id = "change:1", title = "Change inner word", hint = "ciw blue <Esc>",
        start = { "the colour is red" }, cursor = { 1, 15 }, target = { "the colour is blue" }, par = 8, solution = "ciwblue\27" },
    },
  },
  {
    id = "textobjects", title = "6. Text objects", drills = { "textobj" },
    lessons = {
      { id = "textobjects:1", title = "Inside quotes", hint = 'di"',
        start = { 'print("hello world")' }, cursor = { 1, 9 }, target = { 'print("")' }, par = 3, solution = 'di"' },
      { id = "textobjects:2", title = "Inside brackets", hint = "di(",
        start = { "fn(a, b, c)" }, cursor = { 1, 4 }, target = { "fn()" }, par = 3, solution = "di(" },
    },
  },
  {
    id = "macros", title = "7. Macros", drills = { "macro" },
    lessons = {
      { id = "macros:1", title = "Record and replay", hint = 'qa I"<Esc>A",<Esc>j q, then 3@a',
        start = { "one", "two", "three", "four" }, cursor = { 1, 0 },
        target = { '"one",', '"two",', '"three",', '"four",' }, par = 14, solution = 'qaI"\27A",\27jq3@a' },
    },
  },
}

function M.get(id)
  for _, mod in ipairs(M.modules) do
    if mod.id == id then return mod end
  end
end

return M
