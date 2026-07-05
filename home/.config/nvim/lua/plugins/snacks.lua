local settings = require("config.settings")
local escape_key = settings.escape_key

return {
  "folke/snacks.nvim",
  opts = {
    dashboard = {
      preset = {
        -- You can customize the header (ASCII art) here
        header = [[
 ███╗   ██╗███████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
 ████╗  ██║██╔════╝██╔═══██╗██║   ██║██║████╗ ████║
 ██╔██╗ ██║█████╗  ██║   ██║██║   ██║██║██╔████╔██║
 ██║╚██╗██║██╔══╝  ██║   ██║╚██╗ ██╔╝██║██║╚██╔╝██║
 ██║ ╚████║███████╗╚██████╔╝ ╚████╔╝ ██║██║ ╚═╝ ██║
 ╚═╝  ╚═══╝╚══════╝ ╚═════╝   ╚═══╝  ╚═╝╚═╝     ╚═╝
        ]],
      },
    },
    picker = {
      enabled = true,
      ui_select = true,
      sources = {
        files = {
          hidden = true,
        },
      },
      -- Show ~ for fuzzy, R for regex in the picker title {flags}
      toggles = {
        fuzzy = { icon = "~", value = true },
        regex = { icon = "R", value = true },
      },
      actions = {
        stopinsert = function()
          vim.cmd("stopinsert")
        end,
        -- Cycle: fuzzy → plain → regex → fuzzy (mirrors fff's <S-Tab>)
        cycle_search_mode = function(picker)
          if picker.opts.fuzzy then
            picker.opts.fuzzy = false
            picker.opts.regex = false
          elseif not picker.opts.regex then
            picker.opts.fuzzy = false
            picker.opts.regex = true
          else
            picker.opts.fuzzy = true
            picker.opts.regex = false
          end
          picker.list:set_target()
          picker:find()
        end,
      },
      win = {
        input = {
          keys = {
            -- Disable arrow keys
            ["<Up>"] = { "", mode = { "n", "i" } },
            ["<Down>"] = { "", mode = { "n", "i" } },
            ["<Left>"] = { "", mode = { "n", "i" } },
            ["<Right>"] = { "", mode = { "n", "i" } },
            -- Cycle search mode: fuzzy → plain → regex (like fff's <S-Tab>)
            ["<S-Tab>"] = { "cycle_search_mode", mode = { "n", "i" } },
          },
        },
        list = {
          keys = {
            -- Disable arrow keys
            ["<Up>"] = { "", mode = { "n", "i" } },
            ["<Down>"] = { "", mode = { "n", "i" } },
            ["<Left>"] = { "", mode = { "n", "i" } },
            ["<Right>"] = { "", mode = { "n", "i" } },
          },
        },
      },
    },
  },
}
