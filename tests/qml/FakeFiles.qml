import QtQuick
import "../../Library.js" as Library

// Files in memory, with the calls Workspace.qml makes of Store.qml: for
// tests and the dev harness, so the real workspace runs without a disk.
QtObject {
  id: files

  property string rootPath: "/tmp/omanote-dev"
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
  }

  property var fetchPages: ({})
  property var fetchPictures: ({})

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
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-scan") {
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
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-pictures") {
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
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-notes") {
      var ids = argv.slice(4, 7)
      done(true, argv.slice(7).map(function(d) {
        var bit = function(on) { return on ? "1" : "0" }
        return [bit(disk[d + "/library.json"] !== undefined || disk[d + "/Pages/index.json"] !== undefined),
          bit(ids[0] && disk[d + "/Pages/" + ids[0] + ".json"] !== undefined), bit(ids[1] && disk[d + "/Pages/" + ids[1] + ".json"] !== undefined),
          bit(ids[2] && disk[d + "/" + ids[2] + "/notebook.json"] !== undefined)].join(" ")
      }).join("\n") + "\n")
      return
    }
    if (argv[0] === "/usr/bin/cp" && disk[argv[2]] !== undefined) {
      disk[argv[3]] = disk[argv[2]]
      done(true, "")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-list") {
      var dir = argv[4] + "/"
      var names = Object.keys(disk).filter(function(p) { return p.indexOf(dir) === 0 && p.slice(dir.length).indexOf("/") < 0 && /\.json$/.test(p) })
        .map(function(p) { return p.slice(dir.length) })
      done(true, names.join("\n") + (names.length ? "\n" : ""))
      return
    }
    // The Markdown copy's own files in a folder (Mirror.qml).
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-mirror-list") {
      var top = argv[4] + "/"
      var mine = Object.keys(disk).filter(function(p) { return p.indexOf(top) === 0 })
        .map(function(p) { return p.slice(top.length) })
        .filter(function(p) { return /^(Pages|Notebooks|sketches)\//.test(p) && /\.(md|svg)$/.test(p) })
      done(true, mine.join("\n") + (mine.length ? "\n" : ""))
      return
    }
    // A file copied into assets: its size.
    // An email's attachment: its base64, decoded into a file.
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-unpack") {
      if (disk[argv[4]] === undefined) { done(false, "No such file"); return }
      disk[argv[5]] = Qt.atob(String(disk[argv[4]]))
      delete disk[argv[4]]
      done(true, "")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-import-file") {
      if (disk[argv[4]] === undefined) { done(false, "No such file"); return }
      disk[argv[5]] = disk[argv[4]]
      done(true, String(disk[argv[4]].length) + "\n")
      return
    }
    // A link's page, and its picture (`pages`: { url: html }; `pictures`: { url: content type }).
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-fetch") {
      var html = fetchPages[argv[4]]
      done(html !== undefined, html || "")
      return
    }
    if (argv[0] === "/usr/bin/bash" && argv[3] === "omanote-fetch-image") {
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
  function pickAgent() { picked++ }
  function notify(title, text, pageId, day) { notified = notified.concat([{ title: title, text: text, page: pageId, day: day || "" }]) }
}
