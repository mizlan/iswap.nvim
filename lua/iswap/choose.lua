local util = require('iswap.util')
local ts_utils = require('nvim-treesitter.ts_utils')
local internal = require('iswap.internal')
local ui = require('iswap.ui')
local err = util.err

local function autoswap(config, iters)
  if config.autoswap == true or config.autoswap == "always" then return true end
  if config.autoswap == nil or config.autoswap == false then return false end
  if config.autoswap == "after_label" then return iters ~= 1 end
end


local function choose(direction, config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local select_two_nodes = direction == 2

  local iters = 0

  local ancestors, list_index
  if config.all_nodes then
    local cur_node = ts_utils.get_node_at_cursor(winid)
    if cur_node == nil then return end
    ancestors, _, list_index = internal.get_ancestors_at_cursor(cur_node, config.only_current_line, config,
      not select_two_nodes)
    if not ancestors then return end
  else
    local lists = internal.get_list_nodes_at_cursor(winid, config, not select_two_nodes)
    list_index = 1
    ancestors = vim.tbl_map(function(list)
      local parent, children, cur_node_idx = unpack(list)
      return children[cur_node_idx or 1]
    end, lists)
  end


  list_index = list_index - 1
  while true do
    iters = iters + 1
    list_index = list_index + 1
    if list_index == 0 then list_index = #ancestors end
    if list_index > #ancestors then list_index = 1 end
    local ancestor = ancestors[list_index]
    local parent = ancestor:parent()
    local children = ts_utils.get_named_children(parent)

    local sr, sc, er, ec = parent:range()

    -- a and b are the nodes to swap
    local swap_node, swap_node_idx, ancestor_idx

    if autoswap(config, iters) and #children == 2 then -- auto swap ancestor with other sibling
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

return choose
