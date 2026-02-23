local M = {}

local defaults = {
  server_url = nil,
  issue_path = "/issues/%s",
  enable_mouse = true,
  notify = true,
  open_cmd = nil,
  open_fn = nil,
  copy_url_on_fail = true,
  copy_url_always = false,
}

local mouse_keys = {
  "<LeftMouse>",
  "<C-LeftMouse>",
  "<2-LeftMouse>",
  "<C-2-LeftMouse>",
}

M.options = vim.deepcopy(defaults)
M._mouse_map_installed = false

local function notify(message, level)
  if not M.options.notify then
    return
  end

  vim.notify(message, level or vim.log.levels.INFO, { title = "redmine_tag_opener" })
end

local function normalize_server_url(url)
  if type(url) ~= "string" or url == "" then
    return nil
  end

  return url:gsub("/+$", "")
end

local function build_custom_open_command(open_cmd, url)
  if type(open_cmd) == "table" then
    local command = {}
    local has_placeholder = false

    for _, arg in ipairs(open_cmd) do
      if type(arg) ~= "string" then
        return nil
      end

      if arg:find("%%s") then
        local ok, formatted = pcall(string.format, arg, url)
        if not ok then
          return nil
        end

        table.insert(command, formatted)
        has_placeholder = true
      else
        table.insert(command, arg)
      end
    end

    if not has_placeholder then
      table.insert(command, url)
    end

    return command
  end

  if type(open_cmd) == "string" then
    local escaped = vim.fn.shellescape(url)

    if open_cmd:find("%%s") then
      local ok, command = pcall(string.format, open_cmd, escaped)
      if ok then
        return command
      end

      return nil
    end

    return open_cmd .. " " .. escaped
  end

  return nil
end

local function run_open_command(command)
  local job_id = vim.fn.jobstart(command, { detach = false })
  if job_id <= 0 then
    return false
  end

  local wait_result = vim.fn.jobwait({ job_id }, 350)[1]
  return wait_result == -1 or wait_result == 0
end

local function open_with_fn(url)
  if type(M.options.open_fn) ~= "function" then
    return nil
  end

  local ok, result = pcall(M.options.open_fn, url)
  if not ok then
    notify("open_fn failed", vim.log.levels.ERROR)
    return false
  end

  return result ~= false
end

local function open_with_custom_command(url)
  local command = build_custom_open_command(M.options.open_cmd, url)
  if not command then
    return nil
  end

  return run_open_command(command)
end

local function open_with_vim_ui(url)
  if not (vim.ui and vim.ui.open) then
    return nil
  end

  local ok, proc = pcall(vim.ui.open, url)
  if not ok then
    return nil
  end

  if not proc then
    return false
  end

  if type(proc) == "table" and type(proc.wait) == "function" then
    local wait_ok, result = pcall(proc.wait, proc, 350)
    if wait_ok and type(result) == "table" and type(result.code) == "number" then
      return result.code == 0
    end
  end

  return true
end

local function open_with_env_browser(url)
  local browser = vim.env.BROWSER
  if type(browser) ~= "string" or browser == "" then
    return nil
  end

  local first_entry = browser:match("^[^:]+") or browser
  local command = build_custom_open_command(first_entry, url)
  if not command then
    return nil
  end

  return run_open_command(command)
end

local function copy_url(url)
  local copied = false

  for _, reg in ipairs({ "+", "*", '"' }) do
    local ok = pcall(vim.fn.setreg, reg, url)
    copied = copied or ok
  end

  return copied
end

local function char_col_to_byte_col(line, col)
  local ok, byte_col = pcall(vim.str_byteindex, line, math.max(col - 1, 0))
  if not ok or byte_col < 0 then
    return nil
  end

  return byte_col + 1
end

local function issue_id_at_byte_col(line, byte_col)
  if not line or line == "" or not byte_col then
    return nil
  end

  local search_from = 1
  while true do
    local start_col, end_col = line:find("#%d+", search_from)
    if not start_col then
      return nil
    end

    if byte_col >= start_col and byte_col <= end_col then
      return line:sub(start_col + 1, end_col)
    end

    search_from = end_col + 1
  end
end

local function issue_id_near_byte_col(line, byte_col)
  if type(byte_col) ~= "number" then
    return nil
  end

  for _, offset in ipairs({ 0, -1, 1 }) do
    local probe = byte_col + offset
    if probe > 0 then
      local issue_id = issue_id_at_byte_col(line, probe)
      if issue_id then
        return issue_id
      end
    end
  end

  return nil
end

