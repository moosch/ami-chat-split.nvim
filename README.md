# ami-chat-split.nvim

A split-window chat UI for [ami](https://github.com/moosch/ami.nvim).

ami's chat panel is a floating window by default. This extension replaces it with
a real **window split** — a sidebar column with the transcript on top and the
input below — by providing ami's `chat_ui` capability. Nothing in ami core
changes; the chat controller just drives this renderer instead.

It's also the second reference example of an ami extension (after
[`ami-custom-proactive.nvim`](https://github.com/moosch/ami-custom-proactive.nvim)),
and a complete implementation of the `chat_ui` contract documented in ami's
[`docs/extensions.md`](https://github.com/moosch/ami.nvim/blob/main/docs/extensions.md).

## Requirements

- [ami.nvim](https://github.com/moosch/ami.nvim) (provides the extension API and
  the `chat_ui` capability this plugs into).

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim), install it alongside ami and
register it in ami's `setup()`:

```lua
{
  "moosch/ami.nvim",
  dependencies = { "moosch/ami-chat-split.nvim" },
  build = "make build",
  config = function()
    require("ami").setup({
      extensions = { require("ami-chat-split") },
      -- optional (defaults shown):
      -- chat_split = { side = "right", width = 0.33, prompt_height = 6 },
    })
  end,
}
```

Then use ami's usual chat commands (`:AmiChat`, `:AmiAsk`, …) — they open in the
split. The in-panel keys match the floating UI: `<CR>` (normal mode) sends,
`<C-n>` starts a new session, `q`/`<Esc>` close.

## Configuration

Config lives under `chat_split` in ami's `setup()`:

| Key | Default | Meaning |
| --- | --- | --- |
| `side` | `"right"` | which side the column docks to (`"right"` or `"left"`) |
| `width` | `0.33` | column width: a fraction of the screen (`<=1`) or absolute columns (`>1`) |
| `prompt_height` | `6` | height of the input window, in lines |

> ami's `chat.ui` options (`position`/`opacity`/…) apply to the **built-in**
> floating panel only; when this extension is active they're not used.

## License

[MIT](LICENSE)
