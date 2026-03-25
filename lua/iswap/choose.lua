local M = {}
local util = require('iswap.util')
local internal = require('iswap.internal')
local err = util.err

local ui = require('iswap.ui')

function M.two_nodes_from_list(config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local parent, children = internal.get_list_node_at_cursor(winid, config)
  if not parent then
    err('did not find a satisfiable parent node', config.debug)
    return
  end
  local sr, sc, er, ec = parent:range()

  local a, b
  local a_idx, b_idx

  if config.autoswap and #children == 2 then
    a, b = unpack(children)
    a_idx, b_idx = 1, 2
  else
    local user_input = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 2)
    if not (type(user_input) == 'table' and #user_input == 2) then
      err('did not get two valid user inputs', config.debug)
      return
    end
    a_idx, b_idx = unpack(user_input)
    a, b = children[a_idx], children[b_idx]
  end

  if a == nil or b == nil then
    err('some of the nodes were nil', config.debug)
    return
  end

  return children, a_idx, b_idx
end

function M.one_other_node_from_list(direction, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local parent, children, cur_node_idx = internal.get_list_node_at_cursor(winid, config, true)
  if not parent or not children or not cur_node_idx then
    err('did not find a satisfiable parent node', config.debug)
    return
  end

  local cur_node = table.remove(children, cur_node_idx)

  local sr, sc, er, ec = parent:range()

  local a, a_idx

  if config.autoswap and #children == 1 then
    a = children[1]
    a_idx = 1
  else
    if direction == 'left' then
      a = children[cur_node_idx - 1]
      a_idx = cur_node_idx - 1
    elseif direction == 'right' then
      a = children[cur_node_idx]
      a_idx = cur_node_idx
    else
      local user_input = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
      if not (type(user_input) == 'table' and #user_input == 1) then
        err('did not get a valid user input', config.debug)
        return
      end
      a_idx = user_input[1]
      a = children[a_idx]
    end
  end

  if a == nil then
    err('the node was nil', config.debug)
    return
  end

  table.insert(children, cur_node_idx, cur_node)
  if cur_node_idx <= a_idx then a_idx = a_idx + 1 end

  return children, cur_node_idx, a_idx
end

function M.two_nodes_from_any(config)
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()

  local cur_node = util.get_node_at_cursor(winid)
  local parent = cur_node:parent()

  if not parent then
    err('did not find a satisfiable parent node', config.debug)
    return
  end

  local ancestors = { cur_node }
  local prev_parent = cur_node
  local current_row = parent:start()
  local last_row, last_col

  while parent and parent:start() == current_row do
    last_row, last_col = prev_parent:start()
    local s_row, s_col = parent:start()

    if last_row == s_row and last_col == s_col then
      if util.has_siblings(parent) and parent:type() ~= 'comment' then
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

  util.tbl_reverse(ancestors)

  if #ancestors == 0 then
    err('No proper node with siblings found to swap', config.debug)
    return
  end

  local dim_exclude_range = { { last_row, 0 }, { last_row, 120 } }
  local user_input = ui.prompt(bufnr, config, ancestors, dim_exclude_range, 1)
  if not (type(user_input) == 'table' and #user_input == 1) then
    err('did not get two valid user inputs', config.debug)
    return
  end
  local picked_node = ancestors[user_input[1]]
  local picked_parent = picked_node:parent()
  local children = util.get_named_children(picked_parent)
  local sr, sc, er, ec = picked_parent:range()

  for i = #children, 1, -1 do
    if children[i]:type() == 'comment' then table.remove(children, i) end
  end

  if #children < 2 then return end

  local swap_node, swap_node_idx, picked_node_idx

  if config.autoswap and #children == 2 then
    if children[1] == picked_node then
      swap_node = children[2]
      swap_node_idx = 2
      picked_node_idx = 1
    else
      swap_node = children[1]
      swap_node_idx = 1
      picked_node_idx = 2
    end
  else
    for i, child in ipairs(children) do
      if child == picked_node then
        picked_node_idx = i
        break
      end
    end
    user_input = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
    if not (type(user_input) == 'table' and #user_input == 1) then
      err('did not get two valid user inputs', config.debug)
      return
    end
    swap_node_idx = user_input[1]
    swap_node = children[swap_node_idx]
  end

  if swap_node == nil then
    err('picked nil swap node', config.debug)
    return
  end

  return children, picked_node_idx, swap_node_idx
end

function M.one_other_node_from_any(direction, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local cursor_node = util.get_node_at_cursor(winid)
  local current_row, current_col = cursor_node:start()

  local last_valid_node = cursor_node
  local outer_cursor_node = cursor_node:parent()
  while outer_cursor_node do
    local outer_row, outer_col = outer_cursor_node:start()
    if outer_row ~= current_row or outer_col ~= current_col then
      break
    end
    if direction == 'right' and outer_cursor_node:next_named_sibling() ~= nil then
      last_valid_node = outer_cursor_node
    elseif direction == 'left' and outer_cursor_node:prev_named_sibling() ~= nil then
      last_valid_node = outer_cursor_node
    elseif (direction == nil or direction == false) and util.has_siblings(outer_cursor_node) then
      last_valid_node = outer_cursor_node
    end
    outer_cursor_node = outer_cursor_node:parent()
  end

  outer_cursor_node = last_valid_node

  local outer_parent = outer_cursor_node:parent()
  if outer_parent == nil then
    err('No siblings found for swap', config.debug)
    return
  end
  local children = util.get_named_children(outer_parent)
  local sr, sc, er, ec = outer_parent:range()

  if #children < 2 then return end

  local swap_node, swap_node_idx, outer_cursor_node_idx

  if config.autoswap and #children == 2 then
    if children[1] == outer_cursor_node then
      swap_node = children[2]
      swap_node_idx = 2
      outer_cursor_node_idx = 1
    else
      swap_node = children[1]
      swap_node_idx = 1
      outer_cursor_node_idx = 2
    end
  else
    for i, child in ipairs(children) do
      if child == outer_cursor_node then
        outer_cursor_node_idx = i
        break
      end
    end
    if direction == 'right' then
      swap_node = outer_cursor_node:next_named_sibling()
      swap_node_idx = outer_cursor_node_idx + 1
      while swap_node ~= nil and swap_node:type() == 'comment' do
        swap_node = swap_node:next_named_sibling()
        swap_node_idx = swap_node_idx + 1
      end
    elseif direction == 'left' then
      swap_node = outer_cursor_node:prev_named_sibling()
      swap_node_idx = outer_cursor_node_idx - 1
      while swap_node ~= nil and swap_node:type() == 'comment' do
        swap_node = swap_node:prev_named_sibling()
        swap_node_idx = swap_node_idx - 1
      end
    else
      local user_input = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
      if not (type(user_input) == 'table' and #user_input == 1) then
        err('did not get two valid user inputs', config.debug)
        return
      end
      swap_node_idx = user_input[1]
      swap_node = children[swap_node_idx]
    end
  end

  if swap_node == nil then
    err('no node to swap with', config.debug)
    return
  end

  return children, outer_cursor_node_idx, swap_node_idx
end

return M
