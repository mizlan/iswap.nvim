local ui = require('iswap.ui')
local internal = require('iswap.internal')
local default_config = require('iswap.defaults')
local util = require('iswap.util')
local choose = require('iswap.choose')
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
  -- <Plug>ISwap will delay because it becomes <Plug>ISwapWith prefix sequence.
  -- Use <Plug>ISwapNormal instead and etc for others
  local cmds = {
    { 'ISwap', 'iswap', {}, 'ISwapNormal' },
    { 'ISwapWith', 'iswap_with', false },
    { 'ISwapWithRight', 'iswap_with', "right" },
    { 'ISwapWithLeft', 'iswap_with', "left" },
    { 'IMove', 'imove', {}, 'IMoveNormal' },
    { 'IMoveWith', 'imove_with', false },
    { 'IMoveWithRight', 'imove_with', "right" },
    { 'IMoveWithLeft', 'imove_with', "left" },
    { 'ISwapNode', 'iswap_node', {}, 'ISwapNodeNormal' },
    { 'ISwapNodeWith', 'iswap_node_with', false },
    { 'ISwapNodeWithRight', 'iswap_node_with', "right" },
    { 'ISwapNodeWithLeft', 'iswap_node_with', "left" },
    { 'IMoveNode', 'imove_node', {}, 'IMoveNodeNormal' },
    { 'IMoveNodeWith', 'imove_node_with', false },
    { 'IMoveNodeWithRight', 'imove_node_with', "right" },
    { 'IMoveNodeWithLeft', 'imove_node_with', "left" },
  }
  local map = vim.keymap.set
  for _, v in ipairs(cmds) do
    local cmd, fn, arg, plug = unpack(v)
    plug = plug or cmd
    local cb = function() M[fn](arg) end
    -- vim.cmd('command ' .. cmd .. " lua require'iswap'." .. rhs)
    vim.api.nvim_create_user_command(cmd, cb, {})
    -- map('n', '<Plug>' .. plug, "<cmd>lua require'iswap'." .. rhs .. '<cr>')
    map('n', '<Plug>' .. plug, cb)
  end
end

function M.iswap(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, a_idx, b_idx = choose.two_nodes_from_list(config)

  if children then
    local ranges = internal.swap_nodes_and_return_new_ranges(children[a_idx], children[b_idx], bufnr, false)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNormal", -1)]])
end

function M.imove(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, a_idx, b_idx = choose.two_nodes_from_list(config)

  if children then
    local ranges = internal.move_node_to_index(children, a_idx, b_idx, config)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>IMoveNormal", -1)]])
end

function M.iswap_node_with(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, outer_cursor_node_idx, swap_node_idx = choose.one_other_node_from_any(direction, config)

  if children then
    local ranges = internal.swap_nodes_and_return_new_ranges(
      children[outer_cursor_node_idx],
      children[swap_node_idx],
      bufnr,
      config.move_cursor
    )

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNodeWith", -1)]])
end

function M.imove_node_with(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, outer_cursor_node_idx, swap_node_idx = choose.one_other_node_from_any(direction, config)

  if children then
    local ranges = internal.move_node_to_index(children, outer_cursor_node_idx, swap_node_idx, config)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>IMoveNodeWith", -1)]])
end

function M.iswap_node(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, picked_node_idx, swap_node_idx = choose.two_nodes_from_any(config)

  if children then
    local ranges =
      internal.swap_nodes_and_return_new_ranges(children[picked_node_idx], children[swap_node_idx], bufnr, false)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapNodeNormal", -1)]])
end

function M.imove_node(config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, picked_node_idx, move_node_idx = choose.two_nodes_from_any(config)

  if children then
    local ranges = internal.move_node_to_index(children, picked_node_idx, move_node_idx, config)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>IMoveNodeNormal", -1)]])
end

function M.imove_with(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, cur_node_idx, a_idx = choose.one_other_node_from_list(direction, config)

  if children then
    local ranges = internal.move_node_to_index(children, cur_node_idx, a_idx, config)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>IMoveWith", -1)]])
end

-- TODO: refactor iswap() and iswap_with()
-- swap current with one other node
function M.iswap_with(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  local children, cur_node_idx, a_idx = choose.one_other_node_from_list(direction, config)
  if children then
    local ranges =
      internal.swap_nodes_and_return_new_ranges(children[cur_node_idx], children[a_idx], bufnr, config.move_cursor)

    ui.flash_confirm(bufnr, ranges, config)
  end

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapWith", -1)]])
end

return M
