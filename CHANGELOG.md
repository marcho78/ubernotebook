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
  tags (`#errand` in any line, the "#" menu, a color for each, a Tags list
  in the sidebar with a ⋯ and right-click menu to color, rename or remove
  one, sorted by name or by color, nested tags under the tag they're in and
  in its color unless they have their own, Ctrl+P with "#"): a tag shows
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
  beside the one picked, or cards; each person a card: their numbers and
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
- **A picture picker of Omanote's own**: your pictures shown as pictures
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
  width; a picture is shown large in Omanote (←/→ for the others, Esc),
  not in another app. **Galleries** (`/gallery`): pictures in a grid, 2 to
  4 to a row, picked several at once or dropped, moved, captioned, taken
  out, taller or shorter by the bottom edge, shown large, in the Library,
  with colors. A click in the calendar's event editor no longer clicks the
  day under it too.
- **Calendar files and contact cards open in Omanote**: an `.ics` (an
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
  archive tool opens it: an `omanote-backup.json` and each profile's
  folder), in `~/Documents/Omanote Backups` or a folder you choose, whole
  or not at all; automatic ones daily or weekly (off to start with), the
  oldest past 3 to 50 to the trash, never the ones you make. **Restore**
  says what's in a backup, then puts each profile back as a new profile in
  a new folder, with its page, notebook and Inbox, writing over nothing;
  the first run can restore one, for a new computer. A file that isn't a
  backup, or holds links or reaches outside its folders, is refused;
  `backup`, `backups` and `restoreBackup` for agents.
- **Updates**: Omanote asks GitHub for its newest release a minute after
  it starts and once a day (Settings → About; off, only when you ask);
  a newer one shows at the foot of Pages' sidebar, in the shelf's corner
  and by About, a click from its release notes (read in Omanote, without
  pictures or HTML); *Update now* for an Omanote installed with
  `omarchy plugin add` (`omarchy plugin update`), else the command to
  copy; *Release notes* for the version you have, from `CHANGELOG.md`;
  `appVersion`, `checkUpdate`, `releaseNotes` and `installUpdate` for
  agents.
- **Follow me on X** (@devsec_ai) at the foot of Pages' sidebar, in the
  shelf's corner and in Settings → About.
- **Profiles**: notes kept apart (personal, work, the demo...), each a
  folder of its own with its notebooks, Pages, calendar, People, templates
  and Markdown copy, and its own Inbox for agents and place you were; a
  dropdown at the top of Pages' sidebar and on the shelf switches between
  them, makes a new one (a name, and the folder its notes go in) or opens
  Settings' Profiles (rename, another folder, open the folder, take one off
  the list, start the demo over); the first run asks for your first profile
  (or the demo) and makes nothing anywhere until then; an Omanote from
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
  cards (yours, then Omanote's), each with what it's for (a line written at
  the top of a template of yours), found by its name or what it's for, a
  click a new page from it; written as Markdown in `starter/`
  (`dev/starter` builds them in). The Library has someone, or a link, once
  for each page they're on; a contact card says a birthday as People does;
  the sidebar's page tree keeps room for its pages however many projects and
  tags there are.
- **Commands for AI agents and scripts**, over the Omarchy shell's IPC (no
  MCP server): `omarchy-shell omanote help`, `list`, `find`, `read`, `add`,
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
  version of a page is kept in its history before a command changes it. A skill (`skills/omanote/SKILL.md`), linked into the
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
