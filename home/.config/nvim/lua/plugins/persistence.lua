return {
  "folke/persistence.nvim",
  lazy = false,
  opts = {},
  config = function(_, opts)
    require("persistence").setup(opts)
    local group = vim.api.nvim_create_augroup("persistence_auto_restore", { clear = true })

    vim.api.nvim_create_autocmd("User", {
      group = group,
      pattern = "VeryLazy",
      once = true,
      callback = function()
        local args = vim.fn.argv()
        if #args > 0 then
          for _, arg in ipairs(args) do
            if vim.fn.isdirectory(arg) == 0 then
              return
            end
          end
        end
        vim.schedule(function()
          require("persistence").load()
        end)
      end,
    })
  end,
}
