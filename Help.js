// Help.js - what Help (app/HelpPanel.qml) shows: every key and where it
// works, what you can type, every block, every feature where you meet it,
// and the commands from a terminal. Taken from the code, each checked
// there (tests/help.test.cjs keeps it so: every key the views handle, every
// "/" command and every terminal command are in it). Plain words only,
// shown as plain text: nothing in it is run, opened or read from your notes.
.pragma library

// [{ id, label, icon (Theme's icons), note, groups: [{ title, rows: [[what
// you do, what it does, a note ("" for none)]] }] }]
var SECTIONS = [
 {
  "id": "start",
  "label": "Start here",
  "icon": "info",
  "note": "The few things worth knowing first.",
  "groups": [
   {
    "title": "Start here",
    "rows": [
     [
      "Super+N",
      "Open or close Uber Notebook, from anywhere (or click the notebook in the top bar).",
      ""
     ],
     [
      "Super+Alt+N",
      "A quick note, from anywhere: it goes to your Pages Inbox (right-click the top bar's notebook too).",
      ""
     ],
     [
      "New page (Ctrl+N)",
      "A new page, at the top of Pages: the button at the top of the sidebar.",
      ""
     ],
     [
      "/",
      "On a page, the menu of every kind of block: headings, to-dos, tables, boards, mind maps, pictures, files, audio, meetings, equations, diagrams...",
      "See Blocks."
     ],
     [
      "@",
      "A person, a date, or a reminder: type @ and a time (@in 10 min, @fri 3pm), then pick ⏰ Remind me.",
      "See Dates and reminders."
     ],
     [
      "[[  #  :",
      "A link to a page, a tag, an emoji.",
      ""
     ],
     [
      "Ctrl+P",
      "Find a page by its words.",
      ""
     ],
     [
      "Ctrl+J",
      "Ask your agent (Claude Code, Grok or Codex) about the page, the blocks or the words you picked.",
      "See Your agent."
     ],
     [
      "⋮⋮ beside a block",
      "Drag it to move it; click it for its menu (turn it into another kind, color, duplicate...).",
      ""
     ],
     [
      "Ctrl+,",
      "Settings.",
      ""
     ],
     [
      "Ctrl+/ or F1",
      "This Help, from anywhere in Uber Notebook.",
      "Ctrl+? where / needs Shift."
     ]
    ]
   }
  ]
 },
 {
  "id": "keys",
  "label": "Keyboard",
  "icon": "keyboard",
  "note": "Every key, where it works.",
  "groups": [
   {
    "title": "Global (Hyprland)",
    "rows": [
     [
      "Super+N",
      "Open or close Uber Notebook from anywhere on the desktop",
      "You can change it, or clear it to turn it off, in Settings → General → Shortcuts. It is not registered when another Hyprland binding already uses those keys, and Settings names that binding. When Hyprland's bindings can't be read, neither shortcut is registered. A shortcut needs a modifier unless the key is F1-F24 or an XF86 media key."
     ],
     [
      "Super+Alt+N",
      "Jot a quick note: the sticky note pops up wherever you are",
      "You can change it in Settings → General → 'Jot a quick note'. It is skipped when it matches the open/close shortcut, or when another binding already uses it."
     ]
    ]
   },
   {
    "title": "Anywhere",
    "rows": [
     [
      "Ctrl+,",
      "Open Settings (Esc closes them)",
      "Works in Pages, on the shelf and in a notebook. In a text block, Ctrl+Shift+, means 'smaller text' instead."
     ]
    ]
   },
   {
    "title": "Pages",
    "rows": [
     [
      "Ctrl+N",
      "Make a new page at the top level of Pages (not inside another page) and put the cursor in its title",
      "Pages only. In a notebook, Ctrl+N adds a notebook page instead."
     ],
     [
      "Ctrl+P",
      "Search your pages: recent pages, or every page with the words you type",
      "Pages only."
     ],
     [
      "Ctrl+\\",
      "Hide or show the sidebar",
      "Only when the cursor is NOT in a text block, a table cell or on picked blocks. There, Ctrl+\\ clears formatting instead."
     ],
     [
      "Ctrl+F",
      "Find on this page",
      "Also works with the cursor in a locked page's text."
     ],
     [
      "Ctrl+J",
      "Ask your AI agent. It asks about the picked blocks, otherwise the selected words, otherwise the empty line you're on, otherwise the whole page",
      "With no page open (for example in the calendar or People), it asks for a new page. If the page already has a chat with the agent, Ctrl+J opens that panel again. While the agent is working, it shows the agent's panel."
     ],
     [
      "Ctrl+Shift+D",
      "Start dictating. Press it again to finish, and your words are written at the cursor",
      "Needs a page open that isn't locked. Needs ffmpeg and voxtype. In a notebook, Ctrl+Shift+D means Draw instead."
     ],
     [
      "Ctrl+Shift+R",
      "Record an audio note where you are. Press it again to stop",
      "Needs a page open that isn't locked. Needs ffmpeg. Pages only."
     ],
     [
      "Ctrl+Shift+C",
      "Open the calendar",
      "Pages only. With blocks picked, Ctrl+Shift+C copies the blocks instead."
     ],
     [
      "Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y",
      "Undo / redo on the page",
      "Does nothing on a locked page."
     ],
     [
      "Alt+← / Alt+→",
      "Go back / forward through the pages and views you opened (calendar, People, Library, a tag, Templates)",
      "Pages only. In a notebook, Alt+←/→ turns the page. Also works on a locked page."
     ]
    ]
   },
   {
    "title": "Page title",
    "rows": [
     [
      "Enter or Tab in the title, or ↓ at the end of it",
      "Go from the title down to the page's first line",
      "In Pages, ↓ works only with the cursor at the end of the title. In a notebook, ↓ works from anywhere in the title."
     ],
     [
      "↑ on the page's first line",
      "Go up into the title",
      "Pages and Notebooks."
     ],
     [
      "Ctrl+V or Shift+Insert in the title, with several lines of text copied",
      "Paste: the first line becomes the title and the rest becomes the page (Markdown is read)",
      "Pages only. Text on a single line pastes normally."
     ],
     [
      "Enter / Esc in a template's 'what it's for' line",
      "Keep the description / put it back as it was",
      "Only on a template's own page."
     ]
    ]
   },
   {
    "title": "Editing text",
    "rows": [
     [
      "Ctrl+B",
      "Bold",
      "Pages and Notebooks. With nothing selected, it applies to what you type next. In Pages, formatting does nothing inside a code block."
     ],
     [
      "Ctrl+I",
      "Italic",
      ""
     ],
     [
      "Ctrl+U",
      "Underline",
      ""
     ],
     [
      "Ctrl+Shift+X",
      "Strikethrough",
      "It works with nothing selected (for what you type next) and on selected words in a table cell. The strikethrough buttons on the toolbars work."
     ],
     [
      "Ctrl+Shift+H",
      "Highlight",
      "Not in table cells."
     ],
     [
      "Ctrl+E",
      "Inline code",
      ""
     ],
     [
      "Ctrl+K",
      "Open the link box for the selected words, or the word at the cursor. On a link, you can change or remove it",
      "Pages and Notebooks. Not in table cells."
     ],
     [
      "Ctrl+Shift+> (Ctrl+Shift+.) / Ctrl+Shift+< (Ctrl+Shift+,)",
      "Make the text one size bigger / smaller",
      ""
     ],
     [
      "Ctrl+\\",
      "Clear formatting (back to plain text)",
      "With nothing selected, it cancels formatting you'd set for what you type next."
     ],
     [
      "Ctrl+Alt+0 / 1 / 2 / 3",
      "Turn the block into text / title (H1) / heading (H2) / subheading (H3)",
      "Pages and Notebooks. Also works on picked blocks."
     ],
     [
      "Ctrl+Alt+4 / 5 / 6 / 7 / 8",
      "Turn the block into a to-do / bulleted list / numbered list / toggle / code block",
      "Pages only, and only with the cursor in text. These keys don't work on picked blocks."
     ],
     [
      "Ctrl+Shift+7 / 8 / 9",
      "Turn a numbered list / bulleted list / checklist on or off",
      "Pages and Notebooks."
     ],
     [
      "Alt+Shift+↑ / ↓",
      "Move the block up / down",
      ""
     ],
     [
      "Ctrl+D",
      "Duplicate the block",
      ""
     ],
     [
      "Ctrl+A, then Ctrl+A again",
      "Select the block's text, then pick every block on the page",
      "In an empty block, the first Ctrl+A already picks every block."
     ],
     [
      "Ctrl+Home / Ctrl+End",
      "Jump to the page's first / last line of text",
      ""
     ],
     [
      "Ctrl+Enter",
      "Tick or untick a to-do, tick today on a habit, or fold/unfold a toggle (Pages)",
      "Folding also works on a locked page."
     ],
     [
      "Alt+Enter",
      "Add a new line below the whole list, toggle or callout you're in",
      "Pages only."
     ],
     [
      "Shift+Enter",
      "Add a new line inside the same block",
      ""
     ],
     [
      "Enter",
      "Start a new block. Enter at the very start of a line puts an empty block above it. On an empty list item, quote, habit or toggle, Enter ends the list. In code, Enter adds a new line, and Enter on an empty last line leaves the code block",
      "In Pages: an empty nested line steps out one level, Enter at the end of an open toggle or a callout starts a line inside it, and a quote ends with Enter. In a time slot: in the text, Enter adds a line to the slot. At the end, it goes to the next slot, or adds one an hour later. On an empty last slot, it ends the schedule."
     ],
     [
      "Type --- (or *** or ___) on a line, then Enter",
      "Turn the line into a divider",
      "Pages and Notebooks. This is also a Markdown-as-you-type item."
     ],
     [
      "Type ``` on a line, then Enter",
      "Turn the line into a code block",
      "Pages and Notebooks."
     ],
     [
      "Backspace at the start of a block",
      "Turn a list item, heading or other kind of block into plain text, take an indented line out one level, or join the line with the one above",
      "When a picture or divider is above, Backspace picks it first instead of deleting it."
     ],
     [
      "Delete at the end of a block",
      "Join the next block onto this one",
      "In Pages, a table, mind map, sketch, audio note, meeting, board or synced block below is picked first. Any other non-text block below (a picture, divider, page block, bookmark...) is removed at once, and Ctrl+Z brings it back. Unlike Backspace, it doesn't pick it first."
     ],
     [
      "↑ / ↓ on a block's first / last line",
      "Move into the block above / below. With Shift held, start picking whole blocks",
      ""
     ],
     [
      "← at the start / → at the end of a block",
      "Move into the previous / next block of text",
      ""
     ],
     [
      "Tab / Shift+Tab",
      "Indent / outdent the block. In a code block, Tab types two spaces instead",
      "In Pages, any block can be indented (it goes inside the one above). In Notebooks, list items and plain text lines can."
     ],
     [
      "Esc",
      "Deselect the selected text. If nothing is selected, pick the whole block",
      ""
     ],
     [
      "Ctrl+V or Shift+Insert / Ctrl+Shift+V",
      "Paste / paste as plain text",
      ""
     ],
     [
      "Ctrl+click a link",
      "Open the link",
      "In Pages, links to pages, #tags and @people open with a plain click."
     ],
     [
      "Ctrl+Shift+8",
      "Makes the line (or the picked blocks) a bulleted list; again, plain text.",
      "Pages and Notebooks."
     ],
     [
      "Ctrl+Shift+9",
      "Makes the line (or the picked blocks) a to-do list; again, plain text.",
      "Pages and Notebooks."
     ]
    ]
   },
   {
    "title": "Menus while typing",
    "rows": [
     [
      "In the / menu: ↑ / ↓, Enter or Tab, Esc",
      "Move through the choices, insert the chosen block, close the menu",
      "Pages only."
     ],
     [
      "In the @ (people and dates), [[ (pages), # (tags) and :name (emoji) menus: ↑ / ↓, Enter or Tab, Esc",
      "Move through the choices, insert the chosen one, close the menu",
      "Pages only."
     ]
    ]
   },
   {
    "title": "Picked blocks",
    "rows": [
     [
      "Shift+↑ / Shift+↓",
      "Pick more blocks / fewer blocks",
      "To pick blocks: Esc in a block, Shift+↑/↓ at a block's edge, Ctrl+A twice, or drag across blocks. Pages and Notebooks."
     ],
     [
      "↑ / ↓",
      "Pick the block above / below instead",
      ""
     ],
     [
      "Delete or Backspace",
      "Remove the picked blocks",
      ""
     ],
     [
      "Ctrl+C / Ctrl+X",
      "Copy / cut the picked blocks",
      "Ctrl+Shift+C copies them too. Ctrl+Shift+X strikes their words through; it doesn't cut."
     ],
     [
      "Ctrl+V / Ctrl+Shift+V or Shift+Insert",
      "Paste after the picked blocks / paste as plain text",
      "With blocks picked, Shift+Insert pastes as plain text. In text, it pastes normally."
     ],
     [
      "Ctrl+D",
      "Duplicate the picked blocks",
      ""
     ],
     [
      "Alt+Shift+↑ / ↓",
      "Move the picked blocks up / down",
      ""
     ],
     [
      "Tab / Shift+Tab",
      "Indent / outdent the picked blocks",
      ""
     ],
     [
      "Ctrl+B, Ctrl+I, Ctrl+U, Ctrl+Shift+H, Ctrl+\\, Ctrl+Shift+> / <",
      "Format every picked block at once",
      "Ctrl+E isn't handled on picked blocks. Code blocks in Pages are skipped."
     ],
     [
      "Ctrl+Alt+0-3, Ctrl+Shift+7 / 8 / 9",
      "Change what kind of block they are (text or heading; numbered, bulleted or checklist)",
      "Ctrl+Alt+4-8 are not handled here."
     ],
     [
      "Ctrl+A",
      "Pick every block",
      ""
     ],
     [
      "Ctrl+J",
      "Ask your agent about the picked blocks",
      "Pages only."
     ],
     [
      "Esc",
      "Go back to writing",
      ""
     ],
     [
      "Enter",
      "Write in the first picked block. If it's a picture, show it large",
      "In Pages, the picture opens in Uber Notebook's own viewer. In a notebook, it opens in its own app."
     ]
    ]
   },
   {
    "title": "Find",
    "rows": [
     [
      "Enter / Shift+Enter / Esc in the find bar",
      "Go to the next match / the previous match / close the find bar",
      "Pages and Notebooks (Ctrl+F opens it)."
     ],
     [
      "In page search (Ctrl+P): ↑ / ↓, Enter, Esc",
      "Move through the results, open the chosen one, close. Start with # to look for tags",
      "Pages only."
     ]
    ]
   },
   {
    "title": "Tables",
    "rows": [
     [
      "Tab / Shift+Tab",
      "Go to the next / previous cell. Tab in the last cell adds a row",
      "Pages only. No new row on a locked page."
     ],
     [
      "Enter / Shift+Enter",
      "Go down a row (past the last row, add a new one) / add a new line inside the cell",
      ""
     ],
     [
      "Arrow keys at a cell's edge",
      "Cross into the next cell. At the table's top or bottom, leave the table",
      ""
     ],
     [
      "Esc",
      "Pick the whole table",
      ""
     ],
     [
      "Ctrl+B, Ctrl+I, Ctrl+U, Ctrl+Shift+X, Ctrl+E, Ctrl+\\",
      "Format the selected words in a cell",
      "Needs words selected, and a page that isn't locked. Ctrl+Shift+H and Ctrl+K don't work in cells."
     ],
     [
      "Ctrl+V / Ctrl+Shift+V",
      "Paste / paste as plain text into a cell",
      ""
     ],
     [
      "Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y",
      "Undo / redo",
      ""
     ]
    ]
   },
   {
    "title": "Mind maps",
    "rows": [
     [
      "Enter / Tab / Shift+Tab / ↑ ↓",
      "Add the next idea / add an idea branching from this one / move the idea out a level / move between ideas",
      "While you write on an idea. Pages only. Enter on the main topic adds a branching idea."
     ],
     [
      "Backspace on an empty idea / Ctrl+Backspace or Ctrl+Delete",
      "Remove the idea / remove the idea and its whole branch",
      "Backspace only removes an idea with no ideas under it. The main topic can't be removed this way."
     ],
     [
      "Esc",
      "Stop editing the map and go back to writing after it",
      ""
     ]
    ]
   },
   {
    "title": "Sketches",
    "rows": [
     [
      "P / M / E",
      "Choose the pen / highlighter / eraser",
      "Only while drawing on a sketch. Pages only."
     ],
     [
      "Esc",
      "Stop drawing",
      ""
     ],
     [
      "Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y",
      "Undo / redo a stroke",
      ""
     ]
    ]
   },
   {
    "title": "Diagrams and equations, large",
    "rows": [
     [
      "+ or = / - / 0 / 1",
      "Zoom in / zoom out / fit it all in / show it at real size",
      "In the large view of a diagram or an equation."
     ],
     [
      "Arrow keys, Ctrl+scroll, Shift+scroll",
      "Move around / zoom around the pointer / scroll sideways",
      ""
     ],
     [
      "Ctrl+C / Ctrl+S",
      "Copy it as a picture / save it as a picture",
      ""
     ],
     [
      "Esc",
      "Close the large view",
      ""
     ]
    ]
   },
   {
    "title": "Pictures",
    "rows": [
     [
      "← or ↑ / → or ↓ / Home / End, or the scroll wheel",
      "Show the previous / next / first / last picture",
      "In the large picture view. Pages only. Previous and next wrap around."
     ],
     [
      "Esc or Space",
      "Close the large picture",
      ""
     ],
     [
      "Ctrl+C / Ctrl+S",
      "Copy the picture / save a copy",
      ""
     ],
     [
      "In the picture picker: Enter / Esc / Ctrl+A / Backspace / Shift+click",
      "Add the chosen pictures / cancel / choose all or none / go up a folder / choose a run of pictures",
      "Ctrl+A and Shift+click work only when several pictures can be picked (a gallery). Pages only."
     ]
    ]
   },
   {
    "title": "Audio notes",
    "rows": [
     [
      "Enter or Space / Esc",
      "Stop recording / throw the recording away",
      "Only while that note is recording. Pages only."
     ],
     [
      "Esc in the written-out text",
      "Keep your corrections and leave the text",
      ""
     ]
    ]
   },
   {
    "title": "Boards, galleries, bookmarks, meetings, people",
    "rows": [
     [
      "Board card: Enter / Shift+Enter / Esc",
      "Keep the card's text / add a new line / put it back as it was",
      ""
     ],
     [
      "Board column name: Enter / Esc",
      "Keep the name / put it back as it was",
      ""
     ],
     [
      "Gallery caption: Enter / Esc",
      "Keep the caption / stop editing without keeping the change",
      ""
     ],
     [
      "Bookmark link box: Enter / Esc",
      "Read the link's page and make the card / keep the bookmark as it was",
      "Esc only matters when you're changing an existing bookmark's link."
     ],
     [
      "Meeting speaker's name: Enter / Esc",
      "Name the speaker / close the box",
      ""
     ],
     [
      "Contact block's 'Who?' box: Enter / Esc",
      "Choose the first match from People, or add a new person with that name / stop choosing",
      "Pages only."
     ],
     [
      "Button setup box: Enter in its words",
      "Keep the button's words",
      "Closing the box keeps them too."
     ]
    ]
   },
   {
    "title": "Calendar",
    "rows": [
     [
      "← / →",
      "Go to the previous / next month (month and compact views), week (week view), or 30 days back or ahead (agenda)",
      "Calendar keys work when the calendar has the keyboard, not while you're typing in a box."
     ],
     [
      "T",
      "Go to today",
      ""
     ],
     [
      "M / W / A / C",
      "Show the month / week / agenda / compact view",
      ""
     ],
     [
      "N",
      "Add a new event (today, or the day shown or picked)",
      "Opens the quick add box."
     ],
     [
      "Ctrl+Z / Ctrl+Shift+Z",
      "Undo / redo a calendar change",
      "Ctrl+Y does not redo in the calendar."
     ],
     [
      "Quick add box: Enter / Esc",
      "Add the event / close the box",
      ""
     ],
     [
      "Event editor: Enter in a field, ↑ / ↓ in a time, Esc in the title or a time",
      "Keep what you typed; move the time 15 minutes earlier or later; close the list of times first, then the editor",
      ""
     ]
    ]
   },
   {
    "title": "People",
    "rows": [
     [
      "Ctrl+S or Ctrl+Enter / Esc in the form",
      "Save the person / cancel",
      "Ctrl+Enter is in the code too."
     ],
     [
      "Esc on someone's card",
      "Go back to the list",
      ""
     ],
     [
      "Arrow keys / Enter / Esc in the cards view",
      "Move from card to card / open the card you're on / stop moving through the cards",
      ""
     ],
     [
      "Enter / Esc in the search box",
      "Open the first match / clear the search",
      ""
     ]
    ]
   },
   {
    "title": "Popovers and panels",
    "rows": [
     [
      "Esc",
      "Close any popover or menu, Settings, Page history or What's new",
      ""
     ],
     [
      "Page history: ↑ / ↓ / Enter",
      "Move through the versions / restore the chosen one",
      "Doesn't restore on a locked page."
     ],
     [
      "Agent box: Enter / Esc",
      "Send your request to the agent / close the box",
      ""
     ],
     [
      "Agent panel reply: Enter / Esc",
      "Send your reply / clear what you typed",
      ""
     ],
     [
      "Templates search: Enter / Esc",
      "Make a new page from the first template found / clear the search",
      ""
     ],
     [
      "Library search: Esc",
      "Clear the search",
      ""
     ],
     [
      "Page picker: ↑ / ↓, Enter, Esc",
      "Choose a page (to link to, or to move something into), confirm it, close",
      ""
     ],
     [
      "Link box: Enter / Esc",
      "Apply the link (an empty box removes it) / close the box",
      ""
     ],
     [
      "Equation or footnote box: Enter / Esc",
      "Keep it / leave it as it was",
      ""
     ],
     [
      "Color picker: Enter / Esc",
      "Apply the color / cancel and put back the old color",
      ""
     ],
     [
      "Confirm dialog: Enter / Esc",
      "Confirm / cancel",
      ""
     ],
     [
      "Rename tag: Enter / Esc",
      "Rename the tag everywhere / close the box",
      ""
     ],
     [
      "Project due date: Enter / Esc",
      "Set the due date / close the box",
      ""
     ],
     [
      "New profile form: Enter / Esc",
      "Create the profile / cancel",
      "Esc only works when the form can be cancelled."
     ],
     [
      "Esc on the profile start screen",
      "Go back",
      "Only when the start screen was opened again, not on a first run. Every other key is ignored there."
     ],
     [
      "Settings, a profile's name: Enter / Esc",
      "Rename the profile / put the name back",
      ""
     ],
     [
      "Settings, a shortcut box or the Markdown copy folder: Enter",
      "Use what you typed",
      "Clicking out of the box does the same."
     ]
    ]
   },
   {
    "title": "Notebooks",
    "rows": [
     [
      "Ctrl+PgDown or Alt+→ / Ctrl+PgUp or Alt+←",
      "Turn to the next / previous page. Going past the last page adds a new one",
      "No new page is added while the last page is still blank."
     ],
     [
      "Ctrl+N",
      "Add a new page after this one",
      ""
     ],
     [
      "Ctrl+T",
      "Make a page from a template (in the picker: arrow keys, then Enter or Space; Esc closes)",
      "On a page that's still blank, the template goes on that page."
     ],
     [
      "Ctrl+F",
      "Find on this page",
      ""
     ],
     [
      "Ctrl+G",
      "See every page in the notebook",
      ""
     ],
     [
      "Ctrl+W",
      "Go back to the shelf",
      ""
     ],
     [
      "Ctrl+;",
      "Type today's date (for example 'Friday, 9 October 2026')",
      "Notebooks only, with the cursor in text. Pages has no Ctrl+;."
     ],
     [
      "Ctrl+Shift+D",
      "Turn drawing on or off",
      ""
     ],
     [
      "While drawing: P / M / E / Esc",
      "Choose the pen / highlighter / eraser / go back to writing",
      ""
     ],
     [
      "While drawing: Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y",
      "Undo / redo ink",
      ""
     ],
     [
      "Ctrl+Shift+N",
      "Make a new notebook",
      "Notebooks only (on the shelf or in an open notebook). Does nothing in Pages."
     ],
     [
      "Ctrl+= or Ctrl++ / Ctrl+- / Ctrl+0",
      "Make the notebook page bigger / smaller / reset its size",
      "Notebooks only. Goes from 60% to 200% in 10% steps. Does nothing in Pages."
     ],
     [
      "Time slot's time: Enter or Tab / Esc",
      "Keep the time / put it back as it was",
      ""
     ],
     [
      "Index tab box: Enter / Esc",
      "Apply the tab / close the box",
      ""
     ],
     [
      "Notebook dialog: Enter / Esc",
      "Create or save the notebook / close the dialog",
      ""
     ]
    ]
   },
   {
    "title": "Shelf",
    "rows": [
     [
      "Ctrl+F",
      "Search every notebook",
      "Only on the shelf. Ctrl+Shift+F does the same. The search box shows only when the window is wide enough."
     ],
     [
      "Enter / Esc in the shelf search",
      "Open the first result / clear the search",
      ""
     ],
     [
      "Esc",
      "Put Uber Notebook away (hide the window)",
      "Only on the shelf. Esc does not hide the window in Pages or in an open notebook."
     ]
    ]
   },
   {
    "title": "Quick note",
    "rows": [
     [
      "Ctrl+Enter, Ctrl+S or Esc",
      "Keep the note: it goes to the Pages Inbox or the Quick notes notebook, as set in Settings",
      "Esc keeps the note too; it doesn't throw it away. An empty note is just closed. Only the ✕ button throws a note away. Keeping it while you dictate cancels the dictation."
     ],
     [
      "Ctrl+Shift+D",
      "Start dictating. Press it again to stop, and the words go in at the cursor",
      "Needs ffmpeg and voxtype."
     ]
    ]
   }
  ]
 },
 {
  "id": "typing",
  "label": "Typing",
  "icon": "pen",
  "note": "Menus that open as you type, Markdown as you type, pasting and dropping.",
  "groups": [
   {
    "title": "Typing",
    "rows": [
     [
      "/",
      "Opens the block menu. Type to filter it. Pick with ↑/↓ and Enter or Tab, or click an item. Esc closes it and leaves the / as text.",
      "Pages only: in Notebooks the editor never checks for /. It opens at the start of a block or after a space or line break, so 'and/or' doesn't open it. It doesn't open in code blocks, table cells, board cards, mind maps or the page title. It closes on a space right after the /, on two spaces, on a space after nothing matched, past 30 characters, or when the cursor moves before the /. If nothing matches, it says 'Nothing like that."
     ],
     [
      "@",
      "Opens the menu for a person, a date or a reminder. What you type after the @ filters it. Pick with ↑/↓ and Enter or Tab, or click. Esc closes it and leaves the text as typed.",
      "Pages only, not in code blocks. It opens only at the start of a block or after a space, so an email address doesn't open it. It closes on a space right after the @, on two spaces, on a new line, or past 40 characters."
     ],
     [
      "@ then nothing",
      "Offers five things: today, tomorrow and next Monday as dates, then 'Remind me' tomorrow at 9 am and 'Remind me' in an hour. Each shows as its date, e.g. 'Fri 9 Oct'.",
      "No people are listed until you type something."
     ],
     [
      "@ then part of a name (e.g. @sam)",
      "Lists up to 5 matching people from People, above the dates. Picking one writes @Name as a link. Clicking the link opens their card.",
      "Pages only. A person also matches on their company, title, address, notes or email, or on 3 or more digits of a phone number."
     ],
     [
      "@ then a new name, then 'New contact “name”'",
      "Adds that person to People and links them in the line.",
      "Offered last in the list, for anything of 2 or more characters that starts with a letter, uses only letters, spaces and ' . -, and isn't exactly an existing name. So it also appears under words like @tomorrow, but not under @tomorrow 9am, because that has digits."
     ],
     [
      "@ then a date, then pick the date",
      "Writes the date in the line, e.g. '@Fri 9 Oct' or '@Fri 9 Oct 3:00 pm'. The year shows only when it isn't this year. The time follows your 12- or 24-hour clock setting.",
      "The date is only a marker: clicking it does nothing. For the phrases it understands, see 'Dates with @'."
     ],
     [
      "@ then a date, then pick 'Remind me …'",
      "Sets a reminder, written as '⏰ Fri 9 Oct 3:00 pm'. At that time (or 9 am that day if no time was given) an Omarchy notification shows the page's title and what the line says. Clicking it opens the page.",
      "It comes only while the Omarchy shell is running. One missed in the last 12 hours comes when the shell starts. With Settings 'Show what reminders say' off, it says only 'A reminder is due'. Deleting the date from the page cancels it. Dates in templates or in Trash are never reminders."
     ],
     [
      "[[",
      "Links to a page in the line. It lists up to 8 pages whose titles contain the words you typed, or the 8 most recently changed when nothing is typed, each with where it is. The link shows the page's icon and name, and a click opens the page.",
      "Pages only, not in code blocks. It works anywhere in a line. It never offers the page you're on, trashed pages or templates. It closes on ]], on two spaces, on a new line or past 40 characters."
     ],
     [
      "[[ then a new name, then 'New page “name”'",
      "Makes a top-level page with that name (at the top of Pages) and links to it.",
      ""
     ],
     [
      "#",
      "Opens the tag menu. With nothing typed it shows your 8 most-used tags, otherwise the matching ones, plus 'New tag #name'. A tag in the line opens, on a click, every block that has it.",
      "Pages only, not in code blocks. It opens at the start of a block or after a space or ( [ { \" ' “ ‘, so 'C#' doesn't open it. '# ' at the start of a line makes a heading instead. With no tags yet it says 'Type a tag: #idea, #project/uber-notebook'."
     ],
     [
      "#name then a space or . , ; : ! ? ) ] } or a quote",
      "Makes it a tag without picking from the menu. The character you typed after the name stays. #Idea and #idea are the same tag.",
      "A tag name uses letters, digits, _ - and /, as in #project/uber-notebook. It can be up to 60 characters, can't be only digits (#1 is not a tag), and can't start with / or -. Esc closes the menu and leaves plain text."
     ],
     [
      ": then 2 or more letters of an emoji name (e.g. :roc)",
      "Opens the emoji menu with up to 8 matches. Enter, Tab or a click inserts the one picked.",
      "Pages only, not in code blocks. It opens at the start of a block or after a space, bracket or quote, and only when something matches, so 10:30 and :) don't open it. It has 571 emoji, found by their GitHub/Slack names and extra keywords."
     ],
     [
      ":name: (e.g. :rocket:, :+1:, :tada:)",
      "Typing the full name and a closing colon inserts the emoji directly.",
      "If no emoji has exactly that name, the menu closes and the text stays as typed."
     ],
     [
      "an email address, then a space or Enter",
      "Turns it into a link. Ctrl+click opens your mail app. If the address belongs to someone in People, it links to them and a plain click opens their card.",
      "Pages only, not in code blocks. The address must contain a dot. Punctuation right after it is fine, but it converts only when a space, line break or Enter follows. Punctuation alone doesn't convert it. Web addresses typed in text never become links by themselves: use Ctrl+K."
     ],
     [
      "$$x^2$$",
      "Turns the LaTeX between the $$ into an equation inside the line. Click it to change it or remove it in a small box.",
      "Pages only, not in code blocks. /inline equation does the same."
     ],
     [
      "Enter at the end of a quote; Shift+Enter inside it",
      "In Pages, Enter at the end of a quote ends it, and the next line is plain text. Shift+Enter adds a new line inside the quote.",
      "In Notebooks, Enter carries the quote on to the next line, and Enter on an empty quote line ends it."
     ]
    ]
   },
   {
    "title": "Markdown as you type",
    "rows": [
     [
      "**bold**",
      "Becomes bold when you type the closing **. What you type next is not bold.",
      "Pages only, not in code blocks or while the / menu is open. There must be no space just inside the marks. Ctrl+Z right after brings the asterisks back. __bold__ and _italic_ are not converted as you type. They are converted only in pasted Markdown."
     ],
     [
      "*italic*",
      "Becomes italic when you type the closing *.",
      "Pages only. There must be no space just inside the marks. So 2*3*4 typed in a line italicizes the 3: Ctrl+Z brings the asterisks back."
     ],
     [
      "`code`",
      "Becomes inline code when you type the closing backtick.",
      "Pages only. Spaces inside are allowed."
     ],
     [
      "~~struck~~",
      "Becomes strikethrough when you type the closing ~~.",
      "Pages only. There must be no space just inside the marks."
     ],
     [
      "# (then a space, at the start of a line)",
      "Heading 1 (called Title in Notebooks).",
      "Works in Pages and Notebooks, only at the start of a plain text block (not inside a heading, quote or code block). Ctrl+Z right after brings back what you typed."
     ],
     [
      "## (then a space)",
      "Heading 2 (called Heading in Notebooks).",
      ""
     ],
     [
      "### (then a space)",
      "Heading 3 (called Subheading in Notebooks).",
      ""
     ],
     [
      "- (or *, +, •) then a space",
      "Bulleted list.",
      "Any list marker (- , 1. , [] ) typed at the start of a list item of another kind switches that item to the new kind."
     ],
     [
      "1. (or 1) ) then a space",
      "Numbered list.",
      "Any number of 1 to 3 digits works, but the list numbers itself: typing 5. doesn't start it at 5. '."
     ],
     [
      "[] or [ ] then a space; [x] then a space",
      "A to-do. [x] makes it already ticked.",
      ""
     ],
     [
      "> (then a space)",
      "In Pages, a toggle list. In Notebooks, a quote.",
      ""
     ],
     [
      "\" (a double quote, then a space)",
      "Quote, in Pages and Notebooks.",
      ""
     ],
     [
      "!! (then a space)",
      "A callout in Pages, a sticky note in Notebooks.",
      ""
     ],
     [
      "``` then a space, or ``` then Enter",
      "Code block.",
      "You can't type a language after the ``` (```js then a space stays text). Pick the language on the block."
     ],
     [
      "--- (or *** or ___, 3 or more) then Enter",
      "Divider.",
      "Only in a plain text block."
     ],
     [
      "9:30 (then a space)",
      "A time slot at that time (shown as 09:30).",
      "Notebooks only, and on the 24-hour clock (0:00 to 23:59). In Pages a time typed at the start of a line stays plain text."
     ],
     [
      "Enter at the end of a time slot (Notebooks)",
      "Starts the next slot an hour on, or the same step as between the last two slots (up to 3 hours). Enter on an empty slot ends the schedule. Enter in the middle of a slot's text adds a new line in that slot.",
      "Notebooks only."
     ]
    ]
   },
   {
    "title": "Pasting",
    "rows": [
     [
      "Ctrl+V (or Shift+Insert)",
      "Pastes. Formatted text from a web page or another app keeps bold, italic, underline, strikethrough, superscript, subscript, web and email links, and line breaks. Its lists, headings and code blocks become those blocks. Fonts, sizes, colors and pictures are dropped, and nothing in it is fetched.",
      "Whole blocks copied with Esc, Ctrl+C keep them. The clipboard is read up to 4 MB. Text you copied in the same editor keeps its colors, fonts and sizes."
     ],
     [
      "Paste one line, or several lines",
      "One line goes in at the cursor. Several lines split the block: each line of plain text, or each paragraph of formatted text, becomes its own block, and bulleted, numbered, to-do, heading and code kinds are kept.",
      ""
     ],
     [
      "Paste Markdown",
      "Becomes blocks: # headings, - * + and 1. lists, - [ ] and - [x] to-dos, > quotes, > [!NOTE] callouts, ``` code with its language, tables, --- dividers, $$ equations and <details> toggles. Inside lines: **bold**, *italic*, ~~struck~~, ==highlight==, `code`, $math$, [links](…), bare web addresses, footnotes and #tags.",
      "Pages only. It applies when what's pasted has no lists, headings or code in its own formatting (plain text, or formatted text that's only paragraphs) and looks like Markdown. A single line counts only if it has **, __, ` or [text](link). Pictures in it aren't downloaded."
     ],
     [
      "Paste Markdown with a ```board, ```mindmap or ```agenda block",
      "Becomes a board (## Column, then - card lines), a mind map (an indented outline) or a day's agenda (a date, 'today', or nothing).",
      "Pages only. This is the format agents write. ```gallery (pictures already in Pages/assets) and ```bookmark are read too. ```event and ```link by title are not, when pasted."
     ],
     [
      "Paste cells copied from a spreadsheet",
      "Becomes a table with a header row.",
      "Pages only. As plain text, it needs tab-separated cells: 2 or more rows of 2 or more columns, or one row of 3 or more. It keeps up to 500 rows and 30 columns."
     ],
     [
      "Paste a table copied from a web page",
      "Becomes a table block.",
      "Pages only."
     ],
     [
      "Paste a picture (a screenshot, or an image copied in another app)",
      "The picture is saved into the notes folder's assets and goes on the page as a picture block after the block you're in.",
      "PNG, JPEG, WebP or GIF, up to 50 MB. Only when the clipboard has no text. Works in Notebooks too."
     ],
     [
      "Paste text that contains email addresses",
      "The addresses become links, to the person when they're in People.",
      "Pages only, not in code blocks."
     ],
     [
      "Paste into a code block",
      "The text goes in exactly as copied, every line, with no formatting.",
      "Pages only."
     ],
     [
      "Ctrl+Shift+V",
      "Pastes as plain text. Every block becomes plain text, and code stays code.",
      "In Pages, Markdown is read before the formatting is removed, so '**bold**' pastes as 'bold' and '# Title' as 'Title'. Check this before writing it into Help."
     ],
     [
      "Middle-click in text",
      "Pastes what's selected anywhere on screen where you click, cleaned the same way as Ctrl+V. It never pastes a picture.",
      "Works in table cells too. Not on a locked page."
     ],
     [
      "Esc to pick blocks, then Ctrl+V",
      "Pastes after the picked blocks, and leaves the pasted blocks picked.",
      "With blocks picked, Ctrl+Shift+V and Shift+Insert paste as plain text, every block a plain paragraph. A table becomes an empty paragraph. In text, Shift+Insert is a normal paste."
     ],
     [
      "Copy blocks (Esc, then Ctrl+C), then Ctrl+V",
      "The blocks come back exactly as they were: tables, boards, mind maps, colors, links and all.",
      "Only while the clipboard still holds what was copied."
     ],
     [
      "Ctrl+V of several lines into a page's title",
      "The first line becomes the title, without a leading #. The rest goes at the top of the page, read as Markdown if it looks like Markdown.",
      "Pages only. Shift+Insert and Ctrl+Shift+V do the same. A single line pastes normally. So a multi-line paste into a locked page's title may add blocks to it."
     ],
     [
      "Paste cells into a table cell (Ctrl+V or Ctrl+Shift+V)",
      "Tab-separated cells, or a copied table, fill the table from that cell, and the table grows to fit them (up to 500 rows, 30 columns). Anything else goes in at the cursor.",
      ""
     ],
     [
      "/bookmark, then paste a link into its field and press Enter",
      "Reads the page once and shows it as a card with its title, a line about it, the site and its picture.",
      "Only http/https links (www. gets https://). A web address pasted on its own into ordinary text stays plain text: it becomes neither a bookmark nor a link. Links inside copied formatted text stay links. Use Ctrl+K to make a link."
     ]
    ]
   },
   {
    "title": "Drag and drop",
    "rows": [
     [
      "Drop pictures on a page",
      "They go in as picture blocks after the block you're in.",
      "Pages. It accepts png, jpg, jpeg, gif, webp, bmp and svg, among the first 12 dropped items. So a picture dropped on a locked page may be added."
     ],
     [
      "Drop pictures on a gallery block",
      "They are added to the end of that gallery.",
      "Up to 100 pictures. Not on a locked page. There, they fall through to the page drop above."
     ],
     [
      "Drop an .eml file on a page",
      "Makes an email block showing who it's from, the subject and the message. The file is kept in Pages/assets.",
      "Among the first 12 dropped items, up to 64 MB each. Not on a locked page. An empty line you're on is replaced by the block."
     ],
     [
      "Drop a .vcf or .vcard file on a page",
      "Its people go into People, a message says how many, and People opens at the first new one.",
      "Nothing goes on the page. A .csv of contacts imports only when dropped on People. Dropped on a page, a .csv becomes a file block."
     ],
     [
      "Drop a .vcf, .vcard or .csv on People",
      "Imports the contacts into People.",
      "Up to 10 files at once."
     ],
     [
      "Drop an .ics (or .ical, .ifb, .vcs) on a page",
      "Shows its events, with 'Add to calendar' ('Add the N new' when some are already on the calendar).",
      "Reads up to 16 MB. Nothing goes on the page itself."
     ],
     [
      "Drop notes files on a page (.md, .markdown, .txt, .log, .html, .htm, .enex, .docx, .doc, .odt, .rtf, .epub, .org, .rst, .tex, .ipynb, .zip…)",
      "Each file is imported as a page inside the page you're on. A message says how many were imported, and the first imported page opens.",
      "Word and other office formats need pandoc or LibreOffice. Any .zip is unpacked as notes, never kept as a file. The drop reads the first 100 items. This path doesn't check the page lock."
     ],
     [
      "Drop a video on a page (.mp4, .m4v, .mov, .webm, .mkv, .avi, .ogv)",
      "Makes a video block. The file is copied into Pages/assets.",
      "Among the first 12 dropped items. Not on a locked page."
     ],
     [
      "Drop any other file on a page (PDF, spreadsheet, slides, audio, an archive other than .zip…)",
      "Makes a file block, copied into Pages/assets. A PDF shows page by page.",
      "Among the first 12 dropped items, only a regular file, up to 8 GB. Not on a locked page. Only files are accepted; dragged text is not. An audio file becomes a file block, not an audio note."
     ],
     [
      "Drop pictures on a notebook page",
      "They go in as pictures after the block you're in.",
      "Notebooks only. png, jpg, jpeg, gif, webp, bmp or svg, among the first 12 dropped items; other files are ignored. Turned off when the page is read-only."
     ]
    ]
   }
  ]
 },
 {
  "id": "blocks",
  "label": "Blocks",
  "icon": "newPage",
  "note": "The / menu, and what you can do with any block.",
  "groups": [
   {
    "title": "The / menu",
    "rows": [
     [
      "/agent (also /ask, /ai, /claude, /codex, /help, /write)",
      "Ask agent: “Your default coding agent does it”. Opens the agent box for this line if it's empty, or for this block if it has text.",
      "Typing /age lists Ask agent before Agenda."
     ],
     [
      "/text (also /p, /paragraph, /plain)",
      "Text: “Just start writing”.",
      "The same for every text kind (Text, headings, lists, to-do, toggles, quote, callout, code, equation, diagrams): an empty block turns into that kind. In a block with text, a new block of that kind goes below it. /plain also lists Default (no color)."
     ],
     [
      "/heading 1 (also /h1, /title, /#)",
      "Heading 1: “Big section heading”.",
      "/# also lists Heading 2 and Heading 3 after it."
     ],
     [
      "/heading 2 (also /h2, /subtitle, /##)",
      "Heading 2: “Medium section heading”.",
      ""
     ],
     [
      "/heading 3 (also /h3, /###)",
      "Heading 3: “Small section heading”.",
      ""
     ],
     [
      "/bulleted list (also /bullet, /ul, /unordered, /-)",
      "Bulleted list: “A simple bulleted list”.",
      "/- also lists Divider."
     ],
     [
      "/numbered list (also /number, /ol, /ordered, /1.)",
      "Numbered list: “A list with numbers”.",
      ""
     ],
     [
      "/to-do list (also /check, /todo, /task, /checkbox, /[])",
      "To-do list: “Track tasks with a to-do list”.",
      "/todo also lists Board, after the to-do list."
     ],
     [
      "/toggle list (also /toggle, /collapse, /fold, /details, />)",
      "Toggle list: “Hide what's inside, show it with a click”.",
      "/toggle and /collapse also list the three toggle headings after it."
     ],
     [
      "/toggle heading 1 (also /th1)",
      "Toggle heading 1: “A big heading that folds”.",
      ""
     ],
     [
      "/toggle heading 2 (also /th2)",
      "Toggle heading 2: “A medium heading that folds”.",
      ""
     ],
     [
      "/toggle heading 3 (also /th3)",
      "Toggle heading 3: “A small heading that folds”.",
      ""
     ],
     [
      "/quote (also /blockquote, /citation, /\")",
      "Quote: “Capture a quote”.",
      ""
     ],
     [
      "/callout (also /note, /info, /tip, /warning, /aside)",
      "Callout: “Make writing stand out”. It starts with a 💡 icon.",
      ""
     ],
     [
      "/divider (also /line, /separator, /hr, /rule, /---)",
      "Divider: “Visually divide blocks”.",
      ""
     ],
     [
      "/code (also /snippet, /pre, /```)",
      "Code: “Capture a code snippet”.",
      ""
     ],
     [
      "/table (also /grid, /rows, /cells, /spreadsheet)",
      "Table: “Rows and columns, with a header row”. It's 3 × 3, and the cursor goes into its first cell.",
      "/columns lists Table first, before the column layouts."
     ],
     [
      "/sketch (also /draw, /pen, /doodle, /whiteboard, /handwriting)",
      "Sketch: “Draw with a pen and a highlighter”. Drawing starts at once.",
      ""
     ],
     [
      "/agenda (also /schedule)",
      "Agenda: “A day's events from the calendar (today, or a day)”.",
      "The keyword '/today's events' in the old list doesn't exist. /today lists Today first, then Agenda."
     ],
     [
      "/event (also /appointment)",
      "Event: “Put something on the calendar, and here”. Opens quick add for today. The event goes on the calendar, and an event block goes where the / was.",
      "/meeting lists the Meeting recorder first, and /schedule lists Agenda first, so those don't reach Event with Enter."
     ],
     [
      "/habit (also /tracker, /streak, /routine)",
      "Habit: “A habit, with a circle for each day of the week”.",
      ""
     ],
     [
      "/calendar (also /month, /planner)",
      "Calendar: “A month at a glance: click a date to circle it”.",
      ""
     ],
     [
      "/page (also /subpage, /new)",
      "Page: “A page inside this page”. It makes the page and opens it with the cursor in its title.",
      "/page also lists Link to page after it."
     ],
     [
      "/template (also /boilerplate, /preset)",
      "Template: “One of your templates, put in here”. Opens the template picker.",
      ""
     ],
     [
      "/link to page (also /link, /mention, /goto)",
      "Link to page: “Point to a page elsewhere”. Opens a page picker.",
      "To link a page inside a line of text, use [[ instead."
     ],
     [
      "/image (also /picture, /photo, /png, /jpg)",
      "Image: “A picture from a file”. Opens the picture picker, with the desktop's file dialog one click away.",
      ""
     ],
     [
      "/gallery (also /pictures, /photos, /album, /collage)",
      "Gallery: “Pictures side by side in a grid”. Opens the picker so you can choose several.",
      ""
     ],
     [
      "/file (also /attachment, /attach, /upload)",
      "File: “Any file: a PDF shows page by page”. Opens the file picker, and the file is copied into Pages/assets.",
      ""
     ],
     [
      "/pdf",
      "PDF: “A PDF, shown page by page”. Opens the file picker for PDFs.",
      ""
     ],
     [
      "/video (also /movie, /clip, /mp4, /mov, /webm)",
      "Video: “A video file, played here”. Opens the file picker for videos.",
      ""
     ],
     [
      "/email (also /mail, /eml)",
      "Email: “An email (.eml): who it's from, the subject, the message”. Opens the picker for a .eml file.",
      ""
     ],
     [
      "/web bookmark (also /bookmark, /url, /embed)",
      "Web bookmark: “A link as a card: its title, a line, its picture”. Puts the cursor in its link field: paste a link and press Enter.",
      "The page is read once, when the link is added."
     ],
     [
      "/audio note (also /audio, /voice, /record, /mic)",
      "Audio note: “Record your voice; it's written out under it”. Recording starts at once.",
      "Writing it out needs voxtype."
     ],
     [
      "/meeting (also /call, /zoom, /interview, /minutes)",
      "Meeting: “Record a meeting; voxtype writes out who said what”. Recording starts at once.",
      "Needs voxtype."
     ],
     [
      "/dictate (also /dictation, /speak, /speech)",
      "Dictate: “Say it, and it's written here (Ctrl+Shift+D)”.",
      "Needs voxtype. /voice lists Audio note first, so it isn't a way to reach Dictate with Enter."
     ],
     [
      "/contact (also /person, /people, /vcard)",
      "Contact: “Someone's card from People: their numbers and emails”. Puts the cursor in the field for picking the person.",
      ""
     ],
     [
      "/board (also /kanban, /trello)",
      "Board: “Cards in columns: to do, doing, done”.",
      ""
     ],
     [
      "/button (also /automation)",
      "Button: “A click puts in a template”. Opens its setup.",
      ""
     ],
     [
      "/synced block (also /synced, /mirror, /transclude)",
      "Synced block: “The same blocks in many places: changed in one, changed in all”. Opens a picker: 'A new synced block', or one that already exists.",
      ""
     ],
     [
      "/mind map (also /mindmap, /brainstorm)",
      "Mind map: “Ideas branching out from one topic”. It starts with 'Central topic' and three 'Main idea's, with the cursor on the topic.",
      ""
     ],
     [
      "/table of contents (also /toc, /contents, /outline)",
      "Table of contents: “The headings on this page”.",
      ""
     ],
     [
      "/equation (also /math, /latex, /formula)",
      "Equation: “Math in LaTeX, drawn on a line of its own”. It's a code block set to Math.",
      "/math also lists Inline equation, after it."
     ],
     [
      "/diagram (also /flowchart, /mermaid)",
      "Diagram: “Boxes and arrows, written in Mermaid and drawn”. It starts with a small example.",
      ""
     ],
     [
      "/decision tree (also /troubleshooting, /runbook)",
      "Decision tree: “Questions, yes or no, and where each answer goes” (Mermaid, with a starter).",
      ""
     ],
     [
      "/network diagram (also /topology, /router, /firewall)",
      "Network diagram: “Devices, and how they're connected” (Mermaid, with a starter).",
      ""
     ],
     [
      "/system diagram (also /architecture, /services, /database)",
      "System diagram: “Services, databases, and what talks to what” (Mermaid, with a starter).",
      ""
     ],
     [
      "/2 columns, /3 columns, /4 columns, /5 columns (also /cols2, /cols3, /cols4, /cols5, /split, /layout)",
      "Two, three, four or five empty columns side by side. They go after the block, or replace it if it's an empty top-level line. The cursor goes into the first column.",
      "/columns lists Table first."
     ],
     [
      "/today (also /now, /time)",
      "Today: “Today's date”. Inserts the date as plain text, e.g. '9 October 2026'.",
      "/date lists Calendar before Today. Ctrl+; inserts the date only in Notebooks, and there it includes the weekday. For a date marker in Pages, use @today."
     ],
     [
      "/inline equation (also /inlinemath, /inline)",
      "Inline equation: “Math in the line, in LaTeX (or type $$x^2$$)”. Opens a small box to write it in.",
      ""
     ],
     [
      "/footnote (also /cite, /source, /endnote)",
      "Footnote: “A numbered note, listed at the end of the page”. Opens a small box for its words. The number goes right after the word before the /.",
      "/citation lists Quote first, /note lists Callout first, and /reference lists Link to page first."
     ],
     [
      "/red, /blue, /green… (Gray, Brown, Orange, Yellow, Green, Blue, Purple, Pink, Red)",
      "Colors the whole block's text (the hint says e.g. “Red text”).",
      "Color items appear only after you type something after the /. A bare / lists only blocks. /color lists every color."
     ],
     [
      "/red background, /blue background… (also /background, /highlight)",
      "Gives the whole block a colored background (the hint says e.g. “A red background”).",
      ""
     ],
     [
      "/default",
      "Default: “No color”. Removes the block's color.",
      "/plain lists Text first, then Default."
     ]
    ]
   },
   {
    "title": "Blocks",
    "rows": [
     [
      "Hover a block, click + beside it",
      "Adds a new block below with the / menu open",
      "On an empty text block, the menu opens in that block."
     ],
     [
      "Drag ⋮⋮ beside a block",
      "Moves the block (and everything inside it) anywhere. Drop it along the right side of another block to put the two in columns (up to six)",
      ""
     ],
     [
      "Drag the line between two columns",
      "Changes how the width is shared between the columns",
      "Not on a locked page"
     ],
     [
      "Click ⋮⋮ beside a block",
      "Opens the block menu (for all selected blocks when several are selected)",
      ""
     ],
     [
      "⋮⋮ → Ask agent",
      "Asks your agent about this block (or the selected blocks)",
      ""
     ],
     [
      "⋮⋮ → Turn into ›",
      "Changes the block to Text, Heading 1–3, Bulleted list, Numbered list, To-do list, Toggle list, Toggle heading 1–3, Quote, Callout, Code or Habit",
      "Text blocks only."
     ],
     [
      "⋮⋮ → Color ›",
      "Sets a text color or a background: one of Pages' nine colors, a recent one, or Custom… (a color picker that shows how readable the text is; Apply or Cancel)",
      ""
     ],
     [
      "⋮⋮ → Turn into page",
      "The block's text becomes the title of a new page inside this one, and what's inside the block goes with it",
      ""
     ],
     [
      "⋮⋮ → Turn into mind map",
      "Makes the list a mind map: the top item becomes the topic and the items inside it become the ideas",
      "Not on a locked page."
     ],
     [
      "⋮⋮ → Turn into list (on a mind map)",
      "Makes the mind map a nested list again",
      ""
     ],
     [
      "⋮⋮ → Turn into a synced block",
      "Moves the blocks to a page of their own and shows them here. Copy the synced block to show the same blocks on other pages",
      "Not on a page block or a synced block, and not on a locked page."
     ],
     [
      "⋮⋮ → Duplicate (Ctrl+D)",
      "Copies the block(s) right after the original",
      ""
     ],
     [
      "⋮⋮ → Move to…",
      "Moves the block(s) to the end of another page",
      ""
     ],
     [
      "⋮⋮ → Delete (Del)",
      "Deletes the block(s) and everything inside them",
      ""
     ],
     [
      "Select words on a page",
      "A toolbar appears: Ask, Turn into, Bold, Italic, Underline, Strikethrough, Code, Link, Color",
      "Not in code blocks or on a locked page"
     ],
     [
      "Click a link in a line",
      "A link to a page, a tag or a person opens with a plain click. A web link opens with Ctrl+click",
      ""
     ],
     [
      "Click an inline equation or a footnote in a line",
      "Edit it in a small box: Enter or Done keeps the change, Esc cancels, Remove takes it out of the line",
      ""
     ],
     [
      "Click a toggle's arrow",
      "Folds or unfolds what's inside the toggle (or toggle heading)",
      ""
     ],
     [
      "Click a callout's emoji",
      "Pick another emoji for it",
      ""
     ],
     [
      "Click a code block's language",
      "Picks its language (Bash to Zig, plus Math and Mermaid). The code is colored to match",
      ""
     ],
     [
      "Hover a code block: Copy",
      "Copies the code",
      ""
     ],
     [
      "Hover a diagram or equation: Copy as a picture / Save as a picture…, or its expand button",
      "Copies it, or saves it as a PNG. Expand opens it large so you can zoom: Ctrl+scroll, + and −, 0 to fit, 1 for real size, Esc to close. Ctrl+C and Ctrl+S work there too. Clicking the drawing shows its source again for editing",
      ""
     ],
     [
      "/equation, /diagram, /decision tree, /network diagram, /system diagram",
      "Adds a Math (LaTeX) or Mermaid code block, drawn below what you write",
      ""
     ],
     [
      "/inline equation, /footnote, /today",
      "Adds an equation in the line, a numbered footnote listed at the page's end, or today's date",
      ""
     ],
     [
      "/2 columns … /5 columns",
      "Adds columns side by side",
      ""
     ],
     [
      "/page",
      "Makes a new page inside this one where you typed / and opens it. Click a page block to open it",
      ""
     ],
     [
      "/link (Link to page)",
      "Pick a page to link to. Click the link block to open that page",
      ""
     ],
     [
      "/toc (Table of contents)",
      "Lists the page's headings. Click one to jump to it",
      ""
     ],
     [
      "/ and a color name (e.g. /red, /red background)",
      "Colors the block's text or background",
      ""
     ],
     [
      "Click a picture on a page",
      "Its toolbar: Left, Centered, Right, See it large, Copy, Save a copy…, Remove",
      "Not on a locked page"
     ],
     [
      "Drag a picture's corner or side handles",
      "Resizes it, keeping its shape. Double-click a side handle to make it the page's width",
      ""
     ],
     [
      "Double-click a picture",
      "Shows it large: ← → go to the page's other pictures, Esc or a click outside closes it. Copy (Ctrl+C), Save a copy (Ctrl+S), Open in its app",
      ""
     ],
     [
      "/image",
      "Adds a picture from Uber Notebook's picture picker (Pictures, Downloads, Desktop, Home) or 'The file dialog…'",
      ""
     ],
     [
      "Link-to-page block: 'Change' (hover) or 'Link to a page'",
      "Points the link at another page. A link whose page no longer exists offers 'Link to a page'",
      ""
     ],
     [
      "/table (or paste spreadsheet cells or a Markdown table)",
      "A table with a header row. Tab / Shift+Tab move between cells (Tab in the last cell adds a row), Enter goes down, Shift+Enter starts a new line in the cell, Esc selects the whole table",
      ""
     ],
     [
      "Table: handle at a row's left or a column's top",
      "Row menu: Insert row above/below, Move up/down. Column menu: Insert column left/right, Move left/right. Both: Color ›, Header row on/off, Delete",
      ""
     ],
     [
      "Table: + bars along the bottom and right; drag the lines between columns",
      "Adds a row or a column. Dragging a line makes columns wider or narrower",
      ""
     ],
     [
      "Table: color button on the cell you're in",
      "Sets the cell's text color and background (Pages' colors or Custom…)",
      ""
     ],
     [
      "/board",
      "Cards in columns (To do, Doing, Done to start). Click a card to write on it (Enter keeps the text, Esc cancels). Drag a card to another place or column",
      ""
     ],
     [
      "Board card: ⋯ or right-click",
      "Color…, Open as page (the card becomes a page inside this one; afterwards it reads Open page), Rename, Delete",
      ""
     ],
     [
      "Board column: ⋯ or right-click",
      "Rename, Color…, Move left, Move right, Delete the column",
      "The last column can't be deleted. Clicking a column's name also renames it."
     ],
     [
      "Board: 'New' under a column, + for another column, drag a column's right edge or the board's bottom edge, palette at its corner",
      "Adds a card or a column, resizes (double-click an edge to reset), or colors the whole board",
      ""
     ],
     [
      "/mindmap, then click an idea",
      "Write on ideas: Enter adds the next idea, Tab adds a branch, Shift+Tab moves out a level, ↑ ↓ move between ideas, Backspace on an empty idea removes it, Ctrl+Backspace removes an idea and its branch, Esc stops. The circle at an idea's end folds its branch. The color button colors the idea",
      "On a locked page a map can only be folded"
     ],
     [
      "/sketch, then click it",
      "Draw with the pen or highlighter (P, M), or erase whole strokes (E). Choose a color, one of three nib sizes, and plain, dotted or grid paper. Undo, Redo, and clear the sketch. Esc or Done stops drawing. Drag the bottom edge to resize",
      ""
     ],
     [
      "/gallery",
      "Pictures 2, 3 or 4 to a row (set with the numbers at its corner). Add pictures, or drop them on it. Hover a picture to move it earlier or later, add a caption, or remove it. Drag the bottom edge to change the size (double-click resets). Click a picture to see it large",
      ""
     ],
     [
      "/file or /pdf (or drop a file on the page)",
      "Copies the file into Pages/assets. Open opens it in its app. A PDF also shows its pages (Show pages / Hide pages) in a frame you can resize",
      "Clicking an .ics or .vcf file block adds its events or people instead. A file that only a web browser could open isn't handed to the browser."
     ],
     [
      "/video (or drop a video)",
      "Plays on the page: play/pause, seek bar, time, sound on/off. Open plays it in your video player",
      ""
     ],
     [
      "/email (or drop an .eml)",
      "An email card: subject, from, to, date, first lines, attachments. Show email shows the full message (no scripts or web pictures). Click an attachment to open it. ↗ opens the .eml in your mail app",
      "An .ics attachment shows its events to add; a .vcf attachment adds its people to People, with Undo."
     ],
     [
      "/bookmark, then paste a link",
      "A link card (title, a line about it, site, picture), fetched once when added. Click it to open the link. Tools: Change the link, Get the page again, Copy the link, colors",
      ""
     ],
     [
      "/contact",
      "Someone's card from People (type to find them, or create them). Click a number or email to copy it; the mail button writes to them. Tools: Open in People, Someone else, colors",
      ""
     ],
     [
      "/button",
      "A button that inserts a template right after it ('Puts it in, here') or makes a new page from it inside this page ('Makes a page inside'). The template can be one of yours or a built-in one. The gear opens its setup again",
      ""
     ],
     [
      "/synced",
      "Adds a new synced block, or one you already have. On it, Edit changes its blocks everywhere it appears and Unsync turns them into this page's own blocks",
      ""
     ],
     [
      "/agenda, /event",
      "Agenda: a day's events (‹ › for other days, Today to come back; + adds an event; click one to open it). Event: puts an event on the calendar and on the page; click it to open the event",
      ""
     ],
     [
      "/habit, /calendar",
      "Habit: a circle for each day of the week; click a circle to tick that day. Calendar: a month; click a date to circle it, and ‹ › change the month",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "dates",
  "label": "Dates and reminders",
  "icon": "calendarMonth",
  "note": "@ and a date or a time; reminders and when they come.",
  "groups": [
   {
    "title": "Dates with @",
    "rows": [
     [
      "@today, @tod, @tomorrow, @tmr, @tmrw, @yesterday",
      "That day, with no time.",
      "A time can follow, e.g. @tomorrow 9am."
     ],
     [
      "@tonight",
      "Today at 8 pm.",
      "A time after it replaces 8 pm, e.g. @tonight 10pm."
     ],
     [
      "@in 10 min, @in 30 minutes, @in 2 hours, @in 1 hr, @in 2 h",
      "That exact time from now.",
      "Units: min, mins, minute, minutes, h, hr, hrs, hour, hours. The number has 1 to 3 digits and a space after it. '@in 10min' and '@in an hour' are not understood."
     ],
     [
      "@in 3 days, @in 2 weeks, @in 1 month",
      "That day, with no time.",
      "A time can follow, e.g. @in 3 days 9am."
     ],
     [
      "@fri, @friday, @thurs, @this fri",
      "The next day with that name, or today if today is that day.",
      "Short names: sun, mon, tue/tues, wed/weds, thu/thur/thurs, fri, sat."
     ],
     [
      "@next fri, @next monday",
      "The next day with that name, or a week from today if today is that day.",
      "On a Wednesday, @next fri is the Friday two days later, not the one after."
     ],
     [
      "@next week, @next month",
      "Next week means next Monday. Next month means the 1st of next month.",
      "'this week', 'next weekend' and 'end of month' are not understood."
     ],
     [
      "@oct 12, @12 oct, @october 12, @oct 12th, @oct 12, 2027",
      "That date. If no year is given and the date has already passed this year, it means next year.",
      "A month name needs at least its first 3 letters (jan, sept, octo…). '1st of oct', '10/12' and a month alone are not understood. '12.10' is read as a time (12:10), not a date."
     ],
     [
      "@2026-12-24, @2026-12-24T09:30",
      "An ISO date, optionally with a time.",
      "@2026-12-24 09:30 (with a space) also works."
     ],
     [
      "@3pm, @9:30, @15:00, @noon, @midnight",
      "A time alone means today at that time, or tomorrow if that time has already passed today.",
      ""
     ],
     [
      "@tomorrow 9am, @fri 3pm, @oct 12 2pm, @fri at noon, @today at 5, @in 3 days 9am",
      "A date followed by a time. 'at' between them is optional.",
      "If today is Friday and 3 pm has passed, @fri 3pm means next Friday. The time must come after the date: '@9am tomorrow' and '@at 5pm' are not understood."
     ],
     [
      "Times: 9, 9am, 9a, 9 am, 9:30, 9.30pm, 21:00, 03, noon, midnight",
      "The time formats the @ menu reads.",
      "A bare 1 to 6 with no am/pm means afternoon (3 is 3 pm). With minutes, 3:30 means 3:30 pm on the 12-hour clock and 03:30 on the 24-hour clock (Settings). A leading zero (03) means morning. When nothing in the menu matches (e.g. one letter, or a number that isn't a time), the menu says: Try “tomorrow 9am”, “fri”, “in 2 hours”, “oct 3”."
     ]
    ]
   }
  ]
 },
 {
  "id": "pages",
  "label": "Pages",
  "icon": "pages",
  "note": "Pages, their menu, history, templates, projects, tags and the Library.",
  "groups": [
   {
    "title": "Pages",
    "rows": [
     [
      "Back / Forward buttons at the top left, or Alt+← / Alt+→",
      "Goes to the previous or next page or view",
      ""
     ],
     [
      "Click a name in the path at the top",
      "Opens that page (one of the pages this page is inside)",
      ""
     ],
     [
      "'Edited …' at the top right",
      "Shows when the page was last changed",
      ""
     ],
     [
      "Star at the top right of a page",
      "Adds the page to Favorites, or takes it out",
      ""
     ],
     [
      "'Locked' button at the top of a locked page",
      "Unlocks the page",
      "Only shown while the page is locked"
     ],
     [
      "Magnifier at the top right, or Ctrl+F",
      "Find on this page: every match is highlighted. Enter goes to the next, Shift+Enter to the previous, Esc closes it",
      "Searches only text blocks, not the title, table cells, mind maps or text inside folded toggles."
     ],
     [
      "⋯ at the top right of a page",
      "Opens the page's menu: font, small text, width, lock, favorites, agent, history, project, archive, duplicate, templates, copy as Markdown, print, export, move, trash",
      "Greyed out when no page is open"
     ],
     [
      "Hover the page's header: 'Add icon' / 'Add cover'",
      "Add icon puts a random emoji. Add cover puts a random gradient",
      ""
     ],
     [
      "Click the page's icon",
      "Opens the emoji picker: pick an emoji, Random, or Remove",
      ""
     ],
     [
      "Hover the cover: 'Change cover' or 'Remove'",
      "Change cover offers 12 gradients, 'A picture…' of your own, or Remove",
      ""
     ],
     [
      "Enter, Tab, or ↓ at the end of the title",
      "Moves from the title into the page's first block",
      ""
     ],
     [
      "Paste several lines into the page's title",
      "The first line becomes the title and the rest becomes the start of the page. Markdown comes in as blocks",
      ""
     ],
     [
      "'Start with a template' chips on a blank page",
      "Lays the page out from a template: your own first, then the built-in ones. Ctrl+Z undoes it",
      "Not on a locked page. The Project plan template also makes the page a project."
     ],
     [
      "'↩ Linked from' under the title",
      "Lists the pages that link to this one. Click one to open it",
      "Only shown when some page links here"
     ],
     [
      "Click under the page's last block",
      "Puts the cursor on a new line at the end",
      ""
     ],
     [
      "Drop files on a page",
      "An .eml becomes an email block. A .vcf adds its people to People. An .ics shows its events so you can add them. Notes (Markdown, HTML, text…) become pages inside this one. Pictures go on the page, or into a gallery they're dropped on. Any other file becomes a file block, or a video block for a video",
      "Up to 100 files per drop; emails, pictures and other files up to 12 each"
     ],
     [
      "Paste Markdown on a page",
      "It comes in as blocks",
      "Spreadsheet cells and HTML tables come in as a table."
     ],
     [
      "Paste with a picture on the clipboard",
      "Puts the picture on the page",
      ""
     ],
     [
      "'In the archive · Bring it back' on an archived page",
      "Takes the page out of the archive",
      ""
     ],
     [
      "Banner on a synced block's own page",
      "Says that changes here show on every page the synced block is on. 'Back' returns to where you were",
      ""
     ],
     [
      "Event line under the title of an event's notes page",
      "Shows which event the page is for. Click it to open the event",
      ""
     ],
     [
      "'No page open' screen: New page",
      "Makes a new page",
      ""
     ],
     [
      "Page ⋯ → Default / Serif / Mono",
      "Sets the page's font",
      ""
     ],
     [
      "Page ⋯ → Small text",
      "Uses smaller text on this page",
      ""
     ],
     [
      "Page ⋯ → Full width",
      "The page uses the full width of the window",
      ""
     ],
     [
      "Page ⋯ → Lock the page",
      "The page can be read and copied but not changed until you unlock it",
      "Recording, dictating, making it a project and restoring a version are refused on a locked page. Block handles are hidden."
     ],
     [
      "Page ⋯ → Add to Favorites / Out of Favorites",
      "Stars or unstars the page",
      ""
     ],
     [
      "Page ⋯ → Ask agent about this page",
      "Opens 'Ask your agent' about the whole page",
      ""
     ],
     [
      "Page ⋯ → Page history",
      "Lists the saved versions of the page, newest first, each shown as it was. 'Restore this version' (or Enter) brings it back; Ctrl+Z undoes that, and the current page is saved as a version first. ↑ ↓ move through the versions",
      "A version is saved every 10 minutes while you write, and always before an agent or command changes the page, before a restore, and before a tag is renamed or removed. The newest 100 per page are kept."
     ],
     [
      "Page ⋯ → Make it a project / Not a project",
      "Turns the page into a project (with a status, due date and progress) or back into a page. Undo on the message",
      "Disabled on a locked page"
     ],
     [
      "Page ⋯ → Archive / Out of the archive",
      "Puts the page and the pages inside it away: out of the tree, Projects, Favorites and the calendar, but still searchable and openable. Undo on the message",
      ""
     ],
     [
      "Page ⋯ → Duplicate",
      "Copies the page and the pages inside it, places the copy right after it, and opens it",
      ""
     ],
     [
      "Page ⋯ → Save as template / Not a template (a page again)",
      "Saves a copy of the page (and its pages) as one of your templates. On a template, puts it back in the tree as a page. Undo on the message",
      ""
     ],
     [
      "Page ⋯ → Pages inside start from…",
      "Picks the template (or 'A blank page') that every new page inside this one starts from",
      "Lists only your own templates, not the built-in ones"
     ],
     [
      "Page ⋯ → Copy as Markdown",
      "Copies the page to the clipboard as Markdown",
      ""
     ],
     [
      "Page ⋯ → Move to…",
      "Pick a page (or the top of Pages) to move this page into",
      ""
     ],
     [
      "Page ⋯ → Move to the trash",
      "Moves the page and the pages inside it to the trash, where they can be restored",
      ""
     ]
    ]
   },
   {
    "title": "Library",
    "rows": [
     [
      "Library tile in the sidebar",
      "Everything on your pages, newest first. Filter by kind: All, Links, Files, Videos, Pictures, Audio, Meetings, Sketches, People, Emails",
      "Only kinds you have are shown. Long lists end with 'Show more' (:303)."
     ],
     [
      "Library search box",
      "Finds items by name, link or page. Esc clears it",
      ""
     ],
     [
      "Click a Library item",
      "Opens its page at that block",
      ""
     ],
     [
      "Hover a Library item: Open / Copy",
      "Open: a link in your browser, a file in its app, an email in your mail app, a person in People. Copy: the link or email address",
      ""
     ]
    ]
   },
   {
    "title": "Templates",
    "rows": [
     [
      "Templates at the sidebar's foot",
      "Shows every template as a card, yours first, then Uber Notebook's. Click one to make a new page from it",
      ""
     ],
     [
      "Templates search box",
      "Finds templates by name or description. Enter makes a page from the first match; Esc clears the search",
      ""
     ],
     [
      "New template (Templates view)",
      "Makes an empty template and opens it for writing",
      ""
     ],
     [
      "Hover one of your template cards: Edit",
      "Opens the template to edit like any page",
      ""
     ],
     [
      "On a template's own page",
      "A banner says it's a template, with 'New page from it'. A line at the top holds its description, which shows on its card",
      ""
     ],
     [
      "{{date}}, {{weekday}}, {{time}}, {{month}}, {{year}}, {{week}} in a template",
      "Filled in when the template is used, including in its title",
      ""
     ],
     [
      "/template",
      "Inserts the blocks of one of your templates where you are. Pages in the template are created inside this page",
      "Your own templates only. With none, a message says 'No templates yet'."
     ],
     [
      "Built-in templates",
      "Daily, weekly and monthly planner, journal, habit tracker, to-do list, meeting notes, lecture notes, project plan, reading log, recipe, packing list",
      ""
     ]
    ]
   },
   {
    "title": "Projects",
    "rows": [
     [
      "+ on the sidebar's Projects, a page dragged onto Projects, Make it a project (page ⋯ or sidebar ⋯), or the Project plan template",
      "Makes a project (Active, no due date)",
      ""
     ],
     [
      "Click the status in a project's line under its title",
      "Planning, Active, Paused or Done; or Not a project",
      ""
     ],
     [
      "Click the due date in a project's line",
      "Type a date ('fri', 'oct 20', 'in 2 weeks') or pick Today, Tomorrow, Next week (next Monday), In 2 weeks, or In a month; or choose No due date. Late due dates show in red",
      ""
     ],
     [
      "Project line: progress",
      "Shows how many to-dos are done on the project and on the pages inside it",
      ""
     ],
     [
      "Set a project to Done",
      "Offers 'Archive it' to put it away",
      ""
     ]
    ]
   },
   {
    "title": "Tags",
    "rows": [
     [
      "# and a name in a line",
      "Makes a tag, shown in its color. The # menu suggests the tags you have",
      ""
     ],
     [
      "Click a tag (in a line or the sidebar)",
      "Shows every block with the tag, grouped by page. You can tick to-dos there; click a block to open it on its page",
      ""
     ],
     [
      "Tag view: palette, pen and trash at the top",
      "Palette sets the tag's color. Pen renames it on every page (renaming it to an existing tag merges the two). Trash takes it off every page, after asking; each page's previous version stays in its history",
      ""
     ],
     [
      "Tag colors",
      "Pages' colors or Custom…. A tag inside another (#work/acme) uses the outer tag's color until it has its own",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "sidebar",
  "label": "Sidebar",
  "icon": "sidebar",
  "note": "Everything in the sidebar, and the top bar's notebook.",
  "groups": [
   {
    "title": "Top bar",
    "rows": [
     [
      "Click the notebook icon in the Omarchy top bar (or Super+N)",
      "Opens or closes Uber Notebook",
      "Super+N is the default; change it in Settings → General → Shortcuts. The icon's tooltip shows the shortcut and says 'right-click for a quick note'. Settings → General → Window → Show Uber Notebook in the top bar hides the icon."
     ],
     [
      "Right-click the notebook icon in the top bar",
      "Pops up a quick note",
      ""
     ]
    ]
   },
   {
    "title": "Sidebar",
    "rows": [
     [
      "Click 'Uber Notebook' (the app name) at the top of the sidebar or the shelf",
      "Opens Settings at About",
      ""
     ],
     [
      "Hide-sidebar button at the sidebar's top right, or Ctrl+\\",
      "Hides the sidebar. The Show the sidebar button at the page's top left, or Ctrl+\\ again, brings it back",
      ""
     ],
     [
      "Notebooks / Pages switch at the top of the sidebar",
      "Goes to the notebooks' shelf",
      ""
     ],
     [
      "New page button (full width, under the profile), or Ctrl+N",
      "Makes a new page at the top of Pages and opens it",
      ""
     ],
     [
      "Search row in the sidebar, or Ctrl+P",
      "Find a page: recent pages, or every page with the words you type in its title or text, shown with the words around them. # and a tag name lists matching tags first",
      "Archived pages are still found."
     ],
     [
      "Calendar tile",
      "Opens the calendar in place of the page. Its tooltip gives today's day and date and how many events are left today",
      ""
     ],
     [
      "Library tile",
      "Opens the Library (everything on your pages). Its tooltip says how many items it has",
      ""
     ],
     [
      "People tile",
      "Opens People (your contacts). Its tooltip says how many people there are",
      ""
     ],
     [
      "Today section",
      "What's left of today on the calendar, up to 4 events, marked 'Now' or 'in N min'. Click one to open its event editor. 'N more today' opens the calendar",
      "Only shown when something is left today."
     ],
     [
      "Favorites section",
      "Your starred pages. Click one to open it",
      "Only shown when there is at least one favorite. Archived pages drop out of it."
     ],
     [
      "Projects section",
      "Every project with the pages inside it, ongoing ones first and late ones first. Each shows its due date (red when late) and a progress ring in its status color. Hover a project for its status, due date and how many to-dos are done",
      "The section shows even with no projects (a 'New project' row). If you hide Projects, projects appear in Pages, in their place in the tree."
     ],
     [
      "+ on the Projects heading, or 'New project' under it when there are none",
      "Makes a new page that is a project (Active, no due date) at the top and opens it",
      ""
     ],
     [
      "Tags section (chips)",
      "Each tag in its color, with how many blocks have it. Click a tag to see every block with it",
      "Only shown when you have tags"
     ],
     [
      "'A–Z' / 'By color' button on the Tags heading",
      "Sorts the tags by name or by color",
      "Saved as the tagSort setting"
     ],
     [
      "'Show all N' / 'Show fewer' under the tags",
      "Shows every tag, or only the first rows",
      "Appears only when the tags need more than five rows"
     ],
     [
      "Hover a tag chip and click its ⋯, or right-click the chip",
      "Tag menu: Every block with it, Color ›, Rename…, Take it off every page",
      ""
     ],
     [
      "Click a page in the Pages section",
      "Opens it. Its arrow shows or hides the pages inside it",
      ""
     ],
     [
      "Hover a page in the sidebar, click +",
      "Makes a new page inside it",
      "If that page has 'Pages inside start from…' set, the new page starts from that template"
     ],
     [
      "Hover a page in the sidebar, click ⋯",
      "Page menu: A page inside it, A page inside it from a template…, Add to / Out of Favorites, Make it a project / Not a project, Duplicate, Move to…, Archive, Move to the trash",
      "Page rows have no right-click menu. 'From a template' lists only your own templates. With none, a message says 'No templates yet'."
     ],
     [
      "Drag a page in the sidebar",
      "Moves it before, after or inside another page (a line or a highlighted page shows where it will go). Drop it on Pages' name to move it to the end of Pages, or onto Projects to make it a project. A project dropped in Pages becomes a page again. Undo on the message puts it back",
      "A page can't go inside a page that's inside it."
     ],
     [
      "Click a section's name (Today, Favorites, Projects, Tags, Pages)",
      "Folds or unfolds the section. A folded section shows how many items it has and stays folded",
      ""
     ],
     [
      "Right-click Search, Calendar, Library, People, Today, Favorites, Projects, Tags, Import, Templates, Archive or Trash",
      "Menu: Hide <it> (Undo on the message brings it back; so does Settings → Appearance), or Choose what's in the sidebar…",
      "Pages and Settings can't be hidden. Right-clicking them offers only 'Choose what's in the sidebar…', which opens Settings → Appearance → Sidebar."
     ],
     [
      "Templates button at the sidebar's foot",
      "Opens Templates in place of a page. The number is how many of your own templates you have",
      ""
     ],
     [
      "Archive button at the sidebar's foot",
      "Opens the archive. Click a page to open it (it stays archived). Its 'Bring it back' button puts it back in the tree",
      "Projects in it show their status."
     ],
     [
      "Trash button at the sidebar's foot",
      "Opens the trash. 'Put it back' returns a page where it was. 'Delete it from Pages' removes it and the pages inside it, after asking; its files still go to the .trash folder",
      ""
     ],
     [
      "Settings cog at the sidebar's foot, or Ctrl+,",
      "Opens Settings",
      ""
     ],
     [
      "'Version X is available' at the sidebar's foot (or the shelf's corner)",
      "Shows the new version's release notes and the command that installs it (omarchy plugin update), to copy and run in a terminal",
      "Only shown when a newer version exists."
     ],
     [
      "'Follow me on X' at the sidebar's foot (or the shelf's corner)",
      "Opens @devsec_ai on X in your browser",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "calendar",
  "label": "Calendar and People",
  "icon": "calendarMonth",
  "note": "Your calendar and your people.",
  "groups": [
   {
    "title": "Calendar",
    "rows": [
     [
      "Calendar tile in the sidebar, or Ctrl+Shift+C",
      "Opens the calendar in place of the page, in the view you used last",
      "Last view saved as calendarView"
     ],
     [
      "Month / Week / Agenda / Compact, or M, W, A, C",
      "Switches the view. Compact shows a small month with dots, and the days from the one you pick (+ on a day adds an event)",
      "In a narrow window the views fold into one menu."
     ],
     [
      "Today button (or T), ← / → buttons (or arrow keys)",
      "Goes back to today, or back or forward a month or week",
      ""
     ],
     [
      "+ New event (or N), or click a day or a time",
      "Type the event, e.g. 'Lunch with Sam fri 12:30', 'Standup 9:30-9:45', 'Dentist oct 12 3pm for 30 min'. Enter adds it; More… opens all its details",
      ""
     ],
     [
      "'+N more' in a month's day",
      "Opens that day in Week view",
      ""
     ],
     [
      "Click an event",
      "Opens its editor: title, color, all day or start and end, repeats, alert, place, a few words, Notes for it, delete, Done",
      ""
     ],
     [
      "Event editor → Repeats",
      "No, Daily, Weekdays, Weekly, Monthly or Yearly; every N; until a date (or for good)",
      "On a repeating event, 'Change just this one' makes this occurrence a separate event (:257)"
     ],
     [
      "Event editor → Alert",
      "None, At the start, 5, 10 or 30 min, 1 hour, or A day before. Sends an Omarchy notification; clicking it opens the event's notes page, or the calendar on that day",
      "Settings → Writing → Times → Show what reminders say controls whether it includes the event's title"
     ],
     [
      "Event editor → Notes for it / Open notes",
      "Makes a notes page for the event, linked to it (from your template with 'meeting' in its name, otherwise Meeting notes). Afterwards it opens that page",
      ""
     ],
     [
      "Event editor → trash button",
      "Takes the event off the calendar (Undo on the message). For a repeating event it asks: Just this one, This one and the ones after, or Every one",
      ""
     ],
     [
      "Drag an event; in Week view drag its bottom edge",
      "Moves it to another day or time, or makes it longer or shorter. For a repeating event it asks Just this one or Every one. Undo on the message",
      ""
     ],
     [
      "Calendar ⋯ → Import .ics…",
      "Shows a calendar file's events, then 'Add to calendar'. Events already there aren't added twice",
      "The same happens when you drop an .ics on a page or click one in an email or file block."
     ],
     [
      "Calendar ⋯ → Export as .ics…",
      "Saves your calendar as an .ics file for another calendar app",
      "Goes where Settings → Writing → Exports says"
     ],
     [
      "Calendar ⋯ → Undo / Redo, or Ctrl+Z / Ctrl+Shift+Z",
      "Undoes or redoes a calendar change",
      ""
     ],
     [
      "⏰ items on the calendar",
      "Reminders from your pages and projects' due dates show on the calendar. Click one to go to its page",
      "Not from archived pages, the trash or templates"
     ]
    ]
   },
   {
    "title": "People",
    "rows": [
     [
      "People tile in the sidebar",
      "Your contacts A to Z, with a search by name, company, email or phone number",
      ""
     ],
     [
      "List / cards switch at the top of People",
      "Shows everyone as a list beside the selected person, or as cards. As cards, 'Group by' Name or Company",
      ""
     ],
     [
      "Cards: arrow keys, Enter, Esc",
      "Move from card to card, open one, go back",
      ""
     ],
     [
      "Pick someone",
      "Their card: each number and email (click to copy; the mail button writes to them), birthday, address, website (Open it), notes, and the pages they're mentioned on",
      ""
     ],
     [
      "Edit, or New person",
      "Opens a form. Save (or Ctrl+S / Ctrl+Enter) keeps it, Cancel (or Esc) discards changes",
      ""
     ],
     [
      "⋯ on someone's card → Delete <name>",
      "Deletes them. Undo brings them back",
      ""
     ],
     [
      "Import (or People ⋯ → Import contacts…), or drop a file on People",
      "Reads a .vcf or .csv. People already there (same email or number) are filled in, not added twice",
      "A .vcf dropped on a page also goes to People."
     ],
     [
      "People ⋯ → Export everyone… / Undo",
      "Export saves everyone as a .vcf. Undo reverses the last change to People",
      ""
     ],
     [
      "@ and a name on a page",
      "Mentions a person in the line ('New contact' adds a name that isn't in People). Click the mention for their card and 'Open in People'",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "agent",
  "label": "Your agent",
  "icon": "agent",
  "note": "Claude Code, Grok and Codex on a page; the others in a terminal.",
  "groups": [
   {
    "title": "Agent",
    "rows": [
     [
      "AI button at a page's top right, Ctrl+J, /agent, ⋮⋮ → Ask agent, Ask on the selected-words toolbar, or ⋯ → Ask agent about this page",
      "Opens 'Ask your agent', or returns to this page's conversation",
      "A mark under the AI button means the page has a conversation."
     ],
     [
      "Switch at the top of the Ask box",
      "Ask about what you're on (This page, This block, N blocks, Selected words, This line) or ask for a New page",
      "With no page open (calendar, People, Library), Ctrl+J goes straight to a new page and the switch isn't shown."
     ],
     [
      "Suggestion chips in the Ask box",
      "Ready-made requests (Turn this into to-dos, Summarize this page, Continue writing, Link related pages…)",
      ""
     ],
     [
      "New page → 'Goes': At the top of Pages / Inside '<page>'",
      "Sets where the agent's new page is made. The page is created and opened first, then written while you watch",
      ""
     ],
     [
      "'Agent ▾' in the Ask box",
      "Choose another installed agent. It also becomes Omarchy's default agent",
      ""
     ],
     [
      "model · effort buttons in the Ask box",
      "Sets the model and effort for Claude Code, Grok or Codex (Default: whatever the agent is set up with)",
      "Only for agents that work in the panel. Also in Settings → AI → Model and effort"
     ],
     [
      "Ask ⏎, or the terminal button beside it",
      "Claude Code, Grok and Codex work in a panel on the page; the terminal button asks in a terminal instead. Other agents always open in a terminal",
      ""
     ],
     [
      "Agent panel → Stop",
      "Ends the turn. Changes the agent already made stay, and can be undone like any other change",
      ""
     ],
     [
      "Agent panel → reply box",
      "Continues the same conversation",
      ""
     ],
     [
      "Agent panel → New chat",
      "Opens the Ask box to start a new conversation",
      ""
     ],
     [
      "Agent panel → Close",
      "Hides the panel. The conversation is kept with the page, and Ctrl+J brings it back, even after a restart",
      "Kept in Pages/chats.json"
     ],
     [
      "Agent panel → Open in a terminal instead (or 'Stop, and open in a terminal')",
      "Continues with the agent in a terminal, with all its own controls",
      ""
     ],
     [
      "Agent panel asks permission",
      "Allow once (for a command: Allow this command), Allow for this conversation, Always for <it>, or No",
      "'Always' permissions are listed in Settings → AI → What agents may do without asking, where they can be removed."
     ],
     [
      "omarchy-shell uber-notebook-agent <command> ...",
      "The same commands under a second name, used only by the agent working in Uber Notebook's panel (Claude Code, Grok or Codex). It can read and change your notes but not Uber Notebook's settings, profiles or backups. When no agent is working in the panel, the commands that are checked refuse.",
      "toggle, show, hide, search, shelf, pages, calendar, open, settings and status skip the scope check, so they work under this name at any time. While the agent is being stopped, it can't change anything."
     ],
     [
      "Commands the panel agent can't use",
      "quick, importNotes, set and mirror are refused with a reason. reset is ignored without a word. profile, addProfile, renameProfile, profileFolder, removeProfile, demo, restartDemo, backup and restoreBackup are refused because they aren't on Scope's lists.",
      "Read-only commands it can use: help, list, find, read, blocks, tags, library, contacts, contact, tagged, projects, templates, events, trashed, history, version, preferences, notebooks, notebook, readNotebook, profiles, backups, appVersion, checkUpdate, releaseNotes, skill. Every other command on the CHANGES list changes notes and is allowed."
     ],
     [
      "A panel-agent command that names a file",
      "Files are read only from the agent's own folder (and, for pictures, Grok's own generated pictures). A file from a folder you chose Always for is taken without asking. A file from anywhere else is asked about in the panel (Allow once, Always from <folder>, No), and the command runs once you say yes.",
      "Applies to add, addTo, append, replace, insertAfter, attach, addGallery, gallery add, addTemplate, addToNotebook, importContacts and importCalendar. Files in a profile's notes or the backups folder only ever get Allow once. Always isn't offered for your home folder or a hidden folder. A path that isn't absolute, or has .. in it, is refused outright."
     ],
     [
      "A panel-agent removal",
      "Before the panel agent removes something, you're asked in the panel, one question per item. Trash: Allow once, Always let it trash pages, or No. Removing a person, event or tag, or emptying a field: Allow once, Allow for this conversation, or No.",
      "Covers trash, removeEvent, removeContact, removeTag, editEvent emptying place or notes, and editContact emptying a field or removing a phone or email. Saying yes to removing people also covers their details."
     ],
     [
      "A panel-agent link (bookmark, setLink)",
      "The card keeps just the link. Uber Notebook reads the site's page for a title and picture only if you allowed that site, and otherwise asks in the panel: Allow once, Always for <site>, or No.",
      "Only https links are read for the agent. Other links stay link-only until you refresh the card."
     ],
     [
      "(automatic) Uber Notebook's skill in your agents' skill folders",
      "While Uber Notebook runs, its skill is linked as uber-notebook into ~/.agents/skills, ~/.claude/skills, ~/.codex/skills, ~/.hermes/skills and ~/.pi/agent/skills, so agents know the commands. The links are removed when it stops.",
      "A link is only made where the folder exists and nothing called uber-notebook is already there. Only its own links are removed."
     ]
    ]
   }
  ]
 },
 {
  "id": "audio",
  "label": "Recording",
  "icon": "mic",
  "note": "Audio notes, dictation and meetings.",
  "groups": [
   {
    "title": "Meetings and audio",
    "rows": [
     [
      "Red dot at a page's top right, Ctrl+Shift+R, or /audio",
      "Records an audio note where you are. Enter or the square stops it; Esc or ✕ discards it",
      "Needs ffmpeg; not available on a locked page."
     ],
     [
      "Audio note player",
      "Play/pause, click or drag the waveform to seek, speed 1×, 1.25×, 1.5× or 2×. The button at its right hides or shows the transcript",
      ""
     ],
     [
      "Audio note → Write it out",
      "voxtype writes out what was said below the note",
      "Happens automatically when Settings → Audio → Write out audio notes is on"
     ],
     [
      "Audio note → Louder",
      "Makes a louder copy of a quiet recording (Undo goes back to the original)",
      "Only offered on quiet recordings"
     ],
     [
      "Microphone at a page's top right, Ctrl+Shift+D, or /dictate",
      "Dictation: a bar at the bottom listens. Press again (or Done) to write what you said at the cursor; ✕ discards it",
      "Needs voxtype. If the text can't go on the page (another profile was opened, or the page was locked or closed), it's copied to the clipboard instead. In Notebooks, Ctrl+Shift+D is Draw instead."
     ],
     [
      "Recording bar at the foot of a page",
      "Shows while you dictate or while an audio note records on another page (Done, or ✕ to discard). A separate bar shows a meeting recording on another page (Stop only)",
      ""
     ],
     [
      "People icon at a page's top right, or /meeting",
      "Adds a meeting block. voxtype's meeting mode records your microphone and the computer's audio. The top-right icon starts recording right away when meeting mode is on, or jumps to a meeting that's already recording",
      "The icon only shows when voxtype is installed."
     ],
     [
      "Meeting → Turn on meeting mode",
      "Sets meeting.enabled in voxtype's settings. It takes effect when voxtype restarts",
      "Also in Settings → Audio → Meetings → Turn on"
     ],
     [
      "Meeting → Start, Pause, Stop",
      "Records the meeting. Stop ends it, and voxtype writes it out turn by turn",
      ""
     ],
     [
      "Click a speaker's name in a meeting",
      "Lets you name the speaker",
      ""
     ],
     [
      "Meeting → Summarize",
      "Your agent writes a summary, decisions and to-dos below the meeting",
      ""
     ],
     [
      "Meeting → Bring one in / Get it again",
      "Bring one in puts a meeting that voxtype already recorded on the page. Get it again asks voxtype for its transcript again",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "quick",
  "label": "Quick notes",
  "icon": "sticky",
  "note": "A note from anywhere, and where it goes.",
  "groups": [
   {
    "title": "Quick notes",
    "rows": [
     [
      "Super+Alt+N, or right-click the notebook in the top bar",
      "A sticky note pops up wherever you are",
      "Super+Alt+N is the default; change it in Settings → General → Jot a quick note."
     ],
     [
      "Quick note: Ctrl+Enter, Ctrl+S or Esc",
      "Saves the note. The first line is the title, '- ' lines become a list and '[] ' lines a checklist; in Pages the rest is read as Markdown. Only ✕ discards a note",
      ""
     ],
     [
      "Click the destination at the quick note's foot ('Ctrl+Enter keeps it in your Pages Inbox / Quick notes')",
      "Switches where quick notes go: your Pages Inbox or the Quick notes notebook",
      "Same as Settings → General → Quick notes go to."
     ],
     [
      "Microphone on the quick note",
      "Dictates: click, speak, and click again; or hold it while you speak (Ctrl+Shift+D also works)",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "notebooks",
  "label": "Notebooks",
  "icon": "notebook",
  "note": "Paper notebooks on a shelf, and moving them to Pages.",
  "groups": [
   {
    "title": "Notebooks",
    "rows": [
     [
      "Click a notebook on the shelf",
      "Opens it",
      ""
     ],
     [
      "Right-click a notebook on the shelf",
      "Open, Cover paper and pen…, Export as Markdown, Move to Pages…, Put in the trash…",
      "Put in the trash asks first; the notebook's folder goes to .trash"
     ],
     [
      "Shelf → Move to Pages…",
      "Asks first, then makes the notebook a page in Pages, with a page inside it for each notebook page (drawings become a sketch at the end). The notebook then goes to .trash",
      "If a picture couldn't be copied or something couldn't be saved, the notebook also stays on the shelf. If a page is too long for Pages, nothing is moved."
     ],
     [
      "Search every page (top of the shelf), or Ctrl+F on the shelf",
      "Searches every page of every notebook",
      ""
     ],
     [
      "New notebook (shelf), or Ctrl+Shift+N",
      "Choose its title, kind of page, cover (color, material, elastic band), binding, paper and pen",
      "Ctrl+Shift+N works only in Notebooks."
     ],
     [
      "Esc on the shelf",
      "Hides Uber Notebook",
      ""
     ],
     [
      "'Notebooks' at the top left of an open notebook, or Ctrl+W",
      "Goes back to the shelf",
      ""
     ],
     [
      "Click the notebook's title at the top",
      "Opens its cover, paper and pen settings",
      ""
     ],
     [
      "‹ › arrows at the top, or Ctrl+PgUp / Ctrl+PgDn",
      "Previous or next page. On the last page, the next arrow makes a new page",
      ""
     ],
     [
      "'Page N of M' at the top, or Ctrl+G",
      "Lists every page: jump to one, move pages up and down, or start a new one",
      ""
     ],
     [
      "Magnifier at the top, or Ctrl+F (in a notebook)",
      "Find on this page",
      ""
     ],
     [
      "+ at the top right, or Ctrl+T",
      "Adds a new page from a template (planners, habits, journal, lists…)",
      ""
     ],
     [
      "Notebook ⋯ menu",
      "Paper…, Add a tab… / Change tab…, Copy page as Markdown, Export notebook…, Cover paper and pen…, Tear out this page (Clear this page if it's the only one)",
      ""
     ],
     [
      "Pen in the bottom bar, or Ctrl+Shift+D (in a notebook)",
      "Draw over the page: P for pen, M for highlighter, E for eraser. Esc or Done goes back to writing. The trash button clears the page's drawings",
      ""
     ],
     [
      "+ (Insert) in the notebook's bottom bar",
      "Link, Picture…, Sticky note, Code, Divider, Month calendar, Habit to track, Time slot, Today's date",
      ""
     ],
     [
      "Ctrl+= / Ctrl+- / Ctrl+0",
      "Bigger, smaller, back to normal size",
      "Notebooks only (on the shelf and in an open notebook); Pages ignores these keys"
     ]
    ]
   }
  ]
 },
 {
  "id": "profiles",
  "label": "Profiles and backups",
  "icon": "people",
  "note": "Notes kept apart, backups, the Markdown copy, import and export.",
  "groups": [
   {
    "title": "Profiles",
    "rows": [
     [
      "Profile button at the top of the sidebar or the shelf → a profile",
      "Switches to that profile (whatever is open is saved first)",
      "The switch is refused while something is busy, such as an audio note recording."
     ],
     [
      "Profile menu → New profile…",
      "Asks for a name and the folder for its notes (suggested from the name, typed, or picked). Create profile opens it",
      ""
     ],
     [
      "Profile menu → Explore the demo",
      "Opens the demo profile, with example pages",
      "Shown until a demo profile exists"
     ],
     [
      "Profile menu → Start screen…",
      "Opens the welcome screen: make your own profile, try the demo, or restore a backup",
      ""
     ],
     [
      "Profile menu → Manage profiles…",
      "Opens Settings",
      ""
     ],
     [
      "'Make my own profile' on the demo strip",
      "Opens the start screen to make your own profile (or restore a backup)",
      "The strip shows only while the demo is open"
     ],
     [
      "'Try again' / 'Pick another folder' over the notes",
      "Shown when a profile's notes folder can't be kept private (another account could read it) or can't be reached. Try again retries the folder; Pick another folder opens Settings → Profiles",
      "Nothing of that profile opens until its folder works"
     ],
     [
      "Settings → Profiles: a profile's row",
      "Rename it in place; Open; Folder… (point it at notes kept elsewhere; nothing is moved); open its folder; or remove it from the list (asks first; its notes stay). The demo's row has Start over (asks first; the old demo goes to the trash)",
      "The open profile can't be removed"
     ],
     [
      "Settings → Profiles → New profile / Explore the demo",
      "Makes a profile, or opens the demo",
      ""
     ],
     [
      "First run",
      "Name your first profile and its folder, Explore the demo, or Restore a backup…. Nothing is created until you pick one",
      ""
     ]
    ]
   },
   {
    "title": "Backups",
    "rows": [
     [
      "Settings → Backups → Back up",
      "Saves the open profile (notebooks, pages, calendar, people, templates) as one .tar.gz file",
      ""
     ],
     [
      "Settings → Backups → Back up all",
      "Saves every profile in one file (the demo is left out)",
      ""
     ],
     [
      "Settings → Backups → Back up automatically (Off, Daily, Weekly) and Keep (3, 5, 10, 20, 50)",
      "Backs up every profile while Uber Notebook runs. The oldest automatic backups go to the trash; backups you make yourself are never cleared",
      ""
     ],
     [
      "Settings → Backups → Folder: Change… / Default / open",
      "Sets where backups go (default ~/Documents/Uber Notebook Backups)",
      ""
     ],
     [
      "Settings → Backups → Restore… (a listed backup) or Choose a file…",
      "Shows what's in the backup, then restores each profile as a new profile in a new folder. Nothing you already have is changed. 'Open it' opens a restored profile",
      "Also 'Restore a backup…' on the first-run screen"
     ]
    ]
   },
   {
    "title": "Markdown copy",
    "rows": [
     [
      "Settings → Writing → Markdown copy → Keep a Markdown copy",
      "Keeps an up-to-date Markdown file of every page (including notebook pages, with pictures, and sketches as SVG) in a folder, for Obsidian, git or any editor",
      ""
     ],
     [
      "Markdown copy → Copy to (folder field) and the folder button",
      "Sets the folder (default: Markdown/ in your notes folder). The folder button opens the copy",
      "Refuses your home folder, the root folder, the notes folder (or a folder containing it), and Uber Notebook's own folders. Only shown while the copy is on."
     ]
    ]
   },
   {
    "title": "Import and export",
    "rows": [
     [
      "Import button at the sidebar's foot → Files… / A folder…",
      "Brings notes in: Markdown, HTML, text, Word and more, or a whole folder (such as a Notion or Obsidian export)",
      "Word files need pandoc or LibreOffice. 'Importing… N' shows at the sidebar's foot while it works."
     ],
     [
      "Page ⋯ → Export… → PDF / Word (.docx) / Markdown",
      "Exports the page as a PDF, a Word file, or a folder of Markdown files with its pages (sketches as SVG)",
      "PDF needs Chromium and Word needs LibreOffice; without them the option is greyed out with a hint. Destination: Settings → Writing → Exports"
     ],
     [
      "Page ⋯ → Export… → With the pages inside it",
      "Includes the pages inside it in the PDF or Word file",
      "Only shown when the page has pages inside it"
     ],
     [
      "Page ⋯ → Print…",
      "Makes a PDF and opens it in your PDF viewer, so you can print from its dialog",
      ""
     ],
     [
      "Shelf right-click → Export as Markdown, or a notebook's ⋯ → Export notebook…",
      "Exports each page of the notebook as a Markdown file, with its pictures, in a folder",
      ""
     ]
    ]
   }
  ]
 },
 {
  "id": "settings",
  "label": "Settings",
  "icon": "cog",
  "note": "What each setting does, and its name for the terminal.",
  "groups": [
   {
    "title": "Settings",
    "rows": [
     [
      "Settings → General → Shortcuts",
      "Change the keys that open/close Uber Notebook and jot a quick note, and choose where quick notes go (Pages Inbox or Quick notes)",
      ""
     ],
     [
      "Settings → General → Window",
      "Float in the middle of the screen (off: tiles like other windows), Size (Small, Medium, Large; applies when floating), Show Uber Notebook in the top bar",
      ""
     ],
     [
      "Settings → General → Scrolling speed",
      "Slower, Normal or Faster scrolling with a trackpad or mouse wheel",
      ""
     ],
     [
      "Settings → Appearance → Colors",
      "Your own colors for the sidebar, page background, sections and cards, and text, each with Reset (Reset all goes back to the theme). Warns when text would be hard to read",
      ""
     ],
     [
      "Settings → Appearance → Sidebar",
      "A checkbox for each item at the top, in the sections and at the foot of the sidebar. Show all brings everything back",
      ""
     ],
     [
      "Settings → Appearance → Motion and sound",
      "Reduce motion (fades instead of page turns and swinging covers); Paper sounds",
      ""
     ],
     [
      "Settings → Writing → Checklists",
      "Cross off checked items",
      ""
     ],
     [
      "Settings → Writing → Times → Clock",
      "Shows times as 1:30 pm or 13:30 (you can type either)",
      ""
     ],
     [
      "Settings → Writing → Times → Show what reminders say",
      "When off, notifications only say that a reminder or event is due (turn it off on a shared computer)",
      "On by default."
     ],
     [
      "Settings → Writing → Exports",
      "Exports go to: Ask where (a folder picker each time) or the Exports folder",
      ""
     ],
     [
      "Settings → AI → Your agent",
      "Choose your agent (it also becomes Omarchy's default). Claude Code, Grok and Codex work in the panel; others work in a terminal",
      ""
     ],
     [
      "Settings → AI → Model and effort",
      "Sets the model and effort for Claude Code, Grok and Codex",
      ""
     ],
     [
      "Settings → AI → Commands",
      "Lets Claude Code or Grok run any command without asking (off by default)",
      "Only Claude Code and Grok have this toggle, not Codex"
     ],
     [
      "Settings → AI → Use with any AI",
      "The uber-notebook skill: Copy, Save a copy…, or Show its file",
      ""
     ],
     [
      "Settings → AI → What agents may do without asking",
      "Lists the 'Always' permissions you've given, each with Remove",
      ""
     ],
     [
      "Settings → Audio → Microphone",
      "Pick the microphone; Make my voice louder; Test the microphone (says whether it's too quiet, good or too loud)",
      ""
     ],
     [
      "Settings → Audio → Voice",
      "Write out audio notes (with voxtype) as soon as they're recorded. Meetings: turn on voxtype's meeting mode",
      "Needs voxtype"
     ],
     [
      "Settings → About → Updates",
      "Shows your version, with What's new and Check now. Check for updates automatically (once a day; asks GitHub only). Release notes → Read",
      ""
     ],
     [
      "Settings → About → Contact",
      "Follow me on X (@devsec_ai), Project page",
      ""
     ],
     [
      "Ctrl+, or the cog on the shelf / in the sidebar, or omarchy-shell uber-notebook settings",
      "Opens Settings. Sections: General, Appearance, Writing, AI, Audio, Profiles, Backups, About. Changes apply right away.",
      ""
     ],
     [
      "Settings → General → Shortcuts → Open and close Uber Notebook (or: set shortcut \"SUPER + N\")",
      "shortcut (default SUPER + N): the global shortcut that opens and closes Uber Notebook. Leave it empty for none.",
      "It needs a modifier (SUPER, CTRL, ALT or SHIFT) unless it's F1-F24 or an XF86 media key. If another binding already uses it, the shortcut is left alone and Settings says which binding has it."
     ],
     [
      "Settings → General → Shortcuts → Jot a quick note (or: set quickShortcut \"SUPER + ALT + N\")",
      "quickShortcut (default SUPER + ALT + N): the global shortcut for a quick note. Leave it empty for none.",
      "If it's the same as the open-and-close shortcut, it isn't registered."
     ],
     [
      "Settings → General → Shortcuts → Quick notes go to (or: set quickTo pages|notebook)",
      "quickTo (default pages): where a quick note goes. pages makes a page in the Pages Inbox (the first line is the title, the rest is Markdown). notebook adds a page to the Quick notes notebook.",
      "It can also be changed from the bottom of the quick-note card."
     ],
     [
      "Settings → General → Window → Float in the middle of the screen (or: set floating true|false)",
      "floating (default true): the window floats in the middle of the screen. When off, it tiles like any other window.",
      ""
     ],
     [
      "Settings → General → Window → Size: Small / Medium / Large (or: set width <px>, set height <px>)",
      "width and height (default 1320 x 900): the floating window's size. Small is 1100x760, Medium 1320x900, Large 1560x1040.",
      "Values are kept within 640-5000 (width) and 480-4000 (height)."
     ],
     [
      "Settings → General → Window → Show Uber Notebook in the top bar (or: set barIcon true|false)",
      "barIcon (default true): shows the notebook icon in the top bar. When off, the icon takes no space and Uber Notebook keeps running.",
      ""
     ],
     [
      "Settings → General → Scrolling → Scrolling speed (or: set scrollSpeed slower|normal|faster)",
      "scrollSpeed (default normal): how fast a page scrolls with a trackpad or mouse wheel.",
      ""
     ],
     [
      "Settings → Appearance → Colors (Sidebar, Page background, Sections and cards, Text) (or: set colorSidebar \"#1e1e2e\")",
      "colorSidebar, colorPage, colorCards, colorText (default \"\"): your own #rrggbb colors in place of the Omarchy theme's. \"\" follows the theme. Each one has Reset, and Reset all puts all four back.",
      "Only #rrggbb is used; any other text is ignored and the theme color shows. Settings warns when text would be hard to read (contrast below 4.5:1)."
     ],
     [
      "Settings → Appearance → Sidebar (checkboxes), or right-click in the sidebar → Hide (or: set sidebarHidden \"calendar,trash\")",
      "sidebarHidden (default []): what Pages' sidebar leaves out. Choices: search, calendar, library, people, today, favorites, projects, tags, import, templates, archive, trash. Show all brings everything back.",
      "Pages and Settings always stay. With set, use lowercase names separated by commas, or \"\" for none. If any name isn't lowercase, the whole list is rejected and goes back to empty, so everything shows."
     ],
     [
      "Click a section's name in Pages' sidebar (or: set sidebarFolded \"tags,projects\")",
      "sidebarFolded (default []): which sidebar sections are folded: today, favorites, projects, tags, pages.",
      ""
     ],
     [
      "Settings → Appearance → Motion and sound → Reduce motion (or: set reduceMotion true|false)",
      "reduceMotion (default false): pages and covers fade instead of turning and swinging.",
      ""
     ],
     [
      "Settings → Appearance → Motion and sound → Paper sounds (or: set sounds true|false)",
      "sounds (default true): a soft paper sound when a page turns or a notebook opens.",
      ""
     ],
     [
      "Settings → Writing → Checklists → Cross off checked items (or: set strikeDone true|false)",
      "strikeDone (default true): draws a line through checked items.",
      ""
     ],
     [
      "Settings → Writing → Times → Clock: 1:30 pm / 13:30",
      "clock (default \"12\"): shows times on a 12-hour or 24-hour clock in the calendar, events, reminders and dated items. You can type times either way.",
      "Or: set clock 12 / set clock 24."
     ],
     [
      "Settings → Writing → Times → Show what reminders say (or: set reminderWords true|false)",
      "reminderWords (default true): a reminder's words and an event's title appear in its notification. When off, the notification only says that a reminder is due or an event is starting.",
      "Omarchy's notifications briefly put these words on a command line that other accounts on the computer can read, so turn this off on a shared computer."
     ],
     [
      "Settings → Writing → Exports → Exports go to: Ask where / Exports folder (or: set exportTo ask|folder)",
      "exportTo (default ask): ask asks for a folder each time; folder saves to Exports/ in the notes folder.",
      ""
     ],
     [
      "Settings → Writing → Markdown copy → Keep a Markdown copy (or: set mirror true|false)",
      "mirror (default false): keeps a Markdown file of every page (Pages and notebooks) up to date in a folder, for Obsidian, git or any editor.",
      "Each profile has its own setting. `omarchy-shell uber-notebook mirror` brings the copy up to date now."
     ],
     [
      "Settings → Writing → Markdown copy → Copy to (or: set mirrorFolder ~/Vault)",
      "mirrorFolder (default \"\"): where the Markdown copy goes. \"\" means Markdown/ in the notes folder. The folder button opens it.",
      "Each profile has its own. It must be an absolute or ~/ path with no ... Copying refuses your home folder, the notes folder itself, and Uber Notebook's own folders inside it."
     ],
     [
      "Settings → AI → Your agent → Agent",
      "Chooses your agent. This is Omarchy's default agent, written to ~/.config/omarchy/defaults/agent. Claude Code, Grok and Codex work in the panel; the others open in a terminal.",
      ""
     ],
     [
      "Settings → AI → Model and effort (or: set claudeModel <model>, set claudeEffort <effort>; same for grok and codex)",
      "claudeModel, claudeEffort, grokModel, grokEffort, codexModel, codexEffort (default \"\"): the model and effort Claude Code, Grok and Codex use in Uber Notebook. \"\" uses each agent's own setup.",
      "The ask box's model and effort buttons set these too. The values are cleaned before they're passed to the agent."
     ],
     [
      "Settings → AI → Commands → <Claude Code|Grok> may run any command",
      "Lets Claude Code or Grok run any command in the panel without asking. Off by default. It's stored in agentPermissions as a shell/any entry.",
      "There's no toggle for Codex. Commands it runs can read and change any file you can, including your notes and Uber Notebook's settings, and can use the network."
     ],
     [
      "Settings → AI → What agents may do without asking → Remove",
      "agentPermissions (default []): what you've allowed with Always: sites to contact, web search, connector tools, trashing pages, running any command, and folders to take files from. Remove takes one away.",
      "Agents can't change this list (the panel agent can't use set). `set agentPermissions <anything>` and `reset` both clear the whole list."
     ],
     [
      "Settings → AI → Use with any AI → Copy / Save a copy… / Show",
      "Copies the skill (SKILL.md) to the clipboard, saves a copy where you choose, or shows its folder. `omarchy-shell uber-notebook skill` prints it.",
      ""
     ],
     [
      "Settings → Audio → Microphone → Microphone (or: set audioInput <PipeWire source name>)",
      "audioInput (default \"\"): the microphone that audio notes and dictation record from. \"\" uses the default one.",
      ""
     ],
     [
      "Settings → Audio → Microphone → Make my voice louder (or: set audioBoost true|false)",
      "audioBoost (default true): evens out and raises a quiet voice after recording, for audio notes and dictation.",
      ""
     ],
     [
      "Settings → Audio → Microphone → Test the microphone → Test / Stop",
      "Records a short test and shows the input level as you speak.",
      ""
     ],
     [
      "Settings → Audio → Voice → Write out audio notes (or: set audioTranscribe true|false)",
      "audioTranscribe (default true): voxtype transcribes an audio note as soon as it's recorded.",
      "Needs voxtype (omarchy voxtype install). Audio notes still record and play without it."
     ],
     [
      "Settings → Audio → Voice → Meetings → Turn on",
      "Turns on voxtype's meeting mode (runs voxtype config set meeting.enabled true) so /meeting can record meetings.",
      "Needs voxtype. It takes effect when voxtype restarts."
     ],
     [
      "Settings → Profiles (rename in place, Open, Folder…, folder icon, Remove, Start over, New profile, Explore the demo)",
      "Manages profiles: rename one, open one, point one at another folder (nothing is moved), open its folder, take it off the list (its notes stay), start the demo over, create a new profile, or explore the demo.",
      "Remove and Start over ask first. Folder… is hidden for the demo, Remove is hidden for the open profile, and Explore the demo only shows when there's no demo profile yet."
     ],
     [
      "set folder <path> / set profile <name or id> / profiles (internal)",
      "folder (default \"\" = ~/Documents/Uber Notebook) is the open profile's notes folder. profile is the open profile's id. profiles is the list of profiles.",
      "These internal keys are hidden from preferences. Use Settings → Profiles or the profile commands instead. `set profiles` is refused."
     ],
     [
      "Settings → Backups → Back up now → Back up / Back up all",
      "Back up saves the open profile in one .tar.gz. Back up all saves every profile except the demo, together in one .tar.gz.",
      "The earlier draft said \"one .tar.gz each\"; the code writes a single file for all profiles (the label is \"All profiles\"). A profile with nothing written yet isn't backed up."
     ],
     [
      "Settings → Backups → Automatic backups → Back up automatically (or: set backupEvery off|daily|weekly)",
      "backupEvery (default off): backs up every profile except the demo, in one file, daily or weekly, while Uber Notebook runs.",
      "It checks 3 minutes after starting and then every 30 minutes. Automatic backups stop, with a notification, if the backup folder can't be kept private."
     ],
     [
      "Settings → Backups → Automatic backups → Keep (or: set backupKeep 3|5|10|20|50)",
      "backupKeep (default 10): how many automatic backups to keep. Older ones go to the trash; backups you make yourself are never removed.",
      "Shown only when automatic backups are on. Any other number falls back to 10."
     ],
     [
      "Settings → Backups → Automatic backups → Folder → Change… / Default (or: set backupFolder ~/Backups)",
      "backupFolder (default \"\" = ~/Documents/Uber Notebook Backups): where backups go. The folder icon opens it.",
      ""
     ],
     [
      "Settings → Backups → Restore → Restore… / Choose a file…",
      "Shows what's in a backup first, then restores each profile in it as a new profile in a new folder. Nothing you have now is changed. Open it opens a profile that was just restored.",
      ""
     ],
     [
      "Settings → About → Updates → Check now / What's new",
      "Check now asks GitHub for a newer version right away. What's new shows the newer release notes, and only appears when an update is available.",
      ""
     ],
     [
      "Settings → About → Updates → Check for updates automatically (or: set checkUpdates true|false)",
      "checkUpdates (default true): asks GitHub a minute after starting and then once a day whether there's a newer version. When off, it checks only when you ask.",
      ""
     ],
     [
      "Settings → About → Release notes → Read",
      "Shows what's in the version you have, from CHANGELOG.md.",
      ""
     ],
     [
      "Settings → About → Contact → @devsec_ai / Project page → Open",
      "Opens the author's X profile, or the project's homepage, in your browser.",
      "Project page shows only when the manifest has a homepage."
     ],
     [
      "Settings → About → Your notes",
      "Where your notes live: plain files on your computer, yours alone (each page and notebook a JSON file, pictures copied in beside them). Uber Notebook goes online only to ask GitHub for a newer version and to read a link's page for a bookmark; an agent you ask works through its own account and is given what it needs of the page.",
      ""
     ],
     [
      "Calendar's view switch (or: set calendarView month|week|agenda|compact)",
      "calendarView (default month): the view the calendar opens in. It remembers the last one you used.",
      ""
     ],
     [
      "People's layout switch (or: set peopleLayout list|cards)",
      "peopleLayout (default list): People shows everyone either as a list beside the selected person, or as cards.",
      ""
     ],
     [
      "People's grouping switch, in cards view (or: set peopleGroup letter|company)",
      "peopleGroup (default letter): in cards view, People groups everyone A to Z or by company.",
      ""
     ],
     [
      "The A–Z / By color button on Tags in Pages' sidebar (or: set tagSort name|color)",
      "tagSort (default name): sorts tags in the sidebar by name or by color.",
      ""
     ],
     [
      "Ctrl+= / Ctrl+- / Ctrl+0 in Notebooks (or: set zoom <60-200>)",
      "zoom (default 100): how large an open paper notebook is drawn, in percent. Ctrl+= and Ctrl+- change it in steps of 10, and Ctrl+0 puts it back to 100.",
      "Corrected: it doesn't make everything bigger. Only NotebookView uses it, and the keys are ignored in Pages. The keys work on the shelf and in an open notebook."
     ],
     [
      "New notebook dialog (cover, material, binding, paper, paper color, spacing, pen) (or: set pen|paper|paperColor|spacing|cover|material|binding <value>)",
      "pen (sans), paper (ruled), paperColor (ivory), spacing (regular), cover (navy), material (leather), binding (spiral): what a new notebook starts with. Each one remembers the choices from the last new notebook you made.",
      "Editing an existing notebook doesn't change these. pen: sans, serif, hand, print, typewriter, mono, duo. paper: blank, ruled, grid, dots, graph, legal. paperColor: white, ivory, cream, yellow, kraft, gray, night, blueprint, theme. spacing: compact, regular, roomy. cover: navy, black, forest, burgundy, mustard, sky, coral, lavender, sage, sand, charcoal, accent. material: leather, linen, kraft, plain, composition. binding: spiral, stitched, hardcover."
     ],
     [
      "Switching between Pages and Notebooks (internal: space)",
      "space (default pages): whether Uber Notebook opens in Pages or Notebooks. It remembers the one you were in last.",
      "Internal key, hidden from preferences."
     ],
     [
      "(automatic) lastNotebook, lastPage",
      "Remember the notebook and the Pages page you were on, so Uber Notebook reopens there.",
      "Internal keys, kept per profile and through reset."
     ],
     [
      "(automatic) inbox (or: set inbox <page id>)",
      "inbox: the page where new pages from agents, scripts and quick notes go. It's created as Inbox the first time it's needed. Set it to another page id to change it.",
      "Internal key, kept per profile and through reset. If the page is gone or in the trash, a new Inbox is made."
     ],
     [
      "(automatic) recentColors",
      "The last custom colors you picked, newest first, up to 8. The color pickers use it (Pages' custom colors and the Appearance colors).",
      "Internal key."
     ]
    ]
   }
  ]
 },
 {
  "id": "terminal",
  "label": "From a terminal",
  "icon": "terminal",
  "note": "Commands for you, scripts and agents: omarchy-shell uber-notebook …",
  "groups": [
   {
    "title": "From a terminal",
    "rows": [
     [
      "omarchy-shell uber-notebook <command> [arguments]",
      "Runs one of Uber Notebook's commands in the running app, over the Omarchy shell's IPC. Arguments go by position; use \"\" to leave one empty. Most commands answer in JSON ({ ok: false, error } when they can't). read, version, readNotebook, releaseNotes and skill answer in Markdown.",
      "Content goes in as a Markdown file, given by its full path (/... or ~/...). It must be a plain file, not a link, of at most 2 MB (importContacts takes up to 32 MB, importCalendar up to 16 MB). The first time a file is named, the answer can be \"run the same command again in a moment\". toggle, show, hide, search, shelf, pages, calendar, open, settings and reset answer nothing. set answers in plain text when it refuses. Until a profile exists, most commands answer \"Uber Notebook has no profile yet: make one with addProfile\". new.md` and `addToNotebook <id> note.md` use relative paths, which the code refuses."
     ],
     [
      "omarchy-shell uber-notebook help",
      "Lists every scripting command with its usage and what it does, plus the fenced-block, columns and Markdown formats, as JSON.",
      "These commands aren't in the list: toggle, show, hide, quick, search, shelf, pages, calendar, importNotes, settings, set, reset, mirror, status and help itself. unarchive appears inside archive's entry, and restartDemo inside demo's."
     ],
     [
      "omarchy-shell uber-notebook toggle",
      "Opens or closes the Uber Notebook window.",
      ""
     ],
     [
      "omarchy-shell uber-notebook show",
      "Opens the window where you left off. Does nothing if it's already open.",
      ""
     ],
     [
      "omarchy-shell uber-notebook hide",
      "Closes the window.",
      ""
     ],
     [
      "omarchy-shell uber-notebook quick",
      "Opens the quick-note card when no text is given.",
      "With no profile yet, it opens the main window instead. The panel agent can't use it (\"quick notes are yours\")."
     ],
     [
      "omarchy-shell uber-notebook quick \"Buy milk\"",
      "Saves a quick note right away. By default it becomes a page in the Pages Inbox (the first line is the title, the rest is Markdown). With quickTo set to notebook, it goes to the Quick notes notebook instead. Answers { ok, note }, with waiting: true if the profile's notes are still opening.",
      "If the Pages page can't be made, the note goes to Quick notes instead. Text is capped at 20000 characters. With no profile yet, the note isn't saved and the window opens. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook search \"tram 28\"",
      "Opens the window on the Notebooks shelf with the text in its search box.",
      "This searches the notebooks shelf, not Pages. Text is capped at 200 characters. Empty text just opens the window where you left off."
     ],
     [
      "omarchy-shell uber-notebook shelf",
      "Opens the window on the Notebooks shelf, closing any open notebook.",
      ""
     ],
     [
      "omarchy-shell uber-notebook pages",
      "Opens the window straight into Pages.",
      ""
     ],
     [
      "omarchy-shell uber-notebook calendar \"\" (or calendar 2026-10-12)",
      "Opens the calendar in Pages, on today or on the date given (YYYY-MM-DD).",
      "Anything other than a YYYY-MM-DD date opens on today."
     ],
     [
      "omarchy-shell uber-notebook importNotes ~/notes",
      "Imports files or a folder (for example a Notion or Obsidian export) into Pages. The OSD says how it went.",
      "~/ is expanded. It's refused while the profile's notes are still opening, if the profile's notes folder can't be used, or if another profile opens during the import. The panel agent can't use it (\"importing is yours\")."
     ],
     [
      "omarchy-shell uber-notebook open <page id>",
      "Opens that page in Pages.",
      "Does nothing unless the id is 36 characters of hex digits and dashes (a page id)."
     ],
     [
      "omarchy-shell uber-notebook settings",
      "Opens the window with Settings open.",
      ""
     ],
     [
      "omarchy-shell uber-notebook set <key> <value>",
      "Changes one setting and answers with its new value as JSON. The value is read as that setting takes it: true or false for an on/off one, a number for a number, words for the rest (set clock 24, set paper grid). folder and profile go through Profiles, as Settings does them; profiles can't be set whole.",
      "Not for the panel's agent. omarchy-shell uber-notebook reset puts every setting back, but your profiles and what's each one's own."
     ],
     [
      "omarchy-shell uber-notebook reset",
      "Puts settings back to their defaults. It keeps the profiles, the open profile, its folder, and each profile's own inbox, lastPage, lastNotebook, mirror and mirrorFolder.",
      "Reset also clears agentPermissions (everything you allowed agents with Always) and puts both shortcuts back to their defaults. When the panel agent calls it, nothing happens and nothing is said."
     ],
     [
      "omarchy-shell uber-notebook mirror",
      "Starts bringing the Markdown copy up to date now and answers { ok, folder, status, files }.",
      "Answers an error if the Markdown copy is off (`set mirror true` turns it on). The status can still say Copying… because the copy runs in the background. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook status",
      "Reports the app's state as JSON: whether the window is open, Hyprland registration, shortcuts already taken by other bindings, notes folder, open profile's name, version, whether an update is available, notebook and page counts, ready, and connected.",
      "Not listed by help. It skips the panel agent's scope check, so it also works under uber-notebook-agent."
     ],
     [
      "omarchy-shell uber-notebook list",
      "Lists every page: id, title, icon and path (the pages it sits inside).",
      ""
     ],
     [
      "omarchy-shell uber-notebook find <words>",
      "Finds pages with all of the words in their title or text, best match first, with a snippet. Pages in the trash and templates are skipped. At most 50 results.",
      "Empty words are refused (\"find needs words to look for\")."
     ],
     [
      "omarchy-shell uber-notebook read <id>",
      "Returns the page as Markdown. Links to other pages come out as uber-notebook://page/<id>, and boards, contacts, events and similar blocks come out as fenced blocks.",
      ""
     ],
     [
      "omarchy-shell uber-notebook add <title> <file.md>",
      "Creates a new page in the Inbox from a Markdown file. An empty title takes the file's first # heading. The Inbox page is created the first time it's needed, and again if it's gone or in the trash.",
      "The panel agent can use it, but only with a file from its own folder or one you approve."
     ],
     [
      "omarchy-shell uber-notebook addTo <page id> <title> <file.md>",
      "Creates a new page inside that page. Use \"\" or top for the top of Pages.",
      "The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook append <id> <file.md>",
      "Adds the Markdown to the end of a page. The page as it was is saved in its history first.",
      "Refused for a locked page. The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook blocks <id>",
      "Lists the page's blocks in order: id, type, depth and text (as Markdown).",
      ""
     ],
     [
      "omarchy-shell uber-notebook replace <page id> <block id> <file.md>",
      "Replaces that block, and the blocks inside it, with the Markdown.",
      "Refused for a locked page, for a block that holds columns, and for a block with a page inside it. The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook insertAfter <page id> <block id> <file.md>",
      "Inserts the Markdown after that block (and the blocks inside it), at the same depth.",
      "The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook trash <id>",
      "Moves the page, and the pages inside it, to the trash, where it can be restored.",
      "For the panel agent, you're asked in the panel first unless you chose Always."
     ],
     [
      "omarchy-shell uber-notebook tags",
      "Lists every tag with how many pages and blocks have it, and its color.",
      ""
     ],
     [
      "omarchy-shell uber-notebook library <kind> <words>",
      "Lists what has been put on pages (the Library), newest first. kind is link, file, video, picture, audio, meeting, sketch, person or email, or \"\" (or all) for everything. words narrows the list by title, link or page.",
      "Plurals such as files, pictures and people work, but \"sketches\" doesn't: only a trailing s is dropped, which leaves \"sketche\". At most 500 results."
     ],
     [
      "omarchy-shell uber-notebook contacts <words>",
      "Lists your People: id, name, company, title, phones, emails and birthday. Use \"\" for everyone.",
      ""
     ],
     [
      "omarchy-shell uber-notebook contact <id or name>",
      "Shows one person with everything kept about them (address, website, notes), plus the pages they're named on. It finds the person by id, or else by the best match for a name, email or number.",
      ""
     ],
     [
      "omarchy-shell uber-notebook addContact <name> <phone> <email>",
      "Adds someone to People (use \"\" for what you don't know). If someone with that email or number is already there, their details are filled in instead.",
      ""
     ],
     [
      "omarchy-shell uber-notebook importContacts <file>",
      "Imports a .vcf (vCard) or .csv file into People. People already there are filled in, not added twice. Answers { read, added, filledIn }.",
      "A .csv needs a header row. The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook tagged <tag>",
      "Lists every block with the tag: page id, page title, block id, type, text, and whether it's checked.",
      ""
     ],
     [
      "omarchy-shell uber-notebook tagColor <tag> <color>",
      "Sets a tag's color: gray, brown, orange, yellow, green, blue, purple, pink, red, a hex like #ff8800, or \"\" for none.",
      "A tag with no color takes the color of the tag it's inside (#work/acme takes #work's)."
     ],
     [
      "omarchy-shell uber-notebook projects",
      "Lists every project not in the archive: id, title, status, due date, progress, whether it's overdue, and its path.",
      ""
     ],
     [
      "omarchy-shell uber-notebook project <id> <status> <due>",
      "Makes the page a project or changes one. status is planning, active, paused or done (\"\" keeps it; none turns it back into a page). due is a date like 2026-10-12, \"\" for none, or - to keep it.",
      "Refused for a locked page."
     ],
     [
      "omarchy-shell uber-notebook archive <id>",
      "Puts the page, and the pages inside it, in the archive (unarchive brings it back).",
      ""
     ],
     [
      "omarchy-shell uber-notebook unarchive <id>",
      "Brings an archived page (and the pages in it) back from the archive.",
      ""
     ],
     [
      "omarchy-shell uber-notebook events <from> <to>",
      "Lists calendar events from one date to another (2026-10-05). \"\" \"\" means today and the following week. It also lists the dates in your notes (reminders and projects' due dates).",
      "At most about 400 days at a time."
     ],
     [
      "omarchy-shell uber-notebook addEvent <what and when> <repeat>",
      "Puts an event on the calendar, for example \"Dentist oct 12 3pm\" or \"Standup mon 9:30-9:45\". repeat is daily, weekdays, weekly, monthly, yearly or \"\".",
      "A timed event gets a 10-minute alert; an all-day event gets none."
     ],
     [
      "omarchy-shell uber-notebook editEvent <id> <field> <value>",
      "Changes an event. Fields: title, when (\"fri 3pm\"), start, end, allDay, place, notes, repeat, alert (0, 5, 10, 15, 30, 60, 120 or 1440 minutes before, or none) and color.",
      "For the panel agent, emptying the place or notes asks you first."
     ],
     [
      "omarchy-shell uber-notebook removeEvent <id>",
      "Removes an event from the calendar, including every repeat.",
      "For the panel agent, you're asked first."
     ],
     [
      "omarchy-shell uber-notebook importCalendar <file.ics>",
      "Adds an .ics file's events to the calendar. Events already there are skipped. Answers { added, skipped }.",
      "The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook templates",
      "Lists your templates: id, title, icon, description and page count.",
      ""
     ],
     [
      "omarchy-shell uber-notebook addTemplate <title> <file.md> <description>",
      "Creates a template from Markdown. {{date}}, {{weekday}}, {{time}}, {{month}}, {{year}} and {{week}} are filled in when it's used. An empty title takes the file's first # heading.",
      "The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook describeTemplate <template> <text>",
      "Sets a one-line description of what a template is for, shown on its card in Templates.",
      ""
     ],
     [
      "omarchy-shell uber-notebook fromTemplate <template> <title> <parent>",
      "Creates a new page from a template (by name or id). A title of \"\" uses the template's title. A parent of \"\" puts the page in the Inbox and top puts it at the top of Pages; you can also give a page id.",
      ""
     ],
     [
      "omarchy-shell uber-notebook makeTemplate <id>",
      "Saves a copy of the page, and the pages inside it, as one of your templates.",
      ""
     ],
     [
      "omarchy-shell uber-notebook preferences",
      "Lists every user setting with its key, value, kind, choices and range. Change one with set <key> <value>.",
      "Leaves out the internal keys profiles, profile, folder, lastNotebook, lastPage, inbox, recentColors and space, though set still accepts them."
     ],
     [
      "omarchy-shell uber-notebook rename <id> <title>",
      "Changes the page's title.",
      "Refused for a locked page."
     ],
     [
      "omarchy-shell uber-notebook move <id> <parent> <position>",
      "Moves the page inside another page (top or \"\" for the top of Pages), at a position among the pages there. 0 is first and \"\" is the end.",
      ""
     ],
     [
      "omarchy-shell uber-notebook icon <id> <emoji>",
      "Sets the page's icon to one emoji, or \"\" for none.",
      ""
     ],
     [
      "omarchy-shell uber-notebook cover <id> <cover>",
      "Sets the page's cover to gradient:0 through gradient:11, or \"\" for none.",
      ""
     ],
     [
      "omarchy-shell uber-notebook lock <id> <true|false>",
      "Locks the page (it can be read but not changed) or unlocks it.",
      "lock is on the panel agent's list of allowed changes, so the panel agent can also unlock a page. false, no, off and 0 count as false; anything else counts as true."
     ],
     [
      "omarchy-shell uber-notebook favorite <id> <true|false>",
      "Adds the page to Favorites or takes it out.",
      ""
     ],
     [
      "omarchy-shell uber-notebook trashed",
      "Lists what's in the trash: id, title, the page it was in, and when it was trashed.",
      ""
     ],
     [
      "omarchy-shell uber-notebook restore <id>",
      "Takes a page out of the trash and puts it back where it was.",
      ""
     ],
     [
      "omarchy-shell uber-notebook duplicate <id>",
      "Copies the page, and the pages inside it, right after the original.",
      ""
     ],
     [
      "omarchy-shell uber-notebook history <id>",
      "Lists the page's saved versions, newest first: name and when it was saved.",
      "The first time, it can answer \"reading its history: ask again in a moment\"."
     ],
     [
      "omarchy-shell uber-notebook version <id> <name>",
      "Returns one saved version of the page as Markdown.",
      "This isn't the app's version; for that, use appVersion."
     ],
     [
      "omarchy-shell uber-notebook restoreVersion <id> <name>",
      "Restores the page to that version. The current page is saved in its history first.",
      ""
     ],
     [
      "omarchy-shell uber-notebook check <page id> <block id> <true|false>",
      "Checks or unchecks a to-do.",
      ""
     ],
     [
      "omarchy-shell uber-notebook color <page id> <block id> <color>",
      "Sets a block's color: gray, brown, orange, yellow, green, blue, purple, pink, red, or a hex such as #ff8800. Add _background for the background, or use \"\" for none.",
      ""
     ],
     [
      "omarchy-shell uber-notebook removeBlock <page id> <block id>",
      "Removes the block, and the blocks inside it, from the page. The page as it was is saved in its history.",
      "Refused for a block that holds columns, and for a block with a page inside it."
     ],
     [
      "omarchy-shell uber-notebook board <page id> <block id> <action> <a> <b>",
      "Changes a board. Actions: add <text> <column>, move <card> <column>, edit <card> <text>, remove <card>, addColumn <name>, renameColumn <column> <name>, removeColumn <column>, height <px>, columnWidth <column> <px>, cardColor <card> <color>, columnColor <column> <color>. A card or column can be given by its id or its text.",
      ""
     ],
     [
      "omarchy-shell uber-notebook picture <page id> <block id> <width> <align>",
      "Sets a picture's width (15 to 100 percent of the page) and alignment (left, center or right). \"\" keeps either one.",
      ""
     ],
     [
      "omarchy-shell uber-notebook addGallery <page id> <pictures> <columns>",
      "Adds a gallery at the end of the page. pictures is a list of full paths (one per line or separated by |) or a folder. columns is 2, 3 or 4; anything else gives 3.",
      "At most 200 pictures. The panel agent can use pictures from its own folder, its own generated pictures, or ones you approve. It can't use a folder from outside its own."
     ],
     [
      "omarchy-shell uber-notebook gallery <page id> <block id> <action> <a> <b>",
      "Changes a gallery. Actions: add <pictures or folder>, remove <n>, move <n> <to>, caption <n> <text>, columns <2|3|4>, height <px>. A picture can be given by its place (1 is first) or its src.",
      "For the panel agent, the pictures for add follow the same file rules as addGallery."
     ],
     [
      "omarchy-shell uber-notebook setLink <page id> <block id> <link>",
      "Changes a bookmark's link (and reads its page again), or points a page link at another page by id or title.",
      "For the panel agent, the bookmark keeps only the link; its page is read only from a site you allowed, or after you're asked."
     ],
     [
      "omarchy-shell uber-notebook attach <page id> <file>",
      "Copies a file into Pages and puts it at the end of the page: a picture, a video, an .eml email, a PDF or any other file.",
      "Refused for a locked page. The panel agent can use a file from its own folder (or its own generated pictures), or one you approve."
     ],
     [
      "omarchy-shell uber-notebook bookmark <page id> <url>",
      "Adds a link at the end of the page as a card with its title, a line of text and its picture.",
      "A bare address like example.com/guide gets https:// added. For the panel agent, the site is contacted only if you allowed it, or after you're asked."
     ],
     [
      "omarchy-shell uber-notebook editContact <id or name> <field> <value>",
      "Changes someone in People. Fields: name, company, title, birthday, address, website, notes. phone and email add one (\"mobile: +1 555 123 4567\"); removePhone and removeEmail take one off.",
      "For the panel agent, emptying a field or removing a phone or email asks you first."
     ],
     [
      "omarchy-shell uber-notebook removeContact <id>",
      "Removes someone from People. It needs their id.",
      "Undo in People can bring them back while Uber Notebook is running. For the panel agent, you're asked first."
     ],
     [
      "omarchy-shell uber-notebook renameTag <tag> <new name>",
      "Renames a tag on every page that has it. Each page keeps its previous version.",
      ""
     ],
     [
      "omarchy-shell uber-notebook removeTag <tag>",
      "Takes a tag off every page and removes the #tag from the text.",
      "For the panel agent, you're asked first."
     ],
     [
      "omarchy-shell uber-notebook notebooks",
      "Lists the notebooks on the shelf: id, title, page count and when each was last modified.",
      ""
     ],
     [
      "omarchy-shell uber-notebook notebook <id>",
      "Lists a notebook's pages in order: id, n, title, day and its first words.",
      "The first time, it can answer \"reading the notebook first: run the same command again in a moment\"."
     ],
     [
      "omarchy-shell uber-notebook readNotebook <id> <page id>",
      "Returns a notebook page as Markdown.",
      ""
     ],
     [
      "omarchy-shell uber-notebook addToNotebook <id> <file.md>",
      "Adds a new page at the end of a notebook from a Markdown file.",
      "The panel agent can use it with a file from its own folder, or with your approval."
     ],
     [
      "omarchy-shell uber-notebook profiles",
      "Lists your profiles: id, name, folder, whether it's open, and whether it's the demo. Every other command works on the open profile.",
      ""
     ],
     [
      "omarchy-shell uber-notebook profile <name or id>",
      "Opens another profile. Anything open is saved first.",
      "Refused while an audio note is recording or saving. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook addProfile <name> <folder> <open>",
      "Creates a new profile with its notes in folder and opens it if open is true. A folder of \"\" uses ~/Documents/Uber Notebook <name>. The profile starts empty, with the templates.",
      "The name must be new (up to 60 characters). The folder must be a full or ~/ path and can't be the same as, inside, or around another profile's folder. If this is the first profile, \"\" means ~/Documents/Uber Notebook. Opening is refused while an audio note records. Only 30 profiles are kept, and add doesn't check the count: a 31st is reported as ok but dropped. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook renameProfile <name or id> <new name>",
      "Renames a profile.",
      "The name must be new. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook profileFolder <name or id> <folder>",
      "Points a profile at another folder for its notes. Nothing is moved.",
      "Refused for the demo, for a folder another profile uses, and, for the open profile, while an audio note records. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook removeProfile <name or id>",
      "Takes a profile off the list. Its notes stay in their folder. The open profile can't be removed.",
      "The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook demo",
      "Opens the demo profile (example pages, people, events and templates), made the first time.",
      "Refused while an audio note records. Not for the panel's agent."
     ],
     [
      "omarchy-shell uber-notebook restartDemo",
      "Starts the demo over in a new folder; the demo as it was goes to the trash.",
      "Refused while an audio note records. Not for the panel's agent."
     ],
     [
      "omarchy-shell uber-notebook backup <profile>",
      "Writes a backup (.tar.gz) to the backup folder. \"\" backs up the open profile, all puts every profile except the demo into one file, or you can give a profile's name or id.",
      "Refused while another backup or restore is running, and when no profile exists. It's written in the background, so backups shows the result. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook backups",
      "Lists the backups in the backup folder, newest first (name, file, made, size, automatic), with the folder, anything still running, and how the last one went.",
      ""
     ],
     [
      "omarchy-shell uber-notebook restoreBackup <file> <open>",
      "Restores a backup. Each profile in it comes back as a new profile in a new folder, and nothing you have now is changed. open true opens the first one.",
      "Needs a full path (/... or ~/...). Refused while another backup or restore is running. The panel agent can't use it."
     ],
     [
      "omarchy-shell uber-notebook skill",
      "Prints Uber Notebook's skill (SKILL.md) as Markdown: how an AI uses these commands.",
      ""
     ],
     [
      "omarchy-shell uber-notebook appVersion",
      "Shows the version running and whether there's a newer one: latest, updateAvailable, status, problem, when it last checked, automatic, releases, and how to install an update.",
      ""
     ],
     [
      "omarchy-shell uber-notebook checkUpdate",
      "Asks GitHub for the newest version now. appVersion shows the result a few seconds later.",
      ""
     ],
     [
      "omarchy-shell uber-notebook releaseNotes",
      "Shows what's new as Markdown: the notes for newer releases, or this version's notes from CHANGELOG.md when you're up to date.",
      ""
     ]
    ]
   },
   {
    "title": "Install and update",
    "rows": [
     [
      "omarchy plugin add https://github.com/marcho78/ubernotebook.git --enable",
      "Installs and enables Uber Notebook. There's no setup step and your Hyprland config isn't edited: shortcuts and window rules are registered while it runs.",
      ""
     ],
     [
      "Uber Notebook in the app launcher",
      "While Uber Notebook runs, it adds an Uber Notebook entry with its icon to the app launcher, which opens the window (it runs omarchy-shell uber-notebook show). The entry is removed when it stops.",
      "It's only created when nothing with that name exists, and only removed if it's still exactly what Uber Notebook made."
     ],
     [
      "omarchy bar move marcho78.uber-notebook --section left",
      "Moves the notebook icon to another section of the top bar.",
      ""
     ],
     [
      "omarchy plugin update marcho78.uber-notebook",
      "Installs a newer version. Run it in a terminal; it shows what will change and asks first. Uber Notebook never installs anything itself.",
      "This works for a git checkout. Otherwise appVersion says to reinstall from git with `omarchy plugin add <its git URL>` first."
     ],
     [
      "omarchy plugin remove marcho78.uber-notebook",
      "Uninstalls Uber Notebook. It saves anything pending, removes its shortcuts, launcher entry and agent skill links, and deletes its settings entry and plugin folder. Your notes are never touched.",
      "Your notes folders, backups (~/Documents/Uber Notebook Backups), the demo (~/.local/share/uber-notebook) and voxtype's meeting mode stay. Run `omarchy-shell uber-notebook profiles` first to see where every profile's notes are."
     ],
     [
      "voxtype config set meeting.enabled false",
      "Turns voxtype's meeting mode off again, if you turned it on for Uber Notebook's meetings.",
      ""
     ],
     [
      "omarchy voxtype install",
      "Installs voxtype, Omarchy's dictation. Uber Notebook needs it for dictation, transcribing audio notes, and meetings.",
      ""
     ]
    ]
   }
  ]
 }
]

// Every row with all the words of `query` in it (any case): [{ section,
// group, row }], in Help's order; [] for no words.
function find(query) {
  var words = String(query || "").toLowerCase().split(/\s+/).filter(function(w) { return w !== "" })
  if (!words.length) return []
  var out = []
  SECTIONS.forEach(function(s) {
    s.groups.forEach(function(g) {
      g.rows.forEach(function(r) {
        var text = (r[0] + " " + r[1] + " " + r[2] + " " + g.title + " " + s.label).toLowerCase()
        if (words.every(function(w) { return text.indexOf(w) >= 0 })) out.push({ section: s.id, group: g.title, row: r })
      })
    })
  })
  return out
}

// How many rows in all.
function count() {
  var n = 0
  SECTIONS.forEach(function(s) { s.groups.forEach(function(g) { n += g.rows.length }) })
  return n
}
