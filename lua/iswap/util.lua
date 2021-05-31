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

-- Returns array of lines, where start and end_ are {row, col} where row is 1-indexed and col is 0-indexed
function M.buf_get_range(bufnr, start, end_)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start[1], end_[1] + 1, false)
  local n = #lines
  if start[1] == end_[1] then
    lines[1] = lines[1]:sub(start[2] + 1, end_[2])
    return lines
  end
  lines[1] = lines[1]:sub(start[2] + 1, -1)
  lines[n] = lines[n]:sub(1, end_[2])
  return lines
end

function M.getchar_handler(on_err)
  local ok, key = pcall(vim.fn.getchar)
  if not ok then
    on_err()
    return
  end
  if type(key) == 'number' then
    local key_str = vim.fn.nr2char(key)
    return key_str
  end
end

return M
