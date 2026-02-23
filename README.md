# redmine_tagjump.nvim

Neovim buffer text like `#2312` can be treated as a Redmine issue id.
When you click that text with the mouse, the issue page opens in your browser.

## Features

- Detects issue patterns like `#1234` and `(#1234)` in the current buffer
- Opens `server_url/issues/<id>` when clicking with the mouse
- Keeps default mouse behavior when clicking non-issue text
- Supports custom URL opener command/function for SSH or remote setups
- Provides `:RedmineOpenIssue` command for keyboard workflow

## Requirements

- Neovim 0.8+
- Mouse enabled in Neovim (`set mouse=a`)

## Installation (lazy.nvim)

```lua
{
  "<your-github-id>/redmine_tagjump.nvim",
  main = "redmine_tagjump",
  opts = {
    server_url = "https://redmine.example.com",
  },
}
```

## Configuration

```lua
require("redmine_tagjump").setup({
  server_url = "https://redmine.example.com",
  issue_path = "/issues/%s",
  enable_mouse = true,
  notify = true,
  open_cmd = nil,
  open_fn = nil,
  copy_url_on_fail = true,
  copy_url_always = false,
})
```

### Options

- `server_url` (`string`, required): Redmine base URL
- `issue_path` (`string`, default `"/issues/%s"`): Issue path format (`%s` = issue id)
- `enable_mouse` (`boolean`, default `true`): Enable issue click behavior for left/double/ctrl+left click in normal mode
- `notify` (`boolean`, default `true`): Show notifications for info/warn/error
- `open_cmd` (`string|table`, default `nil`): Custom opener command (use `%s` as URL placeholder)
- `open_fn` (`function`, default `nil`): Custom opener callback `function(url) return true/false end`
- `copy_url_on_fail` (`boolean`, default `true`): Copy URL to registers if browser launch fails
- `copy_url_always` (`boolean`, default `false`): Always copy issue URL to registers when opening

## Remote / SSH setup

When Neovim runs on a remote host (SSH, remote RPC), default open commands run on that remote machine.
If the remote host cannot open a GUI browser, configure a custom opener.

Examples:

```lua
-- Example: use custom relay command/script
require("redmine_tagjump").setup({
  server_url = "https://redmine.example.com",
  open_cmd = "open-url %s",
})

-- Example: remote Linux session with xdg-open
-- (works when GUI session / DISPLAY is available on the remote host)
require("redmine_tagjump").setup({
  server_url = "https://redmine.example.com",
  open_cmd = { "xdg-open", "%s" },
})

-- Example: WSL -> open Windows browser
require("redmine_tagjump").setup({
  server_url = "https://redmine.example.com",
  open_cmd = { "wslview", "%s" },
})
```

If no opener works, the plugin copies the issue URL to clipboard/unnamed register (default behavior).

## Usage

1. Open a file containing text such as `Fix in #2312`.
2. Click `#2312` (or `(#2312)`) in normal mode.
3. Browser opens `https://redmine.example.com/issues/2312`.

Optional command:

```vim
:RedmineOpenIssue
```

Opens the issue under the cursor.

## Publish to GitHub

1. Create a new GitHub repository named `redmine_tagjump.nvim`.
2. Push this project to the repository.
3. Replace `<your-github-id>` in lazy.nvim spec with your GitHub ID.
