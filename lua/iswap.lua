local queries = require('nvim-treesitter.query')
local ui = require('iswap.ui')
local internal = require('iswap.internal')
local default_config = require('iswap.defaults')
local choose = require('iswap.choose')

local M = {}

M.config = default_config

function M.setup(config)
  config = config or {}
  M.config = setmetatable(config, { __index = default_config })
end

function M.evaluate_config(config, parent)
  parent = parent or M.config
  return config and setmetatable(config, { __index = parent }) or parent
end

local last_iswap = nil
local function repeat_set(cb)
  last_iswap = cb
  vim.cmd([[silent! call repeat#set("\<Plug>ISwapRepeat", -1)]])
end

function M.init()
  require('nvim-treesitter').define_modules {
    iswap = {
      module_path = 'iswap.internal',
      is_supported = function(lang) return queries.get_query(lang, 'iswap-list') ~= nil end,
    },
  }

  -- <Plug>ISwap will delay because it becomes <Plug>ISwapWith prefix sequence.
  -- Use <Plug>ISwapNormal instead and etc for others
  local cmds = {
    { 'ISwap', 'iswap', {}, 'ISwapNormal' },
    { 'ISwapWith', 'iswap_with', { false } },
    { 'ISwapWithRight', 'iswap_with', { 'right' } },
    { 'ISwapWithLeft', 'iswap_with', { 'left' } },
    { 'IMove', 'imove', {}, 'IMoveNormal' },
    { 'IMoveWith', 'imove_with', { false } },
    { 'IMoveWithRight', 'imove_with', { 'right' } },
    { 'IMoveWithLeft', 'imove_with', { 'left' } },
    { 'ISwapNode', 'iswap_node', {}, 'ISwapNodeNormal' },
    { 'ISwapNodeWith', 'iswap_node_with', { false } },
    { 'ISwapNodeWithRight', 'iswap_node_with', { 'right' } },
    { 'ISwapNodeWithLeft', 'iswap_node_with', { 'left' } },
    { 'IMoveNode', 'imove_node', {}, 'IMoveNodeNormal' },
    { 'IMoveNodeWith', 'imove_node_with', { false } },
    { 'IMoveNodeWithRight', 'imove_node_with', { 'right' } },
    { 'IMoveNodeWithLeft', 'imove_node_with', { 'left' } },
  }
  local map = vim.keymap.set
  for _, v in ipairs(cmds) do
    local cmd, fn, arg, plug = unpack(v)
    plug = plug or cmd
    local cb = function() M[fn](unpack(arg)) end
    -- vim.cmd('command ' .. cmd .. " lua require'iswap'." .. rhs)
    vim.api.nvim_create_user_command(cmd, cb, {})
    -- map('n', '<Plug>' .. plug, "<cmd>lua require'iswap'." .. rhs .. '<cr>')
    map('n', '<Plug>' .. plug, cb, { desc = cmd })
  end
  map('n', '<Plug>ISwapRepeat', function()
    if last_iswap then last_iswap() end
  end)
end

function M.swap(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  choose(direction, config, function(children, b_idx, a_idx)
    local ranges = internal.swap_ranges_in_place(children, a_idx, b_idx, config.move_cursor)

    ui.flash_confirm(bufnr, ranges, config)

    return ranges
  end)

  repeat_set(function() M.swap(direction, config) end)
end
function M.move(direction, config)
  config = M.evaluate_config(config)
  local bufnr = vim.api.nvim_get_current_buf()

  choose(direction, config, function(children, b_idx, a_idx)
    local ranges = internal.move_range_in_place(children, a_idx, b_idx, config.move_cursor)

    ui.flash_confirm(bufnr, ranges, config)

    return ranges
  end)

  repeat_set(function() M.move(direction, config) end)
end

function M.iswap(config)
  config = config or {}
  config.all_nodes = false
  M.swap(2, config)
end

function M.imove(config)
  config = config or {}
  config.all_nodes = false
  M.move(2, config)
end

function M.iswap_node_with(direction, config) M.swap(direction, config) end

function M.imove_node_with(direction, config) M.move(direction, config) end

function M.iswap_node(config) M.swap(2, config) end

function M.imove_node(config) M.move(2, config) end

function M.imove_with(direction, config)
  config = config or {}
  config.all_nodes = false
  M.move(direction, config)
end

-- swap current with one other node
function M.iswap_with(direction, config)
  config = config or {}
  config.all_nodes = false
  M.swap(direction, config)
end

return M
