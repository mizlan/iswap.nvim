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
      local children_and_parents = config.label_parents and
          util.join_lists({ children, vim.tbl_map(function(l) return l[1] end, lists) })
          or children

      local user_input, user_keys = ui.prompt(bufnr, config, children_and_parents, { { sr, sc }, { er, ec } }, 1, #children)
      if not (type(user_input) == 'table' and #user_input == 1) then
        if user_keys[1] == config.expand_key then goto continue end
        if user_keys[1] == config.shrink_key then goto continue_prev end
        err('did not get two valid user inputs', config.debug)
        return
      end
      a_idx = user_input[1]
      if a_idx > #children then
        list_index = a_idx - #children - 1
        goto continue
      end

      local user_input, user_keys = ui.prompt(bufnr, config, children, { { sr, sc }, { er, ec } }, 1)
      if not (type(user_input) == 'table' and #user_input == 1) then
        err('did not get two valid user inputs', config.debug)
        return
      end
      b_idx = user_input[1]
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

        local children_and_parents = config.label_parents and
            util.join_lists({ children, vim.tbl_map(function(l) return l[1] end, lists) })
            or children

        local user_input, user_keys = ui.prompt(bufnr, config, children_and_parents, { { sr, sc }, { er, ec } }, 1, #children)
        if not (type(user_input) == 'table' and #user_input == 1) then
          if user_keys[1] == config.expand_key then goto continue end
          if user_keys[1] == config.shrink_key then goto continue_prev end
          err('did not get a valid user input', config.debug)
          return
        end
        a_idx = user_input[1]
        if a_idx > #children then
          list_index = a_idx - #children - 1
          goto continue
        end

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

function M.nodes_from_any(direction, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local select_two_nodes = direction == 2

  local cur_node = ts_utils.get_node_at_cursor(winid)
  if cur_node == nil then return end
  local ancestors, _, list_index = internal.get_ancestors_at_cursor(cur_node, config.only_current_line, config)
  if not ancestors then return end


  list_index = list_index - 1
  while true do
    list_index = list_index + 1
    if list_index == 0 then list_index = #ancestors end
    if list_index > #ancestors then list_index = 1 end
    local ancestor = ancestors[list_index]
    local parent = ancestor:parent()
    local children = ts_utils.get_named_children(parent)

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
      if not select_two_nodes then
        for i, child in ipairs(children) do
          if child == ancestor then
            ancestor_idx = i
            break
          end
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
        if not select_two_nodes then
          table.remove(children, ancestor_idx)
        end

        local children_and_parents = config.label_parents and
            util.join_lists({ children, vim.tbl_map(function(node) return node:parent() end, ancestors) }) or children

        local times = select_two_nodes and 2 or 1
        local user_input, user_keys = ui.prompt(bufnr, config, children_and_parents, { { sr, sc }, { er, ec } }, times,
          #children)
        if not (type(user_input) == 'table' and #user_input >= 1) then
          if user_keys then
            local inp = user_keys[2] or user_keys[1]
            if inp == config.expand_key then goto continue end
            if inp == config.shrink_key then goto continue_prev end
          end
          err('did not get valid user inputs', config.debug)
          return
        end
        swap_node_idx = select_two_nodes and user_input[2] or user_input[1]
        if swap_node_idx > #children then
          list_index = swap_node_idx - #children - 1
          goto continue
        end
        if select_two_nodes then
          ancestor_idx = user_input[1]
        else
          table.insert(children, ancestor_idx, ancestor)
          if ancestor_idx <= swap_node_idx then swap_node_idx = swap_node_idx + 1 end
        end
      end
    end

    if children[swap_node_idx] ~= nil then return children, ancestor_idx, swap_node_idx end
    err('no node to swap with', config.debug)

    ::continue_prev::
    list_index = list_index - 2
    ::continue::
  end
end

return M
