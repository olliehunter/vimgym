local M = {}
local state

local function path()
  return require("vimgym").config.data_path
    or vim.fs.joinpath(vim.fn.stdpath("data"), "vimgym.json")
end

local function load()
  if state then return state end
  local f = io.open(path(), "r")
  if f then
    local ok, data = pcall(vim.json.decode, f:read("*a"))
    f:close()
    state = ok and type(data) == "table" and data or nil
  end
  state = state or {}
  state.modules = state.modules or {}
  state.best = state.best or {}
  return state
end

local function save()
  local p = path()
  vim.fn.mkdir(vim.fn.fnamemodify(p, ":h"), "p")
  local f = assert(io.open(p, "w"))
  f:write(vim.json.encode(state))
  f:close()
end

function M.is_complete(id) return load().modules[id] ~= nil end

function M.is_unlocked(id)
  local mods = require("vimgym.curriculum").modules
  for i, mod in ipairs(mods) do
    if mod.id == id then return i == 1 or M.is_complete(mods[i - 1].id) end
  end
  return false
end

function M.complete(id, how)
  load().modules[id] = how or "passed"
  save()
end

-- Record best keystroke count; returns true on a new best.
function M.record(id, keys)
  local s = load()
  local prev = s.best[id]
  if not prev or keys < prev then
    s.best[id] = keys
    save()
    return true
  end
  return false
end

function M.reset()
  state = { modules = {}, best = {} }
  save()
end

return M
