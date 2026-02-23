local M = {}

local defaults = {
  server_url = nil,
  issue_path = "/issues/%s",
  enable_mouse = true,
  notify = true,
}

M.options = vim.deepcopy(defaults)
M._mouse_map_installed = false

local function notify(message, level)
  if not M.options.notify then
    return
  end

  vim.notify(message, level or vim.log.levels.INFO, { title = "redmine_tagjump" })
end

local function normalize_server_url(url)
  if type(url) ~= "string" or url == "" then
    return nil
  end

  return url:gsub("/+$", "")
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
  if vim.ui and vim.ui.open then
    local ok = pcall(vim.ui.open, url)
    if ok then
      return true
    end
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
  return vim.fn.jobstart(command, { detach = true }) > 0
end

function M.get_issue_id_at_position(bufnr, line_nr, col)
  local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
  if not line then
    return nil
  end

  local issue_id = issue_id_at_byte_col(line, col)
  if issue_id then
    return issue_id
  end

  local byte_col = char_col_to_byte_col(line, col)
  return issue_id_at_byte_col(line, byte_col)
end

function M.open_issue(issue_id)
  local url = build_issue_url(issue_id)
  if not url then
    notify("Set `server_url` in setup() before opening issues", vim.log.levels.WARN)
    return false
  end

  if not open_external(url) then
    notify("Failed to open URL: " .. url, vim.log.levels.ERROR)
    return false
  end

  return true
end

function M.open_issue_under_cursor()
  local pos = vim.api.nvim_win_get_cursor(0)
  local line = vim.api.nvim_buf_get_lines(0, pos[1] - 1, pos[1], false)[1]
  if not line then
    return false
  end

  local issue_id = issue_id_at_byte_col(line, pos[2] + 1)
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

  return M.open_issue(issue_id)
end

local function left_mouse_expr()
  if M.open_issue_under_mouse() then
    return "<Ignore>"
  end

  return "<LeftMouse>"
end

local function install_mouse_mapping()
  if M._mouse_map_installed then
    return
  end

  vim.keymap.set("n", "<LeftMouse>", left_mouse_expr, {
    expr = true,
    noremap = true,
    silent = true,
    desc = "Open Redmine issue when clicking #123",
  })
  M._mouse_map_installed = true
end

local function uninstall_mouse_mapping()
  if not M._mouse_map_installed then
    return
  end

  pcall(vim.keymap.del, "n", "<LeftMouse>")
  M._mouse_map_installed = false
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  M.options.server_url = normalize_server_url(M.options.server_url)

  if M.options.enable_mouse then
    install_mouse_mapping()
  else
    uninstall_mouse_mapping()
  end
end

return M
