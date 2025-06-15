local M = {}

local fifo_path = '/tmp/preview_on_console_fifo'
local last_file_path = nil
local enabled = false

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
  local stat_cmd = string.format('test -p "%s"', fifo_path)
  local exists = os.execute(stat_cmd) == 0

  if not exists then
    local mkfifo_cmd = string.format('mkfifo "%s"', fifo_path)
    local result = os.execute(mkfifo_cmd)

    if result ~= 0 then
      return false, 'Failed to create FIFO'
    end
  end

  vim.schedule(function()
    local write_cmd = string.format('timeout 1 sh -c \'echo "%s" > "%s"\' &', content:gsub('"', '\\"'), fifo_path)
    vim.fn.system(write_cmd)
  end)

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
  if file_path == last_file_path then
    return
  end
  M.write_to_fifo(file_path)
  last_file_path = file_path
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
