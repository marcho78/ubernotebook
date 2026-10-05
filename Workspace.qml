import QtQuick
import "Workspace.js" as Workspace
import "Import.js" as Import
import "Blocks.js" as Blocks
import "Html.js" as Html
import "Markdown.js" as Markdown
import "Sketch.js" as Sketch
import "Tags.js" as Tags
import "Calendar.js" as Calendar
import "Contacts.js" as Contacts
import "Email.js" as Email
import "Files.js" as Files
import "Bookmark.js" as Bookmark
import "Permissions.js" as Permissions
import "Starter.js" as Starter
import "Agent.js" as Agent

// Pages on disk: the workspace in the Pages folder of your notebooks folder
// (~/Documents/Uber Notebook/Pages), a JSON file per page, named by its UUID, and
// index.json with the tree of pages (Workspace.js says what they may hold).
//
// It reads and writes through the notebooks' store (`files`): every file is
// written whole and atomically, and every program runs by its path with
// arguments, never through a shell with your text in it.
Item {
  id: ws

  // Store.qml: running programs, reading and writing files.
  property var files: null

  readonly property string folder: files && files.rootPath ? Workspace.pagesDir(files.rootPath) : ""
  property bool ready: false
  property var index: Workspace.emptyIndex()
  // Counts every change to the tree of pages (titles, icons, order, trash).
  property int revision: 0
  property int generation: 0

  signal failed(string message)
  // A page's file changed while it wasn't open (a page put inside it, or
  // taken out): a view showing it should read it again.
  signal pageChanged(string id)
  // A page was written (the Markdown copy follows).
  signal saved(string id)

  // Another folder: its own first start (the examples, if it's empty).
  onFolderChanged: {
    welcomed = false
    startingPeople = null
    if (folder) loadTimer.restart()
  }
  Timer {
    id: loadTimer
    interval: 50
    onTriggered: ws.load()
  }

  function pagePath(id) { return Workspace.pageFile(files.rootPath, id) }
  function indexPath() { return Workspace.indexFile(files.rootPath) }

  // ---- the tree of pages ------------------------------------------------------------------

  // Every page file's name in the folder, one a line.
  readonly property string listScript: "shopt -s nullglob; for f in \"$1\"/*.json; do printf '%s\\n' \"${f##*/}\"; done"
  property bool welcomed: false
  // What a new Pages starts with: "examples" (Starter.js: pages that show
  // what it can do, their people and events, templates), "templates" (just
  // the templates), or "" (one page to start from; the tests keep it).
  property string starter: ""
  // The examples' people and events, waiting for People and the calendar
  // to be read (so they're added to what's there, not written over).
  property var startingPeople: null

  // The Pages folder is made when something is first written to it, so
  // there's none until you use Pages.
  property bool folderMade: false

  // fn() once the folder's there (failed(false) if it can't be made).
  function withFolder(fn, failed) {
    if (folderMade) { fn(); return }
    files.mkdirs([folder, Workspace.assetsDir(files.rootPath)], function(ok) {
      if (!ok) { if (failed) failed(false); return }
      ws.folderMade = true
      fn()
    })
  }

  function load() {
    if (!folder) return
    ready = false
    calendarLoaded = false
    contactsLoaded = false
    var gen = ++generation
    folderMade = false
    // (Nothing of another folder's: its pages may have the same ids.)
    texts = ({})
    written = ({})
    readJson = ({})
    unreadable = ({})
    keptAt = ({})
    keptJson = ({})
    versionNames = ({})
    warming = ({})
    warmedAt = ({})
    files.readFiles([ws.indexPath()], function(got, read, failed) {
      if (gen !== ws.generation) return
      ws.keepUnreadable(ws.indexPath(), failed)
      var ix = Workspace.cleanIndex(files.parseJson(got[ws.indexPath()] || ""))
      files.exec(["/usr/bin/bash", "-c", ws.listScript, "uber-notebook-list", ws.folder], function(listed, output) {
        if (gen !== ws.generation) return
        var onDisk = String(output || "").split("\n").map(function(n) { return n.replace(/\.json$/, "") }).filter(Workspace.isUuid)
        var present = {}
        onDisk.forEach(function(id) { present[id] = true })
        // Pages whose files are gone leave the tree; files the tree doesn't
        // know are read and put in it.
        var changed = false
        if (listed) Object.keys(ix.pages).forEach(function(id) {
          if (!present[id] && !ws.written[id]) { Workspace.detach(ix, id); delete ix.pages[id]; changed = true }
        })
        var missing = onDisk.filter(function(id) { return !ix.pages[id] })
        ws.readPages(missing, function(pages) {
          if (gen !== ws.generation) return
          if (pages.length) {
            var raw = JSON.parse(Workspace.indexJson(ix))
            pages.forEach(function(p) {
              raw.pages[p.id] = { title: p.title, icon: p.icon, parent: p.parent, children: Workspace.childPages(p), created: p.created, modified: p.modified }
            })
            ix = Workspace.cleanIndex(raw)
            changed = true
          }
          ws.index = ix
          ws.ready = true
          ws.revision++
          if (changed) ws.saveIndex()
          ws.scanLinks()
          ws.scanTexts()
          ws.scheduleReminders()
          ws.loadCalendar()
          ws.loadContacts()
          ws.loadChats()
        })
      }, { okCodes: [0, 1] })
    })
  }

  // The first time Pages is opened, with no pages: a page to start from.
  function ensureStarted() {
    if (!ready || welcomed || Object.keys(index.pages).length > 0) return false
    welcomed = true
    if (starter === "examples" || starter === "templates") createExamples(starter === "templates")
    else createWelcome()
    return true
  }

  // index.json, a moment after the last change to the tree.
  function saveIndex() { indexTimer.restart() }

  // Its own files (the tree, the calendar, People, conversations) that
  // couldn't be read as it loaded (a link, too big, unreadable: not "not
  // there"): path -> true. Never written over (what changes meanwhile is kept
  // till it closes), said once.
  property var unreadable: ({})
  function keepUnreadable(path, failed) {
    if (!failed || failed.indexOf(path) < 0) return false
    var next = {}
    for (var k in unreadable) next[k] = true
    next[path] = true
    unreadable = next
    ws.failed("Couldn't read " + path.replace(files.home, "~") + ": it's left as it is, and changes to it aren't saved over it")
    return true
  }
  // A change to one of them, not saved: said (once a minute at most), so a
  // person added or an event moved isn't thought kept.
  property var refusedAt: ({})
  function notSaved(path) {
    var now = Date.now()
    if (refusedAt[path] && now - refusedAt[path] < 60000) return
    refusedAt[path] = now
    ws.failed("Not saved: " + path.replace(files.home, "~") + " couldn't be read, so it's left as it is")
  }

  Timer {
    id: indexTimer
    interval: 300
    onTriggered: ws.flushIndex()
  }

  // (done(ok) once it's written.)
  function flushIndex(done) {
    indexTimer.stop()
    if (!ready && Object.keys(index.pages).length === 0) { if (done) done(false); return }
    if (unreadable[indexPath()]) { notSaved(indexPath()); if (done) done(false); return }
    var text = Workspace.indexJson(index)
    withFolder(function() { files.writeFile(ws.indexPath(), text, done) }, done)
  }

  function touched() {
    revision++
    saveIndex()
  }

  function entry(id) { return index.pages[id] || null }

  // { title, icon } for a page block, or null for a page that isn't there
  // (or is in the trash).
  function pageMeta(id) {
    var e = index.pages[id]
    if (!e || Workspace.inTrash(index, id)) return null
    return { title: e.title, icon: e.icon }
  }

  // ---- pages -------------------------------------------------------------------------------

  // Every page written this session: what's on disk may still be on its way.
  property var written: ({})
  // Every page read this session, as its JSON: commands read it here, at once.
  property var readJson: ({})

  function readPages(ids, done) {
    var fresh = []
    var paths = []
    ids.forEach(function(id) {
      if (written[id]) fresh.push(JSON.parse(JSON.stringify(written[id])))
      else paths.push(pagePath(id))
    })
    if (paths.length === 0) { done(fresh); return }
    // (Another folder meanwhile: nothing of this one's kept, or given.)
    var gen = generation
    files.readFiles(paths, function(got) {
      if (gen !== ws.generation) { done([]); return }
      var out = fresh.slice()
      for (var path in got) {
        var id = path.slice(path.lastIndexOf("/") + 1, -5)
        var page = Workspace.cleanPage(files.parseJson(got[path]), id)
        if (page) { out.push(page); ws.readJson[id] = JSON.stringify(page) }
      }
      done(out)
    }, 32 * 1024 * 1024)
  }

  // One page: done(page) or done(null).
  function readPage(id, done) {
    if (!Workspace.isUuid(id)) { done(null); return }
    readPages([id], function(pages) { done(pages.length ? pages[0] : null) })
  }

  // One page, for a command that answers at once: as it was last written or
  // read this session (every page's read as Pages loads), else null. (While
  // the files helper reads your notes, never there and then: a file that
  // never ends would hold up the shell. Without it, as before, from its file.)
  function readPageNow(id) {
    if (!Workspace.isUuid(id)) return null
    if (written[id]) return JSON.parse(JSON.stringify(written[id]))
    if (readJson[id]) return JSON.parse(readJson[id])
    if (typeof files.servesNotes === "function" && files.servesNotes(pagePath(id))) { warm(id); return null }
    var text = files.readNow(pagePath(id), 32 * 1024 * 1024)
    return text === null ? null : Workspace.cleanPage(files.parseJson(text), id)
  }

  // A page a command asked for before it was read (just after Uber Notebook
  // starts, while the rest are read in the background): read now, first, so
  // the command run again has it (isWarming(id) meanwhile). One that can't
  // be read isn't tried again for ten seconds: "couldn't read" meanwhile.
  property var warming: ({})
  property var warmedAt: ({})
  function warm(id) {
    if (warming[id] || !index.pages[id]) return
    if (warmedAt[id] && Date.now() - warmedAt[id] < 10000) return
    warmedAt[id] = Date.now()
    warming[id] = true
    var gen = generation
    readPage(id, function() { if (gen === ws.generation) delete ws.warming[id] })
  }
  function isWarming(id) { return !!warming[id] }
  // The pages these pages' synced blocks show (and theirs, a few deep), read
  // first, so what asks for them at once (an export, a Markdown copy) has
  // them: done().
  function readSyncedOf(pages, done, round) {
    var want = []
    pages.forEach(function(p) {
      for (var k in (p && p.blocks) || {}) {
        var b = p.blocks[k]
        var sid = b && b.type === "synced" && b.data ? b.data.page : ""
        if (Workspace.isUuid(sid) && want.indexOf(sid) < 0 && !ws.written[sid] && !ws.readJson[sid] && ws.index.pages[sid]) want.push(sid)
      }
    })
    if (!want.length || (round || 0) >= 5) { done(); return }
    readPages(want.slice(0, 50), function(read) { ws.readSyncedOf(read, done, (round || 0) + 1) })
  }
  // Pages read at once, all of them, or null (those not read yet being read).
  function readPagesNow(ids) {
    var out = []
    var missed = false
    ids.forEach(function(id) { var p = ws.readPageNow(id); if (p) out.push(p); else missed = true })
    return missed ? null : out
  }

  // Every page's text (its title first), so commands find pages at once:
  // read in the background when Pages loads, and kept as pages are written.
  property var texts: ({})

  function scanTexts() {
    var ids = Object.keys(index.pages).filter(function(id) { return ws.texts[id] === undefined })
    var gen = generation
    function next() {
      if (gen !== ws.generation || ids.length === 0) return
      readPages(ids.splice(0, 200), function(pages) {
        pages.forEach(function(p) { if (ws.texts[p.id] === undefined) ws.texts[p.id] = p.text || Workspace.pageText(p) })
        Qt.callLater(next)
      })
    }
    next()
  }

  // Writes a page, and what the tree knows of it: its title, icon, and the
  // pages on it (in the order their blocks are). done(ok) once it's written.
  function savePage(page, done) {
    if (!page || !Workspace.isUuid(page.id)) { if (done) done(false); return }
    // The page as it was, kept in its history first (every ten minutes of writing).
    keepVersion(page.id, "edit", false)
    page.text = Workspace.pageText(page)
    written[page.id] = JSON.parse(JSON.stringify(page))
    texts[page.id] = page.text
    var path = pagePath(page.id)
    var text = Workspace.pageJson(page)
    withFolder(function() { files.writeFile(path, text, done) }, done)
    var e = index.pages[page.id]
    if (!e) {
      index.pages[page.id] = { title: page.title, icon: page.icon, parent: "", children: [], trashed: false, created: page.created, modified: page.modified }
      Workspace.attach(index, page.id, page.parent, -1)
      touched()
    }
    e = index.pages[page.id]
    var changed = e.title !== page.title || e.icon !== page.icon
    e.title = page.title
    e.icon = page.icon
    e.modified = page.modified
    if (Workspace.syncChildren(index, page.id, Workspace.childPages(page))) changed = true
    // What it links to (for backlinks) and its reminders.
    var links = Workspace.linkedPages(page)
    if (JSON.stringify(links) !== JSON.stringify(e.links)) { e.links = links; changed = true }
    var reminders = Workspace.pageReminders(page)
    if (JSON.stringify(reminders) !== JSON.stringify(e.reminders)) { e.reminders = reminders; scheduleReminders() }
    var tags = Workspace.pageTags(page)
    if (JSON.stringify(tags) !== JSON.stringify(e.tags)) { e.tags = tags; changed = true }
    // What's been put on it, for the Library.
    var collected = Workspace.pageCollected(page)
    if (JSON.stringify(collected) !== JSON.stringify(e.collected)) { e.collected = collected; changed = true }
    // A project's status and due date, and the to-dos (its progress).
    var project = page.project || null
    if (JSON.stringify(project) !== JSON.stringify(e.project)) { e.project = project; changed = true }
    var checks = Workspace.pageChecks(page)
    if (JSON.stringify(checks) !== JSON.stringify(e.checks)) { e.checks = checks; changed = true }
    if (changed) touched()
    else saveIndex()
    saved(page.id)
  }

  // ---- the archive ----------------------------------------------------------------------------

  // A page put away in the archive (with the pages in it), or back out.
  function setArchived(id, on) {
    var e = index.pages[id]
    if (!e || e.archived === !!on) return
    e.archived = !!on
    touched()
  }

  // ---- tags -------------------------------------------------------------------------------

  // Every tag (not the trash's): [{ name, label, pages, blocks }].
  function tags() { return Workspace.tagList(index) }

  // A tag's color: one of Pages' ("blue"), one of your own, or "" for none.
  function setTagColor(name, color) {
    var n = Tags.clean(name)
    if (!n) return
    // (A new object, so what's drawn from it hears.)
    var colors = {}
    var had = index.tagColors || {}
    for (var k in had) colors[k] = had[k]
    var c = Workspace.cleanTagColor(color)
    if (c) colors[n] = c
    else delete colors[n]
    index.tagColors = colors
    touched()
  }

  // A tag renamed, or taken away (`to` ""), on every page with it: each page
  // keeps the version it was in its history first. done(pages changed).
  function changeTag(name, to, done) {
    var from = Tags.clean(name)
    var into = to ? Tags.clean(to) : ""
    if (!from || (to && !into)) { if (done) done(0); return }
    var ids = Workspace.pagesTagged(index, from)
    var changed = 0
    var i = 0
    function next() {
      if (i >= ids.length) {
        var colors = index.tagColors || {}
        if (colors[from] !== undefined) {
          if (into && colors[into] === undefined) colors[into] = colors[from]
          if (into !== from) delete colors[from]
          index.tagColors = colors
        }
        touched()
        if (done) done(changed)
        return
      }
      var id = ids[i++]
      keepVersion(id, "tag", true)
      editPage(id, function(page) {
        var n = Workspace.changeTags(page, function(inner) { return into ? Tags.rename(inner, from, to) : Tags.remove(inner, from) })
        if (n === 0) return false
        changed++
      }, function() { next() })
    }
    next()
  }

  // ---- page history ---------------------------------------------------------------------

  // Earlier versions of a page, a file each in Pages/history/<id>/: the page
  // as it was before it's written, when the last version kept is ten minutes
  // old or more (so the page as it was before you started writing is always
  // there), and always before a command or an agent changes it ("command")
  // and before an older version is put back ("restore"). A page's newest
  // Workspace.HISTORY_KEEP are kept.
  property int historyGap: 10 * 60 * 1000
  // id -> when its last version was kept (ms), and what it was (its JSON).
  property var keptAt: ({})
  property var keptJson: ({})
  signal versionKept(string id)

  function keepVersion(id, why, always) {
    if (!Workspace.isUuid(id) || !index.pages[id]) return false
    // (Never two in the same millisecond: each has a file of its own.)
    var now = Math.max(Date.now(), (keptAt[id] || 0) + 1)
    if (!always && keptAt[id] && now - keptAt[id] < historyGap) return false
    // (A page with no file yet, just made, counts as kept now; a version
    // that couldn't be written doesn't hold back the next.)
    keptAt[id] = now
    var page = readPageNow(id)
    if (!page) return false
    delete page.text
    var json = Workspace.pageJson(page)
    if (keptJson[id] === json) return false
    keptJson[id] = json
    var dir = Workspace.historyDir(files.rootPath, id)
    var text = JSON.stringify({ kept: new Date(now).toISOString(), why: why || "edit", page: JSON.parse(json) })
    function missed() {
      if (ws.keptAt[id] === now) delete ws.keptAt[id]
      if (ws.keptJson[id] === json) delete ws.keptJson[id]
    }
    files.mkdirs([dir], function(ok) {
      if (!ok) { missed(); return }
      var name = Workspace.versionName(new Date(now))
      files.writeFile(dir + "/" + name, text, function(written) {
        if (!written) { missed(); return }
        if (ws.versionNames[id]) ws.versionNames[id] = [name].concat(ws.versionNames[id])
        ws.versionKept(id)
        ws.pruneVersions(id)
      })
    })
    return true
  }

  // A page's versions, newest first: done([{ name, date }]). (What's found
  // is kept, so the commands agents use can answer at once.)
  property var versionNames: ({})
  function listVersions(id, done) {
    if (!Workspace.isUuid(id)) { done([]); return }
    files.exec(["/usr/bin/bash", "-c", listScript, "uber-notebook-list", Workspace.historyDir(files.rootPath, id)], function(ok, output) {
      var list = ok ? Workspace.versionList(String(output || "").split("\n")) : []
      ws.versionNames[id] = list.map(function(v) { return v.name })
      done(list)
    })
  }

  // One version: done({ kept, why, page }) or done(null).
  function readVersion(id, name, done) {
    var path = Workspace.historyDir(files.rootPath, id) + "/" + name
    if (!Workspace.versionDate(name)) { done(null); return }
    files.readFiles([path], function(got) {
      var v = files.parseJson(got[path] || "")
      var page = v ? Workspace.cleanPage(v.page, id) : null
      done(page ? { kept: v.kept || "", why: v.why || "", page: page } : null)
    }, 32 * 1024 * 1024)
  }

  // Past the newest Workspace.HISTORY_KEEP: gone.
  function pruneVersions(id) {
    listVersions(id, function(list) {
      var past = Workspace.versionsPast(list.map(function(v) { return v.name }))
      if (past.length === 0) return
      var dir = Workspace.historyDir(files.rootPath, id)
      files.exec(["/usr/bin/rm", "-f", "--"].concat(past.map(function(n) { return dir + "/" + n })), null)
    })
  }

  // Pages written before links and reminders were kept in the tree (or
  // changed elsewhere): read once, in the background, to fill them in.
  function scanLinks() {
    var ids = Object.keys(index.pages).filter(function(id) { return index.pages[id].links === null || index.pages[id].reminders === null || index.pages[id].tags === null || index.pages[id].checks === null || index.pages[id].collected === null })
    if (ids.length === 0) return
    readPages(ids.slice(0, 2000), function(pages) {
      pages.forEach(function(p) {
        var e = ws.index.pages[p.id]
        if (!e) return
        e.links = Workspace.linkedPages(p)
        e.reminders = Workspace.pageReminders(p)
        e.tags = Workspace.pageTags(p)
        e.collected = Workspace.pageCollected(p)
        e.checks = Workspace.pageChecks(p)
        e.project = p.project || null
      })
      ws.touched()
      ws.scheduleReminders()
    })
  }

  // ---- reminders ---------------------------------------------------------------------------

  // A reminder comes as an Omarchy notification with what the block says;
  // clicking it opens the page. One that came while Uber Notebook wasn't running
  // comes when it starts, if it was in the last 12 hours.
  readonly property int lateness: 12 * 3600000

  // What's to come: the pages' reminders and the calendar's alerts (the
  // next two days of them), soonest first: [{ key, at, title, text, page, day }].
  function pendingAlerts() {
    var now = Date.now()
    var list = Workspace.pendingReminders(index).map(function(r) {
      var e = ws.index.pages[r.page]
      return { key: r.key, at: r.at, title: e && e.title ? e.title : "Reminder", text: r.text || "Reminder", page: r.page, day: "" }
    })
    Calendar.alerts(calendar, new Date(now - lateness), new Date(now + 2 * 86400000)).forEach(function(a) {
      if (!ws.index.fired[a.key]) list.push(a)
    })
    return list.sort(function(a, b) { return a.at - b.at })
  }

  function scheduleReminders() {
    if (!ready) return
    var pending = pendingAlerts()
    // (Alerts further on come into the next two days: a look every hour.)
    var wait = pending.length ? pending[0].at.getTime() - Date.now() : 3600000
    reminderTimer.interval = Math.max(500, Math.min(3600000, wait))
    reminderTimer.restart()
  }

  Timer {
    id: reminderTimer
    onTriggered: ws.checkReminders()
  }

  function checkReminders() {
    var now = Date.now()
    var any = false
    pendingAlerts().forEach(function(r) {
      if (r.at.getTime() > now + 1000) return
      if (now - r.at.getTime() <= ws.lateness) ws.files.notify(r.title, r.text, r.page, r.day)
      ws.index.fired[r.key] = true
      any = true
    })
    // (A calendar alert's key goes once its day's long gone.)
    var old = Calendar.dayIso(new Date(now - 4 * 86400000))
    Object.keys(index.fired).forEach(function(k) {
      var m = /^cal\|[^|]+\|(\d{4}-\d{2}-\d{2})\|/.exec(k)
      if (m && m[1] < old) { delete ws.index.fired[k]; any = true }
    })
    if (any) saveIndex()
    scheduleReminders()
  }

  // ---- the calendar --------------------------------------------------------------------------

  // Pages/calendar.json: your events (Calendar.js), and the steps Undo takes back.
  property var calendar: Calendar.make()
  property int calendarRevision: 0
  property bool calendarLoaded: false
  property var calendarUndo: []
  property var calendarRedo: []
  function calendarPath() { return folder + "/calendar.json" }

  function loadCalendar() {
    if (!folder) return
    files.readFiles([calendarPath()], function(got, read, failed) {
      ws.keepUnreadable(ws.calendarPath(), failed)
      var raw = got[ws.calendarPath()]
      ws.calendar = Calendar.clean(raw ? files.parseJson(raw) : null)
      ws.calendarUndo = []
      ws.calendarRedo = []
      ws.calendarLoaded = true
      ws.calendarRevision++
      ws.scheduleReminders()
      ws.addStartingPeople()
    })
  }

  function writeCalendar() {
    if (!folder) return
    if (unreadable[calendarPath()]) { notSaved(calendarPath()); return }
    files.writeFile(calendarPath(), JSON.stringify(calendar, null, 1) + "\n")
  }

  // The calendar changed (`next`, a new copy), kept, as a step Undo takes back.
  function setCalendar(next) {
    calendarUndo = calendarUndo.concat([calendar]).slice(-100)
    calendarRedo = []
    calendar = Calendar.clean(next)
    calendarRevision++
    writeCalendar()
    scheduleReminders()
  }

  function undoCalendar() {
    if (calendarUndo.length === 0) return false
    calendarRedo = calendarRedo.concat([calendar])
    calendar = calendarUndo[calendarUndo.length - 1]
    calendarUndo = calendarUndo.slice(0, -1)
    calendarRevision++
    writeCalendar()
    scheduleReminders()
    return true
  }

  function redoCalendar() {
    if (calendarRedo.length === 0) return false
    calendarUndo = calendarUndo.concat([calendar])
    calendar = calendarRedo[calendarRedo.length - 1]
    calendarRedo = calendarRedo.slice(0, -1)
    calendarRevision++
    writeCalendar()
    scheduleReminders()
    return true
  }

  function eventById(id) { return Calendar.byId(calendar, id) }

  // The calendar as an .ics file, where exports go: done(its path, or "").
  function exportCalendar(done) {
    function to(base) {
      var path = base + "/Uber Notebook calendar " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm") + ".ics"
      files.mkdirs([base], function() {
        files.writeFile(path, Calendar.toIcs(calendar, new Date()), function(ok) {
          if (ok && typeof files.exported === "function") files.exported(path)
          if (done) done(ok ? path : "")
        })
      })
    }
    if (typeof files.exportBase === "function") files.exportBase(function(base) { if (base) to(base); else if (done) done("") })
    else to(files.rootPath + "/Exports")
  }

  // ---- conversations with your agent ----------------------------------------------------------

  // Pages/chats.json: each page's conversation with your agent (Agent.js
  // cleanChats), so it can be gone back to, after the panel's closed or
  // Uber Notebook's started again.
  property var chats: ({})
  property int chatsRevision: 0
  function chatsPath() { return folder + "/chats.json" }

  function loadChats() {
    if (!folder) return
    files.readFiles([chatsPath()], function(got, read, failed) {
      ws.keepUnreadable(ws.chatsPath(), failed)
      var raw = got[ws.chatsPath()]
      ws.chats = Agent.cleanChats(raw ? files.parseJson(raw) : null)
      ws.chatsRevision++
    })
  }
  function writeChats() {
    if (!folder) return
    if (unreadable[chatsPath()]) { notSaved(chatsPath()); return }
    var text = JSON.stringify({ version: 1, chats: chats }, null, 1) + "\n"
    withFolder(function() { files.writeFile(ws.chatsPath(), text) })
  }
  // The page's conversation, or null.
  function chatFor(id) { return id && chats[id] ? chats[id] : null }
  // Kept (as it is now), or (null) gone.
  function setChat(id, chat) {
    if (!id) return
    var next = {}
    Object.keys(chats).forEach(function(k) { next[k] = chats[k] })
    var c = chat ? Agent.cleanChat(chat) : null
    if (c) next[id] = c
    else delete next[id]
    chats = Agent.cleanChats({ chats: next })
    chatsRevision++
    writeChats()
  }

  // ---- people -------------------------------------------------------------------------------

  // Pages/contacts.json: the people (Contacts.js), and the steps Undo takes back.
  property var contacts: Contacts.make()
  property int contactsRevision: 0
  property bool contactsLoaded: false
  property var contactsUndo: []
  function contactsPath() { return folder + "/contacts.json" }

  function loadContacts() {
    if (!folder) return
    files.readFiles([contactsPath()], function(got, read, failed) {
      ws.keepUnreadable(ws.contactsPath(), failed)
      var raw = got[ws.contactsPath()]
      ws.contacts = Contacts.clean(raw ? files.parseJson(raw) : null)
      ws.contactsUndo = []
      ws.contactsLoaded = true
      ws.contactsRevision++
      ws.addStartingPeople()
    })
  }

  function writeContacts() {
    if (!folder) return
    if (unreadable[contactsPath()]) { notSaved(contactsPath()); return }
    withFolder(function() { files.writeFile(ws.contactsPath(), JSON.stringify(ws.contacts, null, 1) + "\n") })
  }

  // The people changed (`next`, a new copy), kept, as a step Undo takes back.
  function setContacts(next) {
    contactsUndo = contactsUndo.concat([contacts]).slice(-50)
    contacts = Contacts.clean(next)
    contactsRevision++
    writeContacts()
  }

  function undoContacts() {
    if (contactsUndo.length === 0) return false
    contacts = contactsUndo[contactsUndo.length - 1]
    contactsUndo = contactsUndo.slice(0, -1)
    contactsRevision++
    writeContacts()
    return true
  }

  function contactById(id) { return Contacts.byId(contacts, id) }
  // A person changed or added (as typed in their card): kept.
  function saveContact(c) { setContacts(Contacts.withContact(contacts, c, new Date())) }

  // A .vcf or .csv file's people put in (those there already filled in, not
  // added twice): done({ added, updated }), or done(null, why).
  function importContacts(path, done) {
    files.readFiles([path], function(got) {
      var raw = got[path]
      if (raw === undefined || raw === null) { done(null, "It couldn't be read"); return }
      var people = Contacts.fromFile(path, raw)
      if (people.length === 0) { done(null, "There are no contacts in it (a .vcf or a .csv of contacts)"); return }
      var r = Contacts.merge(ws.contacts, people, new Date())
      ws.setContacts(r.book)
      done({ added: r.added, updated: r.updated })
    }, 64 * 1024 * 1024)
  }

  // Everyone as a .vcf file, where exports go: done(its path, or "").
  function exportContacts(done) {
    function to(base) {
      var path = base + "/Uber Notebook contacts " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm") + ".vcf"
      files.mkdirs([base], function() {
        files.writeFile(path, Contacts.toVcard(ws.contacts), function(ok) {
          if (ok && typeof files.exported === "function") files.exported(path)
          if (done) done(ok ? path : "")
        })
      })
    }
    if (typeof files.exportBase === "function") files.exportBase(function(base) { if (base) to(base); else if (done) done("") })
    else to(files.rootPath + "/Exports")
  }

  // A new page (written straight away): { parent, at, title, icon, cover,
  // format, blocks }. Returns it.
  function createPage(options) {
    var o = options || {}
    var page = Workspace.newPage({ id: o.id, parent: o.parent, title: o.title, icon: o.icon, cover: o.cover, format: o.format, project: o.project, blocks: o.blocks || [{ type: "p", html: "", indent: 0 }] })
    if (!page) return null
    index.pages[page.id] = { title: page.title, icon: page.icon, parent: "", children: [], trashed: false, created: page.created, modified: page.modified }
    Workspace.attach(index, page.id, o.parent && index.pages[o.parent] ? o.parent : "", typeof o.at === "number" ? o.at : -1)
    page.parent = index.pages[page.id].parent
    savePage(page)
    touched()
    return page
  }

  // Changes a page that isn't open: fn(page) changes it, then it's written
  // and pageChanged tells whoever shows it.
  function editPage(id, fn, done) {
    readPage(id, function(page) {
      if (!page) { if (done) done(false); return }
      if (fn(page) === false) { if (done) done(false); return }
      page.modified = new Date().toISOString()
      ws.savePage(page)
      ws.pageChanged(id)
      if (done) done(true)
    })
  }

  // A page (and the pages in it) to the trash. `open`: the page it's on is
  // open, and the view takes its block off; else it comes off the file here.
  function trashPage(id, open) {
    var e = index.pages[id]
    if (!e || e.trashed) return
    e.trashed = true
    e.modified = new Date().toISOString()
    if (e.parent && !open) editPage(e.parent, function(p) { return Workspace.removeBlock(p, id) })
    touched()
  }

  // Out of the trash, back at the end of the page it was in (or at the top,
  // if that's gone or in the trash too).
  function restorePage(id, parentOpen) {
    var e = index.pages[id]
    if (!e) return
    e.trashed = false
    if (e.parent && (!index.pages[e.parent] || Workspace.inTrash(index, e.parent))) Workspace.attach(index, id, "", -1)
    else if (e.parent && !parentOpen) editPage(e.parent, function(p) { return Workspace.appendPageBlock(p, id) })
    touched()
  }

  // Out of the trash for good: its file (and those of the pages in it) go to
  // the notebooks folder's .trash, as nothing in Uber Notebook is ever deleted.
  function deleteForever(id) {
    if (!index.pages[id]) return
    var all = Workspace.withDescendants(index, id)
    Workspace.detach(index, id)
    all.forEach(function(pid) {
      delete index.pages[pid]
      delete written[pid]
      delete readJson[pid]
      delete texts[pid]
      files.trash(ws.pagePath(pid), "page-" + pid + ".json")
      // Its history goes with it (if it has one).
      ws.listVersions(pid, function(list) { if (list.length) files.trash(Workspace.historyDir(files.rootPath, pid), "history-" + pid) })
    })
    // And its conversations with your agent.
    if (all.some(function(pid) { return chats[pid] })) {
      var kept = {}
      Object.keys(chats).forEach(function(k) { if (all.indexOf(k) < 0) kept[k] = chats[k] })
      chats = kept
      chatsRevision++
      writeChats()
    }
    touched()
  }

  // A page moved in the tree: under `parent` ("" is the top) at `at`. The
  // files of the page it was on and the page it goes on are changed unless
  // the view has one open (`openId`), which it changes itself.
  function movePage(id, parent, at, openId) {
    var e = index.pages[id]
    if (!e || id === parent || (parent && Workspace.isInside(index.pages, parent, id))) return false
    var from = e.parent
    Workspace.attach(index, id, parent, at)
    if (from && from !== parent && from !== openId) editPage(from, function(p) { return Workspace.removeBlock(p, id) })
    if (parent && from !== parent && parent !== openId) editPage(parent, function(p) { return Workspace.appendPageBlock(p, id) })
    // The page's own file says where it is too.
    if (from !== parent && id !== openId) editPage(id, function(p) { p.parent = parent; return true })
    touched()
    return true
  }

  // A page put in a place in the tree (Workspace.dropPlace, placeOf): under
  // `parent` at `at`, its block on that page beside the pages it goes
  // between; off the page it was on. done() once the pages are written.
  function placePage(id, place, done) {
    var e = index.pages[id]
    if (!e || !place || (place.parent && (place.parent === id || Workspace.isInside(index.pages, place.parent, id)))) { if (done) done(false); return }
    var from = e.parent
    Workspace.attach(index, id, place.parent, place.at)
    var pending = 1
    function one() { if (--pending === 0) { ws.touched(); if (done) done(true) } }
    if (from && from !== place.parent) { pending++; editPage(from, function(p) { return Workspace.removeBlock(p, id) }, one) }
    if (place.parent) { pending++; editPage(place.parent, function(p) { return Workspace.placePageBlock(p, id, place.before, place.after) }, one) }
    if (from !== place.parent) { pending++; editPage(id, function(p) { p.parent = place.parent; return true }, one) }
    touched()
    one()
  }

  // ---- templates ---------------------------------------------------------------------------------

  // A page (and the pages in it) a template, or a page again.
  function setTemplate(id, on) {
    var e = index.pages[id]
    if (!e || e.template === !!on) return
    e.template = !!on
    e.modified = new Date().toISOString()
    touched()
  }

  // What a template's for (Templates shows it under its name).
  function setDescription(id, text) {
    var e = index.pages[id]
    var d = Workspace.cleanDescription(String(text || ""))
    if (!e || (e.description || "") === d) return
    e.description = d
    touched()
  }

  // A synced block's page, or not.
  function setSynced(id, on) {
    var e = index.pages[id]
    if (!e || e.synced === !!on) return
    e.synced = !!on
    touched()
  }

  // A synced block's page, made with blocks (editor blocks: { type, html,
  // indent... }); returns its id.
  function newSyncedPage(blocks) {
    var p = createPage({ parent: "", title: "Synced block", blocks: blocks && blocks.length ? blocks : undefined })
    if (!p) return ""
    setSynced(p.id, true)
    return p.id
  }

  // ---- files and bookmarks ----------------------------------------------------------------

  // A file copied into Pages/assets: done({ src, name, size, kind }) or done(null).
  // Only a plain file (not a device or a pipe), read once, at most $3 bytes,
  // into a new file (never over one that's there); its size printed.
  // (The new file is made first; only what was made here is ever taken away.)
  readonly property string importFileScript: "set -C -o pipefail; t=$(/usr/bin/stat -L -c %F -- \"$1\") || exit 1; "
    + "case \"$t\" in 'regular file'|'regular empty file') ;; *) echo 'not a plain file' >&2; exit 1 ;; esac; "
    + "exec 3> \"$2\" || exit 1; "
    + "if ! /usr/bin/head -c \"$(($3 + 1))\" -- \"$1\" >&3; then exec 3>&-; /usr/bin/rm -f -- \"$2\"; exit 1; fi; exec 3>&-; "
    + "n=$(/usr/bin/stat -c %s -- \"$2\") || exit 1; if [ \"$n\" -gt \"$3\" ]; then /usr/bin/rm -f -- \"$2\"; echo 'too big' >&2; exit 1; fi; echo \"$n\""
  readonly property real fileMax: 8 * 1024 * 1024 * 1024
  readonly property real emailMax: 64 * 1024 * 1024
  function importFile(path, done) {
    var p = String(path || "")
    var name = p.slice(p.lastIndexOf("/") + 1)
    if (!p || !name || !folder) { done(null); return }
    var asset = Files.assetName(name, new Date())
    var dest = Workspace.assetsDir(files.rootPath) + "/" + asset
    files.mkdirs([Workspace.assetsDir(files.rootPath)], function() {
      files.exec(["/usr/bin/bash", "-c", ws.importFileScript, "uber-notebook-import-file", p, dest, String(ws.fileMax)], function(ok, out) {
        if (!ok) { done(null); return }
        var f = { src: "assets/" + asset, name: name, size: Number(String(out).trim()) || 0, kind: Files.kindOf(name), poster: "" }
        if (f.kind !== "video") { done(f); return }
        // A video's still: a frame from a second in (or its first).
        var still = asset.replace(/\.[A-Za-z0-9]+$/, "") + "-still.jpg"
        files.exec(["/usr/bin/bash", "-c", ws.stillScript, "uber-notebook-still", dest, Workspace.assetsDir(files.rootPath) + "/" + still], function(ok2) {
          if (ok2) f.poster = "assets/" + still
          done(f)
        }, { timeoutMs: 30000, maxBytes: 4096 })
      }, { timeoutMs: 120000, maxBytes: 4096 })
    })
  }
  // An .eml copied into Pages/assets and read: done({ src, name, size,
  // subject, from, to, cc, date, preview, attachments }), or done(null, why).
  function importEmail(path, done) {
    var p = String(path || "")
    var name = p.slice(p.lastIndexOf("/") + 1)
    if (!p || !name || !folder) { done(null, "There's no file"); return }
    var asset = Email.assetName(name, new Date())
    var dir = Workspace.assetsDir(files.rootPath)
    files.mkdirs([dir], function() {
      files.exec(["/usr/bin/bash", "-c", ws.importFileScript, "uber-notebook-import-file", p, dir + "/" + asset, String(ws.emailMax)], function(ok, out) {
        if (!ok) { done(null, "It couldn't be copied in"); return }
        files.readFiles([dir + "/" + asset], function(got) {
          var m = Email.parse(got[dir + "/" + asset] || "")
          if (!m) { done(null, "That isn't an email (.eml)"); return }
          var s = Email.summary(m)
          s.src = "assets/" + asset
          s.name = name
          s.size = Number(String(out).trim()) || 0
          done(s)
        }, 64 * 1024 * 1024)
      }, { timeoutMs: 60000, maxBytes: 4096 })
    })
  }

  // A file in Pages/assets in its app (not a web browser's): done(ok, why).
  function openAsset(src, done) {
    if (!Files.cleanSrc(src) || !folder) { if (done) done(false, "none"); return }
    files.openFile(folder + "/" + src, done)
  }
  // A file in Pages/assets, read as words: done(text), or done(null).
  function readAsset(src, done) {
    if (!Files.cleanSrc(src) || !folder) { done(null); return }
    var path = folder + "/" + src
    files.readFiles([path], function(got) { done(got[path] !== undefined ? got[path] : null) }, 16 * 1024 * 1024)
  }
  // People from a contact card's words (an email's .vcf), put in: done({ added, updated, first }), or done(null).
  function addPeopleFrom(name, text, done) {
    var people = Contacts.fromFile(name, String(text || ""))
    if (!people.length) { done(null); return }
    var before = contacts.contacts.map(function(c) { return c.id })
    var r = Contacts.merge(contacts, people, new Date())
    setContacts(r.book)
    var first = contacts.contacts.filter(function(c) { return before.indexOf(c.id) < 0 })[0]
    done({ added: r.added, updated: r.updated, first: first ? first.id : "" })
  }

  // An email in Pages/assets, read: done(the message, Email.parse's), or done(null).
  function readEmail(src, done) {
    if (!Files.cleanSrc(src) || !folder) { done(null); return }
    var path = folder + "/" + src
    files.readFiles([path], function(got) { done(got[path] !== undefined ? Email.parse(got[path]) : null) }, 64 * 1024 * 1024)
  }

  // An email's attachment written out into Pages/assets (from its base64,
  // through a file beside it, then decoded): done("assets/<name>"), or done("").
  readonly property string unpackScript: "/usr/bin/base64 -d -- \"$1\" > \"$2\"; s=$?; /usr/bin/rm -f -- \"$1\"; exit $s"
  // (`at`: which of its attachments, in the order the block lists them.)
  function emailAttachment(src, at, name, done) {
    readEmail(src, function(m) {
      var a = m ? m.attachments[at] : null
      if (!a) { done(""); return }
      var data = Email.attachmentBase64(m, a.index)
      var out = Files.assetName(name || a.name, new Date()).replace(/^file-/, "mail-")
      var dir = Workspace.assetsDir(files.rootPath)
      var tmp = dir + "/.unpack-" + Math.random().toString(36).slice(2, 10) + ".b64"
      files.writeFile(tmp, data, function(ok) {
        if (!ok) { done(""); return }
        files.exec(["/usr/bin/bash", "-c", ws.unpackScript, "uber-notebook-unpack", tmp, dir + "/" + out], function(ok2) {
          done(ok2 ? "assets/" + out : "")
        }, { timeoutMs: 60000, maxBytes: 4096 })
      })
    })
  }

  // (ffmpeg reads the video as a file on this computer, in a video format:
  // not a playlist or a list of other files.)
  readonly property string stillScript: "w='-protocol_whitelist file -format_whitelist mov,matroska,avi,ogg,mpegts,flv,asf'; /usr/bin/ffmpeg -hide_banner -loglevel error -nostdin -y $w -ss 1 -i \"$1\" -frames:v 1 -vf 'scale=min(1280\\,iw):-2' \"$2\" || /usr/bin/ffmpeg -hide_banner -loglevel error -nostdin -y $w -i \"$1\" -frames:v 1 \"$2\""

  // A link's page read (its title, a line about it, its picture, kept in
  // assets): done(bookmark data, or null and why). Only http and https, and
  // only on the internet (fetchPage); a page of at most 2 MB, a picture of
  // at most 5 MB, 15 seconds each.
  function fetchBookmark(url, done) {
    var u = Bookmark.cleanUrl(url)
    if (!u) { done(null, "That isn't a web link (https://...)"); return }
    fetchPage(u, false, function() { return "" }, function(html, from, why) {
      if (html === null || !String(html).trim()) { done({ url: u, title: "", description: "", site: Bookmark.domain(u), image: "" }, why || "The page couldn't be read: the link's kept"); return }
      var meta = Bookmark.parse(html, from)
      var data = { url: u, title: meta.title, description: meta.description, site: meta.site, image: "" }
      ws.fetchBookmarkPicture(meta.image, function(src) {
        if (src) data.image = src
        done(data, "")
      })
    })
  }

  // A link's page read for an agent, contacting only `hosts` (the sites
  // you've let it have contacted, Permissions.js): https only, and as
  // fetchPage reads any; a redirect followed only to one of them; the
  // picture only from one of them. Then as fetchBookmark: done(bookmark
  // data, or null and why).
  readonly property string fetchAgent: "Mozilla/5.0 (X11; Linux) Uber Notebook"
  function fetchBookmarkWithin(url, hosts, done) {
    var u = Bookmark.cleanUrl(url)
    var allowed = (hosts || []).map(function(h) { return Permissions.cleanHost(h) }).filter(function(h) { return h !== "" })
    function within(link) { var h = Permissions.hostOf(link); return h !== "" && allowed.indexOf(h) >= 0 }
    if (!u || !within(u)) { done(null, "Uber Notebook may not contact that site for it"); return }
    function kept(why) { done({ url: u, title: "", description: "", site: Bookmark.domain(u), image: "" }, why) }
    fetchPage(u, true, function(link) { return within(link) ? "" : "It goes on to a site you haven't let it contact: the link's kept" }, function(html, from, why) {
      if (html === null || !String(html).trim()) { kept(why || "The page couldn't be read: the link's kept"); return }
      var meta = Bookmark.parse(html, from)
      var data = { url: u, title: meta.title, description: meta.description, site: meta.site, image: "" }
      if (!meta.image || !within(meta.image)) { done(data, ""); return }
      ws.fetchBookmarkPicture(meta.image, function(src) { if (src) data.image = src; done(data, "") })
    })
  }

  // A page read step by step (a bookmark's): each step one request that
  // curl itself never redirects, to a host looked up first (every address
  // it has a public one: not this computer, your network or a reserved
  // range), from that address (--resolve), past no proxy (one would look it
  // up again for itself); a redirect followed here, at most five, each one
  // checked again, and by `allow(link)` ("" or why not). done(html, the link
  // it's from, "") or done(null, "", why).
  function fetchPage(url, httpsOnly, allow, done) {
    function step(link, hops) {
      var no = allow(link)
      if (no) { done(null, "", no); return }
      var target = Bookmark.pageTarget(link, httpsOnly)
      if (!target) { done(null, "", "The page couldn't be read: the link's kept"); return }
      files.exec(["/usr/bin/getent", "ahosts", target.host], function(okR, outR) {
        var ips = okR ? Bookmark.addresses(outR) : []
        if (!ips.length || !ips.every(Bookmark.isPublicIp)) { done(null, "", "That site isn't on the internet (it's this computer or your network): the link's kept"); return }
        var ip = ips.filter(function(a) { return a.indexOf(":") < 0 })[0] || ips[0]
        var at = target.host + ":" + target.port + ":" + (ip.indexOf(":") >= 0 ? "[" + ip + "]" : ip)
        // (It prints the page, then on a line of its own after it, how it
        // answered: its code, and where it sends you on to.)
        files.exec(["/usr/bin/curl", "-q", "-s", "--noproxy", "*", "--proto", httpsOnly ? "=https" : "=http,https", "--max-redirs", "0",
          "--resolve", at, "--max-time", "15", "--max-filesize", "2000000", "-A", ws.fetchAgent, "-H", "Accept: text/html",
          "-w", "\n%{http_code}\t%{redirect_url}", "--", target.url], function(ok, out) {
          var text = String(out || "")
          var cut = text.lastIndexOf("\n")
          var parts = (cut >= 0 ? text.slice(cut + 1) : "").split("\t")
          var code = Number(parts[0])
          var next = String(parts[1] || "").trim()
          if (ok && code >= 300 && code < 400 && next) {
            if (hops >= 5) { done(null, "", "It sends you on too many times: the link's kept"); return }
            step(next, hops + 1)
            return
          }
          var html = cut >= 0 ? text.slice(0, cut) : ""
          if (!ok || code !== 200 || !html.trim()) { done(null, "", "The page couldn't be read: the link's kept"); return }
          done(html, target.url, "")
        }, { timeoutMs: 20000, maxBytes: 2100000 })
      }, { timeoutMs: 5000, maxBytes: 65536 })
    }
    step(url, 0)
  }

  // The page's picture (its og:image, named by the page, not by you): only
  // from the internet (Bookmark.imageTarget, isPublicIp): its host looked up
  // first, every address it has a public one, then fetched from that
  // address, past no proxy, never redirected, into a folder of its own;
  // then copied into assets under a new name, only if it's a picture
  // (Store.copyPictureIn). done("assets/<name>") or done("").
  function fetchBookmarkPicture(url, done) {
    var target = Bookmark.imageTarget(url)
    if (!target) { done(""); return }
    files.exec(["/usr/bin/getent", "ahosts", target.host], function(okR, out) {
      var ips = okR ? Bookmark.addresses(out) : []
      if (!ips.length || !ips.every(Bookmark.isPublicIp)) { done(""); return }
      var ip = ips.filter(function(a) { return a.indexOf(":") < 0 })[0] || ips[0]
      var at = target.host + ":" + target.port + ":" + (ip.indexOf(":") >= 0 ? "[" + ip + "]" : ip)
      var tmp = files.runtimeDir + "/uber-notebook-picture-" + Workspace.uuid4()
      files.exec(["/usr/bin/mkdir", "-m", "700", "--", tmp], function(madeTmp) {
        if (!madeTmp) { done(""); return }
        function finish(src) { files.exec(["/usr/bin/rm", "-rf", "--", tmp], null); done(src) }
        files.exec(["/usr/bin/curl", "-q", "-sS", "--noproxy", "*", "--proto", "=https", "--max-redirs", "0", "--max-time", "15", "--max-filesize", "5000000",
          "--resolve", at, "-A", ws.fetchAgent, "-o", tmp + "/picture", "-w", "%{content_type}", "--", target.url], function(ok2, type) {
          var name = ok2 ? Bookmark.imageName(String(type || ""), target.url, new Date()) : ""
          if (!name) { finish(""); return }
          var dir = Workspace.assetsDir(files.rootPath)
          files.mkdirs([dir], function() {
            files.copyPictureIn(tmp + "/picture", dir, name, function(ok3) { finish(ok3 ? "assets/" + name : "") })
          })
        }, { timeoutMs: 20000, maxBytes: 4096 })
      })
    }, { timeoutMs: 5000, maxBytes: 65536 })
  }

  // The template new pages inside a page start from ("" for none).
  function setChildTemplate(id, template) {
    var e = index.pages[id]
    if (!e) return
    e.childTemplate = Workspace.isUuid(template) ? template : ""
    touched()
  }

  // A template made of a page (a copy of it and the pages in it, its name
  // the page's): done(the template's id, or "").
  function saveAsTemplate(id, done) {
    var e = index.pages[id]
    if (!e) { done(""); return }
    var ids = Workspace.withDescendants(index, id).filter(function(pid) { return pid === id || !Workspace.inTrash(ws.index, pid) })
    readPages(ids, function(pages) {
      if (!pages.length) { done(""); return }
      var copies = Workspace.duplicate(pages, id, new Date())
      var top = copies[0]
      top.title = e.title || ""
      top.parent = ""
      // (A template isn't locked: the pages made from it would be.)
      if (top.format) delete top.format.locked
      copies.forEach(function(c) {
        ws.index.pages[c.id] = { title: c.title, icon: c.icon, parent: "", children: [], trashed: false, created: c.created, modified: c.modified, links: null, reminders: null }
      })
      copies.forEach(function(c) {
        var parent = c.id === top.id ? "" : c.parent
        Workspace.attach(ws.index, c.id, parent, -1)
        c.parent = parent
        ws.savePage(c)
      })
      ws.index.pages[top.id].template = true
      ws.touched()
      done(top.id)
    })
  }

  // A new, empty template.
  function newTemplate() {
    var p = createPage({ parent: "", title: "" })
    if (p) setTemplate(p.id, true)
    return p
  }

  // A template used: its pages read and copied for the page `into` (its
  // blocks, given to place(top), which puts them on it or makes it), then
  // the pages in it made inside that page. `fill(text, html)` fills it in.
  // done(top), or done(null) if it's gone.
  function useTemplate(template, into, fill, place, done) {
    if (!index.pages[template] || !Workspace.inTemplates(index, template)) { if (done) done(null); return }
    var ids = Workspace.withDescendants(index, template).filter(function(pid) { return pid === template || !Workspace.inTrash(ws.index, pid) })
    readPages(ids, function(pages) {
      if (!pages.length) { if (done) done(null); return }
      if (done) done(ws.placeTemplate(pages, template, into, fill, place))
    })
  }

  // A template's pages (read) copied for `into`: place(top), then the pages
  // in it made. Returns the top one's copy.
  function placeTemplate(pages, template, into, fill, place) {
    var made = Workspace.fromTemplate(pages, template, into, fill, new Date())
    if (made.top.format) delete made.top.format.locked
    // (Page blocks point to their pages by their own ids.)
    made.top.blocks.forEach(function(b) { if (b.type === "page") b.id = b.uid })
    place(made.top)
    made.pages.forEach(function(c) {
      ws.index.pages[c.id] = { title: c.title, icon: c.icon, parent: "", children: [], trashed: false, created: c.created, modified: c.modified, links: null, reminders: null }
      Workspace.attach(ws.index, c.id, c.parent, -1)
      ws.savePage(c)
    })
    ws.touched()
    return made.top
  }

  // A new page from a template at once (for commands): its id, or "".
  function pageFromTemplateNow(template, parent, title, fill) {
    if (!index.pages[template] || !Workspace.inTemplates(index, template)) return ""
    var ids = Workspace.withDescendants(index, template).filter(function(pid) { return pid === template || !Workspace.inTrash(ws.index, pid) })
    var pages = readPagesNow(ids)
    if (!pages || !pages.length) return ""
    pages.forEach(function(p, i) { p.id = ids[i] })
    var id = Workspace.uuid4()
    placeTemplate(pages, template, id, fill, function(top) {
      ws.createPage({ id: id, parent: parent, title: title || top.title, icon: top.icon, cover: top.cover, format: top.format, project: top.project,
        blocks: top.blocks.length ? top.blocks : undefined })
    })
    return index.pages[id] ? id : ""
  }

  // A new page from a template, inside `parent` ("" at the top), `title`
  // (or the template's, filled in): done(its id, or ""). `openId`: the page
  // open in the view, which puts the new page's block on itself.
  function pageFromTemplate(template, parent, title, fill, done, openId) {
    var id = Workspace.uuid4()
    useTemplate(template, id, fill, function(top) {
      ws.createPage({ id: id, parent: parent, title: title || top.title, icon: top.icon, cover: top.cover, format: top.format, project: top.project,
        blocks: top.blocks.length ? top.blocks : undefined })
      if (parent && parent !== openId) ws.editPage(parent, function(p) { return Workspace.appendPageBlock(p, id) })
    }, function(top) { done(top ? id : "") })
  }

  // In Favorites, or not.
  function toggleFavorite(id) {
    if (!index.pages[id]) return
    var list = (index.favorites || []).slice()
    var at = list.indexOf(id)
    if (at >= 0) list.splice(at, 1)
    else list.push(id)
    index.favorites = list
    touched()
  }

  function isFavorite(id) {
    return (index.favorites || []).indexOf(id) >= 0
  }

  // A copy of a page and the pages in it, right after it: done(copy's id).
  // `openId`: the page open in the view, which puts the copy's block on
  // itself when it's the one the page is in.
  function duplicatePage(id, openId, done) {
    var e = index.pages[id]
    if (!e) { done(""); return }
    var ids = Workspace.withDescendants(index, id)
    readPages(ids, function(pages) {
      if (!pages.length) { done(""); return }
      var copies = Workspace.duplicate(pages, id, new Date())
      var top = copies[0]
      copies.forEach(function(c) {
        ws.index.pages[c.id] = { title: c.title, icon: c.icon, parent: "", children: [], trashed: false, created: c.created, modified: c.modified, links: null, reminders: null }
      })
      copies.forEach(function(c) {
        var parent = c.id === top.id ? e.parent : c.parent
        var at = -1
        if (c.id === top.id) {
          var sibs = parent ? ws.index.pages[parent].children : ws.index.top
          at = sibs.indexOf(id) + 1
        }
        Workspace.attach(ws.index, c.id, parent, at)
        c.parent = parent
        ws.savePage(c)
      })
      if (e.parent && e.parent !== openId) ws.editPage(e.parent, function(p) { return Workspace.appendPageBlock(p, top.id) })
      ws.touched()
      done(top.id)
    })
  }

  // ---- finding --------------------------------------------------------------------------------

  // Pages with every word of the query in their title or text, best first:
  // done([{ id, title, icon, snippet }]).
  function search(query, done) {
    var words = Workspace.terms(query)
    if (words.length === 0 || !folder) { done([]); return }
    var longest = words.slice().sort(function(a, b) { return b.length - a.length })[0]
    files.exec(["/usr/bin/grep", "-rliF", "--include=*.json", "-e", longest, "--", folder], function(ok, output) {
      var ids = String(output || "").split("\n").map(function(p) { return p.slice(p.lastIndexOf("/") + 1).replace(/\.json$/, "") }).filter(function(id) { return Workspace.isUuid(id) && ws.index.pages[id] && !Workspace.inTrash(ws.index, id) && !Workspace.inTemplates(ws.index, id) })
      // And pages whose titles match, whether or not grep found them.
      Workspace.findTitles(ws.index, query, 40).forEach(function(id) { if (ids.indexOf(id) < 0) ids.push(id) })
      ws.readPages(ids.slice(0, 300), function(pages) {
        var results = []
        pages.forEach(function(p) {
          var score = Workspace.score(p.title || "Untitled", p.text, query)
          if (score > 0) results.push({ id: p.id, title: p.title, icon: p.icon, snippet: Workspace.snippet(p.text.slice((p.title || "").length), query), score: score, modified: p.modified })
        })
        results.sort(function(a, b) { return b.score - a.score || (a.modified < b.modified ? 1 : -1) })
        done(results.slice(0, 50))
      })
    }, { okCodes: [0, 1], maxBytes: 2 * 1024 * 1024, timeoutMs: 8000 })
  }

  // ---- pictures ---------------------------------------------------------------------------------

  function assetUrl(src) {
    if (!Blocks.cleanAsset(src) || !folder) return ""
    return "file://" + encodeURI(folder + "/" + src)
  }
  // Its file, a full path ("" for none).
  function assetPath(src) {
    if (!Blocks.cleanAsset(src) || !folder) return ""
    return folder + "/" + src
  }

  // A file in assets as it is on disk (not as a page says): done({ size,
  // regular }) or done(null).
  function assetInfo(src, done) {
    var path = assetPath(src)
    if (!path) { done(null); return }
    files.exec(["/usr/bin/stat", "-c", "%s\t%F", "--", path], function(ok, out) {
      var m = /^(\d+)\t(.+)$/.exec(String(out || "").trim())
      done(ok && m ? { size: Number(m[1]), regular: m[2] === "regular file" || m[2] === "regular empty file" } : null)
    }, { timeoutMs: 5000, maxBytes: 4096 })
  }

  // Copies a picture into Pages/assets (Store.copyPictureIn: only a picture,
  // within its size; with `within`, an agent's folder, only from it):
  // done("assets/<name>") or done("").
  function importPicture(path, done, within) {
    if (!files.isImagePath(path)) { done(""); return }
    var name = files.assetName(path)
    var dest = Workspace.assetsDir(files.rootPath)
    files.mkdirs([dest], function(ok) {
      if (!ok) { done(""); return }
      files.copyPictureIn(path, dest, name, function(copied, why) {
        if (!copied) ws.failed("Couldn't copy the picture: " + why)
        done(copied ? "assets/" + name : "")
      }, within)
    })
  }

  function pastePicture(done) {
    files.pasteInto(Workspace.assetsDir(files.rootPath), done)
  }

  // ---- out of Uber Notebook --------------------------------------------------------------------------

  // A page and the pages in it as Markdown files, with their pictures, in
  // "<notebooks>/Exports/<title> <date>/"; the folder opens.
  // The page and the pages in it as Markdown files, in a folder of their own
  // where Settings says exports go (asked, or the Exports folder).
  function exportPage(id) {
    if (typeof files.exportBase === "function") files.exportBase(function(base) { if (base) ws.exportPageTo(id, base) })
    else exportPageTo(id, files.rootPath + "/Exports")
  }

  function exportPageTo(id, base) {
    var all = Workspace.withDescendants(index, id).filter(function(pid) { return !Workspace.inTrash(ws.index, pid) || pid === id })
    readPages(all, function(pages) {
      if (!pages.length) return
      var names = {}
      var used = {}
      pages.forEach(function(p) {
        var base = (p.title || "Untitled").replace(/[\/\\:*?"<>|\u0000-\u001f]+/g, " ").trim().slice(0, 80) || "Untitled"
        var name = base
        for (var n = 2; used[name]; n++) name = base + " " + n
        used[name] = true
        names[p.id] = name
      })
      var top = pages.filter(function(p) { return p.id === id })[0] || pages[0]
      var dir = base + "/" + names[top.id] + " " + Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm")
      // Sketches as SVG files in sketches/, named by their blocks.
      var sketches = []
      pages.forEach(function(p) { Workspace.sketchesOf(p).forEach(function(k) { k.title = p.title; sketches.push(k) }) })
      files.mkdirs(sketches.length ? [dir, dir + "/sketches"] : [dir], function(ok) {
        if (!ok) return
        pages.forEach(function(p) {
          files.writeFile(dir + "/" + names[p.id] + ".md", Markdown.fromDocPage(p, function(pid) {
            var e = ws.index.pages[pid]
            return e ? { title: e.title || "Untitled", icon: e.icon, file: names[pid] ? encodeURI(names[pid] + ".md") : "" } : null
          }, { sketchFile: function(bid) { return "sketches/" + bid + ".svg" } }))
        })
        sketches.forEach(function(k) { files.writeFile(dir + "/sketches/" + k.id + ".svg", Sketch.toSvg(k.sketch, "A sketch on " + (k.title || "Untitled"))) })
        files.exec(["/usr/bin/cp", "-r", "--", Workspace.assetsDir(files.rootPath), dir + "/assets"], function() {
          files.exported(dir)
          files.openPath(dir)
        }, { okCodes: [0, 1], timeoutMs: 60000 })
      })
    })
  }

  // ---- importing ----------------------------------------------------------------------------

  // Other people's notes as pages: files (Markdown, HTML, text, Evernote's
  // .enex; Word, OpenDocument, RTF and more through pandoc or LibreOffice)
  // and folders of them, zipped or not (a Notion or Obsidian export). The
  // pages keep the folders' tree (Notion's "Page <id>.md" next to its
  // "Page <id>/" folder too), Notion's ids, the links between them, and
  // their pictures. done({ pages, first, skipped }).
  property bool importing: false
  property int importCount: 0
  // What went wrong while importing (a zip that wouldn't unzip, a picture
  // left out): given with the result as `problems`, said with it.
  property var importProblems: []
  function importProblem(message) {
    if (importing) importProblems.push(message)
    else ws.failed(message)
  }

  // Every file under the paths given ("R\t<root>" before each one's files),
  // each ended by a NUL (a name can't have one; it can have a newline).
  readonly property string scanScript: "for p in \"$@\"; do if [ -d \"$p\" ]; then printf 'R\\t%s\\0' \"$p\"; /usr/bin/find \"$p\" -maxdepth 12 -type f ! -path '*/.*' -print0; elif [ -f \"$p\" ]; then printf 'R\\t%s\\0%s\\0' \"$p\" \"$p\"; fi; done"

  function importPaths(paths, parent, done) {
    var list = (paths || []).filter(function(p) { return /^\/[^\u0000-\u001f]{1,4000}$/.test(String(p)) }).slice(0, 200)
    if (!ready || importing || list.length === 0) { if (done) done({ pages: 0, first: "", skipped: [] }); return }
    importing = true
    importCount = 0
    importProblems = []
    // (A folder of its own, made new: never one that's there, which is
    // taken away after. On disk: a zip may unpack to gigabytes. One a day
    // old, left by an import that never finished, taken away first.)
    var base = files.cacheDir || files.runtimeDir
    var tmp = base + "/import-" + Workspace.uuid4().slice(0, 8)
    files.exec(["/usr/bin/bash", "-c", "/usr/bin/mkdir -p -m 700 -- \"$1\" || exit 1; "
      + "/usr/bin/find \"$1\" -mindepth 1 -maxdepth 1 -type d -name 'import-*' -mmin +1440 -exec /usr/bin/rm -rf -- {} + 2>/dev/null; "
      + "/usr/bin/mkdir -m 700 -- \"$2\"", "uber-notebook-import-dir", base, tmp], function(ok) {
      if (!ok) { ws.importing = false; if (done) done({ pages: 0, first: "", skipped: list }); return }
      ws.unzipAll(list, tmp, function(roots) {
        ws.scanImport(roots, tmp, parent, function(result) {
          files.exec(["/usr/bin/rm", "-rf", "--", tmp], function() {})
          ws.importing = false
          ws.touched()
          result.problems = ws.importProblems
          if (done) done(result)
        })
      })
    })
  }

  // Zips (a Notion export) unpacked into tmp, and the zips in them (Notion
  // zips its export in parts), by the archive helper (bin/uber-notebook-files):
  // nothing in one can land outside its folder, be a link, or take more than
  // UNZIP_MAX_BYTES (UNZIP_MAX_FILES files). Their folders take their place
  // in the list.
  readonly property real unzipMaxBytes: 4 * 1024 * 1024 * 1024
  readonly property int unzipMaxFiles: 200000
  function unzipAll(list, tmp, done) {
    var out = []
    var k = 0
    function next() {
      if (k >= list.length) { done(out); return }
      var p = list[k++]
      if (Import.kindOf(p) !== "zip") { out.push(p); next(); return }
      var dir = tmp + "/zip-" + k + "/" + Import.titleFromName(p).replace(/[\/\u0000-\u001f]/g, " ").replace(/^\.+/, "").slice(0, 80)
      files.mkdirs([dir], function() {
        files.helper(["unzip", p, dir, String(ws.unzipMaxBytes), String(ws.unzipMaxFiles)], function(ok, output) {
          var r = null
          try { r = JSON.parse(String(output || "").trim().split("\n").pop()) } catch (e) { r = null }
          if (!ok || !r || !r.ok) { ws.importProblem("Couldn't unzip " + p + (r && r.error ? ": " + r.error : "")); next(); return }
          out.push(dir)
          next()
        }, { timeoutMs: 10 * 60 * 1000, maxBytes: 64 * 1024 })
      })
    }
    next()
  }

  function scanImport(roots, tmp, parent, done) {
    files.execText(["/usr/bin/bash", "-c", scanScript, "uber-notebook-scan"].concat(roots), function(ok, output) {
      var groups = []
      String(output || "").split("\u0000").forEach(function(item) {
        if (!item) return
        if (item.indexOf("R\t") === 0) { groups.push({ root: item.slice(2), files: [] }); return }
        var g = groups[groups.length - 1]
        // (Only a file in what was asked for, with a name that's only a name.)
        if (g && (item === g.root || item.indexOf(g.root + "/") === 0) && !/[\u0001-\u001f\u007f]/.test(item)) g.files.push(item)
      })
      try { ws.planImport(groups, tmp, parent, done) } catch (e) { ws.importFailed(e, [], done) }
    }, { okCodes: [0, 1], maxBytes: 8 * 1024 * 1024, timeoutMs: 30000 })
  }

  // What pages there'll be, in what tree, with what ids; then each is read.
  function planImport(groups, tmp, parent, done) {
    var plan = []
    var byPath = {}
    var images = {}
    var taken = {}
    function newId(want) {
      var id = Workspace.isUuid(want) && !ws.index.pages[want] && !taken[want] ? want : Workspace.uuid4()
      taken[id] = true
      return id
    }
    function add(entry) {
      entry.id = newId(entry.want || "")
      entry.children = []
      plan.push(entry)
      byPath[entry.path] = entry
      return entry
    }
    var skipped = []
    groups.forEach(function(g) {
      var single = g.files.length === 1 && g.files[0] === g.root
      var notes = g.files.filter(function(f) { return Import.kindOf(f) !== "" && Import.kindOf(f) !== "zip" })
      g.files.forEach(function(f) { if (/\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(f)) images[f] = true })
      g.files.forEach(function(f) { if (!Import.kindOf(f) && !images[f] && single) skipped.push(f) })
      if (notes.length === 0) return
      var rootDir = single ? g.root.split("/").slice(0, -1).join("/") : g.root
      // Folders become pages when no note of the same name stands for them.
      var dirs = {}
      notes.forEach(function(f) {
        var parts = f.slice(rootDir.length + 1).split("/")
        for (var d = 1; d < parts.length; d++) dirs[rootDir + "/" + parts.slice(0, d).join("/")] = true
      })
      var top = []
      function ownerOf(path) {
        // The page a file (or folder) goes in: the note next to its folder
        // ("Page.md" for "Page/"), else the folder's page.
        var dir = path.split("/").slice(0, -1).join("/")
        if (dir.length <= rootDir.length) return null
        return byPath[dir + "#note"] || byPath[dir] || null
      }
      // Folders first (shallowest first), then notes.
      Object.keys(dirs).sort(function(a, b) { return a.split("/").length - b.split("/").length || a.localeCompare(b) }).forEach(function(dir) {
        var noteForDir = notes.filter(function(f) { return f.replace(/\.[A-Za-z0-9]+$/, "") === dir })[0]
        if (noteForDir) return
        add({ path: dir, kind: "folder", title: Import.titleFromName(dir), want: Import.notionId(dir), root: rootDir })
      })
      notes.slice().sort().forEach(function(f) {
        var e = add({ path: f, kind: Import.kindOf(f), title: Import.titleFromName(f), want: Import.notionId(f), root: rootDir })
        byPath[f.replace(/\.[A-Za-z0-9]+$/, "") + "#note"] = e
      })
      // A folder of several pages imported whole gets a page of its own.
      var wrapper = null
      if (!single) {
        var topLevel = plan.filter(function(e) { return e.root === rootDir && !ownerOf(e.path) })
        if (topLevel.length > 1) wrapper = add({ path: rootDir, kind: "folder", title: Import.titleFromName(rootDir) || "Imported", want: "", root: rootDir })
      }
      plan.forEach(function(e) {
        if (e.root !== rootDir || e === wrapper || e.parentEntry !== undefined) return
        var owner = ownerOf(e.path)
        e.parentEntry = owner && owner !== e ? owner : wrapper
        if (e.parentEntry) e.parentEntry.children.push(e)
      })
    })
    ws.readImport(plan, images, tmp, parent, skipped, done)
  }

  function readImport(plan, images, tmp, parent, skipped, done) {
    var textual = plan.filter(function(e) { return e.kind === "markdown" || e.kind === "html" || e.kind === "text" || e.kind === "enex" })
    files.readFiles(textual.map(function(e) { return e.path }), function(got) {
      textual.forEach(function(e) { e.source = got[e.path] || "" })
      ws.convertOffice(plan.filter(function(e) { return e.kind === "office" }), tmp, skipped, function() {
        ws.buildImport(plan, images, parent, skipped, done)
      })
    }, 64 * 1024 * 1024)
  }

  // Word, OpenDocument, RTF, EPUB...: Markdown through pandoc, or HTML
  // through LibreOffice, whichever there is (pandoc first).
  function convertOffice(list, tmp, skipped, done) {
    if (list.length === 0) { done(); return }
    // (Which there are, and whether LibreOffice can be given a network of
    // its own with nothing in it: unshare, as for exports.)
    files.exec(["/usr/bin/bash", "-c", "for t in /usr/bin/pandoc /usr/bin/soffice; do [ -x \"$t\" ] && echo \"$t\"; done; /usr/bin/unshare --user --map-current-user --net -- /usr/bin/true 2>/dev/null && echo unshare; true", "uber-notebook-which"], function(ok, out) {
      var have = String(out || "")
      var pandoc = have.indexOf("/usr/bin/pandoc") >= 0
      var office = have.indexOf("/usr/bin/soffice") >= 0
      var walled = /^unshare$/m.test(have) ? ["/usr/bin/unshare", "--user", "--map-current-user", "--net", "--"] : []
      var k = 0
      function next() {
        if (k >= list.length) { done(); return }
        var e = list[k++]
        var dir = tmp + "/convert-" + k
        var ext = (/\.([A-Za-z0-9]+)$/.exec(e.path) || ["", ""])[1].toLowerCase()
        var pandocReads = { docx: "docx", odt: "odt", rtf: "rtf", epub: "epub", org: "org", rst: "rst", tex: "latex", latex: "latex", textile: "textile", wiki: "mediawiki", mediawiki: "mediawiki", ipynb: "ipynb" }
        files.mkdirs([dir], function() {
          if (pandoc && pandocReads[ext]) {
            // (--sandbox: pandoc reads only the file it's given: nothing it
            // names, on this computer or the web.)
            files.exec(["/usr/bin/pandoc", "--sandbox", "--from=" + pandocReads[ext], "--to=gfm", "--wrap=none", "--extract-media=" + dir, "--output=" + dir + "/out.md", "--", e.path], function(ok2) {
              if (!ok2) { skipped.push(e.path); e.kind = "skip"; next(); return }
              files.readFiles([dir + "/out.md"], function(g) { e.kind = "markdown"; e.source = g[dir + "/out.md"] || ""; e.base = dir + "/out.md"; e.root = tmp; next() })
            }, { timeoutMs: 120000, maxBytes: 1024 * 1024 })
          } else if (office && ["docx", "doc", "odt", "rtf", "fodt", "wpd", "pages"].indexOf(ext) >= 0) {
            // (No network: a document can name pictures on the web, which
            // LibreOffice would fetch as it reads it.)
            files.exec(walled.concat(["/usr/bin/soffice", "--headless", "-env:UserInstallation=file://" + tmp + "/lo-profile", "--convert-to", "html", "--outdir", dir, e.path]), function(ok3) {
              var html = dir + "/" + e.path.split("/").pop().replace(/\.[A-Za-z0-9]+$/, "") + ".html"
              files.readFiles([html], function(g) {
                if (!ok3 || !g[html]) { skipped.push(e.path); e.kind = "skip"; next(); return }
                e.kind = "html"; e.source = g[html]; e.base = html; e.root = tmp
                next()
              })
            }, { timeoutMs: 180000, maxBytes: 1024 * 1024 })
          } else {
            skipped.push(e.path)
            e.kind = "skip"
            next()
          }
        })
      }
      next()
    }, { okCodes: [0, 1], timeoutMs: 5000 })
  }

  // Something in what's imported that couldn't be read: said, and the import
  // over (what was made stays), never stuck.
  function importFailed(e, skipped, done) {
    ws.importProblem("Couldn't import all of it: " + String(e && e.message ? e.message : e).slice(0, 200))
    done({ pages: ws.importCount, first: "", skipped: skipped || [] })
  }

  // Each file read into blocks, its links and pictures pointed where they
  // go now; then the pages are made, parents first, and the pictures copied.
  function buildImport(plan, images, parent, skipped, done) {
    try { buildImportNow(plan, images, parent, skipped, done) } catch (e) { importFailed(e, skipped, done) }
  }
  function buildImportNow(plan, images, parent, skipped, done) {
    var byTitle = {}
    var byFile = {}
    plan.forEach(function(e) {
      if (e.kind === "skip") return
      byTitle[(e.title || "").toLowerCase()] = e.id
      if (e.kind !== "folder") byFile[e.path] = e
    })
    var copies = []
    var usedNames = {}
    var made = []
    plan.forEach(function(e) {
      if (e.kind === "skip") return
      var from = e.base || e.path
      var root = e.root
      var ctx = {
        link: function(href) {
          if (/^(https?:|mailto:)/i.test(href)) return href
          var abs = Import.resolvePath(from, href, root)
          var target = byFile[abs] || byFile[abs + ".md"] || byFile[abs.replace(/\.html?$/i, ".md")]
          return target ? "uber-notebook://page/" + target.id : ""
        },
        image: function(src) {
          var abs = Import.resolvePath(from, src, root)
          if (!abs || !(images[abs] || e.base)) return ""
          var name = files.assetName(abs)
          while (usedNames[name]) name = name.replace(/(\.[a-z0-9]+)$/, "-" + Math.floor(Math.random() * 1000) + "$1")
          usedNames[name] = true
          copies.push({ from: abs, to: Workspace.assetsDir(files.rootPath) + "/" + name })
          return "assets/" + name
        },
        wiki: function(name) { return byTitle[String(name || "").toLowerCase()] || "" }
      }
      var r = { title: "", icon: "", blocks: [] }
      if (e.kind === "markdown") r = Import.fromMarkdown(e.source, ctx, { titleFromHeading: true })
      else if (e.kind === "html") r = Import.fromHtml(e.source, ctx, { titleFromHeading: true })
      else if (e.kind === "text") r = Import.fromText(e.source)
      else if (e.kind === "enex") {
        // Each note in it, a page inside the page for the file.
        Import.enexNotes(e.source).forEach(function(note) {
          var nr = Import.fromHtml(note.html, ctx)
          var child = { id: Workspace.uuid4(), title: note.title, icon: "", blocks: nr.blocks, parentEntry: e, children: [], kind: "note" }
          made.push(child)
          e.children.push(child)
        })
      }
      e.title = r.title || e.title
      e.icon = r.icon || ""
      e.blocks = r.blocks
    })
    // A page's pages: where its text links to one alone on a line, a page
    // block (as Notion's export writes them); the rest at its end.
    plan.concat(made).forEach(function(e) {
      if (e.kind === "skip") return
      var kids = e.children.filter(function(c) { return c.kind !== "skip" }).map(function(c) { return c.id })
      var placed = {}
      e.blocks = (e.blocks || []).map(function(b) {
        if (b.type !== "p" || !b.html) return b
        var only = /^<a href="(?:uber-notebook|omanote):\/\/page\/([0-9a-f-]{36})">[^<]*(?:<[^a][^>]*>[^<]*<\/[^a][^>]*>[^<]*)*<\/a>$/.exec(b.html.trim())
        if (only && kids.indexOf(only[1]) >= 0 && !placed[only[1]]) { placed[only[1]] = true; return { type: "page", uid: only[1], indent: b.indent } }
        return b
      })
      kids.forEach(function(id) { if (!placed[id]) e.blocks.push({ type: "page", uid: id, indent: 0 }) })
    })
    // The pages, parents first.
    var first = ""
    var count = 0
    var order = plan.concat(made).filter(function(e) { return e.kind !== "skip" })
    var done2 = {}
    function make(e) {
      if (done2[e.id]) return
      if (e.parentEntry && e.parentEntry.kind !== "skip") make(e.parentEntry)
      done2[e.id] = true
      var parentId = e.parentEntry && e.parentEntry.kind !== "skip" ? e.parentEntry.id : (parent || "")
      var list = (e.blocks || []).map(function(b) {
        var c = {}
        for (var k in b) c[k] = b[k]
        if (!Workspace.isUuid(c.uid)) c.uid = Workspace.uuid4()
        return c
      })
      var page = Workspace.newPage({ id: e.id, parent: parentId, title: e.title, icon: e.icon, blocks: list })
      if (!page) return
      ws.index.pages[page.id] = { title: page.title, icon: page.icon, parent: "", children: [], trashed: false, created: page.created, modified: page.modified, links: null, reminders: null }
      Workspace.attach(ws.index, page.id, parentId, -1)
      ws.savePage(page)
      count++
      ws.importCount = count
      if (!first && !e.parentEntry) first = page.id
    }
    order.forEach(make)
    // The pages that aren't in a page imported go where they were asked
    // for: in `parent` (its file gets their blocks) or at the top.
    if (parent) {
      var tops = order.filter(function(e) { return !e.parentEntry || e.parentEntry.kind === "skip" }).map(function(e) { return e.id })
      if (tops.length) ws.editPage(parent, function(p) { tops.forEach(function(id) { Workspace.appendPageBlock(p, id) }); return true })
    }
    // Pictures, copied in one after another.
    var i = 0
    function copyNext() {
      if (i >= copies.length) { done({ pages: count, first: first, skipped: skipped }); return }
      var c = copies[i++]
      files.copyPictureIn(c.from, c.to.slice(0, c.to.lastIndexOf("/")), c.to.slice(c.to.lastIndexOf("/") + 1), function(copied, why) {
        if (!copied) ws.importProblem("A picture wasn't copied: " + (why || c.from))
        copyNext()
      })
    }
    files.mkdirs([Workspace.assetsDir(files.rootPath)], function() { copyNext() })
  }

  // ---- a notebook into Pages -------------------------------------------------------------------------

  // One of your notebooks as pages: a page called what it is, at the end of
  // the sidebar, with a page inside it for each of its pages, in order (their
  // text, pictures and drawings, and when they were written: Import.js).
  // `nb` as Store.openNotebook gives it (every page), `dir` its folder. Its
  // pictures are copied in first (never over a picture that's there); one
  // that can't be is left out, and counted. Then the pages are written, and
  // the tree. done({ id, pages, missing, failed }) once every write has
  // answered (`failed`: how many didn't go); done({ tooLong: "<title>" })
  // when a page has more blocks than a page can hold, before anything's
  // made; done(null) when nothing was made.
  function importNotebook(nb, dir, done) {
    if (!ready || importing || !nb || !Array.isArray(nb.pages) || nb.pages.length === 0 || !dir) { done(null); return }
    // (Every page fits, its pictures and drawing too, or none is made.)
    for (var p = 0; p < nb.pages.length; p++) {
      var all = Import.fromNotebookPage(nb.pages[p], { image: function(src) { return src } })
      if (all.blocks.length > Workspace.MAX_BLOCKS) { done({ tooLong: all.title || "Untitled" }); return }
    }
    importing = true
    var dest = Workspace.assetsDir(files.rootPath)
    // Every picture on its pages, once, each with a new name of its own.
    var names = {}
    var taken = {}
    var copies = []
    nb.pages.forEach(function(p) {
      (p.blocks || []).forEach(function(b) {
        if (b.type !== "image" || !Blocks.cleanAsset(b.src) || names[b.src] !== undefined) return
        var name = files.assetName(b.src)
        while (taken[name]) name = name.replace(/(\.[a-z0-9]+)$/, "-" + Math.floor(Math.random() * 1000) + "$1")
        taken[name] = true
        names[b.src] = ""
        copies.push({ src: b.src, from: dir + "/" + b.src, name: name })
      })
    })
    var missing = 0
    var i = 0
    function copyNext() {
      if (i >= copies.length) { make(); return }
      var c = copies[i++]
      files.copyPictureIn(c.from, dest, c.name, function(ok) {
        if (ok) names[c.src] = "assets/" + c.name
        else missing++
        copyNext()
      })
    }
    function make() {
      var ctx = { image: function(src) { return names[src] || "" } }
      var kids = nb.pages.map(function(p) {
        var r = Import.fromNotebookPage(p, ctx)
        return { id: Workspace.uuid4(), title: r.title, blocks: r.blocks, created: p.created, modified: p.modified }
      })
      var top = Workspace.newPage({ title: nb.title, icon: "\u{1f4d3}", blocks: kids.map(function(k) { return { type: "page", uid: k.id, indent: 0 } }) })
      if (!top) { ws.importing = false; done(null); return }
      // Every write answers; then the tree's written, and it's done.
      var waiting = kids.length + 1
      var failed = 0
      function written(ok) {
        if (!ok) failed++
        if (--waiting > 0) return
        ws.flushIndex(function(indexOk) {
          ws.importing = false
          done({ id: top.id, pages: kids.length, missing: missing, failed: failed + (indexOk ? 0 : 1) })
        })
      }
      index.pages[top.id] = { title: top.title, icon: top.icon, parent: "", children: [], trashed: false, created: top.created, modified: top.modified }
      Workspace.attach(index, top.id, "", -1)
      savePage(top, written)
      kids.forEach(function(k) {
        var when = Date.parse(k.created)
        var page = Workspace.newPage({ id: k.id, parent: top.id, title: k.title, blocks: k.blocks }, isFinite(when) ? new Date(when) : new Date())
        if (!page) { written(false); return }
        if (isFinite(Date.parse(k.modified))) page.modified = new Date(Date.parse(k.modified)).toISOString()
        index.pages[page.id] = { title: page.title, icon: page.icon, parent: "", children: [], trashed: false, created: page.created, modified: page.modified }
        Workspace.attach(index, page.id, top.id, -1)
        ws.savePage(page, written)
      })
      touched()
    }
    files.mkdirs([dest], function(ok) {
      if (!ok) { ws.importing = false; done(null); return }
      copyNext()
    })
  }

  // ---- the first pages -----------------------------------------------------------------------------

  function createWelcome() {
    var bold = function(t) { return "<span style=\"font-weight:700;\">" + Html.escapeText(t) + "</span>" }
    var code = function(t) { return "<span style=\"font-family:'iA Writer Mono S';\">" + Html.escapeText(t) + "</span>" }
    var welcome = Workspace.uuid4()
    var inner = createPage({ parent: "", title: "A page inside a page", icon: "\u{1f4c4}", blocks: [
      { type: "p", html: "Pages can hold pages, as deep as you like. They're in the sidebar under the page they're on.", indent: 0 },
      { type: "p", html: "", indent: 0 }
    ] })
    var blocks = [
      { type: "p", html: "Everything on a page is a " + bold("block") + ": a line of text, a heading, a to-do, a picture, a page. Blocks can hold other blocks, and move with everything inside them.", indent: 0 },
      { type: "callout", icon: "\u{1f4a1}", color: "blue_background", html: "Type " + bold("/") + " anywhere for every kind of block: headings, to-dos, toggles, callouts, code, pages inside pages, colors\u2026", indent: 0 },
      { type: "h2", html: "Try these", indent: 0 },
      { type: "check", html: "Hover over a block and drag " + bold("\u22ee\u22ee") + " to move it; drag it right to put it inside the block above", indent: 0 },
      { type: "check", html: "Click " + bold("\u22ee\u22ee") + " for a block's menu: turn it into another kind, color it, duplicate it", indent: 0 },
      { type: "check", html: "Select a few words to make them bold, italic, a link or a color", indent: 0 },
      { type: "check", html: "Type " + code("**bold**") + ", " + code("*italic*") + ", " + code("`code`") + " or " + code("~~struck~~") + " as you write", indent: 0 },
      { type: "check", html: "Type " + bold("@") + " for a date or a reminder, " + bold("[[") + " for a link to a page, " + bold(":") + " for an emoji (" + code(":rocket") + ")", indent: 0 },
      { type: "toggle", html: "Click the arrow to open this toggle", indent: 0 },
      { type: "p", html: "Toggles fold what's inside them away. " + bold("Tab") + " puts a block inside the one above it; " + bold("Shift+Tab") + " takes it out again.", indent: 1 },
      { type: "h2", html: "Pages inside pages", indent: 0 }
    ]
    if (inner) blocks.push({ type: "page", uid: inner.id, indent: 0 })
    blocks.push({ type: "quote", html: "Your pages are plain files in " + Html.escapeText(files.home ? folder.replace(files.home, "~") : folder) + ", one for each page.", indent: 0 })
    blocks.push({ type: "p", html: "", indent: 0 })
    var page = Workspace.newPage({ id: welcome, parent: "", title: "Getting started", icon: "\u{1f44b}", blocks: blocks })
    index.pages[page.id] = { title: page.title, icon: page.icon, parent: "", children: [], trashed: false, created: page.created, modified: page.modified }
    Workspace.attach(index, page.id, "", 0)
    savePage(page)
    if (inner) {
      Workspace.attach(index, inner.id, page.id, 0)
      inner.parent = page.id
      savePage(inner)
    }
    touched()
  }

  // The examples (Starter.js), made for today: their files copied into
  // Pages/assets, their pages (and templates) in the tree, the first two in
  // Favorites; their people and events once People and the calendar are read.
  function createExamples(templatesOnly) {
    var home = files.home || ""
    var root = files.rootPath
    var made = Starter.build(new Date(), { folder: home && root.indexOf(home + "/") === 0 ? "~" + root.slice(home.length) : root, templatesOnly: templatesOnly === true })
    var dir = Workspace.assetsDir(files.rootPath)
    files.mkdirs([dir], function(ok) {
      if (!ok) return
      // (The page open, and the Library, show the pictures once they're here.)
      var left = made.assets.length
      if (!left) return
      function copied() {
        if (--left > 0) return
        made.pages.forEach(function(m) { ws.pageChanged(m.page.id) })
        ws.revision++
      }
      made.assets.forEach(function(a) {
        if (a.text !== undefined) files.writeFile(dir + "/" + a.name, a.text, copied)
        else files.exec(["/usr/bin/cp", "--", ws.starterFile(a.file), dir + "/" + a.name], copied)
      })
    })
    made.pages.forEach(function(m) {
      var p = m.page
      index.pages[p.id] = { title: p.title, icon: p.icon, parent: "", children: [], trashed: false, created: p.created, modified: p.modified, links: null, reminders: null }
    })
    made.pages.forEach(function(m) {
      Workspace.attach(index, m.page.id, m.page.parent, -1)
      if (m.template) index.pages[m.page.id].template = true
      if (m.description) index.pages[m.page.id].description = Workspace.cleanDescription(m.description)
    })
    made.pages.forEach(function(m) { savePage(m.page) })
    index.favorites = (index.favorites || []).concat(made.favorites)
    touched()
    startingPeople = { contacts: made.contacts, events: made.events }
    addStartingPeople()
  }
  function starterFile(name) {
    return decodeURIComponent(Qt.resolvedUrl("starter/assets/" + name).toString().replace(/^file:\/\//, ""))
  }
  function addStartingPeople() {
    if (!startingPeople || !calendarLoaded || !contactsLoaded) return
    var s = startingPeople
    startingPeople = null
    var now = new Date()
    var book = contacts
    s.contacts.forEach(function(c) { book = Contacts.withContact(book, c, now) })
    setContacts(book)
    var cal = calendar
    s.events.forEach(function(e) { cal = Calendar.withEvent(cal, e) })
    setCalendar(cal)
    // (Not a step Undo takes back: they're where you start.)
    contactsUndo = []
    calendarUndo = []
  }

  // Everything still waiting is written (the shell stopping).
  function flush() {
    if (indexTimer.running) flushIndex()
  }

  Component.onDestruction: flush()
}
