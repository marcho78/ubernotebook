import QtQuick
import Quickshell
import Quickshell.Io
import "Library.js" as Library
import "Blocks.js" as Blocks
import "Html.js" as Html
import "Markdown.js" as Markdown
import "Settings.js" as Settings

// The notebooks on disk. Each notebook is a folder in the notebooks folder
// (~/Documents/Omanote by default):
//
//   <notebook>/notebook.json         title, cover, paper, pen, kind of page, pages in order
//   <notebook>/pages/<page>.json     one page each
//   <notebook>/assets/<picture>      pictures, copied in when you add them
//   library.json                     the shelf's order
//   .trash/                          notebooks and pages you threw away
//
// Every file is written whole and atomically (to a temporary file that then
// replaces it), and everything read is checked by Library.js first. Reading
// many files at once, searching, copying pictures and the like run as single
// programs with arguments (Run.qml), never through a shell with your text in
// it; the one bash script below loops over file names it's handed as
// arguments.
Item {
  id: store

  property string home: Quickshell.env("HOME")
  // Where imports are unpacked and converted for a moment (a tmpfs of your own).
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
  // Settings.folder: "" is the default place.
  property string folder: ""
  property string rootPath: ""
  property bool ready: false
  property var notebooks: []

  // id -> notebook.json (clean), for every notebook on the shelf.
  property var index: ({})
  property var order: []

  signal failed(string message)
  signal exported(string path)
  // A page was added from outside the open notebook (a quick note).
  signal pageAdded(string notebookId, var page)

  // The folder can change just after the shell starts (when the settings
  // arrive): look a moment later, once, and ignore what an older look finds.
  onFolderChanged: locateTimer.restart()
  Component.onCompleted: locateTimer.restart()

  Timer {
    id: locateTimer
    interval: 250
    onTriggered: store.locate()
  }

  property int generation: 0

  // ---- running programs ------------------------------------------------------------

  Component {
    id: runComponent
    Run {}
  }

  // Runs argv; done(ok, output) once, then the runner goes away.
  function exec(argv, done, options) {
    var o = options || {}
    var runner = runComponent.createObject(store, { timeoutMs: o.timeoutMs || 8000, maxBytes: o.maxBytes || 256 * 1024, okCodes: o.okCodes || [0] })
    runner.finished.connect(function(ok, output) {
      try { if (done) done(ok, output) } finally { runner.destroy() }
    })
    runner.start(argv)
  }

  // Reads many files in one go: done({ path: text }). The script only loops
  // over the paths (or the files a folder pattern matches) it's given.
  readonly property string readScript: "for f in \"$@\"; do if [ -f \"$f\" ]; then printf '\\036%s\\037' \"$f\"; /usr/bin/cat -- \"$f\"; fi; done"
  readonly property string globScript: "shopt -s nullglob; for f in \"$1\"/$2; do printf '\\036%s\\037' \"$f\"; /usr/bin/cat -- \"$f\"; done"

  function parseFrames(output) {
    var out = {}
    String(output || "").split("\u001e").forEach(function(frame) {
      var cut = frame.indexOf("\u001f")
      if (cut > 0) out[frame.slice(0, cut)] = frame.slice(cut + 1)
    })
    return out
  }

  function readFiles(paths, done, maxBytes) {
    if (paths.length === 0) { done({}); return }
    exec(["/usr/bin/bash", "-c", readScript, "omanote-read"].concat(paths), function(ok, output) {
      done(ok ? parseFrames(output) : {})
    }, { maxBytes: maxBytes || 32 * 1024 * 1024, timeoutMs: 20000 })
  }

  function readGlob(dir, pattern, done, maxBytes) {
    exec(["/usr/bin/bash", "-c", globScript, "omanote-read", dir, pattern], function(ok, output) {
      done(ok ? parseFrames(output) : {})
    }, { maxBytes: maxBytes || 64 * 1024 * 1024, timeoutMs: 30000 })
  }

  function parseJson(text) {
    try { return JSON.parse(text) } catch (e) { return null }
  }

  Component {
    id: readerComponent
    FileView {
      blockAllReads: true
      printErrors: false
      watchChanges: false
    }
  }

  // A file's text, read now, for a command that answers at once (one small
  // file: this holds up the shell while it reads); null if it can't be read
  // or is over maxBytes.
  function readNow(path, maxBytes) {
    var view = readerComponent.createObject(store, { path: path })
    if (!view) return null
    // text() reads it there and then; `loaded` then tells an empty file
    // from one that isn't there.
    var text = view.text()
    if (!view.loaded || text.length > (maxBytes || 2 * 1024 * 1024)) text = null
    view.destroy()
    return text
  }

  // ---- your agent: Omarchy's default coding agent ------------------------------------

  // Its name as Omarchy keeps it ("claude", "codex"...), or "" when there's
  // none yet: done(name).
  function defaultAgent(done) {
    exec(["/usr/bin/omarchy-default-agent"], function(ok, output) {
      var name = ok ? String(output || "").trim().split("\n")[0] : ""
      done(/^[a-z][a-z0-9-]{0,30}$/.test(name) ? name : "")
    }, { timeoutMs: 3000, maxBytes: 4096 })
  }

  // Omarchy launches it, in its own terminal, starting with the prompt;
  // nothing here waits for it.
  function launchAgent(prompt) {
    Quickshell.execDetached(["/usr/bin/omarchy-agent-prompt", String(prompt)])
  }

  // Omarchy's menu for choosing the default agent.
  function pickAgent() {
    Quickshell.execDetached(["/usr/bin/omarchy-menu", "summon", "setup.default.agent"])
  }

  // The omanote skill, linked into the folders agents read skills from (the
  // ones Omarchy links its own skills into), so whichever agent you use knows
  // Omanote's commands. A link is only made where nothing has that name,
  // and only Omanote's own links (to `target`) are taken out.
  readonly property var skillFolders: [".agents/skills", ".claude/skills", ".codex/skills", ".hermes/skills", ".pi/agent/skills"]
  readonly property string skillScript: "mode=$1; target=$2; shift 2; for dir in \"$@\"; do link=\"$dir/omanote\"; "
    + "if [ \"$mode\" = link ]; then if [ -d \"$dir\" ] && [ ! -e \"$link\" ] && [ ! -L \"$link\" ]; then /usr/bin/ln -s -- \"$target\" \"$link\"; fi; "
    + "elif [ -L \"$link\" ] && [ \"$(/usr/bin/readlink -- \"$link\")\" = \"$target\" ]; then /usr/bin/rm -f -- \"$link\"; fi; done; exit 0"

  function skillDirs() { return skillFolders.map(function(f) { return store.home + "/" + f }) }
  function linkSkill(target) {
    exec(["/usr/bin/bash", "-c", skillScript, "omanote-skills", "link", target].concat(skillDirs()), null, { timeoutMs: 5000 })
  }
  function unlinkSkill(target) {
    Quickshell.execDetached(["/usr/bin/bash", "-c", skillScript, "omanote-skills", "unlink", target].concat(skillDirs()))
  }

  // ---- writing files -------------------------------------------------------------------

  Component {
    id: writerComponent
    FileView {
      atomicWrites: true
      preload: false
      printErrors: false
      watchChanges: false
    }
  }

  property var writing: ({})
  property var queued: ({})
  // While the shell is stopping, writes finish before anything else happens.
  property bool stopping: false

  // Writes text to path (atomically). One write per file at a time; a newer
  // text waiting for it replaces an older one.
  function writeFile(path, text, done) {
    if (writing[path]) {
      queued[path] = { text: text, done: done }
      return
    }
    writing[path] = true
    var view = writerComponent.createObject(store, { path: path, blockWrites: stopping })
    function finish(ok, error) {
      delete writing[path]
      view.destroy()
      if (!ok) failed("Couldn't save " + path.replace(home, "~") + (error ? ": " + error : ""))
      if (done) done(ok)
      var next = queued[path]
      if (next) {
        delete queued[path]
        writeFile(path, next.text, next.done)
      }
    }
    view.saved.connect(function() { finish(true, "") })
    view.saveFailed.connect(function(error) { finish(false, String(error)) })
    view.setText(text)
  }

  function mkdirs(paths, done) {
    exec(["/usr/bin/mkdir", "-p", "--"].concat(paths), function(ok, output) {
      if (!ok) failed("Couldn't make " + paths[0].replace(home, "~") + ": " + output)
      if (done) done(ok)
    })
  }

  // ---- notebook folders ------------------------------------------------------------------

  // id -> true once its folder exists; until then, what needs it waits.
  property var folders: ({})
  property var waiting: ({})

  function whenReady(id, fn) {
    if (folders[id]) { fn(); return }
    var list = waiting[id] || []
    list.push(fn)
    waiting[id] = list
  }

  function folderMade(id) {
    folders[id] = true
    var list = waiting[id] || []
    delete waiting[id]
    list.forEach(function(fn) { fn() })
  }

  // ---- the library -------------------------------------------------------------------------

  function locate() {
    if (!home) return
    ready = false
    var gen = ++generation
    exec(["/usr/bin/test", "-d", home + "/Documents"], function(ok) {
      if (gen !== store.generation) return
      store.rootPath = Settings.resolveFolder(store.folder, store.home, ok)
      store.mkdirs([store.rootPath], function(made) { if (made && gen === store.generation) store.loadLibrary() })
    })
  }

  property bool welcomed: false

  function loadLibrary() {
    var gen = generation
    readGlob(rootPath, "*/notebook.json", function(files) {
      if (gen !== store.generation) return
      var found = {}
      for (var path in files) {
        var id = path.slice(rootPath.length + 1, path.length - "/notebook.json".length)
        if (!Library.isId(id)) continue
        var nb = Library.cleanNotebook(parseJson(files[path]), id)
        if (nb) { found[id] = nb; store.folders[id] = true }
      }
      store.index = found
      store.readFiles([Library.libraryFile(store.rootPath)], function(lib) {
        var saved = parseJson(lib[Library.libraryFile(store.rootPath)] || "")
        var list = Object.keys(found).map(function(id) { return found[id] })
        store.order = Library.shelfOrder(saved && Array.isArray(saved.order) ? saved.order : [], list).map(function(nb) { return nb.id })
        store.publish()
        store.ready = true
        // A first notebook, once, in a folder with none.
        if (store.order.length === 0 && !store.welcomed) {
          store.welcomed = true
          store.createWelcome()
        }
      })
    })
  }

  function meta(nb) {
    return { id: nb.id, title: nb.title, cover: nb.cover, binding: nb.binding, paper: nb.paper, pen: nb.pen, template: nb.template, pageCount: nb.pages.length, created: nb.created, modified: nb.modified, lastPage: nb.lastPage, role: nb.role }
  }

  function publish() {
    publishTimer.stop()
    notebooks = order.filter(function(id) { return index[id] }).map(function(id) { return meta(index[id]) })
  }

  // For changes only the shelf's small print shows (when it was last edited).
  function publishSoon() {
    if (!publishTimer.running) publishTimer.start()
  }

  Timer {
    id: publishTimer
    interval: 4000
    onTriggered: store.publish()
  }

  function saveOrder() {
    writeFile(Library.libraryFile(rootPath), Library.stringify({ version: 1, order: order }))
  }

  // notebook.json, a moment after the last change to it.
  property var notebookDirty: ({})

  function saveNotebook(id) {
    notebookDirty[id] = true
    notebookTimer.restart()
  }

  Timer {
    id: notebookTimer
    interval: 400
    onTriggered: store.flushNotebooks()
  }

  function flushNotebooks() {
    var ids = Object.keys(notebookDirty)
    notebookDirty = ({})
    ids.forEach(function(id) {
      var nb = index[id]
      if (nb) whenReady(id, function() { store.writeFile(Library.notebookFile(store.rootPath, id), Library.stringify(nb)) })
    })
  }

  // ---- notebooks ---------------------------------------------------------------------------

  // A new notebook, with the given first pages (null: one blank page). Returns
  // what the shelf shows of it; its folder is made and its files written next.
  function createNotebook(choice, firstPages) {
    var taken = {}
    order.forEach(function(id) { taken[id] = true })
    var nb = Library.newNotebook(choice, new Date(), taken)
    var pages = (firstPages === null || firstPages === undefined ? [{}] : firstPages).map(function(p) { return Library.newPage(p) })
    nb.pages = pages.map(function(p) { return p.id })
    index[nb.id] = nb
    order = order.concat([nb.id])
    publish()
    var dir = rootPath + "/" + nb.id
    mkdirs([dir + "/pages", dir + "/assets"], function(ok) {
      if (!ok) return
      store.folderMade(nb.id)
      store.saveOrder()
    })
    pages.forEach(function(p) { writePage(nb.id, p) })
    saveNotebook(nb.id)
    return meta(nb)
  }

  function updateNotebook(id, choice) {
    var nb = index[id]
    if (!nb) return
    var clean = Library.cleanNotebook({
      title: choice.title, cover: choice.cover, binding: choice.binding, paper: choice.paper, pen: choice.pen,
      template: choice.template !== undefined ? choice.template : nb.template, created: nb.created, modified: new Date().toISOString(), pages: nb.pages, lastPage: nb.lastPage, role: nb.role
    }, id)
    if (!clean) return
    index[id] = clean
    publish()
    saveNotebook(id)
  }

  // Small changes that don't count as editing it: the page it's open at, its paper.
  function touchNotebook(id, changes) {
    var nb = index[id]
    if (!nb) return
    if (changes.lastPage !== undefined && Library.isId(changes.lastPage)) nb.lastPage = changes.lastPage
    if (changes.paper) nb.paper = Library.cleanPaper(changes.paper) || nb.paper
    saveNotebook(id)
  }

  function deleteNotebook(id) {
    if (!index[id]) return
    delete written[id]
    var from = rootPath + "/" + id
    delete index[id]
    order = order.filter(function(x) { return x !== id })
    publish()
    saveOrder()
    trash(from, id)
  }

  function moveNotebook(id, to) {
    var list = order.filter(function(x) { return x !== id })
    list.splice(Math.max(0, Math.min(list.length, to)), 0, id)
    order = list
    publish()
    saveOrder()
  }

  // Moves a notebook or page into the trash, under a name that's never taken.
  function trash(path, name) {
    var dir = Library.trashDir(rootPath)
    var stamp = Library.pageId(new Date())
    mkdirs([dir], function(ok) {
      if (!ok) return
      exec(["/usr/bin/mv", "-n", "--", path, dir + "/" + stamp + "-" + name], function(done, output) {
        if (!done) store.failed("Couldn't move it to the trash: " + output)
      })
    })
  }

  // Opens a notebook: done(notebook with every page), or done(null).
  function openNotebook(id, done) {
    var nb = index[id]
    if (!nb) { done(null); return }
    whenReady(id, function() { store.readPages(id, done) })
  }

  function readPages(id, done) {
    var nb = index[id]
    if (!nb) { done(null); return }
    readGlob(Library.pagesDir(rootPath, id), "*.json", function(files) {
      var byId = {}
      var onDisk = []
      for (var path in files) {
        var pid = path.slice(path.lastIndexOf("/") + 1, path.length - 5)
        var page = Library.cleanPage(parseJson(files[path]), pid)
        if (page) { byId[pid] = page; onDisk.push(pid) }
      }
      var mine = store.written[id] || {}
      for (var wid in mine) {
        if (!byId[wid]) onDisk.push(wid)
        byId[wid] = JSON.parse(JSON.stringify(mine[wid]))
      }
      var ids = Library.reconcilePages(nb.pages, onDisk)
      var pages = ids.map(function(pid) { return byId[pid] })
      if (pages.length === 0) {
        var first = Library.newPage({})
        pages = [first]
        ids = [first.id]
        store.writePage(id, first)
      }
      if (ids.join() !== nb.pages.join()) {
        nb.pages = ids
        store.saveNotebook(id)
        store.publish()
      }
      var out = JSON.parse(JSON.stringify(nb))
      out.pages = pages
      done(out)
    })
  }

  // ---- pages -----------------------------------------------------------------------------

  // Every page created or saved this session, by notebook: what's on disk
  // may still be on its way there, so opening a notebook prefers these.
  property var written: ({})

  function remember(id, page) {
    if (!written[id]) written[id] = {}
    written[id][page.id] = JSON.parse(JSON.stringify(page))
  }

  function pageJson(page) {
    return Library.stringify({
      version: 1, id: page.id, title: page.title || "", created: page.created, modified: page.modified,
      paper: page.paper || null, tab: page.tab || null, template: page.template || "", day: page.day || "",
      blocks: page.blocks, ink: page.ink || [],
      text: page.text !== undefined ? page.text : Blocks.plainText(page.blocks)
    })
  }

  function writePage(id, page) {
    remember(id, page)
    var path = Library.pageFile(rootPath, id, page.id)
    var text = pageJson(page)
    whenReady(id, function() { store.writeFile(path, text) })
  }

  // A new page at an index (blank, or what `options` has on it: a
  // template's title and blocks). Returns it; it's written straight away.
  function createPage(id, at, options) {
    var nb = index[id]
    if (!nb) return null
    var taken = {}
    nb.pages.forEach(function(p) { taken[p] = true })
    var page = Library.newPage(options, new Date(), taken)
    var list = nb.pages.slice()
    list.splice(Math.max(0, Math.min(list.length, at)), 0, page.id)
    nb.pages = list
    nb.modified = page.created
    writePage(id, page)
    saveNotebook(id)
    publish()
    return page
  }

  function savePage(id, page) {
    var nb = index[id]
    if (!nb) return
    writePage(id, page)
    var added = nb.pages.indexOf(page.id) < 0
    if (added) nb.pages = nb.pages.concat([page.id])
    nb.modified = page.modified
    saveNotebook(id)
    if (added) publish()
    else publishSoon()
  }

  function deletePage(id, pageId) {
    var nb = index[id]
    if (!nb || !Library.isId(pageId)) return
    if (written[id]) delete written[id][pageId]
    nb.pages = nb.pages.filter(function(p) { return p !== pageId })
    nb.modified = new Date().toISOString()
    saveNotebook(id)
    publish()
    trash(Library.pageFile(rootPath, id, pageId), id + "-" + pageId + ".json")
  }

  function orderPages(id, ids) {
    var nb = index[id]
    if (!nb) return
    nb.pages = ids.filter(Library.isId)
    saveNotebook(id)
  }

  // ---- the first notebook ----------------------------------------------------------------------

  function createWelcome() {
    var tip = function(html) { return { type: "check", html: html } }
    createNotebook({
      title: "My Notebook",
      cover: { color: "navy", material: "leather" },
      binding: "spiral",
      paper: { pattern: "ruled", color: "ivory", spacing: "regular" },
      pen: "sans"
    }, [{
      title: "Welcome to Omanote",
      blocks: [
        { type: "p", html: "This is your notebook. Everything you write is <span style=\"font-weight:700;\">saved as you go</span>, as plain files in " + Html.escapeText(rootPath.replace(home, "~")) + "." },
        { type: "h2", html: "Things to try" },
        tip("Type <span style=\"font-weight:700;\">- </span> and a space for a list, <span style=\"font-weight:700;\">[] </span> for a checkbox, <span style=\"font-weight:700;\"># </span> for a heading"),
        tip("Select a few words and press <span style=\"font-weight:700;\">Ctrl+B</span>, or pick an ink and a <span style=\"background-color:#fff27a;\">highlighter</span> below"),
        tip("Tick this box with a click, or with Ctrl+Enter"),
        tip("Turn the page with Ctrl+PgDown, or click the page's bottom corner"),
        tip("Paste or drop a picture onto the page"),
        tip("Give a page an index tab: \u22ef, then Add a tab"),
        { type: "callout", tone: "yellow", html: "<span style=\"font-weight:700;\">Super+N</span> opens and closes Omanote from anywhere. <span style=\"font-weight:700;\">Super+Alt+N</span> jots a quick note." },
        { type: "p", html: "Back to the shelf (top left) to start another notebook, with the cover, paper and pen you like." }
      ]
    }, {}])
  }

  // ---- quick notes ---------------------------------------------------------------------------

  // A quick note becomes a new page in the Quick notes notebook (made the
  // first time), titled with its first line.
  function quickNote(text) {
    var lines = String(text || "").replace(/\r/g, "").split("\n")
    while (lines.length && lines[0].trim() === "") lines.shift()
    while (lines.length && lines[lines.length - 1].trim() === "") lines.pop()
    if (lines.length === 0) return
    var id = ""
    order.forEach(function(nid) { if (index[nid] && index[nid].role === "quick") id = nid })
    if (!id) {
      var made = createNotebook({ title: "Quick notes", cover: { color: "mustard", material: "plain" }, binding: "spiral", paper: { pattern: "legal", color: "yellow", spacing: "regular" }, pen: "print", role: "quick" }, [])
      id = made.id
    }
    var title = lines[0].trim().slice(0, 120)
    var blocks = lines.slice(1).map(function(line) {
      var m = /^\s*[-*]\s+(.*)$/.exec(line)
      var c = /^\s*\[( |x|X)?\]\s+(.*)$/.exec(line)
      if (c) return { type: "check", checked: !!c[1] && c[1] !== " ", html: Html.escapeText(c[2]) }
      if (m) return { type: "bullet", html: Html.escapeText(m[1]) }
      return { type: "p", html: Html.escapeText(line) }
    })
    var page = createPage(id, index[id].pages.length, { title: title, blocks: blocks.length ? blocks : [{ type: "p", html: "" }] })
    if (page) {
      page.text = Blocks.plainText(page.blocks)
      writePage(id, page)
      pageAdded(id, page)
    }
  }

  // ---- finding text ------------------------------------------------------------------------

  // Every page that has every word of the query: done([...]), best first.
  function search(query, done) {
    var words = Library.terms(query)
    if (words.length === 0 || !rootPath) { done([]); return }
    var longest = words.slice().sort(function(a, b) { return b.length - a.length })[0]
    exec(["/usr/bin/grep", "-rilF", "--include=*.json", "--exclude-dir=.trash", "--exclude-dir=Pages", "-e", longest, "--", rootPath], function(ok, output) {
      var paths = String(output || "").split("\n").filter(function(p) { return /\/pages\/[a-z0-9-]+\.json$/.test(p) }).slice(0, 400)
      store.readFiles(paths, function(files) {
        var results = []
        for (var path in files) {
          var parts = path.slice(store.rootPath.length + 1).split("/")
          var nid = parts[0]
          var pid = parts[2] ? parts[2].slice(0, -5) : ""
          var nb = store.index[nid]
          var page = nb ? Library.cleanPage(store.parseJson(files[path]), pid) : null
          if (!page) continue
          var title = Library.pageTitle(page, 60) || "Untitled"
          var score = Library.score(title, page.text, query)
          if (score <= 0) continue
          results.push({
            notebookId: nid, notebookTitle: nb.title, cover: nb.cover, pageId: pid, pageTitle: title,
            pageNumber: nb.pages.indexOf(pid) + 1, snippet: Library.snippet(page.text, query), score: score, modified: page.modified
          })
        }
        results.sort(function(a, b) { return b.score - a.score || (a.modified < b.modified ? 1 : -1) })
        done(results.slice(0, 60))
      }, 16 * 1024 * 1024)
    }, { okCodes: [0, 1], maxBytes: 2 * 1024 * 1024, timeoutMs: 8000 })
  }

  // ---- pictures ---------------------------------------------------------------------------

  function assetUrl(id, src) {
    if (!Library.isId(id) || !Blocks.cleanAsset(src)) return ""
    return "file://" + encodeURI(rootPath + "/" + id + "/" + src)
  }

  // Copies a picture into the notebook: done("assets/<name>") or done("").
  function importPicture(id, path, done) {
    if (!index[id] || !Library.isImagePath(path)) { done(""); return }
    var name = Library.assetName(path, new Date())
    var dest = Library.assetsDir(rootPath, id)
    mkdirs([dest], function(ok) {
      if (!ok) { done(""); return }
      store.exec(["/usr/bin/cp", "--", path, dest + "/" + name], function(copied, output) {
        if (!copied) store.failed("Couldn't copy the picture: " + output)
        done(copied ? "assets/" + name : "")
      }, { timeoutMs: 20000 })
    })
  }

  // A picture on the clipboard, saved into the notebook: done(src) or done("").
  function pastePicture(id, done) {
    if (!index[id]) { done(""); return }
    pasteInto(Library.assetsDir(rootPath, id), done)
  }

  function isImagePath(path) { return Library.isImagePath(path) }
  function assetName(path) { return Library.assetName(path, new Date()) }

  // A picture on the clipboard, saved into a folder of pictures (a
  // notebook's or Pages'): done("assets/<name>") or done("").
  function pasteInto(dest, done) {
    exec(["/usr/bin/wl-paste", "--list-types"], function(ok, output) {
      var types = String(output || "").split("\n")
      var pick = ""
      var ext = ""
      var kinds = [["image/png", "png"], ["image/jpeg", "jpg"], ["image/webp", "webp"], ["image/gif", "gif"]]
      for (var i = 0; i < kinds.length && !pick; i++) if (types.indexOf(kinds[i][0]) >= 0) { pick = kinds[i][0]; ext = kinds[i][1] }
      if (!ok || !pick) { done(""); return }
      var name = Library.pageId(new Date()) + "." + ext
      store.mkdirs([dest], function(made) {
        if (!made) { done(""); return }
        // wl-paste writes the picture to its stdout; bash only points that at the file.
        store.exec(["/usr/bin/bash", "-c", "exec /usr/bin/wl-paste --no-newline --type \"$1\" > \"$2\"", "omanote-paste", pick, dest + "/" + name], function(pasted) {
          done(pasted ? "assets/" + name : "")
        }, { timeoutMs: 10000 })
      })
    }, { okCodes: [0, 1], timeoutMs: 3000 })
  }

  // ---- out of Omanote -----------------------------------------------------------------------

  function copyText(text) {
    var value = String(text || "")
    if (!value || value.length > 1000000) return
    Quickshell.execDetached(["/usr/bin/wl-copy", "--", value])
  }

  function openUrl(url) {
    if (!/^(https?:|mailto:|file:)/i.test(String(url || ""))) return
    Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", String(url)])
  }

  function openFolder() {
    if (rootPath) Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", rootPath])
  }

  // An Omarchy notification (a reminder); clicking it opens the page.
  function notify(title, text, pageId) {
    // Texts starting with "-" would be read as options.
    var head = String(title || "Reminder").replace(/^-+/, "\u2010").slice(0, 120)
    var body = String(text || "").replace(/^-+/, "\u2010").slice(0, 300)
    var argv = ["/usr/bin/omarchy-notification-send", "-g", "\u{f009e}", "-u", "normal", "--app-name", "Omanote", head, body]
    if (/^[0-9a-f-]{36}$/.test(String(pageId || ""))) argv = argv.concat(["--exec", "/usr/bin/omarchy-shell", "omanote", "open", pageId])
    Quickshell.execDetached(argv)
  }

  // A folder Omanote made (an export), in the file manager.
  function openPath(path) {
    if (path && path.indexOf(rootPath + "/") === 0) Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", path])
  }

  // Every page as a Markdown file, and its pictures, in a folder beside the
  // notebooks: "<notebooks>/Exports/<title> <date>/".
  function exportNotebook(id) {
    openNotebook(id, function(nb) {
      if (!nb) return
      var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm")
      var name = (nb.title.replace(/[\/\\:*?"<>|\u0000-\u001f]+/g, " ").trim() || "Notebook") + " " + stamp
      var dir = store.rootPath + "/Exports/" + name
      store.mkdirs([dir], function(ok) {
        if (!ok) return
        var used = {}
        nb.pages.forEach(function(page, i) {
          var file = ("00" + (i + 1)).slice(-3) + " " + Markdown.fileName(page, i)
          if (used[file]) file = file.replace(/\.md$/, " " + i + ".md")
          used[file] = true
          store.writeFile(dir + "/" + file, Markdown.fromPage(page, ""))
        })
        store.exec(["/usr/bin/cp", "-r", "--", store.rootPath + "/" + id + "/assets", dir + "/assets"], function() {
          store.exported(dir)
          Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", dir])
        }, { okCodes: [0, 1], timeoutMs: 60000 })
      })
    })
  }

  // ---- when the shell stops ---------------------------------------------------------------------

  // Called by the service as the shell stops: everything still waiting is
  // written now.
  function flush() {
    stopping = true
    notebookTimer.stop()
    var ids = Object.keys(notebookDirty)
    notebookDirty = ({})
    ids.forEach(function(id) {
      var nb = index[id]
      if (nb && folders[id]) store.writeFile(Library.notebookFile(rootPath, id), Library.stringify(nb))
    })
  }

  Component.onDestruction: flush()
}
