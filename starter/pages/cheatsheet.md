---
title: Omarchy cheatsheet
icon: 💻
order: 9
---
Commands worth keeping close. Click *Copy* on a block to copy it.

## Uber Notebook

| Keys | What |
|---|---|
| **Super+N** | Open or close Uber Notebook, from anywhere |
| **Super+Alt+N** | Jot a quick note |
| **Ctrl+P** | Find a page |
| **Ctrl+N** | A new page |
| **Ctrl+J** | Ask your agent |
| **Ctrl+Shift+C** | The calendar |
| **Ctrl+Shift+R** | An audio note |
| **Ctrl+Shift+D** | Dictate |

## The system

```bash
omarchy commands                # every command, with what it does
omarchy theme set catppuccin    # a new look
omarchy toggle nightlight       # easier on the eyes at night
omarchy update                  # everything up to date
omarchy reminder 15 "Tea"       # a nudge in 15 minutes
```

## Back up your notes

```bash
tar czf ~/uber-notebook-$(date +%F).tar.gz -C ~/Documents Uber Notebook
```

> [!NOTE] Your notes are plain files, so any backup tool works: copy the folder, sync it, or put it in git.

## Your notes, from a script

```bash
f=$(mktemp --suffix=.md)
printf -- '- [ ] Call the plumber\n- [ ] Buy milk\n' > "$f"
omarchy-shell uber-notebook add "Errands" "$f"
rm -f "$f"
```

```json
{
  "id": "marcho78.uber-notebook",
  "shortcut": "SUPER + N",
  "floating": true
}
```

Uber Notebook's settings live in its entry in `~/.config/omarchy/shell.json`, like the one above. Settings (**Ctrl+,**) changes them for you.
