if vim.g.loaded_redmine_tagjump == 1 then
  return
end

vim.g.loaded_redmine_tagjump = 1

vim.api.nvim_create_user_command("RedmineOpenIssue", function()
  require("redmine_tagjump").open_issue_under_cursor()
end, {
  desc = "Open Redmine issue under cursor",
})
