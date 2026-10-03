# Omanote for Omarchy

![Omanote](screenshots/notebook.png)

Notebooks that look and feel like paper. Press **Super+N**, or click the
notebook in the top bar, and your notebooks are on the desk, cover up. Pick
one: it slides onto the desk, its cover swings open, and you write on the page
in the pen you like, on ruled, grid, dotted, graph or blank paper. The pages
turn over the binding, the text sits on the lines, and everything is saved as
you go, as plain files you own.

Or switch to **Pages**, the other way to write in Omanote: a workspace of
pages made of blocks, the way Notion does it. Type `/` for any kind of block,
drag blocks around by their handle, put blocks inside blocks and pages inside
pages, fold toggles, color anything.

* **A notebook on your desk.** Pebbled leather with a gold-foil title and an
  elastic band, linen or smooth card with a paper label, kraft with a typed
  stamp, or a marbled composition book with its name box; spiral-bound (wire
  through punched holes), sewn, or hardcover. Twelve cover colors, one of
  them your Omarchy theme's accent.
* **Real paper.** College-ruled with its red margin line, grid, dots, graph,
  a yellow legal pad with its double margin, or blank, on white, ivory, aged,
  yellow, kraft, recycled, night or blueprint paper, or on paper in your
  Omarchy theme's colors. Narrow, college or wide lines. Whatever the font or
  size, every line of text sits on a rule.
* **Pages that turn.** Ctrl+PgDown, or a click on the page's turned-up
  corner, turns the page over the binding, and the next one shows as it goes.
  Turn past the last page for a new one. Give a page an index tab and it
  sticks out of the notebook's edge.
* **Planners and templates.** A page can come laid out: a daily planner with
  your priorities and the day hour by hour, a weekly or monthly planner, a
  habit tracker with a circle to tick for each day, a journal, a to-do list,
  meeting and lecture notes, a project plan, a reading log, a recipe or a
  packing list. Make a notebook of planners and every new page is the next
  day, week or month.
