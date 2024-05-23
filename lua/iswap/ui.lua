local ts_utils = require('nvim-treesitter.ts_utils')
local util = require('iswap.util')
local err = util.err

local M = {}

M.iswap_ns = vim.api.nvim_create_namespace('iswap')

function M.clear_namespace(bufnr)
  vim.api.nvim_buf_clear_namespace(bufnr, M.iswap_ns, 0, -1)
  vim.api.nvim_buf_clear_namespace(bufnr, M.iswap_ns, 0, -1)
end

-- Given a range, grey everything in the window other than that range.
function M.grey_the_rest_out(bufnr, config, begin_exclude, end_exclude)
  local win_info = vim.fn.getwininfo(vim.api.nvim_get_current_win())[1]
  local top_line = win_info.topline - 1
  local bot_line = win_info.botline - 1
  M.clear_namespace(bufnr)
  vim.highlight.range(bufnr, M.iswap_ns, config.hl_grey, {top_line, 0}, begin_exclude, 'v', false, config.hl_grey_priority)
  vim.highlight.range(bufnr, M.iswap_ns, config.hl_grey, end_exclude, {bot_line, -1}, 'v', false, config.hl_grey_priority)
end

-- Prompt user from NODES a total of TIMES times in BUFNR. CONFIG is used for
-- customization and ACTIVE_RANGE looks like {{row, col}, {row, col}} and is
-- used only to determine where to grey out
function M.prompt(bufnr, config, ranges, active_range, times, parents_after)
  local keys = config.keys
  if #ranges > #keys then
    if parents_after and parents_after > #keys then
      -- TODO: do something about this
      -- too many nodes, not enough keys, and I don't want to start using prefixes
      err('Too many nodes but not enough keys!', true)
      return
    else
      err('Too many nodes, but can exclude parents', config.debug)
    end
  end

  local range_start, range_end = unpack(active_range)
  if config.grey ~= 'disable' then
    M.grey_the_rest_out(bufnr, config, range_start, range_end)
  end

  local imap = {}
  for i, range in ipairs(ranges) do
    local key = keys:sub(i, i)
    if key == '' then break end
    imap[key] = i
    local is_child = parents_after and (i <= parents_after)
    if is_child then ts_utils.highlight_range(range, bufnr, M.iswap_ns, config.hl_selection) end
    local start_row, start_col = unpack(range)
    vim.api.nvim_buf_set_extmark(bufnr, M.iswap_ns, start_row, start_col,
      {
        virt_text = { { key, is_child and config.hl_snipe or config.hl_parent } },
        virt_text_pos = is_child and config.label_snipe_style or config.label_parent_style,
        hl_mode = "blend",
      })
  end
  vim.cmd('redraw')

  local ires = {}
  local ikeys = {}
  for _ = 1, times do
    local keystr = util.getchar_handler()
    table.insert(ikeys, keystr)
    if keystr == nil or imap[keystr] == nil then break end
    table.insert(ires, imap[keystr])
    if parents_after and imap[keystr] > parents_after then break end
  end
  M.clear_namespace(bufnr)
  return ires, ikeys
end

-- RANGES is a list of RANGE where RANGE is like
-- { startrow, startcol, endrow, endcol }
function M.flash_confirm_simul(bufnr, ranges, config)
  M.clear_namespace(bufnr)
  for _, range in ipairs(ranges) do
    local sr, sc, er, ec = unpack(range)
    vim.highlight.range(bufnr, M.iswap_ns, config.hl_flash, {sr, sc}, {er, ec}, 'v', false)
  end

  vim.defer_fn(
    function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        M.clear_namespace(bufnr)
      end
    end,
    250
  )
end

function M.flash_confirm_sequential(bufnr, ranges, config)
  local function helper(idx)
    M.clear_namespace(bufnr)
    if idx > #ranges then return end
    local sr, sc, er, ec = unpack(ranges[idx])
    vim.highlight.range(bufnr, M.iswap_ns, config.hl_flash, {sr, sc}, {er, ec}, 'v', false)
    vim.defer_fn(
      function()
        helper(idx + 1)
      end,
      300
    )
  end
  helper(1)
end

function M.flash_confirm(bufnr, ranges, config)
  if config.flash_style == 'simultaneous' then
    M.flash_confirm_simul(bufnr, ranges, config)
  elseif config.flash_style == 'sequential' then
    M.flash_confirm_sequential(bufnr, ranges, config)
  end
end

return M
