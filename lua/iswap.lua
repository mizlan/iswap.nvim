local queries = require('nvim-treesitter.query')
local ui = require('iswap.ui')
local util = require('iswap.util')
local internal = require('iswap.internal')
local ts_utils = require('nvim-treesitter.ts_utils')
local default_config = require('iswap.defaults')

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
  local cursor_row = vim.fn.line('.') - 1
  local cursor_col = vim.fn.col('.')
  local bufnr = vim.fn.bufnr()
  local winnr = vim.fn.winnr()

  local parent = internal.get_list_node_at_cursor(winnr)
  if not parent then return end
  local children = ts_utils.get_named_children(parent)
  local sr, sc, er, ec = parent:range()
  -- nodes to swap
  local a, b = unpack(ui.prompt(bufnr, config, children, {{sr, sc}, {er, ec}}, 2))
  ts_utils.swap_nodes(a, b, bufnr)
end
  
return M
