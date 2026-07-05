local config_path = vim.fn.stdpath("config") .. "/.markdownlint-cli2.yaml"

return {
  "mfussenegger/nvim-lint",
  opts = {
    linters = {
      ["markdownlint-cli2"] = {
        args = { "--config", config_path, "-" },
      },
    },
  },
}
