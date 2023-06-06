local M = {}

function M.err(msg, flag)
  if flag then
    vim.api.nvim_echo({{msg, 'Error'}}, true, {})
  end
end

function M.tbl_reverse(tbl)
  for i=1, math.floor(#tbl / 2) do
    tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
  end
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

return M