local function build_issue_url(issue_id)
  local base_url = M.options.server_url
  if not base_url then
    return nil
  end

  local issue_path = M.options.issue_path
  local ok, path = pcall(string.format, issue_path, issue_id)
  if not ok then
    path = "/issues/" .. issue_id
  end

  if not path:match("^/") then
    path = "/" .. path
  end

  return base_url .. path
end

local function open_external(url)
  local fn_result = open_with_fn(url)
  if fn_result ~= nil then
    return fn_result
  end

  local custom_cmd_result = open_with_custom_command(url)
  if custom_cmd_result ~= nil then
    return custom_cmd_result
  end

  local ui_result = open_with_vim_ui(url)
  if ui_result then
    return true
  end

  local env_result = open_with_env_browser(url)
  if env_result then
    return true
  end

  local open_cmd
  if vim.fn.has("mac") == 1 then
    open_cmd = { "open" }
  elseif vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    open_cmd = { "cmd", "/c", "start", "" }
  else
    open_cmd = { "xdg-open" }
  end

  local command = vim.list_extend(open_cmd, { url })
  return run_open_command(command)
end

function M.get_issue_id_at_position(bufnr, line_nr, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  if not line then
    return nil
  end

  local issue_id = issue_id_near_byte_col(line, col)
  if issue_id then
    return issue_id
  end

  local byte_col = char_col_to_byte_col(line, col)
  if not byte_col then
    return nil
  end

  return issue_id_near_byte_col(line, byte_col)
end

function M.open_issue(issue_id)
  local url = build_issue_url(issue_id)
  if not url then
    notify("Set `server_url` in setup() before opening issues", vim.log.levels.WARN)
    return false
  end

  local copied_always = false
  if M.options.copy_url_always then
    copied_always = copy_url(url)
  end

  local opened = open_external(url)
  if not opened then
    if copied_always or (M.options.copy_url_on_fail and copy_url(url)) then
      notify('URL "' .. url .. '" 가 복사 되었습니다', vim.log.levels.WARN)
    else
      notify("Failed to open URL: " .. url, vim.log.levels.ERROR)
    end

    return false
  end

  if copied_always then
    notify('URL "' .. url .. '" 가 복사 되었습니다', vim.log.levels.INFO)
  end

  return true
end

function M.open_issue_under_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  if not line then
    return false
  end

  local issue_id = issue_id_near_byte_col(line, pos[2] + 1)
  if not issue_id then
    notify("No Redmine issue under cursor", vim.log.levels.INFO)
    return false
  end

  return M.open_issue(issue_id)
end

function M.open_issue_under_mouse()
  local mouse = vim.fn.getmousepos()
  if type(mouse) ~= "table" or mouse.winid == 0 or mouse.line <= 0 or mouse.column <= 0 then
    return false
  end

  local bufnr = vim.api.nvim_win_get_buf(mouse.winid)
  local issue_id = M.get_issue_id_at_position(bufnr, mouse.line, mouse.column)
  if not issue_id then
    return false
  end

  M.open_issue(issue_id)
  return true
end

local function mouse_expr(key)
  if M.open_issue_under_mouse() then
    return "<Ignore>"
  end

  return key
end

local function install_mouse_mapping()
  if M._mouse_map_installed then
    return
  end

  for _, key in ipairs(mouse_keys) do
    vim.keymap.set("n", key, function()
      return mouse_expr(key)
    end, {
      expr = true,
      noremap = true,
      silent = true,
      desc = "Open Redmine issue when clicking #123",
    })
  end

  M._mouse_map_installed = true
end

local function uninstall_mouse_mapping()
  if not M._mouse_map_installed then
    return
  end

  for _, key in ipairs(mouse_keys) do
    pcall(vim.keymap.del, "n", key)
  end

  M._mouse_map_installed = false
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  M.options.server_url = normalize_server_url(M.options.server_url)

  if M.options.open_cmd ~= nil then
    local open_cmd_type = type(M.options.open_cmd)
    if open_cmd_type ~= "string" and open_cmd_type ~= "table" then
      notify("`open_cmd` must be a string or list", vim.log.levels.WARN)
      M.options.open_cmd = nil
    end
  end

  if M.options.open_fn ~= nil and type(M.options.open_fn) ~= "function" then
    notify("`open_fn` must be a function", vim.log.levels.WARN)
    M.options.open_fn = nil
  end

  if type(M.options.copy_url_on_fail) ~= "boolean" then
    M.options.copy_url_on_fail = defaults.copy_url_on_fail
  end

  if type(M.options.copy_url_always) ~= "boolean" then
    M.options.copy_url_always = defaults.copy_url_always
  end

  if M.options.enable_mouse then
    install_mouse_mapping()
  else
    uninstall_mouse_mapping()
  end
end

return M
