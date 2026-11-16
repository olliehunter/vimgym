if vim.g.loaded_vimgym then return end
vim.g.loaded_vimgym = true

vim.api.nvim_create_user_command("VimGym", function(o)
  require("vimgym").command(o.fargs)
end, {
  nargs = "*",
  complete = function(arglead, cmdline)
    local parts = vim.split(cmdline, "%s+")
    if #parts >= 3 and parts[2] == "practice" then
      local ids = {}
      for _, m in ipairs(require("vimgym.curriculum").modules) do table.insert(ids, m.id) end
      return vim.tbl_filter(function(s) return s:find(arglead, 1, true) == 1 end, ids)
    end
    return vim.tbl_filter(function(s) return s:find(arglead, 1, true) == 1 end,
      { "start", "menu", "practice", "skip", "placement", "reset", "quit" })
  end,
})