* **Pages, the Notion way.** Every block is an atomic record with a UUID v4
  id; a page is a block too, and pages hold pages. `/` for headings, to-dos,
  toggles, callouts, code, quotes, sub-pages, links to pages, a table of
  contents; ⋮⋮ to drag a block (and what's inside it) anywhere, or turn it
  into another kind, color it, move it to another page; a toolbar over
  selected words; Markdown as you type; code in its language's colors;
  `:rocket:` emoji. A sidebar with the tree of pages and your favorites,
  covers, icons, templates, three fonts, full width, locked pages, search and
  a trash. No databases: just writing, as flexible as it gets.
* **Seven pens.** Clean, Book, Handwriting, Print, Typewriter, Mono and
  Writer: a notebook has one, and any words can have another.
* **Everything a notebook needs.** Headings, bulleted, numbered and
  checklists (ticked by hand, and crossed off), quotes, sticky notes in six
  colors, code, dividers, and pictures you paste, drop or pick. Bold, italic,
  underline, strikethrough, six inks and six highlighters, sizes from 11 to 64, links.
  Markdown shortcuts as you type: `- `, `1. `, `[] `, `# `, `> `.
* **Draw on the page.** A pen, a highlighter and an eraser, over the writing.
* **Find anything.** Search every page of every notebook from the shelf, or
  Ctrl+F on a page.
* **Quick notes.** Super+Alt+N pops up a sticky note wherever you are; what
  you write becomes a page in your Quick notes notebook, or, if you'd
  rather, a page in your Pages Inbox, written in Markdown.
* **Plain files.** Every notebook is a folder of JSON files in
  `~/Documents/Omanote`, pictures beside them; export any notebook as Markdown.

## Screenshots

**The shelf**, and a notebook **opening**:

![The shelf: five notebooks, cover up](screenshots/shelf.png)

![A leather notebook's cover swinging open](screenshots/opening.png)

**Turning a page**, and **drawing** on one:

![A page turning over the binding](screenshots/turning.png)

![A circled word, an arrow and a highlighter stroke drawn on a page](screenshots/drawing.png)

**Templates**, a **monthly planner** in the handwriting pen, and a **habit
tracker**:

![Every kind of page in miniature: planners, a habit tracker, a journal, lists, meeting and lecture notes and more](screenshots/templates.png)

![A monthly planner on dotted paper: the month's calendar with circled dates, goals, and a line for each day](screenshots/planner.png)

![A week of habits, each day's circle ticked by hand](screenshots/habits.png)

**Pages**: blocks inside blocks, toggles, callouts, colors, code, and the
`/` menu:

![A page in Pages: a toggle heading with a callout and to-dos inside it, colored blocks, lists, a quote, code, a folded toggle and a link to a page](screenshots/pages.png)

![The "/" menu: text, headings, lists, to-dos, toggles](screenshots/pages-slash.png)

Code in its language's colors, and a new page's templates:

![JavaScript, Python and YAML code blocks, each in its colors, on a dark page](screenshots/pages-code.png)

![An empty page with "Start with a template" and a chip for each template](screenshots/pages-templates.png)

**Papers and pens**:

![Ruled, grid, dots, legal, graph, blank, night and theme papers, in different pens](screenshots/papers.png)

**A new notebook**, a **quick note**, and **search**:

![Choosing a new notebook's cover, binding, paper and pen](screenshots/new-notebook.png)

![A quick note: a yellow sticky note over the desk](screenshots/quick-note.png)

![Searching every page for "tram"](screenshots/search.png)

## Requirements

Omarchy 4 (Quattro): the Omarchy shell on Quickshell 0.3 with Qt 6.11, and
Hyprland 0.56 or newer with its Lua configuration. Everything else it uses
ships with Omarchy: `wl-copy` and `wl-paste`, `grep`, `bash`, `uwsm-app` and
`xdg-open`, and the iA Writer and Noto fonts. Its own fonts come with it.
Nothing to build. Audio notes record with `ffmpeg`; dictation, and audio notes
written out, use voxtype, Omarchy's dictation (`omarchy voxtype install` if
you haven't set it up), with the model you picked for it.

## Install

```bash
omarchy plugin add https://github.com/marcho78/omanote.git --enable
```

That's all: no setup step, and your Hyprland config is not touched. Omanote
registers its shortcuts and window rules with Hyprland while it runs and takes
them back out when you disable it. It's in your app launcher too, as
*Omanote*, with its notebook icon. Enabling puts the notebook icon on the
right of the bar; move it with `omarchy bar move marcho78.omanote --section
left`. Omarchy keeps a plugin with a bar icon on for as long as the icon is in
the bar, so to keep Omanote without the icon, turn off **Show Omanote in the
top bar** in its settings: the icon then takes no space.

**Profiles.** Notes kept apart: personal, work, a client, the demo. Each
profile is a folder of its own, with its notebooks, Pages, calendar, People,
templates and Markdown copy; the one open is at the top of Pages' sidebar
and under *Notebooks* on the shelf, and a click there switches (what's open
is written first), makes a new one (its name, and the folder its notes go
in: picked, or suggested from its name), or opens **Manage profiles**
(Settings: rename one in place, give it another folder, open its folder,
take it off the list; its notes stay where they are). Each keeps its own
Inbox for agents, the page and notebook you were on, and its Markdown copy;
the rest of Settings is for all of them. Agents' commands work on the open
one; `omarchy-shell omanote profiles` lists them, `profile Work` opens one,
and `addProfile`, `renameProfile`, `profileFolder`, `removeProfile`, `demo`
and `restartDemo` do the rest (a new install's first profile too).

The first time it opens, Omanote asks for your first profile: its name and
the folder its notes go in (`~/Documents/Omanote` to start with). Nothing is
made anywhere until then. Or **Explore the demo** first: the demo is a
profile of its own, in Omanote's data folder (`~/.local/share/omanote`),
with a notebook of things to try and Pages full of examples of what it can
do (see [Pages](#pages)); *Start over* in Settings makes it new again (the
old one goes to the trash). A profile of your own starts empty, with the
templates. An Omanote from before profiles opens as it was: its folder is a
profile, *Personal*.

## Use

| To | Do |
|---|---|
| Open or close your notebooks | **Super+N**, click the notebook in the top bar, or *Omanote* in the app launcher |
| Jot a quick note from anywhere | **Super+Alt+N**, or right-click the notebook in the bar. The microphone on the note dictates: click it, speak, click it again (or hold it while you speak; **Ctrl+Shift+D**) |
| Open a notebook | Click it on the shelf |
| Back to the shelf | **Ctrl+W**, or *Notebooks* at the top left |
| Turn the page | **Ctrl+PgDown** / **Ctrl+PgUp**, **Alt+→** / **Alt+←**, or click the page's bottom corner |
| A new page | **Ctrl+N**, or turn past the last page (a planner's next day, week or month) |
| A page from a template | **Ctrl+T**, or **+** at the top right: a planner, a habit tracker, a journal, a list... |
| Every page in the notebook | **Ctrl+G**, or click *Page 3 of 12*: jump to one, move pages up and down |
| Find on this page | **Ctrl+F** (Enter for the next, Shift+Enter for the one before) |
| Search every notebook | Type in the search on the shelf |
| Draw | **Ctrl+Shift+D**, or the pen in the bar at the bottom: **P** pen, **M** highlighter, **E** eraser, Esc to write again |
| Change the paper | The page icon in the bar at the bottom, for this page or every page |
| An index tab on a page | ⋯ at the top right, then *Add a tab* |
| A notebook's cover, paper and pen | Its title at the top, or right-click it on the shelf |
| A new notebook | **Ctrl+Shift+N**, or *New notebook* on the shelf |
| Bigger or smaller | **Ctrl+=** / **Ctrl+-**, **Ctrl+0** to reset |
| Settings | **Ctrl+,**, or the cog on the shelf |
| Pages | *Pages* in the switch at the top right of the shelf (and *Notebooks* at the top of the Pages sidebar to go back) |
| Put Omanote away | **Esc** on the shelf, **Super+N**, or close the window |

Closing the window, or Omanote, keeps your place: it opens where you were.

## Writing

Type straight onto the page. Each paragraph, heading or list item is a block,
and the bar at the bottom shows the formatting where the cursor is.

**Markdown shortcuts**, typed at the start of a line and then a space:

| Type | For |
|---|---|
| `- ` or `* ` | a bulleted list |
| `1. ` | a numbered list (1, a, i as it goes deeper) |
| `[] ` or `[x] ` | a checklist item |
| `# `, `## `, `### ` | a title, a heading, a subheading |
| `> ` | a quote |
| `!! ` | a sticky note |
| ```` ``` ```` | code |
| `---` and Enter | a divider |
| `9:30 ` | a time slot at half past nine |

**Keys:**

| Keys | Do |
|---|---|
| Ctrl+B, Ctrl+I, Ctrl+U | bold, italic, underline |
| Ctrl+Shift+>, Ctrl+Shift+< | bigger, smaller text (or the size menu in the bar: 11 to 64) |
| Ctrl+Shift+X | strikethrough |
| Ctrl+Shift+H | highlight |
| Ctrl+E | code |
| Ctrl+K | a link (Ctrl+click a link to open it) |
| Ctrl+\\ | plain text again |
| Ctrl+Alt+1, 2, 3, 0 | title, heading, subheading, text |
| Ctrl+Shift+8, 7, 9 | bulleted, numbered, checklist |
| Ctrl+Enter | tick (or untick) a checklist item, or tick today off a habit |
| Tab, Shift+Tab | indent and outdent a list item |
| Shift+Enter | a new line in the same block |
| Ctrl+; | today's date |
| Ctrl+Shift+V | paste as plain text |
| Esc | pick the whole block; then Shift+↑/↓ picks more, Delete removes them, Alt+Shift+↑/↓ moves them, Ctrl+D duplicates them |
| Ctrl+A twice | pick every block |
| Ctrl+Z, Ctrl+Shift+Z | undo, redo |

Formatting with nothing selected applies to what you type next. Text too big
for one ruled line takes two or more, the way big writing does in a real
notebook, so it never runs into the line above. Enter on an
empty list item ends the list; Backspace at the start of a list item makes it
text again. Dragging from one block into another picks whole blocks. Pictures
come in by pasting them, dropping them on the page, or *Picture…* in the
**+** menu; click one to size it (drag its corner), place it, or remove it.

## Templates and planners

**+** at the top right (or **Ctrl+T**) shows every kind of page in
miniature, on your paper. Pick one with a click, or the arrows and Enter: it
goes on the page you're on while that's still blank, else on a new page
after it.

| Template | What's on it |
|---|---|
| Daily planner | the day as its title, top priorities, a schedule from 7:00 to 20:00, to-dos, notes |
| Weekly planner | the week's focus, each day with its to-dos, habits, notes |
| Monthly planner | the month's calendar, goals, a line for each day of the month, notes |
| Habit tracker | eight habits, each with a circle for every day of the week |
| Journal | what you're grateful for, what would make today great, a highlight, what you learned |
| To-do list | today, this week, someday |
| Meeting notes | who, agenda, notes, decisions, action items |
| Lecture notes | questions and keywords, notes, a summary |
| Project plan | the goal, milestones, tasks, risks, notes |
| Reading log | reading now, up next, favorite lines |
| Recipe | serves and time, ingredients, method, notes |
| Packing list | documents, clothes, toiletries, tech |

Everything on them is ordinary writing: type over it, move it, format it or
delete it. Empty parts show a faint hint of what they're for.

**A notebook of planners.** Choose *Pages* when you make a notebook (or in
its *Cover, paper and pen*): a daily, weekly or monthly planner, a habit
tracker, a journal, to-dos, meeting or lecture notes. Its first page is
today's, and each new page (**Ctrl+N**, or turning past the last) is the next
day, week or month, never one in the past: come back after a week away and
the next page is today's. Any page can still be another kind.

**Time slots.** A schedule's times sit in the margin. Enter at the end of a
slot goes to the next one, and after the last starts another an hour on (or
as far on as the slots before it: half-hourly stays half-hourly); click a
time to change it. Type `9:30 ` at the start of a line for a slot of your own.

**Habits.** Click a day's circle to tick it off, again to untick it;
**Ctrl+Enter** ticks today. Enter adds another habit.

**Calendars.** Today has a dot of color. Click a date to circle it, again to
rub it out; the arrows (when the pointer is over it, or it's picked) turn it
to another month. *Month calendar* in the bar's **+** menu puts one on any
page, as *Habit to track* and *Time slot* do those.

## Pages

Pages is the other way to write in Omanote: not a notebook on a desk, but a
workspace of pages, the way Notion does it. Switch to it with *Pages* at the
top right of the shelf; Omanote opens where you were last, notebooks or pages.

**The demo's examples.** The demo profile's Pages has pages that show what it can do, each a different kind of page:
*Welcome to Omanote* (and pages inside it on writing, staying organized and
your AI agent, and the keyboard shortcuts as a PDF), *This week* (agendas,
habits, a month), *Website relaunch* (a project with its board, milestones,
team, and meeting notes with the meeting in them), *Weekend in Lisbon* (the
flight's email, a plan, bookmarks, a budget), *Podcast ideas* (a mind map and
a sketch), a reading list, a recipe, a journal with a button for today's
entry, people to follow up, and an Omarchy cheatsheet. The people and events
they name are in People and on the calendar, dated from the day you start
(none of them sends a notification, and their emails and numbers reach
nobody), and *Templates* has six to start from (a weekly review, a 1:1, a
project brief, a trip, book notes, a decision). They're ordinary pages:
change them, or put them in the trash. They're made from `starter/`
(Markdown files, people, events and files: see `starter/README.md`).

**Everything is a block.** A line of text, a heading, a to-do, a toggle, a
callout, a picture, a page: each is an atomic record with its own id (a UUID
v4), its type, what it says, the blocks inside it and the block it's in. A
page is a block too, and a page inside a page is a *page* block on it. Blocks
inside a block go wherever it goes: dragged, moved, copied or deleted, it
takes them along.

| To | Do |
|---|---|
| A new block of any kind | Type **/** (then a few letters of its name: `/todo`, `/h2`, `/toggle`, `/page`, `/red`), or **+** beside a block |
| Move a block | Drag **⋮⋮** beside it (hover over the block); drag it right to put it inside the block above |
| Columns | Drag a block up the right side of another: the two go side by side (drop more beside them for up to six). Or `/2 columns` … `/5 columns`. Drag the gap between two columns to share the width differently |
| Turn it into another kind, color it, duplicate it, move it to another page, delete it | Click **⋮⋮** |
| Put a block inside the one above it, or take it out | **Tab**, **Shift+Tab** |
| Fold a toggle, or unfold it | Click its arrow, or **Ctrl+Enter** |
| Bold, italic, underline, strikethrough, code, a link, a color | Select the words: a toolbar comes up over them (or the notebook's shortcuts: Ctrl+B, Ctrl+I…) |
| Markdown as you type | `**bold**`, `*italic*`, `` `code` ``, `~~struck~~`; at the start of a line `# `, `- `, `1. `, `[] `, `> ` (a toggle), `" ` (a quote), ```` ``` ```` |
| Text, headings, to-do, bulleted, numbered, toggle, code | **Ctrl+Alt+0**…**3**, **4**, **5**, **6**, **7**, **8** |
| Move a block up or down | **Alt+Shift+↑/↓** |
| A new page | **Ctrl+N**, *New page* in the sidebar, or **+** beside a page there for one inside it |
| A page inside this page | `/page` |
| An email | `/email` (or drop an `.eml` on a page): a saved email, kept in `Pages/assets`, shown as a card: its subject, who it's from and to, when, its first lines and its attachments. **Show email** reads it in full: From, To, Cc and Date, then the message (an HTML email with its formatting and links, but no scripts, styles or pictures from the web, which would tell the sender you opened it). Click an attachment to open it in its app (it's saved beside the email the first time); a calendar file (`.ics`, a booking's or an invitation's) shows its events here instead, with *Add to calendar* (those already on it aren't added twice), and a contact card (`.vcf`) puts its people in People (*Undo* on the message takes them out); ↗ opens the `.eml` in your mail app. A file whose only app is a web browser (or that has none, like an `.eml` with no mail app set up) isn't handed to it, which would download it and take you away from Omanote: a message says so, and it stays in `Pages/assets`. Its colors are Pages' or your own. In the Library, under **Emails**, with who it's from and to and the page it's on; found by subject, sender or recipient. `.eml` is the standard format every mail app saves (Thunderbird, Apple Mail, Outlook, Gmail's *Download message*); Outlook's own `.msg` isn't read |
| A person in a line | **@** and a name: the people in *People* who match come first (with *New contact* for a name that isn't there yet). It's drawn as `@Sam Rivera`; click it for their card: their numbers and emails (a click copies one, ✉ opens your mail app) and *Open in People* |
| An email in a line | An email typed (then a space) or pasted becomes a link by itself: to your mail app, or, when it's someone's in *People*, to them (their card on a click) |
| A date in a line | **@** and a date: `@tomorrow`, `@fri 3pm`, `@in 2 hours`, `@oct 3`, `@2026-12-24` |
| A reminder | **@** and a date, then *Remind me*: an Omarchy notification then (click it to open the page) |
| A tag | **#** and a name, anywhere in a line: `#errand`, `#project/omanote` (letters, digits, `-`, `_` and `/`; not only digits). The **#** menu offers the tags you have (and a new one with what's typed); a space or a stop after a name makes it a tag too. A tag is drawn in its color; click it (or it in the sidebar's *Tags*, or find it with **Ctrl+P** and `#`) for every block with it, page by page: tick to-dos there, click a block to go to it on its page. At the top of that view: the tag's color (Pages' colors, or **Custom…**, the color picker), renaming it on every page (renamed to a tag you have, the two are one), and taking it off every page (each page keeps the version before in its *Page history*) |
| Color-code tags | A tag's **⋯** in the sidebar (or a right-click on it): *Color*, *Rename…*, *Take it off every page*; or the palette at the top of its blocks. A tag inside another (`#work/acme`) takes the color of the one it's in (`#work`) until it has its own, and sits under it in the sidebar. *A–Z* at the top of the sidebar's *Tags* sorts them by color instead (Pages' colors in order, then yours, then gray). The **#** menu shows each tag in its color |
| A link to a page, as a block | `/link`, then pick the page. Under the pointer, *Change* beside it picks another page (one step **Ctrl+Z** takes back); a link whose page is gone says so, and *Link to a page* fixes it |
| A link to a page in a line | **[[** and part of its name (or a new name, for a new page); click the link to go there |
| An emoji | **:** and part of its name: `:rocket`, `:tada`, `:+1` (pick one, or type the whole name and a closing `:`) |
| Ask your agent | The AI button at the top of the page, **Ctrl+J**, `/agent`, or *Ask agent* in a block's ⋮⋮ menu, on the toolbar over selected words, or in the page's ⋯ menu: Omarchy's default coding agent (Claude Code, Codex, OpenCode...) does it, and its changes show up on the page (see [For AI agents and scripts](#for-ai-agents-and-scripts)) |
| Start a page from a template | On a new, empty page: pick one under *Start with a template* (a daily, weekly or monthly planner, a journal, a habit tracker, meeting or lecture notes, a project plan, a to-do list, a reading log, a recipe, a packing list). Each is laid out as a page: sections side by side, a callout for the one thing that matters, the day hour by hour, habits to tick, the month's calendar, and on every empty line, faintly, what goes there. **Ctrl+Z** takes it back off |
| A mind map | `/mindmap`, or *Turn into mind map* in a nested list's ⋮⋮ menu (the top item is the topic, the items inside it the ideas). Click an idea to write on it: **Enter** adds the next idea, **Tab** one branching from it, **Shift+Tab** moves it out a level, **↑ ↓** move between ideas, **Backspace** on an empty idea takes it away, **Ctrl+Backspace** an idea and its branch, **Esc** stops. The color button over the idea you're writing on gives it a text color and a background (a main idea's color is its whole branch's): one of Pages' colors (which follow your light or dark theme), one you picked recently, or **Custom…**, a color picker (saturation and brightness, hue, a hex to type or paste, and how well the idea's text reads on it) that shows the color on the map as you pick it; **Enter** or *Apply* keeps it, **Esc** or *Cancel* puts back what was there. Text on a background with no text color of its own is made readable. The circle at an idea's end folds its branch. The block's own ⋮⋮ *Color* puts a background behind the whole map, or sets the text color of ideas with none of their own. *Turn into list* (⋮⋮) makes it a nested list again |
| A table | `/table` (or paste cells from a spreadsheet, or a Markdown table). Click a cell to write in it: **Tab** and **Shift+Tab** go to the next and previous cell (**Tab** in the last one makes a new row), **Enter** goes down a row (past the last, a new one), **Shift+Enter** is a new line in the cell, the arrows cross into the next cell at a cell's ends and leave the table at its top and bottom, **Esc** picks the whole table. **Ctrl+B**, **Ctrl+I**, **Ctrl+U**, **Ctrl+Shift+X** and **Ctrl+E** format what's selected in a cell (the toolbar over selected words is for text blocks). Point at a cell: the handle on its row's left and on its column's top open their menus (insert above or below, left or right; move; delete; *Header row* on or off), the **+** bars along the bottom and the right add a row or a column, and the lines between columns drag to make them wider. Colors: the color button on the cell you're in, or *Color* in a row's or a column's menu, gives a text color and a background: one of Pages' colors (which follow your light or dark theme), one you picked recently, or **Custom…**, the color picker (shown in the table as you pick, with how well the text reads; **Enter** keeps it, **Esc** puts back what was there). Cells pasted from a spreadsheet into a cell fill the table from there, and it grows to take them |
| A board | `/board`: cards in columns (To do, Doing, Done to start). A click on a card writes in it (Enter keeps it, Esc puts it back); *New* under a column adds one; a card drags to another place or column. Each card and each column has its own colors, its text's and its box's background (Pages' or your own): point at it and click its palette; the color menu says what it's coloring. A card's ⋯ (or a right-click on it): *Rename*, *Open as page* (it becomes a page inside this one, in the tree, and opens; after, *Open page*), *Delete*. A column's name is shaded under the pointer and a click renames it (or its ⋯, *Rename*); its ⋯ (or a right-click on it) also has moving it left or right, deleting it; **+** adds a column and puts you in its name. Drag a column's right edge to make it wider or narrower, and the board's bottom edge to make it taller or shorter (then it scrolls inside); a double-click on either edge puts it back as it fits. The palette at the board's corner colors the whole board. Each change is a step to undo; as Markdown, a column a bold line and its cards a list |
| A picture | `/image`: one picture, from the picture picker (a click on it), or *The file dialog…* there |
| Size a picture | Point at it: a handle at each corner, dragged any way (it keeps its shape), and one on each side; how wide it is shows as you drag, one step **Ctrl+Z** takes back; a double-click on a side's handle makes it the page's width. Click it for left, centered or right. A double-click on a picture shows it large, here in Omanote: **←** **→** for the page's other pictures, **Esc** to close, ↗ to open it in its app |
| A gallery | `/gallery`: pictures side by side, 2, 3 or 4 to a row (the numbers at its corner, under the pointer). Pick several at once in Omanote's picture picker (your pictures shown as pictures, Pictures' newest first, its folders first: a click chooses one, another lets it go, **Shift**+click a run of them, **Ctrl+A** all of them, then *Add 3 pictures*; Pictures, Downloads, Desktop and Home at its top; *The file dialog…* for the desktop's), or drop them on it; *Add pictures* under it for more. Under the pointer, a picture moves earlier or later, gets a caption, or goes; drag the gallery's bottom edge to make them taller or shorter (a double-click puts them back as they were). A click on one shows it large, the gallery's others a key away. Its colors (the palette at its corner): the captions', and behind it. Each picture is in the Library; Markdown has them as pictures, captions and all |
| A file, a PDF | `/file` or `/pdf` (or drop a file on the page): it's copied into `Pages/assets`, shown with what it is, its name and how big, and *Open* opens it in its app. A PDF shows its pages here too, one under another, with the page you're on, in a frame whose bottom edge drags; *Hide pages* folds them away. Colors, Pages' or your own |
| A video | `/video` (or drop one on the page): copied into `Pages/assets`, a still from it until it plays; play and pause, where it is (click or drag the bar), the time, the sound on or off; *Open* in your video player |
| A web bookmark | `/bookmark`, then paste a link: a card with its page's title, a line about it, the site and its picture. The page is read once, when it's added (with `curl`; nothing's fetched when the page is shown), and its picture kept in `Pages/assets`. A click opens the link; its tools change the link (✎: the link in its field, Enter reads the new page, Esc keeps it as it was), read it again, or copy it |
| A button | `/button`: its words, and what a click does: puts in a template (yours, or one of Omanote's) right after it, or makes a new page from it inside this page. Its gear sets it up again; its colors, Pages' or your own |
| A synced block | Pick blocks, then *Turn into a synced block* in their ⋮⋮ menu (or `/synced`: a new one, or one there is): the blocks go on a page of their own and are shown where they were, outlined; copy the synced block (⋮⋮, Ctrl+C) and paste it on other pages. *Edit* opens its blocks (the page says it's a synced block's, and on how many pages): changed there, changed everywhere it is. *Unsync* makes them a page's own plain blocks again. Markdown has its blocks where it is |
| An audio note | The red dot at the top right of a page (**Ctrl+Shift+R**), or `/audio`: a note where you are, recording at once (the time, your voice's level as you speak). **Enter** or the square stops it, **Esc** or ✕ throws it away. Then it's a player: play and pause, the waveform (the part played in its color; click or drag to go there), the time, the speed (1×, 1.25×, 1.5×, 2×). What you said is written out under it by voxtype as soon as it's recorded (Settings → *Write out audio notes*; else *Write it out*), to read, search, copy and correct; the button at its right hides and shows it. Its colors (the player's and the card's) are Pages' colors or your own (**Custom…**). Each change is a step **Ctrl+Z** takes back. The recording is an Opus file in `Pages/assets`; a page as Markdown links to it, with what was said quoted under it. Recording on another page, a bar at the foot says so, to stop it there. Your voice is evened out once it's recorded, so a quiet laptop microphone comes out loud and clear (Settings → Audio); a quiet note from before offers *Louder*, which makes a louder copy (Undo goes back to the first) |
| A meeting | `/meeting`, or the people at the top right of a page: voxtype's meeting mode records your microphone and what the computer plays (the other side of a call), with the time, **Pause** and **Stop** on the meeting (and a bar at the foot on other pages). When it ends voxtype writes it out, and it's in the meeting: who said what, turn by turn, each speaker in a color; click a name to name them ("Remote" is Sam). **Summarize** asks your agent for the summary, the decisions and the to-dos, under it. *Bring one in* puts a meeting voxtype recorded (from its own shortcut) on the page. Meeting mode is off in voxtype until you turn it on, from the meeting or Settings → Audio (that sets `meeting.enabled` in voxtype's settings and restarts it). Pages search finds what was said; Markdown has it, a turn a line |
| The microphone | Settings → Audio: which microphone audio notes and dictation record from, *Make my voice louder*, and *Test the microphone* (a few seconds of your voice's level, then whether it's quiet, good or too loud) |
| Dictate | **Ctrl+Shift+D**, the microphone at the top right, or `/dictate`: a bar at the foot listens (your voice's level as you speak). **Ctrl+Shift+D** again or *Done*, and what you said is written where your cursor is (on a new line at the end when it isn't in one); ✕ throws it away. voxtype writes it out, as its settings say (on your computer, the way Omarchy sets it up) |
| A sketch | `/sketch`: a sheet to draw on, with your mouse, pen or tablet. Click it to draw; its tools come up under it: the pen, the highlighter (**P**, **M**), the eraser (**E**, which lifts whole strokes), the color (the page's ink, Pages' colors, which follow your light or dark theme, colors you picked recently, or **Custom…**, the color picker), three nibs, plain paper, dots or a grid, Undo, Redo, and clearing it. Every stroke is a step **Ctrl+Z** takes back. **Esc**, *Done* or a click elsewhere on the page stops drawing. Its bottom edge drags to make it taller or shorter. A drawing keeps its shape at any page width |
| Go back to an earlier version | *Page history* in the page's ⋯ menu: the versions Omanote kept (every ten minutes while you write, and before an agent or a command changes the page), each shown as it was. *Restore this version* puts it back as one step **Ctrl+Z** takes back, and keeps the page as it was in the history too. Pages made inside the page since stay in it |
| A habit to keep | `/habit`: its name, and a circle for each day of the week to click when it's done (today's is rimmed in your accent) |
| A month at a glance | `/calendar`: click a date to circle it; the arrows over it go to other months |
| Turn a block into a page | **⋮⋮** → *Turn into page*: its text is the page's name, and what's inside it goes along |
| Reorganize pages | Drag a page in the sidebar: a line shows where it goes (before or after another page, as deep as it), or the page it goes inside lights up; below every page is the end of the top. A page can't go inside a page that's inside it. Its block moves to its place on the page it goes on, the page open is shown as it is then, and **Undo** on the message puts it back. Dropped on **Projects**, a page is a project; a project dropped in **Pages** is a page again |
| A project | **+** on the sidebar's **Projects** makes one; so does dragging a page there, or *Make it a project* in a page's ⋯ menu or its menu in the sidebar (the *Project plan* template is one already): a line under its title with its status (Planning, Active, Paused, Done; click it to change it), when it's due (click: a date, typed as `fri`, `oct 20`, `in 2 weeks`, or Today, Tomorrow, Next week...; late, it says so in red) and how far along it is (the to-dos on it and on the pages inside it). The sidebar's **Projects** has every project, with the pages in it under it (they're not in **Pages**): what's on now first, late first, then by when they're due, done ones last, each with a ring for its progress in its status's color. Done, it offers to go in the archive |
| People | **People** in the Pages sidebar: your contacts, on your computer (`Pages/contacts.json`, no account), A to Z, as a list beside the one you pick or as cards (the switch at the top; it's kept), found by a name, a company, an email or a number. The one you pick is a card: their name and what they do, then each number and email with what it is (a click copies one; ✉ opens your mail app), birthday (and how long until it), address, website, notes, and the pages they're named on. **Edit** opens a form, each field named above it (what's wrong is said under it; **Save** or Ctrl+S keeps it, **Cancel** or Esc leaves it); **New person** opens it empty. **Import** a `.vcf` (from a phone, Google Contacts, iCloud or Outlook: one card or thousands) or a `.csv` (Google's or Outlook's), or drop a `.vcf` on the window: those already there (the same email or number) are filled in, not added twice. ⋯ exports everyone as a `.vcf`. ⋯ on someone's page deletes them, taken back with *Undo*. `/contact` puts someone's card on a page |
| The Library | **Library** in the Pages sidebar: everything you've put on your pages, in one place, newest first: links (bookmark cards, and links written in text or tables), files and PDFs, videos, pictures, audio notes, meetings, sketches, the people you've named and emails, each with what it is (a PDF, its size, the site) and the page it's on. Pick a kind (*Links*, *Files*, *Videos*...) or type to find one by its name, its link or its page. Click one to go to it on its page; under the pointer, **Open** opens the link in your browser or the file in its app, and **Copy** copies a link. The trash's and templates' pages aren't in it; **Back** comes back to it. Each page keeps a list of what's on it in Pages' index as it's saved, so the Library opens at once |
| The calendar | **Calendar** in the Pages sidebar (**Ctrl+Shift+C**): yours, on your computer, no account. By **month**, by **week** (hour by hour, events side by side when they overlap, a line at now), as an **agenda**, or **compact**: a small month with a dot for each event, and beside it (under it, in a narrow window) the days from the one you pick, + on a day adding an event there; **Today**, ←/→, M, W, A, C. It opens in the view you used last; in a narrow window the views fold into one menu. Click a day or a time and type: "Lunch with Sam fri 12:30", "Standup 9:30-9:45", "Dentist oct 12 3pm for 30 min", "Holiday dec 24" (a time alone, "Call Sam 17:00", is on the day you clicked). Click an event to change it: its title, all day or a start and an end ("fri", "9:30"), a repeat (daily, weekdays, weekly, monthly, yearly; every few, until a day), an alert (an Omarchy notification before it; a click opens its notes or the calendar), a color (Pages' or your own), a place, a few words. Drag an event to another day or time, its bottom edge to make it longer; a repeating one asks: just this one, or every one (and taking one off: this one, the ones after, or all). **Ctrl+Z** takes a change back. Reminders on your pages and projects' due dates are on it too, a click away from their pages. **Today** in the sidebar has what's left of today. *Notes for it* makes a page for an event (from your template with "meeting" in its name, else Meeting notes), and the page says which event it's for. `/agenda` puts a day's events on a page (today's, or a day you go to), `/event` puts an event on the calendar and on the page. ⋯ exports it as an `.ics` file for another calendar app, or imports one (*Import .ics…*: its events shown first, then *Add to calendar*); so does dropping an `.ics` on a page, or clicking one on a page. It's kept in `Pages/calendar.json` |
| Your own templates | *Save as template* in a page's ⋯ menu (a copy of it, and the pages in it), or *New template* in **Templates** at the sidebar's foot. **Templates** shows every template as a card in place of a page, yours and then Omanote's, each with its name and what it's for (a line you write at the top of your template; else how it starts), found by typing words from either (**Enter** makes a page from the first, **Esc** shows them all again): a click makes a new page from it, and *Edit* (under the pointer) opens one of yours. A template is a page kept apart: open it there and change it like any page (out of the tree, search, tags, backlinks, reminders and the Projects; it says it's a template, with *New page from it*). Use one: on a blank page (yours come first among the templates), `/template` (its blocks where you are, the pages in it made inside this one), *New page from it* (Templates, or *A page inside it, from a template…* in a page's menu in the sidebar), or *Pages inside start from…* in a page's ⋯ menu (every new page inside it starts from that template). In it, `{{date}}` (a date, "@Fri 2 Oct"), `{{weekday}}`, `{{time}}`, `{{month}}`, `{{year}}` and `{{week}}` are filled in when it's used, in its title too; a meeting in it is a new one each time. *Not a template* puts it back in the tree; **Undo** on the message puts it back |
| Put a page away | *Archive* in its ⋯ menu: it leaves the tree (with the pages in it) and the Projects, and is in **Archive** at the sidebar's foot, still there to open, search and link to. Open, it says it's in the archive, with *Bring it back*; so does the archive's arrow. **Undo** on the message takes it back too |
| Keep a page at hand | The ☆ at the top right, or *Add to Favorites* in its menu: it's under *Favorites* at the top of the sidebar |
| Copy a page | *Duplicate* in its ⋯ menu (or in the sidebar's): a copy of it and the pages in it, right after it |
| Stop a page changing | *Lock the page* in its ⋯ menu: it reads, and copies, but can't be changed until you unlock it (the lock at the top) |
| Bring notes in | *Import…* at the foot of the sidebar: files, or a whole folder (a Notion or Obsidian export, zipped or not). Or drop files on a page |
| Paste Markdown | It comes in as blocks. Into a page's title: the first line is the title, the rest the page |
| Find a page | **Ctrl+P**: recent pages, or every page with the words you type |
| Back, forward | **Alt+←**, **Alt+→** |
| Hide or show the sidebar | **Ctrl+\\** |

**Blocks**: text, columns side by side, three sizes of heading (and toggle
headings, which fold what's under them), bulleted, numbered (1, a, i as they nest) and to-do
lists, toggles, quotes, callouts with an emoji (click it for another), code
with its language (in its colors: 30 languages, from Bash to Zig) and a Copy button, dividers, pictures (pasted, dropped or
picked), pages, links to pages, a table of contents of the page's
headings, habits with a circle for each day of the week, a month's
calendar, mind maps (the topic in the middle, ideas branching out in a
color for each branch, laid out by themselves), tables (rows and
columns, a header row, columns as wide as you drag them, cells in a text
color and a background of their own, and the cells' words formatted like
any other), sketches (pen and highlighter drawings on plain paper,
dots or a grid), audio notes (a recording, a player, and what was said,
written out by voxtype), and meetings (recorded by voxtype's meeting mode:
who said what). Nine text colors and nine backgrounds (Notion's), for a whole block
or a few words; a callout or a colored block keeps the blocks inside it in
its color.

**Links and reminders.** A page shows the pages that link to it (with `[[`
or a *Link to page* block) under its title, and a link to a page always says
the page's name now, however often it's renamed. Reminders come whenever
they're due while the Omarchy shell runs (Omanote keeps them, so taking the
date off the page takes the reminder away too); one that came due while the
computer was off comes when it starts, if that was in the last 12 hours.

**Bringing notes in.** Import reads Markdown (Notion's, Obsidian's,
GitHub's: headings, bold, italics, strikethrough, `==highlights==`, code,
links, nested lists, to-dos ticked or not, quotes, `> [!NOTE]` callouts,
`<details>` toggles, code blocks with their language, tables, front matter),
HTML (Notion's export too, which keeps its colors, toggles, callouts and
columns), plain text, Evernote's `.enex`, and Word, OpenDocument, RTF and
more through LibreOffice (which Omarchy has) or pandoc. A folder's tree
becomes pages inside pages, with a Notion page's own folder inside it; pages
keep Notion's ids as their UUIDs; links between the files (and
`[[wikilinks]]`) become links between the pages; pictures are copied in.
Tables come in as tables, their cells' bold, links and line breaks kept;
pictures on the web stay links (Omanote never goes online).

**A page** has an icon (an emoji), a cover (a gradient or a picture of your
own), a title, and a look of its own in its ⋯ menu: the Default, Serif or
Mono font, small text, and full width. The same menu copies it as Markdown,
exports it and the pages in it (as Markdown files, to a folder you pick or to
`Exports/`, as Settings → Exports says, with its sketches as SVG files beside them), moves it into another page, or puts it
in the trash. The sidebar shows every page as a tree; the trash at its foot puts a
page back where it was, or deletes it from Pages.

Pages follows your Omarchy theme, light or dark.

## Paper, pens and covers

A notebook has a paper and a pen; any page can have its own paper, and any
words their own pen and size.

| Paper | |
|---|---|
| Patterns | Blank, Ruled, Grid, Dots, Graph, Legal pad |
| Colors | White, Ivory, Aged, Legal yellow, Kraft, Recycled, Night, Blueprint, your Omarchy theme |
| Lines | Narrow, College, Wide |

The inks and highlighters you pick are kept as their light-paper colors and
shown as a matching lighter ink on dark paper, so switching a page to night
paper never leaves dark ink on a dark page.

| Pen | Font |
|---|---|
| Clean | Adwaita Sans (else Inter, Noto Sans) |
| Book | Lora |
| Handwriting | Caveat |
| Print | Patrick Hand |
| Typewriter | Special Elite |
| Mono | iA Writer Mono |
| Writer | iA Writer Duo |

Covers come in leather, linen, kraft, smooth card and composition, in twelve
colors, with or without an elastic band, spiral-bound, sewn or hardcover.
Titles go on the way the material takes them: stamped in foil, written on a
label with a marker, typed onto kraft, written in a composition book's name
box.

## Where your notebooks are

In `~/Documents/Omanote` (or `~/Omanote` without a Documents folder), unless
you pick another folder in the settings:

```
Omanote/
  library.json                  the order of the shelf
  my-notebook-k3f9/
    notebook.json               its title, cover, paper, pen, kind of page and pages in order
    pages/20260930-143201-a8f2.json
    assets/20260930-150412-p7wq.png
  Pages/
    index.json                  the tree of pages: titles, icons, which page is in which
    calendar.json               the calendar's events
    6f1c2b9e-….json             a page of Pages, named by its UUID
    history/6f1c2b9e-…/         its earlier versions, a file each, named for when they were kept (the newest 100)
    assets/                     pictures and covers on Pages' pages
  .trash/                       notebooks and pages you threw away
  Exports/                      notebooks and pages exported as Markdown (with Settings → Exports on "Exports folder")
  Markdown/                     the Markdown copy of every page (Settings → Markdown copy), unless you pick another folder
```

A page of Pages is its blocks as Notion keeps them: the ids of the blocks on
the page in order (`content`), and every block by its id (`blocks`), each with
its `type`, its `parent`, what it says, and the ids of the blocks inside it:

```json
{
 "id": "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b", "type": "page", "parent": "",
 "title": "Plans", "icon": "🗺️", "content": ["a3e1…", "c07d…"],
 "blocks": {
  "a3e1…": { "id": "a3e1…", "type": "toggle", "parent": "6f1c…", "html": "Trip", "content": ["9b4f…"] },
  "9b4f…": { "id": "9b4f…", "type": "check", "parent": "a3e1…", "html": "Tickets", "checked": true },
  "c07d…": { "id": "c07d…", "type": "page", "parent": "6f1c…" }
 }
}
```

A page's file holds its title, its blocks (each block's text as Qt writes rich
text: `Hello <span style="font-weight:700;">bold</span>`), its drawings, its
paper and tab, the template it came from and the day it's for, and its plain
text for searching. Files are written whole, to a
temporary file that then replaces them, so a crash never leaves half a page.
Nothing is ever deleted: throwing a page or notebook away moves it to
`.trash`.

*Export notebook…* (⋯, or right-click on the shelf) writes each page as a
Markdown file, with its pictures, into a folder of its own, and opens it. Where
that folder goes is a setting (Settings → Exports): a folder you pick each time
(the default), or `Exports/` in your notebooks folder.
*Copy page as Markdown* puts the page on the clipboard. Highlights come out as
`==marked==`, sticky notes as `> [!NOTE]` callouts, checklists as `- [ ]`,
time slots as a list with the times in bold, habits as a table of the week and
a calendar as a table of the month.

### Backups

Settings → **Backups** keeps your notes safe, or takes them to another
computer. **Back up** puts the open profile (its notebooks, Pages, calendar,
People, templates, history and trash: everything in its folder) in one
`.tar.gz`; **Back up all** puts every profile in one (the demo can start
over, so it's left out). They go in `~/Documents/Omanote Backups` (or a
folder you choose), named for the profile and the time:
`Omanote Personal 2026-10-03 0130.tar.gz`. Any archive tool opens one: it
holds `omanote-backup.json` (which profiles, when, which Omanote made it) and
each profile's folder under `p1/`, `p2/`.... A backup is written beside where
it goes and only named when it's whole, and a backup folder inside a
profile's folder is left out of it.

**Automatic backups**, daily or weekly (off to start with), back up every
profile while Omanote runs, and keep the newest 3, 5, 10, 20 or 50: older
automatic ones go to the trash. The backups you make are never cleared out.

**Restore** puts a backup back, from the list or from a file anywhere: it
says what's in it first, then each profile in it comes back as a new
profile, in a new folder (`~/Documents/Omanote Personal (restored)`), with
the page, notebook and Inbox it had. Nothing you have is changed or written
over; a name that's taken gets *(restored)*. A file that isn't one of
Omanote's backups, or that holds links or anything reaching outside its
folders, isn't put back. The first time Omanote opens, *Restore a backup…*
does the same, so a new computer starts with your profiles.

### Updates

Omanote asks GitHub for the project's newest release a minute after it
starts and once a day after that (Settings → About → *Check for updates
automatically*; off, it asks only when you click *Check now*). It's one plain
request for the list of releases: nothing of yours goes with it. When there's
a newer version, the foot of Pages' sidebar and the shelf's corner say so
(*Version 1.1.0 is available*), with a dot by About in Settings; a click
shows its release notes, here in Omanote (no pictures or HTML from them,
nothing fetched). An Omanote installed with `omarchy plugin add` updates
itself with *Update now* (`omarchy plugin update marcho78.omanote`, which
checks it before the shell loads it); one installed another way shows that
command, to copy. *Release notes* in About shows what's in the version you
have, from `CHANGELOG.md`.

At the foot of the sidebar (and the shelf's corner) is *Follow me on X
@devsec_ai*: a click opens the profile in your browser.

## Settings

They apply as you change them and are saved on Omanote's entry in
`~/.config/omarchy/shell.json`, keeping only what differs from the defaults
in `Defaults.js`. Settings (the ⚙ in the sidebar or on the shelf, or
**Ctrl+,**) has a section for each part of Omanote: General (shortcuts, the
window, scrolling), Appearance (colors, motion and sound), Writing
(checklists, exports, the Markdown copy), Audio (the microphone, dictation,
meetings), Profiles, Backups and About (the version, updates, release notes,
contact).

| Setting | Default | Values |
|---|---|---|
| `colorSidebar`, `colorPage`, `colorCards`, `colorText` | `""` | Settings → **Appearance**: your own colors (`#rrggbb`) for the sidebar, the page (behind your pages, the calendar, People and the Library, and the notebooks' desk), the sections and cards (the sidebar's sections become cards in it; cards and menus take it), and all the text (the dimmer text follows it). `""` follows the Omarchy theme, as it changes. Each is picked with the color picker, shown as you pick, and has *Reset*; Settings warns when the text won't read well on a color |
| `peopleLayout` | `list` | how People shows everyone: `list` (beside the one picked) or `cards` |
| `calendarView` | `month` | the view the calendar opens in: `month`, `week`, `agenda` or `compact` |
| `shortcut` | `SUPER + N` | any modifiers and a key, or empty |
| `quickShortcut` | `SUPER + ALT + N` | any modifiers and a key, or empty |
| `mirror` | `false` | keep a Markdown copy of every page (see [A Markdown copy](#a-markdown-copy)) |
| `mirrorFolder` | `""` | where the copy goes: a full path or `~/…`; empty is `Markdown/` in your notes folder |
| `tagSort` | `name` | how the sidebar lists tags: `name` (a tag inside another under it) or `color` |
| `audioTranscribe` | `true` | write out an audio note (with voxtype) as soon as it's recorded; `false`: only with *Write it out* |
| `audioInput` | `""` | the microphone audio notes and dictation record from: a PipeWire source's name (`pactl list sources short`); empty is the default one |
| `audioBoost` | `true` | even out your voice once it's recorded (and before it's written out), so a quiet microphone comes out loud and clear without turning up the hiss |
| `quickTo` | `notebook` | where a quick note goes: `notebook` (the Quick notes notebook) or `pages` (a page in the Pages Inbox, its text read as Markdown). The note's foot says which, and a click there changes it |
| `barIcon` | `true` | show the notebook in the top bar |
| `folder` | `""` | where the notebooks live (`""` is `~/Documents/Omanote`); `/path` or `~/path` |
| `floating` | `true` | float in the middle of the screen (`false`: tile) |
| `width`, `height` | `1320`, `900` | the floating window's size |
| `strikeDone` | `true` | cross off checked items |
| `sounds` | `true` | a soft paper sound when a page turns and a notebook opens |
| `scrollSpeed` | `"normal"` | how fast a page scrolls with a trackpad or a wheel: `slower`, `normal`, `faster` (a trackpad's quick strokes go further, as on a MacBook) |
| `reduceMotion` | `false` | fade instead of turning pages and swinging covers |
| `zoom` | `100` | 60 to 200 |
| `space` | `notebooks` | which Omanote opens in: `notebooks` or `pages` (the one you were in) |
| `recentColors` | `""` | the colors of your own you picked last in a mind map, newest first (up to 8) |
| `exportTo` | `ask` | where exports go: `ask` (a folder picker each time) or `folder` (`Exports/` in your notebooks folder) |
| `inbox` | `""` | the page agents' and scripts' new pages go into: made (as *Inbox*) the first time; `omarchy-shell omanote set inbox <page id>` makes it another page |
| `backupFolder` | `""` | where backups go (`""` is `~/Documents/Omanote Backups`); `/path` or `~/path` |
| `backupEvery` | `off` | automatic backups of every profile: `off`, `daily` or `weekly` |
| `backupKeep` | `10` | how many automatic backups are kept: `3`, `5`, `10`, `20` or `50` (older ones go to the trash; yours are never cleared out) |
| `checkUpdates` | `true` | ask GitHub once a day whether there's a newer Omanote |
| `pen`, `paper`, `paperColor`, `spacing`, `cover`, `material`, `binding` | `sans`, `ruled`, `ivory`, `regular`, `navy`, `leather`, `spiral` | what a new notebook starts with (the choices of the last one you made) |

A shortcut another binding already uses is left alone, and the settings say
which. A shortcut needs a modifier, unless it's a function or media key.

### From a terminal

```bash
omarchy-shell omanote toggle              # or show, hide
omarchy-shell omanote quick               # the quick-note card
omarchy-shell omanote quick "Buy milk"    # straight into Quick notes (or the Pages Inbox)
omarchy-shell omanote search "tram 28"
omarchy-shell omanote shelf
omarchy-shell omanote pages               # straight to Pages
omarchy-shell omanote calendar ""         # the calendar (or on a day: 2026-10-12)
omarchy-shell omanote open <page id>      # a page in Pages (what a reminder's notification does)
omarchy-shell omanote importNotes ~/notes # files or a folder (a Notion or Obsidian export) into Pages
omarchy-shell omanote settings
omarchy-shell omanote set paper grid      # any setting above
omarchy-shell omanote reset               # every setting back to its default
omarchy-shell omanote mirror              # the Markdown copy, up to date now
omarchy-shell omanote status
```

A quick note's first line is its title; lines starting with `- ` become a
list and `[] ` a checklist. Sent to Pages (`quickTo`), the rest is Markdown
too (**bold**, links, `[[Page title]]`, code, `- [ ]` to-dos), every line
stays a line of its own, and a first line that's a list item or a to-do
names the page and stays in it. A note made while Pages is still loading
waits for it; if Pages can't load, the note goes to Quick notes, so it's
never lost.

### A Markdown copy

Settings → **Markdown copy** keeps a plain Markdown file of every page in a
folder, a few seconds after anything changes, so Obsidian, git, grep or any
editor can read your notes (`omarchy-shell omanote set mirror true` does the
same). It's `Markdown/` in your notes folder unless you pick another
(`mirrorFolder`, or *Copy to* in Settings), for example an Obsidian vault:

```
Markdown/
  Pages/
    Plans.md                    a page of Pages
    Plans/Trip.md               the pages inside it, in its folder
  Notebooks/
    Recipes/001 2026-09-30 Shakshuka.md   a notebook's pages, in order
    Recipes/assets/             its pictures
  assets/                       Pages' pictures
  sketches/<id>.svg             sketches, as SVG
  .omanote-mirror.json          what the copy wrote
```

Links between pages are links between the files, so they work in any
Markdown app. The copy goes one way: Omanote writes it and never reads it, so
change your notes in Omanote. It writes a file only when what's in it changed
(git sees real changes), and takes away only files it wrote itself (as
`.omanote-mirror.json` lists them): anything else in the folder is never
touched, and a file of yours with a name it wants keeps it (the page's takes
`Name (2).md`). It won't use your home folder, the notes folder itself or one
of Omanote's own folders in it. `omarchy-shell omanote mirror` brings it up to
date now and says how it is.

### For AI agents and scripts

An AI agent, a script, a keybinding or a cron job can read and write your
pages with the same `omarchy-shell omanote` calls, with no MCP server or anything
else running: the commands go to Omanote over the Omarchy shell's IPC, and the
app does the writing, so a page shows up in the window as it's added, and its
links and reminders work. Each command answers at once, in JSON (`read` gives
Markdown).

```bash
omarchy-shell omanote help                        # the commands, as JSON
omarchy-shell omanote list                        # every page: id, title, icon, path
omarchy-shell omanote find "lisbon tram"          # pages with those words, with a snippet
omarchy-shell omanote read <page id>              # a page as Markdown
omarchy-shell omanote add "Title" ~/note.md       # a new page in the Inbox, from a Markdown file
omarchy-shell omanote addTo <page id> "" note.md  # a new page inside a page ("": its # heading is the title)
omarchy-shell omanote append <page id> more.md    # added at the end of a page
omarchy-shell omanote blocks <page id>            # its blocks: id, type, depth, text (Markdown)
omarchy-shell omanote replace <page id> <block id> new.md      # in place of a block (and what's inside it)
omarchy-shell omanote insertAfter <page id> <block id> more.md # after a block, as deep as it is
omarchy-shell omanote trash <page id>             # to the trash, where it can be put back
omarchy-shell omanote tags                        # every tag: how many pages and blocks have it
omarchy-shell omanote tagged "#errand"            # every block with the tag: page, block id, text (Markdown), ticked
omarchy-shell omanote tagColor "#work" blue       # a tag's color (Pages' colors, a hex, or "" for none)
omarchy-shell omanote library files "spec"        # what's on the pages (the Library): links, files, videos, pictures... ("" "" for all)
omarchy-shell omanote contacts "acme"             # your people: name, company, numbers, emails ("" for everyone)
omarchy-shell omanote contact "Sam"               # one person, everything kept about them, and the pages they're named on
omarchy-shell omanote addContact "Kim Park" "+82 2 555 0100" ""   # someone new (or filled in, by email or number)
omarchy-shell omanote importContacts ~/contacts.vcf   # a .vcf or .csv into People
omarchy-shell omanote projects                    # every project: status, due date, progress, late or not
omarchy-shell omanote project <page id> active 2026-10-12   # a page made a project, or changed ("" keeps, "-" keeps the date, none: a page again)
omarchy-shell omanote archive <page id>           # put away in the archive (unarchive <page id> brings it back)
omarchy-shell omanote templates                   # your templates: id, title, icon, what it's for, how many pages
omarchy-shell omanote addTemplate "" retro.md "A sprint's look back"   # a template from Markdown ({{date}} and the like filled in when used)
omarchy-shell omanote describeTemplate "Retro" "Looking back on a sprint"   # what a template's for, on its card
omarchy-shell omanote events "" ""                # the calendar's events this week (from, to: 2026-10-05), and your notes' dates
omarchy-shell omanote addEvent "Dentist oct 12 3pm" ""   # an event on the calendar (repeat: daily, weekdays, weekly, monthly, yearly)
omarchy-shell omanote removeEvent <event id>      # off the calendar
omarchy-shell omanote fromTemplate "Standup" "" ""   # a new page from a template (name or id), its title ("" the template's), in the Inbox ("top", or a page id)
omarchy-shell omanote rename <page id> "New title"   # its title (move, icon, cover, lock, favorite: its place and looks)
omarchy-shell omanote move <page id> top 0        # inside another page ("top": the top of Pages), at a place ("" the end)
omarchy-shell omanote trashed                     # what's in the trash (restore <page id> puts one back)
omarchy-shell omanote duplicate <page id>         # a copy, right after it (makeTemplate <page id>: one of your templates)
omarchy-shell omanote history <page id>           # its kept versions (version <page id> <name> reads one, restoreVersion puts it back)
omarchy-shell omanote check <page id> <block id> true   # a to-do ticked (color <page id> <block id> blue: a block's color)
omarchy-shell omanote removeBlock <page id> <block id>  # a block off the page
omarchy-shell omanote board <page id> <block id> add "Ship it" "Doing"   # a board's cards and columns (move, edit, remove, addColumn, renameColumn, removeColumn, height, columnWidth, cardColor, columnColor)
omarchy-shell omanote attach <page id> ~/ticket.pdf   # a file on a page: a picture, a video, an .eml, a PDF, anything
omarchy-shell omanote picture <page id> <block id> 50 right   # a picture's width (a percent of the page's) and side ("" keeps either)
omarchy-shell omanote addGallery <page id> ~/Pictures/Lisbon 3   # a gallery of a folder's pictures (or paths, | between them), 2-4 to a row
omarchy-shell omanote gallery <page id> <block id> caption 2 "Tram 28"   # a gallery changed: add, remove, move, caption, columns, height
omarchy-shell omanote bookmark <page id> https://example.com   # a link as a card
omarchy-shell omanote setLink <page id> <block id> https://example.org   # a bookmark's link (or a link's page: its id or title)
omarchy-shell omanote preferences                 # every setting, its value and what it can be (set <key> <value> changes one)
omarchy-shell omanote backup ""                   # a backup of the open profile ("all": every one; or a profile's name)
omarchy-shell omanote backups                     # the backups in the backup folder, newest first, and how the last one went
omarchy-shell omanote restoreBackup ~/Documents/Omanote\ Backups/<file>.tar.gz false   # put back as new profiles (true opens the first)
omarchy-shell omanote appVersion                  # the version running, and whether there's a newer one (checkUpdate asks GitHub now)
omarchy-shell omanote releaseNotes                # what's new, as Markdown (installUpdate installs it, for an Omanote installed from git)
omarchy-shell omanote editEvent <event id> when "fri 3pm"   # an event changed: title, when, start, end, allDay, place, notes, repeat, alert, color
omarchy-shell omanote editContact "Sam" phone "mobile: +1 555 0100"   # someone changed (removeContact <id>: taken out)
omarchy-shell omanote renameTag "#idea" "#ideas"  # on every page (removeTag "#idea": off every page)
omarchy-shell omanote notebooks                   # the shelf's notebooks (notebook <id>, readNotebook <id> <page id>, addToNotebook <id> note.md)
```

Pages come in as Markdown files, since an argument can't carry a page. They
keep their headings, nested lists, to-dos and ticks, code with its language and
callouts. A `mindmap` code block (an outline: the topic, then each idea
indented two spaces under the one it branches from; or Mermaid's `mindmap`) is
a mind map, so "make me a mind map of…" puts one on a page. An idea's colors
go in braces after it: `Marketing {red}`, `Marketing {blue background}`,
`Marketing {red, yellow background}`, or any hex color, `Marketing {#ff8800}`. A Markdown table (`| a | b |` lines, the second `|---|---|`) is a
table, its first row the header. Front matter's `status:` (planning, active, paused, done) and `due:` (2026-10-12) make the page a project, and a project's page is read and exported with them. `[[Page title]]` links to the page called that, and `#tag` is a tag. A date is
`[@Fri 2 Oct](omanote://date/2026-10-02)`, and a reminder is
`[⏰ Fri 2 Oct 9:30](omanote://remind/2026-10-02T09:30)`: a notification at
that time. Boards, bookmarks, links to pages, galleries, people, a day's
agenda and events are fenced code, read and written the same way:
```` ```board ```` (`## Column` lines, `- card` lines under them),
```` ```bookmark ```` (a link), ```` ```link ```` (a page's title or id),
```` ```gallery ```` (`columns: 3`, then a `![caption](assets/...)` line a
picture, pictures already in Pages), ```` ```contact ```` (a name, email or
id in People), ```` ```agenda ```` (`2026-10-05` or `today`) and
```` ```event ```` (an event's id). `add` puts pages in an Inbox page at the top of Pages, made the first
time it's needed; move them anywhere. Nothing is deleted for good, a locked
page isn't changed, and the page as it was is kept in its *Page history*
before a command changes it. On the page you have open, what's added goes in as one step
you can undo, and your cursor stays where it is.

`replace` and `insertAfter` won't change columns themselves (only what's in
them), and `replace` won't take a block with a page inside it.

**Ask your agent, from Omanote.** In Pages, the AI button at the top of the page, **Ctrl+J**, `/agent`, *Ask agent*
in a block's ⋮⋮ menu, *Ask* on the toolbar over selected words, or *Ask agent
about this page* in the page's ⋯ menu opens a box for what you'd like (or a
suggestion: to-dos, a summary, carrying on writing, linking related pages).
It goes to Omarchy's default coding agent, whichever you chose with
`omarchy default agent` (Claude Code, Codex, OpenCode, Gemini, Crush, Cursor,
Pi...), which opens in its own terminal and does it with the commands above,
so what it changes shows up on the page as it goes, each change a step you can
undo. The box says which agent it is; click it to choose another of the agents
installed here (Omarchy's list of them). That makes it Omarchy's default agent
too, and opens nothing. The agent gets the page's id, the
ids of the blocks you picked (or the empty line you're on, where its writing
goes), the words you selected, and where the omanote skill is; it reads the
rest itself. Omarchy starts it the way it starts every agent from a menu, with
its approval prompts off, so it can also do whatever else your agent can on
your computer; Omanote's commands keep your notes safe from it (nothing
deleted for good, no locked page changed, every change undoable).

**The skill.** While Omanote runs, it links its skill (`skills/omanote`) into
the folders agents read skills from, the ones Omarchy links its own into:
`~/.agents/skills`, `~/.claude/skills`, `~/.codex/skills`, `~/.hermes/skills`
and `~/.pi/agent/skills`, where those folders exist and nothing called
`omanote` is there already. It takes its links out again when it stops.
Agents that don't read skills get the file's path in the prompt.

**Claude Code** asks before each command unless you allow them in
`~/.claude/settings.json` (leave `trash` out, so that one still asks):

```json
"permissions": {
  "allow": [
    "Bash(omarchy-shell omanote find:*)", "Bash(omarchy-shell omanote list:*)",
    "Bash(omarchy-shell omanote read:*)", "Bash(omarchy-shell omanote add:*)",
    "Bash(omarchy-shell omanote addTo:*)", "Bash(omarchy-shell omanote append:*)",
    "Bash(omarchy-shell omanote blocks:*)", "Bash(omarchy-shell omanote replace:*)",
    "Bash(omarchy-shell omanote insertAfter:*)"
  ]
}
```

## How it works

Omanote is QML and JavaScript, two small shaders and a small Hyprland Lua
file; nothing is built on your machine. It runs inside the Omarchy shell: a
service with the settings, the Hyprland registration and the notebooks on
disk (`Service.qml`, `Store.qml`), a panel with the notebook window and the
quick-note card (`Notebook.qml`, `app/`), and the icon in the bar.

* **The page** is a column of blocks, each its own Qt rich-text editor
  (`app/Block.qml`); `app/Editor.qml` decides what keys do across them (Enter
  splits a block, Backspace at its start joins it to the one above, the
  arrows move between them), formats text, pastes, picks whole blocks and
  keeps the undo history. Formatting works on the selection's HTML, read into
  runs of text and written back (`Html.js`), so bolding a heading-sized word
  together with body text keeps both sizes.
* **Text on the lines.** Every line of every block has a fixed height, a whole
  number of rules, and Qt puts a fixed-height line's baseline at four fifths
  of it, whatever the font: that's where the paper's rules are drawn. A title
  takes two rules and moves down a fifth of one, so it sits on the second.
* **The paper** is a fragment shader (`shaders/paper.frag`): the color, a
  grain of noise, kraft's fibers, and the pattern, with each rule one device
  pixel wide. The covers are another (`shaders/cover.frag`): leather's
  pebbles, linen's weave, kraft's fibers, the composition book's marbling,
  stitching and the spine. The spiral, tabs, checkboxes and ticks are drawn
  with Qt Quick Shapes.
* **Turning a page** takes a picture of the page, puts the next page under it
  and turns the picture over the binding in 3D with light and shadow across
  it; turning back, the earlier page comes over a picture of this one. The
  cover opens the same way, around the spine.
* **Pages** is the same editor in another layout: blocks with natural
  spacing instead of ruled lines (`app/DocBlock.qml`), each block's depth
  telling which block it's inside. `Workspace.js` turns a page's tree of
  blocks into that list and back, keeps depths that make sense, and checks
  page files and the tree of pages; `Workspace.qml` reads and writes them,
  through the same atomic writes as the notebooks; `Docs.js` has Pages' type,
  colors and "/" commands. `Dates.js` reads the dates typed after "@",
  `Emoji.js` has the emoji names for ":", and `Import.js` reads the notes you
  bring in. Code is stored as plain text and colored as it's shown, by
  `Highlight.js`: a small reader for each language that finds its comments,
  strings, numbers, keywords, types, functions and tags, and never changes a
  character (it colors again a moment after you stop typing). `Api.qml`
  answers the commands agents and scripts send over IPC, through the same
  store as the window, and `Agent.js` writes what *Ask agent* hands your agent.
  A mind map keeps its ideas as an outline; `Mindmap.js` reads it (and
  Mermaid's), changes it and lays it out, and `app/MindMap.qml` draws it and
  lets you write on it. A table keeps its rows of cells (each a little rich
  text), whether its first row is a header, and its columns' widths;
  `Table.js` cleans and changes it (its cells' colors too, which go with
  their rows and columns; and it reads spreadsheet cells and writes
  Markdown, which has no colors), and `app/TableBlock.qml` draws it and lets you write in it.
  `Workspace.qml` keeps each page's earlier versions in `Pages/history/`, and
  `app/HistoryPanel.qml` shows them and puts one back. A sketch keeps its
  strokes in its own units (1000 wide), so it scales with the page;
  `Sketch.js` cleans it, finds what the eraser touches and writes it as SVG,
  and `app/SketchBlock.qml` draws it and lets you draw on it. An audio note
  keeps its recording's file in `Pages/assets`, its length, its waveform and
  what was said; `Audio.js` cleans it, reads ffmpeg's levels and voxtype's
  output, `Recorder.qml` runs the microphone (one recording at a time) and
  voxtype, `app/AudioBlock.qml` records and plays it, and
  `app/RecordingBar.qml` is the bar at the foot while dictating. The calendar
  keeps its events in `Pages/calendar.json` (in the computer's own time);
  `Calendar.js` cleans them, works out repeats, lays out a day, reads what's
  typed ("Lunch fri 12:30"), finds the alerts and writes `.ics`;
  `app/CalendarView.qml` is the month, the week and the agenda,
  `app/EventPop.qml` changes an event, `app/QuickAddPop.qml` adds one, and
  `app/CalendarBlock.qml` is an agenda or an event on a page. The newer
  blocks keep what they are in `data`: `Board.js`, `Files.js` and
  `Bookmark.js` clean and change theirs, and `app/BoardBlock.qml`,
  `app/FileBlock.qml` (with Qt's PDF view), `app/VideoBlock.qml`,
  `app/BookmarkBlock.qml`, `app/ButtonBlock.qml` and `app/SyncedBlock.qml`
  (an editor of its own, showing the page its blocks are on) draw them, on
  `app/DataCard.qml`'s data and colors. The Library is `Collection.js`
  (what each kind of block puts in it, kept in each page's index entry as
  the page is saved, then gathered, sorted and filtered) and
  `app/LibraryView.qml`; a new kind of block with something worth finding
  again is a line in `Collection.ofBlock`. People are `Contacts.js` (they're
  kept in `Pages/contacts.json`; it reads vCard 2.1 to 4.0 and Google's and
  Outlook's CSV, matches an import to who's there, writes vCard, and finds
  people), `app/PeopleView.qml` (the list and the card), `app/ContactPop.qml`
  (a person named on a page, clicked), `app/ContactBlock.qml` (/contact) and
  `app/Avatar.qml`; a person on a page is a link to `omanote://contact/<id>`,
  and `Html.linkEmails` makes emails links. An email block is `Email.js`
  (it reads an .eml: headers in any charset, plain and HTML bodies in
  base64 or quoted-printable, attachments; makes its HTML safe; and says
  what the block keeps) and `app/EmailBlock.qml`; its attachments are
  written out with `base64 -d`. A meeting
  keeps voxtype's id for it, what voxtype wrote out and the names you gave
  its speakers; `Meeting.js` cleans it and reads voxtype's export, list and
  state file, `Meetings.qml` follows voxtype's meeting
  (`$XDG_RUNTIME_DIR/voxtype/meeting_state`) and runs its commands, and
  `app/MeetingBlock.qml` shows it.
* **Blocks** (`Blocks.js`) know how Enter, Backspace and numbering work for
  each kind; **templates**, and the dates planners go on by, are in
  `Templates.js`; **papers, pens and inks** are in `Papers.js`, **covers** in
  `Covers.js`, and **what the files may hold** in `Library.js`, which checks
  everything read from disk before anything uses it.
* `hypr/omanote.lua` registers the shortcuts as messages to the service over
  Hyprland's event socket (`hl.dsp.event`), and window rules that float the
  notebook in the middle of the screen at your size, keep it fully opaque
  (paper isn't see-through), float the picture picker, and take the border
  and shadow off the quick-note card. The service runs it with `hyprctl eval`
  when the shell starts, after every Hyprland config reload, and when you
  change the shortcuts or window settings; disabling Omanote removes it all.
* **Sounds** are made from noise and sine waves by `sounds/make`, so there are
  no recordings in it.

## Security

Omanote runs as unsandboxed code in the Omarchy shell, like every shell
plugin, so here is exactly what it does.

**No root, nothing compiled on your machine, and the network only for two
things.** Links you Ctrl+click open in your browser. Omanote itself connects
only to read a web bookmark's page and picture, once, when you add one; and
to ask GitHub's API for the project's list of releases (a minute after it
starts and once a day, while Settings → About has it on; a plain request,
with nothing of yours in it).

**Programs.** Every command runs by absolute path with an argument list:

| Program | Why |
|---|---|
| `/usr/bin/bash` | three fixed scripts: one prints the files it's handed (or that a fixed pattern matches in a notebook's folder), each after its name, so a notebook is read in one go; one lists the page files in the Pages folder; the other points `wl-paste`'s output at a new picture file. Your text is never part of a script |
| `/usr/bin/cat` | read files, from that script |
| `/usr/bin/grep` | find the pages that contain what you searched for (`-F`: plain text, never a pattern) |
| `/usr/bin/mkdir`, `/usr/bin/cp`, `/usr/bin/mv`, `/usr/bin/test` | make notebook folders, copy pictures in and out, move things to the trash, see if there's a Documents folder |
| `/usr/bin/wl-copy`, `/usr/bin/wl-paste` | copy a page as Markdown; paste a picture |
| `/usr/bin/uwsm-app` with `xdg-open` | open a link, a picture or a folder the way Omarchy's launcher does |
| `/usr/bin/hyprctl` | read Hyprland's bindings; register and remove the shortcuts and rules |
| `/usr/bin/omarchy-shell` | say "Saved to Quick notes" on the OSD |
| `/usr/bin/omarchy-notification-send` | a reminder from Pages, as an Omarchy notification; clicking it runs `omarchy-shell omanote open <page id>` |
| `/usr/bin/find`, `/usr/bin/unzip` | list the files in a folder you import; unpack a zipped export (into a folder of your own under `$XDG_RUNTIME_DIR`, removed afterwards with `/usr/bin/rm`) |
| `/usr/bin/soffice` or `/usr/bin/pandoc` | turn a Word, OpenDocument or RTF file you import into HTML or Markdown, in that same folder |
| `/usr/bin/ffmpeg` | record from your microphone (PipeWire's, through its Pulse server) while an audio note, dictation or a test of the microphone records, printing its level ten times a second; even out a voice once it's recorded; make a recording a 16 kHz WAV for voxtype |
| `/usr/bin/pactl` | list the microphones, for Settings |
| `/usr/bin/curl` | read a web bookmark's page (http and https only, at most 2 MB, 15 seconds) and its picture (at most 5 MB), once, when you add it |
| `/usr/bin/cp`, `/usr/bin/stat` | copy a file you put on a page into `Pages/assets`, and say how big it is |
| `/usr/bin/voxtype` | `transcribe`: write out what was said in a recording, the way voxtype's settings say (its model, on your computer as Omarchy sets it up); `meeting start`, `stop`, `pause`, `resume`, `list` and `export`: record a meeting and get what voxtype wrote out; `config get meeting.enabled`, and `config set meeting.enabled true` when you turn meeting mode on |
| `/usr/bin/systemctl` | `--user restart voxtype.service`, once, when you turn voxtype's meeting mode on |
| `/usr/bin/rm` | take Omanote's launcher entry out when it stops; take away dictation's recordings (in a folder of Omanote's own under `$XDG_RUNTIME_DIR`) once they're written out |
| `/usr/bin/curl` | ask `api.github.com` for the project's releases (https only, at most 2 MB, 15 seconds) |
| `/usr/bin/tar`, `/usr/bin/gzip`, `/usr/bin/mktemp`, `/usr/bin/stat`, `/usr/bin/find` | make a backup (a fixed script: its omanote-backup.json in a folder of its own from `mktemp`, then each profile's folder added under `p1/`..., compressed beside where it goes and named when it's whole); list the backups; look inside one before it's put back (only plain files and folders, nothing outside its own) and put a profile back into a new folder (`--no-same-owner`) |
| `/usr/bin/gio` | `trash`: automatic backups past how many are kept (only ever those) |
| `omarchy-plugin-update` | when you click *Update now* (an Omanote installed from git): `omarchy plugin update marcho78.omanote --yes` |
| `/usr/bin/setsid`, `/usr/bin/kill` | run each command in its own process group, with a deadline and an output budget, and end it if it overruns them |

What you type reaches `grep` as a separate argument after `-e`, so it can
never be read as an option. Paths are checked before they're used: notebook
and page ids are plain lowercase names, pictures must be in their notebook's
`assets` folder, and dropped or picked pictures must be absolute image paths.

**Commands.** The IPC commands for agents and scripts (`add`, `addTo`,
`append`, `replace`, `insertAfter`) read the Markdown file they're given, by its
full path, up to 2 MB, as text; they don't run it or follow anything in it.
They reach Omanote over the Omarchy shell's IPC, which only programs running
as you can use, and they can add, append, change blocks and put pages in the
trash, never delete a page for good or change a locked one.

**Your agent.** Omanote starts an agent only when you ask (Ask agent), and
only Omarchy's default one, by running `/usr/bin/omarchy-agent-prompt` with
the prompt as one argument; it reads which agent that is with
`/usr/bin/omarchy-default-agent`, and *Change* runs `/usr/bin/omarchy-menu
summon setup.default.agent`. The agent runs as Omarchy runs it, with its
approval prompts off, so it can do on your computer whatever that agent can;
the prompt holds the page's and blocks' ids and the words you selected, never
the rest of your notes.

**Files.** Omanote writes inside its notebooks folder, and, outside it: its
launcher entry, `~/.local/share/applications/marcho78-omanote.desktop`, and a
link named `omanote` to its skill in each of `~/.agents/skills`,
`~/.claude/skills`, `~/.codex/skills`, `~/.hermes/skills` and
`~/.pi/agent/skills` that exists (never over anything already called that),
all made when it starts and removed when it stops (only links to its own
skill are removed). A fixed `/usr/bin/bash` script does the links with
`/usr/bin/ln`, `/usr/bin/readlink` and `/usr/bin/rm`. Its settings are written by
the Omarchy shell to Omanote's entry in `shell.json`. Every file it
reads is checked by `Library.js` or `Workspace.js` (types, sizes, counts,
known values, UUIDs, a tree with no block or page inside itself), and the
text of every block is cut down to the formatting Omanote writes itself
(no pictures, stylesheets or scripts inside text, and only `http`, `https`,
`mailto` and `file` links), so a damaged, hand-edited or synced-in page can't
make it load anything. Pasted text keeps what it says (bold, italic, links)
and drops how the page it came from looked. Every title, label and name is
drawn as plain text.

## Development

```bash
dev/starter        # starter/ (the examples a new Pages starts with) into StarterContent.js
tests/run          # settings, HTML, blocks, papers, library, Markdown,
                   # templates, Pages and the Hyprland module (node, lua),
                   # and the editor, notebook and Pages
                   # driven with keys and the mouse, offscreen (qmltestrunner)
shaders/build      # recompile the shaders (needs qt6-shadertools)
sounds/make        # make the sounds again
```

The Omarchy shell caches plugin QML, and Omanote stays loaded, so after
changing QML run `omarchy restart shell` (a symlinked checkout isn't watched
at all).

## Known limitations

* Text can be selected within a block; dragging across blocks picks whole
  blocks, as in Notion, rather than part of one and part of the next.
* Pages grow as long as you write; they're not cut into printed-page lengths.
* Drawings stay where you drew them: if the text under them moves (a line
  added above, the window narrower), they don't follow it.
* Find on a page looks through the writing, not the title, a table's cells
  or a mind map's ideas; search (Ctrl+P, and on the shelf) looks through all
  of them.
* Notebooks have no tables (Pages has them), no spell checking (Qt Quick's
  text editor has none), and no printing or PDF export: export as Markdown,
  or copy a page.
* Pages has no databases (on purpose: a table is rows and columns of text,
  a board columns of cards, and a project a page with a status, a due date
  and its to-dos), no live embeds of other websites (a link is a bookmark
  card), no equations,
  no merged cells, no @-mentions of
  people (Omanote has one writer), and no syncing between computers; pages move into other pages with *Move to…*, not by
  dragging them in the sidebar. Columns are at the top of a page (not inside
  a toggle or a list), as Notion has them.
* Weeks start on Monday (ISO weeks) in planners, habits and calendars,
  whatever your locale says.
* Circling dates is all a calendar's days take; write about a day in a
  monthly planner's line for it.
* *Ask agent* hands your request to Omarchy, which opens your agent in its
  own terminal (Omarchy's agent window, `org.omarchy.agent`), outside
  Omanote. What it changes shows up on the page as it goes, but what it says,
  its questions and its summary of what it changed, is in that window, and
  you answer it there.

## Uninstall

```bash
omarchy plugin remove marcho78.omanote
```

The shortcuts and rules leave Hyprland with it, its launcher entry goes, and
its settings go with its `shell.json` entry. Your notebooks stay in `~/Documents/Omanote`.

## License

MIT. See [LICENSE](LICENSE). The fonts in `fonts/` keep their own licenses,
which come with them: Caveat, Patrick Hand and Lora under the SIL Open Font
License, Special Elite and Permanent Marker under the Apache License 2.0.
