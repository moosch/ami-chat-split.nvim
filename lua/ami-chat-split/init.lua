-- ami-chat-split: a split-window chat UI for ami.
--
-- A reference ami extension — it replaces ami-chat.nvim's floating panel with a
-- real window split (a sidebar column: transcript on top, prompt below) by
-- providing the "chat_ui" capability that the chat controller drives. Install it
-- alongside ami AND ami-chat.nvim, and register both:
--
--   require("ami").setup({
--     extensions = { require("ami-chat"), require("ami-chat-split") },
--     -- optional: chat_split = { side = "right", width = 0.33, prompt_height = 6 }
--   })
--
-- It implements the full chat_ui contract (see ami's docs/extensions.md):
-- open/show/close/is_open/owns_buf/append/clear/set_status/read_input/clear_input.
-- It also hooks the chat_turn_pre/post lifecycle events (api.on) to show a
-- streaming indicator in the prompt winbar for the whole turn.

-- The renderer. A single table instance is provided to ami as the chat_ui.
local R = {
  transcript_buf = nil,
  prompt_buf = nil,
  transcript_win = nil,
  prompt_win = nil,
  _status_text = nil,
  _cfg = nil, -- api.config, set in setup()
}

-- Prompt winbar; a streaming indicator is appended while a turn is in flight.
local PROMPT_BAR = " Ask  (⏎ normal = send · ⌃n new · q close) "

local function cfg()
  return R._cfg or {}
end

-- Resolve a width given as a fraction of columns (0<v<=1) or absolute cells (>1).
local function resolve_width()
  local total = vim.o.columns
  local v = cfg().width
  if not v or v <= 0 then
    return math.floor(total * 0.33)
  end
  local w = (v <= 1) and math.floor(total * v) or math.floor(v)
  return math.max(30, math.min(w, total - 10))
end

local function win_valid(w)
  return w and vim.api.nvim_win_is_valid(w)
end

-- Highlight the transcript like telescope's previewer: treesitter (markdown, with
-- per-language fenced-code injections) when available, else regex syntax.
local function start_highlight(buf)
  local ts = vim.treesitter
  if ts and ts.highlighter and ts.highlighter.active[buf] then
    return
  end
  if not (ts and ts.start and pcall(ts.start, buf, "markdown")) then
    pcall(function() vim.bo[buf].syntax = "markdown" end)
  end
end

local function ensure_bufs()
  if not (R.transcript_buf and vim.api.nvim_buf_is_valid(R.transcript_buf)) then
    R.transcript_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[R.transcript_buf].bufhidden = "hide"
    vim.bo[R.transcript_buf].buftype = "nofile"
    vim.bo[R.transcript_buf].filetype = "markdown"
    pcall(vim.api.nvim_buf_set_name, R.transcript_buf, "ami://chat")
    start_highlight(R.transcript_buf)
  end
  if not (R.prompt_buf and vim.api.nvim_buf_is_valid(R.prompt_buf)) then
    R.prompt_buf = vim.api.nvim_create_buf(false, true)
    vim.bo[R.prompt_buf].bufhidden = "hide"
    vim.bo[R.prompt_buf].buftype = "nofile"
    vim.bo[R.prompt_buf].filetype = "markdown"
  end
end

local function style_win(win, winbar)
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].winfixwidth = true
  vim.wo[win].winfixheight = true
  if winbar then
    vim.wo[win].winbar = winbar
  end
end

-- Build the split layout. When focus_prompt is false, focus returns to the window
-- that was active before (show() must not steal focus).
local function open_layout(ctl, focus_prompt)
  ensure_bufs()
  if win_valid(R.transcript_win) or win_valid(R.prompt_win) then
    if focus_prompt and win_valid(R.prompt_win) then
      vim.api.nvim_set_current_win(R.prompt_win)
      vim.cmd("startinsert")
    end
    return
  end

  local prev = vim.api.nvim_get_current_win()

  -- Vertical split on the chosen side, spanning full height.
  local side = cfg().side or "right"
  vim.cmd(side == "left" and "topleft vsplit" or "botright vsplit")
  R.transcript_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(R.transcript_win, R.transcript_buf)
  vim.api.nvim_win_set_width(R.transcript_win, resolve_width())
  style_win(R.transcript_win, " ami · advisor ")

  -- Prompt: a short window split off the bottom of the transcript column.
  vim.api.nvim_set_current_win(R.transcript_win)
  vim.cmd("belowright split")
  R.prompt_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(R.prompt_win, R.prompt_buf)
  vim.api.nvim_win_set_height(R.prompt_win, cfg().prompt_height or 6)
  style_win(R.prompt_win, PROMPT_BAR)

  local opts = { buffer = R.prompt_buf, nowait = true, silent = true }
  vim.keymap.set("n", "<CR>", ctl.submit, opts)
  vim.keymap.set({ "n", "i" }, "<C-s>", ctl.submit, opts)
  vim.keymap.set({ "n", "i" }, "<C-n>", ctl.new_session, opts)
  vim.keymap.set("n", "q", ctl.close, opts)
  vim.keymap.set("n", "<Esc>", ctl.close, opts)

  if focus_prompt then
    vim.api.nvim_set_current_win(R.prompt_win)
    vim.cmd("startinsert")
  elseif win_valid(prev) then
    vim.api.nvim_set_current_win(prev)
  end
