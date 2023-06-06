local M = {}

function M.err(msg, flag)
  if flag then
    vim.api.nvim_echo({{msg, 'Error'}}, true, {})
  end
end
local err = M.err

function M.tbl_reverse(tbl)
  for i=1, math.floor(#tbl / 2) do
    tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
  end
  return tbl
end

function M.tbl_pack(...)
  local t = {...}
  t.n = #t
  return t
end

function M.compare_position(a, b)
  if a[1] == b[1] then
    return a[2] <= b[2]
  else
    return a[1] <= b[1]
  end
end

function M.within(a, b, c)
  return M.compare_position(a, b) and M.compare_position(b, c)
end

function M.nodes_containing_cursor(node, winid)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local cursor_range = { cursor[1] - 1, cursor[2] }
  return M.nodes_containing_pos(node, cursor_range)
end

-- pos is in form {r, c}
function M.node_contains_pos(node, pos)
  local sr, sc, er, ec = node:range()
  local s = {sr, sc}
  local e = {er, ec}
  return M.within(s, pos, e)
end
function M.node_contains_range(node, pos1, pos2)
  return M.node_contains_pos(node, pos1) and M.node_contains_pos(node, pos2)
end

function M.node_contains_cursor(node, winid)
  local cursor = vim.api.nvim_win_get_cursor(winid)
  local cursor_range = { cursor[1] - 1, cursor[2] }
  return M.node_contains_pos(node, cursor_range)
end

function M.nodes_containing_pos(nodes, pos)
  local idxs = {}
  for i, node in ipairs(nodes) do
    if M.node_contains_pos(node, pos) then
      table.insert(idxs, i)
    end
  end
  return idxs
end

function M.has_siblings(node)
  return node:next_named_sibling() ~= nil or node:prev_named_sibling() ~= nil
end

function M.getchar_handler()
  local ok, key = pcall(vim.fn.getchar)
  if not ok then return nil end
  if type(key) == 'number' then
    local key_str = vim.fn.nr2char(key)
    return key_str
  end
  return nil
end

function M.same_range(r1, r2) return r1[1] == r2[1] and r1[2] == r2[2] and r1[3] == r2[3] and r1[4] == r2[4] end

function M.ancestors(cur_node, only_current_line, config)
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
      if M.has_siblings(parent) and parent:type() ~= 'comment' then
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

  return ancestors, last_row
end

-- Calls node:parent until the node differs in start or end
function M.expand_node(node)
  local range = { node:range() }
  local parent = node:parent()
  while M.same_range(range, { parent:range() }) do
    parent = parent:parent()
  end
  return parent
end

return M
