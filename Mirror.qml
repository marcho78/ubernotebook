import QtQuick
import "Mirror.js" as Mirror
import "Markdown.js" as Markdown
import "Workspace.js" as Workspace
import "Sketch.js" as Sketch

// The Markdown copy of your notes (Mirror.js says what it is), kept up to
// date a few seconds after anything changes while it's on: Pages' pages, the
// notebooks' pages, Pages' pictures (and each notebook's) and sketches as SVG.
// It reads again only what changed since it last looked, writes only files
// whose text changed, and takes away only files it wrote itself.
Item {
  id: mirror

  // Workspace.qml (Pages), and Store.qml (the notebooks, and the calls that
  // read and write files and run programs).
  property var workspace: null
  property var store: null
  // Kept up to date while it's on.
  property bool on: false
  // Where the copy goes (a full path), the notes folder, and home.
  property string folder: ""
  property string notesRoot: ""
  property string home: ""
  // How long after a change it copies.
  property int delay: 3000

  // What it says in Settings: "" (off), or how it's going.
  property string status: ""
  property string problem: ""
  property bool busy: false
  property int files: 0
  property var lastSync: null
  signal synced()

  property bool again: false
  property int generation: 0
  // The manifest (path -> fingerprint) of the folder it was read from.
  property var manifest: null
  property string manifestFor: ""
  // Pages and notebooks read before, and when they'd last changed.
  property var pageCache: ({})
  property var notebookCache: ({})

  readonly property string listScript: "cd \"$1\" 2>/dev/null || exit 0; for d in Pages Notebooks sketches; do [ -d \"$d\" ] && /usr/bin/find \"$d\" -maxdepth 16 -type f \\( -name '*.md' -o -name '*.svg' \\) -print; done; exit 0"
  readonly property string rmdirScript: "cd \"$1\" || exit 0; shift; for d in \"$@\"; do /usr/bin/rmdir -p --ignore-fail-on-non-empty -- \"$d\" 2>/dev/null; done; exit 0"

  Timer {
    id: timer
    interval: mirror.delay
    onTriggered: mirror.sync()
  }

  function schedule() { if (on) timer.restart() }

  onOnChanged: {
    if (on) { status = "Copying soon"; Qt.callLater(mirror.sync) }
    else { timer.stop(); status = ""; problem = "" }
  }
  onFolderChanged: { manifest = null; manifestFor = ""; schedule() }

  Connections {
    target: mirror.workspace
    ignoreUnknownSignals: true
    function onSaved(id) { mirror.schedule() }
    function onRevisionChanged() { mirror.schedule() }
    function onReadyChanged() { mirror.schedule() }
  }
  Connections {
    target: mirror.store
    ignoreUnknownSignals: true
    function onChanged() { mirror.schedule() }
    function onReadyChanged() { mirror.schedule() }
  }

  // Copies now (or as soon as what's copying now is done).
  function sync() {
    if (!on) { status = ""; return }
    if (busy) { again = true; return }
    if (!workspace || !workspace.ready || !store || !store.ready || !folder) { timer.restart(); return }
    var why = Mirror.folderProblem(folder, notesRoot, home, store.notebookList().map(function(n) { return n.id }))
    if (why) {
      problem = why
      status = "Not copying: " + why
      return
    }
    problem = ""
    busy = true
    status = "Copying\u2026"
    var gen = ++generation
    var dir = folder
    function stale() { return gen !== mirror.generation || dir !== mirror.folder || !mirror.on }
    loadManifest(dir, function() {
      if (stale()) return finish(gen)
      store.exec(["/usr/bin/bash", "-c", listScript, "uber-notebook-mirror-list", dir], function(ok, output) {
        if (stale()) return finish(gen)
        var existing = {}
        String(output || "").split("\n").forEach(function(p) { if (p) existing[p] = true })
        readPages(function(pages) {
          if (stale()) return finish(gen)
          readNotebooks(function(notebooks) {
            if (stale()) return finish(gen)
            write(dir, gen, existing, pages, notebooks)
          })
        })
      }, { timeoutMs: 20000, maxBytes: 8 * 1024 * 1024 })
    })
  }

  function finish(gen) {
    if (gen !== generation) return
    busy = false
    if (again) { again = false; schedule() }
  }

  function loadManifest(dir, done) {
    if (manifestFor === dir && manifest) { done(); return }
    var path = dir + "/" + Mirror.MANIFEST
    var legacy = dir + "/" + Mirror.LEGACY_MANIFEST
    store.readFiles([path, legacy], function(got) {
      var raw = null
      var text = got[path] !== undefined ? got[path] : got[legacy]
      try { raw = text ? JSON.parse(text) : null } catch (e) { raw = null }
      mirror.manifest = Mirror.cleanManifest(raw)
      mirror.manifestFor = dir
      done()
    })
  }

  // Every page of Pages not in the trash: those changed since they were last
  // read, read again. done({ id: page }).
  function readPages(done) {
    var ix = workspace.index
    // (Not the templates: they're no one's notes.)
    var ids = Object.keys(ix.pages).filter(function(id) { return !Workspace.inTrash(ix, id) && !Workspace.inTemplates(ix, id) })
    var need = ids.filter(function(id) { var c = pageCache[id]; return !c || c.modified !== ix.pages[id].modified || workspace.written[id] })
    workspace.readPages(need, function(list) {
      var cache = {}
      ids.forEach(function(id) { if (mirror.pageCache[id]) cache[id] = mirror.pageCache[id] })
      list.forEach(function(p) { cache[p.id] = { modified: ix.pages[p.id] ? ix.pages[p.id].modified : p.modified, page: p } })
      mirror.pageCache = cache
      var out = {}
      ids.forEach(function(id) { if (cache[id]) out[id] = cache[id].page })
      done(out)
    })
  }

  // Every notebook on the shelf with its pages: those changed since they
  // were last read, read again. done([{ id, title, pages }]).
  function readNotebooks(done) {
    var list = store.notebookList()
    var cache = {}
    var i = 0
    function next() {
      if (i >= list.length) {
        mirror.notebookCache = cache
        done(list.map(function(nb) { return { id: nb.id, title: nb.title, pages: cache[nb.id] ? cache[nb.id].pages : [] } }))
        return
      }
      var nb = list[i++]
      var had = mirror.notebookCache[nb.id]
      if (had && had.modified === nb.modified) { cache[nb.id] = had; next(); return }
      store.notebookPages(nb.id, function(pages) {
        cache[nb.id] = { modified: nb.modified, pages: pages }
        next()
      })
    }
    next()
  }

  // The files the copy should have: { path: text }, and the notebooks' folders.
  function build(existing, pages, notebooks) {
    var ix = workspace.index
    var man = manifest || {}
    var paths = Mirror.claim(Mirror.pagePaths(ix), man, existing)
    var desired = {}
    for (var id in paths) {
      var page = pages[id]
      if (!page) continue
      var file = paths[id]
      desired[file] = Markdown.fromDocPage(page, function(pid) {
        var e = ix.pages[pid]
        if (!e || Workspace.inTrash(ix, pid)) return null
        return { title: e.title || "Untitled", icon: e.icon, file: paths[pid] ? Mirror.relative(file, paths[pid]) : "" }
      }, {
        assetPrefix: Mirror.toTop(file),
        calendar: workspace.calendar,
        syncedPage: function(id) { return pages[id] || null },
        contactOf: function(id) { return mirror.workspace ? mirror.workspace.contactById(id) : null },
        sketchFile: function(bid) { return Mirror.relative(file, "sketches/" + bid + ".svg") }
      })
      Workspace.sketchesOf(page).forEach(function(k) {
        desired["sketches/" + k.id + ".svg"] = Sketch.toSvg(k.sketch, "A sketch on " + (page.title || "Untitled"))
      })
    }
    var dirs = Mirror.notebookDirs(notebooks)
    var nbPaths = {}
    var texts = {}
    notebooks.forEach(function(nb, n) {
      var used = {}
      nb.pages.forEach(function(p, i) {
        var name = Markdown.fileName(p, i)
        var f = Mirror.notebookFile(dirs[n].dir, i, name)
        if (used[f]) f = f.replace(/\.md$/, " " + (i + 1) + ".md")
        used[f] = true
        nbPaths[nb.id + "/" + p.id] = f
        texts[nb.id + "/" + p.id] = Markdown.fromPage(p, "")
      })
    })
    Mirror.claim(nbPaths, man, existing)
    for (var key in nbPaths) desired[nbPaths[key]] = texts[key]
    return { desired: desired, notebookDirs: dirs }
  }

  // A file of the copy's that isn't as it wrote it (edited in Obsidian, say)
  // is yours now: never written over or taken away, and no longer the copy's
  // (its page goes to "Name (2).md" next time). Each one it would change is
  // read first. done(write, remove) with those left out.
  function keepEdited(dir, todo, existing, done) {
    var man = manifest || {}
    var check = todo.write.filter(function(p) { return man[p] !== undefined && existing[p] }).concat(todo.remove.filter(function(p) { return existing[p] }))
    if (check.length === 0) { done(todo.write, todo.remove, {}); return }
    store.readFiles(check.map(function(p) { return dir + "/" + p }), function(got) {
      var edited = {}
      check.forEach(function(p) {
        var text = got[dir + "/" + p]
        // (One it couldn't read: left as it is.)
        if (text === undefined || Mirror.hash(text) !== man[p]) edited[p] = true
      })
      done(todo.write.filter(function(p) { return !edited[p] }), todo.remove.filter(function(p) { return !edited[p] }), edited)
    }, 64 * 1024 * 1024)
  }

  function write(dir, gen, existing, pages, notebooks) {
    var built = build(existing, pages, notebooks)
    var planned = Mirror.plan(manifest || {}, built.desired, existing)
    keepEdited(dir, planned, existing, function(toWrite, toRemove, edited) {
      if (gen !== mirror.generation) return finish(gen)
      if (Object.keys(edited).length === 0) { writeNow(dir, gen, built, { write: toWrite, remove: toRemove }, edited, existing); return }
      // (They're yours now: the copy is planned again without them, so their
      // pages' copies go beside them.)
      var man = {}
      for (var k in (mirror.manifest || {})) if (!edited[k]) man[k] = mirror.manifest[k]
      mirror.manifest = man
      var again = build(existing, pages, notebooks)
      writeNow(dir, gen, again, Mirror.plan(man, again.desired, existing), edited, existing)
    })
  }

  function writeNow(dir, gen, built, todo, edited, existing) {
    var desired = built.desired
    var next = {}
    for (var p in desired) if (!edited[p] && (manifest || {})[p] === Mirror.hash(desired[p]) && existing[p]) next[p] = (manifest || {})[p]
    var dirs = {}
    todo.write.forEach(function(path) { dirs[dir + "/" + path.slice(0, path.lastIndexOf("/"))] = true })
    var pending = 1
    function one() {
      if (--pending > 0) return
      // Pictures: Pages' into assets/, each notebook's into its folder.
      var copies = [[workspace.folder + "/assets", dir + "/assets"]]
      built.notebookDirs.forEach(function(d) { copies.push([mirror.notesRoot + "/" + d.id + "/assets", dir + "/" + d.dir + "/assets"]) })
      copyAll(copies, function() {
        if (gen !== mirror.generation) return finish(gen)
        var changed = canon(next) !== canon(mirror.manifest || {}) || todo.write.length > 0 || todo.remove.length > 0
        mirror.manifest = next
        var done = function() {
          mirror.files = Object.keys(next).length
          mirror.lastSync = new Date()
          mirror.status = "Up to date"
          mirror.synced()
          finish(gen)
        }
        if (changed) store.writeFile(dir + "/" + Mirror.MANIFEST, JSON.stringify({ version: 1, app: "Uber Notebook", files: next }, null, 1) + "\n", function() { done() })
        else done()
      })
    }
    store.mkdirs(Object.keys(dirs).length ? Object.keys(dirs) : [dir], function(ok) {
      if (!ok) { mirror.status = "Couldn't make " + dir; return finish(gen) }
      todo.write.forEach(function(path) {
        pending++
        store.writeFile(dir + "/" + path, desired[path], function(written) {
          if (written) next[path] = Mirror.hash(desired[path])
          one()
        })
      })
      if (todo.remove.length) {
        pending++
        store.exec(["/usr/bin/rm", "-f", "--"].concat(todo.remove.map(function(path) { return dir + "/" + path })), function() {
          var gone = {}
          todo.remove.forEach(function(path) { gone[path.slice(0, path.lastIndexOf("/"))] = true })
          store.exec(["/usr/bin/bash", "-c", rmdirScript, "uber-notebook-mirror-rmdir", dir].concat(Object.keys(gone)), function() { one() })
        })
      }
      one()
    })
  }

  function canon(o) { return JSON.stringify(Object.keys(o).sort().map(function(k) { return [k, o[k]] })) }

  // Pictures copied over (only what's new).
  function copyAll(list, done) {
    var i = 0
    function next() {
      if (i >= list.length) { done(); return }
      var c = list[i++]
      // (Never over a file that's there: a picture's name is new each time.)
      store.exec(["/usr/bin/bash", "-c", "[ -d \"$1\" ] || exit 0; /usr/bin/mkdir -p -- \"$2\" && /usr/bin/cp -r --update=none -- \"$1\"/. \"$2\"/", "uber-notebook-mirror-copy", c[0], c[1]], function() { next() }, { timeoutMs: 60000, okCodes: [0, 1] })
    }
    next()
  }
}
