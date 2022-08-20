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
  local winid = vim.api.nvim_get_current_win()

  local parent = internal.get_list_node_at_cursor(winid, config)
  if not parent then
    err('did not find a satisfiable parent node', config.debug)
    return
  end
  local children = ts_utils.get_named_children(parent)
  local sr, sc, er, ec = parent:range()

  -- nothing to swap here
  if #children < 2 then return end

  -- a and b are the nodes to swap
  local a, b

  -- enable autoswapping with two children
  -- and default to prompting for user input
  if config.autoswap and #children == 2 then
    a, b = unpack(children)
  else
    local user_input = ui.prompt(bufnr, config, children, {{sr, sc}, {er, ec}}, 2)
    if not (type(user_input) == 'table' and #user_input == 2) then
      err('did not get two valid user inputs', config.debug)
      return
    end
    a, b = unpack(user_input)
  end

  if a == nil or b == nil then
    err('some of the nodes were nil', config.debug)
    return
  end

  local a_range, b_range = unpack(
    internal.swap_nodes_and_return_new_ranges(a, b, bufnr, false)
  )

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNormal", -1)]])
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
    if util.has_siblings(outer_cursor_node) then
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
      user_input = ui.prompt(bufnr, config, children, {{sr, sc}, {er, ec}}, 1)
      if not (type(user_input) == 'table' and #user_input == 1) then
        err('did not get two valid user inputs', config.debug)
        return
      end
      swap_node = unpack(user_input)
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

function M.iswap_node(config, direction)
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
  local picked_node = user_input[1] -- for swap
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
    swap_node = unpack(user_input)
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
function M.iswap_with(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()
  local winid = vim.api.nvim_get_current_win()

  local parent = internal.get_list_node_at_cursor(winid, config)
  if not parent then
    err('did not find a satisfiable parent node', config.debug)
    return
  end
  local children = ts_utils.get_named_children(parent)

  -- nothing to swap here
  if #children < 2 then return end

  local cur_nodes = util.nodes_containing_cursor(children, winid)
  if #cur_nodes == 0 then
    err('not on a node!', 1)
  end

  if #cur_nodes > 1 then
    err('multiple found, using first', config.debug)
  end

  local cur_node = children[cur_nodes[1]]
  table.remove(children, cur_nodes[1])

  local sr, sc, er, ec = parent:range()

  -- a is the node to swap the cur_node with
  local a

  -- enable autoswapping with one other child
  -- and default to prompting for user input
  if config.autoswap and #children == 1 then
    a = children[1]
  else
    local user_input = ui.prompt(bufnr, config, children, {{sr, sc}, {er, ec}}, 1)
    if not (type(user_input) == 'table' and #user_input == 1) then
      err('did not get a valid user input', config.debug)
      return
    end
    a = unpack(user_input)
  end

  if a == nil then
    err('the node was nil', config.debug)
    return
  end

  local a_range, b_range = unpack(
    internal.swap_nodes_and_return_new_ranges(cur_node, a, bufnr, config.move_cursor)
  )

  ui.flash_confirm(bufnr, { a_range, b_range }, config)

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapWith", -1)]])
end

return M
