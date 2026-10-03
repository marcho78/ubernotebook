import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Sketch.js" as Sketch
import "../../Html.js" as Html

// Sketches in Pages: "/sketch", drawing with the mouse (pen, highlighter,
// eraser), its colors, nibs and background, making it taller, every stroke a
// step to undo, drawing starting and stopping, and the page saved and exported.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  TestCase {
    name: "Sketches"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      var e = view.editor
      e.readOnly = false
      e.sketchTool = "pen"
      e.sketchColor = ""
      e.sketchMarker = "yellow"
      e.sketchNib = Sketch.NIBS[1]
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i))
    }
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
    function findText(text) { return find(win(), function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }) }
    function tip(item, t) { return find(item, function(it) { return it.tip === t }) }
    // The sketch on the page (its block, and its SketchBlock).
    function sketchAt(i) { return view.editor.serialize()[i].sketch }
    function put() {
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "sketch", sketch: { height: 400, background: "dots", strokes: [] }, indent: 0 }])
      var uid = e.uidAt(0)
      tryVerify(function() { return e.items[uid] && e.items[uid].sketchView }, 1000)
      return e.items[uid].sketchView
    }
    // Drawing on it, its tools laid out under it.
    function drawOn(sv) {
      sv.startDrawing()
      tryVerify(function() { return named(sv, "sketchBar") !== null }, 1000)
      waitForRendering(sv)
      wait(50)
    }
    // A stroke across the sheet, from (x0, y0) to (x1, y1) in its pixels.
    function draw(sv, x0, y0, x1, y1) {
      var frame = sv.children[1]
      mousePress(sv, x0, y0)
      for (var i = 1; i <= 8; i++) mouseMove(sv, x0 + (x1 - x0) * i / 8, y0 + (y1 - y0) * i / 8)
      mouseRelease(sv, x1, y1)
    }

    function test_1_slash_sketch_and_drawing() {
      fresh()
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      type("/sketch")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "sketch")
      keyClick(Qt.Key_Return)
      var at = e.serialize().map(function(b) { return b.type }).indexOf("sketch")
      verify(at >= 0, "a sketch on the page")
      var uid = e.uidAt(at)
      var sv = e.items[uid].sketchView
      tryVerify(function() { return sv.drawing }, 1000, "drawing on it at once")
      verify(named(sv, "sketchBar") !== null, "its tools under it")
      compare(sketchAt(at).strokes.length, 0)
      draw(sv, 60, 60, 300, 140)
      tryVerify(function() { return sketchAt(at).strokes.length === 1 }, 1000, "a stroke")
      var s = sketchAt(at).strokes[0]
      compare(s.tool, "pen")
      compare(s.color, "", "in the page's ink")
      compare(s.width, Sketch.NIBS[1])
      verify(s.points.length >= 6, "through the points it went")
      var u = sv.unit
      verify(Math.abs(s.points[0] - 60 / u) < 2 && Math.abs(s.points[1] - 60 / u) < 2, "in the sketch's own units: " + s.points.slice(0, 2))
      // Another, then Undo takes one off at a time; drawing goes on.
      draw(sv, 400, 30, 600, 50)
      tryVerify(function() { return sketchAt(at).strokes.length === 2 }, 1000)
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      compare(sketchAt(at).strokes.length, 1, "Ctrl+Z: the last stroke")
      tryVerify(function() { return sv.drawing }, 1000, "still drawing")
      keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
      compare(sketchAt(at).strokes.length, 2, "and back")
      // Saved with the page.
      view.commit()
      var file = files.parseJson(files.disk[Workspace.pageFile(files.rootPath, view.page.id)])
      compare(file.blocks[uid].type, "sketch")
      compare(file.blocks[uid].sketch.strokes.length, 2)
      // Esc stops, and picks the sketch; a click draws again.
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !sv.drawing }, 1000)
      verify(e.selectedMap[uid] === true, "Esc picks it")
      verify(named(sv, "sketchBar") === null, "its tools go")
      mouseClick(sv, 400, 100)
      tryVerify(function() { return sv.drawing }, 1000, "a click draws again")
      compare(sketchAt(at).strokes.length, 2, "the click itself draws nothing")
      // A click on the page's writing stops it.
      e.focusBlock(e.uidAt(at + 1), 0)
      tryVerify(function() { return !sv.drawing }, 1000, "writing elsewhere stops drawing")
    }

    function test_2_highlighter_eraser_nibs() {
      fresh()
      var e = view.editor
      var sv = put()
      drawOn(sv)
      draw(sv, 40, 80, 400, 80)
      tryVerify(function() { return sketchAt(0).strokes.length === 1 }, 1000)
      keyClick(Qt.Key_M)
      compare(e.sketchTool, "marker", "M: the highlighter")
      mouseClick(tip(sv, "Highlighter  M"))
      draw(sv, 40, 200, 400, 200)
      tryVerify(function() { return sketchAt(0).strokes.length === 2 }, 1000)
      var m = sketchAt(0).strokes[1]
      compare(m.tool, "marker")
      compare(m.color, "yellow", "in yellow, to start with")
      compare(m.width, Sketch.NIBS[1] * Sketch.MARKER, "six times the nib")
      // The thickest nib.
      keyClick(Qt.Key_P)
      var nibs = find(sv, function(it) { return it.objectName === "sketchBar" })
      sv.setNib(Sketch.NIBS[2])
      draw(sv, 40, 260, 400, 260)
      tryVerify(function() { return sketchAt(0).strokes.length === 3 }, 1000)
      compare(sketchAt(0).strokes[2].width, Sketch.NIBS[2])
      // The eraser lifts the strokes it touches, as one step.
      keyClick(Qt.Key_E)
      compare(e.sketchTool, "eraser")
      mousePress(sv, 200, 60)
      mouseMove(sv, 200, 120)
      mouseMove(sv, 200, 210)
      mouseRelease(sv, 200, 210)
      tryVerify(function() { return sketchAt(0).strokes.length === 1 }, 1000, "the two strokes it crossed")
      compare(sketchAt(0).strokes[0].width, Sketch.NIBS[2], "not the one it didn't")
      e.undo()
      compare(sketchAt(0).strokes.length, 3, "one Undo puts both back")
    }

    // A tile in the color menu that's open.
    function tile(test) {
      var t = null
      tryVerify(function() { t = find(win(), test); return t !== null }, 1000, "the color is on screen")
      wait(250)
      return find(win(), test)
    }

    function test_3_colors_and_the_picker() {
      fresh()
      var e = view.editor
      var sv = put()
      drawOn(sv)
      mouseClick(named(sv, "sketchColor"))
      mouseClick(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === "red" && it.back === false }))
      compare(e.sketchColor, "red", "the pen in red")
      wait(200)
      verify(sv.drawing, "drawing goes on")
      draw(sv, 40, 80, 400, 80)
      tryVerify(function() { return sketchAt(0).strokes.length === 1 }, 1000)
      compare(sketchAt(0).strokes[0].color, "red")
      // A color of your own: Enter keeps it, and it's among your recent colors.
      mouseClick(named(sv, "sketchColor"))
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText("Text color of your own") !== null }, 1000, "the color picker")
      wait(200)
      var hex = "#2a6f97"
      for (var i = 0; i < hex.length; i++) keyClick(hex.charAt(i))
      tryCompare(e, "sketchColor", hex, 1000, "the pen takes it as you pick")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return findText("Text color of your own") === null }, 1000)
      wait(200)
      compare(e.sketchColor, hex)
      compare(service.settings.recentColors.split(",")[0], hex)
      verify(sv.drawing, "and drawing goes on")
      draw(sv, 40, 200, 400, 200)
      tryVerify(function() { return sketchAt(0).strokes.length === 2 }, 1000)
      compare(sketchAt(0).strokes[1].color, hex)
      // Cancel puts back the pen it had.
      mouseClick(named(sv, "sketchColor"))
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText("Text color of your own") !== null }, 1000)
      wait(200)
      for (var j = 0; j < "#00ff00".length; j++) keyClick("#00ff00".charAt(j))
      tryCompare(e, "sketchColor", "#00ff00", 1000)
      keyClick(Qt.Key_Escape)
      tryCompare(e, "sketchColor", hex, 1000, "put back")
      // Drawn in its colors: Pages' follow the theme.
      verify(String(sv.colorOf("red")) !== "", "a color")
    }

    function test_4_background_and_height() {
      fresh()
      var e = view.editor
      var sv = put()
      drawOn(sv)
      mouseClick(tip(sv, "Grid"))
      compare(sketchAt(0).background, "grid")
      mouseClick(tip(sv, "Plain paper"))
      compare(sketchAt(0).background, "plain")
      e.undo()
      compare(sketchAt(0).background, "grid", "each a step to undo")
      // The bottom edge, dragged down: taller, in one step.
      var edge = named(sv, "sketchEdge")
      var h0 = sv.canvasH
      mousePress(edge, edge.width / 2, 5)
      for (var i = 1; i <= 6; i++) mouseMove(edge, edge.width / 2, 5 + i * 20)
      mouseRelease(edge, edge.width / 2, 125)
      tryVerify(function() { return sketchAt(0).height > 400 }, 1000, "taller")
      verify(sv.canvasH > h0 + 100, sv.canvasH + " > " + h0)
      e.undo()
      compare(sketchAt(0).height, 400, "one step")
      // Cleared, as one step.
      draw(sv, 40, 80, 300, 80)
      tryVerify(function() { return sketchAt(0).strokes.length === 1 }, 1000)
      mouseClick(named(sv, "clearSketch"))
      compare(sketchAt(0).strokes.length, 0)
      e.undo()
      compare(sketchAt(0).strokes.length, 1)
    }

    function test_5_locked_safe_and_exported() {
      fresh()
      var e = view.editor
      var sv = put()
      drawOn(sv)
      draw(sv, 40, 80, 300, 120)
      tryVerify(function() { return sketchAt(0).strokes.length === 1 }, 1000)
      keyClick(Qt.Key_Escape)
      // Delete at the end of the line above picks it, never takes it.
      e.insertBlocksAt(0, [{ type: "p", html: "above", indent: 0 }])
      var uid = e.uidAt(1)
      e.focusBlock(e.uidAt(0), -1)
      keyClick(Qt.Key_Delete)
      compare(e.typeOf(uid), "sketch")
      verify(e.selectedMap[uid] === true)
      e.clearBlockSelection()
      // Turning it into a mind map with the line above: not done (it'd be lost).
      e.selectBlocks(e.uidAt(0), uid)
      compare(e.toMindMap(e.selectedList), "", "a drawing isn't an idea")
      compare(e.typeOf(uid), "sketch")
      e.clearBlockSelection()
      // Locked: only shown.
      e.readOnly = true
      mouseClick(sv, 400, 100)
      wait(100)
      verify(!sv.drawing, "a locked page's sketch isn't drawn on")
      e.readOnly = false
      // Exported: the page's Markdown points to its SVG, written beside it.
      view.commit()
      files.exportBase = null
      ws.exportPageTo(view.page.id, "/tmp/out")
      var svg = Object.keys(files.disk).filter(function(p) { return p.indexOf("/tmp/out/") === 0 && /\/sketches\/[0-9a-f-]+\.svg$/.test(p) })
      compare(svg.length, 1, "its SVG")
      verify(files.disk[svg[0]].indexOf("<path d=\"M ") >= 0, "with its stroke")
      var md = Object.keys(files.disk).filter(function(p) { return p.indexOf("/tmp/out/") === 0 && /\.md$/.test(p) && files.disk[p].indexOf("![Sketch](sketches/" + uid + ".svg)") >= 0 })
      compare(md.length, 1, "the page's Markdown shows it")
    }
  }
}
