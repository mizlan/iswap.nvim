local M = {}

function M.err(msg, flag)
  if flag then
    vim.api.nvim_echo({{msg, 'Error'}}, true, {})
  end
end

function M.compare_position(a, b)
  if a[1] == b[1] then
    return a[2] < b[2]
  else
    return a[1] < b[1]
  end
end

function M.within(a, b, c)
  return M.compare_position(a, b) and M.compare_position(b, c)
end

function M.getchar_handler()
  local ok, key = pcall(vim.fn.getchar)
  if not ok then return nil end
  if type(key) == 'number' then
    local key_str = vim.fn.nr2char(key)
    return key_str
  end
  return nil
end

return M