end

-- chat_ui contract ------------------------------------------------------------

function R.open(ctl)
  R._ctl = ctl
  open_layout(ctl, true)
end

function R.show()
  -- Reuse the controller callbacks captured on the last open, if any.
  open_layout(R._ctl or { submit = function() end, new_session = function() end, close = R.close }, false)
end

function R.close()
  if win_valid(R.prompt_win) then
    pcall(vim.api.nvim_win_close, R.prompt_win, true)
  end
  R.prompt_win = nil
  if win_valid(R.transcript_win) then
    pcall(vim.api.nvim_win_close, R.transcript_win, true)
  end
  R.transcript_win = nil
end

function R.is_open()
  return win_valid(R.transcript_win) or win_valid(R.prompt_win) or false
end

function R.owns_buf(bufnr)
  return bufnr == R.transcript_buf or bufnr == R.prompt_buf
end

function R.append(text)
  ensure_bufs()
  local buf = R.transcript_buf
  local last = vim.api.nvim_buf_line_count(buf) - 1
  local last_line = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or ""
  local parts = vim.split(last_line .. text, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(buf, last, last + 1, false, parts)
  if win_valid(R.transcript_win) then
    vim.api.nvim_win_set_cursor(R.transcript_win, { vim.api.nvim_buf_line_count(buf), 0 })
  end
end

function R.clear()
  ensure_bufs()
  vim.api.nvim_buf_set_lines(R.transcript_buf, 0, -1, false, {})
end

function R.set_status(text)
  if text then
    R.append(text)
    R._status_text = text
    return
  end
  if not R._status_text then
    return
  end
  local want = R._status_text
  R._status_text = nil
  ensure_bufs()
  local buf = R.transcript_buf
  local last = vim.api.nvim_buf_line_count(buf) - 1
  local line = vim.api.nvim_buf_get_lines(buf, last, last + 1, false)[1] or ""
  if line == want then
    vim.api.nvim_buf_set_lines(buf, last, last + 1, false, { "" })
  end
end

function R.read_input()
  if not (R.prompt_buf and vim.api.nvim_buf_is_valid(R.prompt_buf)) then
    return ""
  end
  return table.concat(vim.api.nvim_buf_get_lines(R.prompt_buf, 0, -1, false), "\n")
end

function R.clear_input()
  if R.prompt_buf and vim.api.nvim_buf_is_valid(R.prompt_buf) then
    vim.api.nvim_buf_set_lines(R.prompt_buf, 0, -1, false, {})
  end
end

-- Show/hide a streaming indicator in the prompt winbar. Driven by the
-- chat_turn_pre/post events, so it covers the whole turn (set_status only covers
-- the wait before the first token).
function R.set_busy(on)
  if win_valid(R.prompt_win) then
    vim.wo[R.prompt_win].winbar = PROMPT_BAR .. (on and "  ⟳ streaming…" or "")
  end
end

-- Extension spec --------------------------------------------------------------

return {
  name = "chat-split",
  config = {
    side = "right",      -- "right" | "left"
    width = 0.33,        -- fraction of columns (<=1) or absolute columns (>1)
    prompt_height = 6,   -- input window height in lines
  },
  setup = function(api)
    R._cfg = api.config
    api.provide("chat_ui", R)
    -- Reflect streaming state in the prompt winbar for the whole turn.
    api.on("chat_turn_pre", function() R.set_busy(true) end)
    api.on("chat_turn_post", function() R.set_busy(false) end)
    api.log.debug("chat-split: registered chat_ui renderer + turn hooks")
  end,
}
