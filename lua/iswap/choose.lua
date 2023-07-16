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

local function ranges(parent, children, ancestor_idx)
  return { { parent:range() }, vim.tbl_map(function(child) return { child:range() } end, children), ancestor_idx }
end

local function choose(direction, config, callback)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()
  local select_two_nodes = direction == 2

  local iters = 0

  local lists, list_index
  if config.all_nodes then
    local cur_node = ts_utils.get_node_at_cursor(winid)
    if cur_node == nil then return end
    lists, _, list_index =
      internal.get_ancestors_at_cursor(cur_node, config.only_current_line, config, not select_two_nodes)
  else
    lists = internal.get_list_nodes_at_cursor(winid, config, not select_two_nodes)
    list_index = 1
  end
  if not lists then return end
  lists = vim.tbl_map(function(list) return ranges(unpack(list)) end, lists)

  while true do
    iters = iters + 1
    local parent, children, ancestor_idx = unpack(lists[list_index])
    local ancestor = children[ancestor_idx]

    local sr, sc, er, ec = unpack(parent)

    -- a and b are the nodes to swap
    local swap_node_idx

    if autoswap(config, iters) and #children == 2 then -- auto swap ancestor with other sibling
      swap_node_idx = 3 - ancestor_idx
    else -- draw picker
      local function increment(dir)
        swap_node_idx = ancestor_idx + dir
        -- local swap_node = children[swap_node_idx]
        -- while swap_node ~= nil and swap_node:type() == 'comment' do
        --   swap_node_idx = swap_node_idx + dir
        --   swap_node = children[swap_node_idx]
        -- end
      end
      if direction == 'right' then
        increment(1)
      elseif direction == 'left' then
        increment(-1)
      else
        if not select_two_nodes then table.remove(children, ancestor_idx) end
        local function increment_swap(dir)
          table.insert(children, ancestor_idx, ancestor)
          increment(dir)
          local swapped = callback(children, ancestor_idx, swap_node_idx)
          children[ancestor_idx] = swapped[1]
          children[swap_node_idx] = swapped[2]
          lists[list_index][3] = swap_node_idx
        end

        local children_and_parents = config.label_parents
            and util.join_lists { children, vim.tbl_map(function(list) return list[1] end, lists) }
          or children

        local times = select_two_nodes and 2 or 1
        local user_input, user_keys =
          ui.prompt(bufnr, config, children_and_parents, { { sr, sc }, { er, ec } }, times, #children)
        if not (type(user_input) == 'table' and #user_input >= 1) then
          if user_keys then
            local inp = user_keys[2] or user_keys[1]
            if inp == config.expand_key then
              list_index = list_index + 1
              goto continue
            end
            if inp == config.shrink_key then
              list_index = list_index - 1
              goto continue
            end
            if not select_two_nodes then
              if inp == config.incr_left_key then
                increment_swap(-1)
                goto continue
              end
              if inp == config.incr_right_key then
                increment_swap(1)
                goto continue
              end
            end
          end
          err('did not get valid user inputs', config.debug)
          return
        end

        swap_node_idx = select_two_nodes and user_input[2] or user_input[1]
        if swap_node_idx > #children then
          list_index = swap_node_idx - #children
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

    if children[swap_node_idx] ~= nil then return callback(children, ancestor_idx, swap_node_idx) end
    err('no node to swap with', config.debug)

    ::continue::
    if list_index == 0 then list_index = #lists end
    if list_index > #lists then list_index = 1 end
  end
end

return choose
