local M = {}

local fifo_path = '/tmp/preview_on_console_fifo'
local last_file_path = nil
local enabled = true
local debounce_timer = nil

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

function M.write_to_fifo(content)
  ---@diagnostic disable-next-line
  local stat = vim.loop.fs_stat(fifo_path)
  if not stat or stat.type ~= 'fifo' then
    local success = os.execute(string.format('mkfifo "%s"', fifo_path)) == 0
    if not success then
      return false, 'Failed to create FIFO'
    end
  end

  local file = io.open(fifo_path, 'a')
  if file then
    file:write(content .. '\n')
    file:close()
  else
    print('Failed to open FIFO for writing')
    return false, 'Failed to open FIFO'
  end

  return true
end

function M.on_cursor_moved()
  if not enabled then
    return
  end

  local file_path = M.get_cursor_file_path()
  if not file_path then
    return
  end

  local absolute_path = vim.fn.fnamemodify(file_path, ':p')

  if absolute_path == last_file_path then
    return
  end

  if debounce_timer then
    vim.fn.timer_stop(debounce_timer)
  end

  local path_to_write = absolute_path
  debounce_timer = vim.fn.timer_start(200, function()
    M.write_to_fifo(path_to_write)
    last_file_path = path_to_write
    debounce_timer = nil
  end)
end

function M.toggle()
  enabled = not enabled
  if enabled then
    print('Preview on console: enabled')
  else
    print('Preview on console: disabled')
  end
end

function M.enable()
  enabled = true
  print('Preview on console: enabled')
end

function M.disable()
  enabled = false
  print('Preview on console: disabled')
end

function M.setup()
  vim.api.nvim_create_autocmd('CursorMoved', {
    callback = M.on_cursor_moved,
    desc = 'Trigger on cursor movement',
  })

  vim.api.nvim_create_user_command('POCToggle', M.toggle, {
    desc = 'Toggle preview on console functionality',
  })

  vim.api.nvim_create_user_command('POCEnable', M.enable, {
    desc = 'Enable preview on console functionality',
  })

  vim.api.nvim_create_user_command('POCDisable', M.disable, {
    desc = 'Disable preview on console functionality',
  })
end

return M
