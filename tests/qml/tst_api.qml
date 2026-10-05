import QtQuick
import QtTest
import "../.." as UberNotebook
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

  UberNotebook.Workspace {
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
    function askAgentPermission(req) { return view.askAgentPermission(req) }
  }

  UberNotebook.Api {
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
      api.agentScope = null
      api.caller = null
      api.prefetched = ({})
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

    function test_11_a_quick_note_into_the_inbox() {
      fresh()
      var r = json(api.quickPage("Groceries\n[] milk\n[x] eggs\nsee [[Getting started]]\n**for Sunday**"))
      verify(r.ok, JSON.stringify(r))
      compare(r.title, "Groceries", "its first line is the title")
      compare(r.path, "Inbox / Groceries", "in the Inbox")
      compare(ws.index.pages[r.id].parent, api.inbox)
      var page = fileOf(r.id)
      compare(kinds(page).join("|"), "check:0:milk|check:0:eggs|p:0:see Getting started|p:0:for Sunday|p:0:")
      verify(page.blocks[page.content[1]].checked, "ticked as it was")
      verify(page.blocks[page.content[2]].html.indexOf("uber-notebook://page/" + named("Getting started")) >= 0, "a link to the page")
      verify(page.blocks[page.content[3]].html.indexOf("font-weight:700") >= 0, "Markdown")
      compare(fileOf(api.inbox).blocks[r.id].type, "page", "its block is on the Inbox")
      // One line: a page with that title, to write in.
      var one = json(api.quickPage("Call the dentist"))
      compare(one.title, "Call the dentist")
      compare(kinds(fileOf(one.id)).join("|"), "p:0:")
      // A list: it names the page, and stays in it.
      var list = json(api.quickPage("- [ ] pay rent\n- [ ] water plants"))
      compare(list.title, "pay rent")
      compare(kinds(fileOf(list.id)).join("|"), "check:0:pay rent|check:0:water plants|p:0:")
      compare(json(api.quickPage("   \n ")).ok, false, "nothing in it")
      // The Inbox open in the window: the page shows up on it.
      view.open(api.inbox)
      tryVerify(function() { return view.page && view.page.id === api.inbox }, 2000)
      var r4 = json(api.quickPage("Seen at once"))
      verify(view.editor.serialize().some(function(b) { return b.type === "page" && b.uid === r4.id }), "on the open Inbox")
      ws.ready = false
      compare(json(api.quickPage("later")).ok, false, "not before the pages are loaded")
      ws.ready = true
    }

    function test_12_tags() {
      fresh()
      var r = json(api.add("Errands", file("e.md", "- [ ] milk #errand\n- [x] post #Errand #home\n\nPlan the week #planning\n\n`#notatag`")))
      verify(r.ok, JSON.stringify(r))
      var list = json(api.tags())
      compare(list.map(function(t) { return t.name }), ["errand", "home", "planning"], "the tags an agent's Markdown had")
      compare(list[0].blocks, 2)
      compare(list[0].tag, "#errand")
      var blocks = json(api.tagged("#errand"))
      compare(blocks.length, 2)
      compare(blocks[0].page, r.id)
      compare(blocks[0].text, "milk #errand", "as Markdown, the tag as its words")
      compare(blocks[1].checked, true)
      compare(json(api.tagged("not a tag")).ok, false)
      compare(json(api.tagged("nothing")).length, 0)
      // Colors: set by name or hex, a tag inside another takes its color.
      compare(json(api.tagColor("#errand", "Blue")).color, "blue")
      compare(json(api.tagColor("#home", "#FF8800")).color, "#ff8800")
      compare(json(api.tagColor("#home", "neon")).ok, false)
      var add2 = json(api.add("More", file("m.md", "x #errand/shop")))
      var withColors = json(api.tags())
      var shop = withColors.filter(function(t) { return t.name === "errand/shop" })[0]
      compare(shop.color, "blue")
      compare(shop.colorFrom, "#errand")
      compare(json(api.tagColor("#errand", "")).color, "")
      compare(ws.index.tagColors.errand, undefined, "none")
      // read gives them back as Markdown's #tags.
      verify(api.read(r.id).indexOf("- [ ] milk #errand") >= 0)
    }

    function test_13_projects_and_the_archive() {
      fresh()
      var r = json(api.add("", file("p.md", "---\nstatus: active\ndue: 2026-12-01\n---\n\n# Launch\n\n- [x] post\n- [ ] video")))
      verify(r.ok, JSON.stringify(r))
      compare(fileOf(r.id).project.status, "active", "front matter makes it a project")
      var list = json(api.projects())
      compare(list.length, 1)
      compare(list[0].title, "Launch")
      compare(list[0].due, "2026-12-01")
      compare(list[0].progress, "1/2")
      // Changed: its status, its due date kept; then none.
      compare(json(api.project(r.id, "paused", "-")).project.status, "paused")
      compare(fileOf(r.id).project.due, "2026-12-01", "kept")
      compare(json(api.project(r.id, "", "2027-01-15")).project.due, "2027-01-15")
      compare(json(api.project(r.id, "bogus", "")).ok, false)
      compare(json(api.project(r.id, "", "next week")).ok, false)
      var other = json(api.add("Plain", file("q.md", "x")))
      compare(json(api.project(other.id, "planning", "")).project.status, "planning", "a page made a project")
      compare(json(api.project(other.id, "none", "")).project, null, "and a page again")
      compare(fileOf(other.id).project, undefined)
      // The archive.
      verify(json(api.archive(r.id)).ok)
      compare(json(api.projects()).length, 0, "not on the list in the archive")
      verify(api.read(r.id).indexOf("status: paused") >= 0, "still read, its status as front matter")
      verify(json(api.archive(r.id, false)).ok)
      compare(json(api.projects()).length, 1)
    }

    function test_3_add_inside_a_page_with_links_dates_and_reminders() {
      fresh()
      var home = named("Getting started")
      var inner = named("A page inside a page")
      var r = json(api.addTo(home, "Trip", file("trip.md",
        "See [[a page inside a page]] and [[Nobody]]. Due [@Fri 2 Oct](uber-notebook://date/2026-10-02), and [\u23f0 Fri 2 Oct 9:30](uber-notebook://remind/2026-10-02T09:30)")))
      verify(r.ok, JSON.stringify(r))
      compare(r.path, "Getting started / Trip")
      compare(ws.index.pages[r.id].parent, home)
      compare(fileOf(home).blocks[r.id].type, "page", "its block is on the page it's in")
      var html = fileOf(r.id).blocks[fileOf(r.id).content[0]].html
      verify(html.indexOf("uber-notebook://page/" + inner) >= 0, "a [[link]] to the page called that: " + html)
      verify(html.indexOf("Nobody") >= 0 && html.indexOf("uber-notebook://page/\"") < 0, "and text, when there's none")
      verify(html.indexOf("uber-notebook://date/2026-10-02") >= 0 && html.indexOf("uber-notebook://remind/2026-10-02T09:30") >= 0)
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
      verify(api.read(named("Getting started")).indexOf("(uber-notebook://page/" + named("A page inside a page") + ")") > 0, "pages in it, by their ids")
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

    function test_10_an_agent_makes_a_mind_map() {
      fresh()
      var r = json(api.add("", file("m.md", "# Launch plan\n\n```mindmap\nLaunch\n  Marketing\n    Blog post\n  Engineering\n```\n\nNotes under it.")))
      verify(r.ok, JSON.stringify(r))
      var list = json(api.blocks(r.id))
      compare(list[0].type, "mindmap", "a mind map block on the page")
      compare(list[0].text, "Launch\n  Marketing\n    Blog post\n  Engineering")
      verify(api.read(r.id).indexOf("```mindmap\nLaunch\n  Marketing\n    Blog post\n  Engineering\n```") >= 0, "read gives it back the same way")
      verify(json(api.find("blog post")).some(function(p) { return p.id === r.id }), "found by its ideas")
      // Changed by the agent while the page is open: one step you can undo.
      view.open(r.id)
      tryVerify(function() { return view.page && view.page.id === r.id }, 2000)
      compare(json(api.replace(r.id, list[0].id, file("m2.md", "```mermaid\nmindmap\n  root((Launch))\n    Marketing\n    Engineering\n    Support\n```"))).ok, true)
      var b = view.editor.blockAt(0)
      compare(b.type, "mindmap")
      compare(b.outline, "Launch\n  Marketing\n  Engineering\n  Support")
      view.editor.undo()
      compare(view.editor.blockAt(0).outline, "Launch\n  Marketing\n    Blog post\n  Engineering")
    }

    // The Library for agents: links (in text too) and files, by kind and
    // words, with a file's path on disk.
    function test_11_the_library() {
      fresh()
      var r = json(api.add("Reading", file("r.md", "Start with [the guide](https://example.com/guide).\n\nThen the rest.")))
      verify(r.ok, JSON.stringify(r))
      ws.createPage({ parent: "", title: "Specs", blocks: [{ type: "file", indent: 0, data: { src: "assets/file-20261001-090000-abc-spec.pdf", name: "Spec.pdf", size: 52311, kind: "pdf" } }] })
      var all = json(api.library("", ""))
      verify(all.some(function(x) { return x.kind === "link" && x.url === "https://example.com/guide" && x.title === "the guide" && x.page === r.id && x.pageTitle === "Reading" }), JSON.stringify(all))
      var pdfs = json(api.library("files", "spec"))
      compare(pdfs.length, 1)
      compare(pdfs[0].detail, "PDF  \u00b7  51 KB")
      verify(/\/Pages\/assets\/file-20261001-090000-abc-spec\.pdf$/.test(pdfs[0].file), pdfs[0].file)
      compare(json(api.library("link", "nothing like it")).length, 0)
      compare(json(api.library("rockets", "")).ok, false)
    }

    // A page's name, place, icon, cover, lock, Favorites.
    function test_14_pages_renamed_moved_and_dressed() {
      fresh()
      var a = json(api.add("Alpha", file("a.md", "x")))
      var b = json(api.add("Beta", file("b.md", "y")))
      var r = json(api.rename(a.id, "  Alpha two "))
      verify(r.ok, JSON.stringify(r))
      compare(r.title, "Alpha two")
      compare(ws.index.pages[a.id].title, "Alpha two")
      compare(fileOf(a.id).title, "Alpha two")
      // Inside Beta: off the Inbox, on Beta.
      var m = json(api.move(a.id, b.id, ""))
      verify(m.ok, JSON.stringify(m))
      compare(ws.index.pages[a.id].parent, b.id)
      compare(m.path, "Inbox / Beta / Alpha two")
      tryVerify(function() { var f = fileOf(b.id); return f && f.blocks[a.id] && f.blocks[a.id].type === "page" }, 2000, "its block on Beta")
      tryVerify(function() { return !fileOf(api.inbox).blocks[a.id] }, 2000, "and off the Inbox")
      compare(json(api.move(b.id, a.id, "")).ok, false, "not inside itself")
      compare(json(api.move(a.id, "nonsense", "")).ok, false)
      compare(json(api.move(a.id, "top", "x")).ok, false)
      // The top of Pages, first.
      compare(json(api.move(a.id, "top", "0")).ok, true)
      compare(ws.index.top[0], a.id)
      compare(ws.index.pages[a.id].parent, "")
      tryVerify(function() { return !fileOf(b.id).blocks[a.id] }, 2000, "off Beta")
      // Icon and cover.
      compare(json(api.icon(a.id, "\u{1f680}")).icon, "\u{1f680}")
      compare(fileOf(a.id).icon, "\u{1f680}")
      compare(ws.index.pages[a.id].icon, "\u{1f680}")
      compare(json(api.icon(a.id, "abc")).ok, false, "an emoji")
      compare(json(api.icon(a.id, "")).icon, "")
      compare(json(api.cover(a.id, "gradient:3")).ok, true)
      compare(fileOf(a.id).cover, "gradient:3")
      compare(json(api.cover(a.id, "gradient:12")).ok, false)
      compare(json(api.cover(a.id, "")).cover, "")
      // Locked: nothing changes it.
      compare(json(api.lock(a.id, "true")).locked, true)
      compare(fileOf(a.id).format.locked, true)
      compare(json(api.rename(a.id, "Nope")).ok, false, "a locked page keeps its name")
      compare(json(api.icon(a.id, "\u{1f680}")).ok, false)
      compare(json(api.lock(a.id, "false")).locked, false)
      compare(json(api.rename(a.id, "Alpha")).ok, true)
      // Favorites.
      compare(json(api.favorite(a.id, "true")).favorite, true)
      verify(ws.isFavorite(a.id))
      compare(json(api.favorite(a.id, "true")).ok, true, "twice: still one")
      compare(ws.index.favorites.filter(function(x) { return x === a.id }).length, 1)
      compare(json(api.favorite(a.id, "false")).favorite, false)
      verify(!ws.isFavorite(a.id))
      compare(json(api.rename("nonsense", "x")).ok, false)
    }

    // The trash, copies, templates.
    function test_15_trash_copies_and_templates() {
      fresh()
      var r = json(api.add("Recipe", file("r.md", "- [ ] flour")))
      var kid = json(api.addTo(r.id, "Notes", file("n.md", "inside")))
      compare(json(api.trashed()).length, 0)
      compare(json(api.trash(r.id)).ok, true)
      var t = json(api.trashed())
      compare(t.length, 1, "the page, not the pages in it too")
      compare(t[0].id, r.id)
      compare(t[0].in, api.inbox)
      var back = json(api.restore(r.id))
      verify(back.ok, JSON.stringify(back))
      compare(ws.index.pages[r.id].trashed, false)
      compare(ws.index.pages[kid.id].parent, r.id, "with the pages in it")
      tryVerify(function() { return !!fileOf(api.inbox).blocks[r.id] }, 2000, "back on the Inbox")
      compare(json(api.restore(r.id)).ok, false, "not in the trash")
      // A copy, right after it, with the page in it.
      var d = json(api.duplicate(r.id))
      verify(d.ok, JSON.stringify(d))
      var sibs = ws.index.pages[api.inbox].children
      compare(sibs.indexOf(d.id), sibs.indexOf(r.id) + 1)
      compare(ws.index.pages[d.id].children.length, 1)
      verify(ws.index.pages[d.id].children[0] !== kid.id, "the page in it, copied")
      compare(kinds(fileOf(d.id))[0], "check:0:flour")
      tryVerify(function() { return !!fileOf(api.inbox).blocks[d.id] }, 2000, "its block on the Inbox")
      // A template.
      var tpl = json(api.makeTemplate(r.id))
      verify(tpl.ok, JSON.stringify(tpl))
      compare(tpl.title, "Recipe")
      compare(ws.index.pages[tpl.id].template, true)
      verify(json(api.templates()).some(function(x) { return x.id === tpl.id }))
      compare(json(api.duplicate("nonsense")).ok, false)
    }

    // A page's history: its versions, one read, one put back.
    function test_16_history() {
      fresh()
      var r = json(api.add("Diary", file("d.md", "first words")))
      var first = api.history(r.id)
      tryVerify(function() { return ws.versionNames[r.id] !== undefined }, 2000, "read for next time")
      compare(json(api.append(r.id, file("m.md", "second words"))).ok, true)
      var h = []
      tryVerify(function() { h = json(api.history(r.id)); return Array.isArray(h) && h.length >= 1 }, 2000)
      var oldest = h[h.length - 1]
      verify(oldest.kept !== "", JSON.stringify(oldest))
      var md = api.version(r.id, oldest.name)
      verify(md.indexOf("first words") >= 0 && md.indexOf("second words") < 0, md)
      var rv = json(api.restoreVersion(r.id, oldest.name))
      verify(rv.ok, JSON.stringify(rv))
      var now = kinds(fileOf(r.id)).join("|")
      verify(now.indexOf("first words") >= 0 && now.indexOf("second words") < 0, now)
      tryVerify(function() { return json(api.history(r.id)).length > h.length }, 2000, "the page as it was, kept too")
      compare(json(api.version(r.id, "nonsense")).ok, false)
      compare(json(api.restoreVersion(r.id, "2020-01-01T00-00-00-000Z.json")).ok, false)
      // The pages in it stay.
      var kid = json(api.addTo(r.id, "Inside", file("k.md", "x")))
      verify(kid.ok)
      compare(json(api.restoreVersion(r.id, oldest.name)).ok, true)
      verify(!!fileOf(r.id).blocks[kid.id], "a page in it isn't lost")
    }

    // Blocks ticked, colored, taken off.
    function test_17_blocks_ticked_colored_taken_off() {
      fresh()
      var r = json(api.add("Todo", file("t.md", "- [ ] call Sam\n- [ ] book flights\n\nA paragraph\n\n```board\n## To do\n- x\n```")))
      var list = json(api.blocks(r.id))
      compare(json(api.check(r.id, list[0].id, "true")).checked, true)
      compare(fileOf(r.id).blocks[list[0].id].checked, true)
      compare(json(api.check(r.id, list[2].id, "true")).ok, false, "not a to-do")
      compare(json(api.color(r.id, list[2].id, "blue_background")).ok, true)
      compare(fileOf(r.id).blocks[list[2].id].color, "blue_background")
      compare(json(api.color(r.id, list[2].id, "chartreuse")).ok, false)
      compare(json(api.color(r.id, list[2].id, "#ff8800")).ok, false, "text takes Pages' colors")
      // A block's id is one of the page's: never what every object has.
      for (var bad of ["__proto__", "constructor", "toString", "hasOwnProperty"]) {
        compare(json(api.color(r.id, bad, "blue")).ok, false, bad)
        compare(json(api.check(r.id, bad, "true")).ok, false, bad)
        compare(json(api.removeBlock(r.id, bad)).ok, false, bad)
      }
      compare(({}).color, undefined, "nothing set on every object")
      compare(({}).checked, undefined)
      compare(json(api.color(r.id, list[2].id, "")).ok, true)
      compare(fileOf(r.id).blocks[list[2].id].color, undefined)
      // A card's: its own, one of each.
      compare(json(api.color(r.id, list[3].id, "#ff8800_background")).ok, true)
      compare(json(api.color(r.id, list[3].id, "green")).ok, true)
      var data = fileOf(r.id).blocks[list[3].id].data
      compare(data.background, "#ff8800")
      compare(data.color, "green")
      compare(data.columns[0].cards[0].text, "x", "the board as it was")
      compare(json(api.removeBlock(r.id, list[1].id)).ok, true)
      verify(json(api.blocks(r.id)).every(function(b) { return b.text !== "book flights" }))
      // Open in the window: shown as it is now.
      view.open(r.id)
      tryVerify(function() { return view.page && view.page.id === r.id }, 2000)
      compare(json(api.check(r.id, list[0].id, "false")).ok, true)
      tryVerify(function() { return view.editor.blockAt(0).checked === false }, 2000)
      view.setFormat("locked", true)
      compare(json(api.check(r.id, list[0].id, "true")).ok, false, "a locked page")
      compare(json(api.removeBlock(r.id, list[0].id)).ok, false)
      view.setFormat("locked", false)
      // Not a page's block.
      var home = named("Getting started")
      var pb = json(api.blocks(home)).filter(function(b) { return b.type === "page" })[0]
      compare(json(api.removeBlock(home, pb.id)).ok, false)
    }

    // A board an agent writes, reads and changes.
    function test_18_boards() {
      fresh()
      var r = json(api.add("Sprint", file("s.md", "```board\n## To do\n- Write spec\n- Fix login\n\n## Doing\n\n## Done\n```")))
      verify(r.ok, JSON.stringify(r))
      var bl = json(api.blocks(r.id))[0]
      compare(bl.type, "board")
      compare(bl.board.columns.map(function(c) { return c.name }).join(","), "To do,Doing,Done")
      compare(bl.board.columns[0].cards.map(function(k) { return k.text }).join(","), "Write spec,Fix login")
      verify(api.read(r.id).indexOf("```board\n## To do\n- Write spec\n- Fix login\n\n## Doing\n\n## Done\n```") >= 0, api.read(r.id))
      var add = json(api.board(r.id, bl.id, "add", "Ship it", "doing"))
      verify(add.ok, JSON.stringify(add))
      compare(add.column, "Doing", "a column by its name, any case")
      compare(json(api.board(r.id, bl.id, "move", "write spec", "Done")).column, "Done")
      compare(json(api.board(r.id, bl.id, "edit", "Fix login", "Fix the login")).ok, true)
      compare(json(api.board(r.id, bl.id, "remove", add.card, "")).ok, true, "a card by its id")
      compare(json(api.board(r.id, bl.id, "addColumn", "Blocked", "")).ok, true)
      compare(json(api.board(r.id, bl.id, "renameColumn", "Blocked", "Waiting")).ok, true)
      compare(json(api.board(r.id, bl.id, "removeColumn", "Doing", "")).ok, true)
      var cols = json(api.blocks(r.id))[0].board.columns
      compare(cols.map(function(c) { return c.name + ":" + c.cards.map(function(k) { return k.text }).join("+") }).join("|"), "To do:Fix the login|Done:Write spec|Waiting:")
      compare(json(api.board(r.id, bl.id, "add", "x", "Nowhere")).ok, false)
      compare(json(api.board(r.id, bl.id, "move", "no such card", "Done")).ok, false)
      compare(json(api.board(r.id, bl.id, "fly", "", "")).ok, false)
      var p = json(api.blocks(r.id))
      compare(json(api.board(r.id, p[1] ? p[1].id : "x", "add", "x", "")).ok, false, "not a board")
    }

    // Files and links put on a page.
    function test_19_files_and_links() {
      fresh()
      var r = json(api.add("Trip", file("t.md", "Plans")))
      files.disk["/tmp/in/ticket.pdf"] = "%PDF-1.4 ticket"
      var a = json(api.attach(r.id, "/tmp/in/ticket.pdf"))
      verify(a.ok, JSON.stringify(a))
      compare(a.kind, "file")
      var f = null
      tryVerify(function() { f = json(api.blocks(r.id)).filter(function(b) { return b.type === "file" })[0]; return !!f }, 2000)
      var data = fileOf(r.id).blocks[f.id].data
      compare(data.name, "ticket.pdf")
      compare(files.disk[ws.folder + "/" + data.src], "%PDF-1.4 ticket", "copied into Pages/assets")
      files.disk["/tmp/in/beach.png"] = "PNG"
      compare(json(api.attach(r.id, "/tmp/in/beach.png")).kind, "picture")
      tryVerify(function() { return json(api.blocks(r.id)).some(function(b) { return b.type === "image" }) }, 2000)
      files.disk["/tmp/in/Hello.eml"] = "From: Sam <sam@acme.com>\r\nTo: me@here.com\r\nSubject: Hello\r\n\r\nHi there."
      compare(json(api.attach(r.id, "/tmp/in/Hello.eml")).kind, "email")
      tryVerify(function() { return json(api.blocks(r.id)).some(function(b) { return b.type === "email" }) }, 2000)
      var em = json(api.blocks(r.id)).filter(function(b) { return b.type === "email" })[0]
      compare(fileOf(r.id).blocks[em.id].data.subject, "Hello")
      compare(json(api.attach(r.id, "ticket.pdf")).ok, false, "a full path")
      // A link as a card.
      files.fetchPages["https://example.com/guide"] = "<html><head><title>The guide</title><meta name=\"description\" content=\"All of it\"></head></html>"
      var bk = json(api.bookmark(r.id, "example.com/guide"))
      verify(bk.ok, JSON.stringify(bk))
      compare(bk.url, "https://example.com/guide")
      var bb = null
      tryVerify(function() { bb = json(api.blocks(r.id)).filter(function(b) { return b.type === "bookmark" })[0]; return !!bb }, 2000)
      compare(fileOf(r.id).blocks[bb.id].data.title, "The guide")
      compare(json(api.bookmark(r.id, "not a link")).ok, false)
      // Open in the window: it adds them itself.
      view.open(r.id)
      tryVerify(function() { return view.page && view.page.id === r.id }, 2000)
      files.disk["/tmp/in/two.pdf"] = "%PDF two"
      api.attach(r.id, "/tmp/in/two.pdf")
      tryVerify(function() { return view.editor.serialize().filter(function(b) { return b.type === "file" }).length === 2 }, 2000)
    }

    // Events, people and tags changed.
    function test_20_events_people_tags() {
      fresh()
      var e = json(api.addEvent("Dentist oct 12 3pm", ""))
      verify(e.ok, JSON.stringify(e))
      var c = json(api.editEvent(e.id, "title", "Dentist (Dr. Lee)"))
      compare(c.title, "Dentist (Dr. Lee)")
      compare(json(api.editEvent(e.id, "place", "Main St 4")).place, "Main St 4")
      compare(json(api.editEvent(e.id, "start", "2026-10-14T09:30")).start, "2026-10-14T09:30")
      compare(json(api.editEvent(e.id, "repeat", "monthly")).repeat, "monthly")
      compare(json(api.editEvent(e.id, "alert", "15")).alert, 15)
      compare(json(api.editEvent(e.id, "color", "green")).color, "green")
      compare(json(api.editEvent(e.id, "allDay", "true")).allDay, true)
      var w = json(api.editEvent(e.id, "when", "oct 20 9:00-10:30"))
      verify(w.ok, JSON.stringify(w))
      verify(/-10-20T09:00$/.test(w.start) && /-10-20T10:30$/.test(w.end), JSON.stringify(w))
      compare(w.allDay, false)
      compare(json(api.editEvent(e.id, "notes", "Bring the form")).ok, true)
      compare(ws.calendar.events.filter(function(x) { return x.id === e.id })[0].detail, "Bring the form")
      compare(json(api.editEvent(e.id, "alert", "7")).ok, false)
      compare(json(api.editEvent(e.id, "repeat", "hourly")).ok, false)
      compare(json(api.editEvent(e.id, "when", "whenever")).ok, false)
      compare(json(api.editEvent(e.id, "mood", "x")).ok, false)
      compare(json(api.editEvent("nonsense", "title", "x")).ok, false)
      // An .ics file's events; again, none twice.
      var icsFile = file("trip.ics", ["BEGIN:VCALENDAR", "BEGIN:VEVENT", "DTSTART:20261011T072500", "DTEND:20261011T104000", "SUMMARY:Flight out", "END:VEVENT",
        "BEGIN:VEVENT", "DTSTART;VALUE=DATE:20261011", "DTEND;VALUE=DATE:20261013", "SUMMARY:Lisbon", "END:VEVENT", "END:VCALENDAR"].join("\r\n"))
      var im = json(api.importCalendar(icsFile))
      verify(im.ok, JSON.stringify(im))
      compare([im.added, im.skipped].join(","), "2,0")
      compare(json(api.importCalendar(icsFile)).added, 0, "not twice")
      compare(json(api.importCalendar(file("x.ics", "nothing"))).ok, false)
      // People.
      var s = json(api.addContact("Sam Rivera", "", "sam@acme.com"))
      verify(s.ok, JSON.stringify(s))
      var p = json(api.editContact("Sam Rivera", "company", "Acme"))
      verify(p.ok, JSON.stringify(p))
      compare(p.company, "Acme")
      compare(json(api.editContact(s.id, "phone", "mobile: +1 555 123 4567")).phones[0].number, "+1 555 123 4567")
      compare(json(api.editContact(s.id, "email", "home: sam@home.org")).emails.length, 2)
      compare(json(api.editContact(s.id, "birthday", "--04-12")).birthday, "--04-12")
      compare(json(api.editContact(s.id, "birthday", "someday")).ok, false)
      compare(json(api.editContact(s.id, "removePhone", "+15551234567")).phones.length, 0, "the number, written any way")
      compare(json(api.editContact(s.id, "removeEmail", "nobody@x.com")).ok, false)
      compare(json(api.editContact(s.id, "phone", "call me")).ok, false)
      compare(json(api.removeContact("Sam Rivera")).ok, false, "taken out by id only")
      var gone = json(api.removeContact(s.id))
      verify(gone.ok, JSON.stringify(gone))
      verify(!ws.contactById(s.id))
      // Tags.
      var t1 = json(api.add("One", file("1.md", "an #idea here")))
      json(api.add("Two", file("2.md", "another #idea")))
      var rt = json(api.renameTag("#idea", "#ideas"))
      verify(rt.ok, JSON.stringify(rt))
      compare(rt.pages, 2)
      tryVerify(function() { return json(api.tags()).some(function(x) { return x.tag === "#ideas" && x.pages === 2 }) }, 2000)
      verify(api.read(t1.id).indexOf("#ideas") >= 0, api.read(t1.id))
      compare(json(api.renameTag("#nothing", "#x")).ok, false)
      var rm = json(api.removeTag("#ideas"))
      verify(rm.ok, JSON.stringify(rm))
      tryVerify(function() { return !json(api.tags()).some(function(x) { return x.tag === "#ideas" }) }, 2000)
      verify(api.read(t1.id).indexOf("an here") >= 0, "the #tag out of the text, as in the window: " + api.read(t1.id))
    }

    // Notebooks: listed, read, added to.
    function test_21_notebooks() {
      fresh()
      files.index = ({ "journal-ab12": { title: "Journal", modified: "2026-10-01T09:00:00.000Z", pages: ["20261001-090000-aaaa"] } })
      files.disk[files.rootPath + "/journal-ab12/pages/20261001-090000-aaaa.json"] = JSON.stringify({
        version: 1, id: "20261001-090000-aaaa", title: "Thursday", day: "2026-10-01", created: "2026-10-01T09:00:00.000Z", modified: "2026-10-01T09:00:00.000Z",
        blocks: [{ type: "p", html: "Long walk by the river." }, { type: "check", checked: true, html: "Call mum" }] })
      var list = json(api.notebooks())
      compare(list.length, 1)
      compare(list[0].title, "Journal")
      compare(list[0].pages, 1)
      var nb = json(api.notebook("journal-ab12"))
      compare(nb.pages[0].title, "Thursday")
      compare(nb.pages[0].day, "2026-10-01")
      verify(nb.pages[0].text.indexOf("Long walk") >= 0, nb.pages[0].text)
      var md = api.readNotebook("journal-ab12", "20261001-090000-aaaa")
      verify(md.indexOf("# Thursday") === 0 && md.indexOf("- [x] Call mum") >= 0, md)
      var added = json(api.addToNotebook("journal-ab12", file("f.md", "# Friday\n\n- [ ] Pack\n\nRain all day.")))
      verify(added.ok, JSON.stringify(added))
      compare(added.n, 2)
      compare(added.title, "Friday")
      var made = files.written["journal-ab12"][added.id]
      compare(made.blocks.map(function(b) { return b.type }).join(","), "check,p")
      verify(api.readNotebook("journal-ab12", added.id).indexOf("- [ ] Pack") >= 0)
      compare(json(api.notebook("nope")).ok, false)
      compare(json(api.readNotebook("journal-ab12", "nope")).ok, false)
    }

    // What read gives as fenced blocks is what add takes.
    function test_22_fenced_blocks_round_trip() {
      fresh()
      var s = json(api.addContact("Sam Rivera", "", "sam@acme.com"))
      var e = json(api.addEvent("Standup oct 5 9:30", ""))
      var r = json(api.add("Hub", file("h.md", "```contact\nsam@acme.com\n```\n\n```agenda\n2026-10-05\n```\n\n```event\n" + e.id + "\n```\n\n```bookmark\nhttps://example.com/a\n```")))
      verify(r.ok, JSON.stringify(r))
      var types = json(api.blocks(r.id)).map(function(b) { return b.type })
      compare(types.slice(0, 4).join(","), "contact,agenda,event,bookmark")
      compare(fileOf(r.id).blocks[json(api.blocks(r.id))[0].id].data.contact, s.id, "the person, found by their email")
      var md = api.read(r.id)
      verify(md.indexOf("```contact\nSam Rivera\n```") >= 0, md)
      verify(md.indexOf("```agenda\n2026-10-05\n```") >= 0, md)
      verify(md.indexOf("```event\n" + e.id + "\n```") >= 0, md)
      verify(md.indexOf("```bookmark\nhttps://example.com/a\n```") >= 0, md)
      verify(json(api.help()).fences.indexOf("```board") >= 0)
    }

    // Pictures: a size and a side; a gallery, of files or a folder's, changed.
    function test_23_pictures_and_galleries() {
      fresh()
      var r = json(api.add("Trip", file("t.md", "Plans")))
      files.disk["/tmp/in/beach.png"] = "PNG"
      api.attach(r.id, "/tmp/in/beach.png")
      var img = null
      tryVerify(function() { img = json(api.blocks(r.id)).filter(function(b) { return b.type === "image" })[0]; return !!img }, 2000)
      compare(img.width, 100, "as it comes: as wide as the page")
      compare(img.align, "center")
      compare(files.picturesIn[files.picturesIn.length - 1].within, "", "yours: from wherever you said")
      var s = json(api.picture(r.id, img.id, "40%", "right"))
      verify(s.ok, JSON.stringify(s))
      compare(fileOf(r.id).blocks[img.id].width, 0.4)
      compare(fileOf(r.id).blocks[img.id].align, "right")
      compare(json(api.picture(r.id, img.id, "0.8", "")).width, 80, "a fraction, too; where it sits kept")
      compare(fileOf(r.id).blocks[img.id].align, "right")
      compare(json(api.picture(r.id, img.id, "5", "")).width, 15, "no smaller than 15%")
      compare(json(api.picture(r.id, img.id, "", "sideways")).ok, false)
      compare(json(api.picture(r.id, img.id, "", "")).ok, false)
      var para = json(api.blocks(r.id))[0]
      compare(json(api.picture(r.id, para.id, "50", "")).ok, false, "not a picture")
      // A gallery of files ("|" between them), and one of a folder's.
      files.disk["/tmp/Pics/a.jpg"] = "A"
      files.disk["/tmp/Pics/b.png"] = "B"
      files.disk["/tmp/Pics/c.webp"] = "C"
      files.disk["/tmp/Pics/notes.txt"] = "words"
      var g = json(api.addGallery(r.id, "/tmp/Pics/a.jpg | /tmp/Pics/b.png", "2"))
      verify(g.ok, JSON.stringify(g))
      compare(g.columns, 2)
      var gb = null
      tryVerify(function() { gb = json(api.blocks(r.id)).filter(function(b) { return b.type === "gallery" })[0]; return !!gb }, 2000)
      compare(gb.images.length, 2)
      compare(gb.columns, 2)
      var d = fileOf(r.id).blocks[gb.id].data
      verify(d.images.every(function(x) { return /^assets\//.test(x.src) && files.disk[ws.folder + "/" + x.src] !== undefined }), "copied into Pages/assets")
      compare(json(api.addGallery(r.id, "/tmp/Pics", "")).columns, 3)
      tryVerify(function() { return json(api.blocks(r.id)).filter(function(b) { return b.type === "gallery" }).length === 2 }, 2000)
      var g2 = json(api.blocks(r.id)).filter(function(b) { return b.type === "gallery" })[1]
      compare(g2.images.length, 3, "a folder: its pictures, not its notes")
      compare(json(api.addGallery(r.id, "a.jpg", "")).ok, false, "a full path")
      compare(json(api.addGallery(r.id, "/tmp/Pics/notes.txt|/tmp/x.doc", "")).ok, false, "no pictures")
      // Changed: more, a caption, moved, one out, two to a row, taller.
      verify(json(api.gallery(r.id, gb.id, "add", "/tmp/Pics/c.webp", "")).ok)
      tryVerify(function() { return fileOf(r.id).blocks[gb.id].data.images.length === 3 }, 2000)
      var third = fileOf(r.id).blocks[gb.id].data.images[2].src
      compare(json(api.gallery(r.id, gb.id, "caption", "3", "Sunset")).caption, "Sunset")
      compare(json(api.gallery(r.id, gb.id, "move", "3", "1")).picture, 1)
      d = fileOf(r.id).blocks[gb.id].data
      compare(d.images[0].src, third)
      compare(d.images[0].caption, "Sunset")
      compare(json(api.gallery(r.id, gb.id, "remove", third, "")).removed, 1, "a picture by its src")
      compare(fileOf(r.id).blocks[gb.id].data.images.length, 2)
      compare(json(api.gallery(r.id, gb.id, "columns", "4", "")).columns, 4)
      compare(json(api.gallery(r.id, gb.id, "height", "300", "")).height, 300)
      compare(json(api.gallery(r.id, gb.id, "height", "20", "")).height, 80, "no shorter than 80")
      compare(json(api.gallery(r.id, gb.id, "height", "0", "")).height, 0)
      compare(json(api.gallery(r.id, gb.id, "columns", "5", "")).ok, false)
      compare(json(api.gallery(r.id, gb.id, "remove", "9", "")).ok, false)
      compare(json(api.gallery(r.id, gb.id, "spin", "", "")).ok, false)
      compare(json(api.gallery(r.id, img.id, "columns", "2", "")).ok, false, "not a gallery")
      // Open in the window: the same.
      view.open(r.id)
      tryVerify(function() { return view.page && view.page.id === r.id }, 2000)
      compare(json(api.gallery(r.id, gb.id, "caption", "1", "Morning")).ok, true)
      tryVerify(function() { var x = view.editor.serialize().filter(function(b) { return b.type === "gallery" })[0]; return x && x.data.images[0].caption === "Morning" }, 2000)
      compare(json(api.picture(r.id, img.id, "50", "left")).ok, true)
      tryVerify(function() { var x = view.editor.serialize().filter(function(b) { return b.type === "image" })[0]; return x && x.width === 0.5 && x.align === "left" }, 2000)
      // The panel's agent's pictures: only from its own folder (the files
      // helper walks it, through no link).
      api.agentScope = { agent: "Grok", id: "grok", dir: "/tmp/in", frozen: false }
      api.caller = api.agentScope
      files.disk["/tmp/in/two.png"] = "PNG"
      var before = files.picturesIn.length
      api.attach(r.id, "/tmp/in/two.png")
      api.addGallery(r.id, "/tmp/in/beach.png|/tmp/in/two.png", "2")
      api.caller = null
      api.agentScope = null
      tryVerify(function() { return files.picturesIn.length >= before + 3 }, 2000)
      verify(files.picturesIn.slice(before).every(function(c) { return c.within === "/tmp/in" }), JSON.stringify(files.picturesIn.slice(before)))
    }

    function test_24_links_templates_boards_settings() {
      fresh()
      files.fetchPages["https://example.com/a"] = "<html><head><title>Page A</title></head></html>"
      files.fetchPages["https://example.com/b"] = "<html><head><title>Page B</title></head></html>"
      var target = json(api.add("Target", file("tg.md", "x")))
      var r = json(api.add("Links", file("l.md", "```bookmark\nhttps://example.com/a\n```\n\n```link\nTarget\n```")))
      verify(r.ok, JSON.stringify(r))
      var bl = json(api.blocks(r.id))
      compare(bl[0].type, "bookmark")
      compare(bl[1].type, "link")
      compare(fileOf(r.id).blocks[bl[1].id].target, target.id, "a link to a page, by its title")
      var s = json(api.setLink(r.id, bl[0].id, "example.com/b"))
      verify(s.ok, JSON.stringify(s))
      compare(s.url, "https://example.com/b")
      tryVerify(function() { return fileOf(r.id).blocks[bl[0].id].data.title === "Page B" }, 2000, "its page read again")
      compare(fileOf(r.id).blocks[bl[0].id].data.url, "https://example.com/b")
      var other = json(api.add("Other", file("o.md", "y")))
      var l = json(api.setLink(r.id, bl[1].id, other.id))
      compare(l.title, "Other")
      compare(fileOf(r.id).blocks[bl[1].id].target, other.id)
      compare(json(api.setLink(r.id, bl[1].id, "Target")).target, target.id)
      compare(json(api.setLink(r.id, bl[1].id, "No such page")).ok, false)
      compare(json(api.setLink(r.id, bl[0].id, "not a link")).ok, false)
      var md = api.read(r.id)
      verify(md.indexOf("```link\n" + target.id + "\nTarget\n```") >= 0, md)
      // A template from Markdown, and what it's for.
      var t = json(api.addTemplate("", file("tpl.md", "# Retro\n\n## Went well\n\n- \n\n## Next time\n\n- "), "A sprint's look back"))
      verify(t.ok, JSON.stringify(t))
      compare(t.title, "Retro", "its # heading")
      var listed = json(api.templates()).filter(function(x) { return x.id === t.id })[0]
      verify(!!listed, "a template now")
      compare(listed.description, "A sprint's look back")
      compare(json(api.describeTemplate("retro", "Looking back on a sprint")).description, "Looking back on a sprint", "by its title, any case")
      compare(json(api.templates()).filter(function(x) { return x.id === t.id })[0].description, "Looking back on a sprint")
      compare(json(api.describeTemplate("nope", "x")).ok, false)
      // A board: taller, a column wider, colored.
      var b = json(api.add("Sprint", file("s.md", "```board\n## To do\n- Write spec\n\n## Done\n```")))
      var bid = json(api.blocks(b.id))[0].id
      compare(json(api.board(b.id, bid, "height", "500", "")).height, 500)
      compare(json(api.board(b.id, bid, "height", "50", "")).height, 160, "no shorter than 160")
      compare(json(api.board(b.id, bid, "columnWidth", "to do", "320")).width, 320)
      compare(json(api.board(b.id, bid, "cardColor", "write spec", "blue_background")).ok, true)
      compare(json(api.board(b.id, bid, "columnColor", "Done", "#FF8800")).ok, true)
      var bd = fileOf(b.id).blocks[bid].data
      compare(bd.height, 160)
      compare(bd.columns[0].width, 320)
      compare(bd.columns[0].cards[0].background, "blue")
      compare(bd.columns[1].color, "#ff8800")
      compare(json(api.board(b.id, bid, "cardColor", "write spec", "")).ok, true)
      compare(fileOf(b.id).blocks[bid].data.columns[0].cards[0].background, "", "\"\": none")
      compare(json(api.board(b.id, bid, "cardColor", "write spec", "plaid")).ok, false)
      compare(json(api.board(b.id, bid, "columnWidth", "Nowhere", "300")).ok, false)
      // The settings there are, and what each can be.
      api.settings = { scrollSpeed: "faster", pen: "serif" }
      var prefs = json(api.preferences())
      var speed = prefs.filter(function(x) { return x.key === "scrollSpeed" })[0]
      compare(speed.value, "faster")
      compare(speed.choices.join(","), "slower,normal,faster")
      compare(prefs.filter(function(x) { return x.key === "zoom" })[0].range.join(","), "60,200")
      verify(!prefs.some(function(x) { return x.key === "profiles" || x.key === "folder" || x.key === "inbox" }), "not the ones kept for it")
      api.settings = null
      verify(json(api.help()).fences.indexOf("```gallery") >= 0)
    }

    // While an agent works in the panel, a file it names is read by the
    // helper first (a plain file only), and the command, asked again, uses it;
    // never a device, at any time.
    function test_25_files_an_agent_names() {
      fresh()
      var r = json(api.add("Log", file("a.md", "first")))
      compare(json(api.append(r.id, "/dev/zero")).ok, false)
      compare(json(api.append(r.id, "/proc/self/environ")).ok, false)
      // Any path a command is given goes to the helper (never read there and
      // then), however it's written.
      ;["//dev/zero", "/tmp/../dev/zero", "/./proc/self/environ"].forEach(function(p) {
        compare(json(api.append(r.id, p)).ok, false, p)
        verify(files.ran.some(function(a) { return a[4] === "read" && a[6] === p }), "read by the helper: " + p)
      })
      files.deferHelperReads = true
      api.agentScope = { agent: "Claude Code", dir: "/tmp/in", frozen: false }
      function kept(p) { return api.prefetched[api.maxBytes + ":" + p] }
      var path = file("agent.md", "from the agent")
      var first = json(api.append(r.id, path))
      compare(first.ok, false)
      verify(first.error.indexOf("run the same command again") >= 0, first.error)
      compare(kinds(fileOf(r.id)).join("|"), "p:0:first|p:0:", "nothing yet")
      compare(json(api.append(r.id, path)).ok, false, "still being read: asked again, not read twice")
      compare(files.ran.filter(function(a) { return a[4] === "read" && a[6] === path }).length, 1)
      files.answerReads()
      verify(kept(path) !== undefined && kept(path).at > 0, "read")
      var again = json(api.append(r.id, path))
      compare(again.ok, true, "asked again: done")
      compare(again.added, 1)
      compare(kinds(fileOf(r.id)).join("|"), "p:0:first|p:0:from the agent|p:0:")
      verify(files.ran.some(function(a) { return a[4] === "read" && a[6] === path }), "read by the helper")
      // One it couldn't read: said, asked again.
      compare(json(api.append(r.id, "/tmp/in/missing.md")).ok, false)
      files.answerReads()
      verify(json(api.append(r.id, "/tmp/in/missing.md")).error.indexOf("no file there") >= 0)
      // At most so many at a time: the rest are asked to wait.
      for (var n = 0; n < api.maxReading; n++) json(api.append(r.id, file("w" + n + ".md", "x")))
      var busy = json(api.append(r.id, file("w9.md", "x")))
      verify(busy.error.indexOf("reading other files") >= 0, busy.error)
      // A read kept too long is read again; none outlives the agent's work.
      files.answerReads()
      kept("/tmp/in/w0.md").at = Date.now() - 121000
      compare(json(api.append(r.id, "/tmp/in/w0.md")).ok, false, "read again, not used")
      files.answerReads()
      compare(json(api.append(r.id, "/tmp/in/w0.md")).ok, true)
      json(api.append(r.id, file("late.md", "late")))
      api.agentScope = null
      compare(Object.keys(api.prefetched).length, 0, "nothing kept after")
      files.answerReads()
      compare(Object.keys(api.prefetched).length, 0, "and a read that comes after isn't kept")
      files.deferHelperReads = false
    }

    // While an agent works, Uber Notebook contacts a site for it only with
    // your yes: asked in its panel (Allow once, Always for that agent and
    // site, No); redirects and pictures only from sites it may contact.
    function test_26_sites_contacted_for_an_agent_only_with_your_yes() {
      fresh()
      var r = json(api.add("Links", file("l.md", "x")))
      function contacted(host) { return files.ran.filter(function(a) { return a.join(" ").indexOf(host) >= 0 && (a[0] === "/usr/bin/curl" || a[2] && String(a[2]).indexOf("curl") >= 0 || a[0] === "/usr/bin/getent") }).length }
      function cards() { var p = fileOf(r.id); return Object.keys(p.blocks).map(function(k) { return p.blocks[k] }).filter(function(b) { return b.type === "bookmark" }).map(function(b) { return b.data }) }
      function find(item, name) {
        if (!item) return null
        if (item.objectName === name && item.visible) return item
        for (var i = 0; i < item.children.length; i++) { var hit = find(item.children[i], name); if (hit) return hit }
        return null
      }
      // A button of the panel's question, once it's laid out where you'd click it.
      function askButton(name) {
        tryVerify(function() { var st = find(view.agentPanel, "agentPanelAsks"); return st !== null && st.height > 0 && find(view.agentPanel, name) !== null }, 1000, name)
        wait(50)
        return find(view.agentPanel, name)
      }
      api.settings = Qt.binding(function() { return service.settings })
      // (Its commands, as the panel's agent's: Service.qml tells the Api who calls.)
      api.agentScope = { agent: "Grok", id: "grok", dir: "/tmp/in", frozen: false }
      api.caller = api.agentScope
      // A site it may not contact yet: the link only, and you're asked.
      var b = json(api.bookmark(r.id, "https://e.org/?note=private+text"))
      compare(b.ok, true)
      verify(b.note.indexOf("asked in the panel") >= 0, b.note)
      compare(contacted("e.org"), 0, "not contacted")
      compare(cards()[0].url, "https://e.org/?note=private+text")
      compare(view.agentAsks.length, 1)
      compare(view.agentAsks[0].target, "e.org")
      // Again for the same site: the same question, both waiting on it.
      var mark = Object.keys(fileOf(r.id).blocks).filter(function(k) { return fileOf(r.id).blocks[k].type === "bookmark" })[0]
      json(api.bookmark(r.id, "https://e.org/two"))
      compare(view.agentAsks.length, 1)
      compare(view.agentAsks[0].runs.length, 2)
      // Not https: never asked, the card reads it when you ask.
      verify(json(api.bookmark(r.id, "http://plain.example.com/x")).note.indexOf("when you ask") >= 0)
      compare(view.agentAsks.length, 1)
      // Asked in the panel, in words; Allow once: read, nothing kept.
      tryVerify(function() { return find(view.agentPanel, "agentAskText") !== null }, 1000)
      verify(find(view.agentPanel, "agentAskText").text.indexOf("Grok wants to have Uber Notebook contact e.org") === 0, find(view.agentPanel, "agentAskText").text)
      files.fetchPages["https://e.org/?note=private+text"] = '<html><head><title>One</title></head></html>'
      files.fetchPages["https://e.org/two"] = '<html><head><title>Two</title></head></html>'
      mouseClick(askButton("agentAskOnce"))
      tryVerify(function() { return cards().filter(function(d) { return d.title === "One" || d.title === "Two" }).length === 2 }, 2000, "both read")
      compare(view.agentAsks.length, 0)
      compare(service.settings.agentPermissions.length, 0, "Allow once: nothing kept")
      // Always: kept for Grok and that site; the next one is read at once.
      json(api.bookmark(r.id, "https://docs.example.org/a"))
      files.fetchPages["https://docs.example.org/a"] = '<html><head><title>Docs</title></head></html>'
      mouseClick(askButton("agentAskAlways"))
      tryVerify(function() { return cards().some(function(d) { return d.title === "Docs" }) }, 2000)
      compare(JSON.stringify(service.settings.agentPermissions), JSON.stringify([{ agent: "grok", action: "contact", target: "docs.example.org" }]))
      files.fetchPages["https://docs.example.org/b"] = '<html><head><title>Docs B</title><meta property="og:image" content="https://cdn.elsewhere.net/p.png"></head></html>'
      verify(json(api.bookmark(r.id, "https://docs.example.org/b")).note.indexOf("being read") >= 0)
      tryVerify(function() { return cards().some(function(d) { return d.title === "Docs B" }) }, 2000, "read without asking")
      compare(view.agentAsks.length, 0)
      compare(contacted("cdn.elsewhere.net"), 0, "its picture: not from a site it may not contact")
      // Sent on to another site: not followed.
      files.fetchPages["https://docs.example.org/r"] = "REDIRECT https://evil.example.com/?leak=private+text"
      json(api.bookmark(r.id, "https://docs.example.org/r"))
      wait(200)
      compare(contacted("evil.example.com"), 0, "never contacted")
      verify(cards().some(function(d) { return d.url === "https://docs.example.org/r" && d.title === "" }), "the link kept")
      // A terminal's agent (or a script) meanwhile: as always, read at once.
      api.caller = null
      var others = contacted("other-site.example.com")
      verify(json(api.bookmark(r.id, "https://other-site.example.com/x")).note.indexOf("being read") >= 0)
      verify(contacted("other-site.example.com") > others, "not the panel's agent: fetched, not asked")
      compare(view.agentAsks.length, 0)
      // Only Grok: Claude is asked about it.
      api.agentScope = { agent: "Claude Code", id: "claude", dir: "/tmp/in", frozen: false }
      api.caller = api.agentScope
      json(api.bookmark(r.id, "https://docs.example.org/c"))
      compare(view.agentAsks.length, 1, "asked: Grok's yes isn't Claude's")
      // No: the link stays as it is.
      mouseClick(askButton("agentAskNo"))
      compare(view.agentAsks.length, 0)
      verify(cards().some(function(d) { return d.url === "https://docs.example.org/c" && d.title === "" }))
      // Without an agent at work: read, as always.
      api.agentScope = null
      api.caller = null
      var before = contacted("plain-site.example.com")
      api.bookmark(r.id, "https://plain-site.example.com/page")
      verify(contacted("plain-site.example.com") > before, "fetched when you add one")
      service.setSetting("agentPermissions", [])
      api.settings = null
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
