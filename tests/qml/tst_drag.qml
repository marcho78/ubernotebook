import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace

// Pages dragged in the sidebar: before, after or inside another page, to the
// end of the top; never into a page inside it; the page open shown as it is
// then; Undo puts it back.
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
    name: "Dragging pages"
    when: windowShown

    property var ids: ({})

    function fresh() {
      files.reset()
      view.page = null
      view.tagShown = ""
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      ws.ensureStarted()
      // A (with A1 and A2), B, C at the top.
      var a = ws.createPage({ parent: "", title: "A" })
      var b = ws.createPage({ parent: "", title: "B" })
      var c = ws.createPage({ parent: "", title: "C" })
      var a1 = ws.createPage({ parent: a.id, title: "A1" })
      var a2 = ws.createPage({ parent: a.id, title: "A2" })
      ws.editPage(a.id, function(p) { Workspace.appendPageBlock(p, a1.id); Workspace.appendPageBlock(p, a2.id); return true })
      ids = { a: a.id, b: b.id, c: c.id, a1: a1.id, a2: a2.id }
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      view.expandTo(a1.id)
      root.lastUndo = null
      wait(50)
    }
    function find(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) find(item.children[i], test, out)
      return out
    }
    function row(title) {
      var r = null
      tryVerify(function() { r = find(root, function(it) { return it.objectName === "pageRow" && it.modelData && it.modelData.title === title }, [])[0] || null; return r !== null }, 1000, title + " in the sidebar")
      return r
    }
    // Drags a row to a point on another (frac: how far down it, 0 to 1).
    function drag(from, to, frac) {
      var src = row(from)
      var p0 = src.mapToItem(root, 60, src.height / 2)
      var dst = to ? row(to) : null
      var p1 = dst ? dst.mapToItem(root, 80, dst.height * frac) : Qt.point(p0.x, p0.y + frac)
      mousePress(root, p0.x, p0.y)
      for (var i = 1; i <= 10; i++) mouseMove(root, p0.x + (p1.x - p0.x) * i / 10, p0.y + (p1.y - p0.y) * i / 10)
      wait(30)
      mouseRelease(root, p1.x, p1.y)
      wait(50)
    }
    function kids(id) { return ws.index.pages[id].children.map(function(c) { return ws.index.pages[c].title }) }
    function topTitles() { return ws.index.top.map(function(c) { return ws.index.pages[c].title }) }
    function onPage(id) { return Workspace.childPages(ws.readPageNow(id)).map(function(c) { return ws.index.pages[c].title }) }

    function test_1_before_after_inside() {
      fresh()
      drag("C", "A1", 0.1)
      tryVerify(function() { return kids(ids.a).join() === "C,A1,A2" }, 2000, "in front of A1, inside A")
      compare(onPage(ids.a).join(), "C,A1,A2", "its block on A, in that place")
      compare(ws.readPageNow(ids.c).parent, ids.a, "and it knows where it is")
      verify(topTitles().indexOf("C") < 0)
      verify(root.lastToast.indexOf("into \u201cA\u201d") >= 0, root.lastToast)
      // After.
      drag("A1", "A2", 0.9)
      tryVerify(function() { return kids(ids.a).join() === "C,A2,A1" }, 2000, "after A2")
      compare(onPage(ids.a).join(), "C,A2,A1")
      // Inside.
      drag("B", "A2", 0.5)
      tryVerify(function() { return kids(ids.a2).join() === "B" }, 2000, "inside A2")
      compare(onPage(ids.a2).join(), "B")
      // Undo: back where it was.
      verify(root.lastUndo !== null)
      root.lastUndo()
      tryVerify(function() { return topTitles().join() === "Getting started,A,B" }, 2000, "B back at the top, where it was: " + topTitles().join())
      compare(kids(ids.a2).join(), "")
      compare(onPage(ids.a2).join(), "", "and off A2's page")
    }

    function test_2_never_into_itself_and_to_the_end() {
      fresh()
      var before = JSON.stringify(ws.index.top) + JSON.stringify(ws.index.pages[ids.a].children)
      drag("A", "A1", 0.5)
      wait(200)
      compare(JSON.stringify(ws.index.top) + JSON.stringify(ws.index.pages[ids.a].children), before, "not into a page inside it")
      // Below every page: the end of the top.
      var last = row("C")
      drag("A1", "C", 0.5)
      tryVerify(function() { return ws.index.pages[ids.a1].parent === ids.c }, 2000)
      root.lastUndo()
      tryVerify(function() { return ws.index.pages[ids.a1].parent === ids.a }, 2000)
      compare(kids(ids.a).join(), "A1,A2", "back in its place")
      // Below every page: the end of the top of Pages.
      var src = row("A2")
      var c = row("C")
      var p0 = src.mapToItem(root, 60, src.height / 2)
      var p1 = c.mapToItem(root, 60, c.height + 40)
      mousePress(root, p0.x, p0.y)
      for (var i = 1; i <= 10; i++) mouseMove(root, p0.x + (p1.x - p0.x) * i / 10, p0.y + (p1.y - p0.y) * i / 10)
      wait(30)
      mouseRelease(root, p1.x, p1.y)
      tryVerify(function() { return topTitles().join() === "Getting started,A,B,C,A2" }, 2000, "at the end: " + topTitles().join())
    }

    function test_3_the_page_open_shows_it() {
      fresh()
      view.open(ids.a)
      tryVerify(function() { return view.page && view.page.id === ids.a }, 2000)
      function pagesOnIt() { return view.editor.serialize().filter(function(b) { return b.type === "page" }).map(function(b) { return ws.index.pages[b.uid].title }) }
      compare(pagesOnIt().join(), "A1,A2")
      drag("C", "A2", 0.1)
      tryVerify(function() { return pagesOnIt().join() === "A1,C,A2" }, 2000, "the open page has it, in its place")
      // Still the open page, and what's written to it is kept.
      view.commit()
      compare(onPage(ids.a).join(), "A1,C,A2")
    }
  }
}
