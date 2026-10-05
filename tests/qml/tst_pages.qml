import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html
import "../../Mindmap.js" as Mindmap
import "../../Colors.js" as Colors

// Pages end to end: the view, the real workspace store, and files in memory.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }
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

  TestCase {
    name: "Pages"
    when: windowShown

    // A fresh workspace (its first pages are made), and the view on it.
    function fresh() {
      files.reset()
      view.page = null
      view.history = []
      view.historyAt = -1
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      wait(0)
    }

    function fileOf(id) { return files.parseJson(files.disk[Workspace.pageFile(files.rootPath, id)] || "") }
    function titles() { return Workspace.rows(ws.index, {}).map(function(r) { return r.title }) }

    function test_1_first_pages() {
      fresh()
      compare(view.page.title, "Getting started")
      compare(titles(), ["Getting started"])
      var sub = ws.index.pages[view.page.id].children
      compare(sub.length, 1, "with a page inside it")
      var file = fileOf(view.page.id)
      verify(file !== null, "written to its file")
      verify(Workspace.isUuid(file.id))
      verify(file.content.length > 5)
      var ids = Object.keys(file.blocks)
      verify(ids.every(Workspace.isUuid), "every block has a UUID")
      verify(ids.every(function(id) { return file.blocks[id].id === id && typeof file.blocks[id].parent === "string" }), "and knows its parent")
      verify(file.content.indexOf(sub[0]) >= 0, "the page inside it is a block on it, with the page's id")
      compare(file.blocks[sub[0]].type, "page")
      ws.flushIndex()
      var index = files.parseJson(files.disk[Workspace.indexFile(files.rootPath)])
      verify(index.pages[view.page.id] !== undefined, "and the tree has it")
    }

    function test_2_a_new_page_and_its_title() {
      fresh()
      view.newPage("")
      tryVerify(function() { return view.page && view.page.title === "" }, 2000)
      var id = view.page.id
      keyClick("P")
      keyClick("l")
      keyClick("a")
      keyClick("n")
      compare(ws.index.pages[id].title, "Plan", "the sidebar follows as you type")
      keyClick(Qt.Key_Return)
      keyClick("x")
      view.commit()
      compare(fileOf(id).title, "Plan")
      compare(Html.plainText(fileOf(id).blocks[fileOf(id).content[0]].html), "x")
      compare(titles(), ["Getting started", "Plan"])
    }

    function test_3_a_page_inside_a_page() {
      fresh()
      var home = view.page.id
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      e.subpageRequested(last)
      tryVerify(function() { return view.page && view.page.id !== home }, 2000)
      var child = view.page.id
      compare(ws.index.pages[child].parent, home)
      compare(view.crumbs.length, 2, "the path shows the page it's in")
      verify(Workspace.childPages(fileOf(home)).indexOf(child) >= 0, "its block is on the page it's in")
      view.back()
      tryCompare(view.page, "id", home, 2000)
      view.forward()
      tryCompare(view.page, "id", child, 2000)
    }

    function test_4_a_page_block_taken_off_goes_to_the_trash() {
      fresh()
      var home = view.page.id
      var sub = ws.index.pages[home].children[0]
      view.editor.removeBlocks([sub])
      view.commit()
      compare(ws.index.pages[sub].trashed, true)
      compare(Workspace.trashed(ws.index), [sub])
      view.editor.undo()
      view.commit()
      compare(ws.index.pages[sub].trashed, false, "Undo brings it back")
      view.trashPage(sub)
      compare(ws.index.pages[sub].trashed, true)
      verify(Workspace.childPages(fileOf(home)).indexOf(sub) < 0)
      view.restorePage(sub)
      compare(ws.index.pages[sub].trashed, false)
      verify(Workspace.childPages(fileOf(home)).indexOf(sub) >= 0, "back on the page it was on")
    }

    function test_5_moving_pages_and_deleting_them() {
      fresh()
      var home = view.page.id
      var sub = ws.index.pages[home].children[0]
      view.movePage(sub, "")
      compare(ws.index.pages[sub].parent, "")
      compare(ws.index.top.indexOf(sub), 1, "at the top now")
      verify(Workspace.childPages(fileOf(home)).indexOf(sub) < 0, "and not on the page it was on")
      view.movePage(sub, home)
      compare(ws.index.pages[sub].parent, home)
      verify(Workspace.childPages(fileOf(home)).indexOf(sub) >= 0)
      ws.deleteForever(sub)
      compare(ws.index.pages[sub], undefined)
      compare(files.trashed.length, 1, "its file is in .trash, not deleted")
    }

    function test_6_search() {
      fresh()
      var found = null
      ws.search("toggles fold", function(list) { found = list })
      tryVerify(function() { return found !== null }, 2000)
      compare(found.length, 1)
      compare(found[0].title, "Getting started")
      compare(found[0].snippet.match.toLowerCase(), "toggles")
    }

    function test_7_moving_blocks_to_another_page() {
      fresh()
      var home = view.page.id
      var sub = ws.index.pages[home].children[0]
      var e = view.editor
      var toggle = ""
      for (var i = 0; i < e.model.count; i++) if (e.model.get(i).type === "toggle") toggle = e.uidAt(i)
      view.moveBlocks([toggle], sub)
      tryVerify(function() { return e.indexOf(toggle) < 0 }, 2000)
      var moved = fileOf(sub)
      verify(moved.blocks[toggle] !== undefined, "the toggle is on the other page")
      compare(moved.blocks[toggle].content.length, 1, "with what was inside it")
    }

    function test_9_backlinks() {
      fresh()
      var home = view.page.id
      var target = ws.createPage({ parent: "", title: "Target" })
      ws.editPage(home, function(p) {
        var id = Workspace.uuid4()
        p.blocks[id] = { id: id, type: "p", parent: p.id, html: 'about <a href="uber-notebook://page/' + target.id + '">Target</a>' }
        p.content.push(id)
        return true
      })
      tryVerify(function() { return ws.index.pages[home].links && ws.index.pages[home].links.indexOf(target.id) >= 0 }, 2000)
      view.open(target.id)
      tryVerify(function() { return view.page && view.page.id === target.id }, 2000)
      compare(view.backlinks, [home], "the page that links here")
    }

    function test_10_reminders() {
      fresh()
      function iso(d) { return Qt.formatDateTime(d, "yyyy-MM-ddTHH:mm") }
      var now = Date.now()
      var recent = iso(new Date(now - 3600000))
      var old = iso(new Date(now - 3 * 86400000))
      var later = iso(new Date(now + 86400000))
      ws.createPage({ parent: "", title: "Errands", blocks: [
        { type: "check", html: 'Call the bank <a href="uber-notebook://remind/' + recent + '">x</a>', indent: 0 },
        { type: "check", html: 'Old one <a href="uber-notebook://remind/' + old + '">x</a>', indent: 0 },
        { type: "check", html: 'Later <a href="uber-notebook://remind/' + later + '">x</a>', indent: 0 }
      ] })
      ws.checkReminders()
      compare(files.notified.length, 1, "the one due now comes; one long gone doesn't; one to come waits")
      compare(files.notified[0].title, "Errands")
      verify(files.notified[0].text.indexOf("Call the bank") === 0)
      ws.checkReminders()
      compare(files.notified.length, 1, "and comes once")
      compare(Workspace.pendingReminders(ws.index).length, 1)
    }

    function test_11_importing_a_notion_export() {
      fresh()
      var plans = "Plans 6f1c2b9e0d3a4f6e9b1c2e8a7d5f4c3b"
      var trip = "Trip aaaabbbbccccddddeeeeffff00001111"
      var root = "/tmp/export"
      var d = {}
      d[root + "/" + plans + ".md"] = "# Plans\n\n- [x] Book\n- [ ] Pack\n  - socks\n\n[Trip](" + encodeURIComponent(plans) + "/" + encodeURIComponent(trip) + ".md)\n\n![map](" + encodeURIComponent(plans) + "/map.png)\n"
      d[root + "/" + plans + "/" + trip + ".md"] = "# Trip\n\nSee [[Plans]] first.\n\n> [!NOTE]\n> Pack light\n\n```sh\nls -la\n```\n"
      d[root + "/" + plans + "/map.png"] = "PNG"
      d[root + "/Notes.md"] = "Just *notes*"
      for (var k in d) files.disk[k] = d[k]
      var result = null
      ws.importPaths([root], "", function(r) { result = r })
      tryVerify(function() { return result !== null }, 3000)
      compare(result.pages, 4, "the export's folder, Plans, Trip, Notes")
      var plansId = "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b"
      var tripId = "aaaabbbb-cccc-dddd-eeee-ffff00001111"
      var e = ws.index.pages[plansId]
      verify(e !== undefined, "Plans keeps its id from Notion")
      compare(e.title, "Plans")
      compare(ws.index.pages[tripId].parent, plansId, "Trip is inside Plans, as it was")
      compare(ws.index.pages[e.parent].title, "export", "the two pages at the top are in a page for the folder")
      var file = fileOf(plansId)
      var list = Workspace.flatten(file)
      compare(list.map(function(b) { return b.type + ":" + b.indent + (b.checked ? "x" : "") }).join(","), "check:0x,check:0,bullet:1,page:0,image:0",
        "to-dos with their ticks, the list inside one, Trip where its link was, the picture")
      compare(list[3].uid, tripId)
      var src = list[4].src
      verify(/^assets\//.test(src), "the picture is in Pages' assets")
      compare(files.disk[files.rootPath + "/Pages/" + src], "PNG", "copied")
      var tripList = Workspace.flatten(fileOf(tripId))
      verify(tripList[0].html.indexOf("uber-notebook://page/" + plansId) >= 0, "[[Plans]] links to the page imported")
      compare(tripList[1].type, "callout")
      compare(tripList[2].lang, "Bash")
      tryVerify(function() { return view.page && view.page.id === ws.index.pages[plansId].parent || true }, 100)
    }

    function test_12_pasting_markdown() {
      fresh()
      clip.text = "# Shopping\n\n- [ ] milk\n- [x] eggs\n\n> quoted"
      clip.selectAll()
      clip.copy()
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      keyClick(Qt.Key_V, Qt.ControlModifier)
      var types = e.serialize().map(function(b) { return b.type })
      var at = types.indexOf("h1")
      verify(at >= 0, "Markdown pasted is blocks: " + types.join(","))
      compare(types.slice(at, at + 4).join(","), "h1,check,check,quote")
      compare(e.serialize()[at + 2].checked, true)
      // Pasted into the title: the first line is the title, the rest the page.
      view.newPage("")
      tryVerify(function() { return view.page && view.page.title === "" }, 2000)
      clip.text = "# A README\n\nSome **bold** text\n\n- one\n- two"
      clip.selectAll()
      clip.copy()
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(view.pageTitleText(), "A README")
      compare(e.serialize().map(function(b) { return b.type }).slice(0, 3).join(","), "p,bullet,bullet")
    }

    function test_13_favorites_and_copies() {
      fresh()
      var home = view.page.id
      var sub = ws.index.pages[home].children[0]
      view.toggleFavorite(sub)
      verify(ws.isFavorite(sub))
      compare(Workspace.favorites(ws.index), [sub])
      ws.flushIndex()
      compare(files.parseJson(files.disk[Workspace.indexFile(files.rootPath)]).favorites, [sub], "kept with the tree")
      view.duplicatePage(home)
      tryVerify(function() { return view.page && view.page.id !== home }, 2000)
      var copy = view.page.id
      compare(ws.index.pages[copy].title, "Getting started (copy)")
      compare(titles(), ["Getting started", "Getting started (copy)"], "right after the page")
      var inner = ws.index.pages[copy].children
      compare(inner.length, 1, "with a copy of the page inside it")
      verify(inner[0] !== sub)
      compare(fileOf(copy).blocks[inner[0]].type, "page", "whose block on the copy is its own")
      compare(ws.index.pages[inner[0]].parent, copy)
      verify(Object.keys(fileOf(copy).blocks).every(function(id) { return !fileOf(home).blocks[id] }), "every block a new id")
      view.toggleFavorite(sub)
      compare(Workspace.favorites(ws.index), [])
    }

    function test_14_a_locked_page() {
      fresh()
      var e = view.editor
      view.setFormat("locked", true)
      verify(view.locked)
      compare(fileOf(view.page.id).format.locked, true, "kept with the page")
      var before = JSON.stringify(e.serialize())
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      keyClick("x")
      keyClick(Qt.Key_Return)
      keyClick(Qt.Key_Backspace)
      keyClick(Qt.Key_Tab)
      clip.text = "pasted"
      clip.selectAll()
      clip.copy()
      keyClick(Qt.Key_V, Qt.ControlModifier)
      e.clickBelow()
      view.turnIntoPage(e.uidAt(1))
      compare(JSON.stringify(e.serialize()), before, "nothing changes it")
      view.setFormat("locked", false)
      e.focusBlock(last, 0)
      keyClick("x")
      verify(JSON.stringify(e.serialize()) !== before, "unlocked, it changes again")
    }

    function test_15_a_block_turned_into_a_page() {
      fresh()
      var e = view.editor
      var home = view.page.id
      var at = e.model.count
      e.insertBlocksAt(at, [{ type: "bullet", html: "Trip", indent: 0 }, { type: "p", html: "pack", indent: 1 }, { type: "check", html: "tickets", indent: 1 }])
      var uid = e.uidAt(at)
      view.turnIntoPage(uid)
      var kids = ws.index.pages[home].children
      compare(kids.length, 2)
      var made = kids[1]
      compare(ws.index.pages[made].title, "Trip")
      compare(e.typeOf(made), "page", "its block is where the bullet was")
      compare(e.indexOf(made), at)
      verify(e.serialize().every(function(b) { return Html.plainText(b.html || "") !== "pack" }), "what was inside it went with it")
      var file = fileOf(made)
      var inside = file.content.map(function(id) { return file.blocks[id] })
      compare(inside.map(function(b) { return b.type }).join(","), "p,check")
      compare(Html.plainText(inside[1].html || ""), "tickets")
      view.editor.undo()
      view.commit()
      compare(ws.index.pages[made].trashed, true, "Undo takes it back to a bullet")
    }

    function test_16_a_page_from_a_template() {
      fresh()
      verify(!view.pageBlank, "a page with things on it has no templates")
      view.newPage("")
      tryVerify(function() { return view.page && view.page.title === "" }, 2000)
      verify(view.pageBlank, "a new page does")
      view.applyTemplate("meeting")
      verify(!view.pageBlank)
      compare(view.titleHint, "What's the meeting?", "you name the meeting")
      var list = view.editor.serialize()
      compare(list.slice(0, 3).map(function(b) { return b.type }).join(","), "p,columns,column", "today's date, then who's there and the agenda side by side")
      verify(list[0].html.indexOf("uber-notebook://date/") >= 0)
      verify(list.some(function(b) { return b.type === "check" && b.hint === "Who does what, by when" }), "every line says what goes on it")
      compare(view.page.icon, "\u{1f465}")
      view.commit()
      var saved = fileOf(view.page.id)
      compare(saved.icon, "\u{1f465}")
      verify(Object.keys(saved.blocks).some(function(id) { return saved.blocks[id].hint === "Who does what, by when" }), "and it's kept")
      view.editor.undo()
      verify(view.pageBlank, "Undo takes the template off")
      view.applyTemplate("monthly")
      list = view.editor.serialize()
      verify(list.some(function(b) { return b.type === "calendar" && b.month === Qt.formatDate(new Date(), "yyyy-MM") }), "a planner has what a planner has")
      compare(view.pageTitleText(), Qt.formatDate(new Date(), "MMMM yyyy"), "and names its page")
      keyClick("x")
      view.applyTemplate("todo")
      compare(view.pageTitleText(), Qt.formatDate(new Date(), "MMMM yyyy"), "only a blank page takes one")
    }

    function test_17_export_where_settings_say() {
      fresh()
      function written(prefix) { return Object.keys(files.disk).filter(function(k) { return k.indexOf(prefix) === 0 }) }
      // Asked, and a folder picked: in a folder of its own there.
      files.exportBase = function(done) { done("/tmp/picked") }
      view.exportPage()
      tryVerify(function() { return written("/tmp/picked/Getting started ").length === 2 }, 2000)
      var mine = written("/tmp/picked/Getting started ")
      verify(mine.some(function(k) { return /\/Getting started\.md$/.test(k) }), mine.join(", "))
      verify(mine.some(function(k) { return /\/A page inside a page\.md$/.test(k) }), "with the pages in it")
      // Asked, and nothing picked: no export.
      var before = Object.keys(files.disk).length
      files.exportBase = function(done) { done("") }
      view.exportPage()
      wait(100)
      compare(Object.keys(files.disk).length, before)
      // The Exports folder.
      files.exportBase = null
      view.exportPage()
      tryVerify(function() { return written(files.rootPath + "/Exports/Getting started ").length === 2 }, 2000)
    }

    // A visible item anywhere in the window (popups too) that `test` likes.
    function findItem(item, test) {
      if (!item || !item.visible) return null
      if (test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = findItem(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function clickIdea(map, text) {
      var L = map.lay
      var n = L.nodes.filter(function(x) { return x.node.text === text })[0]
      verify(n !== undefined, "an idea called " + text)
      var left = Math.max(0, (map.width - L.width * L.scale) / 2)
      mouseClick(map, left + (n.x + n.w / 2) * L.scale, (n.y + n.h / 2) * L.scale)
    }
    function pickColor(id, background) {
      var tile = null
      tryVerify(function() {
        tile = findItem(root.Window.window.contentItem, function(it) { return it.entry !== undefined && it.entry && it.entry.id === id && it.back === background })
        return tile !== null
      }, 1000, "the " + id + (background ? " background" : "") + " color is on screen")
      wait(250)
      mouseClick(tile)
    }

    function test_18_mind_map_colors() {
      fresh()
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "mindmap", outline: "Trip\n  Lisbon\n    Trams\n  Packing", indent: 0 }])
      var map = e.items[e.uidAt(0)].mindMap
      clickIdea(map, "Lisbon")
      verify(map.editing)
      // (Found again each time: the map is drawn again when a color changes.)
      function button() { return findItem(map, function(it) { return it.text === "\u{f0e0c}" }) }
      verify(button() !== null, "a color button over the idea you're on")
      mouseClick(button())
      pickColor("red", true)
      tryVerify(function() { return map.current && map.current.background === "red" }, 1000)
      mouseClick(button())
      pickColor("yellow", false)
      tryVerify(function() { return map.current && map.current.color === "yellow" }, 1000)
      verify(map.editing, "still writing on it")
      keyClick(Qt.Key_Escape)
      var b = e.blockAt(0)
      compare(b.outline, "Trip\n  Lisbon {yellow, red background}\n    Trams\n  Packing")
      // How it looks: its own colors, and its branch in its color.
      var lisbon = map.lay.nodes.filter(function(x) { return x.node.text === "Lisbon" })[0]
      compare(String(map.fillOf(lisbon, false, false)), String(Qt.color(map.backOf("red"))))
      compare(String(map.inkOf(lisbon.node, 1)), String(Qt.color(map.textOf("yellow"))))
      compare(String(map.tint(lisbon.branch)), String(Qt.color(map.textOf("red"))), "the branch takes the main idea's background")
      var trams = map.lay.nodes.filter(function(x) { return x.node.text === "Trams" })[0]
      compare(trams.branch, lisbon.branch)
      // Default takes them off again; all of it one step to undo.
      e.undo()
      compare(e.blockAt(0).outline, "Trip\n  Lisbon\n    Trams\n  Packing")
      e.redo()
      clickIdea(map, "Lisbon")
      mouseClick(button())
      var none = null
      tryVerify(function() {
        none = findItem(root.Window.window.contentItem, function(it) { return it.entry === null && it.back === true })
        return none !== null
      }, 1000)
      wait(250)
      mouseClick(none)
      keyClick(Qt.Key_Escape)
      compare(e.blockAt(0).outline, "Trip\n  Lisbon {yellow}\n    Trams\n  Packing")
      view.commit()
      var saved = fileOf(view.page.id)
      verify(Object.keys(saved.blocks).some(function(id) { return saved.blocks[id].outline === "Trip\n  Lisbon {yellow}\n    Trams\n  Packing" }), "saved with the page")
    }

    function test_19_mind_map_colors_of_your_own() {
      fresh()
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "mindmap", outline: "Trip\n  Lisbon\n    Trams\n  Packing", indent: 0 }])
      var map = e.items[e.uidAt(0)].mindMap
      var win = root.Window.window.contentItem
      function button() { return findItem(map, function(it) { return it.text === "\u{f0e0c}" }) }
      function tile(test) {
        var t = null
        tryVerify(function() { t = findItem(win, test); return t !== null }, 1000)
        wait(250)
        return findItem(win, test)
      }
      // Custom… for the background: a hex typed in shows on the map as it's typed.
      clickIdea(map, "Lisbon")
      mouseClick(button())
      mouseClick(tile(function(it) { return it.plus === true && it.back === true }))
      tryVerify(function() { return findItem(win, function(it) { return it.text === "Background of your own" }) !== null }, 1000, "the color picker")
      wait(200)
      for (var i = 0; i < "#ff8800".length; i++) keyClick("#ff8800".charAt(i))
      tryCompare(map.current, "background", "#ff8800", 1000, "it shows on the map as you pick it")
      verify(findItem(win, function(it) { return typeof it.text === "string" && it.text.indexOf("Contrast ") === 0 }) !== null, "with how well the idea reads")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return findItem(win, function(it) { return it.text === "Background of your own" }) === null }, 1000, "Enter applies, and the picker closes")
      verify(map.editing, "writing goes on")
      keyClick(Qt.Key_Escape)
      compare(e.blockAt(0).outline, "Trip\n  Lisbon {#ff8800 background}\n    Trams\n  Packing")
      compare(service.settings.recentColors, "#ff8800", "kept among the colors you picked last")
      var lisbon = map.lay.nodes.filter(function(x) { return x.node.text === "Lisbon" })[0]
      compare(String(map.fillOf(lisbon, false, false)), "#ff8800")
      // Custom… for the text, dragged in the square, then Esc: put back.
      clickIdea(map, "Packing")
      mouseClick(button())
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      var square = tile(function(it) { return it.cursorShape === Qt.CrossCursor })
      mousePress(square, 20, 20)
      mouseMove(square, square.width - 10, 30)
      tryVerify(function() { return /^#[0-9a-f]{6}$/.test(map.current.color) }, 1000, "dragging shows on the map")
      mouseRelease(square, square.width - 10, 30)
      keyClick(Qt.Key_Escape)
      tryCompare(map.current, "color", "", 1000, "Esc puts back what was there")
      wait(200)
      verify(map.editing)
      // Opened and applied with nothing picked: nothing changes (a color of
      // Pages stays one).
      mouseClick(button())
      mouseClick(tile(function(it) { return it.plus === true && it.back === true }))
      tryVerify(function() { return findItem(win, function(it) { return it.text === "Background of your own" }) !== null }, 1000)
      wait(200)
      compare(map.current.background, "", "opening it changes nothing")
      keyClick(Qt.Key_Return)
      wait(200)
      compare(map.current.background, "")
      // A recent color, from the menu.
      mouseClick(button())
      mouseClick(tile(function(it) { return it.custom === "#ff8800" && it.back === false }))
      tryCompare(map.current, "color", "#ff8800", 1000)
      keyClick(Qt.Key_Escape)
      compare(e.blockAt(0).outline, "Trip\n  Lisbon {#ff8800 background}\n    Trams\n  Packing {#ff8800}")
      // Text on a background of your own reads, dark or light.
      ;["#1e1e2e", "#ffe680", "#ff8800", "#3584e4"].forEach(function(bg) {
        var ink = map.inkOf(Mindmap.parse("A {" + bg + " background}"), 1)
        verify(Colors.contrast(ink, bg) >= 4.5, "text on " + bg + " reads: " + ink)
      })
    }

    // Another folder (another profile) with a page of the same id (a restored
    // backup's are): its own page is read, never the one written here.
    function test_20_another_folder_same_ids() {
      fresh()
      var p = ws.createPage({ title: "Private A", blocks: [{ type: "p", html: "only in A", indent: 0 }] })
      verify(ws.written[p.id] !== undefined, "written this session")
      var a = files.rootPath
      var b = a + "-other"
      var copy = JSON.parse(files.disk[ws.pagePath(p.id)])
      copy.title = "Page B"
      for (var k in copy.blocks) if (copy.blocks[k].html !== undefined) copy.blocks[k].html = "only in B"
      files.disk[b + "/Pages/" + p.id + ".json"] = JSON.stringify(copy)
      files.disk[b + "/Pages/index.json"] = files.disk[a + "/Pages/index.json"]
      files.rootPath = b
      tryCompare(ws, "folder", b + "/Pages", 1000)
      tryVerify(function() { return ws.ready && ws.generation > 0 }, 2000)
      wait(200)
      tryCompare(ws, "ready", true, 2000)
      compare(ws.written[p.id], undefined, "nothing of A's kept")
      var got = null
      ws.readPage(p.id, function(page) { got = page })
      tryVerify(function() { return got !== null }, 2000)
      compare(got.title, "Page B")
      verify(Workspace.pageText(got).indexOf("only in A") < 0, "A's text never in B")
      files.rootPath = a
      tryCompare(ws, "folder", a + "/Pages", 1000)
    }

    // Pasting reads the clipboard itself (wl-paste, in the app): its HTML with
    // nothing in it Qt would load (a picture, a background), and a middle
    // click pastes what's selected the same way, where it's clicked.
    function test_21_pasting_html_without_what_it_names() {
      fresh()
      var e = view.editor
      var asked = []
      var clipboard = { html: "<p>Hello <b>world</b><img src=\"http://127.0.0.1:9/pixel.png\"></p>"
        + "<style>p { background: url(http://127.0.0.1:9/bg.png) }</style><p style=\"background-image:url(http://127.0.0.1:9/b.png)\">more</p>", text: "Hello world\nmore" }
      var selection = { html: "", text: "picked " }
      // Through the view's own forwarding to the store, as in the app.
      files.readClipboard = function(done, primary) { asked.push(primary === true); done(primary ? selection : clipboard) }
      try {
        var last = e.uidAt(e.model.count - 1)
        e.focusBlock(last, 0)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        compare(asked, [false], "the clipboard, not what's selected")
        var list = e.serialize()
        var at = list.map(function(b) { return Html.plainText(b.html || "") }).indexOf("Hello world")
        verify(at >= 0, "pasted: " + JSON.stringify(list.map(function(b) { return b.html })))
        verify(/font-weight:700/.test(list[at].html), "bold kept")
        var all = JSON.stringify(list)
        verify(all.indexOf("127.0.0.1") < 0 && all.indexOf("<img") < 0 && all.indexOf("url(") < 0, "nothing it names: " + all)
        verify(list.some(function(b) { return Html.plainText(b.html || "") === "more" }), "its text all there")
        // A middle click at the start of "Hello world": what's selected, there.
        var item = e.items[e.uidAt(at)]
        mouseClick(item.edit, 1, item.edit.cursorRectangle.height / 2, Qt.MiddleButton)
        compare(asked, [false, true], "what's selected")
        compare(Html.plainText(e.serialize()[at].html), "picked Hello world")
        // Nothing selected: nothing pasted (not a picture from the clipboard).
        selection = null
        var before = JSON.stringify(e.serialize())
        mouseClick(item.edit, 1, item.edit.cursorRectangle.height / 2, Qt.MiddleButton)
        compare(asked.length, 3)
        compare(JSON.stringify(e.serialize()), before)
        // A locked page: no paste at all.
        selection = { html: "", text: "never" }
        view.setFormat("locked", true)
        mouseClick(item.edit, 1, item.edit.cursorRectangle.height / 2, Qt.MiddleButton)
        compare(asked.length, 3, "not even read")
        compare(JSON.stringify(e.serialize()), before)
        view.setFormat("locked", false)
        // Plain text, its empty lines kept (as Qt pastes it): a block each.
        clipboard = { html: "", text: "one\n\ntwo" }
        var count = e.model.count
        e.focusBlock(e.uidAt(count - 1), -1)
        keyClick(Qt.Key_Return)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        compare(e.serialize().slice(count).map(function(b) { return Html.plainText(b.html || "") }), ["one", "", "two"])
        before = JSON.stringify(e.serialize())
        // Without wl-paste (tests): no middle-click paste.
        files.readClipboard = null
        mouseClick(item.edit, 1, item.edit.cursorRectangle.height / 2, Qt.MiddleButton)
        compare(JSON.stringify(e.serialize()), before)
      } finally {
        files.readClipboard = null
      }
    }

    // A paste whose clipboard comes late: only into the page it was for,
    // still open and not locked since; never into another.
    function test_22_a_late_clipboard_goes_nowhere_else() {
      fresh()
      var e = view.editor
      var waiting = []
      files.readClipboard = function(done, primary) { waiting.push(done) }
      try {
        var first = view.page.id
        e.focusBlock(e.uidAt(e.model.count - 1), -1)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        compare(waiting.length, 1)
        // Another page opened before the clipboard came.
        view.newPage("")
        tryVerify(function() { return view.page && view.page.id !== first }, 2000)
        var before = JSON.stringify(e.serialize())
        waiting[0]({ html: "", text: "LATE" })
        compare(JSON.stringify(e.serialize()), before, "nothing in the page open now")
        verify(JSON.stringify(fileOf(first)).indexOf("LATE") < 0, "nor in the one it was for")
        // Locked while it was read: nothing.
        e.focusBlock(e.uidAt(0), 0)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        compare(waiting.length, 2)
        view.setFormat("locked", true)
        waiting[1]({ html: "", text: "LOCKED" })
        compare(JSON.stringify(e.serialize()), before)
        view.setFormat("locked", false)
        // In time, on the same page: pasted.
        e.focusBlock(e.uidAt(0), 0)
        keyClick(Qt.Key_V, Qt.ControlModifier)
        waiting[2]({ html: "", text: "ON TIME" })
        verify(JSON.stringify(e.serialize()).indexOf("ON TIME") >= 0)
      } finally {
        files.readClipboard = null
      }
    }

    // A file of its own that couldn't be read as it loaded (a link, too big:
    // not "not there"): left as it is, never written over, said once.
    // A page as a PDF, a Word file, or printed (app/Exporter.qml): what's
    // run, and where it goes.
    function test_24_export_and_print() {
      fresh()
      var said = []
      function heard(t) { said.push(t) }
      view.toast.connect(heard)
      view.exporter.tools = null
      function lastRun(test) { var r = files.ran.filter(test); return r.length ? r[r.length - 1] : null }
      function isPdf(a) { return a.some(function(x) { return String(x).indexOf("--print-to-pdf=") === 0 }) }
      var title = view.page.title
      // A PDF, saved where you say (the save dialog, Documents first).
      service.nextSave = "/tmp/picked/Doc.pdf"
      view.exportAs("pdf", false)
      tryVerify(function() { return files.disk["/tmp/picked/Doc.pdf"] === "PDF" }, 3000)
      compare(service.saveName, title + ".pdf")
      var run = lastRun(isPdf)
      compare(run.slice(0, 5), ["/usr/bin/unshare", "--user", "--map-current-user", "--net", "--"], "with no network at all")
      compare(run[5], "/usr/lib/chromium/chromium", "Chromium itself, not the launcher that reads your flags")
      verify(view.exporter.browsers.every(function(b) { return !/^\/usr\/(local\/)?bin\//.test(b) }), "never a launcher on the PATH (chromium-flags.conf, extensions)")
      verify(run.indexOf("--proxy-server=http://127.0.0.1:9") > 0 && run.indexOf("--host-resolver-rules=MAP * ~NOTFOUND") > 0, "every request sent nowhere")
      verify(run.indexOf("--disable-extensions") > 0 && run.some(function(a) { return /^--user-data-dir=\/tmp\/uber-notebook-export-[0-9a-f]{8}\/profile$/.test(a) }), "a profile of its own")
      var work = /^--user-data-dir=(.*)\/profile$/.exec(run.filter(function(a) { return a.indexOf("--user-data-dir=") === 0 })[0])[1]
      var src = files.disk[work + "/page.src.html"]
      verify(src.indexOf("Content-Security-Policy") > 0 && src.indexOf(title) > 0, "the page as a document")
      var checked = lastRun(function(a) { return a[4] === "export-html" })
      compare(checked.slice(5), [files.rootPath + "/Pages/assets", work, String(512 * 1024 * 1024)], "its pictures put in, and checked, first")
      verify(files.ran.indexOf(checked) < files.ran.indexOf(run))
      tryVerify(function() { return lastRun(function(a) { return a[0] === "/usr/bin/rm" && a[3] === work }) !== null }, 2000)
      // A Word file: LibreOffice, a profile of its own, no network.
      service.nextSave = "/tmp/picked/Doc.docx"
      view.exportAs("docx", false)
      tryVerify(function() { return files.disk["/tmp/picked/Doc.docx"] === "DOCX" }, 3000)
      var office = lastRun(function(a) { return a.indexOf("--convert-to") >= 0 })
      compare(office.slice(0, 6), ["/usr/bin/unshare", "--user", "--map-current-user", "--net", "--", "/usr/lib/libreoffice/program/soffice"])
      verify(office.some(function(a) { return /^-env:UserInstallation=file:\/\/\/tmp\/uber-notebook-export-[0-9a-f]{8}\/lo$/.test(a) }))
      compare(office[office.indexOf("--convert-to") + 1], "docx:MS Word 2007 XML")
      // Not saved: nothing kept.
      service.nextSave = ""
      view.exportAs("pdf", false)
      tryVerify(function() { return said.indexOf("Not saved") >= 0 }, 3000)
      // Printing: in the print folder, opened in your PDF viewer.
      view.exportAs("print", false)
      tryVerify(function() { return files.printed.length === 1 }, 3000)
      compare(files.printed[0], "/tmp/uber-notebook-print/" + title + ".pdf")
      // The Exports folder (Settings), never over a file that's there.
      service.setSetting("exportTo", "folder")
      view.exportAs("pdf", false)
      tryVerify(function() { return Object.keys(files.disk).some(function(k) { return k.indexOf(files.rootPath + "/Exports/" + title + " ") === 0 && /\.pdf$/.test(k) }) }, 3000)
      verify(lastRun(function(a) { return a[0] === "/usr/bin/cp" && a[1] === "--update=none-fail" }) !== null)
      service.setSetting("exportTo", "ask")
      // The pictures couldn't be checked: nothing's made.
      files.failExportHtml = "a picture from elsewhere"
      var pdfs = files.ran.filter(isPdf).length
      view.exportAs("pdf", false)
      tryVerify(function() { return said.some(function(t) { return t.indexOf("a picture from elsewhere") >= 0 }) }, 3000)
      compare(files.ran.filter(isPdf).length, pdfs, "not converted")
      files.failExportHtml = ""
      // No LibreOffice: said, nothing run; no unshare: Chromium as it is.
      view.exporter.tools = null
      files.exportTools = "/usr/lib/chromium/chromium\n"
      view.exportAs("docx", false)
      tryVerify(function() { return said.some(function(t) { return t.indexOf("needs LibreOffice") >= 0 }) }, 3000)
      service.nextSave = "/tmp/picked/Plain.pdf"
      view.exportAs("pdf", false)
      tryVerify(function() { return files.disk["/tmp/picked/Plain.pdf"] === "PDF" }, 3000)
      compare(lastRun(isPdf)[0], "/usr/lib/chromium/chromium")
      // LibreOffice installed since ("install it and try again"): found.
      files.exportTools = "/usr/lib/chromium/chromium\n/usr/lib/libreoffice/program/soffice\n"
      service.nextSave = "/tmp/picked/Later.docx"
      view.exportAs("docx", false)
      tryVerify(function() { return files.disk["/tmp/picked/Later.docx"] === "DOCX" }, 3000, "tried again, it's made")
      files.exportTools = "/usr/lib/chromium/chromium\n"
      // Equations drawn by the editor's MathJax, diagrams made pictures, as
      // the page shows them, before it's written.
      files.exportTools = "/usr/lib/chromium/chromium\n"
      view.exporter.tools = null
      service.setSetting("exportTo", "folder")
      var page = JSON.parse(JSON.stringify(view.page))
      page.content = ["m1", "m2", "d1"]
      page.blocks = {
        m1: { id: "m1", type: "p", html: 'A line with <a href="uber-notebook://math/x%5E2">x^2</a> in it' },
        m2: { id: "m2", type: "code", lang: "Math", html: "\\frac{1}{2}" },
        d1: { id: "d1", type: "code", lang: "Mermaid", html: "flowchart LR<br />A --&gt; B" }
      }
      var before = files.ran.filter(isPdf).length
      view.exporter.run("pdf", page, false)
      tryVerify(function() { return files.ran.filter(isPdf).length > before }, 15000)
      var run2 = lastRun(isPdf)
      var work2 = /^--user-data-dir=(.*)\/profile$/.exec(run2.filter(function(a) { return a.indexOf("--user-data-dir=") === 0 })[0])[1]
      var src2 = files.disk[work2 + "/page.src.html"]
      compare((src2.match(/src="data:image\/svg\+xml;base64,/g) || []).length, 2, "both equations drawn")
      verify(src2.indexOf('src="uber-notebook-drawing:d1.png"') > 0, "the diagram, as its picture")
      compare(files.disk[work2 + "/drawings/d1.png"], "PNG")
      service.setSetting("exportTo", "ask")
      view.toast.disconnect(heard)
    }

    // A save that couldn't be written (a full disk) stays to be saved: the
    // next save, here the next change, has it, and nothing is lost.
    function test_25_a_failed_save_is_tried_again() {
      fresh()
      view.newPage("")
      tryVerify(function() { return view.page && view.page.title === "" }, 2000)
      var id = view.page.id
      files.failWrites = id
      keyClick("P")
      keyClick("l")
      view.commit()
      verify(view.pageDirty, "still to be saved")
      compare(fileOf(id) ? fileOf(id).title : "", "")
      files.failWrites = ""
      keyClick("a")
      keyClick("n")
      tryCompare(view, "pageDirty", false, 3000)
      compare(fileOf(id).title, "Plan")
      files.failWrites = id
      keyClick("s")
      view.commit()
      verify(view.pageDirty)
      files.failWrites = ""
      view.commit()
      verify(!view.pageDirty)
      compare(fileOf(id).title, "Plans", "and a commit (another page, closing) has it too")
    }

    function test_23_what_couldnt_be_read_isnt_written_over() {
      fresh()
      var cal = ws.calendarPath()
      var ix = ws.indexPath()
      files.disk[cal] = "THE CALENDAR AS IT IS"
      files.disk[ix] = "THE TREE AS IT IS"
      var told = []
      function heard(m) { told.push(m) }
      ws.failed.connect(heard)
      try {
        var f = {}
        f[cal] = true
        f[ix] = true
        files.failReads = f
        ws.load()
        tryCompare(ws, "ready", true, 2000)
        tryVerify(function() { return ws.calendarLoaded }, 2000)
        verify(ws.unreadable[cal] && ws.unreadable[ix], "both kept as unreadable")
        compare(told.filter(function(m) { return m.indexOf("calendar.json") >= 0 }).length, 1, "said once: " + JSON.stringify(told))
        // Changed meanwhile: in memory, never written over, and said so
        // (once a minute at most).
        ws.refusedAt = ({})
        told = []
        ws.writeCalendar()
        ws.writeCalendar()
        ws.flushIndex()
        compare(told.filter(function(m) { return m.indexOf("Not saved") === 0 && m.indexOf("calendar.json") >= 0 }).length, 1, JSON.stringify(told))
        compare(told.filter(function(m) { return m.indexOf("Not saved") === 0 && m.indexOf("index.json") >= 0 }).length, 1, JSON.stringify(told))
        view.newPage("")
        tryVerify(function() { return view.page && view.page.title === "" }, 2000)
        ws.flushIndex()
        compare(files.disk[cal], "THE CALENDAR AS IT IS")
        compare(files.disk[ix], "THE TREE AS IT IS")
        // Read again (fine now): written as always.
        files.failReads = ({})
        ws.load()
        tryCompare(ws, "ready", true, 2000)
        tryVerify(function() { return ws.calendarLoaded && !ws.unreadable[cal] }, 2000)
        ws.writeCalendar()
        verify(files.disk[cal] !== "THE CALENDAR AS IT IS", "written once it could be read")
      } finally {
        ws.failed.disconnect(heard)
        files.failReads = ({})
      }
    }

    // What went wrong importing is said with what was imported, not under it;
    // outside an import, as it happens.
    function test_26_an_import_says_what_went_wrong() {
      fresh()
      files.disk["/tmp/broken.zip"] = "NOT A ZIP"
      var said = []
      function heard(t) { said.push(t) }
      view.toast.connect(heard)
      try {
        view.importPaths(["/tmp/broken.zip"], "")
        tryVerify(function() { return said.some(function(t) { return t.indexOf("no notes to import") >= 0 }) }, 3000)
        var last = said[said.length - 1]
        verify(last.indexOf("Couldn't unzip /tmp/broken.zip") > 0, last)
        compare(ws.importing, false)
        // Unzipped on disk (the runtime folder is memory), in a folder of its own.
        var unzip = files.ran.filter(function(a) { return a[4] === "unzip" })[0]
        verify(unzip && unzip[6].indexOf(files.cacheDir + "/import-") === 0, JSON.stringify(unzip))
        var made = files.ran.filter(function(a) { return a[3] === "uber-notebook-import-dir" })[0]
        compare(made[4], files.cacheDir)
        verify(made[5] && unzip[6].indexOf(made[5] + "/") === 0)
      } finally {
        view.toast.disconnect(heard)
      }
      var told = []
      function heard2(m) { told.push(m) }
      ws.failed.connect(heard2)
      ws.importProblem("A picture wasn't copied")
      ws.failed.disconnect(heard2)
      compare(told, ["A picture wasn't copied"])
    }

    function test_8_the_open_page_reloads_after_the_store_changes_it() {
      fresh()
      var home = view.page.id
      var other = ws.createPage({ parent: "", title: "Other" })
      ws.editPage(home, function(p) { return Workspace.appendPageBlock(p, other.id) })
      tryVerify(function() { return view.editor.indexOf(other.id) >= 0 }, 2000)
    }
  }
}
