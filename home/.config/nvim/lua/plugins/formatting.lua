-- Project-aware formatting: uses oxfmt when .oxfmtrc.json is present, falls back to prettier

return {
  "stevearc/conform.nvim",
  opts = function(_, opts)
    opts.formatters = opts.formatters or {}
    opts.formatters.oxfmt = {
      condition = function(self, ctx)
        return vim.fs.find(
          { ".oxfmtrc.json", ".oxfmtrc.jsonc" },
          { path = ctx.dirname, upward = true }
        )[1] ~= nil
      end,
    }

    local oxfmt_filetypes = {
      "css",
      "graphql",
      "handlebars",
      "html",
      "javascript",
      "javascriptreact",
      "json",
      "jsonc",
      "less",
      "scss",
      "typescript",
      "typescriptreact",
      "vue",
      "yaml",
    }

    opts.formatters_by_ft = opts.formatters_by_ft or {}
    for _, ft in ipairs(oxfmt_filetypes) do
      opts.formatters_by_ft[ft] = { "oxfmt", "prettier", stop_after_first = true }
    end
  end,
}
