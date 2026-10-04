import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace

// A notebook moved to Pages (Move to Pages… in its menu on the shelf): a
// page called what it is, with a page inside it for each of its pages, in
// order, their text as it was, their pictures copied into Pages, what's
// drawn on them a sketch at their end; the notebook in the trash, and Pages
// open at the page. A picture that can't be copied: the pages are made
// without it, and the notebook stays on the shelf. And Pages is where
// Uber Notebook opens, and where quick notes go, unless you say.
Item {
  id: root
  width: 1320
  height: 900

  FakeStore { id: store }
  FakeService { id: service; store: store; user: ({ sounds: false, space: "notebooks" }) }
  FakeService { id: firstService; store: store; user: ({ sounds: false }) }
  FakeFiles { id: files }
  UberNotebook.Workspace { id: ws; files: files }

  App {
    id: app
    anchors.fill: parent
    store: store
    workspace: ws
    service: service
  }

  Component { id: anotherApp; App { anchors.fill: parent } }

  TestCase {
    name: "MoveToPages"
    when: windowShown

    function find(item, test) {
      if (!item) return null
      if (item.visible && test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    // What the toast says (shown or fading).
    function said(text) {
      function look(item) {
        if (!item) return false
        if (item.text === text && String(item).indexOf("QQuickText") === 0) return true
        for (var i = 0; i < item.children.length; i++) if (look(item.children[i])) return true
        return false
      }
      return look(app)
    }
    function fresh() {
      store.reset()
      files.reset()
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      app.showSpace("notebooks")
      wait(50)
    }
    function children(id) { return ws.index.pages[id].children.slice() }
    function blocksOf(id) { return Workspace.flatten(ws.readPageNow(id)) }
    // Its menu on the shelf (a right click on it), and Move to Pages…, asked.
    function moveFromMenu(nb) {
      var tile = null
      tryVerify(function() { tile = find(app, function(it) { return it.modelData !== undefined && it.modelData !== null && it.modelData.id === nb.id && it.width > 100 }); return tile !== null && (tile.x > 0 || tile.y > 0) }, 2000, "on the shelf, in its place")
      mouseClick(tile, tile.width / 2, 60, Qt.RightButton)
      var row = null
      tryVerify(function() { row = named(win(), "shelfMoveToPages"); return row !== null && row.width > 0 }, 1000, "in its menu")
      wait(150)
      mouseClick(row)
      tryVerify(function() { return find(win(), function(it) { return it.text === "Move “" + nb.title + "” to Pages?" }) !== null }, 1000, "asked first")
      keyClick(Qt.Key_Return)
    }

    function test_1_moved() {
      fresh()
      var nb = store.add({ title: "Lisbon trip" }, [
        { title: "Day one", blocks: [
          { type: "h2", html: "Morning" },
          { type: "check", html: "Pastéis de nata", checked: true },
          { type: "bullet", html: "Tram 28" },
          { type: "bullet", html: "Alfama", indent: 1 },
          { type: "image", src: "assets/tram.png", width: 0.5, align: "left" },
          { type: "callout", tone: "blue", html: "Bring the adapter" }
        ], ink: [{ tool: "pen", color: "#1e4fa3", width: 2.2, points: [100, 300, 200, 320, 260, 330] }, { tool: "marker", color: "#fff27a", width: 13.2, points: [80, 340, 300, 340] }] },
        { title: "", blocks: [{ type: "time", label: "9:00", html: "Flight home" }, { type: "image", src: "assets/tram.png", width: 0.6 }] }
      ])
      store.refresh()
      files.disk[store.rootPath + "/" + nb.id + "/assets/tram.png"] = "PNG"
      var before = Object.keys(ws.index.pages).length
      var others = store.notebooks.length

      moveFromMenu(nb)

      // Pages, open at the page it is now.
      tryCompare(app, "space", "pages", 2000)
      compare(service.settings.space, "pages", "and it opens there next time")
      var top = null
      tryVerify(function() { top = Object.keys(ws.index.pages).filter(function(id) { return ws.index.pages[id].title === "Lisbon trip" })[0]; return !!top }, 2000, "a page called what it was")
      compare(ws.index.pages[top].icon, "\u{1f4d3}")
      compare(ws.index.pages[top].parent, "", "at the top")
      tryVerify(function() { return app.docView.page && app.docView.page.id === top }, 2000, "open")
      verify(said("“Lisbon trip” is in Pages now"))
      compare(Object.keys(ws.index.pages).length, before + 3)
      // A page inside it for each of its pages, in order.
      var kids = children(top)
      compare(kids.length, 2)
      compare(ws.index.pages[kids[0]].title, "Day one")
      compare(ws.index.pages[kids[1]].title, "Flight home", "named as the notebook named it: its first line")
      compare(blocksOf(top).map(function(b) { return b.type + ":" + b.uid }), kids.map(function(id) { return "page:" + id }))
      // Their text as it was; the picture copied in; the drawing at the end.
      var one = blocksOf(kids[0])
      compare(one.map(function(b) { return b.type + ":" + b.indent }).join(" "), "h2:0 check:0 bullet:0 bullet:1 image:0 callout:0 sketch:0")
      compare(one[1].checked, true)
      compare(one[1].html, "Pastéis de nata")
      compare(one[5].color, "blue_background")
      verify(/^assets\/.+\.png$/.test(one[4].src), one[4].src)
      compare(files.disk[ws.folder + "/" + one[4].src], "PNG", "copied into Pages")
      compare(one[4].width, 0.5)
      compare(one[4].align, "left")
      var sk = one[6].sketch
      compare(sk.strokes.length, 2)
      compare(sk.strokes[0].color, "blue")
      compare(sk.strokes[1].tool, "marker")
      compare(sk.strokes[1].color, "yellow")
      var two = blocksOf(kids[1])
      compare(two[0].type, "p")
      verify(/^<span style="\s*font-weight:700;">9:00<\/span> Flight home$/.test(two[0].html), two[0].html)
      compare(two[1].src, one[4].src, "the same picture once")
      // When they were written.
      compare(ws.readPageNow(kids[0]).created, nb.pages[0].created)
      // The notebook: in the trash (off the shelf).
      compare(store.notebooks.length, others - 1)
      verify(store.data[nb.id] === undefined)
      // The other notebooks as they were.
      verify(store.notebooks.some(function(n) { return n.title === "Recipes" }))
    }

    function test_2_a_picture_that_cant_be_copied() {
      fresh()
      var nb = store.add({ title: "Sketchbook" }, [
        { title: "Birds", blocks: [{ type: "p", html: "A heron" }, { type: "image", src: "assets/heron.png", width: 0.6 }, { type: "image", src: "assets/gone.png", width: 0.6 }] }
      ])
      store.refresh()
      files.disk[store.rootPath + "/" + nb.id + "/assets/heron.png"] = "PNG"
      var others = store.notebooks.length

      moveFromMenu(nb)

      tryCompare(app, "space", "pages", 2000)
      var top = null
      tryVerify(function() { top = Object.keys(ws.index.pages).filter(function(id) { return ws.index.pages[id].title === "Sketchbook" })[0]; return !!top }, 2000)
      var kid = children(top)[0]
      compare(blocksOf(kid).map(function(b) { return b.type }).join(" "), "p image", "the picture that's there")
      verify(said("“Sketchbook” is in Pages now, but a picture couldn't be copied: the notebook stays on the shelf"))
      compare(store.notebooks.length, others, "still on the shelf")
      verify(store.data[nb.id] !== undefined)
    }

    function test_2b_not_all_saved_or_too_long() {
      fresh()
      // A page of it couldn't be written: in Pages as far as it went, and
      // the notebook stays on the shelf.
      var nb = store.add({ title: "Garden" }, [{ title: "Beds", blocks: [{ type: "p", html: "Tomatoes" }] }, { title: "Seeds", blocks: [{ type: "p", html: "Basil" }] }])
      store.refresh()
      var others = store.notebooks.length
      files.failWrites = "/Pages/index.json"
      moveFromMenu(nb)
      tryVerify(function() { return said("\u201cGarden\u201d is in Pages, but not all of it could be saved: the notebook stays on the shelf") }, 2000)
      compare(store.notebooks.length, others, "still on the shelf")
      files.failWrites = ""
      // A page longer than a page in Pages can be (its drawing too): nothing
      // moved, and it says which.
      fresh()
      var blocks = []
      for (var i = 0; i < 5000; i++) blocks.push({ type: "p", html: "line " + i })
      var long = store.add({ title: "Diary" }, [{ title: "Everything", blocks: blocks, ink: [{ tool: "pen", color: "#1f2430", width: 2, points: [10, 10, 50, 50] }] }])
      store.refresh()
      others = store.notebooks.length
      var pages = Object.keys(ws.index.pages).length
      moveFromMenu(long)
      tryVerify(function() { return said("\u201cEverything\u201d in \u201cDiary\u201d is longer than a page in Pages can be: nothing was moved") }, 3000)
      compare(Object.keys(ws.index.pages).length, pages, "no page made")
      compare(store.notebooks.length, others)
      compare(app.space, "notebooks")
    }

    function test_3_asked_first() {
      fresh()
      var nb = store.notebooks[0]
      var pages = Object.keys(ws.index.pages).length
      var tile = null
      tryVerify(function() { tile = find(app, function(it) { return it.modelData !== undefined && it.modelData !== null && it.modelData.id === nb.id && it.width > 100 }); return tile !== null }, 2000)
      mouseClick(tile, tile.width / 2, 60, Qt.RightButton)
      var row = null
      tryVerify(function() { row = named(win(), "shelfMoveToPages"); return row !== null && row.width > 0 }, 1000)
      wait(150)
      mouseClick(row)
      tryVerify(function() { return find(win(), function(it) { return it.text === "Move to Pages" }) !== null }, 1000)
      // Esc: nothing moved.
      keyClick(Qt.Key_Escape)
      wait(300)
      compare(app.space, "notebooks")
      compare(Object.keys(ws.index.pages).length, pages)
      verify(store.data[nb.id] !== undefined)
    }

    function test_4_pages_first() {
      // Nothing said: Pages, and quick notes into the Pages Inbox.
      compare(firstService.settings.space, "pages")
      compare(firstService.settings.quickTo, "pages")
      var other = createTemporaryObject(anotherApp, root, { store: store, workspace: ws, service: firstService })
      verify(other !== null)
      compare(other.space, "pages")
      other.visible = false
      // Where you were last: the notebooks.
      compare(app.space, "notebooks")
    }
  }
}
