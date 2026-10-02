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

  function reset() {
    disk = ({})
    copied = ""
    trashed = []
    notified = []
    agent = "claude"
    agentList = [{ name: "claude", label: "Claude" }, { name: "codex", label: "Codex" }, { name: "gemini", label: "Gemini" }]
    launched = []
    picked = 0
  }

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
  function openUrl(url) { console.log("open:", url) }
  function openPath(path) { console.log("open:", path) }
  // The agents installed (Store.qml: listAgents), and choosing one.
  property var agentList: [{ name: "claude", label: "Claude" }, { name: "codex", label: "Codex" }, { name: "gemini", label: "Gemini" }]
  function listAgents(done) { done(agentList) }
  function setDefaultAgent(name, done) { agent = name; done(true) }
  function defaultAgent(done) { done(agent) }
  function launchAgent(prompt) { launched = launched.concat([String(prompt)]) }
  function pickAgent() { picked++ }
  function notify(title, text, pageId) { notified = notified.concat([{ title: title, text: text, page: pageId }]) }
}
