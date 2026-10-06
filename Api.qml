import QtQuick
import "Workspace.js" as Workspace
import "Templates.js" as Templates
import "Calendar.js" as Calendar
import "Dates.js" as Dates
import "Import.js" as Import
import "Markdown.js" as Markdown
import "Tags.js" as Tags
import "Collection.js" as Collection
import "Contacts.js" as Contacts
import "Blocks.js" as Blocks
import "Board.js" as Board
import "Files.js" as Files
import "Bookmark.js" as Bookmark
import "Permissions.js" as Permissions
import "Library.js" as Library
import "Profiles.js" as Profiles
import "Defaults.js" as Defaults

// Uber Notebook's commands for AI agents and scripts: `omarchy-shell uber-notebook
// <command>` (Service.qml hands them on). They work on the same pages as the
// window, through the same store, so what they add shows up as you watch,
// links and reminders work, and nothing but the app writes its files.
//
// Every command answers at once, in JSON ({ ok: false, error } when it
// can't), except `read`, which gives the page as Markdown. Content comes in
// as a Markdown file, by its path: arguments are short, and agents write
// Markdown well. Commands add, append and put pages in the trash; nothing is
// deleted for good, and a locked page isn't changed.
QtObject {
  id: api

  property var workspace: null
  // Store.qml: reads a file now (readNow), and where home is.
  property var files: null
  // The window, while there is one: the page you're on is written before a
  // command changes pages, and the page open in it takes what's added to it
  // itself, so that's in its Undo.
  property var ui: null
  // The Inbox: where pages go when a command doesn't say (a setting, so it
  // stays the same page when you rename or move it).
  property string inbox: ""
  signal inboxMade(string id)
  // No profile yet (the first run): nothing to work on until one's made.
  property bool noProfile: false
  // Profiles.qml: notes kept apart, each a folder of its own; the commands
  // work on the open one.
  property var profiles: null
  // Settings as they are now (Service.qml's), for `preferences`.
  property var settings: null
  // Whether there's a newer Uber Notebook (Updates.qml), and backups (Backups.qml).
  property var updates: null
  property var backups: null

  readonly property int maxBytes: 2 * 1024 * 1024
  // While an agent works in the panel (Service.qml: Scope.js), what it may do.
  property var agentScope: null
  // That scope while the command going now is the panel's agent's (its
  // uber-notebook-agent commands, Service.qml); null for yours, a script's
  // or a terminal's agent's.
  property var caller: null
  // Files a command is given, read for it ("max:path" -> { text, error, at,
  // started }; readGiven): never there and then (one that never ends would
  // hold up the shell), but by the archive helper, which reads only a plain
  // file, not a link, at most so many bytes; asked again, the command uses
  // that. At most maxReading at a time, maxKept kept, maxKeptChars of text;
  // a read is kept two minutes, and none from before an agent began or
  // ended its work (readsGen).
  property var prefetched: ({})
  property int reading: 0
  property int readsGen: 0
  readonly property int maxReading: 4
  readonly property int maxKept: 32
  readonly property real maxKeptChars: 48 * 1024 * 1024
  onAgentScopeChanged: { prefetched = ({}); readsGen++ }

  // A link an agent puts on a page while it works: kept as its link, and
  // its page read for it only from a site you've let it have contacted
  // (Settings → AI: Permissions.js); any other https site is asked about in
  // the panel first (Allow once, Always, No: DocView.askAgentPermission).
  // What the command says of it.
  function agentLink(id, url) {
    var who = caller ? String(caller.id || "") : ""
    var host = Permissions.hostOf(url)
    if (!who || !host) return "added as its link only: the card reads its page when you ask"
    var list = settings && settings.agentPermissions ? settings.agentPermissions : []
    // (Onto the card in the profile it was added in: another opened by the
    // time it's read, nothing.)
    var got = inThisFolder(function(data) {
      if (!data || (!data.title && !data.description && !data.image)) return
      api.editPageNow(id, function(p) {
        var changed = false
        for (var k in p.blocks) {
          var x = p.blocks[k]
          if (x.type !== "bookmark" || !x.data || x.data.url !== url || x.data.title || x.data.description || x.data.image) continue
          x.data = Blocks.cleanData("bookmark", data)
          changed = true
        }
        return changed ? undefined : false
      }, true)
    })
    var start = inThisFolder(function(hosts) { api.workspace.fetchBookmarkWithin(url, hosts, got) })
    function read(hosts) { start(hosts) }
    if (Permissions.allowed(list, who, "contact", host)) {
      read(Permissions.clean(list).filter(function(r) { return r.agent === who && r.action === "contact" }).map(function(r) { return r.target }))
      return "its page is being read (" + host + " is a site you've let it contact); the card shows it in a moment"
    }
    // (The whole link shown: what it would send there is in it too. Asked
    // for that link, in the conversation that added it: another link to the
    // same site is asked about itself.)
    viewDoes("askAgentPermission", { key: "contact " + (caller.talk || "") + " " + url, agent: who, action: "contact", target: host,
      why: "to get a link's title and picture", detail: url, talk: caller.talk || "", grants: caller.grants || null, run: read })
    return "added as its link only: the user is asked in the panel before Uber Notebook contacts " + host
  }

  // A removal the panel's agent asks for (`kind`: "trash", "contact",
  // "contact detail", "event", "tag"; `item`: which one, its id; `what`:
  // what it is, in words): done at once if it may (pages to the trash, where
  // they can be put back: Always, kept in settings; a person, a detail of
  // one, an event or a tag, which have no trash: for this conversation, its
  // scope's grants; a yes to taking people out covers their details, not
  // the other way round), else asked in the panel first, one question for
  // each thing, and done when you say yes. Yours, a script's, a terminal's
  // agent's: as always.
  // A value with nothing in it but blanks, punctuation and what can't be
  // seen ("", ".", "-", a control character, a no-break space, the
  // invisible tag letters): what it's put in, emptied. Any letter, digit or
  // symbol, in any script (Khmer, Amharic, ☕, ①), is something.
  function blankish(v) {
    var t = String(v || "")
    // (Spaces, controls, format and invisible characters, blank lookalikes;
    // variation selectors and the tag letters, U+E0000 to U+E01EF.)
    t = t.replace(/[\u0000-\u0020\u007f-\u00a0\u00ad\u034f\u061c\u115f\u1160\u1680\u17b4\u17b5\u180b-\u180f\u2000-\u200f\u2028-\u202f\u205f-\u206f\u2800\u3000\u3164\ufe00-\ufe0f\ufeff\uffa0\ufff0-\ufffb]/g, "")
    t = t.replace(/\udb40[\udc00-\uddef]|\ud834[\udd73-\udd7a]/g, "")
    // (Punctuation: dots, commas, dashes, quotes, brackets and the like,
    // Latin and general, CJK and full-width. A symbol ($, #, •, §) is
    // something.)
    t = t.replace(/[!"'(),\-.\/:;?\[\\\]_`{}*\u00a1\u00ab\u00b7\u00bb\u00bf\u2010-\u2015\u2018-\u201f\u2026\u2039\u203a\u3001-\u3003\u3008-\u3011\u3014-\u301f\u30fb\uff01\uff02\uff07-\uff0f\uff1a\uff1b\uff1f\uff3b-\uff3d\uff3f\uff40\uff5b\uff5d\uff5f-\uff65]/g, "")
    return t === ""
  }
  function agentRemoval(kind, item, what, doIt) {
    if (!caller) return doIt()
    var who = String(caller.id || "")
    var grants = caller.grants || {}
    var list = settings && settings.agentPermissions ? settings.agentPermissions : []
    if (kind === "trash" && Permissions.allowed(list, who, "trash", "pages")) return doIt()
    if (grants["remove " + kind] === true) return doIt()
    if (/ detail$/.test(kind) && grants["remove " + kind.replace(/ detail$/, "")] === true) return doIt()
    var asked = viewDoes("askAgentPermission", {
      key: "remove " + kind + " " + (caller.talk || "") + " " + item, agent: who, text: what,
      action: kind === "trash" ? "trash" : "", target: kind === "trash" ? "pages" : "",
      always: kind === "trash" ? "Always let it trash pages" : "",
      grant: kind === "trash" ? "" : "remove " + kind, conversation: kind === "trash" ? "" : "Allow for this conversation",
      talk: caller.talk || "", grants: caller.grants || null,
      run: function() { doIt() }
    })
    if (asked !== true) return fail("not without the user's yes, and they can't be asked now")
    return answer({ ok: true, asked: true, note: "the user is asked in the panel first: it's done when they say yes (no need to run it again)" })
  }

  function answer(o) { return JSON.stringify(o) }
  function fail(message) { return JSON.stringify({ ok: false, error: message }) }

  function unready() {
    if (noProfile) return "Uber Notebook has no profile yet: make one with addProfile (or the user can, opening Uber Notebook)"
    // (All of it: its pages, People and the calendar, of the profile open now.)
    if (!workspace || !workspace.ready || !workspace.contactsLoaded || !workspace.calendarLoaded) return "Uber Notebook's pages aren't loaded yet: try again in a moment"
    return ""
  }

  function live(id) {
    var ix = workspace.index
    return Workspace.isUuid(id) && !!ix.pages[id] && !Workspace.inTrash(ix, id)
  }

  function where(id) {
    var d = Workspace.describe(workspace.index, id)
    return d ? (d.path ? d.path + " / " : "") + d.title : ""
  }

  // The page you're on in the window, written first (so it's what's read,
  // and nothing of yours is lost to what a command writes).
  function writeOpen() {
    if (ui && typeof ui.saveNow === "function") ui.saveNow()
  }

  // The page as it is, kept in its history before a command changes it
  // (what's being written in the window too).
  function keep(id) {
    writeOpen()
    workspace.keepVersion(id, "command", true)
  }

  function viewDoes(what, a, b) {
    return ui && typeof ui[what] === "function" ? ui[what](a, b) : false
  }

  // A block of a page by its id (a UUID that's the page's own: never
  // anything an object has by itself, like __proto__), or null.
  function blockOf(page, block) {
    var id = String(block || "")
    return page && page.blocks && Workspace.isUuid(id) && Object.prototype.hasOwnProperty.call(page.blocks, id) ? page.blocks[id] : null
  }

  // A Markdown file's text: { text } or { error } (readGiven).
  function readMarkdown(path) { return readGiven(path, maxBytes, "give the Markdown file's full path") }

  // A file given to a command, read by the helper: { text } or { error }.
  // The first time it's read in the background, and the command is told to
  // run again (`needed`: what to say when the path isn't a full one).
  function readGiven(path, max, needed) {
    var p = String(path || "").trim()
    if (p.indexOf("~/") === 0 && files && files.home) p = files.home + p.slice(1)
    if (!p || p.charAt(0) !== "/" || /[\u0000-\u001f]/.test(p)) return { error: needed }
    if (!files || typeof files.helper !== "function") return { error: "couldn't read " + p }
    // (The panel's agent's: only from its folder, every step through no link.)
    var within = caller && caller.dir ? String(caller.dir) : ""
    var key = max + ":" + within + ":" + p
    var got = keptRead(key)
    // (A helper that answers at once, as in the tests, has it already.)
    if (!got) { startRead(key, p, max, within); got = keptRead(key) }
    if (got && got.at) {
      delete prefetched[key]
      return got.error ? { error: "couldn't read " + p + ": " + got.error } : { text: got.text }
    }
    if (got) return { error: "reading that file first (only a plain file, at most " + Math.round(max / 1048576) + " MB): run the same command again in a moment" }
    return { error: "Uber Notebook is reading other files: run the same command again in a moment" }
  }
  // What was read for `key` (or is being read), or null: none, or kept too
  // long (a read two minutes old, or one a minute in the reading, goes).
  function keptRead(key) {
    if (!Object.prototype.hasOwnProperty.call(prefetched, key)) return null
    var e = prefetched[key]
    var now = Date.now()
    if ((e.at && now - e.at >= 120000) || (!e.at && now - e.started >= 60000)) { delete prefetched[key]; return null }
    return e
  }
  function startRead(key, p, max, within) {
    var keys = Object.keys(prefetched)
    var chars = 0
    keys.forEach(function(k) { var e = prefetched[k]; if (e && typeof e.text === "string") chars += e.text.length })
    if (reading >= maxReading || keys.length >= maxKept || chars >= maxKeptChars) return
    var gen = readsGen
    prefetched[key] = { at: 0, started: Date.now() }
    reading++
    // (Its answer is JSON: each character of the file at most six there.)
    files.helper(["read", String(max), p].concat(within ? [within] : []), function(ok, out) {
      reading = Math.max(0, reading - 1)
      if (gen !== readsGen) return
      var r = null
      try { r = JSON.parse(String(out || "")) } catch (e) { r = null }
      prefetched[key] = r && r.ok && typeof r.text === "string" ? { text: r.text, at: Date.now() }
        : { error: r && r.error ? String(r.error).slice(0, 200) : "it couldn't be read", at: Date.now() }
    }, { timeoutMs: 20000, maxBytes: 6 * max + 4096 })
  }

  // Markdown as blocks, "[[Page title]]" a link to the page called that.
  function blocksOf(text, titleFromHeading) {
    return Import.fromMarkdown(text, {
      wiki: function(name) { return Workspace.pageNamed(api.workspace.index, name) },
      // ```contact: a person by id, else the best match for a name, an email, a number.
      contact: function(q) { var c = api.workspace.contactById(q) || Contacts.find(api.workspace.contacts, q, 1)[0]; return c ? c.id : "" },
      // ```event: one that's on the calendar.
      event: function(id) { return !!Calendar.byId(api.workspace.calendar, id) }
    }, { titleFromHeading: titleFromHeading })
  }

  // ---- the commands ---------------------------------------------------------------------------

  function help() {
    return answer({
      ok: true,
      app: "Uber Notebook (Omarchy's notes app): its Pages, a tree of pages made of blocks",
      run: "omarchy-shell uber-notebook <command> [arguments]",
      commands: [
        { use: "list", does: "every page: id, title, icon, path (the pages it's inside)" },
        { use: "find <words>", does: "pages with all the words in their title or text, best first, with a snippet" },
        { use: "read <id>", does: "the page as Markdown (pages it links to as uber-notebook://page/<id>)" },
        { use: "add <title> <file.md>", does: "a new page in the Inbox from a Markdown file; an empty title takes the file's first # heading" },
        { use: "addTo <page id> <title> <file.md>", does: "a new page inside that page (\"\" for the top of Pages)" },
        { use: "append <id> <file.md>", does: "the Markdown added at the end of a page" },
        { use: "blocks <id>", does: "the page's blocks, in order: id, type, depth (how far inside other blocks), text (Markdown)" },
        { use: "replace <page id> <block id> <file.md>", does: "the Markdown in place of that block and the blocks inside it" },
        { use: "insertAfter <page id> <block id> <file.md>", does: "the Markdown after that block (and the blocks inside it), as deep as it is" },
        { use: "trash <id>", does: "the page (and the pages in it) to the trash, where it can be put back" },
        { use: "tags", does: "every tag: tag, pages, blocks (how many have it)" },
        { use: "library <kind> <words>", does: "what's been put on the pages (the Library), newest first: kind (link, file, video, picture, audio, meeting, sketch, person, email; \"\" for all), title, detail, url (a link's), file (its path on disk), page, pageTitle, block, added; words (\"\" for all) narrow it to those with all of them in their title, link or page" },
        { use: "contacts <words>", does: "the user's people (People): id, name, company, title, phones, emails, birthday; words (\"\" for everyone) narrow it to a name, company, email or number" },
        { use: "contact <id or name>", does: "one person with everything kept about them (address, website, notes) and the pages they're named on" },
        { use: "addContact <name> <phone> <email>", does: "someone new in People (\"\" for what you don't know); one with that email or number already there is filled in instead" },
        { use: "importContacts <file>", does: "the people in a .vcf (vCard) or .csv file put in People; those already there are filled in, not added twice" },
        { use: "tagged <tag>", does: "every block with the tag: page id, page title, block id, type, text (Markdown), checked" },
        { use: "projects", does: "every project (not the archive's): id, title, status, due, progress (to-dos done of all, its pages' too), overdue" },
        { use: "project <id> <status> <due>", does: "makes the page a project, or changes it: status planning, active, paused or done (\"\" keeps it); due a date like 2026-10-12, \"\" for none, \"-\" to keep it; status \"none\" makes it a page again" },
        { use: "events <from> <to>", does: "what's on the user's calendar from to (2026-10-05; \"\" \"\" for today and the week on), and the dates in their notes (reminders, projects' due dates)" },
        { use: "addEvent <what and when> <repeat>", does: "puts an event on the calendar: \"Dentist oct 12 3pm\", \"Standup mon 9:30-9:45\"; repeat daily, weekdays, weekly, monthly, yearly or \"\"" },
        { use: "removeEvent <id>", does: "takes an event off the calendar (all of it, if it repeats)" },
        { use: "templates", does: "lists the user's templates: [{ id, title, icon, description (what it's for), pages }]" },
        { use: "addTemplate <title> <file.md> <description>", does: "a new template from Markdown ({{date}}, {{weekday}}, {{time}}, {{month}}, {{year}}, {{week}} are filled in when it's used); description: what it's for (\"\" for none)" },
        { use: "describeTemplate <template> <text>", does: "what a template's for, in a line (Templates shows it on its card)" },
        { use: "preferences", does: "every setting there is: key, value, kind, choices, range; change one with: set <key> <value>" },
        { use: "fromTemplate <template> <title> <parent>", does: "a new page from a template (its name or id), called title (\"\" for the template's), in parent (\"\" the Inbox, \"top\" the top of Pages); {{date}} and the like in it are filled in" },
        { use: "archive <id>", does: "puts the page (and the pages in it) away in the archive; unarchive <id> brings it back" },
        { use: "tagColor <tag> <color>", does: "the tag's color: gray, brown, orange, yellow, green, blue, purple, pink, red, a hex like #ff8800, or \"\" for none (a tag with none takes the color of the tag it's in: #work/acme, #work's)" },
        { use: "rename <id> <title>", does: "the page's title" },
        { use: "move <id> <parent> <position>", does: "the page inside another (\"top\" for the top of Pages), at a place among the pages there (0 is first, \"\" the end)" },
        { use: "icon <id> <emoji>", does: "the page's icon: one emoji, \"\" for none" },
        { use: "cover <id> <cover>", does: "the page's cover: gradient:0 to gradient:11, \"\" for none" },
        { use: "lock <id> <true|false>", does: "locks the page (it reads, but nothing changes it) or unlocks it" },
        { use: "favorite <id> <true|false>", does: "the page in Favorites, or out of them" },
        { use: "trashed", does: "what's in the trash: id, title, in (the page it was in), trashed" },
        { use: "restore <id>", does: "a page out of the trash, back where it was" },
        { use: "duplicate <id>", does: "a copy of the page (and the pages in it), right after it" },
        { use: "makeTemplate <id>", does: "a copy of the page (and the pages in it) kept as one of the user's templates" },
        { use: "history <id>", does: "the page's kept versions, newest first: name, kept (when)" },
        { use: "version <id> <name>", does: "one kept version, as Markdown" },
        { use: "restoreVersion <id> <name>", does: "the page as that version was (the page as it is now kept in its history first)" },
        { use: "check <page id> <block id> <true|false>", does: "ticks a to-do, or unticks it" },
        { use: "color <page id> <block id> <color>", does: "a block's color: gray, brown, orange, yellow, green, blue, purple, pink or red (its text), with _background for behind it (\"blue_background\"), \"\" for none" },
        { use: "removeBlock <page id> <block id>", does: "takes the block (and the blocks inside it) off the page; the page before is kept in its history" },
        { use: "board <page id> <block id> <action> <a> <b>", does: "changes a board: add <text> <column> (\"\" the first), move <card> <column>, edit <card> <text>, remove <card>, addColumn <name>, renameColumn <column> <name>, removeColumn <column>, height <px, 0 as tall as its cards>, columnWidth <column> <px, 0 as fits>, cardColor <card> <color>, columnColor <column> <color> (blue, #ff8800, either with _background, \"\" none); a card or column by its id or its text (blocks gives them)" },
        { use: "picture <page id> <block id> <width> <align>", does: "a picture's size (width, a percent of the page's: 15 to 100) and where it sits (left, center, right); \"\" keeps either" },
        { use: "addGallery <page id> <pictures> <columns>", does: "a gallery at the end of the page: pictures' full paths, one a line (or | between them), or a folder (its pictures); 2, 3 or 4 to a row. It shows in a moment" },
        { use: "gallery <page id> <block id> <action> <a> <b>", does: "changes a gallery: add <pictures or a folder>, remove <n>, move <n> <to>, caption <n> <text>, columns <2|3|4>, height <px, 0 for as they were>; a picture by its place (1 is first) or its src" },
        { use: "setLink <page id> <block id> <link>", does: "a bookmark's link (its page read again), or a link to a page's page (its id or title)" },
        { use: "attach <page id> <file>", does: "a file at the end of the page, copied into Pages: a picture, a video, an email (.eml, shown with its subject, who and attachments), or any file (a PDF shown page by page); it shows in a moment" },
        { use: "bookmark <page id> <url>", does: "a link at the end of the page as a card with its title, a line and its picture; it shows in a moment" },
        { use: "editEvent <id> <field> <value>", does: "changes an event: title, when (\"fri 3pm\", \"oct 12 9:30-10:00\"), start or end (2026-10-05, 2026-10-05T09:30), allDay, place, notes, repeat (daily, weekdays, weekly, monthly, yearly, \"\" for not), alert (minutes before: 0, 5, 10, 15, 30, 60, 120, 1440, or none), color" },
        { use: "editContact <id or name> <field> <value>", does: "changes someone in People: name, company, title, birthday (1990-04-12, --04-12), address, website, notes; phone and email add one (\"mobile: +1 555 123 4567\"); removePhone and removeEmail take one off" },
        { use: "removeContact <id>", does: "takes someone out of People" },
        { use: "importCalendar <file.ics>", does: "an .ics file's events (a booking's, an invitation's, another calendar's) on the calendar; those there already are skipped: { added, skipped }" },
        { use: "renameTag <tag> <new name>", does: "renames a tag on every page with it" },
        { use: "removeTag <tag>", does: "takes a tag off every page: the #tag comes out of the text, as Remove tag does in the window" },
        { use: "notebooks", does: "the notebooks on the shelf (Notebooks, the handwritten-style space): id, title, pages, modified" },
        { use: "notebook <id>", does: "a notebook's pages in order: id, n, title, day, text (its first words)" },
        { use: "readNotebook <id> <page id>", does: "a notebook's page as Markdown" },
        { use: "addToNotebook <id> <file.md>", does: "a new page at the end of a notebook from a Markdown file" },
        { use: "open <id>", does: "shows the page in Uber Notebook's window" },
        { use: "profiles", does: "the user's profiles (notes kept apart: personal, work, the demo...): id, name, folder, open, demo; every other command works on the open one" },
        { use: "profile <name or id>", does: "opens another profile (only when the user asks)" },
        { use: "addProfile <name> <folder> <open>", does: "a new profile, its notes in folder (\"\" for ~/Documents/Uber Notebook <name>; an empty folder starts fresh, one with Uber Notebook's notes opens them), opened if open is true; it starts empty, with the templates" },
        { use: "renameProfile <name or id> <new name>", does: "a profile's name" },
        { use: "profileFolder <name or id> <folder>", does: "a profile's notes looked for in another folder (nothing is moved)" },
        { use: "removeProfile <name or id>", does: "takes a profile off the list (not the open one); its notes stay in their folder" },
        { use: "demo", does: "opens the demo profile (example pages, people, events, templates), made the first time; restartDemo makes it new again, the old one to the trash (only when the user asks)" },
        { use: "backup <profile>", does: "a backup (a .tar.gz in the backup folder) of the open profile (\"\"), every profile (all; not the demo), or one by its name or id; written in a moment" },
        { use: "backups", does: "the backups in the backup folder, newest first: name, file, made, size, automatic; and how the last one went (last, lastFailed, working)" },
        { use: "restoreBackup <file> <open>", does: "a backup put back (only when the user asks): each profile in it a new profile in a new folder (nothing there is changed); open true opens the first" },
        { use: "skill", does: "this skill (SKILL.md) as Markdown: how an AI uses these commands; give it to any AI that can run commands on this computer" },
        { use: "appVersion", does: "the version running, and whether there's a newer one: latest, updateAvailable, status (current, available, none: no releases yet, failed), checked, releases, and update: how the user installs it (a command they run in a terminal; Uber Notebook doesn't install anything itself)" },
        { use: "checkUpdate", does: "asks GitHub for the newest version now; appVersion says what it found a few seconds later" },
        { use: "releaseNotes", does: "what's new, as Markdown: the newer releases' notes, or (up to date) this version's" }
      ],
      fences: "read gives (and add, append, replace and insertAfter take) these as fenced code: "
        + "```board (## a column, - a card under it), ```bookmark (a link), ```contact (someone in People: their name, email or id), "
        + "```agenda (a day's events: 2026-10-05 or today), ```event (an event's id), ```link (a link to a page: its id or title), "
        + "```gallery (columns: 3, height: 240, then ![caption](assets/...) a picture a line, pictures already in Pages/assets)",
      markdown: "Headings, lists, - [ ] to-dos, code blocks with their language, > [!NOTE] callouts, "
        + "[[Page title]] (a link to that page), #tag (a tag), [@Fri 2 Oct](uber-notebook://date/2026-10-02) (a date) and "
        + "[\u23f0 Fri 2 Oct 9:30](uber-notebook://remind/2026-10-02T09:30) (a reminder: a notification then)"
    })
  }

  function list() {
    var not = unready()
    if (not) return fail(not)
    return answer(Workspace.allPages(workspace.index))
  }

  function find(words) {
    var not = unready()
    if (not) return fail(not)
    var query = String(words || "")
    if (Workspace.terms(query).length === 0) return fail("find needs words to look for")
    var ix = workspace.index
    var found = []
    for (var id in ix.pages) {
      if (Workspace.inTrash(ix, id) || Workspace.inTemplates(ix, id)) continue
      var e = ix.pages[id]
      var text = workspace.texts[id] || e.title || ""
      var score = Workspace.score(e.title || "Untitled", text, query)
      if (score <= 0) continue
      var d = Workspace.describe(ix, id)
      var s = Workspace.snippet(text.slice(String(e.title || "").length), query)
      d.snippet = s.before + s.match + s.after
      d.score = score
      found.push(d)
    }
    found.sort(function(a, b) { return b.score - a.score || (a.modified < b.modified ? 1 : -1) })
    return answer(found.slice(0, 50).map(function(d) { delete d.score; return d }))
  }

  // ---- projects and the archive ---------------------------------------------------------------

  function projects() {
    var not = unready()
    if (not) return fail(not)
    return answer(Workspace.projectList(workspace.index, new Date()).map(function(p) {
      return { id: p.id, title: p.title || "Untitled", status: p.status, due: p.due, progress: p.progress.done + "/" + p.progress.total, overdue: p.overdue, path: where(p.id) }
    }))
  }

  // A page made a project (or changed, or a page again: status "none").
  function project(id, status, due) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var st = String(status || "").trim().toLowerCase()
    var d = String(due === undefined ? "-" : due).trim()
    if (st && st !== "none" && !/^(planning|active|paused|done)$/.test(st)) return fail("a status is planning, active, paused or done (or none: not a project)")
    if (d && d !== "-" && !/^\d{4}-\d{2}-\d{2}$/.test(d)) return fail("a due date is like 2026-10-12, \"\" for none, \"-\" to keep it")
    keep(id)
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    if (page.format && page.format.locked) return fail("that page is locked: unlock it in Uber Notebook first")
    var had = page.project || { status: "active", due: "" }
    var next = st === "none" ? null : Workspace.cleanProject({ status: st || had.status, due: d === "-" ? had.due : d })
    var took = viewDoes("setProjectOfOpenPage", id, next)
    if (took === "locked") return fail("that page is locked: unlock it in Uber Notebook first")
    if (took !== true) {
      if (next) page.project = next
      else delete page.project
      page.modified = new Date().toISOString()
      workspace.savePage(page)
      workspace.pageChanged(id)
    }
    return answer({ ok: true, id: id, project: next })
  }

  function archive(id, on) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id) && !(on === false && Workspace.isUuid(id) && workspace.index.pages[id])) return fail("there's no page with that id (list or find gives them)")
    workspace.setArchived(id, on !== false)
    return answer({ ok: true, id: id, archived: on !== false })
  }

  // What's been put on the pages (the Library), newest first: [{ kind,
  // title, detail, url, file, page, pageTitle, block, added }].
  function library(kind, words) {
    var not = unready()
    if (not) return fail(not)
    var k = String(kind || "").trim().toLowerCase().replace(/s$/, "")
    if (k === "all") k = ""
    if (k === "people") k = "person"
    if (k && !Collection.isKind(k)) return fail("a kind is one of " + Collection.KINDS.map(function(x) { return x.id }).join(", ") + ", or \"\" for all")
    return answer(Collection.filter(Workspace.collected(workspace.index), k, words).slice(0, 500).map(function(r) {
      var o = { kind: r.kind, title: r.title, page: r.page, pageTitle: r.pageTitle, block: r.block }
      var d = Collection.detail(r)
      if (d) o.detail = d
      if (r.url) o.url = r.url
      if (r.src) o.file = workspace.folder + "/" + r.src
      if (r.person) o.person = r.person
      if (r.at) o.added = r.at
      return o
    }))
  }

  // ---- people ----

  function personOut(c, full) {
    var o = { id: c.id, name: Contacts.nameOf(c), company: c.company, title: c.title,
      phones: c.phones.map(function(p) { return { label: p.label, number: p.value } }),
      emails: c.emails.map(function(e) { return { label: e.label, email: e.value } }), birthday: c.birthday }
    if (full) {
      o.address = c.address
      o.website = c.website
      o.notes = c.notes
      var seen = {}
      o.pages = Workspace.collected(workspace.index).filter(function(r) {
        if (r.kind !== "person" || r.person !== c.id || seen[r.page]) return false
        seen[r.page] = true
        return true
      }).map(function(r) { return { id: r.page, title: r.pageTitle } })
    }
    return o
  }

  // The user's people: [{ id, name, company, title, phones, emails, birthday }].
  function contacts(words) {
    var not = unready()
    if (not) return fail(not)
    return answer(Contacts.find(workspace.contacts, words, 500).map(function(c) { return personOut(c, false) }))
  }

  // One person: by id, else the best match for a name (or email, or number).
  function contact(which) {
    var not = unready()
    if (not) return fail(not)
    var q = String(which || "").trim()
    if (!q) return fail("give someone's id or name: contact \"Sam\" (contacts lists everyone)")
    var c = workspace.contactById(q) || Contacts.find(workspace.contacts, q, 1)[0] || null
    if (!c) return fail("there's no one like \"" + q + "\" in People (contacts lists everyone)")
    return answer(personOut(c, true))
  }

  // Someone new, or one already there (the same email or number) filled in.
  function addContact(name, phone, email) {
    var not = unready()
    if (not) return fail(not)
    var p = { name: String(name || ""), phones: phone ? [{ label: "mobile", value: String(phone) }] : [], emails: email ? [{ label: "", value: String(email) }] : [] }
    if (phone && !Contacts.cleanPhone(phone)) return fail("that isn't a phone number: digits, spaces, + ( ) - . (and ext 12)")
    if (email && !Contacts.cleanEmail(email)) return fail("that isn't an email")
    if (!Contacts.cleanContact(p)) return fail("give at least a name, a number or an email")
    var before = workspace.contacts.contacts.map(function(c) { return c.id })
    var r = Contacts.merge(workspace.contacts, [p], new Date())
    workspace.setContacts(r.book)
    var made = workspace.contacts.contacts.filter(function(c) { return before.indexOf(c.id) < 0 })[0]
    var who = made || Contacts.find(workspace.contacts, phone || email || name, 1)[0]
    return answer({ ok: true, id: who ? who.id : "", added: r.added === 1, filledIn: r.updated === 1 })
  }

  // The people in a .vcf or .csv file, put in People.
  function importContacts(path) {
    var not = unready()
    if (not) return fail(not)
    var got = readGiven(path, 32 * 1024 * 1024, "give the file's full path (a .vcf or a .csv)")
    if (got.error) return fail(got.error)
    var p = String(path || "").trim()
    var people = Contacts.fromFile(p, got.text)
    if (!people.length) return fail("there are no contacts in " + p + " (a .vcf or a .csv with a header row)")
    var r = Contacts.merge(workspace.contacts, people, new Date())
    workspace.setContacts(r.book)
    return answer({ ok: true, read: people.length, added: r.added, filledIn: r.updated })
  }

  // Every tag: [{ tag, pages, blocks }].
  function tags() {
    var not = unready()
    if (not) return fail(not)
    var colors = workspace.index.tagColors || {}
    return answer(Workspace.tagList(workspace.index).map(function(t) {
      var c = Workspace.tagColorOf(colors, t.name)
      var o = { tag: t.label, name: t.name, pages: t.pages, blocks: t.blocks, color: c.color }
      if (c.from && c.from !== t.name) o.colorFrom = "#" + c.from
      return o
    }))
  }

  // A tag's color: one of Pages' ("blue"), one of your own ("#ff8800"), or "" for none.
  function tagColor(tag, color) {
    var not = unready()
    if (not) return fail(not)
    var name = Tags.clean(tag)
    if (!name) return fail("give a tag: tagColor \"#work\" blue")
    var value = String(color || "").trim().toLowerCase()
    var clean = Workspace.cleanTagColor(value)
    if (value && !clean) return fail("a color is gray, brown, orange, yellow, green, blue, purple, pink, red, a hex like #ff8800, or \"\" for none")
    workspace.setTagColor(name, clean)
    return answer({ ok: true, tag: "#" + name, color: clean })
  }

  // Every block with a tag: [{ page, title, block, type, text, checked }].
  function tagged(tag) {
    var not = unready()
    if (not) return fail(not)
    var name = Tags.clean(tag)
    if (!name) return fail("give a tag: tagged \"#idea\" (or tags, for every tag)")
    writeOpen()
    var out = []
    var ids = Workspace.pagesTagged(workspace.index, name)
    var pages = ids.map(function(id) { return workspace.readPageNow(id) })
    if (stillReading(ids)) return fail("reading pages first: run the same command again in a moment")
    ids.forEach(function(id, i) {
      var page = pages[i]
      if (!page) return
      Workspace.taggedBlocks(page, name).forEach(function(b) {
        var o = { page: id, title: page.title || "Untitled", block: b.uid, type: b.type, text: Markdown.inline(b.html) }
        if (b.type === "check") o.checked = b.checked
        out.push(o)
      })
    })
    return answer(out)
  }

  function read(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    // (A page it syncs that isn't read yet: the whole of it when it is.)
    var synced = []
    var md = Markdown.fromDocPage(page, function(pid) {
      var e = api.workspace.index.pages[pid]
      return e && !Workspace.inTrash(api.workspace.index, pid) ? { title: e.title || "Untitled", icon: e.icon, file: "uber-notebook://page/" + pid } : null
    }, { fences: true, contactOf: function(cid) { return api.workspace.contactById(cid) },
      syncedPage: function(sid) { synced.push(sid); return live(sid) ? api.workspace.readPageNow(sid) : null } })
    if (stillReading(synced)) return fail("reading a page it syncs first: run the same command again in a moment")
    return md
  }

  // A quick note (Super+Alt+N) as a page in the Inbox: its first line the
  // title, the rest Markdown (Import.quickNote).
  function quickPage(text) {
    var not = unready()
    if (not) return fail(not)
    var q = Import.quickNote(text)
    if (!q) return fail("there's nothing in it")
    var got = blocksOf(q.markdown, false)
    writeOpen()
    var into = inboxPage()
    if (!into) return fail("couldn't make the Inbox")
    var page = workspace.createPage({ parent: into, title: Workspace.cleanTitle(q.title),
      blocks: got.blocks.concat([{ type: "p", html: "", indent: 0 }]) })
    if (!page) return fail("couldn't make the page")
    placeIn(into, page.id)
    return answer({ ok: true, id: page.id, title: page.title || "Untitled", path: where(page.id) })
  }

  function add(title, path) {
    var not = unready()
    if (not) return fail(not)
    return addTo(inboxPage(), title, path)
  }

  function addTo(parent, title, path) {
    var not = unready()
    if (not) return fail(not)
    var into = String(parent || "")
    if (into === "top") into = ""
    if (into && !live(into)) return fail("there's no page with that id to put it in (\"\" is the top of Pages)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var name = String(title || "").trim()
    var got = blocksOf(md.text, name === "")
    writeOpen()
    var page = workspace.createPage({ parent: into, title: Workspace.cleanTitle(name || got.title || ""), icon: got.icon || "", project: got.project,
      blocks: got.blocks.length ? got.blocks.concat([{ type: "p", html: "", indent: 0 }]) : undefined })
    if (!page) return fail("couldn't make the page")
    if (into) placeIn(into, page.id)
    return answer({ ok: true, id: page.id, title: page.title || "Untitled", path: where(page.id) })
  }

  // ---- the calendar ----------------------------------------------------------------------------

  // What's on the calendar from `from` to `to` ("2026-10-05"; "" for today,
  // and a week on): [{ id, title, start, end, allDay, place, repeats, notes }],
  // and the dates in the user's notes ({ kind: "reminder" | "due", page, title, text, at }).
  function events(from, to) {
    var not = unready()
    if (not) return fail(not)
    var n = new Date()
    var lo = Dates.fromIso(String(from || ""))
    var a = lo ? lo.at : new Date(n.getFullYear(), n.getMonth(), n.getDate())
    var hi = Dates.fromIso(String(to || ""))
    var b = hi ? new Date(hi.at.getFullYear(), hi.at.getMonth(), hi.at.getDate() + 1) : new Date(a.getFullYear(), a.getMonth(), a.getDate() + 7)
    if (b <= a) return fail("to is before from")
    if (b - a > 400 * 86400000) return fail("at most a year and a bit at a time")
    var list = Calendar.occurrences(workspace.calendar, a, b).map(function(o) {
      return { id: o.id, title: o.title, start: o.allDay ? Calendar.dayIso(o.start) : Calendar.timeIso(o.start),
        end: o.allDay ? Calendar.dayIso(new Date(o.end.getTime() - 86400000)) : Calendar.timeIso(o.end),
        allDay: o.allDay, place: o.place, repeats: o.repeats, notes: o.page || "" }
    })
    var dated = Workspace.datedNotes(workspace.index, a, b).map(function(d) {
      return { kind: d.kind, page: d.page, title: d.title, text: d.text, at: Dates.iso(d.at, d.time) }
    })
    return answer({ events: list, notes: dated })
  }

  // An event put on the calendar: what and when, as typed ("Dentist oct 12
  // 3pm", "Standup mon 9:30-9:45"), and how it repeats ("" for not).
  function addEvent(what, repeat) {
    var not = unready()
    if (not) return fail(not)
    var q = Calendar.quick(String(what || ""), new Date())
    if (!q) return fail("there's no day or time in that (\"Dentist oct 12 3pm\")")
    if (!q.title) return fail("what is it? (\"Dentist oct 12 3pm\")")
    var r = String(repeat || "").trim().toLowerCase()
    if (r && Calendar.REPEATS.indexOf(r) < 0) return fail("repeat is daily, weekdays, weekly, monthly or yearly (\"\" for not)")
    var e = Calendar.cleanEvent({ title: q.title, start: q.start, end: q.end, allDay: q.allDay, alert: q.allDay ? -1 : 10, repeat: r ? { freq: r } : null })
    workspace.setCalendar(Calendar.withEvent(workspace.calendar, e))
    return answer({ ok: true, id: e.id, title: e.title, start: e.start, end: e.end, allDay: e.allDay, repeat: e.repeat ? e.repeat.freq : "" })
  }

  function removeEvent(id) {
    var not = unready()
    if (not) return fail(not)
    var ev = Calendar.byId(workspace.calendar, String(id || ""))
    if (!ev) return fail("there's no event with that id (events lists them)")
    return agentRemoval("event", ev.id, "take the event \u201c" + (ev.title || "Untitled") + "\u201d off the calendar", function() {
      workspace.setCalendar(Calendar.without(workspace.calendar, String(id)))
      return answer({ ok: true })
    })
  }

  // Your templates: [{ id, title, icon, pages }].
  function templates() {
    var not = unready()
    if (not) return fail(not)
    var ix = workspace.index
    return answer(Workspace.templates(ix).map(function(t) {
      return { id: t.id, title: t.title, icon: t.icon, description: t.description, pages: Workspace.withDescendants(ix, t.id).length }
    }))
  }

  // A new page from a template (by name or id), in `parent` ("" the Inbox,
  // "top" the top of Pages), called `title` (or the template's).
  function fromTemplate(template, title, parent) {
    var not = unready()
    if (not) return fail(not)
    var ix = workspace.index
    var tpl = Workspace.templateNamed(ix, template)
    if (!tpl) return fail("there's no template called that (templates lists them)")
    var into = String(parent || "")
    if (into === "top") into = ""
    else if (!into) into = inboxPage()
    if (into && !live(into)) return fail("there's no page with that id to put it in (\"\" is the Inbox, \"top\" the top of Pages)")
    writeOpen()
    var now = new Date()
    var id = workspace.pageFromTemplateNow(tpl, into, Workspace.cleanTitle(String(title || "")), function(text, html) {
      return Templates.fill(text, html, now, function(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) })
    })
    if (!id) return fail(stillReading(Workspace.withDescendants(ix, tpl)) ? "reading the template first: run the same command again in a moment" : "couldn't make the page")
    if (into) placeIn(into, id)
    return answer({ ok: true, id: id, title: ix.pages[id].title || "Untitled", path: where(id) })
  }

  function append(id, path) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var blocks = blocksOf(md.text, false).blocks
    if (blocks.length === 0) return fail("there's nothing in that file to add")
    keep(id)
    // Open in the window: it adds them itself.
    var took = viewDoes("appendToOpenPage", id, blocks)
    if (took === "locked") return fail("that page is locked: unlock it in Uber Notebook first")
    if (took === true) return answer({ ok: true, id: id, added: blocks.length })
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    if (page.format && page.format.locked) return fail("that page is locked: unlock it in Uber Notebook first")
    var n = Workspace.appendBlocks(page, blocks)
    page.modified = new Date().toISOString()
    workspace.savePage(page)
    workspace.pageChanged(id)
    return answer({ ok: true, id: id, added: n })
  }

  // A page's blocks, so a block can be changed: [{ id, type, depth, text }].
  function blocks(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    return answer(Workspace.blockList(page, Markdown.inline, function(pid) {
      var e = api.workspace.index.pages[pid]
      return e ? e.title || "Untitled" : ""
    }))
  }

  function replace(id, block, path) { return changeBlock(id, block, path, "replace") }
  function insertAfter(id, block, path) { return changeBlock(id, block, path, "after") }

  // A block (and the blocks inside it) replaced by the Markdown, or the
  // Markdown put after it, as deep as it is. Not columns (only what's in
  // them), and not a block with pages inside it, which would go with it.
  function changeBlock(id, block, path, how) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var list = blocksOf(md.text, false).blocks
    if (list.length === 0) return fail("there's nothing in that file to put in")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    if (page.format && page.format.locked) return fail("that page is locked: unlock it in Uber Notebook first")
    var spot = Workspace.locate(page, String(block || ""))
    if (!spot) return fail("there's no block with that id on the page (blocks <page id> gives them)")
    if (Workspace.isStructure(spot.block.type)) return fail("that block holds columns: change the blocks inside them instead")
    if (how === "replace") {
      for (var k = spot.at; k <= spot.end; k++) {
        if (spot.list[k].type === "page") return fail("there's a page inside that block, which would go with it: change the blocks around it instead")
      }
    }
    keep(id)
    // Open in the window: it changes the page itself, as a step you can undo.
    var took = viewDoes(how === "replace" ? "replaceInOpenPage" : "insertInOpenPage", id, { block: spot.block.uid, blocks: list })
    if (took === "locked") return fail("that page is locked: unlock it in Uber Notebook first")
    if (took !== true) {
      if (how === "replace") Workspace.putBlocks(page, spot.at, spot.end - spot.at + 1, list, spot.depth)
      else Workspace.putBlocks(page, spot.end + 1, 0, list, spot.depth)
      page.modified = new Date().toISOString()
      workspace.savePage(page)
      workspace.pageChanged(id)
    }
    return answer({ ok: true, id: id, block: spot.block.uid, added: list.length })
  }

  function trash(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail("there's no page with that id (list or find gives them)")
    var title = workspace.index.pages[id].title || "Untitled"
    return agentRemoval("trash", id, "move \u201c" + title + "\u201d (and the pages in it) to the trash", function() {
      if (!api.live(id)) return fail("there's no page with that id (list or find gives them)")
      api.writeOpen()
      if (api.viewDoes("trashPage", id) !== true) workspace.trashPage(id, false)
      return answer({ ok: true, id: id, title: title, note: "in the trash, where it can be put back" })
    })
  }

  // ---- pages: their name, place, icon, cover, lock; the trash; copies -------------------------

  readonly property string noPage: "there's no page with that id (list or find gives them)"

  // A page's file changed now: fn(page) changes it (false: nothing to do; a
  // string: what's wrong). Kept in its history first (`keepIt`); the window
  // shows it as it is now.
  // A page that couldn't be read at once: just after Uber Notebook started,
  // being read now (the same command again has it); else not readable.
  readonly property string readingFirst: "reading that page first: run the same command again in a moment"
  function notRead(id) { return workspace.isWarming(id) ? readingFirst : "couldn't read that page" }
  function stillReading(ids) { return ids.some(function(pid) { return api.workspace.isWarming(pid) }) }

  function editPageNow(id, fn, keepIt) {
    if (keepIt) keep(id)
    else writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return notRead(id)
    var r = fn(page)
    if (r === false) return ""
    if (typeof r === "string" && r) return r
    page.modified = new Date().toISOString()
    workspace.savePage(page)
    workspace.pageChanged(id)
    return ""
  }
  function lockedNote(page) { return page.format && page.format.locked ? "that page is locked: unlock it first (lock <id> false)" : "" }
  function yes(v) { var t = String(v === undefined ? "" : v).trim().toLowerCase(); return !(t === "false" || t === "no" || t === "off" || t === "0") }

  function rename(id, title) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var t = Workspace.cleanTitle(String(title || ""))
    var err = editPageNow(id, function(p) { if (lockedNote(p)) return lockedNote(p); if (p.title === t) return false; p.title = t })
    return err ? fail(err) : answer({ ok: true, id: id, title: t || "Untitled", path: where(id) })
  }

  // Under another page ("top": the top of Pages), at a place among the pages
  // there (0 is first; "" the end).
  function move(id, parent, position) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var into = String(parent || "").trim()
    if (into === "top") into = ""
    if (into && !live(into)) return fail("there's no page with that id to put it in (\"top\" is the top of Pages)")
    if (into === id || (into && Workspace.isInside(workspace.index.pages, into, id))) return fail("a page can't go inside itself")
    var pos = String(position || "").trim()
    var at = pos === "" ? -1 : Number(pos)
    if (!isFinite(at) || at < -1) return fail("position is a number (0 is first), or \"\" for the end")
    writeOpen()
    if (!workspace.movePage(id, into, Math.round(at), "")) return fail("couldn't move it there")
    return answer({ ok: true, id: id, path: where(id) })
  }

  function icon(id, emoji) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var v = String(emoji || "").trim()
    var clean = Workspace.cleanIcon(v)
    if (v && !clean) return fail("an icon is one emoji (or \"\" for none)")
    var err = editPageNow(id, function(p) { if (lockedNote(p)) return lockedNote(p); p.icon = clean })
    return err ? fail(err) : answer({ ok: true, id: id, icon: clean })
  }

  // One of Uber Notebook's covers ("gradient:0" to "gradient:11"), or "" for none.
  function cover(id, which) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var v = String(which || "").trim()
    var clean = Workspace.cleanCover(v)
    if (v && !clean) return fail("a cover is gradient:0 to gradient:11, or \"\" for none")
    var err = editPageNow(id, function(p) { if (lockedNote(p)) return lockedNote(p); p.cover = clean })
    return err ? fail(err) : answer({ ok: true, id: id, cover: clean })
  }

  // Locked: it reads, but nothing changes it (in the window or here) until it's unlocked.
  function lock(id, on) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var want = yes(on)
    var err = editPageNow(id, function(p) { p.format = Workspace.cleanFormat(p.format); if (p.format.locked === want) return false; p.format.locked = want })
    return err ? fail(err) : answer({ ok: true, id: id, locked: want })
  }

  function favorite(id, on) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var want = yes(on)
    if (workspace.isFavorite(id) !== want) workspace.toggleFavorite(id)
    return answer({ ok: true, id: id, favorite: want })
  }

  // What's in the trash: [{ id, title, path, trashed }].
  function trashed() {
    var not = unready()
    if (not) return fail(not)
    var ix = workspace.index
    return answer(Workspace.trashed(ix).map(function(id) {
      return { id: id, title: ix.pages[id].title || "Untitled", in: ix.pages[id].parent || "", trashed: ix.pages[id].modified }
    }))
  }

  // Out of the trash: back in the page it was in (or at the top).
  function restore(id) {
    var not = unready()
    if (not) return fail(not)
    var e = Workspace.isUuid(id) ? workspace.index.pages[id] : null
    if (!e || !e.trashed) return fail("there's no page with that id in the trash (trashed lists them)")
    writeOpen()
    workspace.restorePage(id, false)
    return answer({ ok: true, id: id, title: e.title || "Untitled", path: where(id) })
  }

  // Copies of a page and the pages in it: { copy's id } (`asTemplate`: kept as a template).
  function copyPages(id, asTemplate) {
    var ix = workspace.index
    var e = ix.pages[id]
    var pages = workspace.readPagesNow(Workspace.withDescendants(ix, id).filter(function(pid) { return pid === id || !Workspace.inTrash(ix, pid) }))
    if (!pages || !pages.length) return ""
    var copies = Workspace.duplicate(pages, id, new Date())
    var top = copies[0]
    if (asTemplate) { top.title = e.title || ""; if (top.format) delete top.format.locked }
    copies.forEach(function(c) {
      ix.pages[c.id] = { title: c.title, icon: c.icon, parent: "", children: [], trashed: false, created: c.created, modified: c.modified, links: null, reminders: null }
    })
    copies.forEach(function(c) {
      var parent = c.id === top.id ? (asTemplate ? "" : e.parent) : c.parent
      var at = -1
      if (c.id === top.id && !asTemplate) at = (parent ? ix.pages[parent].children : ix.top).indexOf(id) + 1
      Workspace.attach(ix, c.id, parent, at)
      c.parent = parent
      workspace.savePage(c)
    })
    if (asTemplate) ix.pages[top.id].template = true
    else if (e.parent) placeIn(e.parent, top.id)
    workspace.touched()
    return top.id
  }
  function copyFailed(id) { return stillReading(Workspace.withDescendants(workspace.index, id)) ? "reading its pages first: run the same command again in a moment" : "couldn't copy it (a page in it couldn't be read)" }
  function duplicate(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    writeOpen()
    var made = copyPages(id, false)
    return made ? answer({ ok: true, id: made, title: workspace.index.pages[made].title || "Untitled", path: where(made) }) : fail(copyFailed(id))
  }
  // A copy of the page (and the pages in it) kept as one of your templates.
  function makeTemplate(id) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    writeOpen()
    var made = copyPages(id, true)
    return made ? answer({ ok: true, id: made, title: workspace.index.pages[made].title || "Untitled", note: "a template now (templates lists it; fromTemplate uses it)" }) : fail(copyFailed(id))
  }

  // ---- a page's history ----

  // Its versions, newest first: [{ name, kept }].
  function history(id) {
    var not = unready()
    if (not) return fail(not)
    if (!Workspace.isUuid(id) || !workspace.index.pages[id]) return fail(noPage)
    var names = workspace.versionNames[id]
    // (Read again, for next time.)
    workspace.listVersions(id, function() {})
    if (!names) return fail("reading its history: ask again in a moment")
    return answer(names.map(function(n) { var d = Workspace.versionDate(n); return { name: n, kept: d ? d.toISOString() : "" } }))
  }
  // A kept version of a page: { page } or { error } (read by the helper first,
  // then asked again: readGiven).
  function versionPage(id, name) {
    var none = "there's no version called that (history <id> lists them)"
    if (!Workspace.versionDate(String(name || "")) || !files) return { error: none }
    var got = readGiven(Workspace.historyDir(files.rootPath, id) + "/" + name, 32 * 1024 * 1024, none)
    if (got.error) return { error: /no file there/.test(got.error) ? none : got.error }
    var v = files.parseJson(got.text)
    var page = v ? Workspace.cleanPage(v.page, id) : null
    return page ? { page: page } : { error: "that version can't be read" }
  }
  // One version, as Markdown.
  function version(id, name) {
    var not = unready()
    if (not) return fail(not)
    if (!Workspace.isUuid(id) || !workspace.index.pages[id]) return fail(noPage)
    var v = versionPage(id, name)
    if (v.error) return fail(v.error)
    return Markdown.fromDocPage(v.page, null, { fences: true })
  }
  // The page as it was: what it is now kept in its history first.
  function restoreVersion(id, name) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var kept = versionPage(id, name)
    if (kept.error) return fail(kept.error)
    var old = kept.page
    var err = editPageNow(id, function(p) {
      var lockedNow = lockedNote(p)
      if (lockedNow) return lockedNow
      // (As the window does it: the pages in it now stay, at its end.)
      var r = Workspace.versionToRestore(old, p, workspace.index)
      p.title = r.title
      p.icon = Workspace.cleanIcon(r.icon)
      Workspace.putBlocks(p, 0, Workspace.flatten(p).length, r.blocks, 0)
    }, true)
    return err ? fail(err) : answer({ ok: true, id: id, title: old.title || "Untitled" })
  }

  // ---- blocks: ticked, colored, taken off; boards; files and links ------------------------------

  function check(id, block, on) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var want = yes(on)
    var err = editPageNow(id, function(p) {
      var lockedNow = lockedNote(p)
      if (lockedNow) return lockedNow
      var b = blockOf(p, block)
      if (!b || b.type !== "check") return "that isn't a to-do on the page (blocks <page id> gives them)"
      if (b.checked === want) return false
      b.checked = want
    }, true)
    return err ? fail(err) : answer({ ok: true, id: id, block: block, checked: want })
  }

  // A block's color: gray, brown, orange, yellow, green, blue, purple, pink
  // or red (its text), with "_background" (behind it), or "" for none. A
  // card (a board, a file, a bookmark, a person, an email...) takes a hex
  // too ("#ff8800", "#ff8800_background"), and keeps one of each.
  function color(id, block, value) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var v = String(value || "").trim().toLowerCase()
    var name = v.replace(/_background$/, "")
    var hex = /^#[0-9a-f]{6}$/.test(name)
    if (v && !Blocks.isColor(v) && !hex) return fail("a color is gray, brown, orange, yellow, green, blue, purple, pink or red, with _background for behind it (\"blue_background\"), or \"\" for none")
    var err = editPageNow(id, function(p) {
      var lockedNow = lockedNote(p)
      if (lockedNow) return lockedNow
      var b = blockOf(p, block)
      if (!b) return "there's no block with that id on the page (blocks <page id> gives them)"
      if (Blocks.hasData(b.type)) {
        var d = Blocks.cleanData(b.type, b.data)
        if (!v) { d.color = ""; d.background = "" }
        else if (v !== name) d.background = name
        else d.color = name
        b.data = Blocks.cleanData(b.type, d)
      } else if (hex) return "a hex color is for a card (a board, file, video, bookmark, button, person or email); text takes one of Pages' colors"
      else if (v) b.color = v
      else delete b.color
    }, true)
    return err ? fail(err) : answer({ ok: true, id: id, block: block, color: v })
  }

  // A block taken off the page (and the blocks inside it); kept in its history.
  function removeBlock(id, block) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var err = editPageNow(id, function(p) {
      var lockedNow = lockedNote(p)
      if (lockedNow) return lockedNow
      var spot = Workspace.locate(p, String(block || ""))
      if (!spot) return "there's no block with that id on the page (blocks <page id> gives them)"
      if (Workspace.isStructure(spot.block.type)) return "that block holds columns: take off the blocks inside them instead"
      for (var k = spot.at; k <= spot.end; k++) if (spot.list[k].type === "page") return "there's a page inside that block: move or trash that page first"
      Workspace.putBlocks(p, spot.at, spot.end - spot.at + 1, [], spot.depth)
    }, true)
    return err ? fail(err) : answer({ ok: true, id: id, block: block })
  }

  // A board's cards and columns changed: add (text, column), move (card,
  // column), edit (card, text), remove (card), addColumn (name),
  // renameColumn (column, name), removeColumn (column). A column or a card
  // by its id or its name; `blocks` gives the board's.
  function board(id, block, action, a, b) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var result = null
    var err = editPageNow(id, function(p) {
      var lockedNow = lockedNote(p)
      if (lockedNow) return lockedNow
      var bl = blockOf(p, block)
      if (!bl || bl.type !== "board") return "that isn't a board on the page (blocks <page id> gives them)"
      var d = Blocks.cleanData("board", bl.data)
      function col(x) {
        var t = String(x || "").trim().toLowerCase()
        return d.columns.filter(function(c) { return c.id === x })[0] || d.columns.filter(function(c) { return c.name.toLowerCase() === t })[0] || null
      }
      function card(x) {
        var t = String(x || "").trim().toLowerCase()
        var all = []
        d.columns.forEach(function(c) { c.cards.forEach(function(k) { all.push(k) }) })
        return all.filter(function(k) { return k.id === x })[0] || all.filter(function(k) { return k.text.toLowerCase() === t })[0] || null
      }
      var next = null
      var act = String(action || "")
      if (act === "add") {
        var into = b ? col(b) : d.columns[0]
        if (!into) return "there's no column called that on the board"
        if (!String(a || "").trim()) return "what does the card say?"
        var r = Board.addCard(d, into.id, String(a))
        next = r[0]
        result = { card: r[1], column: into.name }
      } else if (act === "move" || act === "edit" || act === "remove") {
        var k = card(a)
        if (!k) return "there's no card like that on the board"
        if (act === "move") { var to = col(b); if (!to) return "there's no column called that on the board"; next = Board.moveCard(d, k.id, to.id); result = { card: k.id, column: to.name } }
        else if (act === "edit") { if (!String(b || "").trim()) return "what does the card say now?"; next = Board.setCard(d, k.id, { text: String(b) }); result = { card: k.id } }
        else { next = Board.removeCard(d, k.id); result = { card: k.id } }
      } else if (act === "addColumn") {
        next = Board.addColumn(d, String(a || ""))
        if (next.columns.length === d.columns.length) return "a board has " + d.columns.length + " columns at most"
        result = { column: next.columns[next.columns.length - 1].id }
      } else if (act === "renameColumn" || act === "removeColumn") {
        var c = col(a)
        if (!c) return "there's no column called that on the board"
        if (act === "renameColumn") { if (!String(b || "").trim()) return "what's it called now?"; next = Board.setColumn(d, c.id, { name: String(b) }) }
        else { if (d.columns.length < 2) return "a board keeps one column at least"; next = Board.removeColumn(d, c.id) }
        result = { column: c.id }
      } else if (act === "height") {
        var h = Math.round(Number(a))
        if (!isFinite(h) || h < 0) return "a height in pixels (" + Board.MIN_HEIGHT + " to " + Board.MAX_HEIGHT + "), or 0 for as tall as its cards"
        next = JSON.parse(JSON.stringify(d))
        next.height = h === 0 ? 0 : Math.max(Board.MIN_HEIGHT, Math.min(Board.MAX_HEIGHT, h))
        result = { height: next.height }
      } else if (act === "columnWidth") {
        var cw = col(a)
        if (!cw) return "there's no column called that on the board"
        var w = Math.round(Number(b))
        if (!isFinite(w) || w < 0) return "a width in pixels (" + Board.MIN_WIDTH + " to " + Board.MAX_WIDTH + "), or 0 for as wide as fits"
        next = Board.setColumn(d, cw.id, { width: w === 0 ? 0 : Math.max(Board.MIN_WIDTH, Math.min(Board.MAX_WIDTH, w)) })
        result = { column: cw.id, width: w === 0 ? 0 : Math.max(Board.MIN_WIDTH, Math.min(Board.MAX_WIDTH, w)) }
      } else if (act === "cardColor" || act === "columnColor") {
        var paint = colorOf(b)
        if (paint === null) return "a color is one of Pages' (blue), a hex (#ff8800), either with _background for behind it, or \"\" for none"
        if (act === "cardColor") {
          var kc = card(a)
          if (!kc) return "there's no card like that on the board"
          next = Board.setCard(d, kc.id, paint)
          result = { card: kc.id }
        } else {
          var cc = col(a)
          if (!cc) return "there's no column called that on the board"
          next = Board.setColumn(d, cc.id, paint)
          result = { column: cc.id }
        }
      } else return "the action is add, move, edit, remove, addColumn, renameColumn, removeColumn, height, columnWidth, cardColor or columnColor"
      next.color = d.color
      next.background = d.background
      bl.data = Blocks.cleanData("board", next)
    }, true)
    if (err) return fail(err)
    var o = { ok: true, id: id, block: block }
    for (var key in result) o[key] = result[key]
    return answer(o)
  }

  // "blue" (its text), "blue_background" (behind it), "#ff8800" or
  // "#ff8800_background", "" (none): the fields to change, or null.
  function colorOf(value) {
    var v = String(value || "").trim().toLowerCase()
    if (!v) return { color: "", background: "" }
    var name = v.replace(/_background$/, "")
    if (!Blocks.isColor(name) && !/^#([0-9a-f]{3}|[0-9a-f]{6})$/.test(name)) return null
    return v !== name ? { background: name } : { color: name }
  }

  // fn, for when a file's copied in (or a site read): nothing, if another
  // profile's notes are open by then (it went into the folder that was;
  // their pages may have the same ids).
  function inThisFolder(fn) {
    var gen = workspace.generation
    var folder = workspace.folder
    return function() { if (api.workspace && gen === api.workspace.generation && folder === api.workspace.folder) return fn.apply(null, arguments) }
  }

  // Blocks put at the end of a page now, or later (after a file is copied in):
  // the window adds them itself when the page is open there.
  function appendNow(id, list) {
    if (!live(id) || !list.length) return false
    keep(id)
    var took = viewDoes("appendToOpenPage", id, list)
    if (took === true || took === "locked") return took === true
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) {
      workspace.editPage(id, function(p) { if (lockedNote(p)) return false; Workspace.appendBlocks(p, list) })
      return true
    }
    if (lockedNote(page)) return false
    Workspace.appendBlocks(page, list)
    page.modified = new Date().toISOString()
    workspace.savePage(page)
    workspace.pageChanged(id)
    return true
  }

  // A file on a page: a picture, a video, an email (.eml), or any file (a
  // PDF shown page by page), copied into Pages/assets, at its end.
  function attach(id, path) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var p = String(path || "").trim()
    if (p.indexOf("~/") === 0 && files && files.home) p = files.home + p.slice(1)
    if (!p || p.charAt(0) !== "/" || /\/$/.test(p)) return fail("give the file's full path")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    if (lockedNote(page)) return fail(lockedNote(page))
    var name = p.slice(p.lastIndexOf("/") + 1)
    var kind = files.isImagePath(p) ? "picture" : /\.eml$/i.test(name) ? "email" : Files.kindOf(name) === "video" ? "video" : "file"
    // (The panel's agent's picture only from its own folder, through no link.)
    if (kind === "picture") workspace.importPicture(p, inThisFolder(function(src) { if (src) api.appendNow(id, [{ type: "image", src: src, width: 1, align: "center", indent: 0 }]) }), caller ? caller.dir : "")
    // (Any other file of the panel's agent's too: the files helper's copy-file.)
    else if (kind === "email") workspace.importEmail(p, inThisFolder(function(sum) { if (sum) api.appendNow(id, [{ type: "email", indent: 0, data: sum }]) }), caller ? caller.dir : "")
    else workspace.importFile(p, inThisFolder(function(f) { if (f) api.appendNow(id, [{ type: f.kind === "video" ? "video" : "file", indent: 0, data: f }]) }), caller ? caller.dir : "")
    return answer({ ok: true, id: id, file: name, kind: kind, note: "it's being copied in, and shows at the end of the page in a moment (blocks <id> lists it there; if it doesn't, the file couldn't be read)" })
  }

  // ---- pictures and galleries ----

  // A picture's size (its width as a percent of the page's: 15 to 100) and
  // where it sits (left, center, right); "" for either keeps it.
  function picture(id, block, width, align) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var w = String(width === undefined ? "" : width).trim().replace(/%$/, "")
    var al = String(align || "").trim().toLowerCase()
    if (!w && !al) return fail("give a width (15 to 100, a percent of the page's) or where it sits (left, center, right)")
    var n = w ? Number(w) : 0
    if (w && !isFinite(n)) return fail("a width is a percent of the page's: 15 to 100")
    if (w && n > 0 && n <= 1) n = n * 100
    if (al && ["left", "center", "right"].indexOf(al) < 0) return fail("it sits left, center or right")
    var out = null
    var err = editPageNow(id, function(p) {
      var lockedNow = lockedNote(p)
      if (lockedNow) return lockedNow
      var b = blockOf(p, block)
      if (!b || b.type !== "image") return "that isn't a picture on the page (blocks <page id> gives them)"
      if (w) b.width = Math.round(Math.max(15, Math.min(100, n))) / 100
      if (al) b.align = al
      out = { width: Math.round((b.width || 0.6) * 100), align: b.align || "center" }
    }, true)
    if (err) return fail(err)
    return answer({ ok: true, id: id, block: block, width: out.width, align: out.align })
  }

  // Paths: one a line (or "|" between them), or a folder (the pictures in
  // it, A to Z): done(the pictures' paths).
  function pathList(text) {
    return String(text || "").split(/\n|\|/).map(function(p) {
      var t = p.trim()
      return t.indexOf("~/") === 0 && files && files.home ? files.home + t.slice(1) : t
    }).filter(function(p) { return p !== "" })
  }
  function picturesOf(text, done) {
    var list = pathList(text)
    if (list.length === 1 && !files.isImagePath(list[0])) {
      var dir = list[0].replace(/\/+$/, "")
      files.execText(["/usr/bin/bash", "-c", Library.LIST_SCRIPT, "uber-notebook-pictures", dir], function(ok, out) {
        var names = String(out || "").split("\n").map(function(l) { var m = /^f\t[0-9.]+\t(.+)$/.exec(l); return m ? dir + "/" + m[1] : "" })
          .filter(function(p) { return p && files.isImagePath(p) }).sort()
        done(names.slice(0, 200))
      }, { okCodes: [0, 1], timeoutMs: 8000, maxBytes: 1024 * 1024 })
      return
    }
    done(list.filter(function(p) { return files.isImagePath(p) }).slice(0, 200))
  }
  // Pictures copied into Pages/assets: done([srcs], in their order). With
  // `within` (the panel's agent's folder), only pictures in it.
  function importPictures(paths, done, within) {
    if (!paths.length) { done([]); return }
    var got = []
    var left = paths.length
    paths.forEach(function(p, i) {
      workspace.importPicture(p, function(src) {
        got[i] = src
        if (--left === 0) done(got.filter(function(s) { return !!s }))
      }, within)
    })
  }

  // A gallery at a page's end, of pictures (files, or a folder's), 2 to 4 to a row.
  function addGallery(id, pictures, columns) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    if (lockedNote(page)) return fail(lockedNote(page))
    var list = pathList(pictures)
    if (!list.length || list.some(function(p) { return p.charAt(0) !== "/" })) return fail("give the pictures' full paths, one a line (or | between them), or a folder's")
    if (list.length > 1 && !list.some(function(p) { return files.isImagePath(p) })) return fail("none of those are pictures (png, jpg, gif, webp, bmp, svg)")
    var cols = Number(columns)
    if (cols !== 2 && cols !== 4) cols = 3
    var within = caller ? caller.dir : ""
    picturesOf(pictures, inThisFolder(function(paths) {
      api.importPictures(paths, api.inThisFolder(function(srcs) {
        if (srcs.length) api.appendNow(id, [{ type: "gallery", indent: 0, data: Blocks.cleanData("gallery", { images: srcs.map(function(s) { return { src: s, caption: "" } }), columns: cols }) }])
      }), within)
    }))
    return answer({ ok: true, id: id, columns: cols, note: "the pictures are being copied in: the gallery shows at the end of the page in a moment (blocks <id> lists it)" })
  }

  // A gallery changed: add <files or a folder>, remove <n>, move <n> <to>,
  // caption <n> <text>, columns <2|3|4>, height <px, or 0>. A picture by
  // its place (1 is first) or its src.
  function gallery(id, block, action, a, b) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var act = String(action || "")
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    var gb = blockOf(page, block)
    if (!gb || gb.type !== "gallery") return fail("that isn't a gallery on the page (blocks <page id> gives them)")
    if (lockedNote(page)) return fail(lockedNote(page))
    if (act === "add") {
      var list = pathList(a)
      if (!list.length || list.some(function(p) { return p.charAt(0) !== "/" })) return fail("give the pictures' full paths, one a line (or | between them), or a folder's")
      var within = caller ? caller.dir : ""
      picturesOf(a, inThisFolder(function(paths) {
        api.importPictures(paths, api.inThisFolder(function(srcs) {
          if (!srcs.length) return
          api.editPageNow(id, function(p) {
            var x = blockOf(p, block)
            if (!x || x.type !== "gallery") return false
            var d = Blocks.cleanData("gallery", x.data)
            d.images = d.images.concat(srcs.map(function(s) { return { src: s, caption: "" } }))
            x.data = Blocks.cleanData("gallery", d)
          }, true)
        }), within)
      }))
      return answer({ ok: true, id: id, block: block, note: "the pictures are being copied in, then at the gallery's end" })
    }
    var result = {}
    var err = editPageNow(id, function(p) {
      var x = blockOf(p, block)
      var d = Blocks.cleanData("gallery", x.data)
      function at(ref) {
        var r = String(ref || "").trim()
        if (/^\d+$/.test(r)) { var k = Number(r) - 1; return k >= 0 && k < d.images.length ? k : -1 }
        return d.images.map(function(i) { return i.src }).indexOf(r)
      }
      if (act === "remove" || act === "move" || act === "caption") {
        var i = at(a)
        if (i < 0) return "there's no picture like that in it (1 is the first; or its src)"
        if (act === "remove") { d.images.splice(i, 1); result = { removed: i + 1 } }
        else if (act === "caption") { d.images[i].caption = String(b || "").trim(); result = { picture: i + 1, caption: d.images[i].caption } }
        else {
          var to = Number(b) - 1
          if (!isFinite(to) || to < 0 || to >= d.images.length) return "move it to a place: 1 to " + d.images.length
          var one = d.images.splice(i, 1)[0]
          d.images.splice(to, 0, one)
          result = { picture: to + 1 }
        }
      } else if (act === "columns") {
        var c = Number(a)
        if (c !== 2 && c !== 3 && c !== 4) return "2, 3 or 4 to a row"
        d.columns = c
        result = { columns: c }
      } else if (act === "height") {
        var h = Math.round(Number(a))
        if (!isFinite(h) || h < 0) return "a height in pixels (80 to 800), or 0 for three quarters as tall as wide"
        d.height = h === 0 ? 0 : Math.max(80, Math.min(800, h))
        result = { height: d.height }
      } else return "the action is add, remove, move, caption, columns or height"
      x.data = Blocks.cleanData("gallery", d)
    }, true)
    if (err) return fail(err)
    var o = { ok: true, id: id, block: block }
    for (var key in result) o[key] = result[key]
    return answer(o)
  }

  // A link changed: a bookmark's (its page read again), or a link to a
  // page's (another page: its id or its title).
  function setLink(id, block, target) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    writeOpen()
    var page = workspace.readPageNow(id)
    if (!page) return fail(notRead(id))
    var b = blockOf(page, block)
    if (!b || (b.type !== "bookmark" && b.type !== "link")) return fail("that isn't a bookmark or a link to a page (blocks <page id> gives them)")
    if (lockedNote(page)) return fail(lockedNote(page))
    var t = String(target || "").trim()
    if (b.type === "link") {
      var to = Workspace.isUuid(t) && workspace.index.pages[t] ? t : Workspace.pageNamed(workspace.index, t)
      if (!to || !live(to)) return fail("there's no page with that id or title (list or find gives them)")
      var err = editPageNow(id, function(p) { var x = blockOf(p, block); if (!x) return "there's no block with that id on the page (blocks <page id> gives them)"; x.target = to }, true)
      return err ? fail(err) : answer({ ok: true, id: id, block: block, target: to, title: workspace.index.pages[to].title || "Untitled" })
    }
    if (t && !/^[a-z][a-z0-9+.-]*:/i.test(t) && /^[^\s\/]+\.[a-z]{2,}(\/|$)/i.test(t)) t = "https://" + t
    var u = Bookmark.cleanUrl(t)
    if (!u) return fail("that isn't a web link (https://...)")
    if (caller) {
      // (While an agent works, nothing is fetched for it: a link it gives
      // could carry what it read. The card keeps the link; refreshing it reads it.)
      var e2 = editPageNow(id, function(p) {
        var x = blockOf(p, block)
        if (!x || x.type !== "bookmark") return "that isn't a bookmark"
        x.data = Blocks.cleanData("bookmark", { url: u, title: "", description: "", site: Bookmark.domain(u), image: "" })
      }, true)
      return e2 ? fail(e2) : answer({ ok: true, id: id, block: block, url: u, note: agentLink(id, u) })
    }
    workspace.fetchBookmark(u, inThisFolder(function(data) {
      api.editPageNow(id, function(p) {
        var x = blockOf(p, block)
        if (!x || x.type !== "bookmark") return false
        var d = Blocks.cleanData("bookmark", x.data)
        var got = data || { url: u, title: "", description: "", site: Bookmark.domain(u), image: "" }
        for (var k in got) d[k] = got[k]
        x.data = Blocks.cleanData("bookmark", d)
      }, true)
    }))
    return answer({ ok: true, id: id, block: block, url: u, note: "its page is being read; the card shows it in a moment" })
  }

  // ---- templates: what one's for; one from Markdown ----

  function templateOf(which) {
    var w = String(which || "").trim()
    var list = Workspace.templates(workspace.index)
    return list.filter(function(t) { return t.id === w })[0] || list.filter(function(t) { return t.title.toLowerCase() === w.toLowerCase() })[0] || null
  }
  // What a template's for, in a line (Templates shows it on its card).
  function describeTemplate(which, text) {
    var not = unready()
    if (not) return fail(not)
    var t = templateOf(which)
    if (!t) return fail("there's no template like that (templates lists them)")
    workspace.setDescription(t.id, String(text || ""))
    return answer({ ok: true, id: t.id, title: t.title, description: workspace.index.pages[t.id].description || "" })
  }
  // A new template from a Markdown file ({{date}}, {{weekday}}, {{time}},
  // {{month}}, {{year}} and {{week}} filled in when it's used), with what it's for.
  function addTemplate(title, path, description) {
    var not = unready()
    if (not) return fail(not)
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var name = String(title || "").trim()
    var got = blocksOf(md.text, name === "")
    writeOpen()
    var page = workspace.createPage({ parent: "", title: Workspace.cleanTitle(name || got.title || ""), icon: got.icon || "",
      blocks: got.blocks.concat([{ type: "p", html: "", indent: 0 }]) })
    if (!page) return fail("couldn't make it")
    workspace.setTemplate(page.id, true)
    if (description) workspace.setDescription(page.id, String(description))
    return answer({ ok: true, id: page.id, title: page.title || "Untitled template", note: "a template now (templates lists it; fromTemplate uses it)" })
  }

  // ---- settings ----

  // Every setting there is to change (with `set`): [{ key, value, kind, choices, range }].
  readonly property var internalSettings: ["profiles", "profile", "folder", "lastNotebook", "lastPage", "inbox", "recentColors", "space"]
  function preferences() {
    var s = settings || {}
    return answer(Object.keys(Defaults.DEFAULTS).filter(function(k) { return internalSettings.indexOf(k) < 0 }).map(function(k) {
      var o = { key: k, value: s[k] !== undefined ? s[k] : Defaults.DEFAULTS[k], kind: Defaults.SCHEMA.types[k] || typeof Defaults.DEFAULTS[k] }
      if (Defaults.SCHEMA.choices[k]) o.choices = Defaults.SCHEMA.choices[k]
      if (Defaults.SCHEMA.ranges[k]) o.range = Defaults.SCHEMA.ranges[k]
      return o
    }))
  }

  // A link as a card (its page's title, a line, its picture) at a page's end.
  function bookmark(id, url) {
    var not = unready()
    if (not) return fail(not)
    if (!live(id)) return fail(noPage)
    var raw = String(url || "").trim()
    // ("example.com/guide": a web link.)
    if (raw && !/^[a-z][a-z0-9+.-]*:/i.test(raw) && /^[^\s\/]+\.[a-z]{2,}(\/|$)/i.test(raw)) raw = "https://" + raw
    var u = Bookmark.cleanUrl(raw)
    if (!u) return fail("that isn't a web link (https://...)")
    if (caller) {
      if (!appendNow(id, [{ type: "bookmark", indent: 0, data: { url: u, site: Bookmark.domain(u) } }])) return fail("couldn't add it to that page")
      return answer({ ok: true, id: id, url: u, note: agentLink(id, u) })
    }
    workspace.fetchBookmark(u, inThisFolder(function(data) { api.appendNow(id, [{ type: "bookmark", indent: 0, data: data || { url: u } }]) }))
    return answer({ ok: true, id: id, url: u, note: "its page is being read; the card shows at the end of the page in a moment" })
  }

  // ---- the calendar: an event changed ----

  // A field of an event: title, when ("fri 3pm", "oct 12 9:30-10:00",
  // "dec 24"), start or end (2026-10-05 or 2026-10-05T09:30), allDay, place,
  // notes, repeat (daily, weekdays, weekly, monthly, yearly, "" for not),
  // alert (minutes before, or none), color.
  function editEvent(id, field, value) {
    var not = unready()
    if (not) return fail(not)
    var e = Calendar.byId(workspace.calendar, String(id || ""))
    if (!e) return fail("there's no event with that id (events lists them)")
    var v = String(value === undefined ? "" : value).trim()
    var f = String(field || "")
    // (The change, made to it as it is when it's made: { event } or { error }.)
    function edited(cur) {
      var n = JSON.parse(JSON.stringify(cur))
      if (f === "title") { if (!v) return { error: "what is it called?" }; n.title = v }
      else if (f === "when") {
        var q = Calendar.quick("x " + v, new Date())
        if (!q) return { error: "there's no day or time in that (\"fri 3pm\", \"oct 12 9:30-10:00\")" }
        n.start = q.start; n.end = q.end; n.allDay = q.allDay
      }
      else if (f === "start" || f === "end") { if (!Dates.fromIso(v)) return { error: "a date like 2026-10-05, or 2026-10-05T09:30" }; n[f] = v }
      else if (f === "allDay") n.allDay = yes(v)
      else if (f === "place") n.place = v
      else if (f === "notes") n.detail = v
      else if (f === "repeat") {
        var r = v.toLowerCase()
        if (r && Calendar.REPEATS.indexOf(r) < 0) return { error: "repeat is daily, weekdays, weekly, monthly or yearly (\"\" for not)" }
        n.repeat = r ? { freq: r, every: n.repeat ? n.repeat.every : 1, until: n.repeat ? n.repeat.until : "" } : null
      }
      else if (f === "alert") {
        var mins = v === "" || v === "none" ? -1 : Number(v)
        if (mins !== -1 && Calendar.ALERTS.indexOf(mins) < 0) return { error: "an alert is one of " + Calendar.ALERTS.join(", ") + " minutes before, or none" }
        n.alert = mins
      }
      else if (f === "color") { var c = v ? Calendar.cleanColor(v.toLowerCase()) : ""; if (v && !c) return { error: "a color is one of Pages' (blue, red...) or a hex like #ff8800, or \"\" for the calendar's" }; n.color = c }
      else return { error: "the field is title, when, start, end, allDay, place, notes, repeat, alert or color" }
      var clean = Calendar.cleanEvent(n)
      if (!clean) return { error: "that doesn't make an event" }
      return { event: clean }
    }
    var first = edited(e)
    if (first.error) return fail(first.error)
    function save() {
      var cur = Calendar.byId(api.workspace.calendar, e.id)
      if (!cur) return fail("that event is no longer on the calendar")
      var r = edited(cur)
      if (r.error) return fail(r.error)
      var clean = r.event
      api.workspace.setCalendar(Calendar.withEvent(api.workspace.calendar, clean))
      return answer({ ok: true, id: clean.id, title: clean.title, start: clean.start, end: clean.end, allDay: clean.allDay, place: clean.place, repeat: clean.repeat ? clean.repeat.freq : "", alert: clean.alert, color: clean.color })
    }
    // Emptying its place or its notes (the calendar keeps no history):
    // asked first, as a removal.
    var had = f === "place" && blankish(v) ? String(e.place || "").trim() : f === "notes" && blankish(v) ? String(e.detail || "").trim() : ""
    if (!had) return save()
    return agentRemoval("event detail", e.id + " " + f, "clear the " + f + " of \u201c" + (e.title || "Untitled") + "\u201d (\u201c" + (had.length > 80 ? had.slice(0, 80) + "\u2026" : had) + "\u201d)", save)
  }

  // An .ics file's events on the calendar (those it hasn't got already):
  // { added, skipped }.
  function importCalendar(path) {
    var not = unready()
    if (not) return fail(not)
    var got = readGiven(path, 16 * 1024 * 1024, "give the .ics file's full path")
    if (got.error) return fail(got.error)
    var events = Calendar.fromIcs(got.text)
    if (!events.length) return fail("there are no events in it")
    var cal = workspace.calendar
    var added = 0
    events.forEach(function(e) { if (!Calendar.hasLike(cal, e)) { cal = Calendar.withEvent(cal, e); added++ } })
    if (added) workspace.setCalendar(cal)
    return answer({ ok: true, added: added, skipped: events.length - added })
  }

  // ---- people: someone changed, or taken out ----

  // A field: name, company, title, birthday, address, website, notes; phone
  // and email add one ("mobile: +1 555 123 4567", "work: sam@acme.com");
  // removePhone and removeEmail take one off.
  function editContact(which, field, value) {
    var not = unready()
    if (not) return fail(not)
    var q = String(which || "").trim()
    var c = workspace.contactById(q) || (q ? Contacts.find(workspace.contacts, q, 1)[0] : null)
    if (!c) return fail("there's no one like that in People (contacts lists everyone)")
    var v = String(value === undefined ? "" : value).trim()
    var f = String(field || "")
    var lm = /^([a-z ]{1,20}):\s*(.+)$/i.exec(v)
    var label = lm ? lm[1].trim() : ""
    var raw = lm ? lm[2].trim() : v
    // (The change, made to them as they are when it's made: { contact } or { error }.)
    function edited(cur) {
      var n = JSON.parse(JSON.stringify(cur))
      if (["name", "company", "title", "address", "notes"].indexOf(f) >= 0) n[f] = v
      else if (f === "birthday") { if (v && !Contacts.cleanBirthday(v)) return { error: "a birthday like 1990-04-12, or --04-12 without the year" }; n.birthday = Contacts.cleanBirthday(v) }
      else if (f === "website") { if (v && !Contacts.cleanWebsite(v)) return { error: "a website like https://example.com" }; n.website = Contacts.cleanWebsite(v) }
      else if (f === "phone") { if (!Contacts.cleanPhone(raw)) return { error: "that isn't a phone number" }; n.phones.push({ label: label || "mobile", value: raw }) }
      else if (f === "email") { if (!Contacts.cleanEmail(raw)) return { error: "that isn't an email" }; n.emails.push({ label: label || "work", value: raw }) }
      else if (f === "removePhone") { var key = Contacts.phoneKey(raw); var before = n.phones.length; n.phones = n.phones.filter(function(p) { return Contacts.phoneKey(p.value) !== key }); if (n.phones.length === before) return { error: "they don't have that number" } }
      else if (f === "removeEmail") { var e = Contacts.cleanEmail(raw); var was = n.emails.length; n.emails = n.emails.filter(function(x) { return x.value !== e }); if (n.emails.length === was) return { error: "they don't have that email" } }
      else return { error: "the field is name, company, title, birthday, address, website, notes, phone, email, removePhone or removeEmail" }
      if (!Contacts.cleanContact(n)) return { error: "that would leave nothing to know them by" }
      return { contact: n }
    }
    var first = edited(c)
    if (first.error) return fail(first.error)
    function save() {
      var cur = workspace.contactById(c.id)
      if (!cur) return fail("they're no longer in People")
      var r = edited(cur)
      if (r.error) return fail(r.error)
      workspace.saveContact(r.contact)
      var o = personOut(workspace.contactById(r.contact.id), true)
      o.ok = true
      return answer(o)
    }
    // Taking away something they have (a field emptied, a number or an
    // email): asked first, as a removal (People keeps no history).
    var name = Contacts.nameOf(c)
    var had = ["name", "company", "title", "address", "notes", "birthday", "website"].indexOf(f) >= 0 && blankish(v) ? String(c[f] || "").trim() : ""
    var takes = had ? "clear " + name + "\u2019s " + f + " (\u201c" + (had.length > 80 ? had.slice(0, 80) + "\u2026" : had) + "\u201d)"
      : f === "removePhone" ? "take the number \u201c" + raw + "\u201d from " + name
      : f === "removeEmail" ? "take the email \u201c" + raw + "\u201d from " + name : ""
    if (!takes) return save()
    return agentRemoval("contact detail", c.id + " " + f + " " + raw, takes, save)
  }

  function removeContact(which) {
    var not = unready()
    if (not) return fail(not)
    var q = String(which || "").trim()
    var c = workspace.contactById(q)
    if (!c) return fail("give their id (contacts lists everyone)")
    return agentRemoval("contact", c.id, "take " + Contacts.nameOf(c) + " out of People", function() {
      workspace.setContacts(Contacts.without(workspace.contacts, c.id))
      return answer({ ok: true, id: c.id, name: Contacts.nameOf(c), note: "taken out of People (Undo in People puts them back while Uber Notebook runs)" })
    })
  }

  // ---- tags: renamed, or taken off every page ----

  function renameTag(tag, to) {
    var not = unready()
    if (not) return fail(not)
    var from = Tags.clean(tag)
    var into = Tags.clean(to)
    if (!from || !into) return fail("give the tag and its new name: renameTag \"#idea\" \"#ideas\"")
    var pages = Workspace.pagesTagged(workspace.index, from).length
    if (!pages) return fail("no page has #" + from)
    writeOpen()
    workspace.changeTag(from, into, function() {})
    return answer({ ok: true, from: "#" + from, to: "#" + into, pages: pages, note: "renamed on each page (each keeps its version before)" })
  }

  function removeTag(tag) {
    var not = unready()
    if (not) return fail(not)
    var from = Tags.clean(tag)
    if (!from) return fail("give a tag: removeTag \"#idea\"")
    var pages = Workspace.pagesTagged(workspace.index, from).length
    if (!pages) return fail("no page has #" + from)
    return agentRemoval("tag", from, "take #" + from + " off " + pages + (pages === 1 ? " page" : " pages"), function() {
      api.writeOpen()
      workspace.changeTag(from, "", function() {})
      return answer({ ok: true, tag: "#" + from, pages: pages, note: "taken off each page, the #tag out of the text (each keeps its version before)" })
    })
  }

  // ---- notebooks (the Notebooks space) ----

  // A notebook's pages, read in the background as a command asks for them
  // (never there and then): { pid: page }, kept two minutes; null while
  // they're read (the command says to ask again).
  property var notebookReads: ({})
  function notebookPages(id) {
    var kept = Object.prototype.hasOwnProperty.call(notebookReads, id) ? notebookReads[id] : null
    var now = Date.now()
    if (kept && kept.pages && now - kept.at < 120000) return kept.pages
    if (kept && !kept.pages && now - kept.at < 60000) return null
    var next = {}
    for (var k in notebookReads) if (now - notebookReads[k].at < 120000) next[k] = notebookReads[k]
    next[id] = { at: now, pages: null }
    notebookReads = next
    files.readGlob(Library.pagesDir(files.rootPath, id), "*.json", function(got) {
      var pages = {}
      for (var path in got) {
        var pid = path.slice(path.lastIndexOf("/") + 1, -5)
        var p = Library.cleanPage(files.parseJson(got[path]), pid)
        if (p) pages[pid] = p
      }
      var after = {}
      for (var n in api.notebookReads) after[n] = api.notebookReads[n]
      after[id] = { at: Date.now(), pages: pages }
      api.notebookReads = after
    }, 64 * 1024 * 1024)
    kept = notebookReads[id]
    return kept && kept.pages ? kept.pages : null
  }
  // One page of a notebook: { page } or { error }.
  function notebookPage(nb, pid) {
    var mine = files.written && files.written[nb] ? files.written[nb][pid] : null
    if (mine) return { page: JSON.parse(JSON.stringify(mine)) }
    var pages = notebookPages(nb)
    if (!pages) return { error: "reading the notebook first: run the same command again in a moment" }
    return pages[pid] ? { page: pages[pid] } : { error: "couldn't read that page" }
  }
  function notebooks() {
    if (!files || !files.index) return fail("the notebooks aren't loaded yet")
    return answer(files.notebookList().map(function(n) {
      var nb = files.index[n.id]
      return { id: n.id, title: n.title, pages: nb && nb.pages ? nb.pages.length : 0, modified: n.modified }
    }))
  }
  // A notebook's pages in order: [{ id, n, title, day, text }] (text: its first words).
  function notebook(id) {
    var nb = files && files.index ? files.index[id] : null
    if (!nb) return fail("there's no notebook with that id (notebooks lists them)")
    var out = []
    if (!notebookPages(id)) return fail("reading the notebook first: run the same command again in a moment")
    nb.pages.slice(0, 2000).forEach(function(pid, i) {
      var r = notebookPage(id, pid)
      var p = r.page
      if (p) out.push({ id: pid, n: i + 1, title: p.title || "", day: p.day || "", text: String(p.text || Blocks.plainText(p.blocks)).slice(0, 200) })
    })
    return answer({ id: id, title: nb.title, pages: out })
  }
  function readNotebook(id, pageId) {
    var nb = files && files.index ? files.index[id] : null
    if (!nb) return fail("there's no notebook with that id (notebooks lists them)")
    if (nb.pages.indexOf(String(pageId || "")) < 0) return fail("there's no page with that id in it (notebook <id> lists them)")
    var r = notebookPage(id, pageId)
    if (r.error) return fail(r.error)
    return Markdown.fromPage(r.page, "")
  }
  // A new page at a notebook's end, from a Markdown file (headings, lists,
  // to-dos, quotes, paragraphs: what a notebook's page holds).
  function addToNotebook(id, path) {
    var nb = files && files.index ? files.index[id] : null
    if (!nb) return fail("there's no notebook with that id (notebooks lists them)")
    var md = readMarkdown(path)
    if (md.error) return fail(md.error)
    var got = blocksOf(md.text, true)
    var list = Blocks.cleanList(got.blocks)
    var page = files.createPage(id, nb.pages.length, { title: got.title || "", blocks: list.length ? list : [{ type: "p", html: "" }] })
    if (!page) return fail("couldn't make the page")
    page.text = Blocks.plainText(page.blocks)
    files.writePage(id, page)
    files.pageAdded(id, page)
    return answer({ ok: true, notebook: id, id: page.id, n: nb.pages.indexOf(page.id) + 1, title: page.title || "" })
  }

  // ---- profiles ----------------------------------------------------------------------------

  function profileOut(p) {
    var open = profiles.current !== null && profiles.current.id === p.id
    return { id: p.id, name: p.name, folder: p.folder || "~/Documents/Uber Notebook", open: open, demo: p.demo }
  }
  function profileOf(which) {
    var w = String(which || "").trim()
    return profiles ? profiles.shown.filter(function(p) { return p.id === w })[0] || profiles.shown.filter(function(p) { return p.name.toLowerCase() === w.toLowerCase() })[0] || null : null
  }
  function noProfiles() { return !profiles ? "profiles aren't there to change here" : "" }

  // Every profile: [{ id, name, folder, open, demo }].
  function profileList() {
    if (noProfiles()) return fail(noProfiles())
    return answer(profiles.shown.map(profileOut))
  }
  // Another one open.
  function openProfile(which) {
    if (noProfiles()) return fail(noProfiles())
    var p = profileOf(which)
    if (!p) return fail("there's no profile like that (profiles lists them)")
    writeOpen()
    var problem = profiles.use(p.id)
    return problem ? fail(problem) : answer({ ok: true, profile: p.name, folder: profileOut(p).folder })
  }
  // A new one: its notes in `folder` ("" for beside the others, named for
  // it), opened if `open` (it starts empty, with the templates).
  function addProfile(name, folder, open) {
    if (noProfiles()) return fail(noProfiles())
    var f = String(folder || "").trim() || Profiles.suggestFolder(profiles.list, name)
    if (yes(open)) writeOpen()
    var problem = profiles.add(String(name || ""), f, yes(open))
    if (problem) return fail(problem)
    var made = profileOf(String(name || "").trim())
    return answer({ ok: true, id: made ? made.id : "", name: made ? made.name : "", folder: f, open: yes(open) })
  }
  function renameProfile(which, name) {
    if (noProfiles()) return fail(noProfiles())
    var p = profileOf(which)
    if (!p) return fail("there's no profile like that (profiles lists them)")
    var problem = profiles.rename(p.id, String(name || ""))
    return problem ? fail(problem) : answer({ ok: true, id: p.id, name: Profiles.line(String(name), 60) })
  }
  // Its notes looked for in another folder (nothing is moved).
  function profileFolder(which, folder) {
    if (noProfiles()) return fail(noProfiles())
    var p = profileOf(which)
    if (!p) return fail("there's no profile like that (profiles lists them)")
    if (p.demo) return fail("the demo keeps its own folder")
    var problem = profiles.setFolder(p.id, String(folder || "").trim())
    return problem ? fail(problem) : answer({ ok: true, id: p.id, folder: String(folder).trim() })
  }
  // Off the list (its notes stay in their folder); not the open one.
  function removeProfile(which) {
    if (noProfiles()) return fail(noProfiles())
    var p = profileOf(which)
    if (!p) return fail("there's no profile like that (profiles lists them)")
    var problem = profiles.remove(p.id)
    return problem ? fail(problem) : answer({ ok: true, id: p.id, name: p.name, note: "off the list; its notes stay in " + profileOut(p).folder })
  }
  // The demo open (made the first time), or made new (the old one to the trash).
  function demo(fresh) {
    if (noProfiles()) return fail(noProfiles())
    writeOpen()
    var problem = fresh ? profiles.restartDemo() : profiles.openDemo()
    return problem ? fail(problem) : answer({ ok: true, profile: profiles.current ? profiles.current.name : "", note: "example pages, people, events and templates" })
  }

  // ---- updates ----------------------------------------------------------------------------------

  // The version running, and whether there's a newer one (as GitHub said when last asked).
  function appVersion() {
    if (!updates) return fail("the update check isn't here")
    var o = updates.summary()
    o.ok = true
    return answer(o)
  }
  // GitHub asked now; appVersion says what it found, in a few seconds.
  function checkUpdate() {
    if (!updates) return fail("the update check isn't here")
    updates.check()
    return answer({ ok: true, version: updates.current, note: "asking GitHub: appVersion says what it found in a few seconds" })
  }
  // What's new (the newer releases' notes; up to date, this version's), as Markdown.
  function releaseNotes() {
    if (!updates) return fail("the update check isn't here")
    var n = updates.notes()
    return "# " + n.title + "\n\n" + n.markdown + "\n" + (n.url ? "\n" + n.url + "\n" : "")
  }

  // ---- backups ----------------------------------------------------------------------------------

  // A backup made: of the open profile (""), every one ("all"), or one by
  // its name or id. It's written in a moment; backups lists it.
  function backup(which) {
    if (!backups) return fail("backups aren't here")
    if (noProfile) return fail(unready())
    if (backups.working) return fail("a backup is being " + (backups.working === "backup" ? "made" : "put back") + " already: try again when it's done (backups says)")
    var picked = backups.chosen(which)
    if (!picked.length) return fail(String(which || "").trim() ? "there's no profile like that (profiles lists them)" : "no profile is open")
    backups.backUp(which, false, function() {})
    return answer({ ok: true, profiles: picked.map(function(p) { return p.name }), folder: backups.folderShown, note: "being written: backups lists it when it's done" })
  }
  // The backups in the backup folder, newest first, and how the last one went.
  function backupList() {
    if (!backups) return fail("backups aren't here")
    var o = { ok: true, folder: backups.folderShown, working: backups.working, last: backups.note, lastFailed: backups.failed, backups: backups.listing() }
    backups.refresh()
    return answer(o)
  }
  // A backup put back (only when the user asks): each profile in it a new
  // profile, in a new folder; nothing that's there is changed.
  function restoreBackup(file, open) {
    if (!backups) return fail("backups aren't here")
    if (backups.working) return fail("a backup is being " + (backups.working === "backup" ? "made" : "put back") + " already")
    var p = String(file || "").trim()
    if (!p || (p.charAt(0) !== "/" && p.indexOf("~/") !== 0)) return fail("give the backup's full path (backups lists them)")
    backups.restore(p, yes(open === undefined || open === "" ? "false" : open), function() {})
    return answer({ ok: true, file: p, note: "being put back as new profiles, each in a new folder: profiles lists them when it's done (backups says how it went)" })
  }

  // ---- the Inbox --------------------------------------------------------------------------------

  // The Inbox page's id: made (at the top of Pages) the first time, and
  // again if it's gone or in the trash.
  function inboxPage() {
    if (live(inbox)) return inbox
    var page = workspace.createPage({ parent: "", title: "Inbox", icon: "\u{1f4e5}", blocks: [
      { type: "callout", icon: "\u{1f916}", color: "gray_background", indent: 0,
        html: "Quick notes (Super+Alt+N, when Settings sends them here) and pages that AI agents and scripts add come in here. Move them anywhere." },
      { type: "p", html: "", indent: 0 }
    ] })
    if (!page) return ""
    inbox = page.id
    inboxMade(page.id)
    return page.id
  }

  // A new page's block on the page it's in (the window adds it itself, if
  // that page is open there).
  function placeIn(parentId, childId) {
    if (viewDoes("addPageBlock", parentId, childId) === true) return
    var parent = workspace.readPageNow(parentId)
    if (!parent) { workspace.editPage(parentId, function(p) { Workspace.appendBlocks(p, [{ type: "page", uid: childId, indent: 0 }]) }); return }
    Workspace.appendBlocks(parent, [{ type: "page", uid: childId, indent: 0 }])
    parent.modified = new Date().toISOString()
    workspace.savePage(parent)
    workspace.pageChanged(parentId)
  }
}
