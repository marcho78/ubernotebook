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
  property real syncedMax: 16000000

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
  // (Another profile's notes: nothing read from these is kept for them;
  // their pages may have the same ids.)
  onNotesRootChanged: { pageCache = ({}); notebookCache = ({}); schedule() }

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
    // (Where it copies from, as it was when it started: a copy that's begun
    // and another profile's open meanwhile, it stops.)
    var from = { root: notesRoot, pages: workspace.folder }
    function stale() { return gen !== mirror.generation || mirror.movedOn(dir, from) }
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
            write(dir, gen, existing, pages, notebooks, from)
          })
        })
      }, { timeoutMs: 20000, maxBytes: 8 * 1024 * 1024 })
    })
  }

  function movedOn(dir, from) { return dir !== folder || !on || from.root !== notesRoot || !workspace || from.pages !== workspace.folder }

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
    var root = notesRoot
    // (Not the templates: they're no one's notes.)
    var ids = Object.keys(ix.pages).filter(function(id) { return !Workspace.inTrash(ix, id) && !Workspace.inTemplates(ix, id) })
    var need = ids.filter(function(id) { var c = pageCache[id]; return !c || c.modified !== ix.pages[id].modified || workspace.written[id] })
    workspace.readPages(need, function(list) {
      if (root !== mirror.notesRoot) { done({}); return }
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
    var root = notesRoot
    var cache = {}
    var i = 0
    function next() {
      if (root !== mirror.notesRoot) { done([]); return }
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
    // (What synced blocks write, in all the pages of a pass: 16 million
    // characters at most, so many pages syncing one big one stay small.)
    var syncedBudget = { chars: 0, max: mirror.syncedMax }
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
        syncedBudget: syncedBudget,
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

  // Each file's fingerprint (Mirror.hash), worked out again only when its
  // text changed: { path: { text, hash } }.
  property var hashes: ({})
  function hashOf(path, text) {
    var h = hashes[path]
    if (h && h.text === text) return h.hash
    var v = Mirror.hash(text)
    hashes[path] = { text: text, hash: v }
    return v
  }

  // What changed, made by the files helper (mirror-apply): each file written
  // or taken away only if it's still as the copy wrote it (its fingerprint,
  // checked on its bytes as it's moved aside). One that isn't (edited in
  // Obsidian, say) is yours now: never written over or taken away, and no
  // longer the copy's (its page goes to "Name (2).md" the next time, which
  // is at once).
  function write(dir, gen, existing, pages, notebooks, from) {
    var built = build(existing, pages, notebooks)
    built.from = from || { root: notesRoot, pages: workspace.folder }
    apply(dir, gen, built, Mirror.plan(manifest || {}, built.desired, existing, mirror.hashOf), existing)
  }

  function apply(dir, gen, built, todo, existing) {
    var desired = built.desired
    var man = manifest || {}
    // (What it wrote before and is still as it would write: still its own.
    // An old fingerprint, from before, is no proof of that.)
    var next = {}
    for (var p in desired) if (Mirror.isHash(man[p]) && man[p] === hashOf(p, desired[p]) && existing[p]) next[p] = man[p]
    var ops = todo.write.map(function(path) { return { op: "write", path: path, expect: existing[path] ? (man[path] || "") : "absent", text: desired[path] } })
      .concat(todo.remove.map(function(path) { return { op: "remove", path: path, expect: man[path] || "" } }))
    function after(kept) {
      // Pictures: Pages' into assets/, each notebook's into its folder.
      if (mirror.movedOn(dir, built.from)) return finish(gen)
      var copies = [[built.from.pages + "/assets", dir + "/assets"]]
      built.notebookDirs.forEach(function(d) { copies.push([built.from.root + "/" + d.id + "/assets", dir + "/" + d.dir + "/assets"]) })
      copyAll(copies, function() {
        if (gen !== mirror.generation) return finish(gen)
        var changed = canon(next) !== canon(mirror.manifest || {}) || ops.length > 0
        mirror.manifest = next
        var done = function() {
          mirror.files = Object.keys(next).length
          mirror.lastSync = new Date()
          mirror.status = "Up to date"
          mirror.synced()
          finish(gen)
          // (Yours now: their pages' copies go beside them.)
          if (kept.length) mirror.schedule()
        }
        // (Through the files helper: a link put where it goes is replaced,
        // never written through.)
        // (A list that couldn't be kept is said: without it, the next start
        // would take the copy's files for yours.)
        if (changed) store.putFile(dir, Mirror.MANIFEST, JSON.stringify({ version: 1, app: "Uber Notebook", files: next }, null, 1) + "\n", function(ok, why) {
          done()
          if (!ok) mirror.status = "Copied, but its list of what it wrote couldn't be kept" + (why ? ": " + why : "")
        }, true)
        else done()
      })
    }
    if (!ops.length) { after([]); return }
    var plan = store.runtimeDir + "/uber-notebook-mirror-plan-" + Workspace.uuid4().slice(0, 8) + ".json"
    store.mkdirs([dir], function(made) {
      if (!made) { mirror.status = "Couldn't make " + dir; return finish(gen) }
      store.writeFile(plan, JSON.stringify({ ops: ops }), function(wrote) {
        if (!wrote) { mirror.status = "Couldn't copy: its plan couldn't be written"; return finish(gen) }
        store.helper(["mirror-apply", dir, plan], function(ok, out) {
          var r = store.parseJson(String(out || "").trim().split("\n").pop())
          if (!ok || !r || r.ok !== true) {
            store.exec(["/usr/bin/rm", "-f", "--", plan], null)
            mirror.status = "Couldn't copy: " + (r && r.error ? r.error : String(out || "").split("\n")[0] || "the files helper didn't answer")
            return finish(gen)
          }
          for (var w in r.written) if (Mirror.isHash(r.written[w])) next[w] = r.written[w]
          // (One it couldn't change: as it was, its own if it was.)
          for (var f in (r.failed || {})) if (Mirror.isHash(man[f]) && existing[f]) next[f] = man[f]
          after(r.kept || [])
        }, { timeoutMs: 120000, maxBytes: 8 * 1024 * 1024 })
      })
    })
  }

  function canon(o) { return JSON.stringify(Object.keys(o).sort().map(function(k) { return [k, o[k]] })) }

  // Pictures copied over (only what's new).
  function copyAll(list, done) {
    var i = 0
    function next() {
      if (i >= list.length) { done(); return }
      var c = list[i++]
      // (Never over a file that's there: a picture's name is new each time.
      // Neither folder a link: one put there would copy a folder of yours
      // into the copy, or the pictures somewhere else.)
      store.exec(["/usr/bin/bash", "-c", "[ -d \"$1\" ] && [ ! -L \"$1\" ] && [ ! -L \"$2\" ] || exit 0; /usr/bin/mkdir -p -- \"$2\" && /usr/bin/cp -r --update=none -- \"$1\"/. \"$2\"/", "uber-notebook-mirror-copy", c[0], c[1]], function() { next() }, { timeoutMs: 60000, okCodes: [0, 1] })
    }
    next()
  }
}
