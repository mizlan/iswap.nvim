local M = {}
local util = require('iswap.util')
local ts_utils = require('nvim-treesitter.ts_utils')
local internal = require('iswap.internal')
local ui = require('iswap.ui')
local err = util.err

function M.two_nodes_from_list(config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local lists = internal.get_list_nodes_at_cursor(winid, config, false)
  if lists == nil then return end
  local list_index = 0
  while true do
    list_index = list_index + 1
    if list_index == 0 then list_index = #lists end
    if list_index > #lists then list_index = 1 end
    local list = lists[list_index]

    local parent, children = unpack(list)
    if not parent then
      err('did not find a satisfiable parent node', config.debug)
      goto continue
    end
    local sr, sc, er, ec = parent:range()

    -- a and b are the nodes to swap
    local a_idx, b_idx

    -- enable autoswapping with two children
    -- and default to prompting for user input
    if config.autoswap and #children == 2 then
      a_idx, b_idx = 1, 2
    else
      local user_input, user_keys = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 2)
      if not (type(user_input) == 'table' and #user_input == 2) then
        if user_keys[1] == config.expand_key then goto continue end
        if user_keys[1] == config.shrink_key then goto continue_prev end
        err('did not get two valid user inputs', config.debug)
        return
      end
      a_idx, b_idx = unpack(user_input)
    end

    if children[a_idx] ~= nil and children[b_idx] ~= nil then return children, a_idx, b_idx end
    err('some of the nodes were nil', config.debug)
    ::continue_prev::
    list_index = list_index - 2
    ::continue::
  end
end

function M.one_other_node_from_list(direction, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local lists = internal.get_list_nodes_at_cursor(winid, config, true)
  if lists == nil then return end
  local list_index = 0
  while true do
    list_index = list_index + 1
    if list_index == 0 then list_index = #lists end
    if list_index > #lists then list_index = 1 end
    local list = lists[list_index]

    local parent, children, cur_node_idx = unpack(list)
    if not parent or not children or not cur_node_idx then
      err('did not find a satisfiable parent node', config.debug)
      goto continue
    end

    local sr, sc, er, ec = parent:range()

    -- a is the node to move the cur_node into the place of
    local a_idx

    -- enable autoswapping with one other child
    -- and default to prompting for user input
    if config.autoswap and #children == 2 then
      a_idx = 3 - cur_node_idx -- 2<->1
    else
      if direction == 'left' then
        a_idx = cur_node_idx - 1
      elseif direction == 'right' then
        a_idx = cur_node_idx + 1
      else
        local cur_node = table.remove(children, cur_node_idx)

        local user_input, user_keys = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
        if not (type(user_input) == 'table' and #user_input == 1) then
          if user_keys[1] == config.expand_key then goto continue end
          if user_keys[1] == config.shrink_key then goto continue_prev end
          err('did not get a valid user input', config.debug)
          return
        end
        a_idx = user_input[1]

        -- restore cur_node into the correct position in children (and adjust indices)
        table.insert(children, cur_node_idx, cur_node)
        if cur_node_idx <= a_idx then a_idx = a_idx + 1 end
      end
    end

    if children[a_idx] ~= nil then return children, cur_node_idx, a_idx end
    err('the node was nil', config.debug)

    ::continue_prev::
    list_index = list_index - 2
    ::continue::
  end
end

function M.ancestor_node_from_line(config)
  local winid = vim.api.nvim_get_current_win()
  local bufnr = vim.api.nvim_get_current_buf()

  local cur_node = ts_utils.get_node_at_cursor(winid)
  local ancestors, last_row = internal.get_ancestors_at_cursor(cur_node, config.only_current_line, config)
  if not ancestors then return end

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

  -- remove children if child:type() == 'comment'
  for i = #children, 1, -1 do
    if children[i]:type() == 'comment' then table.remove(children, i) end
  end

  -- nothing to swap here
  if #children < 2 then return end

  return children, picked_node, picked_parent
end

function M.two_nodes_from_any(config)
  local children, picked_node, picked_parent = M.ancestor_node_from_line(config)

  local bufnr = vim.api.nvim_get_current_buf()
  if children == nil or picked_node == nil or picked_parent == nil then return end
  local sr, sc, er, ec = picked_parent:range()

  local swap_node_idx, picked_node_idx

  if config.autoswap and #children == 2 then -- auto swap picked_node with other sibling
    if children[1] == picked_node then
      swap_node_idx = 2
      picked_node_idx = 1
    else
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
    table.remove(children, picked_node_idx)

    local user_input = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
    if not (type(user_input) == 'table' and #user_input == 1) then
      err('did not get two valid user inputs', config.debug)
      return
    end
    swap_node_idx = user_input[1]

    -- restore picked_node
    table.insert(children, picked_node_idx, picked_node)
    if picked_node_idx <= swap_node_idx then swap_node_idx = swap_node_idx + 1 end
  end

  if children[swap_node_idx] == nil then
    err('picked nil swap node', config.debug)
    return
  end

  return children, picked_node_idx, swap_node_idx
end

function M.one_other_node_from_any(direction, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local cur_node = ts_utils.get_node_at_cursor(winid)
  local ancestors = internal.get_ancestors_at_cursor(cur_node, config.only_current_line, config)
  if not ancestors then return end


  local ancestor_index = 0
  while true do
    ancestor_index = ancestor_index + 1
    if ancestor_index == 0 then ancestor_index = #ancestors end
    if ancestor_index > #ancestors then ancestor_index = 1 end
    local ancestor = ancestors[ancestor_index]
    err('Found Node', config.debug)
    local parent = ancestor:parent()
    if parent == nil then
      err('No parent found for swap', config.debug)
      goto continue
    end
    local children = ts_utils.get_named_children(parent)

    -- nothing to swap here
    if #children < 2 then
      err('No siblings found for swap', config.debug)
      goto continue
    end

    local sr, sc, er, ec = parent:range()

    -- a and b are the nodes to swap
    local swap_node, swap_node_idx, ancestor_idx

    if config.autoswap and #children == 2 then -- auto swap ancestor with other sibling
      if children[1] == ancestor then
        swap_node = children[2]
        swap_node_idx = 2
        ancestor_idx = 1
      else
        swap_node = children[1]
        swap_node_idx = 1
        ancestor_idx = 2
      end
    else -- draw picker
      for i, child in ipairs(children) do
        if child == ancestor then
          ancestor_idx = i
          break
        end
      end
      if direction == 'right' then
        swap_node = ancestor:next_named_sibling()
        swap_node_idx = ancestor_idx + 1
        while swap_node ~= nil and swap_node:type() == 'comment' do
          swap_node = swap_node:next_named_sibling()
          swap_node_idx = swap_node_idx + 1
        end
      elseif direction == 'left' then
        swap_node = ancestor:prev_named_sibling()
        swap_node_idx = ancestor_idx - 1
        while swap_node ~= nil and swap_node:type() == 'comment' do
          swap_node = swap_node:prev_named_sibling()
          swap_node_idx = swap_node_idx - 1
        end
      else
        table.remove(children, ancestor_idx)

        local user_input, user_keys = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
        if not (type(user_input) == 'table' and #user_input == 1) then
          if user_keys[1] == config.expand_key then goto continue end
          if user_keys[1] == config.shrink_key then goto continue_prev end
          err('did not get two valid user inputs', config.debug)
          return
        end
        swap_node_idx = user_input[1]
        swap_node = children[swap_node_idx]

        table.insert(children, ancestor_idx, ancestor)
        if ancestor_idx <= swap_node_idx then swap_node_idx = swap_node_idx + 1 end
      end
    end

    if swap_node ~= nil then return children, ancestor_idx, swap_node_idx end
    err('no node to swap with', config.debug)

    ::continue_prev::
    ancestor_index = ancestor_index - 2
    ::continue::
  end
end
return M
