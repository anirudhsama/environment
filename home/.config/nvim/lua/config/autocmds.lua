-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local function close_startup_snacks_pickers()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local ft = vim.bo[buf].filetype
    if ft and ft:match("^snacks_picker_") then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local ft = vim.bo[buf].filetype
    if ft and ft:match("^snacks_picker_") then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
  end
end

vim.api.nvim_create_autocmd("VimEnter", {
  group = vim.api.nvim_create_augroup("snacks_no_startup_picker", { clear = true }),
  once = true,
  callback = function()
    vim.schedule(close_startup_snacks_pickers)
  end,
})
