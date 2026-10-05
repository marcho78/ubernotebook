import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../Workspace.js" as Workspace
import "../../Mirror.js" as Mirror

// The Markdown copy: every page of Pages (its tree as folders, links between
// the files, sketches as SVG) and every notebook's pages written to a folder,
// kept up to date as pages change, written only when they change, and never
// a file that isn't the copy's own touched.
Item {
  id: root

  FakeFiles { id: files }
  FakeStore { id: nbs }
  UberNotebook.Workspace { id: ws; files: files }

  // Store.qml as the copy uses it: the files (FakeFiles), and the notebooks (FakeStore).
  QtObject {
    id: shim
    property bool ready: true
    property var writes: []
    signal changed()
    function notebookList() { return nbs.order.map(function(id) { return { id: id, title: nbs.data[id].title, modified: nbs.data[id].modified } }) }
    function notebookPages(id, done) { done(JSON.parse(JSON.stringify(nbs.data[id].pages))) }
    function readFiles(paths, done, max) { files.readFiles(paths, done) }
    function exec(argv, done, options) { files.exec(argv, done, options) }
    function mkdirs(paths, done) { files.mkdirs(paths, done) }
    function writeFile(path, text, done) { writes = writes.concat([path]); files.writeFile(path, text, done) }
    // (Through the files helper: a link there replaced, never written through.)
    property var puts: []
    function putFile(folder, path, text, done, copy) { writes = writes.concat([folder + "/" + path]); puts = puts.concat([(copy ? "copy:" : "") + folder + "/" + path]); files.putFile(folder, path, text, done) }
    readonly property string runtimeDir: "/tmp"
    function helper(args, done, options) { files.helper(args, done, options) }
    function parseJson(text) { return files.parseJson(text) }
  }

  UberNotebook.Mirror {
    id: mirror
    workspace: ws
    store: shim
    on: false
    folder: "/tmp/copy"
    notesRoot: files.rootPath
    home: "/home/u"
    delay: 30
  }

  TestCase {
    name: "Markdown copy"

    function fresh() {
      mirror.on = false
      files.reset()
      nbs.reset()
      mirror.manifest = null
      mirror.manifestFor = ""
      mirror.pageCache = ({})
      mirror.notebookCache = ({})
      mirror.folder = "/tmp/copy"
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      ws.ensureStarted()
      shim.writes = []
      shim.puts = []
    }
    function copied() { return Object.keys(files.disk).filter(function(p) { return p.indexOf("/tmp/copy/") === 0 }).map(function(p) { return p.slice(10) }).sort() }
    function text(path) { return files.disk["/tmp/copy/" + path] }
    function syncNow() {
      var n = mirror.generation
      mirror.sync()
      tryVerify(function() { return !mirror.busy && mirror.status === "Up to date" }, 2000, "copied")
    }
    function page(title) { return Workspace.pageNamed(ws.index, title) }

    function test_1_everything_copied() {
      fresh()
      mirror.on = true
      tryVerify(function() { return mirror.status === "Up to date" }, 2000, "it copies once it's on")
      compare(shim.puts, ["copy:/tmp/copy/" + Mirror.MANIFEST], "what it wrote, kept through the files helper (the copy's folder may be a link to where you keep it)")
      var list = copied()
      verify(list.indexOf("Pages/Getting started.md") >= 0, list.join(", "))
      verify(list.indexOf("Pages/Getting started/A page inside a page.md") >= 0, "a page's pages in its folder")
      verify(list.indexOf(".uber-notebook-mirror.json") >= 0, "and what it wrote, listed")
      var nb = list.filter(function(p) { return p.indexOf("Notebooks/Field Journal/001 ") === 0 })
      compare(nb.length, 1, "a notebook's pages, in order")
      verify(list.some(function(p) { return p.indexOf("Notebooks/Recipes/001 ") === 0 && /Shakshuka\.md$/.test(p) }))
      var top = text("Pages/Getting started.md")
      verify(top.indexOf("# ") === 0, "a page as Markdown")
      verify(top.indexOf("](Getting%20started/A%20page%20inside%20a%20page.md)") >= 0, "the page inside it, a link to its file")
      verify(text(list.filter(function(p) { return p.indexOf("Notebooks/Recipes/") === 0 })[0]).indexOf("**20 minutes**") >= 0, "a notebook page's formatting")
      var man = JSON.parse(text(".uber-notebook-mirror.json"))
      compare(Object.keys(man.files).length, mirror.files)
    }

    function test_2_kept_up_to_date_and_only_what_changed() {
      fresh()
      mirror.on = true
      tryVerify(function() { return mirror.status === "Up to date" }, 2000)
      shim.writes = []
      // A page renamed: its file and its pages' folder follow; the old ones go.
      var id = page("Getting started")
      var p = ws.readPageNow(id)
      p.title = "Start here"
      p.modified = new Date(Date.now() + 1000).toISOString()
      ws.savePage(p)
      tryVerify(function() { return copied().indexOf("Pages/Start here.md") >= 0 }, 2000, "the new name")
      tryVerify(function() { return !mirror.busy }, 2000)
      var list = copied()
      verify(list.indexOf("Pages/Getting started.md") < 0, "the old file gone")
      verify(list.indexOf("Pages/Start here/A page inside a page.md") >= 0, "its pages moved with it")
      verify(list.indexOf("Pages/Getting started/A page inside a page.md") < 0)
      verify(shim.writes.every(function(w) { return w.indexOf("/tmp/copy/Notebooks/") < 0 }), "notebooks that didn't change aren't written again: " + shim.writes.join(", "))
      // Nothing changed: nothing written.
      shim.writes = []
      syncNow()
      compare(shim.writes.length, 0, "nothing new, nothing written")
      // A page in the trash: its file goes.
      ws.trashPage(page("A page inside a page"), false)
      tryVerify(function() { return copied().indexOf("Pages/Start here/A page inside a page.md") < 0 }, 2000, "trashed, gone from the copy")
    }

    // A file of the copy's, edited where it is (in Obsidian, say): never
    // written over or taken away; the page's copy goes beside it.
    function test_3b_edited_files_are_yours() {
      fresh()
      mirror.on = true
      tryVerify(function() { return mirror.status === "Up to date" }, 2000)
      var id = page("Getting started")
      var path = "Pages/Getting started.md"
      verify(text(path) !== undefined)
      files.disk["/tmp/copy/" + path] = "# My own edits\n\nkept, please"
      // The page changes in Uber Notebook: yours is kept, its copy beside it.
      var p = ws.readPageNow(id)
      p.blocks[p.content[0]].html = "Changed in Uber Notebook"
      p.modified = new Date(Date.now() + 1000).toISOString()
      ws.savePage(p)
      tryVerify(function() { return text("Pages/Getting started (2).md") !== undefined }, 3000, "the page's copy, beside it")
      tryVerify(function() { return !mirror.busy }, 2000)
      compare(text(path), "# My own edits\n\nkept, please", "yours, as you left it")
      verify(text("Pages/Getting started (2).md").indexOf("Changed in Uber Notebook") >= 0)
      // The page in the trash: its copy goes; yours stays.
      ws.trashPage(id, false)
      tryVerify(function() { return text("Pages/Getting started (2).md") === undefined }, 3000)
      compare(text(path), "# My own edits\n\nkept, please")
    }

    function test_3_never_your_files() {
      fresh()
      files.disk["/tmp/copy/Pages/Mine.md"] = "my own notes"
      files.disk["/tmp/copy/notes.txt"] = "keep me"
      var made = ws.createPage({ parent: "", title: "Mine", blocks: [{ type: "p", html: "from Uber Notebook", indent: 0 }] })
      mirror.on = true
      tryVerify(function() { return mirror.status === "Up to date" }, 2000)
      compare(text("Pages/Mine.md"), "my own notes", "a file of yours keeps its name")
      verify(text("Pages/Mine (2).md").indexOf("from Uber Notebook") >= 0, "the page takes the next one")
      ws.trashPage(made.id, false)
      tryVerify(function() { return text("Pages/Mine (2).md") === undefined }, 2000, "the copy's own file goes")
      compare(text("Pages/Mine.md"), "my own notes", "yours stays")
      compare(text("notes.txt"), "keep me")
      // A manifest that names files that aren't the copy's: never touched.
      files.disk["/tmp/copy/.uber-notebook-mirror.json"] = JSON.stringify({ files: { "notes.txt": "x", "../escape.md": "y" } })
      mirror.manifest = null
      mirror.manifestFor = ""
      syncNow()
      compare(text("notes.txt"), "keep me")
    }

    function test_4_sketches_and_pictures() {
      fresh()
      var made = ws.createPage({ parent: page("Getting started"), title: "Board", blocks: [
        { type: "sketch", sketch: { height: 300, strokes: [{ tool: "pen", color: "blue", width: 4, points: [1, 2, 30, 40] }] }, indent: 0 },
        { type: "image", src: "assets/pic.png", indent: 0 }] })
      var sketchId = Workspace.flatten(made)[0].uid
      mirror.on = true
      tryVerify(function() { return mirror.status === "Up to date" }, 2000)
      var md = text("Pages/Getting started/Board.md")
      verify(md !== undefined, copied().join(", "))
      verify(md.indexOf("![Sketch](../../sketches/" + sketchId + ".svg)") >= 0, md)
      verify(md.indexOf("![](../../assets/pic.png)") >= 0, "a picture, from where the file is")
      verify(text("sketches/" + sketchId + ".svg").indexOf("<svg") === 0)
      // The sketch taken off: its SVG goes too.
      var p = ws.readPageNow(made.id)
      p.content = p.content.slice(1)
      delete p.blocks[sketchId]
      p.modified = new Date(Date.now() + 1000).toISOString()
      ws.savePage(p)
      tryVerify(function() { return text("sketches/" + sketchId + ".svg") === undefined }, 2000, "its SVG gone")
    }

    function test_5_not_in_the_wrong_folder() {
      fresh()
      mirror.folder = files.rootPath
      mirror.on = true
      tryVerify(function() { return mirror.problem !== "" }, 2000)
      verify(mirror.status.indexOf("Not copying") === 0, mirror.status)
      compare(Object.keys(files.disk).filter(function(p) { return /\.md$/.test(p) }).length, 0, "nothing written")
      mirror.folder = files.rootPath + "/Pages"
      mirror.sync()
      verify(mirror.problem !== "", "not in Uber Notebook's own folders")
      mirror.folder = "/tmp/copy"
      mirror.sync()
      tryVerify(function() { return mirror.status === "Up to date" }, 2000, "a good folder: it copies")
      mirror.on = false
      compare(mirror.status, "")
    }

    // Many pages syncing one big one: what synced blocks write, in all the
    // copy's files of a pass, within one budget.
    function test_5c_synced_blocks_within_one_budget() {
      fresh()
      var sid = ws.newSyncedPage([{ type: "p", html: new Array(100001).join("y"), indent: 0 }])
      for (var n = 0; n < 10; n++) {
        var list = []
        for (var i = 0; i < 5; i++) list.push({ type: "synced", indent: 0, data: { page: sid } })
        ws.createPage({ parent: "", title: "Syncs " + n, blocks: list })
      }
      mirror.syncedMax = 1000000
      try {
        mirror.on = true
        tryVerify(function() { return mirror.status === "Up to date" }, 5000, mirror.status)
        var mds = copied().filter(function(p) { return /^Pages\/Syncs \d\.md$/.test(p) })
        compare(mds.length, 10)
        var total = mds.reduce(function(t, p) { return t + text(p).length }, 0)
        verify(total < 1000000 + 100000 + 50000, "within it: " + total)
        verify(mds.some(function(p) { return text(p).indexOf("*(A synced block: open the page in Uber Notebook)*") >= 0 }), "past it: said")
      } finally {
        mirror.syncedMax = 16000000
        mirror.on = false
      }
    }

    // Its list of what it wrote not kept: said, not "Up to date".
    function test_5b_its_list_not_kept_is_said() {
      fresh()
      files.failPut = true
      try {
        mirror.on = true
        tryVerify(function() { return mirror.status.indexOf("its list of what it wrote couldn't be kept") > 0 }, 2000, mirror.status)
      } finally {
        files.failPut = false
        mirror.on = false
      }
    }

    // Another profile opened: what it read of these notes isn't kept for
    // those (their pages may have the same ids), and a copy that had begun
    // stops, writing nothing.
    function test_6_another_profile_meanwhile() {
      fresh()
      mirror.on = true
      tryVerify(function() { return mirror.status === "Up to date" }, 2000)
      verify(Object.keys(mirror.pageCache).length > 0 && Object.keys(mirror.notebookCache).length > 0)
      try {
        mirror.notesRoot = "/tmp/other-notes"
        compare(Object.keys(mirror.pageCache).length, 0, "its pages: not kept for another's")
        compare(Object.keys(mirror.notebookCache).length, 0, "nor its notebooks")
      } finally {
        mirror.notesRoot = Qt.binding(function() { return files.rootPath })
      }
      fresh()
      files.holdReads = true
      try {
        mirror.on = true
        tryVerify(function() { return mirror.busy }, 2000, "a copy begun")
        mirror.notesRoot = "/tmp/other-notes"
        tryVerify(function() { files.answerReads(); return !mirror.busy }, 3000, "and over")
        compare(copied(), [], "nothing of these notes written for another profile")
        mirror.on = false
      } finally {
        files.holdReads = false
        files.answerReads()
        mirror.on = false
        mirror.notesRoot = Qt.binding(function() { return files.rootPath })
      }
    }
  }
}
