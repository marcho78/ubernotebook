import QtQuick
import "../../Library.js" as Library
import "../../Blocks.js" as Blocks
import "sample.js" as Sample

// A store that keeps everything in memory, for tests and the dev harness: the same
// calls as Store.qml, with a few notebooks to start with.
QtObject {
  id: store

  property bool ready: true
  // A notes folder that can't be used (Store.qml: not opened, said over the notes).
  property string blockedFolder: ""
  property string blockedWhy: ""
  // (Looked at again: how many times.)
  property int retried: 0
  function retry() { retried++ }
  property string rootPath: "/tmp/uber-notebook-dev"
  property var notebooks: []
  // Store.readClipboard(done, primary), when a test sets one (null: Qt's paste).
  property var readClipboard: null
  property var data: ({})
  property var order: []

  signal failed(string message)
  signal exported(string path)

  Component.onCompleted: seed()

  function reset() {
    readClipboard = null
    failSaves = false
    data = ({})
    order = []
    seed()
  }

  function copy(v) { return JSON.parse(JSON.stringify(v)) }

  function add(options, pages) {
    var nb = Library.newNotebook(options, new Date(2026, 8, 1 + order.length * 3))
    nb.pages = pages.map(function(p, i) {
      var page = Library.newPage(p, new Date(2026, 8, 20, 9, i))
      page.text = Blocks.plainText(page.blocks)
      return page
    })
    data[nb.id] = nb
    order.push(nb.id)
    return nb
  }

  function seed() {
    add({ title: "Field Journal", cover: { color: "navy", material: "leather" }, binding: "hardcover", paper: { pattern: "ruled", color: "ivory", spacing: "regular" }, pen: "sans" },
        [Sample.trip, { title: "Reading list", blocks: [{ type: "check", html: "The Overstory" }, { type: "check", html: "Piranesi", checked: true }] }])
    add({ title: "Recipes", cover: { color: "sage", material: "linen" }, binding: "spiral", paper: { pattern: "dots", color: "white", spacing: "regular" }, pen: "hand" },
        [{ title: "Shakshuka", blocks: [{ type: "h2", html: "You need" }, { type: "bullet", html: "6 eggs" }, { type: "bullet", html: "2 cans tomatoes" }, { type: "p", html: "Simmer the sauce <span style=\" font-weight:700;\">20 minutes</span> before the eggs go in." }] }])
    add({ title: "Sketches & Ideas", cover: { color: "sand", material: "kraft" }, binding: "spiral", paper: { pattern: "grid", color: "kraft", spacing: "regular" }, pen: "print" },
        [{ title: "App ideas", blocks: [{ type: "p", html: "A notebook that feels like paper." }] }])
    add({ title: "Math 101", cover: { color: "black", material: "composition" }, binding: "stitched", paper: { pattern: "graph", color: "white", spacing: "compact" }, pen: "duo" },
        [{ title: "Derivatives", blocks: [{ type: "p", html: "d/dx x<span style=\" vertical-align:super;\">2</span> = 2x" }] }])
    add({ title: "Work", cover: { color: "coral", material: "plain" }, binding: "stitched", paper: { pattern: "legal", color: "yellow", spacing: "regular" }, pen: "sans" },
        [{ title: "Standup", blocks: [{ type: "check", html: "Review the pull request" }] }])
    refresh()
  }

  function meta(nb) {
    return { id: nb.id, title: nb.title, cover: nb.cover, binding: nb.binding, paper: nb.paper, pen: nb.pen, template: nb.template, pageCount: nb.pages.length, created: nb.created, modified: nb.modified, lastPage: nb.lastPage }
  }

  function refresh() { notebooks = order.filter(function(id) { return data[id] }).map(function(id) { return meta(data[id]) }) }

  function openNotebook(id, done) { var nb = data[id]; done(nb ? copy(nb) : null) }

  function createNotebook(choice, firstPages) {
    var nb = add(choice, firstPages || [{}])
    refresh()
    return meta(nb)
  }

  function updateNotebook(id, choice) {
    var nb = data[id]
    if (!nb) return
    for (var k in choice) nb[k] = copy(choice[k])
    nb.modified = new Date().toISOString()
    refresh()
  }

  function touchNotebook(id, changes) {
    var nb = data[id]
    if (!nb) return
    for (var k in changes) nb[k] = copy(changes[k])
    refresh()
  }

  function deleteNotebook(id) { delete data[id]; order = order.filter(function(x) { return x !== id }); refresh() }

  function createPage(id, index, options) {
    var nb = data[id]
    if (!nb) return null
    var page = Library.newPage(options)
    nb.pages.splice(index, 0, copy(page))
    refresh()
    return page
  }

  // (failSaves: a save that couldn't be written, done(false).)
  property bool failSaves: false
  function savePage(id, page, done) {
    var nb = data[id]
    if (!nb || failSaves) { if (done) done(false); return }
    for (var i = 0; i < nb.pages.length; i++) if (nb.pages[i].id === page.id) nb.pages[i] = copy(page)
    nb.modified = page.modified
    refresh()
    if (done) done(true)
  }

  function deletePage(id, pageId) {
    var nb = data[id]
    if (!nb) return
    nb.pages = nb.pages.filter(function(p) { return p.id !== pageId })
    refresh()
  }

  function orderPages(id, ids) {
    var nb = data[id]
    if (!nb) return
    var byId = {}
    nb.pages.forEach(function(p) { byId[p.id] = p })
    nb.pages = ids.map(function(pid) { return byId[pid] }).filter(function(p) { return p })
  }

  function search(query, done) {
    var out = []
    order.forEach(function(id) {
      var nb = data[id]
      if (!nb) return
      nb.pages.forEach(function(p, i) {
        var score = Library.score(p.title, p.text, query)
        if (score > 0) out.push({ notebookId: id, notebookTitle: nb.title, cover: nb.cover, pageId: p.id, pageTitle: p.title || Blocks.firstLine(p.blocks) || "Untitled", pageNumber: i + 1, snippet: Library.snippet(p.text, query), score: score })
      })
    })
    out.sort(function(a, b) { return b.score - a.score })
    done(out)
  }

  function importPicture(id, path, done) { done("") }
  function pastePicture(id, done) { done("") }
  function assetUrl(id, src) { return "" }
  function copyText(text) { console.log("copy:", text.slice(0, 200)) }
  function openUrl(url) { console.log("open:", url) }
  function openLocal(path) { console.log("open:", path) }
  function openFolder() { console.log("open folder") }
  function exportNotebook(id) { exported(rootPath + "/export") }
  function quickNote(text) { console.log("quick note:", text) }
}
