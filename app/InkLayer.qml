import QtQuick
import QtQuick.Shapes
import "../Papers.js" as Papers

// Drawing on the page: strokes of a pen or a highlighter over the writing,
// and an eraser that lifts whole strokes. The strokes are in the page's own
// coordinates, so they scroll with it; they're kept with the page (its `ink`).
//
// Drawing is on while `drawing` is; the rest of the time the layer only shows
// the strokes and lets every click through to the text.
Item {
  id: ink

  // [{ tool: "pen" | "marker", color: "#rrggbb", width, points: [x, y, ...] }]
  property var strokes: []
  property bool drawing: false
  property string tool: "pen"
  property string color: "#1f2430"
  property real penWidth: 2.2
  property bool dark: false

  signal changed()

  readonly property var toDark: Papers.darkMap()
  property var undoStack: []
  property var redoStack: []
  readonly property bool canUndo: undoStack.length > 0
  readonly property bool canRedo: redoStack.length > 0

  function load(list) {
    strokes = Array.isArray(list) ? list : []
    undoStack = []
    redoStack = []
  }

  function remember() {
    var stack = undoStack.slice()
    stack.push(strokes)
    if (stack.length > 100) stack.shift()
    undoStack = stack
    redoStack = []
  }

  function undo() {
    if (!undoStack.length) return
    var stack = undoStack.slice()
    var prev = stack.pop()
    undoStack = stack
    redoStack = redoStack.concat([strokes])
    strokes = prev
    changed()
  }

  function redo() {
    if (!redoStack.length) return
    var stack = redoStack.slice()
    var next = stack.pop()
    redoStack = stack
    undoStack = undoStack.concat([strokes])
    strokes = next
    changed()
  }

  function clearAll() {
    if (!strokes.length) return
    remember()
    strokes = []
    changed()
  }

  // Colors are kept as their light-paper ink, and drawn as the dark twin on dark paper.
  function shown(color) {
    return dark ? (toDark[color] || color) : color
  }

  // A stroke's points as a smooth path: straight to the first midpoint, then
  // curves through each point to the next midpoint.
  function pathOf(points) {
    if (!points || points.length < 2) return ""
    var d = "M " + points[0] + " " + points[1]
    if (points.length === 2) return d + " L " + (points[0] + 0.01) + " " + points[1]
    for (var i = 2; i + 3 < points.length; i += 2) {
      var mx = (points[i] + points[i + 2]) / 2
      var my = (points[i + 1] + points[i + 3]) / 2
      d += " Q " + points[i] + " " + points[i + 1] + " " + mx + " " + my
    }
    var n = points.length
    d += " L " + points[n - 2] + " " + points[n - 1]
    return d
  }

  // ---- the strokes -----------------------------------------------------------------

  Repeater {
    model: ink.strokes
    delegate: Shape {
      required property var modelData
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: modelData.tool === "marker"
          ? Qt.alpha(ink.shown(modelData.color), ink.dark ? 0.42 : 0.38)
          : ink.shown(modelData.color)
        strokeWidth: modelData.width
        fillColor: "transparent"
        capStyle: modelData.tool === "marker" ? ShapePath.SquareCap : ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        PathSvg { path: ink.pathOf(modelData.points) }
      }
    }
  }

  // The stroke being drawn.
  Shape {
    id: live
    anchors.fill: parent
    visible: pen.points.length > 0
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeColor: ink.tool === "marker" ? Qt.alpha(ink.shown(ink.color), 0.38) : ink.shown(ink.color)
      strokeWidth: ink.tool === "marker" ? ink.penWidth * 6 : ink.penWidth
      fillColor: "transparent"
      capStyle: ink.tool === "marker" ? ShapePath.SquareCap : ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: ink.pathOf(pen.points) }
    }
  }

  // ---- drawing -----------------------------------------------------------------------

  Item {
    id: pen
    anchors.fill: parent
    enabled: ink.drawing
    property var points: []

    // Where the eraser is, while it's down.
    Rectangle {
      visible: ink.tool === "eraser" && eraser.active
      width: 22
      height: 22
      radius: 11
      x: eraser.centroid.position.x - 11
      y: eraser.centroid.position.y - 11
      color: Qt.alpha("#ffffff", 0.25)
      border.width: 1.5
      border.color: Qt.alpha("#000000", 0.4)
    }

    HoverHandler {
      enabled: ink.drawing
      cursorShape: ink.tool === "eraser" ? Qt.PointingHandCursor : Qt.CrossCursor
    }

    DragHandler {
      id: eraser
      target: null
      enabled: ink.drawing
      dragThreshold: 0
      grabPermissions: PointerHandler.CanTakeOverFromAnything
      property bool erased: false
      onActiveChanged: {
        if (active) {
          erased = false
          if (ink.tool !== "eraser") pen.points = [Math.round(centroid.pressPosition.x * 10) / 10, Math.round(centroid.pressPosition.y * 10) / 10]
          else ink.eraseAt(centroid.pressPosition.x, centroid.pressPosition.y, this)
        } else if (ink.tool !== "eraser") {
          ink.finishStroke()
        }
      }
      onCentroidChanged: {
        if (!active) return
        var p = centroid.position
        if (ink.tool === "eraser") { ink.eraseAt(p.x, p.y, this); return }
        var pts = pen.points
        var n = pts.length
        if (n >= 2 && Math.abs(pts[n - 2] - p.x) + Math.abs(pts[n - 1] - p.y) < 1.5) return
        pen.points = pts.concat([Math.round(p.x * 10) / 10, Math.round(p.y * 10) / 10])
      }
    }
  }

  function finishStroke() {
    var pts = pen.points
    pen.points = []
    if (pts.length < 2) return
    remember()
    strokes = strokes.concat([{
      tool: tool === "marker" ? "marker" : "pen",
      color: color,
      width: tool === "marker" ? penWidth * 6 : penWidth,
      points: pts
    }])
    changed()
  }

  // Lifts every stroke passing within reach of (x, y).
  function eraseAt(x, y, handler) {
    var reach = 10
    var keep = []
    var removed = false
    for (var i = 0; i < strokes.length; i++) {
      var s = strokes[i]
      if (near(s, x, y, reach + s.width / 2)) removed = true
      else keep.push(s)
    }
    if (!removed) return
    if (!handler.erased) { remember(); handler.erased = true }
    strokes = keep
    changed()
  }

  function near(stroke, x, y, reach) {
    var p = stroke.points
    for (var i = 0; i + 1 < p.length; i += 2) {
      var ax = p[i], ay = p[i + 1]
      var bx = i + 3 < p.length ? p[i + 2] : ax
      var by = i + 3 < p.length ? p[i + 3] : ay
      var dx = bx - ax, dy = by - ay
      var len = dx * dx + dy * dy
      var t = len > 0 ? Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / len)) : 0
      var cx = ax + t * dx - x
      var cy = ay + t * dy - y
      if (cx * cx + cy * cy <= reach * reach) return true
    }
    return false
  }
}
