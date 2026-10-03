---
name: omanote
description: >
  Save, find, read and add to the user's notes in Omanote, the notes app in the
  Omarchy shell (its Pages: a tree of pages made of blocks). Use when the user asks
  to write something down, save or keep a note, a plan, summary, list, checklist or
  meeting notes, set a reminder in their notes, add to an existing page, or look
  something up in their notes, or work with their Omanote calendar, People
  (contacts), boards, pictures and galleries, templates, settings, page history,
  notebooks, profiles (notes kept apart: personal, work, a client, the demo),
  backups (back up, restore) or Omanote's version and updates. Triggers: note, notes, Omanote, profile, "save this",
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
| `omarchy-shell omanote contacts "<words>"` | the user's people (People): `[{id, name, company, title, phones: [{label, number}], emails: [{label, email}], birthday}]`; `""` for everyone |
| `omarchy-shell omanote contact "<id or name>"` | one person with their address, website, notes and the pages they're named on |
| `omarchy-shell omanote addContact "<name>" "<phone>" "<email>"` | someone new in People (`""` for what you don't know); someone with that email or number already is filled in |
| `omarchy-shell omanote importContacts <file>` | the people in a `.vcf` or `.csv` put in People (those there already filled in) |
| `omarchy-shell omanote library <kind> "<words>"` | what's been put on the pages (the Library), newest first: `[{kind, title, detail, url, file, page, pageTitle, block, added}]`; kind `link`, `file`, `video`, `picture`, `audio`, `meeting`, `sketch`, `person` (`person`: their id), `email` or `""` for all; words `""` for all (`file` is its path on disk) |
| `omarchy-shell omanote tagged "#tag"` | every block with the tag: `[{page, title, block, type, text, checked}]` |
| `omarchy-shell omanote tagColor "#tag" <color>` | the tag's color: `gray`, `brown`, `orange`, `yellow`, `green`, `blue`, `purple`, `pink`, `red`, a hex like `#ff8800`, or `""` for none |
| `omarchy-shell omanote projects` | every project (not the archive's): `[{id, title, status, due, progress, overdue, path}]` |
| `omarchy-shell omanote project <id> <status> <due>` | makes the page a project or changes it: status `planning`, `active`, `paused`, `done` (`""` keeps it, `none` makes it a page again); due `2026-10-12`, `""` for none, `-` keeps it |
| `omarchy-shell omanote events <from> <to>` | the user's calendar from `from` to `to` (`2026-10-05`; `"" ""` is today and the week on): `{events: [{id, title, start, end, allDay, place, repeats, notes}], notes: [{kind, page, title, text, at}]}` (`notes` on an event is its notes page's id; `notes` are their reminders and projects' due dates) |
| `omarchy-shell omanote addEvent <what and when> <repeat>` | puts an event on the user's calendar: `"Dentist oct 12 3pm"`, `"Standup mon 9:30-9:45"`, `"Holiday dec 24"` (all day); repeat `daily`, `weekdays`, `weekly`, `monthly`, `yearly` or `""` |
| `omarchy-shell omanote removeEvent <id>` | takes an event off the calendar (all of it, if it repeats). Only when the user asks |
| `omarchy-shell omanote templates` | the user's templates: `[{id, title, icon, description, pages}]` (`description`: what it's for) |
| `omarchy-shell omanote addTemplate "<title>" <file.md> "<description>"` | a new template from Markdown (`""` title: its `# heading`); `{{date}}`, `{{weekday}}`, `{{time}}`, `{{month}}`, `{{year}}`, `{{week}}` are filled in when it's used; description: what it's for, in a line (`""` for none) |
| `omarchy-shell omanote describeTemplate <template> "<text>"` | what a template's for (its name or id), shown on its card in Templates |
| `omarchy-shell omanote fromTemplate <template> <title> <parent>` | a new page from one of the user's templates (its name or id): `title` (`""` for the template's), in `parent` (`""` the Inbox, `top` the top of Pages, or a page id); `{{date}}` and the like in it are filled in. Use it when the user asks for a page "from my <name> template" |
| `omarchy-shell omanote archive <id>` | puts the page (and the pages in it) away in the archive; `unarchive <id>` brings it back |
| `omarchy-shell omanote trash <id>` | the page (and the pages in it) to the trash, where it can be put back |
| `omarchy-shell omanote trashed` | what's in the trash: `[{id, title, in, trashed}]` (`in`: the page it was in) |
| `omarchy-shell omanote restore <id>` | a page out of the trash, back where it was |
| `omarchy-shell omanote rename <id> "<title>"` | the page's title |
| `omarchy-shell omanote move <id> <parent> <position>` | the page inside another page (`top` for the top of Pages), at `position` among the pages there (`0` is first, `""` the end) |
| `omarchy-shell omanote icon <id> <emoji>` | the page's icon: one emoji, `""` for none |
| `omarchy-shell omanote cover <id> <cover>` | the page's cover: `gradient:0` to `gradient:11`, `""` for none |
| `omarchy-shell omanote lock <id> true\|false` | locks the page (nothing changes it, the user's edits or yours) or unlocks it |
| `omarchy-shell omanote favorite <id> true\|false` | the page in the sidebar's Favorites, or out of them |
| `omarchy-shell omanote duplicate <id>` | a copy of the page (and the pages in it), right after it: `{id}` |
| `omarchy-shell omanote makeTemplate <id>` | a copy of the page kept as one of the user's templates |
| `omarchy-shell omanote history <id>` | the page's kept versions, newest first: `[{name, kept}]` (the first time: "ask again in a moment") |
| `omarchy-shell omanote version <id> <name>` | one version, as Markdown |
| `omarchy-shell omanote restoreVersion <id> <name>` | the page as that version was (the page as it is now is kept first; the pages inside it stay) |
| `omarchy-shell omanote check <page id> <block id> true\|false` | ticks a to-do or unticks it |
| `omarchy-shell omanote color <page id> <block id> <color>` | a block's color: `blue` (its text), `blue_background` (behind it), `""` for none; a card (board, file, video, bookmark, button, person, email) takes a hex too (`#ff8800`, `#ff8800_background`) |
| `omarchy-shell omanote removeBlock <page id> <block id>` | takes the block (and the blocks inside it) off the page. Only when the user asks |
| `omarchy-shell omanote board <page id> <block id> <action> <a> <b>` | changes a board: `add "<text>" "<column>"` (`""`: the first), `move <card> <column>`, `edit <card> "<text>"`, `remove <card>`, `addColumn "<name>"`, `renameColumn <column> "<name>"`, `removeColumn <column>`, `height <px>` (160 to 2000; `0` as tall as its cards), `columnWidth <column> <px>` (160 to 600; `0` as fits), `cardColor <card> <color>`, `columnColor <column> <color>` (`blue`, `#ff8800`, either with `_background`, `""` for none); a card or column by its id or its text |
| `omarchy-shell omanote attach <page id> <file>` | a file at the end of the page, copied into Pages: a picture, a video, an `.eml` (an email card), any other file (a PDF shows page by page). It shows in a moment |
| `omarchy-shell omanote picture <page id> <block id> <width> <align>` | a picture's size: width a percent of the page's (`15` to `100`; `"40%"` and `0.4` work too), align `left`, `center` or `right`; `""` keeps either |
| `omarchy-shell omanote addGallery <page id> "<pictures>" <columns>` | a gallery at the end of the page: the pictures' full paths, one a line or `\|` between them, or a folder (its pictures, A to Z); `2`, `3` or `4` to a row (`""`: 3). They're copied into Pages; it shows in a moment |
| `omarchy-shell omanote gallery <page id> <block id> <action> <a> <b>` | changes a gallery: `add "<pictures or a folder>"`, `remove <n>`, `move <n> <to>`, `caption <n> "<text>"`, `columns 2\|3\|4`, `height <px>` (80 to 800; `0` as they were); a picture by its place (`1` is first) or its `src` |
| `omarchy-shell omanote bookmark <page id> <url>` | a link at the end of the page as a card with its title, a line and its picture. It shows in a moment |
| `omarchy-shell omanote setLink <page id> <block id> <link>` | changes a link: a bookmark's URL (its card read again, in a moment), or a link to a page's page (its id or title) |
| `omarchy-shell omanote editEvent <id> <field> <value>` | changes an event: `title`, `when` (`"fri 3pm"`, `"oct 12 9:30-10:00"`), `start`/`end` (`2026-10-05`, `2026-10-05T09:30`), `allDay`, `place`, `notes`, `repeat` (`daily`... or `""`), `alert` (minutes before: 0, 5, 10, 15, 30, 60, 120, 1440, or `none`), `color` |
| `omarchy-shell omanote editContact "<id or name>" <field> "<value>"` | changes someone in People: `name`, `company`, `title`, `birthday` (`1990-04-12`, `--04-12`), `address`, `website`, `notes`; `phone`/`email` add one (`"mobile: +1 555 123 4567"`); `removePhone`/`removeEmail` take one off |
| `omarchy-shell omanote removeContact <id>` | takes someone out of People. Only when the user asks |
| `omarchy-shell omanote importCalendar <file.ics>` | an `.ics` file's events (a booking, an invitation, another calendar's export) on the user's calendar; those there already are skipped: `{added, skipped}` |
| `omarchy-shell omanote renameTag "#tag" "#new"` | renames a tag on every page |
| `omarchy-shell omanote removeTag "#tag"` | takes a tag off every page (the `#tag` comes out of the text). Only when the user asks |
| `omarchy-shell omanote notebooks` | the notebooks on the shelf (Notebooks, the handwritten-style space): `[{id, title, pages, modified}]` |
| `omarchy-shell omanote notebook <id>` | a notebook's pages in order: `[{id, n, title, day, text}]` (`text`: its first words) |
| `omarchy-shell omanote readNotebook <id> <page id>` | a notebook's page as Markdown |
| `omarchy-shell omanote addToNotebook <id> <file.md>` | a new page at the end of a notebook (headings, lists, to-dos, quotes, paragraphs) |
| `omarchy-shell omanote open <id>` | shows the page in Omanote's window |
| `omarchy-shell omanote preferences` | every setting: `[{key, value, kind, choices, range}]` |
| `omarchy-shell omanote set <key> <value>` | changes a setting (checked as Settings does): `set scrollSpeed faster`, `set paper grid`, `set colorPage "#1e1e2e"`. Only when the user asks |
| `omarchy-shell omanote profiles` | the user's profiles (notes kept apart): `[{id, name, folder, open, demo}]`; every other command works on the open one |
| `omarchy-shell omanote profile "<name or id>"` | opens another profile. Only when the user asks (say which one you're in when it matters) |
| `omarchy-shell omanote addProfile "<name>" "<folder>" true\|false` | a new profile; `""` folder for `~/Documents/Omanote <name>` (an empty folder starts fresh; one with Omanote's notes opens them); `true` opens it. It starts empty, with the templates |
| `omarchy-shell omanote renameProfile "<name or id>" "<new name>"` | a profile's name |
| `omarchy-shell omanote profileFolder "<name or id>" "<folder>"` | a profile's notes looked for in another folder (nothing is moved) |
| `omarchy-shell omanote removeProfile "<name or id>"` | takes a profile off the list (not the open one); its notes stay in their folder. Only when the user asks |
| `omarchy-shell omanote demo` | opens the demo profile (example pages, people, events, templates), made the first time; `restartDemo` makes it new (the old one to the trash), only when the user asks |
| `omarchy-shell omanote backup "<profile>"` | a backup (one `.tar.gz` in the backup folder) of the open profile (`""`), every profile (`all`; not the demo), or one by its name or id. It's written in a moment |
| `omarchy-shell omanote backups` | the backups in the backup folder, newest first: `{folder, working, last, lastFailed, backups: [{name, file, made, size, automatic}]}` |
| `omarchy-shell omanote restoreBackup <file> true\|false` | puts a backup back: each profile in it a new profile, in a new folder (nothing there is changed); `true` opens the first. Only when the user asks |
| `omarchy-shell omanote appVersion` | the version running and whether there's a newer one: `{version, latest, updateAvailable, status, checked, canUpdateItself, update, releases}` (`status`: `current`, `available`, `none` (no releases yet), `failed`, `idle` (not asked yet)) |
| `omarchy-shell omanote checkUpdate` | asks GitHub for the newest version now; `appVersion` says what it found a few seconds later |
| `omarchy-shell omanote releaseNotes` | what's new, as Markdown: the newer releases' notes, or (up to date) the notes of the version running |
| `omarchy-shell omanote installUpdate` | installs the newer version (`omarchy plugin update`, only for an Omanote installed from git); Omanote starts again. Only when the user asks |
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

## Boards, bookmarks, links, galleries, people, agendas and events in Markdown

`read` gives these blocks as fenced code, and `add`, `append`, `replace` and
`insertAfter` take them the same way:

````markdown
```board
## To do
- Write the spec
- Fix login

## Doing

## Done
```

```bookmark
https://example.com/guide
```

```contact
Sam Rivera
```

```agenda
2026-10-05
```

```event
<an event's id, from events>
```

```link
Lisbon trip
```

```gallery
columns: 3
height: 240
![Tram 28](assets/20261002-tram.jpg)
![](assets/20261002-beach.png)
```
````

A `board`'s columns are `## Name` lines, each card a `- ` line under its
column. A `contact` is someone in People: their name, email or id (someone
not in People yet keeps the name; `addContact` them first if the user wants
them kept). An `agenda` shows a day's events (`today` for whatever day it is
when it's looked at). A `link` is a link to a page, by its title or id
(`read` gives the id, then the title). A `gallery` takes pictures already in
Pages/assets (`blocks` and `read` give their `src`); to put new pictures in
one, use `addGallery` or `gallery ... add`, which copy them in. To change one
card on a board, use `board` (it keeps the board's colors), not `replace`.

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

## Boards, files, bookmarks, buttons, synced blocks

`blocks` lists these with their words in `text`: a `board` as Markdown (a
column a bold line, its cards a list), a `bookmark` as its link (and `url`),
a `file` or `video` as its name and size (and `src`, in Pages/assets), a
`button` as its words. A `synced` block's `text` names the page its blocks
are on (`synced`): `read` or `blocks` that page for what it says, and change
it there (it changes everywhere the synced block is). A board's block in
`blocks` has `board: {columns: [{id, name, cards: [{id, text}]}]}`: change its
cards and columns with `board`. Don't `replace` these blocks unless the user
asks. `attach` and `bookmark` put a file or a link card on a page; `setLink`
changes a bookmark's link, or which page a link to a page goes to.

People: `contacts` and `contact "Sam"` answer "what's Sam's number?" and
"who's at Acme?". In Markdown a person on a page is
`[@Sam Rivera](omanote://contact/<id>)` (keep those links as they are; to
name someone, use their id from `contacts`). Add or change people only when
the user asks (`addContact`, `importContacts`, `editContact`), and take
someone out (`removeContact`) only when they say to.

An `email` block is a saved email (an .eml in Pages/assets): `blocks` gives
its subject, from, to, date and first lines in `text` (and `src`, the
file); `library email` lists every saved email with the page it's on.

`library` lists everything on the pages in one go (the app's Library):
bookmarks and links written in text, files and PDFs, videos, pictures,
audio notes, meetings and sketches, each with the page it's on. Use it for
"which PDFs do I have", "that link about…", "where's the video of…"; a
file's `file` is its path, to read it if the user asks (a PDF with
`pdftotext`, say).

## Pictures and galleries

A picture's block in `blocks` has `src` (in Pages/assets), `width` (a percent
of the page's) and `align`. When the user asks for a picture smaller, bigger
or to one side, use `picture` ("make the map half as wide" is
`picture <page> <block> 50 ""`). For several pictures, `addGallery` makes a
grid of them (a folder works: "make a gallery of ~/Pictures/Lisbon"), and
`gallery` adds, removes, reorders and captions them or changes its columns
and height. In `blocks` a gallery has `images` (`[{src, caption}]`),
`columns` and `height`. Pictures are copied in: the originals stay where
they are.

## Templates

`templates` lists the user's templates with what each is for. Make one only
when the user asks (`addTemplate` from Markdown, or `makeTemplate` from a
page they have), and give it a `description` so it reads well in Templates.
`fromTemplate` makes a page from one.

## Settings

`preferences` lists every setting with its value and what it can be
(`choices`, or a `range`); `set <key> <value>` changes one, as the Settings
panel would (Omanote's window follows at once). Change settings only when
the user asks ("scroll faster" is `set scrollSpeed faster`; the colors
`colorSidebar`, `colorPage`, `colorCards`, `colorText` take a hex, `""` for
the theme's). Profiles have their own commands (`profiles`, `addProfile`...),
not `set`.

## Backups and updates

When the user asks to back up their notes, `backup ""` backs up the open
profile and `backup all` every profile; then `backups` shows it (with
`last` saying how it went). Say where it went (`folder`). Automatic backups
are a setting (`set backupEvery daily`, `weekly` or `off`; `set backupKeep
10`); change them only when asked. `restoreBackup` never changes anything
there is: each profile in the backup comes back as a new one, in a new
folder; use it only when the user asks, and tell them the new profiles'
names (`profiles`).

"Is there a new version?" is `checkUpdate`, then `appVersion` a few seconds
later; `releaseNotes` says what's in it. Install it (`installUpdate`) only
when the user says to: Omanote restarts. If `canUpdateItself` is false, tell
them the command in `update` instead.

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

## Pages, the trash and history

Rename, move, lock, restore and copy pages when the user asks. Nothing a
command does deletes a page for good: `trash` can be undone with `restore`,
and before a command changes a page its version is kept (`history`,
`version`, `restoreVersion`), so "undo what you did to my page" is
`restoreVersion` with the version kept just before. A locked page refuses
every change until it's unlocked; unlock one only when the user asks.

## Notebooks

Besides Pages, Omanote has Notebooks: handwritten-style notebooks on a
shelf (a journal, say). `notebooks`, `notebook <id>` and `readNotebook` read
them; `addToNotebook` adds a page at the end of one. A notebook's page holds
simple blocks (headings, lists, to-dos, quotes, paragraphs), not boards or
tables. Write in a notebook only when the user names it.

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
