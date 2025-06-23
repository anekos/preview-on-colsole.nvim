local M = {}

local fifo_path = '/tmp/preview_on_console_fifo'
local last_file_path = nil
local enabled = false
local debounce_timer = nil
local liname_buffer_cache = {}

-- Default configuration
local config = {
  -- Lua patterns for file name recognition
  patterns = {
    -- Common file path patterns
    '/[^%s]+%.%w+',    -- Absolute paths like /path/to/file.ext
    '%.?/[^%s]+%.%w+', -- Relative paths like ./path/to/file.ext or ../file.ext
    '[%w_%-%.]+%.%w+', -- Simple filenames like file.ext
    '~[^%s]*%.%w+',    -- Home directory paths like ~/file.ext
    -- Custom patterns can be added here
  },
  -- Whether to use word boundaries for file detection
  word_boundaries = true,
  -- Characters considered as word separators
  separators = { ' ', '\t', '\n', '\r', '(', ')', '[', ']', '{', '}', '<', '>', '"', "'", '`' },
}

function M.get_buffer_cache(bufnr)
  return liname_buffer_cache[bufnr or vim.api.nvim_get_current_buf()]
end

function M.get_cursor_file_path()
  local bufnr = vim.api.nvim_get_current_buf()
  local cache = M.get_buffer_cache(bufnr)

  if cache then
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    local cached_path = cache[cursor_line]
    if cached_path then
      return cached_path
    end
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1

  if col > #line then
    return nil
  end

  -- Try to find file paths using configured patterns
  for _, pattern in ipairs(config.patterns) do
    local matches = {}
    local start_pos = 1

    while start_pos <= #line do
      local match_start, match_end = line:find(pattern, start_pos)
      if not match_start then
        break
      end

      local match = line:sub(match_start, match_end)
      table.insert(matches, {
        text = match,
        start_pos = match_start,
        end_pos = match_end,
      })

      start_pos = match_end + 1
    end

    -- Check if cursor is within any of the matches
    for _, match in ipairs(matches) do
      if col >= match.start_pos and col <= match.end_pos then
        local file_path = match.text:match('^%s*(.-)%s*$')
        if file_path and file_path ~= '' then
          return file_path
        end
      end
    end
  end

  -- Fallback to original behavior if no pattern matches
  if config.word_boundaries then
    local file_chars = '[^%c]'
    local start_pos = col
    local end_pos = col

    while start_pos > 1 do
      local char = line:sub(start_pos - 1, start_pos - 1)
      local is_separator = false
      for _, sep in ipairs(config.separators) do
        if char == sep then
          is_separator = true
          break
        end
      end
      if not is_separator and char:match(file_chars) then
        start_pos = start_pos - 1
      else
        break
      end
    end

    while end_pos <= #line do
      local char = line:sub(end_pos, end_pos)
      local is_separator = false
      for _, sep in ipairs(config.separators) do
        if char == sep then
          is_separator = true
          break
        end
      end
      if not is_separator and char:match(file_chars) then
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

  return nil
end

function M.write_to_fifo(content)
  ---@diagnostic disable-next-line
  local stat = vim.loop.fs_stat(fifo_path)
  if not stat or stat.type ~= 'fifo' then
    -- Escape the path to prevent shell injection
    local escaped_path = vim.fn.shellescape(fifo_path)
    local success = os.execute('mkfifo ' .. escaped_path) == 0
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

  local bufnr = vim.api.nvim_get_current_buf()
  local cache = M.get_buffer_cache(bufnr)
  local file_path = nil

  if cache then
    local cursor_line = vim.api.nvim_win_get_cursor(0)[1]
    file_path = cache[cursor_line]
  end

  if not file_path then
    file_path = M.get_cursor_file_path()
  end

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

function M.build_buffer_cache()
  local bufnr = vim.api.nvim_get_current_buf()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local cache = {}

  for _, line_content in ipairs(lines) do
    local tab_pos = line_content:find('\t')
    if tab_pos then
      local line_number_part = line_content:sub(1, tab_pos - 1)
      local file_path_part = line_content:sub(tab_pos + 1)

      if line_number_part:match('^%d+$') and file_path_part ~= '' then
        cache[tonumber(line_number_part)] = file_path_part
      end
    end
  end

  liname_buffer_cache[bufnr] = cache

  return cache
end

function M.enable_liname()
  local cache = M.build_buffer_cache()
  local cache_size = 0
  for _ in pairs(cache) do
    cache_size = cache_size + 1
  end
  enabled = true

  print(string.format('Liname cache built for buffer: %d entries', cache_size))
end

function M.setup(user_config)
  -- Merge user config with default config
  if user_config then
    if user_config.patterns then
      config.patterns = user_config.patterns
    end
    if user_config.word_boundaries ~= nil then
      config.word_boundaries = user_config.word_boundaries
    end
    if user_config.separators then
      config.separators = user_config.separators
    end
    if user_config.fifo_path then
      fifo_path = user_config.fifo_path
    end
  end

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

  vim.api.nvim_create_user_command('POCLinameEnable', M.enable_liname, {
    desc = 'Enable liname functionality and build buffer cache',
  })
end

-- Function to add custom patterns
function M.add_pattern(pattern)
  table.insert(config.patterns, pattern)
end

-- Function to set patterns (replaces all existing patterns)
function M.set_patterns(patterns)
  config.patterns = patterns
end

-- Function to get current configuration
function M.get_config()
  return vim.deepcopy(config)
end

return M
