local ts_utils = require('nvim-treesitter.ts_utils')
local queries = require('nvim-treesitter.query')
local util = require('iswap.util')
local err = util.err

local ft_to_lang = require('nvim-treesitter.parsers').ft_to_lang

local M = {}

--
function M.find(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local cursor_range = { cursor[1] - 1, cursor[2] }
  local row = cursor_range[1]
  -- local root = ts_utils.get_root_for_position(unpack(cursor_range))
  -- NOTE: this root is freshly parsed, but this may not be the best way of getting a fresh parse
  --       see :h Query:iter_captures()
  local ft = vim.bo[bufnr].filetype
  local root = vim.treesitter.get_parser(bufnr, ft_to_lang(ft)):parse()[1]:root()
  local q = queries.get_query(ft_to_lang(ft), 'iswap-list')
  -- TODO: initialize correctly so that :ISwap is not callable on unsupported
  -- languages, if that's possible.
  if not q then
    err('Cannot query this filetype', true)
    return
  end
  return q:iter_captures(root, bufnr, row, row + 1)
end

-- Get the closest parent that can be used as a list wherein elements can be
-- swapped.
function M.get_list_node_at_cursor(winid, config)
  local ret = nil
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local cursor_range = { cursor[1] - 1, cursor[2] }
  local iswap_list_captures = M.find(winid)
  if not iswap_list_captures then
    -- query not supported
    return
  end
  for id, node, metadata in iswap_list_captures do
    err('found node', config.debug)
    local start_row, start_col, end_row, end_col = node:range()
    local start = { start_row, start_col }
    local end_ = { end_row, end_col }
    if util.within(start, cursor_range, end_) and node:named_child_count() > 0 then
      ret = node
    end
  end
  err('completed', config.debug)
  return ret
end


local function private_ts_utils_get_node_text(node, bufnr)
  local bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not node then
    return {}
  end

  -- We have to remember that end_col is end-exclusive
  local start_row, start_col, end_row, end_col = ts_utils.get_node_range(node)

  if start_row ~= end_row then
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
    lines[1] = string.sub(lines[1], start_col + 1)
    -- end_row might be just after the last line. In this case the last line is not truncated.
    if #lines == end_row - start_row + 1 then
      lines[#lines] = string.sub(lines[#lines], 1, end_col)
    end
    return lines
  else
    local line = vim.api.nvim_buf_get_lines(bufnr, start_row, start_row + 1, false)[1]
    -- If line is nil then the line is empty
    return line and { string.sub(line, start_col + 1, end_col) } or {}
  end
end

function M.swap_nodes_and_return_new_ranges(a, b, bufnr)
  local a_sr, a_sc = a:range()
  local b_sr, b_sc = b:range()

  -- [1] first appearing node should be `a`, so swap for convenience
  local HAS_SWAPPED = false
  if not util.compare_position({a_sr, a_sc}, {b_sr, b_sc}) then
    a, b = b, a
    HAS_SWAPPED = true
  end

  local range1 = ts_utils.node_to_lsp_range(a)
  local range2 = ts_utils.node_to_lsp_range(b)

  local text1 = private_ts_utils_get_node_text(a, bufnr)
  local text2 = private_ts_utils_get_node_text(b, bufnr)

  ts_utils.swap_nodes(a, b, bufnr)

  local char_delta = 0
  local line_delta = 0
  if
    range1["end"].line < range2.start.line
    or (range1["end"].line == range2.start.line and range1["end"].character < range2.start.character)
  then
    line_delta = #text2 - #text1
  end

  if range1["end"].line == range2.start.line and range1["end"].character < range2.start.character then
    if line_delta ~= 0 then
      --- why?
      --correction_after_line_change =  -range2.start.character
      --text_now_before_range2 = #(text2[#text2])
      --space_between_ranges = range2.start.character - range1["end"].character
      --char_delta = correction_after_line_change + text_now_before_range2 + space_between_ranges
      --- Equivalent to:
      char_delta = #text2[#text2] - range1["end"].character

      -- add range1.start.character if last line of range1 (now text2) does not start at 0
      if range1.start.line == range2.start.line + line_delta then
        char_delta = char_delta + range1.start.character
      end
    else
      char_delta = #text2[#text2] - #text1[#text1]
    end
  end

  -- now let a = first one (text2), b = second one (text1)
  -- (opposite of what it used to be)

  local a_sr = range1.start.line
  local a_sc = range1.start.character
  local a_er = a_sr + #text2 - 1
  local a_ec = (#text2 > 1) and #text2[#text2] or a_sc + #text2[#text2]
  local b_sr = range2.start.line + line_delta
  local b_sc = range2.start.character + char_delta
  local b_er = b_sr + #text1 - 1
  local b_ec = (#text1 > 1) and #text1[#text1] or b_sc + #text1[#text1]

  local a_data = { a_sr, a_sc, a_er, a_ec }
  local b_data = { b_sr, b_sc, b_er, b_ec }

  -- undo [1]'s swapping
  if HAS_SWAPPED then
    a_data, b_data = b_data, a_data
  end

  return { a_data, b_data }
end

function M.attach(bufnr, lang)
  -- TODO: Fill this with what you need to do when attaching to a buffer
end

function M.detach(bufnr)
  -- TODO: Fill this with what you need to do when detaching from a buffer
end

return M
