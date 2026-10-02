import QtQuick
import "Workspace.js" as Workspace
import "Import.js" as Import
import "Blocks.js" as Blocks
import "Html.js" as Html
import "Markdown.js" as Markdown

// Pages on disk: the workspace in the Pages folder of your notebooks folder
// (~/Documents/Omanote/Pages), a JSON file per page, named by its UUID, and
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

  onFolderChanged: if (folder) loadTimer.restart()
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

  // The Pages folder is made when something is first written to it, so
  // there's none until you use Pages.
  property bool folderMade: false

  function withFolder(fn) {
    if (folderMade) { fn(); return }
    files.mkdirs([folder, Workspace.assetsDir(files.rootPath)], function(ok) {
      if (!ok) return
      ws.folderMade = true
      fn()
    })
  }

  function load() {
    if (!folder) return
    ready = false
    var gen = ++generation
    folderMade = false
    texts = ({})
    files.readFiles([ws.indexPath()], function(got) {
      if (gen !== ws.generation) return
      var ix = Workspace.cleanIndex(files.parseJson(got[ws.indexPath()] || ""))
      files.exec(["/usr/bin/bash", "-c", ws.listScript, "omanote-list", ws.folder], function(listed, output) {
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
        })
      }, { okCodes: [0, 1] })
    })
  }

  // The first time Pages is opened, with no pages: a page to start from.
  function ensureStarted() {
    if (!ready || welcomed || Object.keys(index.pages).length > 0) return false
    welcomed = true
    createWelcome()
    return true
  }

  // index.json, a moment after the last change to the tree.
  function saveIndex() { indexTimer.restart() }

  Timer {
    id: indexTimer
    interval: 300
    onTriggered: ws.flushIndex()
  }

  function flushIndex() {
    indexTimer.stop()
    if (!ready && Object.keys(index.pages).length === 0) return
    var text = Workspace.indexJson(index)
    withFolder(function() { files.writeFile(ws.indexPath(), text) })
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

  function readPages(ids, done) {
    var fresh = []
    var paths = []
    ids.forEach(function(id) {
      if (written[id]) fresh.push(JSON.parse(JSON.stringify(written[id])))
      else paths.push(pagePath(id))
    })
    if (paths.length === 0) { done(fresh); return }
    files.readFiles(paths, function(got) {
      var out = fresh.slice()
      for (var path in got) {
        var id = path.slice(path.lastIndexOf("/") + 1, -5)
        var page = Workspace.cleanPage(files.parseJson(got[path]), id)
        if (page) out.push(page)
      }
      done(out)
    }, 32 * 1024 * 1024)
  }

  // One page: done(page) or done(null).
  function readPage(id, done) {
    if (!Workspace.isUuid(id)) { done(null); return }
    readPages([id], function(pages) { done(pages.length ? pages[0] : null) })
  }

  // One page, read now, for a command that answers at once: as it was last
  // written this session, else from its file. null when there's none.
  function readPageNow(id) {
    if (!Workspace.isUuid(id)) return null
    if (written[id]) return JSON.parse(JSON.stringify(written[id]))
    var text = files.readNow(pagePath(id), 32 * 1024 * 1024)
    return text === null ? null : Workspace.cleanPage(files.parseJson(text), id)
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
  // pages on it (in the order their blocks are).
  function savePage(page) {
    if (!page || !Workspace.isUuid(page.id)) return
    // The page as it was, kept in its history first (every ten minutes of writing).
    keepVersion(page.id, "edit", false)
    page.text = Workspace.pageText(page)
    written[page.id] = JSON.parse(JSON.stringify(page))
    texts[page.id] = page.text
    var path = pagePath(page.id)
    var text = Workspace.pageJson(page)
    withFolder(function() { files.writeFile(path, text) })
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
    if (changed) touched()
    else saveIndex()
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
    keptAt[id] = now
    var page = readPageNow(id)
    if (!page) return false
    delete page.text
    var json = Workspace.pageJson(page)
    if (keptJson[id] === json) return false
    keptJson[id] = json
    var dir = Workspace.historyDir(files.rootPath, id)
    var text = JSON.stringify({ kept: new Date(now).toISOString(), why: why || "edit", page: JSON.parse(json) })
    files.mkdirs([dir], function(ok) {
      if (!ok) return
      files.writeFile(dir + "/" + Workspace.versionName(new Date(now)), text, function(written) {
        if (!written) return
        ws.versionKept(id)
        ws.pruneVersions(id)
      })
    })
    return true
  }

  // A page's versions, newest first: done([{ name, date }]).
  function listVersions(id, done) {
    if (!Workspace.isUuid(id)) { done([]); return }
    files.exec(["/usr/bin/bash", "-c", listScript, "omanote-list", Workspace.historyDir(files.rootPath, id)], function(ok, output) {
      done(ok ? Workspace.versionList(String(output || "").split("\n")) : [])
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
    var ids = Object.keys(index.pages).filter(function(id) { return index.pages[id].links === null || index.pages[id].reminders === null })
    if (ids.length === 0) return
    readPages(ids.slice(0, 2000), function(pages) {
      pages.forEach(function(p) {
        var e = ws.index.pages[p.id]
        if (!e) return
        e.links = Workspace.linkedPages(p)
        e.reminders = Workspace.pageReminders(p)
      })
      ws.touched()
      ws.scheduleReminders()
    })
  }

  // ---- reminders ---------------------------------------------------------------------------

  // A reminder comes as an Omarchy notification with what the block says;
  // clicking it opens the page. One that came while Omanote wasn't running
  // comes when it starts, if it was in the last 12 hours.
  readonly property int lateness: 12 * 3600000

  function scheduleReminders() {
    if (!ready) return
    var pending = Workspace.pendingReminders(index)
    if (pending.length === 0) { reminderTimer.stop(); return }
    var wait = pending[0].at.getTime() - Date.now()
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
    Workspace.pendingReminders(index).forEach(function(r) {
      if (r.at.getTime() > now + 1000) return
      if (now - r.at.getTime() <= ws.lateness) {
        var e = ws.index.pages[r.page]
        ws.files.notify(e && e.title ? e.title : "Reminder", r.text || "Reminder", r.page)
      }
      ws.index.fired[r.key] = true
      any = true
    })
    if (any) saveIndex()
    scheduleReminders()
  }

  // A new page (written straight away): { parent, at, title, icon, cover,
  // format, blocks }. Returns it.
  function createPage(options) {
    var o = options || {}
    var page = Workspace.newPage({ parent: o.parent, title: o.title, icon: o.icon, cover: o.cover, format: o.format, blocks: o.blocks || [{ type: "p", html: "", indent: 0 }] })
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
  // the notebooks folder's .trash, as nothing in Omanote is ever deleted.
  function deleteForever(id) {
    if (!index.pages[id]) return
    var all = Workspace.withDescendants(index, id)
    Workspace.detach(index, id)
    all.forEach(function(pid) {
      delete index.pages[pid]
      delete written[pid]
      delete texts[pid]
      files.trash(ws.pagePath(pid), "page-" + pid + ".json")
      // Its history goes with it (if it has one).
      ws.listVersions(pid, function(list) { if (list.length) files.trash(Workspace.historyDir(files.rootPath, pid), "history-" + pid) })
    })
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
      var ids = String(output || "").split("\n").map(function(p) { return p.slice(p.lastIndexOf("/") + 1).replace(/\.json$/, "") }).filter(function(id) { return Workspace.isUuid(id) && ws.index.pages[id] && !Workspace.inTrash(ws.index, id) })
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

  // Copies a picture into Pages/assets: done("assets/<name>") or done("").
  function importPicture(path, done) {
    if (!files.isImagePath(path)) { done(""); return }
    var name = files.assetName(path)
    var dest = Workspace.assetsDir(files.rootPath)
    files.mkdirs([dest], function(ok) {
      if (!ok) { done(""); return }
      files.exec(["/usr/bin/cp", "--", path, dest + "/" + name], function(copied, output) {
        if (!copied) ws.failed("Couldn't copy the picture: " + output)
        done(copied ? "assets/" + name : "")
      }, { timeoutMs: 20000 })
    })
  }

  function pastePicture(done) {
    files.pasteInto(Workspace.assetsDir(files.rootPath), done)
  }

  // ---- out of Omanote --------------------------------------------------------------------------

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
      files.mkdirs([dir], function(ok) {
        if (!ok) return
        pages.forEach(function(p) {
          files.writeFile(dir + "/" + names[p.id] + ".md", Markdown.fromDocPage(p, function(pid) {
            var e = ws.index.pages[pid]
            return e ? { title: e.title || "Untitled", icon: e.icon, file: names[pid] ? encodeURI(names[pid] + ".md") : "" } : null
          }))
        })
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

  // Every file under the paths given ("R\t<root>" before each one's files).
  readonly property string scanScript: "for p in \"$@\"; do if [ -d \"$p\" ]; then printf 'R\\t%s\\n' \"$p\"; /usr/bin/find \"$p\" -maxdepth 12 -type f ! -path '*/.*' -print; elif [ -f \"$p\" ]; then printf 'R\\t%s\\n' \"$p\"; printf '%s\\n' \"$p\"; fi; done"

  function importPaths(paths, parent, done) {
    var list = (paths || []).filter(function(p) { return /^\/[^\u0000-\u001f]{1,4000}$/.test(String(p)) }).slice(0, 200)
    if (!ready || importing || list.length === 0) { if (done) done({ pages: 0, first: "", skipped: [] }); return }
    importing = true
    importCount = 0
    var tmp = files.runtimeDir + "/omanote-import-" + Workspace.uuid4().slice(0, 8)
    files.mkdirs([tmp], function(ok) {
      if (!ok) { ws.importing = false; if (done) done({ pages: 0, first: "", skipped: list }); return }
      ws.unzipAll(list, tmp, function(roots) {
        ws.scanImport(roots, tmp, parent, function(result) {
          files.exec(["/usr/bin/rm", "-rf", "--", tmp], function() {})
          ws.importing = false
          ws.touched()
          if (done) done(result)
        })
      })
    })
  }

  // Zips (a Notion export) unpacked into tmp, and zips in them; their
  // folders take their place in the list.
  function unzipAll(list, tmp, done) {
    var out = []
    var k = 0
    function next() {
      if (k >= list.length) { done(out); return }
      var p = list[k++]
      if (Import.kindOf(p) !== "zip") { out.push(p); next(); return }
      var dir = tmp + "/zip-" + k + "/" + Import.titleFromName(p).replace(/[\/\u0000-\u001f]/g, " ").slice(0, 80)
      files.mkdirs([dir], function() {
        files.exec(["/usr/bin/unzip", "-qq", "-o", p, "-d", dir], function(ok) {
          if (!ok) { ws.failed("Couldn't unzip " + p); next(); return }
          // Notion zips its export in parts: those too.
          files.exec(["/usr/bin/bash", "-c", "shopt -s nullglob; for z in \"$1\"/*.zip; do /usr/bin/unzip -qq -o \"$z\" -d \"$1\" && /usr/bin/rm -f -- \"$z\"; done", "omanote-unzip", dir], function() {
            out.push(dir)
            next()
          }, { okCodes: [0, 1], timeoutMs: 120000 })
        }, { okCodes: [0, 1], timeoutMs: 120000, maxBytes: 1024 * 1024 })
      })
    }
    next()
  }

  function scanImport(roots, tmp, parent, done) {
    files.exec(["/usr/bin/bash", "-c", scanScript, "omanote-scan"].concat(roots), function(ok, output) {
      var groups = []
      String(output || "").split("\n").forEach(function(line) {
        if (!line) return
        if (line.indexOf("R\t") === 0) groups.push({ root: line.slice(2), files: [] })
        else if (groups.length) groups[groups.length - 1].files.push(line)
      })
      ws.planImport(groups, tmp, parent, done)
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
    files.exec(["/usr/bin/bash", "-c", "for t in /usr/bin/pandoc /usr/bin/soffice; do [ -x \"$t\" ] && echo \"$t\"; done; true", "omanote-which"], function(ok, out) {
      var have = String(out || "")
      var pandoc = have.indexOf("/usr/bin/pandoc") >= 0
      var office = have.indexOf("/usr/bin/soffice") >= 0
      var k = 0
      function next() {
        if (k >= list.length) { done(); return }
        var e = list[k++]
        var dir = tmp + "/convert-" + k
        var ext = (/\.([A-Za-z0-9]+)$/.exec(e.path) || ["", ""])[1].toLowerCase()
        var pandocReads = { docx: "docx", odt: "odt", rtf: "rtf", epub: "epub", org: "org", rst: "rst", tex: "latex", latex: "latex", textile: "textile", wiki: "mediawiki", mediawiki: "mediawiki", ipynb: "ipynb" }
        files.mkdirs([dir], function() {
          if (pandoc && pandocReads[ext]) {
            files.exec(["/usr/bin/pandoc", "--from=" + pandocReads[ext], "--to=gfm", "--wrap=none", "--extract-media=" + dir, "--output=" + dir + "/out.md", "--", e.path], function(ok2) {
              if (!ok2) { skipped.push(e.path); e.kind = "skip"; next(); return }
              files.readFiles([dir + "/out.md"], function(g) { e.kind = "markdown"; e.source = g[dir + "/out.md"] || ""; e.base = dir + "/out.md"; e.root = tmp; next() })
            }, { timeoutMs: 120000, maxBytes: 1024 * 1024 })
          } else if (office && ["docx", "doc", "odt", "rtf", "fodt", "wpd", "pages"].indexOf(ext) >= 0) {
            files.exec(["/usr/bin/soffice", "--headless", "-env:UserInstallation=file://" + tmp + "/lo-profile", "--convert-to", "html", "--outdir", dir, e.path], function(ok3) {
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

  // Each file read into blocks, its links and pictures pointed where they
  // go now; then the pages are made, parents first, and the pictures copied.
  function buildImport(plan, images, parent, skipped, done) {
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
          return target ? "omanote://page/" + target.id : ""
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
        var only = /^<a href="omanote:\/\/page\/([0-9a-f-]{36})">[^<]*(?:<[^a][^>]*>[^<]*<\/[^a][^>]*>[^<]*)*<\/a>$/.exec(b.html.trim())
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
      files.exec(["/usr/bin/cp", "--", c.from, c.to], function() { copyNext() }, { okCodes: [0, 1], timeoutMs: 20000 })
    }
    files.mkdirs([Workspace.assetsDir(files.rootPath)], function() { copyNext() })
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

  // Everything still waiting is written (the shell stopping).
  function flush() {
    if (indexTimer.running) flushIndex()
  }

  Component.onDestruction: flush()
}
