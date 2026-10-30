# ami-chat-split — the chat panel as a window split
#
# Record with:  vhs demos/chat-split.tape
# Needs `vhs` + a running LM Studio, ami core, and ami-chat.nvim checked out next to
# this repo (this renderer drives ami-chat's controller). Set $AMI_CORE /
# $AMI_ENDPOINT / $AMI_CHAT_MODEL as needed.
#
# Shows the sidebar split (transcript on top, prompt below) and the "⟳ streaming…"
# indicator in the prompt winbar for the whole turn. Lengthen the Sleep after
# sending for slower models.

Output demos/chat-split.gif

Require nvim
Set Shell "bash"
Set FontSize 18
Set Width 1280
Set Height 760
Set Padding 20
Set Framerate 24
Set TypingSpeed 45ms
Set Theme "Catppuccin Mocha"

# --- setup (hidden): write a source file and open it ---
# \042 is printf's octal for a double quote; %% prints a literal %.
Hide
Type "printf 'package store\n\nimport (\n\t\042context\042\n\t\042database/sql\042\n\t\042errors\042\n\t\042fmt\042\n)\n\nvar ErrNotFound = errors.New(\042store: user not found\042)\n\n// Get loads one user by id, returning ErrNotFound when the row is absent.\nfunc Get(ctx context.Context, db *sql.DB, id string) (*User, error) {\n\trow := db.QueryRowContext(ctx, \042SELECT id, name, email FROM users WHERE id = $1\042, id)\n\tvar u User\n\tif err := row.Scan(&u.ID, &u.Name, &u.Email); err != nil {\n\t\treturn nil, fmt.Errorf(\042store.Get(%%q): %%w\042, id, err)\n\t}\n\treturn &u, nil\n}\n' > /tmp/ami_split_demo.go"
Enter
Type "nvim -u demos/init.lua /tmp/ami_split_demo.go"
Enter
Sleep 2s           # let the editor settle
Show
Sleep 1500ms       # show the plain source pane first

# --- open the chat: a split column docks on the right ---
Type ":AmiChat"
Enter
Sleep 2s
Type "What edge cases should Get handle, and how would you structure the errors?"
Escape
Enter

# --- the prompt winbar shows "⟳ streaming…" while the reply streams in ---
Sleep 20s
