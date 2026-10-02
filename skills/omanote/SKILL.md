---
name: omanote
description: >
  Save, find, read and add to the user's notes in Omanote, the notes app in the
  Omarchy shell (its Pages: a tree of pages made of blocks). Use when the user asks
  to write something down, save or keep a note, a plan, summary, list, checklist or
  meeting notes, set a reminder in their notes, add to an existing page, or look
  something up in their notes. Triggers: note, notes, Omanote, "save this",
  "write it down", "add to my notes", "put it in my notes", "remind me",
  "what did I write about", "my Inbox".
---

# Omanote

Omanote runs inside the Omarchy shell. Work with it only through
`omarchy-shell omanote <command>`: the app does every write, so a page shows up
in its window as you add it, and its links and reminders work. Never edit the
files in ~/Documents/Omanote yourself.

Every command prints JSON (`{"ok": false, "error": "..."}` when it can't),
except `read`, which prints the page as Markdown.

| Command | What it does |
|---|---|
| `omarchy-shell omanote find "<words>"` | pages with all the words, best first: `[{id, title, path, snippet}]` |
| `omarchy-shell omanote list` | every page: `[{id, title, icon, path}]` (`path`: the pages it's inside) |
| `omarchy-shell omanote read <id>` | the page as Markdown |
| `omarchy-shell omanote add "<title>" <file.md>` | a new page in the Inbox: `{id, title, path}` |
| `omarchy-shell omanote addTo <page id> "<title>" <file.md>` | a new page inside that page (`""` for the top of Pages) |
| `omarchy-shell omanote append <id> <file.md>` | the Markdown added at the end of a page |
| `omarchy-shell omanote blocks <id>` | the page's blocks in order: `[{id, type, depth, text}]` (`text` in Markdown, `depth`: how far inside other blocks) |
| `omarchy-shell omanote replace <page id> <block id> <file.md>` | the Markdown in place of that block and the blocks inside it |
| `omarchy-shell omanote insertAfter <page id> <block id> <file.md>` | the Markdown after that block (and the blocks inside it), as deep as it is |
| `omarchy-shell omanote trash <id>` | the page (and the pages in it) to the trash, where it can be put back |
| `omarchy-shell omanote open <id>` | shows the page in Omanote's window |
| `omarchy-shell omanote help` | all of this, as JSON |

## Writing a page

Content goes in as a Markdown file, by its full path (an argument can't carry a
page). An empty title (`""`) takes the file's first `# heading`.

```bash
f=$(mktemp "$XDG_RUNTIME_DIR/omanote-XXXXXX.md")
cat > "$f" <<'EOF'
# Lisbon trip

- [ ] Book the tram tour [⏰ Fri 2 Oct 9:30](omanote://remind/2026-10-02T09:30)
- [x] Flights
EOF
omarchy-shell omanote add "" "$f"
rm -f "$f"
```

Markdown becomes Omanote's blocks: headings, paragraphs, bulleted and numbered
lists (nested), `- [ ]` and `- [x]` to-dos, code blocks with their language,
quotes, `> [!NOTE]` callouts, **bold**, *italic*, ~~struck~~, `code`, links, and:

- `[[Page title]]`: a link to the page called that (plain text when there's none)
- `[@Fri 2 Oct](omanote://date/2026-10-02)`: a date
- `[⏰ Fri 2 Oct 9:30](omanote://remind/2026-10-02T09:30)`: a reminder, in the
  user's local time. Omarchy shows a notification then; clicking it opens the page.

## Mind maps

When the user asks for a mind map, write it as a `mindmap` code block and
Omanote draws it as one: the topic on the first line, each idea on a line of
its own, indented two spaces under the idea it branches from.

````markdown
```mindmap
Launch plan
  Marketing
    Blog post
    Newsletter
  Engineering
    Release notes
```
````

Keep each idea to a few words. A map holds up to 300 ideas, 8 levels deep.

An idea can have a text color and a background, in braces at the end of its
line: `Marketing {red}`, `Marketing {blue background}`, or both,
`Marketing {red, yellow background}`. The colors are gray, brown, orange,
yellow, green, blue, purple, pink and red, which follow the user's light or
dark theme, or any hex color (`{#ff8800}`, `{#1e66f5 background}`), which
stays as it is; Omanote makes text readable on any background that has no
text color of its own. A main idea's color (its
background's, else its text's) colors its whole branch, so color the main
ideas when the user asks for a colored map; with none, each branch gets a
color of its own.
Mermaid's `mindmap` syntax (in a `mermaid` block) is read too. `read` and
`blocks` give a map back the same way (`blocks`: its `text`); to change one,
`replace` its block with a new `mindmap` block.

## Tables

A Markdown table is a table in Omanote, its first row the header row. A
cell can have **bold**, *italic*, links and `<br>` for a new line in it.
`read` and `blocks` give a table back as Markdown (`blocks`: its `text`); to
change one, `replace` its block with the whole table as you want it. Cell
colors are set in Omanote and aren't in the Markdown, so replacing a colored
table takes its colors off: say so when you do.

```markdown
| Item    | Planned | Spent |
|---------|---------|-------|
| Flights | €420    | €398  |
| Hotel   | €360    |       |
```

## Changing blocks on a page

`blocks <id>` gives each block's id. `replace` puts your Markdown in place of a
block and everything inside it; `insertAfter` puts it after them. Both keep the
block's depth. Neither works on columns themselves (change the blocks inside
them), and `replace` won't take a block with pages inside it.

## When Omanote asks you

The user can ask you from inside Omanote ("Ask agent", Ctrl+J). The prompt
names the page and what they picked: blocks by id, the words they selected
(in a block, by its id), or an empty line by its block id, which is where your
writing goes (`replace` that block). Read what you need with `blocks` or
`read`, make the change, and say what you did.

## Rules

- Look before you write: `find` first, and `append` to a page that's already
  about the subject rather than making a second one.
- Put a page where the user says (`find` the page they name, then `addTo` it);
  otherwise `add` puts it in the Inbox.
- Tell the user the page's title and where it went (`path`).
- Never `trash` a page unless the user asked for that page to go.
- A locked page can't be changed: say so, and don't work around it.
- Omanote keeps the page as it was (its *Page history*) before each change
  you make, so the user can put it back; still, change only what was asked.
- If a command says the pages aren't loaded yet, or omarchy-shell isn't
  running, wait a moment and try once more. Don't fall back to editing files.
