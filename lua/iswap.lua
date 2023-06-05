local queries = require('nvim-treesitter.query')
local ui = require('iswap.ui')
local internal = require('iswap.internal')
local ts_utils = require('nvim-treesitter.ts_utils')
local default_config = require('iswap.defaults')
local util = require('iswap.util')
local err = util.err

local M = {}

M.config = default_config

function M.setup(config)
  config = config or {}
  M.config = setmetatable(config, { __index = default_config })
end

function M.evaluate_config(config)
  return config and setmetatable(config, {__index = M.config}) or M.config
end

function M.init()
  require 'nvim-treesitter'.define_modules {
    iswap = {
      module_path = 'iswap.internal',
      is_supported = function(lang)
        return queries.get_query(lang, 'iswap-list') ~= nil
      end
    }
  }
end

function M.iswap(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local a, b = internal.choose_two_nodes_from_list(config)

  local a_range, b_range = unpack(internal.swap_nodes_and_return_new_ranges(a, b, bufnr, false))

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNormal", -1)]])
end

function M.imove(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local a, b, children, a_idx, b_idx = internal.choose_two_nodes_from_list(config)

  local a_range, b_range = unpack(internal.move_node_to_index(children, a, a_idx, bufnr, b_idx, config))

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>IMoveNormal", -1)]])
end

function M.iswap_node_with(direction, config)
  config = M.evaluate_config(config)
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
    elseif direction == 'left' and outer_cursor_node:prev_named_sibling() ~= nil then  -- or left sibling
      last_valid_node = outer_cursor_node
    elseif direction == nil and util.has_siblings(outer_cursor_node) then  -- if no direction, then node with any sibling is ok
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
  local swap_node

  if config.autoswap and #children == 2 then -- auto swap outer_cursor_node with other sibling
    if children[1] == outer_cursor_node then
      swap_node = children[2]
    else
      swap_node = children[1]
    end
  else -- draw picker
    if direction == 'right' then
      swap_node = outer_cursor_node:next_named_sibling()
      while swap_node ~= nil and swap_node:type() == 'comment' do
        swap_node = swap_node:next_named_sibling()
      end
    elseif direction == 'left' then
      swap_node = outer_cursor_node:prev_named_sibling()
      while swap_node ~= nil and swap_node:type() == 'comment' do
        swap_node = swap_node:prev_named_sibling()
      end
    else
      local user_input = ui.prompt(bufnr, config, children, {{sr, sc}, {er, ec}}, 1)
      if not (type(user_input) == 'table' and #user_input == 1) then
        err('did not get two valid user inputs', config.debug)
        return
      end
      swap_node = children[user_input[1]]
    end
  end

  if swap_node == nil then
    err('no node to swap with', config.debug)
    return
  end

  local a_range, b_range = unpack(
    internal.swap_nodes_and_return_new_ranges(outer_cursor_node, swap_node, bufnr, config.move_cursor)
  )

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNormal", -1)]])
end

function M.iswap_node(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

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
  local dim_exclude_range = {{last_row, 0}, {last_row, 120}}
  local user_input = ui.prompt(bufnr, config, ancestors, dim_exclude_range , 1) -- no dim when picking swap_node ?
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
    if children[i]:type() == 'comment' then
      table.remove(children, i)
    end
  end

  -- nothing to swap here
  if #children < 2 then return end

  local swap_node

  if config.autoswap and #children == 2 then -- auto swap picked_node with other sibling
    if children[1] == picked_node then
      swap_node = children[2]
    else
      swap_node = children[1]
    end
  else -- draw picker
    user_input = ui.prompt(bufnr, config, children, {{sr, sc}, {er, ec}}, 1)
    if not (type(user_input) == 'table' and #user_input == 1) then
      err('did not get two valid user inputs', config.debug)
      return
    end
    swap_node = children[user_input[1]]
  end

  if swap_node == nil then
    err('picked nil swap node', config.debug)
    return
  end

  local a_range, b_range = unpack(
    internal.swap_nodes_and_return_new_ranges(picked_node, swap_node, bufnr, false)
  )

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNormal", -1)]])
end

-- TODO: refactor iswap() and iswap_with()
-- swap current with one other node
function M.imove_with(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local cur_node, a, children, cur_node_idx, a_idx = internal.choose_one_other_node_from_list(direction, config)

  local a_range, b_range
  if not a_idx  then
    -- This means the node is adjacent, swap and move are equivalent
    a_range, b_range = unpack(internal.swap_nodes_and_return_new_ranges(cur_node, a, bufnr, config.move_cursor))
  else
    table.insert(children, cur_node_idx, cur_node)
    if cur_node_idx <= a_idx then a_idx = a_idx + 1 end
    a_range, b_range = unpack(internal.move_node_to_index(children, cur_node, cur_node_idx, bufnr, a_idx, config))
  end

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>IMoveWith", -1)]])
end

function M.iswap_with(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local cur_node, a = internal.choose_one_other_node_from_list(direction, config)

  local a_range, b_range = unpack(internal.swap_nodes_and_return_new_ranges(cur_node, a, bufnr, config.move_cursor))

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

    vim.cmd([[silent! call repeat#set("\<Plug>ISwapWith", -1)]])
end

return M
