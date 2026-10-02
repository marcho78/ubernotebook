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
| `omarchy-shell omanote tags` | every tag: `[{tag, name, pages, blocks}]` |
| `omarchy-shell omanote tagged "#tag"` | every block with the tag: `[{page, title, block, type, text, checked}]` |
| `omarchy-shell omanote tagColor "#tag" <color>` | the tag's color: `gray`, `brown`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `red`, a hex like `#ff8800`, or `""` for none |
| `omarchy-shell omanote projects` | every project (not the archive's): `[{id, title, status, due, progress, overdue, path}]` |
| `omarchy-shell omanote project <id> <status> <due>` | makes the page a project or changes it: status `planning`, `active`, `paused`, `done` (`""` keeps it, `none` makes it a page again); due `2026-10-12`, `""` for none, `-` keeps it |
| `omarchy-shell omanote templates` | the user's templates: `[{id, title, icon, pages}]` |
| `omarchy-shell omanote fromTemplate <template> <title> <parent>` | a new page from one of the user's templates (its name or id): `title` (`""` for the template's), in `parent` (`""` the Inbox, `top` the top of Pages, or a page id); `{{date}}` and the like in it are filled in. Use it when the user asks for a page "from my <name> template" |
| `omarchy-shell omanote archive <id>` | puts the page (and the pages in it) away in the archive; `unarchive <id>` brings it back |
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

## Sketches

A page can have sketches (drawings the user made). `blocks` lists one as
type `sketch`, text `(a drawing)`, and `read` as `*(A sketch, drawn in
Omanote)*`. You can't draw one or see what's in it; don't `replace` a sketch's
block unless the user asks for the drawing to go.

## Audio notes

A page can have audio notes (recordings the user made in Omanote). `blocks`
lists one as type `audio`, with `src` (its file in `Pages/assets`),
`duration` (seconds) and `text`: what was said in it, as voxtype wrote it
out, or `(an audio note, 1:42, not written out)`. `read` shows it as a link
to the file with what was said quoted under it. That text is the note's
transcript: use it to summarize a recording, pull out to-dos or answer what
was said. You can't record or play one; don't `replace` an audio note's block
unless the user asks for it to go.

## Meetings

A page can have meetings, recorded by voxtype's meeting mode. `blocks` lists
one as type `meeting`, with `title`, `duration` (seconds) and `text`: who
said what, a turn a line (`Sam (0:12): The notes are done.`; "You" is the
user, "Remote" the other side of a call unless they named them), or
`(a meeting recorded with voxtype, not written out yet)` while it's going.
When the user asks you to summarize a meeting (Omanote's Summarize button
asks you this way), read it and put right after its block: a short summary,
the decisions, and the action items as to-dos (`- [ ] Sam: screenshots by
Thursday`). Don't change or `replace` the meeting block itself.

## Projects

A page can be a project: a status (planning, active, paused, done), a due
date, and its progress (the to-dos on it and on the pages inside it). Make
one with `project <id> active 2026-10-12`, or write front matter at the top
of the Markdown you `add`:

```markdown
---
status: active
due: 2026-10-12
---
# Q4 launch
```

`projects` lists them, late ones with `overdue: true`. When the user says a
project is finished, set it `done`; `archive` it only when they ask.

## Tags

`#name` in a line is a tag (letters, digits, `-`, `_`, `/`; not only digits;
not in code): `- [ ] renew passport #errand`. Use the user's tags (`tags`
lists them) rather than making near-duplicates, and only tag when the user
asks or the page already uses tags. `tagged "#errand"` gives every block with
a tag (to-dos with `checked`), and `read` gives tags back as `#name`.
`tags` says each tag's `color` (a tag with none of its own takes the color of
the tag it's in: `#work/acme` takes `#work`'s, and says `colorFrom`). Color
tags with `tagColor` only when the user asks.

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
