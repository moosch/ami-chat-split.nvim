# Demo

`chat-split.tape` is a [VHS](https://github.com/charmbracelet/vhs) script — the
source for `chat-split.gif` shown in the main README. GitHub doesn't render `.tape`;
render it to a `.gif` and commit the `.gif`.

## Render

```sh
# from this repo's root, with ami core AND ami-chat.nvim checked out as siblings:
vhs demos/chat-split.tape

# or point at your server / pick the model:
AMI_ENDPOINT=http://192.168.68.100:1234/v1 AMI_CHAT_MODEL=deepseek-coder vhs demos/chat-split.tape

git add demos/chat-split.gif && git commit -m "docs: update demo gif"
```

`demos/init.lua` loads **ami core** (`../ami.nvim` or `../ai-harness`, or `$AMI_CORE`),
**ami-chat.nvim** (`../ami-chat.nvim` — the controller this renderer drives), and this
extension. Requires `vhs` (`brew install vhs`) and a running LM Studio.

The tape opens `:AmiChat` (which renders as a right-hand split here) and sends a
question; watch the `⟳ streaming…` indicator in the prompt winbar while the reply
streams. Lengthen the final `Sleep` for slower models.
