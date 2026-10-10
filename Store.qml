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
  // Where imports are unpacked and converted for a moment (a tmpfs of your
  // own). Without one (no XDG_RUNTIME_DIR), a folder of Uber Notebook's own in
  // your cache, yours alone (made as it starts), never /tmp, which every
  // account on the computer can look in.
  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR") || cacheDir + "/run"
  // On disk, for what may be big (an import unzipped): the runtime folder is
  // memory, shared with the whole session.
  readonly property string cacheDir: { var c = Quickshell.env("XDG_CACHE_HOME") || ""; return (c.charAt(0) === "/" ? c : home + "/.cache") + "/uber-notebook" }
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
  // (Another profile's folder: switching from now till it's open (or said
  // it can't be). A command that comes right after the switch is told the
  // notes aren't open yet (Api.unready), never done in the profile before;
  // what that one was writing still finishes there.)
  property bool switching: false
  onFolderChanged: {
    welcomed = false
    if (rootPath) { switching = true; ready = false }
    locateTimer.restart()
  }
  onActiveChanged: locateTimer.restart()
  Component.onCompleted: {
    // (No runtime folder from the session: the one in your cache, made
    // yours alone before anything's put in it.)
    if (!Quickshell.env("XDG_RUNTIME_DIR")) exec(privateMkdir([runtimeDir]), function() { store.makePrivate(store.runtimeDir) })
    locateTimer.restart()
  }

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
      extraEnv: o.env && typeof o.env === "object" ? o.env : ({}), maxBytes: o.maxBytes || 64 * 1024 * 1024, maxLine: o.maxLine || 4 * 1024 * 1024,
      maxErrors: o.maxErrors || o.maxBytes || 64 * 1024 * 1024 })
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
  // (Not by the notes' helper: by the files helper, once (read-files): only
  // plain files, within their size, what it prints ASCII, so no character
  // is cut in two on its way here; a file it couldn't read, in `failed`.)
  function readFilesAsBefore(paths, done, maxBytes) {
    var max = maxBytes || 32 * 1024 * 1024
    var asked = {}
    paths.forEach(function(p) { asked[p] = true })
    helper(["read-files", String(max), String(max)], function(ok, output) {
      var r = ok ? store.parseJson(String(output || "").trim().split("\n").pop()) : null
      if (!r || r.ok !== true) { done({}, false, paths.slice()); return }
      var files = {}
      for (var p in r.files) if (asked[p] === true) files[p] = r.files[p]
      done(files, true, Object.keys(r.errors || {}).filter(function(e) { return asked[e] === true }))
    }, { input: JSON.stringify(paths), maxBytes: 3 * max + 1024 * 1024, timeoutMs: 30000 })
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
    var max = maxBytes || 64 * 1024 * 1024
    helper(["read-glob", dir, pattern, String(max), String(max)], function(ok, output) {
      var r = ok ? store.parseJson(String(output || "").trim().split("\n").pop()) : null
      if (!r || r.ok !== true) { done({}, false, []); return }
      var files = {}
      for (var p in r.files) if (p.indexOf(dir + "/") === 0) files[p] = r.files[p]
      done(files, true, Object.keys(r.errors || {}).filter(function(e) { return e.indexOf(dir + "/") === 0 }))
    }, { maxBytes: 3 * max + 1024 * 1024, timeoutMs: 30000 })
  }

  // A file of Uber Notebook's own in a folder of its own (an agent's sandbox
  // profile), by the files helper (put): never through a link planted there.
  // done(ok).
  // (`copy`: the Markdown copy's folder, which may be a link to where you
  // keep it; never an agent's.)
  function putFile(folder, path, text, done, copy) {
    helper([copy ? "put-copy" : "put", folder, path], function(ok, out) { if (done) done(ok && String(out || "").trim() === "put", ok ? "" : String(out || "").trim().split("\n").pop()) }, { input: String(text), timeoutMs: 10000, maxBytes: 4096 })
  }

  // A command whose words come back as text that may be long, and in any
  // script (a transcript, a list of files): through the files helper's
  // to-json, so it arrives ASCII (Quickshell reads output a piece at a time,
  // each piece decoded alone: a character cut in two between pieces would
  // come out wrong). done(ok, text), as exec. Its options as exec's, its
  // maxBytes what it may print.
  function execText(argv, done, options) {
    var o = {}
    for (var k in (options || {})) o[k] = options[k]
    var max = o.maxBytes || 256 * 1024
    o.maxBytes = 6 * max + 1024
    exec(["/usr/bin/bash", "-c", "h=$1; n=$2; shift 2; set -o pipefail; \"$@\" | /usr/bin/python3 -I -S \"$h\" to-json \"$n\"", "uber-notebook-text", filesHelper, String(Math.round(max))].concat(argv), function(ok, out) {
      var t = store.parseJson(String(out || "").trim())
      if (typeof t === "string") { done(ok, t); return }
      done(false, ok ? "it printed more than it may" : String(out || ""))
    }, o)
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
    }, { input: true, timeoutMs: 7 * 24 * 3600 * 1000, maxBytes: 1e15, maxLine: 3 * 64 * 1024 * 1024 + 16 * 1024 * 1024 })
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

  // Omarchy launches it, in its own terminal; nothing here waits for it.
  // Its request (your words, the page's, what was said) is put in a file of
  // its own, yours alone, in Uber Notebook's agent folder (in
  // $XDG_RUNTIME_DIR), and it starts with a line saying to read it: a
  // program's command line is there for every account on the computer to
  // read, as long as it runs. done(ok) once it's launched (or not).
  property var agentLauncher: ["/usr/bin/omarchy-agent-prompt"]
  property string agentRequests: runtimeDir + "/uber-notebook-agent"
  function launchAgent(prompt, done) {
    var dir = agentRequests
    var name = "request-" + Date.now().toString(36) + "-" + Math.floor(Math.random() * 0x7fffffff).toString(36) + ".md"
    mkdirs([dir], function(made) {
      if (!made) { if (done) done(false); return }
      putFile(dir, name, String(prompt), function(ok) {
        if (ok) Quickshell.execDetached(agentLauncher.concat([Agent.requestPointer(dir + "/" + name)]))
        else console.warn("Uber Notebook: the agent's request couldn't be written")
        if (done) done(ok)
      })
    })
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
  // ones Omarchy links its own skills into) once you turn it on, so whichever
  // agent you use knows Uber Notebook's commands. A link is only made where
  // nothing has that name, and only Uber Notebook's own links are taken out
  // (to `target`, or to its skill in another place: an install before).
  readonly property var skillFolders: [".agents/skills", ".claude/skills", ".codex/skills", ".hermes/skills", ".pi/agent/skills"]
  // (Under a lock, `skillLock`, the one taking them out as it stops waits
  // for: a link being made then is made before it's taken out, never after.
  // And one asked for before it stopped but not yet under way does nothing:
  // as it stops, it marks this run (`skillToken`) stopped beside the lock
  // (.stopped-<run>, one for each run), under it, and the script looks for
  // that there, under it too. Each run that links or unlinks says it's the
  // one now (.active), so a run before, as it stops, leaves the links of a
  // later one that hasn't stopped alone.)
  readonly property string skillScript: "mode=$1; target=$2; lock=$3; token=$4; shift 4; { exec 9>>\"$lock\"; } 2>/dev/null && /usr/bin/flock -w 10 9; "
    + "if [ -n \"$token\" ]; then [ -e \"$lock.stopped-$token\" ] && exit 0; "
    + "{ printf '%s\\n' \"$token\" > \"$lock.active\"; } 2>/dev/null; fi; "
    + "for dir in \"$@\"; do link=\"$dir/uber-notebook\"; "
    + "if [ \"$mode\" = link ]; then if [ -d \"$dir\" ] && [ ! -e \"$link\" ] && [ ! -L \"$link\" ]; then /usr/bin/ln -sT -- \"$target\" \"$link\"; "
    // (A link to its skill in another place, gone (an install before, moved
    // away): made to point here. Anything else there is left.)
    + "elif [ -L \"$link\" ] && [ ! -e \"$link\" ]; then case \"$(/usr/bin/readlink -- \"$link\")\" in */marcho78.uber-notebook/skills/uber-notebook) /usr/bin/ln -sfnT -- \"$target\" \"$link\";; esac; fi; "
    + "elif [ -L \"$link\" ]; then case \"$(/usr/bin/readlink -- \"$link\")\" in \"$target\"|*/marcho78.uber-notebook/skills/uber-notebook) /usr/bin/rm -f -- \"$link\";; esac; fi; done; exit 0"

  function skillDirs() { return skillFolders.map(function(f) { return store.home + "/" + f }) }
  // This run's, for the marks beside the lock: when it started (9
  // characters, so a later run's sorts after), then a random part. Made
  // once, as it starts.
  readonly property string skillToken: ("000000000" + Date.now().toString(36)).slice(-9) + (Math.random().toString(36) + "00000000").slice(2, 10)
  property string skillLock: { var r = Quickshell.env("XDG_RUNTIME_DIR"); return (r && r.indexOf("/") === 0 ? r : store.home + "/.cache") + "/uber-notebook-skills.lock" }
  // Linked (`on`), or Uber Notebook's own links taken out: one at a time, the
  // last asked for done last, so turning it on and off quickly ends as it was
  // left.
  property bool skillBusy: false
  property var skillNext: null
  // Uber Notebook stopping (Service.qml, as it goes): never linked again,
  // it's taking them out. (Not `stopping`: the window sets that as it's
  // reloaded, while this goes on running.)
  property bool skillsStopped: false
  function setSkillLinks(on, target) {
    if (skillsStopped && on === true) return
    skillNext = { on: on === true, target: String(target || "") }
    if (skillBusy) return
    var w = skillNext
    skillNext = null
    if (!w.target) return
    skillBusy = true
    exec(["/usr/bin/bash", "-c", skillScript, "uber-notebook-skills", w.on ? "link" : "unlink", w.target, skillLock, skillToken].concat(skillDirs()), function() {
      store.skillBusy = false
      if (store.skillNext) store.setSkillLinks(store.skillNext.on, store.skillNext.target)
    }, { timeoutMs: 5000 })
  }
  // Only as this run stops (it marks the run stopped: nothing it asks for
  // links after). (Each link taken out only if it's still Uber Notebook's:
  // read where it's kept, then taken out there; by the archive helper:
  // `runner`, the helper run from its text, kept as it started, when its
  // folder may be gone by now.)
  function unlinkSkill(target, runner) {
    var run = runner && runner.length ? runner : ["/usr/bin/python3", "-I", "-S", filesHelper]
    skillDirs().forEach(function(dir) {
      Quickshell.execDetached(run.concat(["unlink-link", dir + "/uber-notebook", target, skillLock, skillToken]))
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
  // text waiting for it replaces an older one. (`quiet`: a failure isn't
  // said; writeKept's tries again.)
  function writeFile(path, text, done, quiet) {
    if (writing[path]) {
      // The newest text is what's written next; everyone waiting on an
      // earlier one hears when that write (which has theirs in it) is done.
      var q = queued[path] || { text: "", waiters: [], quiet: true }
      q.text = text
      q.quiet = q.quiet && !!quiet
      if (done) q.waiters.push(done)
      queued[path] = q
      return
    }
    writeNow(path, text, done ? [done] : [], !!quiet)
  }
  function writeNow(path, text, waiters, quiet) {
    writing[path] = true
    var view = null
    function finish(ok, error) {
      delete writing[path]
      if (view) view.destroy()
      if (!ok && !quiet) failed("Couldn't save " + path.replace(home, "~") + (error ? ": " + error : ""))
      waiters.forEach(function(w) {
        try { w(ok) } catch (e) { console.warn("Uber Notebook: after saving " + path + ": " + e) }
      })
      var next = queued[path]
      if (next) {
        delete queued[path]
        writeNow(path, next.text, next.waiters, next.quiet)
      }
      if (store.trashLater.length) store.trashLaterNow()
    }
    function asBefore() {
      view = writerComponent.createObject(store, { path: path, blockWrites: stopping })
      view.saved.connect(function() {
        // (Yours alone, as everything Uber Notebook writes: Qt makes a new
        // file readable by others. As the shell stops, nothing more runs;
        // what's written then is in a folder that's yours alone.)
        if (!stopping) exec(["/usr/bin/chmod", "go-rwx", "--", path], null, { okCodes: [0, 1] })
        finish(true, "")
      })
      view.saveFailed.connect(function(error) { finish(false, String(error)) })
      view.setText(text)
    }
    // (In the notes folder, by the files helper; as before when it doesn't
    // answer, or as the shell stops.)
    var h = stopping ? null : notesHelperFor(path)
    var rel = h ? notesRel(h, path) : ""
    // (Anywhere else, a file you chose, an export, one of its own: by the
    // files helper too, a new file yours alone put in its place, never one
    // left readable by others with your words in it.)
    if (!rel && !stopping && /^\/./.test(path)) {
      helperSave(path, text, function(ok, out) {
        finish(ok, ok ? "" : String(out || "").trim().split("\n").pop())
        if (ok && /^open$/m.test(String(out || ""))) store.failed(store.openDriveNote(path))
      })
      return
    }
    if (!rel) { asBefore(); return }
    notesAsk(h, { op: "write", path: rel, text: String(text) }, function(r) {
      if (r === null) { asBefore(); return }
      finish(r.ok === true, r.ok ? "" : String(r.error || ""))
    })
  }
  // Saves by the files helper outside the notes folder, a few at a time
  // (each is a program of its own: an export of hundreds of pages never
  // starts hundreds at once); the rest wait their turn, in order, and each
  // is heard when it's done. done(ok, output).
  property var saveQueue: []
  property int savesRunning: 0
  readonly property int maxSaves: 4
  function helperSave(path, text, done) {
    saveQueue = saveQueue.concat([{ path: path, text: String(text), done: done }])
    nextSaves()
  }
  function nextSaves() {
    while (savesRunning < maxSaves && saveQueue.length) {
      var s = saveQueue[0]
      saveQueue = saveQueue.slice(1)
      startSave(s)
    }
  }
  function startSave(s) {
    savesRunning++
    helper(["save", s.path], function(ok, out) {
      store.savesRunning--
      try { s.done(ok, out) } finally { store.nextSaves() }
    }, { input: s.text, timeoutMs: 60000, maxBytes: 8192 })
  }

  // ---- what couldn't be saved: kept, and tried again --------------------------------------------

  // Your notes' own files (pages, Pages' tree, People, the calendar,
  // conversations with agents, notebooks) are written with writeKept: one
  // that fails (a full disk, say) is kept, its newest text for each file,
  // and tried again every 30 s, before another folder is opened, and as the
  // window closes: never a temporary or an exported file. Said when it first
  // fails (failed), when it's saved after all (recovered), and if it still
  // isn't as the window closes (Service). An older text's failure never
  // stands for a newer one (each write has a version), and a newer text
  // asked for since is never written over by an older one tried again.
  property var unsaved: ({})
  property var writeVersions: ({})
  property int writeVersion: 0
  property int unsavedCount: 0
  signal recovered(int count)
  function writeKept(path, text, done) {
    var v = ++writeVersion
    writeVersions[path] = v
    // (One that's failing already: not said again with each change.)
    writeFile(path, text, function(ok) {
      // (One that couldn't be saved before, saved now with a newer text:
      // said, as a retry's is.)
      var was = store.unsaved[path] !== undefined
      if (store.writeVersions[path] === v) store.keepUnsaved(path, ok ? null : { text: text, version: v })
      if (ok && was && store.unsaved[path] === undefined) store.recovered(1)
      if (done) done(ok)
    }, unsaved[path] !== undefined)
  }
  function keepUnsaved(path, entry) {
    var next = {}
    for (var k in unsaved) if (k !== path) next[k] = unsaved[k]
    if (entry) next[path] = entry
    unsaved = next
    unsavedCount = Object.keys(next).length
    if (unsavedCount > 0 && !retryTimer.running) retryTimer.start()
    if (unsavedCount === 0) retryTimer.stop()
  }
  Timer { id: retryTimer; interval: 30000; repeat: true; onTriggered: store.retryUnsaved(null) }
  // A file, or a folder and what's in it, gone on purpose: nothing of it
  // kept to be written again (and an older write of it never stands).
  function forgetUnsaved(path) {
    var p = String(path || "").replace(/\/+$/, "")
    if (!p) return
    // (Every write asked for there now out of date, so none of them is
    // kept to be tried again either.)
    Object.keys(writeVersions).forEach(function(k) {
      if (k === p || k.indexOf(p + "/") === 0) store.writeVersions[k] = ++store.writeVersion
    })
    Object.keys(unsaved).forEach(function(k) {
      if (k === p || k.indexOf(p + "/") === 0) store.keepUnsaved(k, null)
    })
  }
  // Each one tried again, quietly: done(how many still aren't saved).
  function retryUnsaved(done) {
    var paths = Object.keys(unsaved)
    if (!paths.length) { if (done) done(0); return }
    var left = paths.length
    var saved = 0
    function next() {
      if (--left > 0) return
      if (saved) store.recovered(saved)
      if (done) done(store.unsavedCount)
    }
    paths.forEach(function(path) {
      var e = store.unsaved[path]
      // (A newer text asked for since: that write is what counts, and says
      // how it went when it's done.)
      if (!e || store.writeVersions[path] !== e.version) { next(); return }
      // (One being written now, or waiting to be: never queued behind it,
      // where it would be written after a newer text; that write says how
      // it went, and if it fails, it's tried again next time.)
      if (store.writing[path] || store.queued[path]) { next(); return }
      store.writeFile(path, e.text, function(ok) {
        if (ok && store.unsaved[path] === e) { store.keepUnsaved(path, null); saved++ }
        next()
      }, true)
    })
  }

  // A folder of Uber Notebook's own (a profile's notes, the backups') made
  // yours alone (700), as one from before was made (755): nothing in it can
  // be reached by another account on the computer, whatever it holds. Never
  // your home folder itself (a profile there: its own files and folders in
  // it, privateEntries). done(ok): checked after, readable by no one else
  // and yours (a drive that can't keep modes, a folder of someone else's,
  // a share that takes every account for the same one, a drive that refuses
  // the change (a phone): not ok; one that's read-only, by its mode).
  readonly property string privateScript: "for p in \"$@\"; do [ -e \"$p\" ] || continue; e=$(LC_ALL=C /usr/bin/chmod go-rwx -- \"$p\" 2>&1) || case $e in *'not permitted'*|*'not supported'*|*'not implemented'*) exit 1 ;; esac; m=$(/usr/bin/stat -L -c %a -- \"$p\") || exit 1; [ $(( 8#$m & 077 )) -eq 0 ] || exit 1; [ \"$(/usr/bin/stat -L -c %u -- \"$p\")\" = \"$UID\" ] || exit 1; done"
  function makePrivate(folder, done) {
    var f = String(folder || "").replace(/\/+$/, "")
    if (!/^\/./.test(f) || f === home) { if (done) done(f === home); return }
    exec(["/usr/bin/bash", "-c", privateScript, "uber-notebook-private", f], function(ok) { if (done) done(ok) }, { okCodes: [0] })
  }
  function privateEntries(root, names, done) {
    var paths = (names || []).filter(function(n) { return /^[^\/]+$/.test(String(n)) && n !== "." && n !== ".." }).map(function(n) { return root + "/" + n })
    if (!paths.length) { if (done) done(true); return }
    exec(["/usr/bin/bash", "-c", privateScript, "uber-notebook-private"].concat(paths), function(ok) { if (done) done(ok) }, { okCodes: [0] })
  }
  // What Uber Notebook keeps in a notes folder (a profile in your home
  // folder itself: these made yours alone, not the home folder).
  readonly property var ownEntries: ["Pages", ".trash", "library.json", "Exports", "Markdown"]
  // The notebooks' folders in a notes folder (each one with its
  // notebook.json, named by its id): done([id]). (A profile in your home
  // folder itself: made yours alone with what's above, never anything
  // else there.)
  readonly property string notebookFoldersScript: "for f in \"$1\"/*/notebook.json; do [ -f \"$f\" ] || continue; d=${f%/notebook.json}; printf '%s\\n' \"${d##*/}\"; done"
  function notebookFoldersIn(root, done) {
    exec(["/usr/bin/bash", "-c", notebookFoldersScript, "uber-notebook-notebooks", String(root)], function(ok, out) {
      done(ok ? String(out || "").split("\n").filter(function(n) { return Library.isId(n) }) : [])
    }, { okCodes: [0, 1], timeoutMs: 8000, maxBytes: 256 * 1024 })
  }
  // `mkdir -p` making every folder it makes yours alone (700): notes are
  // never readable by other accounts on the computer.
  function privateMkdir(paths) {
    return ["/usr/bin/bash", "-c", "umask 077 && exec /usr/bin/mkdir -p -- \"$@\"", "uber-notebook-mkdir"].concat(paths)
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
    exec(privateMkdir(paths), function(ok, output) {
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

  // A notes folder that couldn't be used: one that couldn't be made yours
  // alone (a drive that can't keep files private, a folder that isn't
  // yours: "private"), or made at all, or not there any more (a drive
  // that's gone or isn't mounted: "made"). Not opened, nothing of the one
  // before shown or written to; the window says so, with where to pick
  // another, or to try again. "" when the one open is fine.
  property string blockedFolder: ""
  property string blockedWhy: ""
  // That folder looked at again (picked again, the window's Try again): a
  // drive mounted since, a folder made private.
  function retry() {
    if (blockedFolder && active) locateTimer.restart()
  }
  // Uber Notebook's own data folder (the demo's notes are in it).
  property string dataFolder: ""
  // The open profile is new: its folder hasn't been opened yet (Profiles,
  // `fresh`).
  property bool newProfile: false
  // The notes folder made, if it isn't there yet: only a new profile's
  // (and the folders it's in), or one in Uber Notebook's own data folder
  // (the demo's). One that was opened before and isn't there now is never
  // made again (a drive mounted in a folder of yours, ~/GDrive/Notes, not
  // mounted now: its mount point is an empty folder of yours), so nothing's
  // put where that drive goes, hidden once it's back; it's blocked
  // ("made"), and tried again (Try again) once it's there. (A drive mounted
  // at the notes folder itself isn't told apart: not mounted, it's an
  // empty folder, opened as one.) done(ok).
  readonly property string notesMkdirScript: "umask 077; [ -d \"$1\" ] && exit 0; [ \"$2\" = new ] && exec /usr/bin/mkdir -p -- \"$1\"; echo gone; exit 1"
  function makeNotesFolder(path, done) {
    var made = newProfile || (dataFolder !== "" && path.indexOf(dataFolder + "/") === 0)
    exec(["/usr/bin/bash", "-c", notesMkdirScript, "uber-notebook-mkdir", path, made ? "new" : "there"], function(ok, output) {
      var out = String(output || "").trim()
      var shown = path.replace(home, "~")
      if (!ok) failed(out === "gone" ? "Your notes folder " + shown + " isn't there (a drive that isn't mounted?). It isn't made again, so nothing's put where that drive goes: Try again once it's there, or pick another folder"
        : "Couldn't make " + shown + ": " + out)
      done(ok)
    })
  }
  // Nothing of a folder on the shelf (one left, or none to open).
  function clearShelf() {
    index = ({})
    order = []
    publish()
  }
  function block(folder, why) {
    switching = false
    if (rootPath) leaveRoot()
    rootPath = ""
    notesRoot = ""
    clearShelf()
    blockedFolder = folder
    blockedWhy = why
  }
  function locate() {
    if (!home || !active) return
    ready = false
    var gen = ++generation
    exec(["/usr/bin/test", "-d", home + "/Documents"], function(ok) {
      if (gen !== store.generation) return
      var next = Settings.resolveFolder(store.folder, store.home, ok)
      // (Another folder: the one before left at once (what's waiting written
      // there), and nothing of it shown or changed from now, whatever comes
      // of the next.)
      if (next !== store.rootPath) {
        if (store.rootPath) store.leaveRoot()
        store.rootPath = ""
        store.notesRoot = ""
        store.clearShelf()
      }
      store.blockedFolder = ""
      store.blockedWhy = ""
      // (Made, made yours alone and checked before anything of it's opened:
      // your notes aren't kept where another account could read them.)
      store.makeNotesFolder(next, function(made) {
        if (gen !== store.generation) return
        if (!made) { store.block(next, "made"); return }
        function opened(isPrivate) {
          if (gen !== store.generation) return
          if (!isPrivate) {
            store.block(next, "private")
            store.failed("Your notes can't be kept in " + next.replace(store.home, "~") + ": another account on this computer could read them there. Pick another folder for this profile")
            return
          }
          store.switching = false
          store.rootPath = next
          store.notesRoot = next
          store.loadLibrary()
        }
        if (next === store.home) store.privateEntries(next, store.ownEntries, opened)
        else store.makePrivate(next, opened)
      })
    })
  }

  property bool welcomed: false

  function loadLibrary() {
    var gen = generation
    // (Another profile's folder opened meanwhile: not its shelf, nor marked
    // open. The same one looked at again (a new generation) is still this
    // one: the read that answers last is the one kept.)
    var root0 = rootPath
    readGlob(rootPath, "*/notebook.json", function(files) {
      if (gen !== store.generation || root0 !== store.rootPath) return
      var found = {}
      for (var path in files) {
        var id = path.slice(rootPath.length + 1, path.length - "/notebook.json".length)
        if (!Library.isId(id)) continue
        var nb = Library.cleanNotebook(parseJson(files[path]), id)
        if (nb) { found[id] = nb; store.folders[id] = true }
      }
      store.index = found
      // (A profile in your home folder itself: its notebooks' folders too.)
      if (store.rootPath === store.home) store.privateEntries(store.rootPath, Object.keys(found), function(ok) {
        if (!ok) store.failed("Your notebooks in your home folder couldn't be made yours alone: another account on this computer may be able to read them")
      })
      store.readFiles([Library.libraryFile(root0)], function(lib) {
        if (root0 !== store.rootPath) return
        var saved = parseJson(lib[Library.libraryFile(root0)] || "")
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
    writeKept(Library.libraryFile(rootPath), Library.stringify({ version: 1, order: order }))
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
      if (nb) whenReady(id, function() { store.writeKept(Library.notebookFile(store.rootPath, id), Library.stringify(nb)) })
    })
  }

  // ---- notebooks ---------------------------------------------------------------------------

  // A new notebook, with the given first pages (null: one blank page). Returns
  // what the shelf shows of it; its folder is made and its files written next.
  function createNotebook(choice, firstPages) {
    // (No folder open (none yet, or one that can't be used): none made.)
    if (!rootPath || !ready) return null
    var taken = {}
    order.forEach(function(id) { taken[id] = true })
    var nb = Library.newNotebook(choice, new Date(), taken)
    var pages = (firstPages === null || firstPages === undefined ? [{}] : firstPages).map(function(p) { return Library.newPage(p) })
    nb.pages = pages.map(function(p) { return p.id })
    index[nb.id] = nb
    order = order.concat([nb.id])
    publish()
    var dir = rootPath + "/" + nb.id
    // (Its folder made after another profile's folder opened: nothing of it
    // put in that one's, nor its shelf's order.)
    var root0 = rootPath
    mkdirs([dir + "/pages", dir + "/assets"], function(ok) {
      if (!ok || root0 !== store.rootPath) return
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
    // (What couldn't be saved of it, or in it, isn't tried again, and what's
    // waiting to be written there isn't: it would bring back what you took
    // away. One being written now is let finish first, then moved too.)
    forgetUnsaved(path)
    var p = String(path || "").replace(/\/+$/, "")
    function under(k) { return k === p || k.indexOf(p + "/") === 0 }
    Object.keys(queued).forEach(function(k) {
      if (!under(k)) return
      var q = queued[k]
      delete queued[k]
      q.waiters.forEach(function(w) { try { w(false) } catch (e) {} })
    })
    // (Into the trash of the notes it's in, as they are now: never another
    // profile's, opened while a write finishes.)
    var dir = Library.trashDir(rootPath)
    if (Object.keys(writing).some(under)) { trashLater = trashLater.concat([{ path: path, name: name, under: under, dir: dir }]); return }
    trashNow(path, name, dir)
  }
  // Trashed once what was being written in it is done.
  property var trashLater: []
  function trashLaterNow() {
    var ready = trashLater.filter(function(t) { return !Object.keys(store.writing).some(t.under) })
    if (!ready.length) return
    trashLater = trashLater.filter(function(t) { return ready.indexOf(t) < 0 })
    ready.forEach(function(t) { store.trashNow(t.path, t.name, t.dir) })
  }
  function trashNow(path, name, dir) {
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
    if (!nb || !rootPath) { done(null); return }
    whenReady(id, function() { store.readPages(id, done) })
  }

  function readPages(id, done) {
    var nb = index[id]
    if (!nb || !rootPath) { done(null); return }
    // (Another profile opened while it's read: nothing of it is shown,
    // exported, merged with that one's pages or saved there; a restored
    // profile's notebooks have the same ids.)
    var gen = generation
    var root0 = rootPath
    readGlob(Library.pagesDir(rootPath, id), "*.json", function(files, read, failed) {
      if (gen !== store.generation || root0 !== store.rootPath) { done(null); return }
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

  function writePage(id, page, done) {
    remember(id, page)
    var path = Library.pageFile(rootPath, id, page.id)
    var text = pageJson(page)
    whenReady(id, function() { store.writeKept(path, text, done) })
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
    // (None while no folder's open, or another's being opened.)
    if (!nb || !rootPath || !ready || switching) return null
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

  function savePage(id, page, done) {
    var nb = index[id]
    if (!nb) { if (done) done(false); return }
    writePage(id, page, done)
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
  // true once it's kept (written); false when it can't be (no folder open:
  // none yet, or one that can't be used), nothing done.
  function quickNote(text) {
    var lines = String(text || "").replace(/\r/g, "").split("\n")
    while (lines.length && lines[0].trim() === "") lines.shift()
    while (lines.length && lines[lines.length - 1].trim() === "") lines.pop()
    if (lines.length === 0) return true
    if (!rootPath || !ready) return false
    var id = ""
    order.forEach(function(nid) { if (index[nid] && index[nid].role === "quick") id = nid })
    if (!id) {
      var made = createNotebook({ title: "Quick notes", cover: { color: "mustard", material: "plain" }, binding: "spiral", paper: { pattern: "legal", color: "yellow", spacing: "regular" }, pen: "print", role: "quick" }, [])
      if (!made) return false
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
    if (!page) return false
    page.text = Blocks.plainText(page.blocks)
    writePage(id, page)
    pageAdded(id, page)
    return true
  }

  // done, for what's picked (a file, pictures, where an export goes) for
  // the notes open now: given `empty` if another profile was opened (or
  // began to) before it's picked, as it would go into (or come from) that
  // one's; and said (`said`, or that it wasn't added).
  function forTheseNotes(done, empty, said) {
    var gen = generation
    var root0 = rootPath
    var switching0 = switching
    return function(v) {
      var picked = Array.isArray(v) ? v.length > 0 : !!v
      if (picked && (switching0 || store.switching || gen !== store.generation || root0 !== store.rootPath)) {
        store.failed(said || "Not added: another profile was opened. Pick it again there")
        if (done) done(empty)
        return
      }
      if (done) done(v)
    }
  }

  // ---- finding text ------------------------------------------------------------------------

  // Every page that has every word of the query: done([...]), best first.
  function search(query, done) {
    var words = Library.terms(query)
    if (words.length === 0 || !rootPath || switching) { done([]); return }
    var longest = words.slice().sort(function(a, b) { return b.length - a.length })[0]
    // (Another profile opened meanwhile: nothing found in the one before is
    // given, nor mixed with this one's notebooks.)
    var gen = generation
    var root0 = rootPath
    function moved() { return gen !== store.generation || root0 !== store.rootPath || store.switching }
    // (The word on grep's input, not its command line, where every account
    // on the computer can read it.)
    exec(["/usr/bin/grep", "-rilF", "--include=*.json", "--exclude-dir=.trash", "--exclude-dir=Pages", "-f", "-", "--", rootPath], function(ok, output) {
      if (moved()) { done([]); return }
      var paths = String(output || "").split("\n").filter(function(p) { return /\/pages\/[a-z0-9-]+\.json$/.test(p) }).slice(0, 400)
      store.readFiles(paths, function(files) {
        if (moved()) { done([]); return }
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
    }, { input: longest + "\n", okCodes: [0, 1], maxBytes: 2 * 1024 * 1024, timeoutMs: 8000 })
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
  // (What reads the clipboard: wl-paste; a stand-in in tests.)
  property string pasteProgram: "/usr/bin/wl-paste"
  function readClipboard(done, primary) {
    var which = primary === true ? ["--primary"] : []
    exec([store.pasteProgram].concat(which, ["--list-types"]), function(ok, output) {
      var types = ok ? String(output || "").split("\n").map(function(t) { return t.trim() }) : []
      var html = types.indexOf("text/html") >= 0 ? "text/html" : ""
      var text = ["text/plain;charset=utf-8", "text/plain", "UTF8_STRING", "STRING", "TEXT"].filter(function(t) { return types.indexOf(t) >= 0 })[0] || ""
      if (!html && !text) { done(null); return }
      function readText(htmlText) {
        if (!text) { done({ html: htmlText, text: "" }); return }
        // (Through execText: long text in any script arrives whole.)
        store.execText([store.pasteProgram].concat(which, ["--no-newline", "--type", text]), function(ok2, out2) {
          done({ html: htmlText, text: ok2 ? String(out2 || "") : "" })
        }, { timeoutMs: 5000, maxBytes: store.clipboardMax })
      }
      if (!html) { readText(""); return }
      store.execText([store.pasteProgram].concat(which, ["--no-newline", "--type", html]), function(ok1, out1) {
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
  function saveGrab(result, path) {
    var ok = !!result && result.saveToFile(path)
    // (Yours alone, as everything Uber Notebook writes.)
    if (ok) exec(["/usr/bin/chmod", "go-rwx", "--", path], null, { okCodes: [0, 1] })
    return ok
  }
  // A file for a moment (a picture on its way to the clipboard), where only
  // you can read it.
  function tempPath(name) { return runtimeDir + "/uber-notebook-" + name }

  // A copy of a file at `to` (a picture saved where you said): done(ok, why).
  function copyFileTo(from, to, done) { placeFile(from, to, true, done) }
  // A copy of the file `from` at `to`, a place you chose: a new file yours
  // alone, put there (`replace`: over a file that's there; else never),
  // never one left readable by others (as cp over a 644 file would leave
  // it). done(ok, why).
  function placeFile(from, to, replace, done) {
    helper(["place", from, to, replace ? "replace" : "keep"], function(ok, out) {
      if (done) done(ok, ok ? "" : String(out || "").trim().split("\n").pop())
      if (ok && /^open$/m.test(String(out || ""))) store.failed(store.openDriveNote(to))
    }, { timeoutMs: 120000, maxBytes: 8192 })
  }
  // Files of a folder of Uber Notebook's own (Pages/assets), by their names,
  // copied into `to` (an export's assets folder, made yours alone first):
  // only those (never the whole folder), each a new file yours alone (as
  // umask 077 leaves it, whatever the one copied was), a link copied as a
  // link (never what it points to), one that isn't there left out. Their
  // names on its input (xargs), never too many for a command line.
  // done(ok): every one copied.
  readonly property string copyAssetsScript: "umask 077 && cd -- \"$1\" && exec /usr/bin/xargs -r -d '\\n' /usr/bin/cp -P -t \"$2\" --"
  function copyAssets(from, names, to, done) {
    var list = (names || []).map(String).filter(function(n) { return /^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(n) && n.indexOf("..") < 0 })
    if (!list.length || !/^\/./.test(String(from)) || !/^\/./.test(String(to))) { if (done) done(list.length === 0); return }
    exec(["/usr/bin/bash", "-c", copyAssetsScript, "uber-notebook-copy-assets", String(from), String(to)], function(ok) { if (done) done(ok) },
      { input: list.join("\n") + "\n", timeoutMs: 300000, maxBytes: 1024 * 1024 })
  }

  // A file you saved where you chose, on a drive that can't keep files
  // private (an exFAT stick, some shares): saved, as you asked, and said.
  function openDriveNote(path) {
    return "Saved to " + String(path).replace(home, "~") + ", but that drive can't keep files private: another account on this computer may read it"
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
  // opens the page (or the calendar, on `day`). Sent by the files helper
  // over the session bus, its words on the helper's input: never on a
  // command line, where every account on the computer can read them (as
  // omarchy-notification-send would put them, through busctl).
  // A reminder's or an event alert's own words (a page's, or a day's): only
  // when Settings says so (reminderWords, off till you turn it on).
  // Omarchy's notifications keep each one's words for a moment on a command
  // line (as they save it), where another account on the computer could
  // read them: off, it says only that one is due, where to turn its words
  // on, and a click opens it.
  property bool reminderWords: false
  // What a notification says, and what a click on it opens: { summary,
  // body, glyph, exec }.
  function notification(title, text, pageId, day) {
    var isDay = /^\d{4}-\d{2}-\d{2}$/.test(String(day || ""))
    var isPage = /^[0-9a-f-]{36}$/.test(String(pageId || ""))
    // (An event's alert has its day, and its notes page if it has one: an
    // event's, whatever it opens.)
    if (!reminderWords && isDay) { title = "An event is starting"; text = "Click to see it. Turn on reminder details in Settings → Privacy." }
    else if (!reminderWords && isPage) { title = "A reminder is due"; text = "Click to open it. Turn on reminder details in Settings → Privacy." }
    var click = isPage ? ["/usr/bin/omarchy-shell", "uber-notebook", "open", pageId] : isDay ? ["/usr/bin/omarchy-shell", "uber-notebook", "calendar", day] : []
    return { summary: String(title || "Reminder").slice(0, 120), body: String(text || "").slice(0, 300), glyph: "\u{f009e}", exec: click }
  }
  function notify(title, text, pageId, day) {
    var note = notification(title, text, pageId, day)
    helper(["notify"], function(ok, out) {
      if (!ok) console.warn("Uber Notebook: a notification wasn't sent: " + String(out || "").trim().slice(0, 200))
    }, { input: JSON.stringify(note), timeoutMs: 10000, maxBytes: 4096 })
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
    // (Picked after another profile began to open: nothing exported, as
    // what's read for it would be that one's.)
    var given = forTheseNotes(done, "", "Not exported: another profile was opened. Export it again there")
    if (typeof exportFolder === "function") exportFolder(given)
    else given(rootPath + "/Exports")
  }

  function exportNotebook(id) {
    exportBase(function(base) { if (base) store.exportNotebookTo(id, base) })
  }

  function exportNotebookTo(id, base) {
    // (Its pictures from the profile it's exported from, whatever's opened
    // meanwhile.)
    var from = rootPath
    openNotebook(id, function(nb) {
      if (!nb) return
      var stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd HHmm")
      var name = (nb.title.replace(/[\/\\:*?"<>|\u0000-\u001f]+/g, " ").trim() || "Notebook") + " " + stamp
      var dir = base + "/" + name
      store.mkdirs([dir], function(ok) {
        if (!ok) return
        var used = {}
        // (Said done only once every page is written and its pictures
        // copied: the files helper writes a few at a time.)
        var left = nb.pages.length + 1
        var lost = 0
        function one(ok2) {
          if (!ok2) lost++
          if (--left > 0) return
          if (lost) { store.failed("The export in " + dir.replace(home, "~") + " isn't whole: some of its files couldn't be written or copied"); return }
          store.exported(dir)
          Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", dir])
        }
        nb.pages.forEach(function(page, i) {
          var file = ("00" + (i + 1)).slice(-3) + " " + Markdown.fileName(page, i)
          if (used[file]) file = file.replace(/\.md$/, " " + i + ".md")
          used[file] = true
          store.writeFile(dir + "/" + file, Markdown.fromPage(page, ""), one)
        })
        // (Its pictures, if it has any: a copy that fails is an export
        // that isn't whole, said.)
        store.exec(["/usr/bin/bash", "-c", "[ -d \"$1\" ] || exit 0; exec /usr/bin/cp -r -- \"$1\" \"$2\"", "uber-notebook-export-assets", from + "/" + id + "/assets", dir + "/assets"], function(copied) { one(copied) }, { timeoutMs: 300000 })
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
      if (nb && folders[id]) store.writeKept(Library.notebookFile(rootPath, id), Library.stringify(nb))
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
      if (nb && folders[id]) store.writeKept(Library.notebookFile(rootPath, id), Library.stringify(nb))
    })
    retryUnsaved(null)
  }

  Component.onDestruction: flush()
}
