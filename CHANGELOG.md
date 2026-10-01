# Changelog

Every notable change to Omanote is listed here, newest first. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version
numbers follow [Semantic Versioning](https://semver.org/).

## 1.0.0 - Unreleased

The first version.

### Added

- **The shelf.** Your notebooks, cover up on the desk: leather with gold foil
  and an elastic band, linen and smooth card with paper labels, kraft with a
  typed stamp, and marbled composition books with their name box; spiral,
  sewn or hardcover, in twelve colors (one of them your theme's accent).
  Right-click a notebook for its cover, exporting it or the trash.
- **Opening a notebook.** It slides from the shelf onto the desk and its cover
  swings open around the spine; closing it swings the cover shut and puts it
  back.
- **Paper.** Blank, ruled (with a margin line), grid, dots, graph and legal
  pad patterns; white, ivory, aged, legal yellow, kraft, recycled, night,
  blueprint and Omarchy-theme papers; narrow, college and wide lines. Text
  sits on the rules in every font and size. Per page or for the whole
  notebook.
- **Turning pages** over the binding, with light and shadow, from the keys,
  the page's turned-up corner or the page list; a new page past the last one.
  Index tabs on the notebook's edge.
- **The editor.** Paragraphs, a title, headings, subheadings, bulleted,
  numbered (1, a, i) and checklists with hand-drawn ticks and crossing off,
  quotes, sticky notes in six colors, code, dividers (a line, dots or a wave)
  and pictures (pasted, dropped or picked; sized, placed and removed in
  place). Bold, italic, underline, strikethrough, inline code, six inks, six
  highlighters, seven pens, text sizes from 11 to 64 (big text takes two or
  more ruled lines) and links. Markdown shortcuts, block
  picking with Esc, Shift+arrows or a drag, moving and duplicating blocks,
  paste that splits into blocks, and an undo history per page.
- **Templates**: pages that come laid out, picked in miniature from **+** or
  Ctrl+T: daily, weekly and monthly planners, a habit tracker, a journal, a
  to-do list, meeting and lecture notes, a project plan, a reading log, a
  recipe and a packing list, with faint hints in their empty parts.
- **Planner notebooks**: a notebook can make one kind of page, and a
  planner's next page is its next day, week or month (never one in the past).
- **Planner blocks**: time slots with their times in the margin (Enter goes on
  to the next, or starts one an hour on; `9:30 ` makes one), habits with a
  circle to tick for each day of the week, and a month's calendar with today
  marked and dates you circle.
- **Pages**: the other way to write, the way Notion does it, beside the
  notebooks (the Notebooks | Pages switch). Every block is an atomic record
  with a UUID v4, a type, its properties, the blocks inside it and its parent;
  a page is a block, and pages hold pages. The "/" menu, ⋮⋮ handles to drag a
  block and what's inside it (or to turn it into another kind, color it,
  duplicate it, move it to another page, delete it), columns side by side
  (drag a block up the side of another, or "/2 columns"; drag the gap to
  resize them), blocks inside any block,
  toggles and toggle headings, callouts with an emoji, code with its language,
  links to pages, a table of contents, dates in a line ("@tomorrow 3pm") and
  reminders (an Omarchy notification when they're due, which opens the
  page), links to pages in a line ("[["), backlinks, Notion's nine text and background
  colors, a toolbar over selected words, Markdown typed inline, a sidebar with
  the tree of pages, breadcrumbs, back and forward, page icons, covers, three
  fonts, small text, full width, search (Ctrl+P), a trash, and Markdown
  export. Favorites at the top of the sidebar; duplicating a page (and the
  pages in it); locking a page; turning a block (and what's inside it) into a
  page; templates on an empty page, laid out for Pages (columns, callouts,
  the day hour by hour, habits, the month's calendar, and what goes on each
  line); habits and a month's calendar as blocks in Pages too; numbered
  lists in columns counting 1, 2, 3;
  emoji by name (`:rocket:`); and code colored for its language (30 of them,
  light and dark), kept as plain text, with pasted lines staying in the
  block.
- **Import into Pages**: Markdown files and folders (Notion and Obsidian
  exports, zipped or not), HTML (Notion's too, with its colors, toggles,
  callouts and columns), plain text, Evernote's .enex, and Word, OpenDocument
  and RTF through LibreOffice or pandoc, keeping nesting, to-dos and their
  ticks, code languages (and code exactly as written, tabs and all),
  pictures, links between the pages, and Notion's ids. Markdown pasted into
  a page becomes blocks. A page is a JSON file named by its UUID in the Pages folder.
- **Commands for AI agents and scripts**, over the Omarchy shell's IPC (no
  MCP server): `omarchy-shell omanote help`, `list`, `find`, `read`, `add`,
  `addTo`, `append` and `trash`, answered in JSON, with pages in and out as
  Markdown (links to pages, dates and reminders too), new pages in an Inbox, and
  the app doing every write; `blocks`, `replace` and `insertAfter` change a
  page block by block. A skill (`skills/omanote/SKILL.md`), linked into the
  skill folders of the agents Omarchy supports while Omanote runs, teaches them
  how to use the commands.
- **Ask your agent** from Pages: Ctrl+J, `/agent`, a block's menu, the toolbar
  over selected words or the page's menu hand what you'd like (with the page,
  the blocks or words you picked) to Omarchy's default coding agent, whichever
  you chose with `omarchy default agent`; its changes show up on the page as
  it works, each one a step you can undo. The agent runs in its own terminal
  (Omarchy's agent window), so what it says, its questions and its summary of
  what it changed, comes back there rather than in Omanote.
- **Drawing**: a pen, a highlighter and an eraser over the writing, with its
  own undo.
- **Find** on a page (Ctrl+F), and **search** across every notebook from the
  shelf.
- **Quick notes**: Super+Alt+N (or right-click the bar icon, or
  `omarchy-shell omanote quick "text"`) puts a sticky note up anywhere; kept,
  it becomes a page in the Quick notes notebook.
- **Files**: a folder per notebook, a JSON file per page, pictures beside
  them, written atomically; trash instead of deleting; Markdown export.
- **Omarchy**: follows your theme, a bar icon, an app-launcher entry with
  its own icon, Super+N and Super+Alt+N
  registered with Hyprland at runtime (never in your config), window rules
  for a floating, opaque notebook, IPC, and settings on its shell.json entry.
- **Paper sounds** when a page turns and a notebook opens (can be turned off),
  and **reduce motion**.
