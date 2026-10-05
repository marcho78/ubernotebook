import QtQuick
import Quickshell
import Quickshell.Io
import "Library.js" as Library
import "Blocks.js" as Blocks
import "Html.js" as Html
import "Markdown.js" as Markdown
import "Settings.js" as Settings
import "Agent.js" as Agent

// The notebooks on disk. Each notebook is a folder in the notebooks folder
// (~/Documents/Uber Notebook by default):
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
  // Off (no profile yet): no folder is looked for, and nothing's made.
  property bool active: true
  // A first notebook with things to try, in a folder with none.
  property bool welcome: true
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
  // Something on the shelf changed: a page written, a notebook made,
  // renamed, moved or thrown away (the Markdown copy follows).
  signal changed()

  // The folder can change just after the shell starts (when the settings
  // arrive): look a moment later, once, and ignore what an older look finds.
  onFolderChanged: { welcomed = false; locateTimer.restart() }
  onActiveChanged: locateTimer.restart()
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

  Component {
    id: streamComponent
    Stream {}
  }

  // Runs argv, handing on each line it prints as it prints it: onLine(text),
  // then done(code, errors) once (code -1: stopped). { stop() } to end it
  // (options: cwd, timeoutMs).
  function stream(argv, onLine, done, options) {
    var o = options || {}
    var runner = streamComponent.createObject(store, { workingDirectory: o.cwd || "", timeoutMs: o.timeoutMs || 30 * 60 * 1000, input: o.input === true,
      extraEnv: o.env && typeof o.env === "object" ? o.env : ({}), maxBytes: o.maxBytes || 64 * 1024 * 1024, maxLine: o.maxLine || 4 * 1024 * 1024 })
    var over = false
    runner.line.connect(function(text) { if (!over && onLine) onLine(text) })
    runner.finished.connect(function(code, errors) {
      over = true
      try { if (done) done(code, errors) } finally { runner.destroy() }
    })
    if (!runner.start(argv)) {
      over = true
      runner.destroy()
      if (done) done(127, "couldn't start it")
    }
    // (With options.input: send(text) and closeInput(), Stream.qml.)
    return {
      stop: function() { if (!over) runner.stop() },
      send: function(text) { if (!over) runner.send(text) },
      closeInput: function() { if (!over) runner.closeInput() }
    }
  }

  // The helper that opens archives (bin/uber-notebook-files): a zip of notes,
  // a backup. Run isolated (python3 -I -S), as an argument list.
  readonly property string filesHelper: decodeURIComponent(Qt.resolvedUrl("bin/uber-notebook-files").toString().replace(/^file:\/\//, ""))
  function helper(args, done, options) {
    exec(["/usr/bin/python3", "-I", "-S", filesHelper].concat(args), done, options)
  }

  // Runs argv; done(ok, output) once, then the runner goes away. Options:
  // timeoutMs, maxBytes (its output), okCodes, input (written to its stdin),
  // keepChildren (what it starts stays on when it's done: wl-copy).
  function exec(argv, done, options) {
    var o = options || {}
    var runner = runComponent.createObject(store, { timeoutMs: o.timeoutMs || 8000, maxBytes: o.maxBytes || 256 * 1024, okCodes: o.okCodes || [0],
      keepChildren: o.keepChildren === true, input: typeof o.input === "string" ? o.input : "" })
    runner.finished.connect(function(ok, output) {
      try { if (done) done(ok, output) } finally { runner.destroy() }
    })
    runner.start(argv)
  }

  // Reads many files in one go: done({ path: text }, ok) (ok: the read went
  // through, so a file not in it isn't there). The script only loops over the
  // paths (or the files a folder pattern matches) it's given, each file put
  // after a mark made new for each read ($1), so what's in a file can never
  // pass for another file.
  readonly property string readScript: "t=$1; shift; for f in \"$@\"; do if [ -f \"$f\" ]; then printf '\\036%s\\037%s\\037' \"$t\" \"$f\"; /usr/bin/cat -- \"$f\"; fi; done"
  readonly property string globScript: "shopt -s nullglob; for f in \"$2\"/$3; do printf '\\036%s\\037%s\\037' \"$1\" \"$f\"; /usr/bin/cat -- \"$f\"; done"

  function readMark() {
    var s = ""
    for (var i = 0; i < 4; i++) s += ("0000000" + Math.floor(Math.random() * 4294967296).toString(16)).slice(-8)
    return s
  }
  // What a read printed: { path: text }, only for the frames with its mark,
  // and only paths `wanted` says it may hold.
  function parseFrames(output, mark, wanted) {
    var out = {}
    var head = "\u001e" + mark + "\u001f"
    String(output || "").split(head).forEach(function(frame, i) {
      if (i === 0) return
      var cut = frame.indexOf("\u001f")
      if (cut <= 0) return
      var path = frame.slice(0, cut)
      if (wanted(path)) out[path] = frame.slice(cut + 1)
    })
    return out
  }

  // done({ path: text }, ok, failed): ok, the read went through (a file not
  // in it isn't there); `failed`, the paths there that couldn't be read (a
  // link, too big, unreadable: not "not there"). In the notes folder, by the
  // files helper (notesAsk); else, or when it doesn't answer, as before.
  function readFiles(paths, done, maxBytes) {
    if (paths.length === 0) { done({}, true, []); return }
    var h = notesHelperFor(paths[0])
    var rels = h ? paths.map(function(p) { return store.notesRel(h, p) }) : []
    if (h && rels.every(function(r) { return r !== "" })) {
      notesAsk(h, { op: "read", paths: rels, max: maxBytes || 32 * 1024 * 1024, total: maxBytes || 32 * 1024 * 1024 }, function(r) {
        if (r === null) { store.readFilesAsBefore(paths, done, maxBytes); return }
        var got = store.notesGot(h, r)
        done(got.files, r.ok === true, got.failed)
      })
      return
    }
    readFilesAsBefore(paths, done, maxBytes)
  }
  function readFilesAsBefore(paths, done, maxBytes) {
    var mark = readMark()
    var asked = {}
    paths.forEach(function(p) { asked[p] = true })
    exec(["/usr/bin/bash", "-c", readScript, "uber-notebook-read", mark].concat(paths), function(ok, output) {
      done(ok ? parseFrames(output, mark, function(p) { return asked[p] === true }) : {}, ok, ok ? [] : paths.slice())
    }, { maxBytes: maxBytes || 32 * 1024 * 1024, timeoutMs: 20000 })
  }

  // The files a pattern finds in dir ("*.json", "*/notebook.json"), read:
  // done({ path: text }, ok, failed), as readFiles.
  function readGlob(dir, pattern, done, maxBytes) {
    var h = notesHelperFor(dir + "/x")
    var rel = h ? (dir === h.root ? "" : store.notesRel(h, dir)) : ""
    if (h && (rel !== "" || dir === h.root) && /^\*(\/[^\/*]+|[^\/*]*)$/.test(pattern)) {
      notesAsk(h, { op: "find", dir: rel, pattern: pattern, max: maxBytes || 64 * 1024 * 1024, total: maxBytes || 64 * 1024 * 1024 }, function(r) {
        if (r === null) { store.readGlobAsBefore(dir, pattern, done, maxBytes); return }
        var got = store.notesGot(h, r)
        done(got.files, r.ok === true, got.failed)
      })
      return
    }
    readGlobAsBefore(dir, pattern, done, maxBytes)
  }
  function readGlobAsBefore(dir, pattern, done, maxBytes) {
    var mark = readMark()
    exec(["/usr/bin/bash", "-c", globScript, "uber-notebook-read", mark, dir, pattern], function(ok, output) {
      done(ok ? parseFrames(output, mark, function(p) { return p.indexOf(dir + "/") === 0 }) : {}, ok, [])
    }, { maxBytes: maxBytes || 64 * 1024 * 1024, timeoutMs: 30000 })
  }

  // ---- your notes, by the files helper ------------------------------------------------------
  //
  // The files in your notes folder are read and written by the files helper,
  // kept running for that folder (bin/uber-notebook-files serve): every path
  // below the folder walked without following a link, to a plain file only,
  // read within its size, written as a new file put in its place. Only when
  // it doesn't answer (it can't start, it stopped, it's stuck) is a file read
  // or written as before, by bash and Qt; what it refuses stays refused. As
  // the shell stops, writes are Qt's (they finish before it does).
  // `notes`: { root, run, waiting: { id: done }, sent: { id: time }, next, dead }.
  property var notes: null
  property int notesFailures: 0
  // The notes folder known to be there (locate made it): the helper's only for it.
  property string notesRoot: ""

  // The helper for a path in the notes folder in use (started as needed:
  // the last folder's, after a change, answers what it was asked, then
  // ends), or null.
  function notesHelperFor(path) {
    var p = String(path || "")
    if (notes && !notes.dead && p.indexOf(notes.root + "/") === 0) return notes
    if (!rootPath || rootPath !== notesRoot || p.indexOf(rootPath + "/") !== 0 || stopping || notesFailures >= 3) return null
    if (notes && !notes.dead) notes.run.closeInput()
    notes = startNotes(rootPath)
    return notes.dead ? null : notes
  }
  // Whether the files helper reads and writes that path (in the notes folder, now).
  function servesNotes(path) {
    var h = notesHelperFor(path)
    return h !== null && notesRel(h, path) !== ""
  }
  function notesRel(h, path) {
    var p = String(path || "")
    if (p.indexOf(h.root + "/") !== 0) return ""
    var rel = p.slice(h.root.length + 1)
    return rel && !/(^|\/)\.\.?(\/|$)/.test(rel) && !/\/\//.test(rel) && !/[\u0000-\u001f]/.test(rel) ? rel : ""
  }
  function startNotes(root) {
    var h = { root: root, run: null, waiting: {}, sent: {}, next: 1, dead: false }
    h.run = stream(["/usr/bin/python3", "-I", "-S", filesHelper, "serve", root], function(line) {
      var r = store.parseJson(line)
      if (!r || !Object.prototype.hasOwnProperty.call(h.waiting, r.id)) return
      var w = h.waiting[r.id]
      delete h.waiting[r.id]
      delete h.sent[r.id]
      w(r)
    }, function(code, errors) {
      h.dead = true
      if (store.notes === h) store.notes = null
      if (code !== 0 && code !== -1) {
        store.notesFailures++
        console.warn("Uber Notebook: the files helper stopped (" + code + "): " + String(errors || "").slice(0, 300))
      }
      var left = h.waiting
      h.waiting = {}
      h.sent = {}
      for (var k in left) left[k](null)
    }, { input: true, timeoutMs: 7 * 24 * 3600 * 1000, maxBytes: 1e15, maxLine: 1024 * 1024 * 1024 })
    return h
  }
  // Asks it: done(its answer), or done(null) when it doesn't answer.
  function notesAsk(h, req, done) {
    if (!h || h.dead) { done(null); return }
    req.id = h.next++
    h.waiting[req.id] = done
    h.sent[req.id] = Date.now()
    h.run.send(JSON.stringify(req) + "\n")
  }
  // Its answer to a read, as readFiles gives it: { files: { path: text }, failed }.
  function notesGot(h, r) {
    var files = {}
    var failed = []
    if (r.ok) {
      for (var k in r.files) files[h.root + "/" + k] = r.files[k]
      for (var e in r.errors) failed.push(h.root + "/" + e)
    }
    return { files: files, failed: failed }
  }
  // (One that's stuck: what it was asked goes on as before, and it's ended.)
  Timer {
    interval: 5000
    repeat: true
    running: store.notes !== null
    onTriggered: {
      var h = store.notes
      if (!h || h.dead) return
      var now = Date.now()
      for (var id in h.sent) {
        if (now - h.sent[id] > 60000) { console.warn("Uber Notebook: the files helper isn't answering: started again"); h.run.stop(); return }
      }
    }
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

  // The models an agent can work with, and the efforts each takes
  // (Agent.models): Grok's and Codex's from the lists they keep, Claude
  // Code's from its own names for them. done([...]).
  function agentModels(agent, done) {
    var codexHome = Quickshell.env("CODEX_HOME") || home + "/.codex"
    var file = agent === "grok" ? home + "/.grok/models_cache.json" : agent === "codex" ? codexHome + "/models_cache.json" : ""
    done(Agent.models(agent, file ? readNow(file, 4 * 1024 * 1024) || "" : ""))
  }

  // Omarchy launches it, in its own terminal, starting with the prompt;
  // nothing here waits for it.
  function launchAgent(prompt) {
    Quickshell.execDetached(["/usr/bin/omarchy-agent-prompt", String(prompt)])
  }

  // The agents Omarchy offers (its menu file says which, and what each is
  // called) that are installed here: done([{ name, label, path }]). Each is
  // found on the shell's PATH and checked (Agent.AGENTS_SCRIPT), and run by
  // that full path, never looked up again.
  readonly property string omarchyPath: "/usr/share/omarchy"
  property var agentPaths: ({})
  function findAgents(names, done) {
    var list = (names || []).filter(function(n) { return /^[a-z][a-z0-9-]{0,30}$/.test(n) })
    if (list.length === 0) { done({}); return }
    exec(["/usr/bin/bash", "-c", Agent.AGENTS_SCRIPT, "uber-notebook-agents", String(Quickshell.env("PATH") || "")].concat(list), function(ok, output) {
      var found = ok ? Agent.agentPaths(output) : {}
      var all = {}
      for (var k in store.agentPaths) all[k] = store.agentPaths[k]
      list.forEach(function(n) { if (found[n]) all[n] = found[n]; else delete all[n] })
      store.agentPaths = all
      done(found)
    }, { timeoutMs: 4000, maxBytes: 65536 })
  }
  function listAgents(done) {
    var all = Agent.menuAgents(readNow(omarchyPath + "/default/omarchy/omarchy-menu.jsonc", 1024 * 1024) || "")
    if (all.length === 0) { done([]); return }
    findAgents(all.map(function(a) { return a.name }), function(found) {
      done(all.filter(function(a) { return !!found[a.name] }).map(function(a) { return { name: a.name, label: a.label, path: found[a.name] } }))
    })
  }
  // An agent's program, found and checked now: done(full path) or done("").
  function agentPath(name, done) {
    findAgents([name], function(found) { done(found[name] || "") })
  }

  // Your agent made Omarchy's default: the file `omarchy default agent`
  // writes, without launching the agent as that command does. done(ok).
  function setDefaultAgent(name, done) {
    if (!/^[a-z][a-z0-9-]{0,30}$/.test(String(name || ""))) { done(false); return }
    var dir = home + "/.config/omarchy/defaults"
    mkdirs([dir], function(ok) {
      if (!ok) { done(false); return }
      writeFile(dir + "/agent", name + "\n", done)
    })
  }

  // Omarchy's menu for choosing the default agent.
  function pickAgent() {
    Quickshell.execDetached(["/usr/bin/omarchy-menu", "summon", "setup.default.agent"])
  }

  // The uber-notebook skill, linked into the folders agents read skills from (the
  // ones Omarchy links its own skills into), so whichever agent you use knows
  // Uber Notebook's commands. A link is only made where nothing has that name,
  // and only Uber Notebook's own links (to `target`) are taken out.
  readonly property var skillFolders: [".agents/skills", ".claude/skills", ".codex/skills", ".hermes/skills", ".pi/agent/skills"]
  readonly property string skillScript: "mode=$1; target=$2; shift 2; for dir in \"$@\"; do link=\"$dir/uber-notebook\"; "
    + "if [ \"$mode\" = link ]; then if [ -d \"$dir\" ] && [ ! -e \"$link\" ] && [ ! -L \"$link\" ]; then /usr/bin/ln -sT -- \"$target\" \"$link\"; fi; "
    + "elif [ -L \"$link\" ] && [ \"$(/usr/bin/readlink -- \"$link\")\" = \"$target\" ]; then /usr/bin/rm -f -- \"$link\"; fi; done; exit 0"

  function skillDirs() { return skillFolders.map(function(f) { return store.home + "/" + f }) }
  function linkSkill(target) {
    exec(["/usr/bin/bash", "-c", skillScript, "uber-notebook-skills", "link", target].concat(skillDirs()), null, { timeoutMs: 5000 })
  }
  // (Each link taken out only if it's still Uber Notebook's: read where it's
  // kept, then taken out there; by the archive helper, as Uber Notebook stops.)
  function unlinkSkill(target) {
    skillDirs().forEach(function(dir) {
      Quickshell.execDetached(["/usr/bin/python3", "-I", "-S", filesHelper, "unlink-link", dir + "/uber-notebook", target])
    })
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
      // The newest text is what's written next; everyone waiting on an
      // earlier one hears when that write (which has theirs in it) is done.
      var q = queued[path] || { text: "", waiters: [] }
      q.text = text
      if (done) q.waiters.push(done)
      queued[path] = q
      return
    }
    writeNow(path, text, done ? [done] : [])
  }
  function writeNow(path, text, waiters) {
    writing[path] = true
    var view = null
    function finish(ok, error) {
      delete writing[path]
      if (view) view.destroy()
      if (!ok) failed("Couldn't save " + path.replace(home, "~") + (error ? ": " + error : ""))
      waiters.forEach(function(w) {
        try { w(ok) } catch (e) { console.warn("Uber Notebook: after saving " + path + ": " + e) }
      })
      var next = queued[path]
      if (next) {
        delete queued[path]
        writeNow(path, next.text, next.waiters)
      }
    }
    function asBefore() {
      view = writerComponent.createObject(store, { path: path, blockWrites: stopping })
      view.saved.connect(function() { finish(true, "") })
      view.saveFailed.connect(function(error) { finish(false, String(error)) })
      view.setText(text)
    }
    // (In the notes folder, by the files helper; as before when it doesn't
    // answer, or as the shell stops.)
    var h = stopping ? null : notesHelperFor(path)
    var rel = h ? notesRel(h, path) : ""
    if (!rel) { asBefore(); return }
    notesAsk(h, { op: "write", path: rel, text: String(text) }, function(r) {
      if (r === null) { asBefore(); return }
      finish(r.ok === true, r.ok ? "" : String(r.error || ""))
    })
  }

  function mkdirs(paths, done) {
    // (In the notes folder, by the files helper; else, or when it doesn't answer, as before.)
    var h = paths.length ? notesHelperFor(paths[0] + "/x") : null
    var rels = h ? paths.map(function(p) { return store.notesRel(h, p) }) : []
    if (h && rels.every(function(r) { return r !== "" })) {
      var left = rels.length
      var allOk = true
      var why = ""
      var fellBack = false
      rels.forEach(function(rel) {
        notesAsk(h, { op: "mkdir", path: rel }, function(r) {
          if (r === null) fellBack = true
          else if (!r.ok) { allOk = false; why = why || String(r.error || "") }
          if (--left > 0) return
          if (fellBack) { store.mkdirsAsBefore(paths, done); return }
          if (!allOk) failed("Couldn't make " + paths[0].replace(home, "~") + ": " + why)
          if (done) done(allOk)
        })
      })
      return
    }
    mkdirsAsBefore(paths, done)
  }
  function mkdirsAsBefore(paths, done) {
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
    if (!home || !active) return
    ready = false
    var gen = ++generation
    exec(["/usr/bin/test", "-d", home + "/Documents"], function(ok) {
      if (gen !== store.generation) return
      var next = Settings.resolveFolder(store.folder, store.home, ok)
      if (store.rootPath && next !== store.rootPath) store.leaveRoot()
      store.rootPath = next
      store.mkdirs([store.rootPath], function(made) {
        if (!made || gen !== store.generation) return
        store.notesRoot = store.rootPath
        store.loadLibrary()
      })
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
        if (store.order.length === 0 && !store.welcomed && store.welcome) {
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
    changed()
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
    readGlob(Library.pagesDir(rootPath, id), "*.json", function(files, read, failed) {
      // (A read that didn't go through isn't an empty notebook: nothing's
      // made or changed from it.)
      if (!read) { store.failed("Couldn't read that notebook's pages"); done(null); return }
      // (A page that couldn't be read keeps its place, shown or not: said.)
      var unread = (failed || []).map(function(p) { return p.slice(p.lastIndexOf("/") + 1, p.length - 5) }).filter(Library.isId)
      if (unread.length) store.failed("Couldn't read " + unread.length + " of that notebook's pages: left as they are")
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
      var ids = Library.reconcilePages(nb.pages, onDisk.concat(unread))
      var pages = ids.filter(function(pid) { return byId[pid] }).map(function(pid) { return byId[pid] })
      if (pages.length === 0 && unread.length) { done(null); return }
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
    changed()
  }

  // The shelf's notebooks, for the Markdown copy: [{ id, title, modified }].
  function notebookList() {
    return order.filter(function(id) { return index[id] }).map(function(id) { return { id: id, title: index[id].title, modified: index[id].modified } })
  }

  // A notebook's pages in order, read and nothing else (no page made for an
  // empty notebook, no order put right): done([page]).
  function notebookPages(id, done) {
    var nb = index[id]
    if (!nb) { done([]); return }
    readGlob(Library.pagesDir(rootPath, id), "*.json", function(files) {
      var byId = {}
      for (var path in files) {
        var pid = path.slice(path.lastIndexOf("/") + 1, path.length - 5)
        var page = Library.cleanPage(parseJson(files[path]), pid)
        if (page) byId[pid] = page
      }
      var mine = store.written[id] || {}
      for (var wid in mine) byId[wid] = JSON.parse(JSON.stringify(mine[wid]))
      var ids = Library.reconcilePages(nb.pages, Object.keys(byId))
      done(ids.map(function(pid) { return byId[pid] }).filter(function(p) { return !!p }))
    })
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
      title: "Welcome to Uber Notebook",
      blocks: [
        { type: "p", html: "This is your notebook. Everything you write is <span style=\"font-weight:700;\">saved as you go</span>, as plain files in " + Html.escapeText(rootPath.replace(home, "~")) + "." },
        { type: "h2", html: "Things to try" },
        tip("Type <span style=\"font-weight:700;\">- </span> and a space for a list, <span style=\"font-weight:700;\">[] </span> for a checkbox, <span style=\"font-weight:700;\"># </span> for a heading"),
        tip("Select a few words and press <span style=\"font-weight:700;\">Ctrl+B</span>, or pick an ink and a <span style=\"background-color:#fff27a;\">highlighter</span> below"),
        tip("Tick this box with a click, or with Ctrl+Enter"),
        tip("Turn the page with Ctrl+PgDown, or click the page's bottom corner"),
        tip("Paste or drop a picture onto the page"),
        tip("Give a page an index tab: \u22ef, then Add a tab"),
        { type: "callout", tone: "yellow", html: "<span style=\"font-weight:700;\">Super+N</span> opens and closes Uber Notebook from anywhere. <span style=\"font-weight:700;\">Super+Alt+N</span> jots a quick note." },
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
  // Its file, a full path ("" for none).
  function assetPath(id, src) {
    if (!Library.isId(id) || !Blocks.cleanAsset(src)) return ""
    return rootPath + "/" + id + "/" + src
  }

  // Copies a picture into the notebook: done("assets/<name>") or done("").
  function importPicture(id, path, done) {
    if (!index[id] || !Library.isImagePath(path)) { done(""); return }
    var name = Library.assetName(path, new Date())
    var dest = Library.assetsDir(rootPath, id)
    mkdirs([dest], function(ok) {
      if (!ok) { done(""); return }
      store.copyPictureIn(path, dest, name, function(copied, why) {
        if (!copied) store.failed("Couldn't copy the picture: " + why)
        done(copied ? "assets/" + name : "")
      })
    })
  }

  // A picture copied in (bin/uber-notebook-files copy-picture): only a plain
  // file that's a picture Qt can show (at most pictureMax bytes, 16384 px a
  // side), as a new file in `folder` named `name`, never over one; with
  // `within` (an agent's folder), only a picture in it, through no link.
  // done(ok, why). A few at a time (a gallery of 200 waits its turn).
  readonly property real pictureMax: 50 * 1024 * 1024
  property var pictureQueue: []
  property int picturesCopying: 0
  function copyPictureIn(from, folder, name, done, within) {
    pictureQueue = pictureQueue.concat([{ from: String(from), folder: String(folder), name: String(name), done: done, within: String(within || "") }])
    nextPicture()
  }
  function nextPicture() {
    while (picturesCopying < 3 && pictureQueue.length) {
      var c = pictureQueue[0]
      pictureQueue = pictureQueue.slice(1)
      picturesCopying++
      helper(["copy-picture", c.from, c.folder, c.name, String(pictureMax)].concat(c.within ? [c.within] : []), function(ok, out) {
        store.picturesCopying--
        var r = store.parseJson(String(out || "").trim().split("\n").pop())
        var copied = ok && !!r && r.ok === true
        try { if (c.done) c.done(copied, copied ? "" : r && r.error ? String(r.error) : "it couldn't be read") }
        finally { store.nextPicture() }
      }, { timeoutMs: 60000, maxBytes: 4096 })
    }
  }

  // A picture on the clipboard, saved into the notebook: done(src) or done("").
  function pastePicture(id, done) {
    if (!index[id]) { done(""); return }
    pasteInto(Library.assetsDir(rootPath, id), done)
  }

  function isImagePath(path) { return Library.isImagePath(path) }
  function assetName(path) { return Library.assetName(path, new Date()) }

  // A picture on the clipboard, at most PASTE_MAX bytes, saved into a folder
  // of pictures (a notebook's or Pages'): done("assets/<name>") or done("").
  // It's written to a new file of its own (never through a name that's
  // there), then named once it's whole and small enough.
  readonly property real pasteMax: 50 * 1024 * 1024
  readonly property string pasteScript: "set -C -o pipefail; t=\"$2.part-$RANDOM$RANDOM\"; exec 3> \"$t\" || exit 1; "
    + "if ! /usr/bin/wl-paste --no-newline --type \"$1\" | /usr/bin/head -c \"$(($3 + 1))\" >&3; then exec 3>&-; /usr/bin/rm -f -- \"$t\"; exit 1; fi; exec 3>&-; "
    + "n=$(/usr/bin/stat -c %s -- \"$t\") || { /usr/bin/rm -f -- \"$t\"; exit 1; }; "
    + "if [ \"$n\" -eq 0 ] || [ \"$n\" -gt \"$3\" ]; then /usr/bin/rm -f -- \"$t\"; echo 'too big' >&2; exit 1; fi; "
    + "/usr/bin/mv --update=none-fail -T -- \"$t\" \"$2\" || { /usr/bin/rm -f -- \"$t\"; exit 1; }"
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
        store.exec(["/usr/bin/bash", "-c", store.pasteScript, "uber-notebook-paste", pick, dest + "/" + name, String(store.pasteMax)], function(pasted) {
          done(pasted ? "assets/" + name : "")
        }, { timeoutMs: 15000 })
      })
    }, { okCodes: [0, 1], timeoutMs: 3000 })
  }

  // What's on the clipboard (or, with `primary`, what's selected: a middle
  // click's paste), to paste: done({ html, text }) (each "" when it isn't
  // there, at most 4 MB) or done(null) when there's no text at all (a
  // picture: pastePicture). Read by wl-paste, so the editor gets HTML to
  // clean before Qt reads it (Editor.qml: withClipboard).
  readonly property real clipboardMax: 4 * 1024 * 1024
  function readClipboard(done, primary) {
    var which = primary === true ? ["--primary"] : []
    exec(["/usr/bin/wl-paste"].concat(which, ["--list-types"]), function(ok, output) {
      var types = ok ? String(output || "").split("\n").map(function(t) { return t.trim() }) : []
      var html = types.indexOf("text/html") >= 0 ? "text/html" : ""
      var text = ["text/plain;charset=utf-8", "text/plain", "UTF8_STRING", "STRING", "TEXT"].filter(function(t) { return types.indexOf(t) >= 0 })[0] || ""
      if (!html && !text) { done(null); return }
      function readText(htmlText) {
        if (!text) { done({ html: htmlText, text: "" }); return }
        store.exec(["/usr/bin/wl-paste"].concat(which, ["--no-newline", "--type", text]), function(ok2, out2) {
          done({ html: htmlText, text: ok2 ? String(out2 || "") : "" })
        }, { timeoutMs: 5000, maxBytes: store.clipboardMax })
      }
      if (!html) { readText(""); return }
      store.exec(["/usr/bin/wl-paste"].concat(which, ["--no-newline", "--type", html]), function(ok1, out1) {
        // (HTML that isn't UTF-8, or too much of it: its text instead.)
        var h = ok1 ? String(out1 || "") : ""
        readText(h.indexOf("\u0000") >= 0 ? "" : h)
      }, { timeoutMs: 5000, maxBytes: store.clipboardMax })
    }, { okCodes: [0, 1], timeoutMs: 3000, maxBytes: 64 * 1024 })
  }

  // ---- out of Uber Notebook -----------------------------------------------------------------------

  // Text onto the clipboard, given to wl-copy on its stdin (never as an
  // argument, which anyone on the computer could read while it's held).
  function copyText(text) {
    var value = String(text || "")
    if (!value || value.length > 1000000) return
    exec(["/usr/bin/wl-copy"], function() {}, { input: value, keepChildren: true, timeoutMs: 10000 })
  }

  // A picture onto the clipboard, to paste anywhere: as it is (a PNG, a GIF,
  // an SVG), or a JPEG, WebP or BMP as a PNG (what more apps take), made by
  // ffmpeg when it's here. wl-copy stays on to hand it over, so its output
  // goes nowhere (not to the runner, which would wait for it). done(ok).
  readonly property string copyPictureScript: "set -o pipefail; case \"$1\" in image/jpeg|image/webp|image/bmp) [ -x /usr/bin/ffmpeg ] && /usr/bin/ffmpeg -nostdin -v error -protocol_whitelist file -format_whitelist image2,jpeg_pipe,webp_pipe,bmp_pipe -i \"$2\" -frames:v 1 -c:v png -f image2pipe - | /usr/bin/wl-copy --type image/png >/dev/null 2>&1 && exit 0 ;; esac; /usr/bin/wl-copy --type \"$1\" < \"$2\" >/dev/null 2>&1"
  function copyPicture(path, done) {
    var type = Library.pictureType(path)
    if (!type || String(path || "").charAt(0) !== "/") { if (done) done(false); return }
    exec(["/usr/bin/bash", "-c", copyPictureScript, "uber-notebook-copy-picture", type, path], function(ok) { if (done) done(ok) }, { timeoutMs: 20000, keepChildren: true })
  }

  // A picture made here (a diagram or an equation, grabbed) written to
  // `path` (a PNG, or as its ending says): true when it is.
  function saveGrab(result, path) { return !!result && result.saveToFile(path) }
  // A file for a moment (a picture on its way to the clipboard), where only
  // you can read it.
  function tempPath(name) { return runtimeDir + "/uber-notebook-" + name }

  // A copy of a file at `to` (a picture saved where you said): done(ok, why).
  function copyFileTo(from, to, done) {
    exec(["/usr/bin/cp", "--", from, to], function(ok, output) { if (done) done(ok, String(output || "").trim()) }, { timeoutMs: 30000 })
  }

  // A link from a page, a release's notes or an email: only to the web or
  // an email address (a link in a page can't open a file on this computer).
  function openUrl(url) {
    var u = String(url || "")
    if (!/^(https?:\/\/|mailto:)/i.test(u) || u.length > 8000 || /[\u0000-\u001f\u007f]/.test(u)) return
    Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", u])
  }

  // A folder or file of Uber Notebook's own, by its full path (a profile's
  // folder, the backups folder, a notebook's picture): never from a page.
  function openLocal(path) {
    var p = String(path || "")
    if (p.charAt(0) !== "/" || p.length > 4000 || /[\u0000-\u001f\u007f]/.test(p) || /(^|\/)\.\.(\/|$)/.test(p)) return
    Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", p])
  }

  // A file in its app, as the desktop says: done(true), or done(false, why)
  // when there's no app for it ("none") or only a web browser ("browser":
  // it would download it, and take you away from here).
  readonly property string appScript: "t=$(/usr/bin/xdg-mime query filetype \"$1\" 2>/dev/null); d=$(/usr/bin/xdg-mime query default \"$t\" 2>/dev/null); printf '%s\\n%s\\n' \"$t\" \"$d\""
  readonly property var browsers: /(^|[-.])(google-chrome|chrome|chromium|firefox|brave|vivaldi|opera|microsoft-edge|zen|librewolf|epiphany|qutebrowser|falkon|midori)/i
  function openFile(path, done) {
    exec(["/usr/bin/bash", "-c", appScript, "uber-notebook-app", path], function(ok, out) {
      var app = String(out || "").split("\n")[1] || ""
      app = app.trim()
      if (!app) { if (done) done(false, "none"); return }
      if (store.browsers.test(app)) { if (done) done(false, "browser"); return }
      Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", path])
      if (done) done(true, app)
    }, { timeoutMs: 5000, maxBytes: 4096 })
  }

  // A PDF made to print, in your PDF viewer (or whatever opens PDFs, a
  // browser too: it prints them): only one in the print folder.
  function openPrint(path, done) {
    var dir = runtimeDir + "/uber-notebook-print/"
    var p = String(path || "")
    if (p.indexOf(dir) !== 0 || p.slice(dir.length).indexOf("/") >= 0 || !/\.pdf$/.test(p)) { if (done) done(false); return }
    exec(["/usr/bin/bash", "-c", appScript, "uber-notebook-app", p], function(ok, out) {
      var app = (String(out || "").split("\n")[1] || "").trim()
      if (!app) { if (done) done(false); return }
      Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", p])
      if (done) done(true)
    }, { timeoutMs: 5000, maxBytes: 4096 })
  }

  function openFolder() {
    if (rootPath) Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", rootPath])
  }

  // An Omarchy notification (a reminder, an event's alert); clicking it
  // opens the page (or the calendar, on `day`).
  function notify(title, text, pageId, day) {
    // Texts starting with "-" would be read as options.
    var head = String(title || "Reminder").replace(/^-+/, "\u2010").slice(0, 120)
    var body = String(text || "").replace(/^-+/, "\u2010").slice(0, 300)
    var argv = ["/usr/bin/omarchy-notification-send", "-g", "\u{f009e}", "-u", "normal", "--app-name", "Uber Notebook", head, body]
    if (/^[0-9a-f-]{36}$/.test(String(pageId || ""))) argv = argv.concat(["--exec", "/usr/bin/omarchy-shell", "uber-notebook", "open", pageId])
    else if (/^\d{4}-\d{2}-\d{2}$/.test(String(day || ""))) argv = argv.concat(["--exec", "/usr/bin/omarchy-shell", "uber-notebook", "calendar", day])
    Quickshell.execDetached(argv)
  }

  // A folder Uber Notebook made (an export), in the file manager.
  function openPath(path) {
    if (path && path.indexOf(rootPath + "/") === 0) Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", path])
  }

  // Every page as a Markdown file, and its pictures, in a folder beside the
  // notebooks: "<notebooks>/Exports/<title> <date>/".
  // Where an export goes: done(folder), or done("") for none (Service.qml
  // asks you, or says the Exports folder, as Settings says).
  property var exportFolder: null

  function exportBase(done) {
    if (typeof exportFolder === "function") exportFolder(done)
    else done(rootPath + "/Exports")
  }

  function exportNotebook(id) {
    exportBase(function(base) { if (base) store.exportNotebookTo(id, base) })
  }

  function exportNotebookTo(id, base) {
    openNotebook(id, function(nb) {
      if (!nb) return
      var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm")
      var name = (nb.title.replace(/[\/\\:*?"<>|\u0000-\u001f]+/g, " ").trim() || "Notebook") + " " + stamp
      var dir = base + "/" + name
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

  // Another folder (another profile): what's waiting is written where it
  // belongs first, then nothing of this one is kept to be read in the next
  // (its pages, by their ids, may be the same: a restored backup's are).
  function leaveRoot() {
    notebookTimer.stop()
    var ids = Object.keys(notebookDirty)
    notebookDirty = ({})
    ids.forEach(function(id) {
      var nb = index[id]
      if (nb && folders[id]) store.writeFile(Library.notebookFile(rootPath, id), Library.stringify(nb))
    })
    written = ({})
    folders = ({})
    waiting = ({})
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
