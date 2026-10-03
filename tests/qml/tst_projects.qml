import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Dates.js" as Dates

// Projects and the archive: a page made a project (status, due date, its
// to-dos and its pages' as its progress), the sidebar's Projects, a project
// done and put in the archive, and back.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }

  property var lastUndo: null
  property string lastToast: ""

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToastUndo: function(text, undo) { root.lastToast = text; root.lastUndo = undo }
  }

  TestCase {
    name: "Projects"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      view.tagShown = ""
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      root.lastUndo = null
      wait(0)
    }
    function find(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) find(item.children[i], test, out)
      return out
    }
    function named(name) { return find(root.Window.window.contentItem, function(it) { return it.objectName === name }, [])[0] || null }
    function clickText(text) {
      var win = root.Window.window.contentItem
      var t = null
      tryVerify(function() { t = find(win, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }, [])[0] || null; return t !== null }, 1000, text + " is on screen")
      wait(250)
      mouseClick(find(win, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }, [])[0])
    }
    function fileOf(id) { return files.parseJson(files.disk[Workspace.pageFile(files.rootPath, id)] || "") }
    function makePage(title, parent, checks) {
      var blocks = (checks || []).map(function(c) { return { type: "check", html: c[0], checked: c[1], indent: 0 } })
      var p = ws.createPage({ parent: parent || "", title: title, blocks: blocks.length ? blocks : undefined })
      if (parent) ws.editPage(parent, function(x) { return Workspace.appendPageBlock(x, p.id) })
      return p
    }
    function sidebarRows(name) {
      return find(named("sidebar"), function(it) { return it.objectName === name && it.modelData }, []).sort(function(x, y) { return x.mapToItem(root, 0, 0).y - y.mapToItem(root, 0, 0).y })
    }
    function sidebarRow(name, title) {
      var r = null
      tryVerify(function() { r = sidebarRows(name).filter(function(x) { return x.modelData.title === title })[0] || null; return r !== null }, 1000, title + " is a " + name)
      return r
    }
    // Drags an item onto another (frac: how far down it, 0 to 1).
    function dragOnto(src, dst, frac) {
      var p0 = src.mapToItem(root, 60, src.height / 2)
      var p1 = dst.mapToItem(root, 80, dst.height * frac)
      mousePress(root, p0.x, p0.y)
      for (var i = 1; i <= 10; i++) mouseMove(root, p0.x + (p1.x - p0.x) * i / 10, p0.y + (p1.y - p0.y) * i / 10)
      wait(30)
      mouseRelease(root, p1.x, p1.y)
      wait(100)
    }
    function openPage(id) {
      view.open(id)
      tryVerify(function() { return view.page && view.page.id === id }, 2000)
      wait(50)
    }

    function test_1_a_page_made_a_project() {
      fresh()
      var launch = makePage("Launch", "", [["Write the post", true], ["Record the video", false]])
      var tasks = makePage("Tasks", launch.id, [["Tag the release", false], ["Fix the crash", true], ["Ship", false]])
      openPage(launch.id)
      verify(named("projectBar") === null, "not a project yet")
      // From the page's ⋯ menu.
      mouseClick(find(root, function(it) { return it.tip === "Font, width, export, trash" }, [])[0])
      clickText("Make it a project")
      tryVerify(function() { return named("projectBar") !== null }, 1000, "its project line")
      compare(view.page.project.status, "active")
      compare(fileOf(launch.id).project.status, "active", "kept in its file")
      // Its progress: its to-dos and its pages'.
      tryVerify(function() { return find(root, function(it) { return it.text === "2 of 5 to-dos" }, []).length === 1 }, 1000, "2 of 5, the page inside it too")
      // Its status, from the chip (once the menu before has gone).
      wait(250)
      mouseClick(named("projectStatus"))
      clickText("Paused")
      wait(100)
      compare(view.page.id, launch.id, "the click on the menu is the menu's (not the page's under it)")
      compare(view.page.project.status, "paused")
      compare(fileOf(launch.id).project.status, "paused")
      // A due date, typed.
      wait(200)
      mouseClick(named("projectDue"))
      tryVerify(function() { return named("dueField") !== null }, 1000)
      wait(200)
      var field = named("dueField")
      field.text = "tomorrow"
      field.edited("tomorrow")
      keyClick(Qt.Key_Return)
      var n = new Date()
      var tomorrow = Dates.iso(new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1), false)
      tryCompare(view.page.project, "due", tomorrow, 1000)
      tryVerify(function() { return find(root, function(it) { return it.text === "Due Tomorrow" }, []).length === 1 }, 1000)
      // Late: says so, in red.
      view.setProjectDue(Dates.iso(new Date(n.getFullYear(), n.getMonth(), n.getDate() - 3), false))
      tryVerify(function() { return find(root, function(it) { return it.text === "3 days late" }, []).length >= 1 }, 1000, "late")
      // Not a project any more.
      view.setProject(null)
      tryVerify(function() { return named("projectBar") === null }, 1000)
      compare(fileOf(launch.id).project, undefined)
    }

    function test_2_the_sidebars_projects() {
      fresh()
      var a = makePage("Website", "", [["a", true], ["b", false]])
      var b = makePage("Hiring", "")
      var c = makePage("Old thing", "")
      var d = makePage("Someday", "")
      var n = new Date()
      function iso(days) { return Dates.iso(new Date(n.getFullYear(), n.getMonth(), n.getDate() + days), false) }
      function project(id, status, due) { ws.editPage(id, function(p) { p.project = { status: status, due: due }; return true }) }
      project(a.id, "active", iso(5))
      project(b.id, "active", iso(-2))
      project(c.id, "done", "")
      project(d.id, "paused", "")
      var rows = []
      tryVerify(function() {
        rows = sidebarRows("projectRow")
        return rows.length === 4
      }, 1000, "every project")
      compare(rows.map(function(r) { return r.modelData.title }).join(), "Hiring,Website,Someday,Old thing", "late first, then by when it's due, paused, then done")
      verify(rows[0].modelData.overdue, "the late one says so")
      // In Projects, not in Pages.
      var pages = sidebarRows("pageRow").map(function(r) { return r.modelData.title })
      verify(pages.indexOf("Website") < 0 && pages.indexOf("Old thing") < 0, pages.join())
      wait(100)
      mouseClick(rows[1], 60, rows[1].height / 2)
      tryVerify(function() { return view.page && view.page.id === a.id }, 2000, "a click opens it")
    }

    function test_3_done_and_archived() {
      fresh()
      var p = makePage("Conference talk", "", [["Slides", true]])
      var inside = makePage("Notes", p.id)
      openPage(p.id)
      view.makeProject()
      view.setProjectStatus("done")
      tryVerify(function() { return named("projectArchive") !== null }, 1000, "done: it offers the archive")
      wait(100)
      mouseClick(named("projectArchive"))
      tryVerify(function() { return ws.index.pages[p.id].archived === true }, 1000)
      verify(root.lastToast.indexOf("is in the archive") >= 0)
      // Out of the tree (with what's in it), into the Archive.
      var titles = Workspace.rows(ws.index, { [p.id]: true }).map(function(r) { return r.title })
      verify(titles.indexOf("Conference talk") < 0 && titles.indexOf("Notes") < 0, titles.join())
      compare(Workspace.archived(ws.index), [p.id])
      tryVerify(function() { return named("archivedNote") !== null }, 1000, "the page says it's in the archive")
      verify(named("projectArchive") === null)
      // Undo.
      root.lastUndo()
      tryVerify(function() { return !ws.index.pages[p.id].archived }, 1000)
      view.archivePage(p.id, true)
      // The Archive, at the sidebar's foot: open one, bring it back.
      mouseClick(named("archiveRow"))
      var rows = []
      tryVerify(function() { rows = find(root.Window.window.contentItem, function(it) { return it.objectName === "archivedRow" }, []); return rows.length === 1 }, 1000)
      wait(200)
      verify(find(rows[0], function(it) { return typeof it.text === "string" && it.text.indexOf("1 page in it") >= 0 }, []).length === 1, "with the pages in it")
      mouseClick(find(rows[0], function(it) { return it.objectName === "unarchive" }, [])[0])
      tryVerify(function() { return !ws.index.pages[p.id].archived }, 1000, "brought back")
      verify(Workspace.rows(ws.index, {}).map(function(r) { return r.title }).indexOf("Conference talk") >= 0, "in the tree again")
      // A page inside it in the archive: the note brings back the one put away.
      view.archivePage(p.id, true)
      openPage(inside.id)
      tryVerify(function() { return named("archivedNote") !== null }, 1000)
      verify(Workspace.inArchive(ws.index, inside.id))
      view.archivePage(view.archivedRoot(inside.id), false)
      tryVerify(function() { return !Workspace.inArchive(ws.index, inside.id) }, 1000)
    }

    function test_5_a_new_project_from_the_sidebar() {
      fresh()
      wait(100)
      mouseClick(named("newProject"))
      tryVerify(function() { return view.page && view.page.project && view.page.project.status === "active" }, 2000, "a new page, a project")
      var id = view.page.id
      compare(ws.index.pages[id].parent, "", "at the top")
      tryVerify(function() { return sidebarRows("projectRow").some(function(r) { return r.modelData.id === id }) }, 1000, "in Projects")
      verify(!sidebarRows("pageRow").some(function(r) { return r.modelData.id === id }), "not in Pages")
      verify(named("projectBar") !== null)
    }

    function test_6_dragged_into_projects_and_out() {
      fresh()
      var g = makePage("Garden", "", [["Seeds", false]])
      wait(100)
      // A page dragged on Projects: a project, there.
      dragOnto(sidebarRow("pageRow", "Garden"), named("projectsHead"), 0.5)
      tryVerify(function() { return ws.index.pages[g.id].project && ws.index.pages[g.id].project.status === "active" }, 2000, "a project")
      verify(root.lastToast.indexOf("is a project") >= 0, root.lastToast)
      sidebarRow("projectRow", "Garden")
      verify(!sidebarRows("pageRow").some(function(r) { return r.modelData.title === "Garden" }), "out of Pages")
      // Undo: a page again.
      root.lastUndo()
      tryVerify(function() { return !ws.index.pages[g.id].project }, 2000)
      sidebarRow("pageRow", "Garden")
      // A page dragged into a project: in it, under it in Projects.
      var h = makePage("House", "")
      view.makeProjectOf(h.id, true)
      tryVerify(function() { return !!ws.index.pages[h.id].project }, 1000)
      wait(100)
      dragOnto(sidebarRow("pageRow", "Garden"), sidebarRow("projectRow", "House"), 0.5)
      tryVerify(function() { return ws.index.pages[g.id].parent === h.id }, 2000, "inside the project")
      var inside = sidebarRow("projectPageRow", "Garden")
      compare(inside.modelData.depth, 1)
      verify(!ws.index.pages[g.id].project, "still a page (in a project)")
      // A project dragged into Pages: a page again, there.
      wait(100)
      dragOnto(sidebarRow("projectRow", "House"), sidebarRow("pageRow", "Getting started"), 0.5)
      tryVerify(function() { return !ws.index.pages[h.id].project && ws.index.pages[h.id].parent !== "" }, 2000, "a page, inside Getting started")
      verify(root.lastToast.indexOf("is a page again") >= 0, root.lastToast)
      compare(fileOf(h.id).project, undefined, "in its file too")
      sidebarRow("pageRow", "House")
      // Undo: a project again, where it was.
      root.lastUndo()
      tryVerify(function() { return ws.index.pages[h.id].parent === "" && ws.index.pages[h.id].project && ws.index.pages[h.id].project.status === "active" }, 2000)
      sidebarRow("projectRow", "House")
    }

    function test_7_from_the_sidebars_menu() {
      fresh()
      var p = makePage("Taxes", "")
      wait(100)
      var row = sidebarRow("pageRow", "Taxes")
      view.openRowMenu(p.id, row)
      clickText("Make it a project")
      tryVerify(function() { return !!ws.index.pages[p.id].project }, 1000)
      wait(250)
      view.openRowMenu(p.id, sidebarRow("projectRow", "Taxes"))
      clickText("Not a project")
      tryVerify(function() { return !ws.index.pages[p.id].project }, 1000)
      wait(250)
      view.openRowMenu(p.id, sidebarRow("pageRow", "Taxes"))
      tryVerify(function() { return named("rowArchive") !== null }, 1000)
      wait(250)
      mouseClick(named("rowArchive"))
      tryVerify(function() { return ws.index.pages[p.id].archived === true }, 1000)
    }

    function test_4_the_project_plan_is_a_project() {
      fresh()
      view.newPage("")
      tryVerify(function() { return view.page && view.page.title === "" && view.pageBlank }, 2000)
      view.applyTemplate("project")
      view.commit()
      compare(view.page.project.status, "active")
      verify(named("projectBar") !== null)
    }
  }
}
