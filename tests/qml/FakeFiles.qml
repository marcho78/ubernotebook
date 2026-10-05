import QtQuick
import "../../Library.js" as Library
import "../../Agent.js" as Agent

// Files in memory, with the calls Workspace.qml makes of Store.qml: for
// tests and the dev harness, so the real workspace runs without a disk.
QtObject {
  id: files

  property string rootPath: "/tmp/uber-notebook-dev"
  property string home: "/tmp"
  property string runtimeDir: "/tmp"
  // path -> text
  property var disk: ({})
  // The helper's reads answered later, as the real one's are (else at once).
  property bool deferHelperReads: false
  property var heldReads: []
  function answerReads() { var list = heldReads; heldReads = []; list.forEach(function(f) { f() }) }
  // Store.readClipboard(done, primary), when a test sets one (null: Qt's paste).
  property var readClipboard: null
  property var copied: ""
  property var trashed: []
  property var notified: []
  // The default agent, and what was asked of it.
  property string agent: "claude"
  property var launched: []
  property int picked: 0

  signal exported(string path)
  signal failed(string message)
  signal pageAdded(string notebookId, var page)

  // The shelf's notebooks, as the commands use Store.qml's: { id: { title,
  // modified, pages } }, and the pages written this session.
  property var index: ({})
  property var written: ({})
  function notebookList() { return Object.keys(index).map(function(id) { return { id: id, title: index[id].title, modified: index[id].modified } }) }
  function writePage(id, page) {
    if (!written[id]) written[id] = {}
    written[id][page.id] = JSON.parse(JSON.stringify(page))
    disk[Library.pageFile(rootPath, id, page.id)] = Library.stringify(page)
  }
  function createPage(id, at, options) {
    var nb = index[id]
    if (!nb) return null
    var taken = {}
    nb.pages.forEach(function(p) { taken[p] = true })
    var page = Library.newPage(options, new Date(), taken)
    var list = nb.pages.slice()
    list.splice(Math.max(0, Math.min(list.length, at)), 0, page.id)
    nb.pages = list
    writePage(id, page)
    return page
  }

  function reset() {
    ran = []
    exportTools = "/usr/lib/chromium/chromium\n/usr/lib/libreoffice/program/soffice\nunshare\n"
    failExportHtml = ""
    printed = []
    picturesIn = []
    deferHelperReads = false
    heldReads = []
    failReads = ({})
    readClipboard = null
    privateHosts = ({})
    failWrites = ""
    missingAgent = ""
    disk = ({})
    index = ({})
    written = ({})
    copied = ""
    trashed = []
    notified = []
    agent = "claude"
    agentList = [{ name: "claude", label: "Claude" }, { name: "codex", label: "Codex" }, { name: "gemini", label: "Gemini" }]
    launched = []
    picked = 0
    streamed = []
    streamNow = null
    http = ({})
    gitCheckout = false
    installed = []
    mtimes = ({})
    opened = []
  }

  property var fetchPages: ({})
  property var fetchPictures: ({})
  // GitHub, for the update check: { url: { code, body } } (a URL not in it:
  // GitHub can't be reached). Uber Notebook installed from git, and what
  // `omarchy plugin update` was asked to update.
  property var http: ({})
  property bool gitCheckout: false
  property var installed: []
  // When files were last changed (seconds), for the backups listed.
  property var mtimes: ({})

  function parseJson(text) {
    try { return JSON.parse(text) } catch (e) { return null }
  }

  // Where exports go (Store.qml's exportBase): null is the Exports folder.
  property var exportBase: null

  function mkdirs(paths, done) { if (done) done(true) }

  function readNow(path, maxBytes) {
    var text = files.disk[path]
    if (text === undefined || String(text).length > (maxBytes || 2 * 1024 * 1024)) return null
    return String(text)
  }

  // (A path in failReads couldn't be read: not in what's read, said in `failed`.)
  property var failReads: ({})
  function readFiles(paths, done) {
    var out = {}
    var failed = []
    paths.forEach(function(p) {
      if (failReads[p]) failed.push(p)
      else if (files.disk[p] !== undefined) out[p] = files.disk[p]
    })
    done(out, true, failed)
  }
  // The files a pattern finds in dir ("*.json", "*/notebook.json"), as Store's.
  function readGlob(dir, pattern, done) {
    var out = {}
    var sub = pattern.indexOf("*/") === 0 ? pattern.slice(2) : ""
    var end = sub ? "" : pattern.slice(1)
    for (var p in files.disk) {
      if (p.indexOf(dir + "/") !== 0) continue
      var rest = p.slice(dir.length + 1)
      var parts = rest.split("/")
      if (sub ? parts.length === 2 && parts[1] === sub : parts.length === 1 && rest.slice(-end.length) === end) out[p] = files.disk[p]
    }
    done(out, true, [])
  }

  // (A path with failWrites in it isn't written: done(false).)
  property string failWrites: ""
  function writeFile(path, text, done) {
    if (failWrites && String(path).indexOf(failWrites) >= 0) { if (done) done(false); return }
    disk[path] = String(text)
    if (done) done(true)
  }

  function trash(path, name) {
    trashed.push(name)
    delete disk[path]
  }

  // The programs Workspace.qml runs: listing a folder, grep, cp, finding
  // what's in folders to import.
  // A stand-in for a file's sha256: 64 hex digits that change with it.
  function fakeHash(text) {
    var s = String(text)
    var out = ""
    for (var round = 0; out.length < 64; round++) {
      var h = 2166136261 + round
      for (var i = 0; i < s.length; i++) h = Math.imul(h ^ s.charCodeAt(i), 16777619) >>> 0
      out += ("00000000" + h.toString(16)).slice(-8)
    }
    return out.slice(0, 64)
  }

  // Hosts whose address is on your own network: { host: "192.168.1.5" }.
  property var privateHosts: ({})

  // Every command run, in order ([argv, ...]), for tests to read.
  property var ran: []
  // The archive helper (Store.qml), as its commands' first words.
  readonly property string filesHelper: "/plugin/bin/uber-notebook-files"
  function helper(args, done, options) { exec(["/usr/bin/python3", "-I", "-S", filesHelper].concat(args), done, options) }

  // Exports (app/Exporter.qml): the programs there ("" for none), a refusal
  // from the files helper's export-html, the PDFs opened to print.
  property string exportTools: "/usr/lib/chromium/chromium\n/usr/lib/libreoffice/program/soffice\nunshare\n"
  property string failExportHtml: ""
  property var printed: []
  function openPrint(path, done) { printed = printed.concat([path]); if (done) done(true) }

  function exec(argv, done, options) {
    ran = ran.concat([argv.slice()])
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-export-tools") { done(true, exportTools); return }
    if (argv[3] === filesHelper && argv[4] === "export-html") {
      if (failExportHtml) { done(false, JSON.stringify({ ok: false, error: failExportHtml })); return }
      disk[argv[6] + "/page.html"] = disk[argv[6] + "/page.src.html"]
      done(true, JSON.stringify({ ok: true, pictures: 0, missing: 0 }))
      return
    }
    // Chromium printing the page, or LibreOffice converting it.
    var pdfTo = argv.filter(function(a) { return String(a).indexOf("--print-to-pdf=") === 0 })[0]
    if (pdfTo) { disk[pdfTo.slice(15)] = "PDF"; done(true, ""); return }
    if (argv.indexOf("--convert-to") >= 0) { disk[argv[argv.indexOf("--outdir") + 1] + "/page.docx"] = "DOCX"; done(true, ""); return }
    if (argv[0] === "/usr/bin/test" && argv[1] === "-s") { done(disk[argv[2]] !== undefined, ""); return }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-scan") {
      var out = ""
      argv.slice(4).forEach(function(root) {
        if (disk[root] !== undefined) { out += "R\t" + root + "\u0000" + root + "\u0000"; return }
        var inside = Object.keys(disk).filter(function(p) { return p.indexOf(root + "/") === 0 }).sort()
        if (inside.length) out += "R\t" + root + "\u0000" + inside.join("\u0000") + "\u0000"
      })
      done(true, out)
      return
    }
    // A folder's folders and files, for the picture picker ("d\t0\tname", "f\tmtime\tname").
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-pictures") {
      var base = argv[4].replace(/\/+$/, "") + "/"
      var seenDirs = {}
      var rows = []
      Object.keys(disk).forEach(function(p, n) {
        if (p.indexOf(base) !== 0) return
        var rest = p.slice(base.length)
        var cut = rest.indexOf("/")
        if (cut > 0) { var dn = rest.slice(0, cut); if (!seenDirs[dn]) { seenDirs[dn] = true; rows.push("d\t0\t" + dn) } }
        else rows.push("f\t" + (1000 + n) + "\t" + rest)
      })
      done(rows.length > 0, rows.join("\n") + "\n")
      return
    }
    // Notes from before profiles: for each folder, whether it has them, and
    // the Inbox, the page and the notebook the settings name.
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-notes") {
      var ids = argv.slice(4, 7)
      done(true, argv.slice(7).map(function(d) {
        var bit = function(on) { return on ? "1" : "0" }
        return [bit(disk[d + "/library.json"] !== undefined || disk[d + "/Pages/index.json"] !== undefined),
          bit(ids[0] && disk[d + "/Pages/" + ids[0] + ".json"] !== undefined), bit(ids[1] && disk[d + "/Pages/" + ids[1] + ".json"] !== undefined),
          bit(ids[2] && disk[d + "/" + ids[2] + "/notebook.json"] !== undefined)].join(" ")
      }).join("\n") + "\n")
      return
    }
    // The update check (Updates.qml): GitHub's answer, then its status.
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-update") {
      var answer = http[argv[4]]
      if (!answer) { done(false, "curl: (6) Could not resolve host: api.github.com"); return }
      done(true, answer.body + "\n" + answer.code)
      return
    }
    if (argv[0] === "/usr/bin/test" && /\/\.git$/.test(argv[2])) { done(gitCheckout, ""); return }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-install") {
      installed = installed.concat([argv[4]])
      done(true, "Updated " + argv[4] + ".")
      return
    }
    // Backups (Backups.js). A backup here is "FAKE-TAR:" then JSON:
    // { manifest, files: { p1: { "Pages/x.json": text } } }.
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-backup-has") {
      done(true, argv.slice(4).map(function(d) { return Object.keys(disk).some(function(p) { return p.indexOf(d + "/") === 0 }) ? "1" : "0" }).join("\n") + "\n")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-backups") {
      var bdir = argv[4].replace(/\/+$/, "") + "/"
      var rows2 = Object.keys(disk).filter(function(p) { var n = p.slice(bdir.length); return p.indexOf(bdir) === 0 && n.indexOf("/") < 0 && n.charAt(0) !== "." && /\.tar\.gz$/.test(n) })
        .map(function(p) { return (mtimes[p] || 1759455000) + "\t" + String(disk[p]).length + "\t" + p.slice(bdir.length) })
      done(true, rows2.join("\n") + (rows2.length ? "\n" : ""))
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-backup") {
      var a = argv.slice(4)
      var out2 = a[0] + "/" + a[1] + a[2]
      for (var k2 = 2; disk[out2] !== undefined; k2++) out2 = a[0] + "/" + a[1] + " " + k2 + a[2]
      var packed = {}
      for (var t = 4; t + 2 < a.length; t += 3) {
        var src = a[t], skip = a[t + 2]
        packed[a[t + 1]] = {}
        Object.keys(disk).forEach(function(p) {
          if (p.indexOf(src + "/") !== 0) return
          var rel = p.slice(src.length + 1)
          if (skip && (rel === skip || rel.indexOf(skip + "/") === 0)) return
          packed[a[t + 1]][rel] = disk[p]
        })
      }
      disk[out2] = "FAKE-TAR:" + JSON.stringify({ manifest: JSON.parse(a[3]), files: packed })
      mtimes[out2] = Date.now() / 1000
      done(true, String(disk[out2].length) + "\n" + out2 + "\n")
      return
    }
    // The archive helper (bin/uber-notebook-files): a backup looked into,
    // and one profile in it put back (only if it's still the one looked into).
    if (argv[0] === "/usr/bin/python3" && argv[3] === filesHelper && argv[4] === "read") {
      var held2 = disk[argv[6]]
      var said = JSON.stringify(held2 === undefined ? { ok: false, error: "there's no file there" } : String(held2).length > Number(argv[5]) ? { ok: false, error: "more than " + argv[5] + " bytes" } : { ok: true, text: String(held2) })
      if (deferHelperReads) heldReads.push(function() { done(true, said) })
      else done(true, said)
      return
    }
    if (argv[0] === "/usr/bin/python3" && argv[3] === filesHelper && argv[4] === "inspect-backup") {
      var tarred = disk[argv[5]]
      if (tarred === undefined || String(tarred).indexOf("FAKE-TAR:") !== 0) { done(true, "readable:0\n"); return }
      done(true, "readable:1\ntypes:-d\noutside:0\ndots:0\nhash:" + fakeHash(tarred) + "\n---\n" + JSON.stringify(JSON.parse(String(tarred).slice(9)).manifest))
      return
    }
    if (argv[0] === "/usr/bin/python3" && argv[3] === filesHelper && argv[4] === "restore-backup") {
      if (disk[argv[5]] === undefined || fakeHash(disk[argv[5]]) !== argv[8]) { done(false, "the backup changed after it was looked at"); return }
      var held = JSON.parse(String(disk[argv[5]]).slice(9)).files[argv[6]]
      if (!held) { done(false, "not in it"); return }
      var dest = argv[7]
      for (var k3 = 2; Object.keys(disk).some(function(p) { return p === dest || p.indexOf(dest + "/") === 0 }); k3++) dest = argv[7] + " " + k3
      for (var rel2 in held) disk[dest + "/" + rel2] = held[rel2]
      done(true, dest + "\n")
      return
    }
    if (argv[0] === "/usr/bin/gio" && argv[1] === "trash") {
      argv.slice(3).forEach(function(p) { files.trashed.push(p); delete disk[p] })
      done(true, "")
      return
    }
    // (Never over a file that's there: it fails.)
    if (argv[0] === "/usr/bin/cp" && argv[1] === "--update=none-fail") {
      var ok = disk[argv[3]] !== undefined && disk[argv[4]] === undefined
      if (ok) disk[argv[4]] = disk[argv[3]]
      done(ok, ok ? "" : "cp: not copied")
      return
    }
    if (argv[0] === "/usr/bin/cp" && disk[argv[2]] !== undefined) {
      disk[argv[3]] = disk[argv[2]]
      done(true, "")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-list") {
      var dir = argv[4] + "/"
      var names = Object.keys(disk).filter(function(p) { return p.indexOf(dir) === 0 && p.slice(dir.length).indexOf("/") < 0 && /\.json$/.test(p) })
        .map(function(p) { return p.slice(dir.length) })
      done(true, names.join("\n") + (names.length ? "\n" : ""))
      return
    }
    // The Markdown copy's own files in a folder (Mirror.qml).
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-mirror-list") {
      var top = argv[4] + "/"
      var mine = Object.keys(disk).filter(function(p) { return p.indexOf(top) === 0 })
        .map(function(p) { return p.slice(top.length) })
        .filter(function(p) { return /^(Pages|Notebooks|sketches)\//.test(p) && /\.(md|svg)$/.test(p) })
      done(true, mine.join("\n") + (mine.length ? "\n" : ""))
      return
    }
    // A file in assets, as it is: its size, and that it's a plain file.
    if (argv[0] === "/usr/bin/stat" && argv[1] === "-c" && argv[2] === "%s\t%F") {
      var st = disk[argv[4]]
      if (st === undefined) { done(false, "No such file"); return }
      done(true, String(st).length + "\tregular file\n")
      return
    }
    // A file copied into assets: its size.
    // An email's attachment: its base64, decoded into a file.
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-unpack") {
      if (disk[argv[4]] === undefined) { done(false, "No such file"); return }
      disk[argv[5]] = Qt.atob(String(disk[argv[4]]))
      delete disk[argv[4]]
      done(true, "")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-import-file") {
      if (disk[argv[4]] === undefined) { done(false, "No such file"); return }
      disk[argv[5]] = disk[argv[4]]
      done(true, String(disk[argv[4]].length) + "\n")
      return
    }
    // A page's picture: its host looked up (a public address, unless
    // privateHosts names it), then fetched from there into a file.
    if (argv[0] === "/usr/bin/getent" && argv[1] === "ahosts") {
      done(true, (privateHosts[argv[2]] || "93.184.215.14") + "     STREAM " + argv[2] + "\n")
      return
    }
    // A page read step by step (Workspace.fetchPage; `fetchPages`: { url:
    // html }, "REDIRECT <url>" says it's sent on; `fetchPictures`: { url:
    // content type }).
    if (argv[0] === "/usr/bin/curl" && argv.indexOf("\n%{http_code}\t%{redirect_url}") > 0) {
      var page = fetchPages[argv[argv.length - 1]]
      if (page === undefined) { done(false, "\n000\t"); return }
      if (String(page).indexOf("REDIRECT ") === 0) { done(true, "\n301\t" + String(page).slice(9)); return }
      done(true, String(page) + "\n200\t")
      return
    }
    if (argv[0] === "/usr/bin/curl" && argv.indexOf("-o") > 0) {
      var type = fetchPictures[argv[argv.length - 1]]
      if (type === undefined) { done(false, ""); return }
      disk[argv[argv.indexOf("-o") + 1]] = "PNG"
      done(true, type)
      return
    }
    if (argv[0] === "/usr/bin/mv" && disk[argv[3]] !== undefined) {
      disk[argv[4]] = disk[argv[3]]
      delete disk[argv[3]]
      if (done) done(true, "")
      return
    }
    if (argv[0] === "/usr/bin/rm") {
      argv.slice(3).forEach(function(p) { delete disk[p] })
      if (done) done(true, "")
      return
    }
    if (argv[0] === "/usr/bin/grep") {
      var term = argv[argv.indexOf("-e") + 1].toLowerCase()
      var root = argv[argv.length - 1]
      var hits = Object.keys(disk).filter(function(p) { return p.indexOf(root) === 0 && disk[p].toLowerCase().indexOf(term) >= 0 })
      done(hits.length > 0, hits.join("\n"))
      return
    }
    if (done) done(true, "")
  }

  function isImagePath(path) { return Library.isImagePath(path) }
  function assetName(path) { return Library.assetName(path, new Date()) }
  function pasteInto(dest, done) { done("") }
  function copyText(text) { copied = String(text) }
  // A picture copied in (Store.qml: copy-picture): never over a file;
  // what it was asked, `within` too, for tests.
  property var picturesIn: []
  function copyPictureIn(from, folder, name, done, within) {
    picturesIn = picturesIn.concat([{ from: from, to: folder + "/" + name, within: within || "" }])
    var ok = disk[from] !== undefined && disk[folder + "/" + name] === undefined
    if (ok) disk[folder + "/" + name] = disk[from]
    if (done) done(ok, ok ? "" : "it couldn't be read")
  }
  // A picture onto the clipboard (Store.qml: wl-copy): which one.
  property string copiedPicture: ""
  function copyPicture(path, done) {
    var ok = disk[path] !== undefined
    if (ok) copiedPicture = path
    if (done) done(ok)
  }
  // A picture made (a diagram's, grabbed): the last one, and in the disk.
  property var lastGrab: null
  function saveGrab(result, path) {
    if (!result) return false
    lastGrab = result
    disk[path] = "PNG"
    return true
  }
  function tempPath(name) { return "/tmp/uber-notebook-" + name }
  // A copy of a file where you said (Store.qml: cp).
  function copyFileTo(from, to, done) {
    if (disk[from] === undefined) { if (done) done(false, "cp: cannot stat '" + from + "': No such file or directory"); return }
    disk[to] = disk[from]
    if (done) done(true, "")
  }
  property var opened: []
  function openUrl(url) { opened = opened.concat([String(url)]) }
  function openLocal(path) { opened = opened.concat([String(path)]) }
  // A file in its app: opened, unless its name matches `noApp` (no app for
  // it here but a web browser).
  property var noApp: null
  function openFile(path, done) {
    if (noApp && noApp.test(String(path))) { if (done) done(false, "browser"); return }
    opened = opened.concat(["file://" + path])
    if (done) done(true, "app")
  }
  function openPath(path) { console.log("open:", path) }
  // The agents installed (Store.qml: listAgents), and choosing one.
  property var agentList: [{ name: "claude", label: "Claude" }, { name: "codex", label: "Codex" }, { name: "gemini", label: "Gemini" }]
  function listAgents(done) { done(agentList.map(function(a) { return { name: a.name, label: a.label, path: "/usr/bin/" + a.name } })) }
  // An agent's program (Store.qml: found and checked): "" when missingAgent names it.
  property string missingAgent: ""
  function agentPath(name, done) { done(name === missingAgent ? "" : "/usr/bin/" + name) }
  function setDefaultAgent(name, done) { agent = name; done(true) }
  function defaultAgent(done) { done(agent) }
  function launchAgent(prompt) { launched = launched.concat([String(prompt)]) }
  // The models an agent can work with: from the lists in `disk`, as Store.qml reads them.
  function agentModels(agent, done) {
    var file = agent === "grok" ? home + "/.grok/models_cache.json" : agent === "codex" ? home + "/.codex/models_cache.json" : ""
    done(Agent.models(agent, file ? readNow(file) || "" : ""))
  }
  // An agent working without a terminal (Store.qml's stream): each run
  // ({ argv, cwd }), and the one going now, for a test to feed its lines
  // (streamFeed) and end it (streamEnd); stop() ends it as stopped (-1).
  property var streamed: []
  property var streamNow: null
  function stream(argv, onLine, done, options) {
    var s = { argv: argv, cwd: (options || {}).cwd || "", input: (options || {}).input === true, env: (options || {}).env || {}, onLine: onLine, done: done, sent: [], closed: false }
    streamed = streamed.concat([s])
    streamNow = s
    return {
      stop: function() { if (!s.done) return; var d = s.done; s.done = null; Qt.callLater(function() { d(-1, "") }) },
      send: function(text) { if (s.input && !s.closed) s.sent.push(String(text)) },
      closeInput: function() { s.closed = true }
    }
  }
  function streamFeed(line) { if (streamNow && streamNow.done) streamNow.onLine(String(line)) }
  function streamEnd(code, errors) { var s = streamNow; if (s && s.done) { var d = s.done; s.done = null; d(code, errors || "") } }
  function pickAgent() { picked++ }
  function notify(title, text, pageId, day) { notified = notified.concat([{ title: title, text: text, page: pageId, day: day || "" }]) }
}
