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

  function readFiles(paths, done) {
    var out = {}
    paths.forEach(function(p) { if (files.disk[p] !== undefined) out[p] = files.disk[p] })
    done(out)
  }

  function writeFile(path, text, done) {
    disk[path] = String(text)
    if (done) done(true)
  }

  function trash(path, name) {
    trashed.push(name)
    delete disk[path]
  }

  // The programs Workspace.qml runs: listing a folder, grep, cp, finding
  // what's in folders to import.
  function exec(argv, done, options) {
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-scan") {
      var out = ""
      argv.slice(4).forEach(function(root) {
        if (disk[root] !== undefined) { out += "R\t" + root + "\n" + root + "\n"; return }
        var inside = Object.keys(disk).filter(function(p) { return p.indexOf(root + "/") === 0 }).sort()
        if (inside.length) out += "R\t" + root + "\n" + inside.join("\n") + "\n"
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
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-backup-check") {
      var tarred = disk[argv[4]]
      if (tarred === undefined || String(tarred).indexOf("FAKE-TAR:") !== 0) { done(true, "readable:0\n"); return }
      done(true, "readable:1\ntypes:-d\noutside:0\ndots:0\n---\n" + JSON.stringify(JSON.parse(String(tarred).slice(9)).manifest))
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-restore") {
      var held = JSON.parse(String(disk[argv[4]]).slice(9)).files[argv[5]]
      if (!held) { done(false, "not in it"); return }
      var dest = argv[6]
      for (var k3 = 2; Object.keys(disk).some(function(p) { return p === dest || p.indexOf(dest + "/") === 0 }); k3++) dest = argv[6] + " " + k3
      for (var rel2 in held) disk[dest + "/" + rel2] = held[rel2]
      done(true, dest + "\n")
      return
    }
    if (argv[0] === "/usr/bin/gio" && argv[1] === "trash") {
      argv.slice(3).forEach(function(p) { files.trashed.push(p); delete disk[p] })
      done(true, "")
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
    // A link's page, and its picture (`pages`: { url: html }; `pictures`: { url: content type }).
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-fetch") {
      var html = fetchPages[argv[4]]
      done(html !== undefined, html || "")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-fetch-image") {
      var type = fetchPictures[argv[4]]
      if (type === undefined) { done(false, ""); return }
      disk[argv[5]] = "PNG"
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
  property var opened: []
  function openUrl(url) { opened = opened.concat([String(url)]) }
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
  function listAgents(done) { done(agentList) }
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
    var s = { argv: argv, cwd: (options || {}).cwd || "", onLine: onLine, done: done }
    streamed = streamed.concat([s])
    streamNow = s
    return { stop: function() { if (!s.done) return; var d = s.done; s.done = null; Qt.callLater(function() { d(-1, "") }) } }
  }
  function streamFeed(line) { if (streamNow && streamNow.done) streamNow.onLine(String(line)) }
  function streamEnd(code, errors) { var s = streamNow; if (s && s.done) { var d = s.done; s.done = null; d(code, errors || "") } }
  function pickAgent() { picked++ }
  function notify(title, text, pageId, day) { notified = notified.concat([{ title: title, text: text, page: pageId, day: day || "" }]) }
}
