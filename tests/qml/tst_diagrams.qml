import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Html.js" as Html
import "../../Diagram.js" as Diagram
import "../../Library.js" as Library

// Diagrams in Pages: "/decision tree" (and the others) puts in a code block
// in Mermaid with a small one to change; written, its source and the
// drawing under it as it's written; elsewhere, just the drawing; a mistake
// said, a diagram it doesn't draw said, and what's saved. Seen large (a
// diagram or an equation): zoomed (buttons, keys, Ctrl+scroll round the
// pointer), moved (scrolled, dragged), closed with Esc. Colors of their
// own (classDef, :::, style, linkStyle), drawn. Made a picture: copied,
// saved where you say.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  property string lastToast: ""

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToast: function(text) { root.lastToast = text }
  }

  TestCase {
    name: "Diagrams"
    when: windowShown

    function fresh() {
      if (view.editor.drawingViewer && view.editor.drawingViewer.opened) view.editor.drawingViewer.close()
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === " ") keyClick(Qt.Key_Space)
        else keyClick(ch)
      }
    }
    function all(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) all(item.children[i], test, out)
      return out
    }
    function named(item, name) { return all(item, function(it) { return it.objectName === name }, [])[0] || null }
    function win() { return root.Window.window.contentItem }
    function newLine() {
      var e = view.editor
      e.insertBlocksAt(e.model.count, [{ type: "p", html: "", indent: 0 }])
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      return e.uidAt(e.model.count - 1)
    }
    function textOf(uid) { var e = view.editor; e.syncAll(); return Html.plainText(e.blockAt(e.indexOf(uid)).html) }
    function labels(item) { return all(item, function(it) { return it.objectName === "diagramNode" }, []).map(function(n) { return n.label }).sort().join("|") }

    function test_1_from_the_menu() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("/decision")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "decision")
      keyClick(Qt.Key_Return)
      tryCompare(e.blockAt(e.indexOf(uid)), "lang", "Mermaid")
      compare(e.blockAt(e.indexOf(uid)).type, "code")
      compare(textOf(uid), Diagram.STARTERS.decision, "a small one to change")
      var item = e.items[uid]
      verify(item.diagramCode && item.edit.activeFocus, "its source, being written")
      // The drawing under it as it's written.
      tryVerify(function() { return item.diagram && item.diagram.drawable }, 2000)
      compare(all(item, function(it) { return it.objectName === "diagramNode" }, []).length, 7, "every box")
      verify(labels(item).indexOf("Is the server reachable?") >= 0)
      // Elsewhere: just the drawing, the source away.
      newLine()
      tryVerify(function() { return item.drawnView }, 1000)
      verify(!item.edit.visible)
      verify(named(item, "diagramView").height > 100, "drawn: " + named(item, "diagramView").height)
      // Written to: drawn again.
      wait(100)
      mouseClick(named(item, "diagramView"))
      tryVerify(function() { return item.edit.activeFocus && !item.drawnView }, 1000)
      e.focusBlock(uid, item.edit.length)
      keyClick(Qt.Key_Return)
      type("a4 --> extra[Call the team]")
      tryVerify(function() { return labels(item).indexOf("Call the team") >= 0 }, 2000, "the new box")
      // A mistake: said under it.
      keyClick(Qt.Key_Return)
      type("extra -> a1")
      tryVerify(function() { return item.drawnProblem.indexOf("isn't understood") >= 0 }, 2000, item.drawnProblem)
      verify(named(item, "drawnProblem") !== null)
      // Saved: Mermaid, as written.
      view.commit()
      var saved = ws.readPageNow(view.page.id).blocks[uid]
      compare(saved.lang, "Mermaid")
      verify(Html.plainText(saved.html).indexOf("a4 --> extra[Call the team]") >= 0)
    }

    function test_2_each_one_draws() {
      fresh()
      var e = view.editor
      ;["diagram", "network", "system"].forEach(function(id) {
        var uid = newLine()
        type("/" + id)
        tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 && e.slashItems[0].id === id }, 1000, id)
        keyClick(Qt.Key_Return)
        var item = e.items[uid]
        tryVerify(function() { return item.diagram && item.diagram.drawable && item.drawnProblem === "" }, 2000, id + " draws")
      })
    }

    function test_3_one_it_doesnt_draw() {
      fresh()
      var e = view.editor
      var uid = newLine()
      e.convert(uid, "code", false)
      e.setProp(uid, "lang", "Mermaid")
      e.focusBlock(uid, 0)
      type("sequenceDiagram")
      newLine()
      var item = e.items[uid]
      tryVerify(function() { return item.drawnView }, 1000)
      verify(item.drawnProblem.indexOf("sequenceDiagram") >= 0, item.drawnProblem)
      verify(named(item, "drawnProblem") !== null, "said in its place")
      verify(item.height > 30)
    }

    // A diagram wider than the page: drawn smaller, saying so; large, to zoom in on.
    function test_4_seen_large_and_zoomed() {
      fresh()
      var e = view.editor
      var uid = newLine()
      e.convert(uid, "code", false)
      e.setProp(uid, "lang", "Mermaid")
      var src = "flowchart LR\n  a[First step of a long process] --> b[Second step of a long process] --> c[Third step of a long process] --> d[Fourth step of a long process] --> f[Fifth step of a long process]"
      e.setHtml(uid, Html.fromPlainText(src))
      newLine()
      var item = e.items[uid]
      tryVerify(function() { return item.drawnView && item.diagram && item.diagram.drawable }, 2000)
      verify(item.diagram.shrunk, "wider than the page: drawn smaller")
      var button = named(item, "openLarge")
      verify(button !== null, "the button shows when it's drawn smaller")
      verify(all(button, function(it) { return it.text === Math.round(item.diagram.fit * 100) + "%" }, []).length === 1, "saying how much smaller")
      wait(100)
      var blocks = e.model.count
      verify(view.flick.contentHeight > view.flick.height + 360, "a page that could scroll")
      mouseClick(button)
      var v = e.drawingViewer
      tryVerify(function() { return v.opened }, 1000, "large")
      compare(v.kind, "diagram")
      compare(v.source, src)
      // All of it at first: larger than on the page.
      tryVerify(function() { return v.fitted && v.zoom > item.diagram.fit }, 1000, "zoom " + v.zoom + " vs " + item.diagram.fit)
      var shown = named(win(), "viewerDiagram")
      compare(shown.zoom, v.zoom, "drawn at that size (not stretched)")
      // The buttons and the keys (the hint at the bottom out of the way
      // once it's used).
      var z = v.zoom
      verify(!v.touched)
      wait(100)
      mouseClick(named(win(), "viewerZoomIn"))
      tryVerify(function() { return Math.abs(v.zoom - Math.min(v.maxZoom, z * 1.25)) < 1e-6 }, 1000, "bigger: " + z + " -> " + v.zoom)
      verify(v.touched)
      mouseClick(named(win(), "viewerZoomOut"))
      verify(Math.abs(v.zoom - z) < 1e-6)
      var before = Html.plainText(view.editor.blockAt(view.editor.indexOf(uid)).html)
      keyClick(Qt.Key_1)
      compare(v.zoom, 1, "as big as it is")
      keyClick(Qt.Key_Plus)
      compare(v.zoom, 1.25)
      keyClick(Qt.Key_0)
      verify(Math.abs(v.zoom - z) < 1e-6, "all of it again")
      // Ctrl+scroll: zoomed round the pointer, what's under it staying there
      // (once it's wider than the window; till then it stays in the middle).
      keyClick(Qt.Key_1)
      keyClick(Qt.Key_Plus)
      keyClick(Qt.Key_Plus)
      var area = named(win(), "drawingViewerArea")
      var surface = named(win(), "drawingViewerSurface")
      verify(v.drawnW > area.width, "wider than the window: " + v.drawnW)
      var px = surface.width * 0.3
      var py = surface.height * 0.5
      var z0 = v.zoom
      var pageY = view.flick.contentY
      var at0 = (area.contentX + px - v.offsetX(v.zoom)) / v.zoom
      mouseWheel(surface, px, py, 0, 120, Qt.NoButton, Qt.ControlModifier)
      tryVerify(function() { return v.zoom > z0 * 1.1 }, 1000, "Ctrl+scroll zooms: " + v.zoom)
      var at1 = (area.contentX + px - v.offsetX(v.zoom)) / v.zoom
      verify(Math.abs(at1 - at0) < 2, "the same point under the pointer: " + at0 + " / " + at1)
      // Scrolled and dragged: it moves.
      var cx = area.contentX
      mouseWheel(surface, px, py, -240, 0)
      tryVerify(function() { return area.contentX > cx }, 1000, "scrolled sideways")
      cx = area.contentX
      mouseWheel(surface, px, py, 0, -120, Qt.NoButton, Qt.ShiftModifier)
      tryVerify(function() { return area.contentX > cx }, 1000, "Shift+scroll: sideways")
      cx = area.contentX
      mouseDrag(surface, px, py, 120, 0)
      tryVerify(function() { return area.contentX < cx }, 1000, "dragged")
      // A scroll it doesn't use doesn't scroll the page under it.
      mouseWheel(surface, px, py, 0, -360, Qt.NoButton, Qt.AltModifier)
      wait(100)
      compare(view.flick.contentY, pageY, "the page under it stays put")
      // The keys and clicks were the viewer's, not the page's (its buttons
      // are over the page's own).
      view.editor.syncAll()
      compare(Html.plainText(view.editor.blockAt(view.editor.indexOf(uid)).html), before, "nothing typed on the page under it")
      compare(e.model.count, blocks, "nothing on the page clicked through it")
      // Esc closes it.
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !v.opened }, 1000)
    }

    function test_6_its_own_colors() {
      fresh()
      var e = view.editor
      var uid = newLine()
      e.convert(uid, "code", false)
      e.setProp(uid, "lang", "Mermaid")
      e.setHtml(uid, Html.fromPlainText([
        "flowchart LR",
        "  subgraph G [Group]",
        "    b[Plain]",
        "  end",
        "  a[Warm]:::warm --> b",
        "  classDef warm fill:#ffedd5,stroke:#ea580c,color:#7c2d12,font-weight:bold",
        "  style G fill:#f0fdf4",
        "  linkStyle 0 stroke:#dc2626,stroke-width:3px"
      ].join("\n")))
      newLine()
      var item = e.items[uid]
      tryVerify(function() { return item.drawnView && item.diagram && item.diagram.drawable }, 2000)
      compare(item.drawnProblem, "")
      var nodes = all(item, function(it) { return it.objectName === "diagramNode" }, [])
      var warm = nodes.filter(function(n) { return n.label === "Warm" })[0]
      var plain = nodes.filter(function(n) { return n.label === "Plain" })[0]
      verify(Qt.colorEqual(warm.fillColor, "#ffedd5"), "its fill: " + warm.fillColor)
      verify(Qt.colorEqual(warm.strokeColor, "#ea580c"), "its outline: " + warm.strokeColor)
      verify(Qt.colorEqual(warm.textColor, "#7c2d12"), "its words: " + warm.textColor)
      verify(all(warm, function(it) { return it.text === "Warm" && it.font.weight === Font.Bold }, []).length === 1, "bold")
      verify(Qt.colorEqual(plain.fillColor, item.diagram.fill), "one with none: the page's")
      var edge = all(item, function(it) { return it.objectName === "diagramEdge" }, [])[0]
      verify(Qt.colorEqual(edge.lineColor, "#dc2626"), "the line: " + edge.lineColor)
      compare(edge.lineWidth, 3)
      var group = all(item, function(it) { return it.objectName === "diagramGroup" }, [])[0]
      verify(Qt.colorEqual(group.fillColor, "#f0fdf4"), "the group: " + group.fillColor)
      // CSS's color names are Qt's, every one the same color (but
      // rebeccapurple, newer than the names Qt knows: it's given as hex).
      Object.keys(Diagram.NAMED).forEach(function(name) { if (name !== "rebeccapurple") verify(Qt.colorEqual(name, Diagram.NAMED[name]), name) })
    }

    // A diagram or an equation as a picture: copied (a PNG, twice its size,
    // its margin round it), saved where you say (named for its page), from
    // under the pointer and in the view over everything (Ctrl+C, its Save).
    function test_7_as_a_picture() {
      fresh()
      var e = view.editor
      var uid = newLine()
      e.convert(uid, "code", false)
      e.setProp(uid, "lang", "Mermaid")
      e.setHtml(uid, Html.fromPlainText("flowchart LR\n  a[Start] --> b[Done]"))
      newLine()
      var item = e.items[uid]
      tryVerify(function() { return item.drawnView && item.diagram && item.diagram.drawable }, 2000)
      files.copiedPicture = ""
      service.nextSave = ""
      // Under the pointer: Copy as a picture.
      var box = named(item, "drawnBlock")
      mouseMove(box, 40, 10)
      var copy = null
      tryVerify(function() { copy = named(item, "drawnTool_copy"); var save = named(item, "drawnTool_save"); return copy !== null && save !== null && save.x > copy.x }, 1000, "on hover")
      mouseClick(copy)
      tryVerify(function() { return files.copiedPicture !== "" }, 3000, "copied")
      verify(/^\/tmp\/uber-notebook-drawing-\d+\.png$/.test(files.copiedPicture), files.copiedPicture)
      compare(root.lastToast, "Copied as a picture: paste it anywhere")
      // A picture made: the diagram at twice its size, with its margin.
      var lay = item.diagram.lay
      var img = Qt.createQmlObject("import QtQuick; Image {}", root)
      img.source = files.lastGrab.url
      tryCompare(img, "status", Image.Ready)
      compare(img.implicitWidth, Math.ceil((lay.w + 48) * 2))
      compare(img.implicitHeight, Math.ceil((lay.h + 48) * 2))
      img.destroy()
      // Save as a picture: named for its page, where you say.
      service.nextSave = "/tmp/out/flow.png"
      mouseMove(box, 40, 10)
      var save = null
      tryVerify(function() { save = named(item, "drawnTool_save"); return save !== null && save.x > 0 }, 1000)
      mouseClick(save)
      compare(service.saveName, Library.saveName(view.page.title + " diagram", "x.png"))
      tryVerify(function() { return files.disk["/tmp/out/flow.png"] === "PNG" }, 3000, "saved")
      compare(root.lastToast, "Saved to ~/out/flow.png")
      // In the view over everything: the same, said there (it hides the toasts).
      mouseMove(box, 40, 10)
      var large = null
      tryVerify(function() { large = named(item, "openLarge"); return large !== null }, 1000)
      mouseClick(large)
      var v = e.drawingViewer
      tryVerify(function() { return v.opened }, 1000)
      files.copiedPicture = ""
      keyClick(Qt.Key_C, Qt.ControlModifier)
      tryVerify(function() { return files.copiedPicture !== "" }, 3000, "Ctrl+C")
      tryVerify(function() { var said = named(win(), "viewerSaid"); return said !== null && said.text === "Copied as a picture: paste it anywhere" }, 1000, "said in the view")
      service.nextSave = "/tmp/out/flow2.png"
      mouseClick(named(win(), "viewerSave"))
      tryVerify(function() { return files.disk["/tmp/out/flow2.png"] === "PNG" }, 3000, "saved from the view")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !v.opened }, 1000)
      // An equation: the same.
      var m = newLine()
      e.convert(m, "code", false)
      e.setProp(m, "lang", "Math")
      e.setHtml(m, Html.fromPlainText("E = mc^2"))
      newLine()
      var mi = e.items[m]
      tryVerify(function() { return mi.drawnView && mi.mathSized !== null }, 8000, "drawn")
      service.nextSave = "/tmp/out/energy.png"
      var mbox = named(mi, "drawnBlock")
      mouseMove(mbox, 40, 10)
      var msave = null
      tryVerify(function() { msave = named(mi, "drawnTool_save"); return msave !== null && msave.x > 0 }, 1000)
      mouseClick(msave)
      compare(service.saveName, Library.saveName(view.page.title + " equation", "x.png"))
      tryVerify(function() { return files.disk["/tmp/out/energy.png"] === "PNG" }, 3000, "an equation saved")
    }

    // A picture asked for as soon as the one before is made (a Save right
    // after a Copy): made too, not refused as busy.
    function test_8_one_picture_after_another() {
      fresh()
      var e = view.editor
      var source = "flowchart LR\n  a[Start] --> b[Done]"
      var first = null
      var second = null
      e.drawingImage("diagram", source, null, function(r1) {
        first = r1
        e.drawingImage("diagram", source, null, function(r2) { second = r2 })
      })
      tryVerify(function() { return first !== null }, 3000, "the first")
      tryVerify(function() { return second !== null }, 3000, "and the one asked for as it was made")
    }

    function test_5_an_equation_large() {
      fresh()
      var e = view.editor
      var uid = newLine()
      e.convert(uid, "code", false)
      e.setProp(uid, "lang", "Math")
      e.setHtml(uid, Html.fromPlainText("\\int_0^1 x^2 \\, dx = \\frac{1}{3}"))
      newLine()
      var item = e.items[uid]
      tryVerify(function() { return item.drawnView && item.mathSized !== null }, 8000, "drawn")
      var box = named(item, "drawnBlock")
      mouseMove(box, 40, 10)
      wait(50)
      var button = null
      tryVerify(function() { button = named(item, "openLarge"); return button !== null }, 1000, "on hover")
      wait(100)
      mouseClick(button)
      var v = e.drawingViewer
      tryVerify(function() { return v.opened && v.kind === "math" }, 1000)
      tryVerify(function() { var m = named(win(), "viewerMath"); return m !== null && m.width > 100 }, 2000, "the equation, large")
      var w = named(win(), "viewerMath").width
      keyClick(Qt.Key_Plus)
      tryVerify(function() { return named(win(), "viewerMath").width > w * 1.2 }, 1000, "drawn again bigger")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !v.opened }, 1000)
    }
  }
}
