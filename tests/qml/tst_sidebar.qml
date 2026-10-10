import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Tags.js" as Tags

// Pages' sidebar: its sections folding (and staying folded), what's in it
// left out (a right-click, or the settings) and back (Undo), the projects in
// Pages without Projects, the tags as chips (Show all), rows changed in
// place as a title's typed, the middle scrolling as one, and the buttons at
// the top and the foot.
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
  property int choicesAsked: 0
  property int settingsAsked: 0

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToastUndo: function(text, undo) { root.lastToast = text; root.lastUndo = undo }
    onSidebarChoicesRequested: root.choicesAsked++
    onSettingsRequested: root.settingsAsked++
  }

  TestCase {
    name: "Sidebar"
    when: windowShown

    function fresh(user) {
      service.user = user || ({ sounds: false })
      files.reset()
      view.page = null
      view.tagShown = ""
      view.calendarShown = false
      view.libraryShown = false
      view.peopleShown = false
      view.templatesShown = false
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      root.lastUndo = null
      root.lastToast = ""
      wait(50)
    }
    function find(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) find(item.children[i], test, out)
      return out
    }
    function sidebar() { return find(view, function(it) { return it.objectName === "sidebar" }, [])[0] }
    function named(name) { return find(root.Window.window.contentItem, function(it) { return it.objectName === name }, [])[0] || null }
    function all(name) { return find(sidebar(), function(it) { return it.objectName === name }, []) }
    function titles(name) {
      return all(name).sort(function(a, b) { return a.mapToItem(root, 0, 0).y - b.mapToItem(root, 0, 0).y }).map(function(r) { return r.modelData.title })
    }
    // What changed laid out, as it is a frame later on screen.
    function settle() { wait(100) }
    function head(label) { return find(sidebar(), function(it) { return it.label === label && it.fold !== undefined }, [])[0] || null }
    function makePage(title, parent, html) {
      var p = ws.createPage({ parent: parent || "", title: title, blocks: html ? [{ type: "p", html: html, indent: 0 }] : undefined })
      if (parent) ws.editPage(parent, function(x) { return Workspace.appendPageBlock(x, p.id) })
      return p
    }
    function clickText(text) {
      var win = root.Window.window.contentItem
      var t = null
      tryVerify(function() { t = find(win, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }, [])[0] || null; return t !== null }, 1000, text + " is on screen")
      wait(250)
      mouseClick(t)
    }

    function test_1_sections_fold_and_stay_folded() {
      fresh()
      var p = makePage("Garden", "")
      ws.toggleFavorite(p.id)
      tryVerify(function() { return titles("pageRow").indexOf("Garden") >= 0 }, 1000)
      tryVerify(function() { return all("favoriteRow").length === 1 }, 1000, "a favorite")
      settle()
      // A click on Pages' name: its pages folded away, how many said.
      var pages = head("Pages")
      mouseClick(pages, 30, pages.height / 2)
      tryVerify(function() { return all("pageRow").length === 0 }, 1000, "folded")
      settle()
      compare(service.settings.sidebarFolded, ["pages"], "kept")
      verify(find(pages, function(it) { return it.text === String(Workspace.sidebarRows(ws.index, view.openRows, new Date()).pages.length) }, []).length === 1, "how many, said")
      // And Favorites.
      mouseClick(head("Favorites"), 30, 13)
      tryVerify(function() { return all("favoriteRow").length === 0 }, 1000)
      settle()
      compare(service.settings.sidebarFolded, ["pages", "favorites"])
      // Back, with another click.
      mouseClick(head("Pages"), 30, 13)
      tryVerify(function() { return titles("pageRow").indexOf("Garden") >= 0 }, 1000, "open again")
      settle()
      compare(service.settings.sidebarFolded, ["favorites"])
      // Projects' + is its own: a new project, not folded.
      mouseClick(named("newProject"))
      tryVerify(function() { return view.page && view.page.project }, 2000)
      compare(service.settings.sidebarFolded, ["favorites"], "not folded by its +")
    }

    function test_2_hidden_with_a_right_click_and_back() {
      fresh()
      root.choicesAsked = 0
      verify(named("calendarTile") !== null)
      mouseClick(named("calendarTile"), 20, 20, Qt.RightButton)
      tryVerify(function() { return named("sidebarHide") !== null }, 1000, "its menu")
      compare(named("sidebarHide").text, "Hide Calendar")
      wait(150)
      mouseClick(named("sidebarHide"))
      tryVerify(function() { return named("sidebarChoose") === null }, 1000, "the menu gone")
      tryCompare(service.settings, "sidebarHidden", ["calendar"], 1000)
      tryVerify(function() { return named("calendarTile") === null }, 1000, "gone")
      verify(root.lastToast.indexOf("Calendar is hidden") === 0, root.lastToast)
      // The other two share the row.
      var lib = named("libraryTile"), people = named("peopleTile")
      verify(Math.abs(lib.width - people.width) < 1 && lib.width > sidebar().width / 3, "two, side by side")
      // Undo: back.
      root.lastUndo()
      tryVerify(function() { return named("calendarTile") !== null }, 1000)
      compare(service.settings.sidebarHidden, [])
      // A section's: Hide Projects; the projects in Pages then, where they are.
      var pr = makePage("Launch", "")
      view.makeProjectOf(pr.id, true)
      tryVerify(function() { return all("projectRow").length === 1 }, 1000)
      verify(titles("pageRow").indexOf("Launch") < 0, "in Projects, not Pages")
      settle()
      mouseClick(head("Projects"), 30, 13, Qt.RightButton)
      tryVerify(function() { return named("sidebarHide") !== null && named("sidebarHide").text === "Hide Projects" }, 1000)
      wait(150)
      mouseClick(named("sidebarHide"))
      tryVerify(function() { return named("sidebarChoose") === null }, 1000, "the menu gone")
      tryVerify(function() { return named("sidebarProjects") === null }, 1000, "no Projects")
      tryVerify(function() { return titles("pageRow").indexOf("Launch") >= 0 }, 1000, "the project in Pages")
      root.lastUndo()
      tryVerify(function() { return all("projectRow").length === 1 && titles("pageRow").indexOf("Launch") < 0 }, 1000, "in Projects again")
      settle()
      // Pages can't be hidden: its menu only chooses.
      mouseClick(head("Pages"), 30, 13, Qt.RightButton)
      tryVerify(function() { return named("sidebarChoose") !== null }, 1000)
      compare(named("sidebarHide"), null, "no Hide for Pages")
      wait(150)
      mouseClick(named("sidebarChoose"))
      compare(root.choicesAsked, 1, "Settings, at the sidebar's choices")
      tryVerify(function() { return named("sidebarChoose") === null }, 1000, "the menu gone")
      // At the foot, the menu opens over what it's for.
      var trash = named("trashButton")
      mouseClick(trash, 10, 10, Qt.RightButton)
      tryVerify(function() { return named("sidebarHide") !== null && named("sidebarHide").text === "Hide Trash" }, 1000)
      wait(200)
      verify(named("sidebarChoose").mapToItem(root, 0, 0).y + named("sidebarChoose").height <= trash.mapToItem(root, 0, 0).y, "above it")
      keyClick(Qt.Key_Escape)
    }

    function test_3_what_the_settings_leave_out() {
      fresh({ sounds: false, sidebarHidden: ["search", "calendar", "library", "people", "trash", "import"] })
      compare(named("searchRow"), null)
      verify(named("newPageButton") !== null, "New page, there without search too")
      compare(named("calendarTile"), null)
      compare(named("peopleTile"), null)
      compare(named("trashButton"), null)
      compare(named("importButton"), null)
      verify(named("templatesButton") !== null && named("archiveButton") !== null && named("settingsButton") !== null)
      // Settings is always there.
      root.settingsAsked = 0
      mouseClick(named("settingsButton"))
      compare(root.settingsAsked, 1)
      service.setSetting("sidebarHidden", [])
      tryVerify(function() { return named("searchRow") !== null && named("calendarTile") !== null && named("trashButton") !== null }, 1000, "all back")
    }

    function test_4_tags_as_chips() {
      fresh()
      var names = ["alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu", "nu", "xi", "omicron", "pi"]
      makePage("Tagged", "", names.map(function(n) { return Tags.html(n) }).join(" "))
      tryVerify(function() { return all("tagChip").length === names.length }, 2000, "every tag, a chip")
      settle()
      var more = named("tagsMore")
      verify(more !== null, "more than a few rows: Show all")
      compare(more.text, "Show all " + names.length)
      // Some are out of sight until then.
      var box = more.parent
      var hiddenOnes = all("tagChip").filter(function(c) { return c.mapToItem(box, 0, 0).y + c.height > more.y }).length
      verify(hiddenOnes > 0, "some past the rows shown")
      mouseClick(more)
      compare(more.text, "Show fewer")
      settle()
      verify(all("tagChip").every(function(c) { return c.mapToItem(box, 0, 0).y + c.height <= more.y }), "all of them, above it")
      // A click on one shows its blocks.
      var chip = all("tagChip").filter(function(c) { return c.modelData.name === "beta" })[0]
      mouseClick(chip, 12, chip.height / 2)
      tryCompare(view, "tagShown", "beta", 1000)
      verify(chip.current)
    }

    function test_5_a_title_typed_changes_its_row_in_place() {
      fresh()
      var a = makePage("Alpha", "")
      var b = makePage("Bravo", "")
      var row = null
      tryVerify(function() { row = all("pageRow").filter(function(r) { return r.modelData.id === b.id })[0] || null; return row !== null }, 1000)
      var others = all("pageRow").filter(function(r) { return r.modelData.id !== b.id })
      ws.index.pages[b.id].title = "Bravo two"
      ws.revision++
      tryCompare(row, "rowId", b.id)
      tryVerify(function() { return row.modelData.title === "Bravo two" }, 1000, "the same row, its title new")
      verify(others.every(function(o) { return all("pageRow").indexOf(o) >= 0 }), "the others not drawn again")
      // A page opened: its pages' rows come in under it, the rest stay.
      var c = makePage("Child", a.id)
      tryVerify(function() { return all("pageRow").some(function(r) { return r.modelData.id === a.id && r.modelData.hasChildren }) }, 1000)
      view.toggleRow(a.id)
      tryVerify(function() { return titles("pageRow").indexOf("Child") === titles("pageRow").indexOf("Alpha") + 1 }, 1000, "under it")
      verify(all("pageRow").indexOf(row) >= 0, "Bravo's row kept")
    }

    function test_6_the_middle_scrolls_as_one() {
      fresh()
      for (var i = 0; i < 40; i++) ws.createPage({ parent: "", title: "Page " + (i < 10 ? "0" : "") + i })
      tryVerify(function() { return all("pageRow").length >= 40 }, 2000)
      settle()
      var mid = named("sidebarMiddle")
      verify(mid.contentHeight > mid.height, "more than fits")
      compare(mid.contentY, 0)
      var p = mid.mapToItem(root, mid.width / 2, mid.height / 2)
      mouseWheel(root, p.x, p.y, 0, -360)
      tryVerify(function() { return mid.contentY > 100 }, 1000, "the wheel scrolls it")
      // The top and the foot stay where they are.
      var search = named("searchRow")
      verify(search.mapToItem(root, 0, 0).y < mid.y, "search above it")
      verify(named("settingsButton").mapToItem(root, 0, 0).y > mid.y + mid.height - 1, "settings below it")
    }

    function test_7_the_top_and_the_foot() {
      fresh()
      mouseClick(named("libraryTile"))
      tryVerify(function() { return view.libraryShown }, 1000)
      verify(named("libraryTile").checked)
      mouseClick(named("peopleTile"))
      tryVerify(function() { return view.peopleShown && !view.libraryShown }, 1000)
      mouseClick(named("calendarTile"))
      tryVerify(function() { return view.calendarShown }, 1000)
      mouseClick(named("templatesButton"))
      tryVerify(function() { return view.templatesShown }, 1000)
      verify(named("templatesButton").checked, "where you are")
      // A page gone to the trash: its count, there.
      var p = makePage("Old", "")
      view.trashPage(p.id)
      tryVerify(function() { return find(named("trashButton"), function(it) { return it.text === "1" }, []).length === 1 }, 1000, "1 in the trash")
      // The foot's counts, however big, never under Help and Settings.
      var tb = named("trashButton"), ab = named("archiveButton"), tpl = named("templatesButton"), hb = named("helpButton")
      tb.count = 12345; ab.count = 999; tpl.count = 120
      wait(50)
      verify(find(tb, function(it) { return it.text === "99+" }, []).length === 1, "99+")
      verify(named("footLeft").mapToItem(root, 0, 0).x + named("footLeft").width <= hb.mapToItem(root, 0, 0).x, "clear of Help")
      // New page: a row of its own, wide, above search, saying what it is.
      var np = named("newPageButton")
      verify(np.width > named("searchRow").width - 2, "as wide as search")
      verify(np.mapToItem(root, 0, 0).y + np.height <= named("searchRow").mapToItem(root, 0, 0).y, "above it")
      verify(find(np, function(it) { return it.text === "New page" }, []).length === 1, "it says so")
      var before = Object.keys(ws.index.pages).length
      mouseClick(named("newPageButton"))
      tryVerify(function() { return Object.keys(ws.index.pages).length === before + 1 }, 2000, "a new page")
      // Uber Notebook's name, at the top: a click, Settings → About (and
      // nothing under it clicked too).
      var name = named("appName")
      verify(name !== null && name.visible)
      verify(find(name, function(it) { return it.text === "Uber Notebook" }, []).length === 1)
      verify(find(name, function(it) { return it.status === Image.Ready }, []).length === 1, "its icon")
      var asked = 0
      function about() { asked++ }
      view.aboutRequested.connect(about)
      var pages = Object.keys(ws.index.pages).length
      mouseClick(name)
      view.aboutRequested.disconnect(about)
      compare(asked, 1)
      compare(Object.keys(ws.index.pages).length, pages)
    }
  }
}
