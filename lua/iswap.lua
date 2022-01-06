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
  ts_utils.swap_nodes(a, b, bufnr)

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
  ts_utils.swap_nodes(a, cur_node, bufnr)

  vim.cmd([[silent! call repeat#set("\<Plug>ISwapWith", -1)]])
end

return M
