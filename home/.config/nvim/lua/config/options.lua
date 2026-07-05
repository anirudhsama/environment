-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Prioritize .git for root detection (always use monorepo root)
vim.g.root_spec = { { ".git" }, "lsp", "cwd" }
