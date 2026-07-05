local staged_status = {
  staged_new = true,
  staged_modified = true,
  staged_deleted = true,
  renamed = true,
}

local status_map = {
  untracked = "untracked",
  modified = "modified",
  deleted = "deleted",
  renamed = "renamed",
  staged_new = "added",
  staged_modified = "modified",
  staged_deleted = "deleted",
  ignored = "ignored",
  unknown = "untracked",
}

local current_file_cache = nil
local last_indexed_dir = nil

local function ensure_indexed(dir)
  local file_picker = require("fff.file_picker")
  if not file_picker.is_initialized() then
    file_picker.setup()
  end
  if last_indexed_dir ~= dir then
    require("fff").change_indexing_directory(dir)
    last_indexed_dir = dir
  end
end

-- fff.nvim no longer exposes an absolute `path` on result items; only
-- `relative_path`. Anchor it against the indexer's base_path.
local function resolve_path(relative_path)
  if not relative_path or relative_path == "" then
    return nil
  end
  if vim.fn.fnamemodify(relative_path, ":p") == relative_path then
    return relative_path
  end
  local base = require("fff.conf").get().base_path
  if not base or base == "" then
    return relative_path
  end
  return vim.fs.normalize(base .. "/" .. relative_path)
end

---@type snacks.picker.finder
local function fff_file_finder(opts, ctx)
  local file_picker = require("fff.file_picker")

  if not current_file_cache then
    local buf = vim.api.nvim_get_current_buf()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name ~= "" and vim.fn.filereadable(name) == 1 then
        current_file_cache = name
      end
    end
  end

  local results = file_picker.search_files(ctx.filter.search, current_file_cache, 10000, nil, nil)

  ---@type snacks.picker.finder.Item[]
  local items = {}
  for _, r in ipairs(results) do
    ---@type snacks.picker.finder.Item
    local item = {
      text = r.name,
      file = resolve_path(r.relative_path),
      score = r.total_frecency_score,
    }
    if status_map[r.git_status] then
      item.status = {
        status = status_map[r.git_status],
        staged = staged_status[r.git_status] or false,
        unmerged = r.git_status == "unmerged",
      }
    end
    items[#items + 1] = item
  end

  return items
end

---@type snacks.picker.finder
local function fff_grep_finder(opts, ctx)
  local query = ctx.filter.search
  if query == "" then
    return {}
  end

  local mode = opts.fuzzy and "fuzzy" or opts.regex and "regex" or "plain"

  local grep = require("fff.grep")
  local result = grep.search(query, 0, 10000, nil, mode)

  ---@type snacks.picker.finder.Item[]
  local items = {}
  for _, r in ipairs(result.items or {}) do
    local file = resolve_path(r.relative_path)
    items[#items + 1] = {
      text = r.line_content or file,
      file = file,
      pos = { r.line_number or 1, (r.col or 0) + 1 },
      line = r.line_content,
    }
  end

  return items
end

local function format_git_status(item, picker)
  local ret = {} ---@type snacks.picker.Highlight[]
  local status = item.status

  local hl = "SnacksPickerGitStatus"
  if status.unmerged then
    hl = "SnacksPickerGitStatusUnmerged"
  elseif status.staged then
    hl = "SnacksPickerGitStatusStaged"
  else
    hl = "SnacksPickerGitStatus" .. status.status:sub(1, 1):upper() .. status.status:sub(2)
  end

  local icon = picker.opts.icons.git[status.status]
  if status.staged then
    icon = picker.opts.icons.git.staged
  end

  ret[#ret + 1] = { icon, hl }
  ret[#ret + 1] = { " ", virtual = true }
  return ret
end

local function format_file(item, picker)
  ---@type snacks.picker.Highlight[]
  local ret = {}
  if item.status then
    vim.list_extend(ret, format_git_status(item, picker))
  else
    ret[#ret + 1] = { "  ", virtual = true }
  end
  vim.list_extend(ret, require("snacks.picker.format").filename(item, picker))
  return ret
end

local function format_grep(item, picker)
  ---@type snacks.picker.Highlight[]
  local ret = {}
  vim.list_extend(ret, require("snacks.picker.format").filename(item, picker))
  if item.line then
    Snacks.picker.highlight.format(item, item.line, ret)
    ret[#ret + 1] = { " " }
  end
  return ret
end

local function open_files(dir)
  ensure_indexed(dir)
  Snacks.picker({
    title = "FFFiles (" .. vim.fn.fnamemodify(dir, ":~") .. ")",
    finder = fff_file_finder,
    format = format_file,
    on_close = function()
      current_file_cache = nil
    end,
    live = true,
    matcher = { sort = false },
  })
end

local function open_grep(dir)
  ensure_indexed(dir)
  Snacks.picker({
    title = "FFF Grep (" .. vim.fn.fnamemodify(dir, ":~") .. ")",
    finder = fff_grep_finder,
    format = format_grep,
    live = true,
    fuzzy = true,
    regex = false,
    matcher = { sort = false },
  })
end

return {
  "dmtrKovalenko/fff.nvim",
  dependencies = { "folke/snacks.nvim" },
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = false,
  opts = {},
  config = function(_, opts)
    require("fff").setup(opts)
    -- Pre-index on startup so the picker is ready immediately
    vim.api.nvim_create_autocmd("User", {
      pattern = "VeryLazy",
      once = true,
      callback = function()
        ensure_indexed(LazyVim.root())
      end,
    })
  end,
  keys = {
    { "<leader><space>", function() open_files(LazyVim.root()) end, desc = "FFF Find files (root)" },
    { "<leader>ff", function() open_files(LazyVim.root()) end, desc = "FFF Find files (root)" },
    { "<leader>fF", function() open_files(vim.fn.getcwd()) end, desc = "FFF Find files (cwd)" },
    { "<leader>/", function() open_grep(LazyVim.root()) end, desc = "FFF Grep (root)" },
  },
}
