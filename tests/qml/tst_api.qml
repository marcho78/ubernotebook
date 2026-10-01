import QtQuick
import QtTest
import "../.." as Omanote
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html

// The commands agents and scripts use (Api.qml), on the real workspace store
// with files in memory, and the Pages view beside them as the window has it.
Item {
  id: root
  width: 1320
  height: 900

  property string inboxSeen: ""

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }

  Omanote.Workspace {
    id: ws
    files: files
  }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  // What Notebook.qml gives the commands while its window is there.
  QtObject {
    id: ui
    function saveNow() { view.commit() }
    function appendToOpenPage(id, blocks) { return view.appendFromCommand(id, blocks) }
    function addPageBlock(parentId, childId) { return view.pageAddedInto(parentId, childId) }
    function replaceInOpenPage(id, change) { return view.replaceFromCommand(id, change) }
    function insertInOpenPage(id, change) { return view.insertFromCommand(id, change) }
    function trashPage(id) { view.trashPage(id); return true }
  }

  Omanote.Api {
    id: api
    workspace: ws
    files: files
    ui: ui
    onInboxMade: function(id) { root.inboxSeen = id }
  }

  TestCase {
    name: "Commands"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      view.history = []
      view.historyAt = -1
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      ws.ensureStarted()
      api.inbox = ""
      root.inboxSeen = ""
    }

    function json(text) { return JSON.parse(text) }
    function file(name, text) {
      var path = "/tmp/in/" + name
      files.disk[path] = text
      return path
    }
    function fileOf(id) { return files.parseJson(files.disk[Workspace.pageFile(files.rootPath, id)] || "") }
    function kinds(page) { return Workspace.flatten(page).map(function(b) { return b.type + ":" + b.indent + ":" + Html.plainText(b.html || "") }) }
    function named(title) { return Workspace.pageNamed(ws.index, title) }

    function test_1_help_and_list() {
      fresh()
      var help = json(api.help())
      verify(help.ok)
      verify(help.commands.some(function(c) { return c.use.indexOf("add ") === 0 }))
      var pages = json(api.list())
      compare(pages.map(function(p) { return p.title }), ["Getting started", "A page inside a page"])
      compare(pages[1].path, "Getting started", "each with the pages it's in")
      verify(Workspace.isUuid(pages[0].id))
      ws.ready = false
      compare(json(api.list()).ok, false, "not before the pages are loaded")
      ws.ready = true
    }

    function test_2_add_goes_to_the_inbox() {
      fresh()
      var r = json(api.add("Groceries", file("g.md", "- [ ] milk\n- [x] eggs\n\n```bash\nls -la\n```")))
      verify(r.ok, JSON.stringify(r))
      compare(r.path, "Inbox / Groceries")
      verify(Workspace.isUuid(api.inbox))
      compare(root.inboxSeen, api.inbox, "the Inbox is kept, as a setting")
      compare(ws.index.pages[r.id].parent, api.inbox)
      var page = fileOf(r.id)
      compare(kinds(page).join("|"), "check:0:milk|check:0:eggs|code:0:ls -la|p:0:")
      verify(page.blocks[page.content[1]].checked, "ticked as it was")
      compare(page.blocks[page.content[2]].lang, "Bash", "code in its language")
      compare(fileOf(api.inbox).blocks[r.id].type, "page", "its block is on the Inbox")
      var r2 = json(api.add("", file("h.md", "# From its heading\n\nSome text")))
      compare(r2.title, "From its heading", "no title: the Markdown's heading")
      compare(ws.index.pages[r2.id].parent, api.inbox, "the same Inbox")
      compare(Workspace.allPages(ws.index).filter(function(p) { return p.title === "Inbox" }).length, 1)
      // The Inbox in the trash: there's a new one.
      var old = api.inbox
      ws.trashPage(old, false)
      var r3 = json(api.add("Third", file("t.md", "x")))
      verify(api.inbox !== old)
      compare(ws.index.pages[r3.id].parent, api.inbox)
    }

    function test_3_add_inside_a_page_with_links_dates_and_reminders() {
      fresh()
      var home = named("Getting started")
      var inner = named("A page inside a page")
      var r = json(api.addTo(home, "Trip", file("trip.md",
        "See [[a page inside a page]] and [[Nobody]]. Due [@Fri 2 Oct](omanote://date/2026-10-02), and [\u23f0 Fri 2 Oct 9:30](omanote://remind/2026-10-02T09:30)")))
      verify(r.ok, JSON.stringify(r))
      compare(r.path, "Getting started / Trip")
      compare(ws.index.pages[r.id].parent, home)
      compare(fileOf(home).blocks[r.id].type, "page", "its block is on the page it's in")
      var html = fileOf(r.id).blocks[fileOf(r.id).content[0]].html
      verify(html.indexOf("omanote://page/" + inner) >= 0, "a [[link]] to the page called that: " + html)
      verify(html.indexOf("Nobody") >= 0 && html.indexOf("omanote://page/\"") < 0, "and text, when there's none")
      verify(html.indexOf("omanote://date/2026-10-02") >= 0 && html.indexOf("omanote://remind/2026-10-02T09:30") >= 0)
      compare(ws.index.pages[r.id].reminders.length, 1, "the reminder is kept")
      verify(Workspace.backlinks(ws.index, inner).indexOf(r.id) >= 0, "and the link, for backlinks")
      var top = json(api.addTo("", "At the top", file("top.md", "x")))
      compare(ws.index.pages[top.id].parent, "")
      compare(json(api.addTo("nonsense", "x", file("n.md", "x"))).ok, false)
      compare(json(api.add("x", "/tmp/in/missing.md")).ok, false, "a file that isn't there")
      compare(json(api.add("x", "relative.md")).ok, false, "a path that isn't whole")
      files.disk["/tmp/in/big.md"] = new Array(2 * 1024 * 1024 + 10).join("x")
      compare(json(api.add("x", "/tmp/in/big.md")).ok, false, "over 2 MB")
    }

    function test_4_find_and_read() {
      fresh()
      var r = json(api.add("Lisbon", file("l.md", "Trams, **pastries** and the sea\n\n- [ ] tickets")))
      var found = json(api.find("pastries sea"))
      compare(found[0].id, r.id)
      verify(found[0].snippet.indexOf("pastries") >= 0)
      compare(found[0].path, "Inbox")
      // Pages from before, their words read in the background.
      tryVerify(function() { return json(api.find("toggles")).some(function(p) { return p.title === "Getting started" }) }, 2000)
      compare(json(api.find("")).ok, false)
      compare(api.read(r.id), "# Lisbon\n\nTrams, **pastries** and the sea\n\n- [ ] tickets\n")
      // Read from its file, when it wasn't written this session.
      ws.written = ({})
      verify(api.read(named("Getting started")).indexOf("# \u{1f44b} Getting started") === 0)
      verify(api.read(named("Getting started")).indexOf("(omanote://page/" + named("A page inside a page") + ")") > 0, "pages in it, by their ids")
      compare(json(api.read("nonsense")).ok, false)
    }

    function test_5_append() {
      fresh()
      var r = json(api.add("Log", file("a.md", "first")))
      // Not open: into its file, before the empty line it ends with.
      var a = json(api.append(r.id, file("b.md", "- second\n  - inside\n- third")))
      compare(a.added, 3)
      compare(kinds(fileOf(r.id)).join("|"), "p:0:first|bullet:0:second|bullet:1:inside|bullet:0:third|p:0:")
      // Open in the window: it adds them itself, the cursor where it was, and Undo takes them back.
      view.open(r.id)
      tryVerify(function() { return view.page && view.page.id === r.id }, 2000)
      var e = view.editor
      e.focusBlock(e.uidAt(0), 0)
      keyClick("x")
      compare(json(api.append(r.id, file("c.md", "fourth"))).ok, true)
      var texts = e.serialize().map(function(b) { return Html.plainText(b.html || "") })
      compare(texts.slice(-2).join("|"), "fourth|")
      compare(e.focusUid, e.uidAt(0), "the cursor stays where you were")
      compare(Html.plainText(fileOf(r.id).blocks[fileOf(r.id).content[0]].html), "xfirst", "what you typed is kept too")
      e.undo()
      verify(e.serialize().every(function(b) { return Html.plainText(b.html || "") !== "fourth" }), "Undo takes it back")
      // Typing on one page while a command adds to another: both are kept.
      var other = json(api.add("Other", file("o.md", "one")))
      e.focusBlock(e.uidAt(0), 0)
      keyClick("y")
      compare(json(api.append(other.id, file("d.md", "two"))).ok, true)
      compare(Html.plainText(fileOf(r.id).blocks[fileOf(r.id).content[0]].html), "yxfirst")
      compare(kinds(fileOf(other.id)).join("|"), "p:0:one|p:0:two|p:0:")
      // A locked page isn't changed, open or not.
      view.setFormat("locked", true)
      compare(json(api.append(r.id, file("e.md", "no"))).ok, false)
      view.open(other.id)
      tryVerify(function() { return view.page && view.page.id === other.id }, 2000)
      compare(json(api.append(r.id, file("e.md", "no"))).ok, false)
      compare(json(api.append(other.id, file("empty.md", ""))).ok, false, "nothing to add")
      compare(json(api.append("nonsense", file("e.md", "no"))).ok, false)
    }

    function test_6_pages_made_inside_the_open_page() {
      fresh()
      var home = named("Getting started")
      view.open(home)
      tryVerify(function() { return view.page && view.page.id === home }, 2000)
      var r = json(api.addTo(home, "Child", file("c.md", "x")))
      compare(view.editor.typeOf(r.id), "page", "its block is on the open page")
      view.commit()
      compare(fileOf(home).blocks[r.id].type, "page")
      compare(ws.index.pages[home].children.indexOf(r.id) >= 0, true)
    }

    function test_7_trash() {
      fresh()
      var r = json(api.add("Old", file("o.md", "x")))
      var t = json(api.trash(r.id))
      verify(t.ok)
      compare(ws.index.pages[r.id].trashed, true, "in the trash, where it can be put back")
      tryVerify(function() { return !fileOf(api.inbox).blocks[r.id] }, 2000, "and off the Inbox")
      compare(json(api.trash(r.id)).ok, false, "it's not there to trash again")
      verify(files.disk[Workspace.pageFile(files.rootPath, r.id)] !== undefined, "nothing is deleted for good")
    }

    function test_9_blocks_replace_insert_after() {
      fresh()
      var r = json(api.add("Plan", file("p.md", "intro\n\n- one\n  - inside one\n- two\n\n```python\nx = 1\n```")))
      var list = json(api.blocks(r.id))
      compare(list.map(function(b) { return b.type + ":" + b.depth + ":" + (b.text || "") }).join("|"),
        "p:0:intro|bullet:0:one|bullet:1:inside one|bullet:0:two|code:0:x = 1|p:0:")
      compare(list[4].lang, "Python")
      verify(list.every(function(b) { return Workspace.isUuid(b.id) }))
      // Not open: on its file.
      var one = list[1].id
      var rep = json(api.replace(r.id, one, file("r.md", "- [x] one, done\n  - with a note")))
      verify(rep.ok, JSON.stringify(rep))
      compare(json(api.blocks(r.id)).map(function(b) { return b.type + ":" + b.depth + ":" + (b.text || "") }).join("|"),
        "p:0:intro|check:0:one, done|bullet:1:with a note|bullet:0:two|code:0:x = 1|p:0:", "the block and what was inside it")
      var two = json(api.blocks(r.id))[3].id
      compare(json(api.insertAfter(r.id, two, file("i.md", "- three"))).ok, true)
      compare(json(api.blocks(r.id))[4].text, "three", "after it, as deep as it is")
      // Open in the window: the view does it, and Undo takes it back.
      view.open(r.id)
      tryVerify(function() { return view.page && view.page.id === r.id }, 2000)
      var intro = json(api.blocks(r.id))[0].id
      compare(json(api.replace(r.id, intro, file("n.md", "## New intro"))).ok, true)
      compare(view.editor.typeOf(view.editor.uidAt(0)), "h2")
      view.editor.undo()
      compare(Html.plainText(view.editor.blockAt(0).html), "intro", "Undo takes it back")
      compare(json(api.insertAfter(r.id, intro, file("a.md", "after the intro"))).ok, true)
      compare(Html.plainText(view.editor.blockAt(1).html), "after the intro")
      // What it won't do.
      compare(json(api.replace(r.id, "nonsense", file("x.md", "x"))).ok, false, "a block that isn't there")
      compare(json(api.replace(r.id, intro, file("e.md", ""))).ok, false, "nothing to put in")
      compare(json(api.replace("nonsense", intro, file("x.md", "x"))).ok, false)
      view.setFormat("locked", true)
      compare(json(api.replace(r.id, intro, file("x.md", "x"))).ok, false, "a locked page")
      compare(json(api.insertAfter(r.id, intro, file("x.md", "x"))).ok, false)
      view.setFormat("locked", false)
      // A block with a page in it, and columns.
      var home = named("Getting started")
      var homeBlocks = json(api.blocks(home))
      var pageBlock = homeBlocks.filter(function(b) { return b.type === "page" })[0]
      compare(pageBlock.title, "A page inside a page", "a page's block says which page")
      compare(json(api.replace(home, pageBlock.id, file("x.md", "x"))).ok, false, "not a page's block")
      var c = json(api.add("Cols", file("c.md", "x")))
      view.open(c.id)
      tryVerify(function() { return view.page && view.page.id === c.id }, 2000)
      view.editor.insertColumns(view.editor.uidAt(0), 2)
      view.commit()
      var cols = json(api.blocks(c.id)).filter(function(b) { return b.type === "columns" })[0]
      compare(json(api.replace(c.id, cols.id, file("x.md", "x"))).ok, false, "not columns themselves")
    }

    function test_8_without_the_window() {
      fresh()
      api.ui = null
      var home = named("Getting started")
      var r = json(api.addTo(home, "Quiet", file("q.md", "x")))
      compare(fileOf(home).blocks[r.id].type, "page")
      compare(json(api.append(r.id, file("a.md", "more"))).added, 1)
      compare(json(api.trash(r.id)).ok, true)
      api.ui = ui
    }
  }
}
