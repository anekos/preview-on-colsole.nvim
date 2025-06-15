local M = {}

function M.get_cursor_file_path()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  if col > #line then
    return nil
  end

  local file_chars = '[^%c]'

  local start_pos = col
  local end_pos = col

  while start_pos > 1 do
    local char = line:sub(start_pos - 1, start_pos - 1)
    if char:match(file_chars) and char ~= '\t' then
      start_pos = start_pos - 1
    else
      break
    end
  end

  while end_pos <= #line do
    local char = line:sub(end_pos, end_pos)
    if char:match(file_chars) and char ~= '\t' then
      end_pos = end_pos + 1
    else
      break
    end
  end

  if start_pos >= end_pos then
    return nil
  end

  local file_path = line:sub(start_pos, end_pos - 1):match('^%s*(.-)%s*$')

  if file_path == '' then
    return nil
  end

  return file_path
end

function M.on_cursor_moved()
  print(M.get_cursor_file_path() or 'No file path found at cursor position')
end

function M.setup()
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = M.on_cursor_moved,
    desc = 'Trigger on cursor movement',
  })
end

return M
