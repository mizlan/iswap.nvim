local M = {}
local util = require('iswap.util')
local ts_utils = require('nvim-treesitter.ts_utils')
local internal = require('iswap.internal')
local err = util.err

local ui = require('iswap.ui')
function M.two_nodes_from_list(config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local ignored_parents = {}

  ::expand_list::
  local parent, children = internal.get_list_node_at_cursor(winid, ignored_parents, config)
  if not parent then
    err('did not find a satisfiable parent node', config.debug)
    return
  end
  ignored_parents[#ignored_parents+1] = parent
  local sr, sc, er, ec = parent:range()

  -- a and b are the nodes to swap
  local a, b
  local a_idx, b_idx

  -- enable autoswapping with two children
  -- and default to prompting for user input
  if config.autoswap and #children == 2 then
    a, b = unpack(children)
    a_idx, b_idx = 1, 2
  else
    local user_input, user_key = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 2)
    if not (type(user_input) == 'table' and #user_input == 2) then
      if user_key[1] == config.expand_key then
        goto expand_list
      end
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

  local ignored_parents = {}

  ::expand_list::
  local parent, children, cur_node_idx = internal.get_list_node_at_cursor(winid, ignored_parents, config, true)
  if not parent or not children or not cur_node_idx then
    err('did not find a satisfiable parent node', config.debug)
    return
  end
  ignored_parents[#ignored_parents+1] = parent

  local cur_node = table.remove(children, cur_node_idx)

  local sr, sc, er, ec = parent:range()

  -- a is the node to move the cur_node into the place of
  local a, a_idx

  -- enable autoswapping with one other child
  -- and default to prompting for user input
  if config.autoswap and #children == 1 then
    a = children[1]
    a_idx = 1
  else
    if direction == 'left' then
      a = children[cur_node_idx - 1]
      a_idx = cur_node_idx - 1
    elseif direction == 'right' then
      -- already shifted over, no need for +1
      a = children[cur_node_idx]
      a_idx = cur_node_idx
    else
      local user_input, user_key = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
      if not (type(user_input) == 'table' and #user_input == 1) then
        if user_key[1] == config.expand_key then
          goto expand_list
        end
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

  -- restore cur_node into the correct position in children (and adjust indices)
  table.insert(children, cur_node_idx, cur_node)
  if cur_node_idx <= a_idx then a_idx = a_idx + 1 end

  return children, cur_node_idx, a_idx
end

function M.two_nodes_from_any(config)
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()

  local cur_node = ts_utils.get_node_at_cursor(winid)
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
  while parent and parent:start() == current_row do
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

  -- in left-to-right order for generating hints
  util.tbl_reverse(ancestors)

  if #ancestors == 0 then
    err('No proper node with siblings found to swap', config.debug)
    return
  end

  -- pick: {cursor_node +  any ancestors} for swapping
  local dim_exclude_range = { { last_row, 0 }, { last_row, 120 } }
  local user_input = ui.prompt(bufnr, config, ancestors, dim_exclude_range, 1) -- no dim when picking swap_node ?
  if not (type(user_input) == 'table' and #user_input == 1) then
    err('did not get two valid user inputs', config.debug)
    return
  end
  -- we want to pick siblings of user selected node (thus:  usr_node:parent())
  local picked_node = ancestors[user_input[1]] -- for swap
  local picked_parent = picked_node:parent()
  local children = ts_utils.get_named_children(picked_parent)
  local sr, sc, er, ec = picked_parent:range()

  -- remove children if child:type() == 'comment'
  for i = #children, 1, -1 do
    if children[i]:type() == 'comment' then table.remove(children, i) end
  end

  -- nothing to swap here
  if #children < 2 then return end

  local swap_node, swap_node_idx, picked_node_idx

  if config.autoswap and #children == 2 then -- auto swap picked_node with other sibling
    if children[1] == picked_node then
      swap_node = children[2]
      swap_node_idx = 2
      picked_node_idx = 1
    else
      swap_node = children[1]
      swap_node_idx = 1
      picked_node_idx = 2
    end
  else -- draw picker
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

  local cursor_node = ts_utils.get_node_at_cursor(winid)
  local current_row, current_col = cursor_node:start()

  -- find outer parent :=  its start() is same as cursor_node:start()
  local last_valid_node = cursor_node
  local outer_cursor_node = cursor_node:parent()
  while outer_cursor_node do -- only get parents - for current line
    local outer_row, outer_col = outer_cursor_node:start()
    if outer_row ~= current_row or outer_col ~= current_col then -- new outer parent to have same start()
      break
    end
    if direction == 'right' and outer_cursor_node:next_named_sibling() ~= nil then -- only select node if it has a right sibling
      last_valid_node = outer_cursor_node
    elseif direction == 'left' and outer_cursor_node:prev_named_sibling() ~= nil then -- or left sibling
      last_valid_node = outer_cursor_node
    elseif (direction == nil or direction == false) and util.has_siblings(outer_cursor_node) then -- if no direction, then node with any sibling is ok
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
  local children = ts_utils.get_named_children(outer_parent)
  local sr, sc, er, ec = outer_parent:range()

  -- nothing to swap here
  if #children < 2 then return end

  -- a and b are the nodes to swap
  local swap_node, swap_node_idx, outer_cursor_node_idx

  if config.autoswap and #children == 2 then -- auto swap outer_cursor_node with other sibling
    if children[1] == outer_cursor_node then
      swap_node = children[2]
      swap_node_idx = 2
      outer_cursor_node_idx = 1
    else
      swap_node = children[1]
      swap_node_idx = 1
      outer_cursor_node_idx = 2
    end
  else -- draw picker
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
