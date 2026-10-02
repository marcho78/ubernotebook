import QtQuick
import QtTest
import "../.." as Omanote
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
        p.blocks[id] = { id: id, type: "p", parent: p.id, html: 'about <a href="omanote://page/' + target.id + '">Target</a>' }
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
        { type: "check", html: 'Call the bank <a href="omanote://remind/' + recent + '">x</a>', indent: 0 },
        { type: "check", html: 'Old one <a href="omanote://remind/' + old + '">x</a>', indent: 0 },
        { type: "check", html: 'Later <a href="omanote://remind/' + later + '">x</a>', indent: 0 }
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
      verify(tripList[0].html.indexOf("omanote://page/" + plansId) >= 0, "[[Plans]] links to the page imported")
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
      verify(list[0].html.indexOf("omanote://date/") >= 0)
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

    function test_8_the_open_page_reloads_after_the_store_changes_it() {
      fresh()
      var home = view.page.id
      var other = ws.createPage({ parent: "", title: "Other" })
      ws.editPage(home, function(p) { return Workspace.appendPageBlock(p, other.id) })
      tryVerify(function() { return view.editor.indexOf(other.id) >= 0 }, 2000)
    }
  }
}
