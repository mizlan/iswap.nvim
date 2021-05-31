local ts_utils = require('nvim-treesitter.ts_utils')
local util = require('iswap.util')

local M = {}

M.argts_ns = vim.api.nvim_create_namespace('argts')

function M.clear_namespace(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.argts_ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, M.argts_ns, 0, -1)
end

-- Given a range, grey everything in the window other than that range.
function M.grey_the_rest_out(bufnr, begin_exclude, end_exclude)
  local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  local top_line = win_info.topline - 1
  local bot_line = win_info.botline - 1
  M.clear_namespace(bufnr, M.argts_ns)
  vim.highlight.range(bufnr, M.argts_ns, 'ArgUnused', {top_line, 0}, begin_exclude)
  vim.highlight.range(bufnr, M.argts_ns, 'ArgUnused', end_exclude, {bot_line, -1})
end

-- Prompt user from NODES a total of TIMES times in BUFNR. CONFIG is used for
-- customization and ACTIVE_RANGE looks like {{row, col}, {row, col}} and is
-- used only to determine where to grey out
function M.prompt(bufnr, config, nodes, active_range, times)
  local keys = config.keys or 'asdfghjkl;'
  if #nodes > #keys then
    -- TODO: do something about this
    -- too many nodes, not enough keys, and I don't want to start using prefixes
    util.err('Too many nodes but not enough keys!')
    return
  end

  local range_start, range_end = unpack(active_range)
  if config.grey then
    M.grey_the_rest_out(bufnr, range_start, range_end)
  end

  local map = {}
  for i, node in ipairs(nodes) do
    local key = keys:sub(i, i)
    map[key] = node
    ts_utils.highlight_node(node, bufnr, M.argts_ns, config.hl_selection or 'Visual')
    local start_row, start_col = node:range()
    vim.api.nvim_buf_set_extmark(bufnr, M.argts_ns, start_row, start_col,
      { virt_text = { {key, "ArgSnipe" } }, virt_text_pos = "overlay", hl_mode = "blend" })
  end
  vim.cmd('redraw')

  local res = {}
  for i = 1, times do
    local keystr = util.getchar_handler(function() M.clear_namespace(bufnr) end)
    if keystr == nil then break end

    if map[keystr] ~= nil then
      table.insert(res, map[keystr])
    end
  end
  M.clear_namespace(bufnr, M.argts_ns)
  return res
end

return M
