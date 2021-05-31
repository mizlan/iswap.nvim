local ts_utils = require('nvim-treesitter.ts_utils')
local queries = require('nvim-treesitter.query')
local util = require('iswap.util')

local ft_to_lang = require('nvim-treesitter.parsers').ft_to_lang

local M = {}

--
function M.find(winnr)
  local bufnr = vim.fn.winbufnr(winnr)
  local cursor = vim.api.nvim_win_get_cursor(vim.fn.win_getid(winnr))
  local cursor_range = { cursor[1] - 1, cursor[2] }
  local row = cursor_range[1]
  local root = ts_utils.get_root_for_position(unpack(cursor_range))
  local ft = vim.api.nvim_buf_get_option(bufnr, 'filetype')
  local q = queries.get_query(ft_to_lang(ft), 'iswap-list')
  return q:iter_captures(root, bufnr, row, row + 1)
end

-- Get the closest parent that can be used as a list wherein elements can be
-- swapped.
function M.get_list_node_at_cursor(winnr)
  ret = nil
  local cursor = vim.api.nvim_win_get_cursor(vim.fn.win_getid(winnr))
  local cursor_range = { cursor[1] - 1, cursor[2] }
  for id, node, metadata in M.find(winnr) do
    local start_row, start_col, end_row, end_col = node:range()
    local start = { start_row, start_col }
    local end_ = { end_row, end_col }
    if util.within(start, cursor_range, end_) and node:named_child_count() > 0 then
      ret = node
    end
  end
  return ret
end

function M.attach(bufnr, lang)
  -- TODO: Fill this with what you need to do when attaching to a buffer
end

function M.detach(bufnr)
  -- TODO: Fill this with what you need to do when detaching from a buffer
end

return M