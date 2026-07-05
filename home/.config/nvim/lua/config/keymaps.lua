-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local settings = require("config.settings")
local escape_key = settings.escape_key

-- Disable arrow keys to enforce learning hjkl motions
local opts = { noremap = true, silent = true, desc = "Arrow keys disabled - use hjkl" }

vim.keymap.set({ "n", "i", "v", "t", "c" }, "<Up>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "t", "c" }, "<Down>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "t", "c" }, "<Left>", "<Nop>", opts)
vim.keymap.set({ "n", "i", "v", "t", "c" }, "<Right>", "<Nop>", opts)

-- Quick escape from insert/terminal/command-line/visual/select modes
vim.keymap.set("i", escape_key, "<Esc>", { noremap = true, silent = true, desc = "Exit insert mode" })
vim.keymap.set("t", escape_key, "<C-\\><C-n>", { noremap = true, silent = true, desc = "Exit terminal mode" })
vim.keymap.set("c", escape_key, "<C-c>", { noremap = true, silent = true, desc = "Exit command-line mode" })
vim.keymap.set("x", escape_key, "<Esc>", { noremap = true, silent = true, desc = "Exit visual/select mode" })
vim.keymap.set("s", escape_key, "<Esc>", { noremap = true, silent = true, desc = "Exit select mode" })
