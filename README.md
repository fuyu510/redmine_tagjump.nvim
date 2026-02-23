# redmine_tagjump.nvim

Neovim buffer text like `#2312` can be treated as a Redmine issue id.
When you click that text with the mouse, the issue page opens in your browser.

## Features

- Detects issue patterns like `#1234` in the current buffer
- Opens `server_url/issues/<id>` when clicking with the mouse
- Keeps default mouse behavior when clicking non-issue text
- Provides `:RedmineOpenIssue` command for keyboard workflow

## Requirements

- Neovim 0.8+
- Mouse enabled in Neovim (`set mouse=a`)

## Installation (lazy.nvim)

```lua
{
  "<your-github-id>/redmine_tagjump.nvim",
  opts = {
    server_url = "https://redmine.example.com",
  },
  config = function(_, opts)
    require("redmine_tagjump").setup(opts)
  end,
}
```

## Configuration

```lua
require("redmine_tagjump").setup({
  server_url = "https://redmine.example.com",
  issue_path = "/issues/%s",
  enable_mouse = true,
  notify = true,
})
```

### Options

- `server_url` (`string`, required): Redmine base URL
- `issue_path` (`string`, default `"/issues/%s"`): Issue path format (`%s` = issue id)
- `enable_mouse` (`boolean`, default `true`): Enable click behavior on `<LeftMouse>` in normal mode
- `notify` (`boolean`, default `true`): Show notifications for info/warn/error

## Usage

1. Open a file containing text such as `Fix in #2312`.
2. Click `#2312` in normal mode.
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
