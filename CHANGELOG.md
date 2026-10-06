# Changelog

Every notable change to Uber Notebook is listed here, newest first. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and version
numbers follow [Semantic Versioning](https://semver.org/).

## 1.0.0 - Unreleased

The first version.

### Changed

- **Pages first.** Uber Notebook opens in Pages (the first time; then where
  you were), and a quick note goes to the Pages Inbox unless you choose the
  Quick notes notebook. The notebooks stay as they are: Pages is where new
  things come.
- **Omanote is now Uber Notebook.** The command is `omarchy-shell
  uber-notebook`, the plugin `marcho78.uber-notebook`, the agents' skill
  `uber-notebook`, and new notes go in `~/Documents/Uber Notebook` (a
  profile keeps the folder it has). Notes written as Omanote work as they
  did: their `omanote://` links (to pages, dates, reminders, people and
  tags) are read like the new `uber-notebook://` ones, and a Markdown copy
  made then is still recognized.

### Added

- **Print, PDF and Word for Pages.** *Print…* and *Export…* in a page's ⋯
  menu: a PDF (Chromium) or a Word file (LibreOffice), with the pages inside
  it if you like, saved where you say; *Print…* opens the PDF in your PDF
  viewer to print. Equations drawn, diagrams and pictures in it, on white
  paper, A4 or Letter as your locale has it. Chromium or LibreOffice
  installed later is found at the next try, no restart.
- **Claude Code and Grok ask you, in the panel, for what's beyond their
  rules**: a web page, a web search, a command, one of your connectors'
  tools, a file elsewhere (Grok over its agent protocol, in its sandbox,
  Always-approve off for these runs). What it is comes from the tool, never
  from what it's given. A command is shown whole, every line in sight:
  *Allow this command*, *Allow shell for this conversation* or *No*
  (Settings → AI → Commands can allow every command for an agent, off
  unless you turn it on; a command can change any file you can, your notes
  and settings included, and use the network). A site, searching or a tool: *Allow once*, *Always* or *No*; what
  you've allowed for good is in Settings → AI, to take back. Claude Code
  runs with your own plugins and MCP servers (Figma, Canva...), only your
  own settings (none from the folder it works in), its permission mode set
  to ask whatever your settings say; each takes its request and your
  answers on its input. Each conversation has a folder of its own.

- **The way out of the demo, in sight**: while the demo is open, a strip at
  the top says so, with *Make my own profile* (the welcome screen again);
  the profile menu has *Start screen…* too. Esc, Cancel or *Back to the
  demo* closes it.
- **Uber Notebook's name and icon** at the top of Pages' sidebar and the
  shelf (a click: Settings → About).
- **Claude, Grok and Codex side by side**, first, as tiles in the agent box
  and Settings → AI, each with who makes it and whether it's installed:
  they work right here; the other agents, under them, open in a terminal.
- **The skill for any AI**: Settings → AI → *Use with any AI* copies
  Uber Notebook's skill, saves a copy where you say, or shows its file, and
  `omarchy-shell uber-notebook skill` prints it, for an AI that can run
  commands on this computer.

- **A terminal instead, whenever you like**: *In a terminal* beside *Ask* in
  the agent box, and *Open in a terminal instead* in the panel all along (it
  stops there first), for Claude Code, Grok and Codex as you set them up,
  with all their own controls.

- **Move to Pages…**, in a notebook's menu on the shelf: it becomes a page
  with a page inside it for each of its pages, in order, written when they
  were: their text, their pictures (copied into Pages) and what's drawn on
  them (a sketch at each page's end). The notebook goes to the trash only once
  all of it is in Pages and saved; if a picture can't be copied or something
  can't be saved, it stays on the shelf too.
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
  lists in columns counting 1, 2, 3; mind maps (`/mindmap`, or a nested list
  turned into one), drawn with a color for each branch, written on in place,
  with folding branches, a text color and a background for any idea (a main
  idea's coloring its branch): Pages' colors, or any color from a color
  picker (saturation, brightness and hue, a hex field, recent colors, a
  contrast reading, shown on the map as you pick), with text kept readable
  on any background; and made by agents from a `mindmap` (or Mermaid) code
  block, colors and all; tables (`/table`, pasted from a spreadsheet, or
  imported and written as Markdown tables): a header row, cells with
  formatting, Tab, Enter and the arrows between cells, row and column
  handles with their menus, + bars for a new row or column, columns resized
  by dragging, a text color and a background for a cell, a row or a column
  (Pages' colors, recent ones, or the color picker), and spreadsheet cells
  pasted into a cell filling the table;
  tags (`#errand` in any line, the "#" menu, a color for each, the
  sidebar's Tags as chips with a ⋯ and right-click menu to color, rename or
  remove one, sorted by name or by color, nested tags after the tag they're
  in and in its color unless they have their own, Ctrl+P with "#"): a tag shows
  every block with it, page by page, to-dos ticked there, and renames or
  comes off every page in one go (Obsidian's `#tags` come in as tags, and go
  out as `#tags` in Markdown);
  pages dragged in the sidebar (before, after or inside another page, with
  Undo); projects (a page's status, due date and progress from the to-dos on
  it and in it; the sidebar's Projects, where + makes one, a page dragged
  there is one and a project dragged into Pages is a page again, with the
  pages in each under it and late ones in red; front matter in and out of
  Markdown); an Archive for pages that are done (out of the tree and the
  Projects, still there to open and search, with Undo); a page's menu in
  the sidebar makes it a project or archives it too;
  audio notes (`/audio`): it records at once, with the time and your voice's
  level, Enter stops it and Esc throws it away; then a player with its
  waveform (click or drag to go there), the time and the speed, and what was
  said written out under it by voxtype (as it's recorded, or with "Write it
  out"), to read, search and correct; its colors, Pages' or your own; an
  Opus file in Pages/assets, linked with what was said in Markdown; the
  voice evened out once it's recorded, so a quiet laptop microphone comes
  out loud and clear, and "Louder" for a quiet note from before; a red dot
  at the top of a page (Ctrl+Shift+R) records one where you are; Settings →
  Audio picks the microphone, makes the voice louder or not, and tests the
  microphone;
  Settings → Appearance: your own colors for the sidebar, the page
  background, the sections and cards (the sidebar's sections become cards)
  and the text, over the Omarchy theme's (which they follow until you
  change them); picked with the color picker, shown as you pick, reset one
  or all; a warning when the text won't read on a color;
  emails on pages (/email, or an .eml dropped on one: a card with its
  subject, who it's from and to, when, its first lines and attachments;
  shown in full with its HTML made safe, no scripts or pictures from the
  web; attachments opened in their apps; the .eml in your mail app; in the
  Library under Emails, found by subject, sender or recipient);
  People (in the sidebar: your contacts, on your computer with no account;
  imported from a .vcf (a phone, Google, iCloud, Outlook) or a .csv, those
  already there filled in, not added twice; exported as a .vcf; a list
  beside the one picked, or cards (grouped A to Z, with A to Z down the
  side, or by company; each with who and where, a number and an email
  with Copy and Write under the pointer, and a birthday coming up, the
  pages they're on and how many more numbers and emails; the search in
  bold; the arrow keys and Enter); each person a card: their numbers and
  emails with what they are, birthday, address, website, notes, and the
  pages they're named on; Edit, a form with each field named and what's
  wrong said under it); "@" and a name
  on a page for a person (a new one too), their card on a click; /contact,
  someone's card on a page; emails typed or pasted made links (to the
  person, when they're someone's); `contacts`, `contact`, `addContact` and
  `importContacts` for agents;
  the Library (in the sidebar: everything put on the pages in one place,
  newest first: links, from bookmark cards and from text, files and PDFs,
  videos, pictures, audio notes, meetings, sketches, people and emails, each with the page
  it's on; by kind, or found by name, link or page; a click goes to it on
  its page, Open opens it, Copy copies a link; `library` for agents);
  boards (`/board`: cards in columns, written in place, dragged, made
  pages; each card and each column with its own text and background
  color, from a palette on it, and the whole board's apart; a right-click
  for a card's or a column's menu; columns renamed with a click or Rename, a new one named as
  it's added, moved; a column's edge dragged wider, the board's
  bottom edge taller or shorter, scrolling inside); files and PDFs (`/file`,
  `/pdf`, or dropped on a page: copied in, opened in their app, a PDF's
  pages shown); videos (`/video`: played on the page, a still until then);
  web bookmarks (`/bookmark`: a link as a card, its page read once); buttons
  (`/button`: a click puts in a template, or makes a page from it); synced
  blocks (blocks kept on a page of their own and shown wherever they're
  pasted, changed in one place for all, unsynced back); each with Pages'
  colors or your own, undo, Markdown and agents;
  a calendar of your own (no account): by month, by week (hour by hour,
  overlaps side by side), as an agenda, or compact (a small month with a
  dot for each event and the days from the one picked beside it), opening
  in the view used last, its views in one menu in a narrow window; events
  added by typing ("Lunch
  with Sam fri 12:30"), changed in their editor (all day or times, repeats
  daily, on weekdays, weekly, monthly or yearly, every few and until a day,
  alerts as Omarchy notifications, Pages' colors or your own, a place, a few
  words), dragged to another day or time and made longer; a repeating one
  asks about just this one; Undo; reminders and projects' due dates on it;
  Today in the sidebar; notes for an event; `/agenda` and `/event` on a
  page; `.ics` export; `events`, `addEvent` and `removeEvent` for agents;
  your own templates: Save as template (a copy of a page and the pages in
  it) or New template, kept apart in Templates at the sidebar's foot and
  changed like any page; used on a blank page (yours first), with
  `/template` where you are, as a new page, or for every new page inside a
  page; `{{date}}`, `{{weekday}}`, `{{time}}`, `{{month}}`, `{{year}}` and
  `{{week}}` filled in; `templates` and `fromTemplate` for agents;
  meetings (`/meeting`, or the people at the top of a page): voxtype's
  meeting mode records your microphone and the other side of a call, with
  Pause and Stop (and a bar on other pages); when it ends, who said what is
  in the meeting, turn by turn, each speaker in a color and named with a
  click; Summarize asks your agent for the summary, decisions and to-dos;
  a meeting voxtype recorded on its own can be brought in; meeting mode
  turned on from the meeting or Settings → Audio;
  dictation (Ctrl+Shift+D, the microphone at the top of a page, `/dictate`,
  and the microphone on the quick note, clicked or held while you speak):
  voxtype writes what you said where your cursor is;
  sketches (`/sketch`): a pen, a highlighter and an eraser that lifts whole
  strokes, in the page's ink, Pages' colors or any color from the color
  picker, three nibs, plain paper, dots or a grid, a height you drag, every
  stroke a step to undo, and SVG files in exports;
  page history (*Page history* in a page's ⋯ menu): a version kept every ten
  minutes while you write and before an agent or a command changes the page,
  each shown as it was, and put back as a step Undo takes back, without
  losing the pages made inside it since;
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
- **A picture picker of Uber Notebook's own**: your pictures shown as pictures
  (newest first, folders first, Pictures, Downloads, Desktop and Home a
  click away), several chosen at once for a gallery (click, Shift+click a
  run, Ctrl+A), one for `/image`; Qt's own file dialog takes one file at a
  time, and the desktop's would run inside the shell.
- **Scrolling a page with a trackpad** follows the fingers (no more
  stepping), its quicker strokes going further (as on a MacBook; Omarchy's
  Hyprland sends a trackpad's movement at 0.4), and glides on when they
  lift, slowing as a MacBook's does; a mouse wheel's notches glide and add
  up when it's spun fast. In Pages and in notebooks; Settings → *Scrolling
  speed* (slower, normal, faster).
- **Links changed in place**: a web bookmark's ✎ changes its link (its
  page read again); a link-to-page block's *Change* points it at another
  page (and fixes one whose page is gone).
- **Pictures**: a handle on each side of a picture (under the pointer)
  sizes it, its width shown as it's dragged, a double-click the page's
  width; a picture is shown large in Uber Notebook (←/→ for the others, Esc),
  not in another app. **Galleries** (`/gallery`): pictures in a grid, 2 to
  4 to a row, picked several at once or dropped, moved, captioned, taken
  out, taller or shorter by the bottom edge, shown large, in the Library,
  with colors. A click in the calendar's event editor no longer clicks the
  day under it too.
- **Calendar files and contact cards open in Uber Notebook**: an `.ics` (an
  email's attachment, a file on a page, one dropped, or *Import .ics…* in
  the calendar's ⋯) shows its events, with *Add to calendar* (none added
  twice); a `.vcf` attachment puts its people in People; a file whose only
  app is a web browser, or none, isn't handed to it (it would download it
  and take you away): it's said so; `importCalendar` for agents.
- **Settings in sections**: General, Appearance, Writing, Audio, Profiles,
  Backups and About, chosen at the left, each setting on a card in its
  group with a line about it; Esc closes Settings opened from Pages (the
  page kept the keys before).
- **Backups**: the open profile, or all of them, in one `.tar.gz` (any
  archive tool opens it: an `uber-notebook-backup.json` and each profile's
  folder), in `~/Documents/Uber Notebook Backups` or a folder you choose, whole
  or not at all; automatic ones daily or weekly (off to start with), the
  oldest past 3 to 50 to the trash, never the ones you make. **Restore**
  says what's in a backup, then puts each profile back as a new profile in
  a new folder, with its page, notebook and Inbox, writing over nothing;
  the first run can restore one, for a new computer. A file that isn't a
  backup, or holds links or reaches outside its folders, is refused;
  `backup`, `backups` and `restoreBackup` for agents.
- **Updates**: Uber Notebook asks GitHub for its newest release a minute after
  it starts and once a day (Settings → About; off, only when you ask);
  a newer one shows at the foot of Pages' sidebar, in the shelf's corner
  and by About, a click from its release notes (read in Uber Notebook, without
  pictures or HTML), with the command that installs it (`omarchy plugin
  update marcho78.uber-notebook`), to copy and run in a terminal, where it
  shows what changes and asks first (Uber Notebook never installs anything
  itself); *Release notes* for the version you have, from `CHANGELOG.md`;
  `appVersion`, `checkUpdate` and `releaseNotes` for agents.
- **Follow me on X** (@devsec_ai) at the foot of Pages' sidebar, in the
  shelf's corner and in Settings → About.
- **Profiles**: notes kept apart (personal, work, the demo...), each a
  folder of its own with its notebooks, Pages, calendar, People, templates
  and Markdown copy, and its own Inbox for agents and place you were; a
  dropdown at the top of Pages' sidebar and on the shelf switches between
  them, makes a new one (a name, and the folder its notes go in) or opens
  Settings' Profiles (rename, another folder, open the folder, take one off
  the list, start the demo over); the first run asks for your first profile
  (or the demo) and makes nothing anywhere until then; an Uber Notebook from
  before profiles opens as it was, its folder a profile ("Personal"); a new
  profile starts empty, with the templates; `profiles`, `profile`,
  `addProfile`, `renameProfile`, `profileFolder`, `removeProfile`, `demo`
  and `restartDemo` for agents.
- **The demo's examples**: the demo profile's Pages has pages that each show a different side of it (a welcome page with
  the keyboard shortcuts as a PDF, a week's plan with agendas and habits, a
  project with its board, milestones and meeting notes holding a recorded
  meeting, a trip with its flight's email and bookmarks, a mind map and a
  sketch, a reading list, a recipe in columns, a journal with a button, a
  page of people, a cheatsheet), the people and events they name, dated from
  that day, and six templates; **Templates** in the sidebar is a page of
  cards (yours, then Uber Notebook's), each with what it's for (a line written at
  the top of a template of yours), found by its name or what it's for, a
  click a new page from it; written as Markdown in `starter/`
  (`dev/starter` builds them in). The Library has someone, or a link, once
  for each page they're on; a contact card says a birthday as People does.
- **Equations**: `/equation` (a code block in Math: LaTeX, drawn by MathJax
  in a worker thread, with nothing to install; the drawing under it as
  it's written, what's wrong said; elsewhere just the equation, a click
  away from its LaTeX) and equations in a line (`$$x^2$$` typed, or
  `/inline equation`), on the line's baseline, a click to change one.
  Markdown's `$…$`, `$$ … $$` and ```` ```math ```` come in and go out as
  equations (notes imported from Notion and Obsidian keep theirs; a
  backslash in LaTeX was lost on import before), "$5 and $10" stays money,
  search finds their LaTeX, and agents read and write them.
- **Diagrams**: `/diagram`, `/decision tree`, `/network diagram` and
  `/system diagram`, written as Mermaid flowcharts (the shapes, links with
  words, dotted and thick ones, groups, icons such as servers, databases,
  routers, firewalls and users) and drawn in the page in its colors, laid
  out so lines are kept apart and groups go round what's in them; the
  drawing under what's written as it's written, a mistake said by its
  line; ```` ```mermaid ```` from Markdown and agents is drawn the same way.
  Colors as Mermaid gives them (`style`, `classDef` with `class` or `:::`,
  `linkStyle`: fills, outlines, the words' color, thicker or dashed lines,
  bold), kept readable on a light or a dark page. LaTeX and Mermaid are
  colored as they're written.
- **Pictures, out of Uber Notebook**: Copy (onto the clipboard, to paste in
  any app; a JPEG, WebP or BMP as a PNG when ffmpeg is installed) and Save a
  copy… (where you say, named for its page or caption) on a picked
  picture's bar, in Pages and in notebooks, and where it's shown large
  (Ctrl+C, Ctrl+S). Shown large, its arrows go to the next picture without
  closing it, and a click there is no longer also the page's under it.
  Agents find a picture's file with `library pictures`.
- **Diagrams and equations, large**: one wider than the page is drawn
  smaller, saying how much; its expand button (there, or when you point at
  one) opens it over everything, to zoom in on: Ctrl+scroll or a pinch
  (round the pointer), + and -, or the buttons; dragged or scrolled to move
  round it (Shift+scroll sideways); 0 shows all of it, 1 its real size, Esc
  closes it. It's drawn again at each size, so it stays sharp, and nothing
  on the page under it is clicked or scrolled through it. Either one as a
  picture: Copy as a picture (to paste in any app) or Save as a picture…
  (a PNG, twice its size, on its block's colors), from under the pointer
  or large (Ctrl+C, Ctrl+S).
- **Footnotes**: `/footnote` after a word, numbered down the page and listed
  at its end, a click (there or in the list) to change one or take it out;
  Markdown's `[^1]` and `^[…]` come in as footnotes and go out as `[^1]`
  with their words at the end.
- **Pages' sidebar, yours to arrange**: the top stays put (the switch back
  to notebooks, the profile, search with a new-page button beside it, and
  Calendar, Library and People side by side); the middle scrolls as one
  (Today, Favorites, Projects, Tags and Pages, none of them cut short); the
  foot is a row of small buttons (Import, Templates, Archive, Trash and
  Settings, each with how many are in it) over a quieter *Follow me on X*.
  A click on a section's name folds it, and it stays folded. The tags are
  chips in their colors, with *Show all* past four rows. Anything but Pages
  and Settings can be left out: a right-click on it, *Hide* (Undo brings it
  back), or Settings → Appearance → Sidebar; without Projects, the projects
  are in Pages, where they are. A title typed redraws its own row, not the
  whole tree. The `sidebarHidden` and `sidebarFolded` settings, for agents
  and scripts too.
- **Commands for AI agents and scripts**, over the Omarchy shell's IPC (no
  MCP server): `omarchy-shell uber-notebook help`, `list`, `find`, `read`, `add`,
  `addTo`, `append` and `trash`, answered in JSON, with pages in and out as
  Markdown (links to pages, dates and reminders too), new pages in an Inbox, and
  the app doing every write; `blocks`, `replace` and `insertAfter` change a
  page block by block; `tags`, `tagged` and `tagColor` list tags, the blocks
  with one, and color them; `projects`, `project`, `archive` and `unarchive`
  for projects and the archive; `templates` and `fromTemplate` for the
  user's templates; `events`, `addEvent` and `removeEvent` for the calendar; `mirror` brings the Markdown copy up to date;
  `rename`, `move`, `icon`, `cover`, `lock`, `favorite`, `trashed`,
  `restore`, `duplicate` and `makeTemplate` for pages; `history`, `version`
  and `restoreVersion` for a page's history; `check`, `color`,
  `removeBlock`, `board`, `attach` and `bookmark` for blocks, boards, files
  and links; `picture` (a picture's size and side), `addGallery` and
  `gallery` (a gallery of files or a folder's; pictures added, moved,
  captioned, taken out; its columns and height), `setLink` (a bookmark's
  link, a link's page); `board` sizes boards and columns and colors cards
  and columns; `addTemplate` (from Markdown) and `describeTemplate`;
  `preferences` (every setting, with what it can be) beside `set`; `editEvent`, `editContact`, `removeContact`, `renameTag` and
  `removeTag`; `notebooks`, `notebook`, `readNotebook` and `addToNotebook`
  for the Notebooks; boards, bookmarks, links to pages, galleries, people,
  agendas and events read and written as fenced code (```` ```board ```` and
  the like). A
  version of a page is kept in its history before a command changes it. A skill (`skills/uber-notebook/SKILL.md`), linked into the
  skill folders of the agents Omarchy supports while Uber Notebook runs, teaches them
  how to use the commands.
- **Ask your agent** from Pages: Ctrl+J, `/agent`, a block's menu, the toolbar
  over selected words or the page's menu hand what you'd like (with the page,
  the blocks or words you picked) to Omarchy's default coding agent, whichever
  you chose with `omarchy default agent`; its changes show up on the page as
  it works, each one a step you can undo. Claude Code, Grok and Codex work
  right in Uber Notebook, without a terminal: a panel on the page shows each
  step they take and their answer (as it's written, for Claude Code and
  Grok), with Stop; if one can't run there, the panel says why and offers a
  terminal instead (a meeting's Summarize goes the same way). A reply at
  the panel's foot goes on in the same conversation (it remembers what you
  asked and what it did; told where you are if you've moved or picked
  something since), what was said before above. Each page keeps its
  conversation (Pages/chats.json): closed, the AI button marks it, and
  Ctrl+J goes back to it, after a restart too (in a new session told what
  was said, if the agent's own is gone); New chat starts another. Each starts
  with the permission mode Omarchy gives it. Their model and effort are
  chosen in the box or in Settings → AI, from each agent's own list of
  models and the efforts each takes. Agents are told to read and change
  notes only through the commands, and the skill now says how to make a page
  look good (callouts and their colors, toggles, dividers, highlights,
  colored words, block colors, an icon and a cover), so they don't go
  looking through Uber Notebook's code: the same request took Grok 78 tool
  calls before, 7 after. The other agents run in their
  own terminal (Omarchy's agent window), so what they say comes back there
  rather than in Uber Notebook. **A new page** instead of this one: the
  switch at the top of the box (or Ctrl+J with no page open, from the
  calendar, People...); Uber Notebook makes the page first, at the top of
  Pages or inside the page you're on, opens it, and the agent titles it and
  writes it there as you watch; if it couldn't (it failed, or you stopped
  it) and the page is still empty when its panel's closed, the page goes and
  you're back where you were (one it's asked you something about stays, to
  answer on).
- **Drawing**: a pen, a highlighter and an eraser over the writing, with its
  own undo.
- **Find** on a page (Ctrl+F), and **search** across every notebook from the
  shelf.
- **Quick notes**: Super+Alt+N (or right-click the bar icon, or
  `omarchy-shell uber-notebook quick "text"`) puts a sticky note up anywhere; kept,
  it becomes a page in the Quick notes notebook, or (Settings, or a click on
  the note's foot) a page in the Pages Inbox, its text read as Markdown.
- **Files**: a folder per notebook, a JSON file per page, pictures beside
  them, written atomically; trash instead of deleting; Markdown export, to a
  folder you pick or to the Exports folder (a setting).
- **A Markdown copy** (Settings): every page of Pages and of the notebooks
  kept as Markdown files in a folder, a few seconds after anything changes,
  for Obsidian, git or any editor; Pages' tree as folders, links between
  pages as links between files, pictures and sketches beside them; files
  written only when they change, and only the copy's own files ever removed.
- **Omarchy**: follows your theme, a bar icon, an app-launcher entry with
  its own icon, Super+N and Super+Alt+N
  registered with Hyprland at runtime (never in your config), window rules
  for a floating, opaque notebook, IPC, and settings on its shell.json entry.
- **Paper sounds** when a page turns and a notebook opens (can be turned off),
  and **reduce motion**.

### Security

- **Your agent, in the panel, reads and changes your notes as you ask, and
  nothing contacts a site for it without your yes.** While one works, Uber
  Notebook's commands read and change your notes (pages, People, the
  calendar, templates), not Uber Notebook's settings, profiles or backups;
  files they take come only from its folder, read by a helper first. A link
  it adds is kept as its link: Uber Notebook contacts the site (for its title
  and picture) only after you answer in the panel, *Allow once*, *Always for
  that site* or *No*; redirects and pictures only from sites it may contact.
  **Settings → AI** lists the sites you've allowed, for each agent, to take
  back; an agent can't change them. Agents are found where they're
  installed, checked, and run by their full path.
- **Nothing installs itself**: no *Update now*, no `installUpdate` command;
  Uber Notebook shows the `omarchy plugin update` command to run yourself.
- **Your notes are read and written by a helper kept running for their
  folder** (`bin/uber-notebook-files serve`): never through a link, only a
  plain file within its size, each save a new file flushed to the disk and
  put in place. A file that can't be read is said and never saved over
  (before, it could be taken for one that isn't there). If the helper doesn't
  answer, it's done as before.
- **Pictures copied in only as pictures**: attached, in a gallery, in
  imported notes or a notebook moved to Pages, each by the files helper,
  only a plain file whose bytes are a picture Qt can show (50 MB, 16384 px a
  side), as a new file; an agent's only from its own folder, through no
  link. Pictures on a page are decoded no bigger than they're shown.
- **Archives counted before they're made**: every folder and every entry,
  a zip's directory before it's read (zip64's too), and all a backup
  unpacks to; the helper at most 4 GB of memory. An import unzips on disk
  (`~/.cache/uber-notebook`), not in the session's memory. A link in a
  backup (one synced into a profile) is left out when it's put back, and
  said, instead of making the whole backup unrestorable; a sparse file
  refuses it.
- **The recorder runs ffmpeg as every other command runs** (its own process
  group, a tool's environment, its output read in pieces, within budgets).
- **Bookmarks read only from the internet**, step by step, from the address
  looked up, past any proxy, redirects checked one by one.
- **The Markdown copy's changes checked on the file's bytes** (SHA-256, as
  it's moved aside), so a file you edited is never written over or taken
  away; one from before is the copy's only if it's exactly what it would
  write.
- **What's taken away is checked as it's moved aside** (the launcher entry,
  the skill's links, a failed backup's folder), backups never written over
  one, and temporary folders always made new.
- **Imports' LibreOffice gets no network**, as exports' does.
- **Exports are made offline**: the page as HTML with every word escaped,
  its pictures put in and every tag checked by the files helper (nothing that
  loads from anywhere gets past), then Chromium or LibreOffice with a
  profile of its own and no network at all.
- **Archives** (a zip you import, a backup you put back) are opened by a small
  helper (`bin/uber-notebook-files`, Python, isolated): nothing in them can land
  outside its folder, be a link or a device, or take more than its room; a
  backup is put back only if it's still the file looked into.
- **Text from elsewhere stays text**: a page's formatting can't carry a
  picture or a style Uber Notebook wouldn't write; what you paste (Ctrl+V, or
  a middle click) is read with `wl-paste` and cleaned before Qt reads it, so a
  page copied from the web can't make it fetch its pictures; links go only to the web,
  email or Uber Notebook; an agent's answer and release notes are drawn
  without fetching anything; an email's HTML is rebuilt from a short list of
  tags.
- **Budgets** on what can be slow or big: equations ("Too big to draw"),
  diagrams, imports, emails, contacts, code highlighting, an agent's output,
  a pasted picture, a file copied in, a PDF shown, a picture shown large, a
  recording.
- **Commands** get only the environment a tool needs and `PATH=/usr/bin`, end
  with anything they started, and never write over a file that's there;
  `ffmpeg` reads files only as files; `curl` ignores `~/.curlrc`; text you copy
  goes to `wl-copy` on its input; a bookmark's picture is fetched only from
  the internet, never from your computer or network.
- **Files of its own only**: its launcher entry and skill links are made only
  where nothing is, and taken out only if they're still its own; the Markdown
  copy never writes over or takes away a file you edited there; switching
  profiles keeps nothing of one in the other.
- **Taking things away is asked**: the panel's agent moving pages to the
  trash (*Always* there if you like), or removing a person, an event, a tag,
  or emptying a person's or an event's detail (at most for that
  conversation), asks you first, one
  question for each thing, in the conversation that asked; when it ends,
  what it asked is answered No. A link it adds is read only with your yes to
  that link.
- **Text in any script arrives whole**: what a program prints (a
  transcript, an agent's answer, a list of files) and what you paste come
  back ASCII through the files helper, so no character is cut in two; an
  agent's output keeps its room, counted as it prints it.
- **No page or index can freeze the shell**: a page's formatting and Pages'
  tree are read in time in step with their size, and a tree thousands of
  pages deep is gone through without running out of stack.
- **Exports and the Markdown copy within their budgets**: each picture
  counted every time it's used, and one past what's left never read;
  synced blocks at most 50 and 4 million characters a page, never a page
  inside itself, 16 million in all of a copy's pass.
- **A save that fails is said and tried again**: your notes' own files that
  couldn't be written are kept and tried again every 30 s, before another
  profile opens and as the window closes, whether their page is open or
  not ("Saved now" when they are, a notification if they still aren't as
  the window closes); each page's folder is flushed with it; a change not
  saved over a file that couldn't be read is said.
- **Just after it starts, commands read the page first** and say to run
  them again, never that it isn't there.
- **Nothing crosses profiles**: a file, picture or site still on its way
  when another profile opens, or a Markdown copy, an import, an export or
  *Move to Pages* that had begun, stops or stays with the one it was for;
  the panel's conversation, and what you allowed in it, stay behind.
- **Sites read only at the address checked**: a name ending in "." isn't
  read (curl wouldn't keep to that address).
- **The Markdown copy's own files**: its list of what it wrote is written by
  the files helper (a link there replaced, never written through; the folder
  you chose may be a link to where you keep it), said if it couldn't be, and
  its pictures are never copied through a linked folder.
