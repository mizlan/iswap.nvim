local ts_utils = require('nvim-treesitter.ts_utils')
local queries = require('nvim-treesitter.query')
local util = require('iswap.util')
local err = util.err

local ft_to_lang = require('nvim-treesitter.parsers').ft_to_lang

local M = {}

-- certain lines of code below are taken from nvim-treesitter where i
-- had to modify the function body of an existing function in ts_utils

--
function M.find(winid, cursor_range)
  local bufnr = vim.api.nvim_get_current_buf()
  local sr, er = cursor_range[1], cursor_range[3]
  er = (er and (er + 1)) or (sr + 1)
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
  return q:iter_captures(root, bufnr, sr, er)
end

-- Returns ancestors from inside to outside
function M.get_ancestors_at_cursor(cur_node, only_current_line, config)
  local parent = cur_node:parent()

  if not parent then
    err('did not find a satisfiable parent node', config.debug)
    return
  end

  -- pick parent recursive for current line
  local ancestors = { cur_node }
  local prev_parent = cur_node
  local current_row = parent:start()
  local last_row, last_col

  -- only get parents - for current line
  while parent and (not only_current_line or parent:start() == current_row) do
    last_row, last_col = prev_parent:start()
    local s_row, s_col = parent:start()

    if last_row == s_row and last_col == s_col then
      -- new parent has same start as last one. Override last one
      if util.has_siblings(parent) and parent:type() ~= 'comment' then
        -- only add if it has >0 siblings and is not comment node
        -- (override previous since same start position)
        ancestors[#ancestors] = parent
      end
    else
      table.insert(ancestors, parent)
      last_row = s_row
      last_col = s_col
    end
    prev_parent = parent
    parent = parent:parent()
  end

  -- TODO: use the list query to find initial chosen ancestor
  local initial = 1
  local lists = M.get_list_nodes_at_cursor(vim.api.nvim_get_current_win(), config, true)
  if lists and #lists >= 1 then
    for j, ancestor in ipairs(ancestors) do
      if ancestor:parent() and ancestor:parent() == lists[1][1] then
        initial = j
        err('found list ancestor', config.debug)
      end
    end
  end

  return ancestors, last_row, initial
end

-- returns list_nodes
function M.get_list_nodes_at_cursor(winid, config, needs_cursor_node)
  local cursor_range = util.get_cursor_range(winid)
  local visual_sel = #cursor_range > 2

  local ret = {}
  local iswap_list_captures = M.find(winid, cursor_range)
  if not iswap_list_captures then
    -- query not supported
    return
  end

  for id, node, metadata in iswap_list_captures do
    err('found node', config.debug)
    if util.node_intersects_range(node, cursor_range) and node:named_child_count() > 1 then
      local children = ts_utils.get_named_children(node)
      if needs_cursor_node then
        local cur_nodes = util.nodes_containing_range(children, cursor_range)
        if #cur_nodes >= 1 then
          if #cur_nodes > 1 then err('multiple found, using first', config.debug) end
          ret[#ret + 1] = { node, children, cur_nodes[1] }
        end
      else
        local r = { node, children }
        if visual_sel and config.visual_select_list then
          if
            util.node_is_range(node, cursor_range)
            or #util.range_containing_nodes(children, cursor_range) == #children
          then
            -- The visual selection is equivalent to the list
            ret[#ret + 1] = r
          end
        else
          ret[#ret + 1] = r
        end
      end
    end
  end
  if not (not needs_cursor_node and visual_sel and config.visual_select_list) then util.tbl_reverse(ret) end
  err('completed', config.debug)
  return ret
end

local function node_or_range_get_text(node_or_range, bufnr)
  local bufnr = bufnr or vim.api.nvim_get_current_buf()
  if not node_or_range then return {} end

  -- We have to remember that end_col is end-exclusive
  local start_row, start_col, end_row, end_col = vim.treesitter.get_node_range(node_or_range)

  if end_col == 0 then
    if start_row == end_row then
      start_col = -1
      start_row = start_row - 1
    end
    end_col = -1
    end_row = end_row - 1
  end
  return vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
end

-- node 'a' is the one the cursor is on
function M.swap_nodes_and_return_new_ranges(a, b, bufnr, should_move_cursor)
  return M.swap_ranges_and_return_new_ranges({ a:range() }, { b:range() }, bufnr, should_move_cursor)
end
function M.swap_ranges_and_return_new_ranges(a, b, bufnr, should_move_cursor)
  local winid = vim.api.nvim_get_current_win()

  local a_sr, a_sc = unpack(a)
  local b_sr, b_sc = unpack(b)
  local c_r, c_c

  -- #64: note cursor position before swapping
  local cursor_delta
  if should_move_cursor then
    local cursor = vim.api.nvim_win_get_cursor(winid)
    c_r, c_c = unpack { cursor[1] - 1, cursor[2] }
    cursor_delta = { c_r - a_sr, c_c - a_sc }
  end

  -- [1] first appearing node should be `a`, so swap for convenience
  local HAS_SWAPPED = false
  if not util.compare_position({ a_sr, a_sc }, { b_sr, b_sc }) then
    a, b = b, a
    HAS_SWAPPED = true
  end

  local a_sr, a_sc, a_er, a_ec = unpack(a)
  local b_sr, b_sc, b_er, b_ec = unpack(b)

  local text1 = node_or_range_get_text(a, bufnr)
  local text2 = node_or_range_get_text(b, bufnr)

  ts_utils.swap_nodes(a, b, bufnr)

  local char_delta = 0
  local line_delta = 0
  if a_er < b_sr or (a_er == b_sr and a_ec <= b_sc) then line_delta = #text2 - #text1 end

  if a_er == b_sr and a_ec <= b_sc then
    if line_delta ~= 0 then
      --- why?
      --correction_after_line_change =  -b_sc
      --text_now_before_range2 = #(text2[#text2])
      --space_between_ranges = b_sc - a_ec
      --char_delta = correction_after_line_change + text_now_before_range2 + space_between_ranges
      --- Equivalent to:
      char_delta = #text2[#text2] - a_ec

      -- add a_sc if last line of range1 (now text2) does not start at 0
      if a_sr == b_sr + line_delta then char_delta = char_delta + a_sc end
    else
      char_delta = #text2[#text2] - #text1[#text1]
    end
  end

  -- now let a = first one (text2), b = second one (text1)
  -- (opposite of what it used to be)

  local _a_sr = a_sr
  local _a_sc = a_sc
  local _a_er = a_sr + #text2 - 1
  local _a_ec = (#text2 > 1) and #text2[#text2] or a_sc + #text2[#text2]
  local _b_sr = b_sr + line_delta
  local _b_sc = b_sc + char_delta
  local _b_er = b_sr + #text1 - 1
  local _b_ec = (#text1 > 1) and #text1[#text1] or b_sc + #text1[#text1]

  local a_data = { _a_sr, _a_sc, _a_er, _a_ec }
  local b_data = { _b_sr, _b_sc, _b_er, _b_ec }

  -- undo [1]'s swapping
  if HAS_SWAPPED then
    a_data, b_data = b_data, a_data
  end

  if should_move_cursor then
    -- cursor offset depends on whether it is affected by the node start position
    local c_to_c = (#text2 > 1 and cursor_delta[1] ~= 0) and c_c or b_data[2] + cursor_delta[2]
    vim.api.nvim_win_set_cursor(winid, { b_data[1] + 1 + cursor_delta[1], c_to_c })
  end

  return { a_data, b_data }
end

function M.move_node_to_index(children, cur_node_idx, a_idx, config)
  local bufnr = vim.api.nvim_get_current_buf()
  if a_idx == cur_node_idx + 1 or a_idx == cur_node_idx - 1 then
    -- This means the node is adjacent, swap and move are equivalent
    return M.swap_nodes_and_return_new_ranges(children[cur_node_idx], children[a_idx], bufnr, config.move_cursor)
  end

  local children_ranges = vim.tbl_map(function(node) return { node:range() } end, children)
  local cur_range = children_ranges[cur_node_idx]

  local incr = (cur_node_idx < a_idx) and 1 or -1
  for i = cur_node_idx + incr, a_idx, incr do
    local _, b_range =
      unpack(M.swap_ranges_and_return_new_ranges(cur_range, children_ranges[i], bufnr, config.move_cursor))
    cur_range = b_range
  end

  return { cur_range }
end

function M.attach(bufnr, lang)
  -- TODO: Fill this with what you need to do when attaching to a buffer
end

function M.detach(bufnr)
  -- TODO: Fill this with what you need to do when detaching from a buffer
end

return M
