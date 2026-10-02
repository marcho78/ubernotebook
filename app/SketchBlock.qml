import QtQuick
import QtQuick.Shapes
import "../Sketch.js" as Sketch
import "../Colors.js" as Colors

// A sketch on a page in Pages: a sheet to draw on with a pen or a
// highlighter, on plain paper, dots or a grid. Click it to draw: its tools
// come up under it (the pen, the highlighter, the eraser, which lifts whole
// strokes; the color, from Pages' colors, your recent ones or the color
// picker; three nibs; the background; Undo, Redo, and clearing it). Esc,
// Done, or a click elsewhere on the page stops. P, M and E pick the pen, the
// highlighter and the eraser. Every stroke is a step to undo, like any change
// to the page. Its bottom edge drags to make it taller or shorter. The
// strokes are in the sketch's own units (Sketch.js), so a drawing keeps its
// shape on any page width. A locked page's sketch is only shown.
Item {
  id: sk

  property var editor: null
  // The block it's in (DocBlock).
  property var host: null
  property string uid: ""
  // The sketch as the page has it (JSON).
  property string source: ""
  property real available: 600
  property color ink: "black"
  readonly property bool readOnly: editor ? editor.readOnly : true
  readonly property var theme: editor ? editor.theme : null
  readonly property bool dark: editor ? editor.dark : false

  // The sketch shown: the page's, or (while erasing or resizing) what it's becoming.
  property var sketch: Sketch.make()
  property string written: ""
  property bool drawing: false
  // The color menu or the color picker is open: drawing goes on.
  property bool picking: false

  readonly property string tool: editor ? editor.sketchTool : "pen"
  readonly property string penColor: editor ? (tool === "marker" ? editor.sketchMarker : editor.sketchColor) : ""
  readonly property real nib: editor ? editor.sketchNib : Sketch.NIBS[1]

  readonly property real unit: available / Sketch.WIDTH
  readonly property real canvasH: Math.round(sketch.height * unit)
  readonly property real barH: drawing && theme ? bar.height + 10 : 0

  width: available
  height: canvasH + barH

  onSourceChanged: if (source !== written) load()
  Component.onCompleted: load()

  function load() {
    var s = null
    try { s = Sketch.clean(JSON.parse(source)) } catch (e) { s = null }
    written = source
    sketch = s || Sketch.make()
  }

  // A change kept, as a step to undo.
  function commit(next) {
    var clean = Sketch.clean(next)
    if (!clean) return
    written = JSON.stringify(clean)
    sketch = clean
    editor.setSketch(uid, clean)
  }

  // A pen's color and a highlighter's, as they're drawn here.
  function colorOf(id) { return Sketch.colorHex(id, dark, String(ink)) }
  function markerOf(id) { return Sketch.markerHex(id, dark, String(ink)) }
  function alphaOf(id) { return id ? Sketch.MARKER_ALPHA[dark ? 1 : 0] : 0.25 }
  // The pen in use, as it draws.
  readonly property color penShown: tool === "marker" ? markerOf(penColor) : colorOf(penColor)

  // ---- drawing on and off ------------------------------------------------------------------

  function startDrawing() {
    if (readOnly) return
    drawing = true
    keys.forceActiveFocus()
    editor.sketchFocused(uid)
  }

  function stopDrawing() {
    if (!drawing) return
    drawing = false
    picking = false
    if (keys.activeFocus) editor.selectBlocks(uid, uid)
  }

  // Focus gone elsewhere (a click on the page, another block): drawing stops.
  function focusLeft() {
    Qt.callLater(function() {
      if (sk.drawing && !sk.picking && !keys.activeFocus) sk.drawing = false
    })
  }

  function pickTool(t) {
    if (!editor) return
    editor.sketchTool = t
    keys.forceActiveFocus()
  }

  function setNib(n) {
    editor.sketchNib = n
    keys.forceActiveFocus()
  }

  function setBackground(kind) {
    var x = Sketch.copy(sketch)
    x.background = kind
    commit(x)
    keys.forceActiveFocus()
  }

  function clearAll() {
    if (!sketch.strokes.length) return
    var x = Sketch.copy(sketch)
    x.strokes = []
    commit(x)
    keys.forceActiveFocus()
  }

  // ---- the pen's color (DocView's color menu and picker) ----------------------------------------

  function askColors(anchor) {
    picking = true
    editor.sketchColorsRequested(uid, anchor)
  }

  // A color picked for the pen in use ("" the page's ink, "red", "#ff8800").
  function setColor(id) {
    if (tool === "marker") editor.sketchMarker = id || "yellow"
    else editor.sketchColor = id || ""
    if (tool === "eraser") editor.sketchTool = "pen"
  }

  // The color menu or picker closed: drawing goes on.
  function colorsClosed() {
    picking = false
    if (drawing) keys.forceActiveFocus()
  }

  // What the color picker shows as the sample.
  function colorInfo() {
    var paper = Colors.normalize(String(editor.paper)) || "#ffffff"
    return { text: tool === "marker" ? "Highlighter" : "Pen", fill: paper, ownInk: colorOf(penColor), pageInk: Colors.normalize(String(ink)) || "#000000" }
  }

  // ---- keys while drawing -------------------------------------------------------------------------

  Item {
    id: keys
    focus: false
    onActiveFocusChanged: if (!activeFocus) sk.focusLeft()
    Keys.onPressed: function(e) {
      var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
      var shift = (e.modifiers & Qt.ShiftModifier) !== 0
      var alt = (e.modifiers & Qt.AltModifier) !== 0
      if (e.key === Qt.Key_Escape) { e.accepted = true; sk.stopDrawing(); return }
      if (ctrl && !alt && e.key === Qt.Key_Z) { e.accepted = true; if (shift) sk.editor.redo(); else sk.editor.undo(); return }
      if (ctrl && !alt && e.key === Qt.Key_Y) { e.accepted = true; sk.editor.redo(); return }
      if (ctrl || alt) return
      if (e.key === Qt.Key_P) { e.accepted = true; sk.pickTool("pen") }
      else if (e.key === Qt.Key_M) { e.accepted = true; sk.pickTool("marker") }
      else if (e.key === Qt.Key_E) { e.accepted = true; sk.pickTool("eraser") }
    }
  }

  // ---- the sheet -----------------------------------------------------------------------------------

  Rectangle {
    id: frame
    width: sk.available
    height: sk.canvasH
    radius: 8
    color: Qt.alpha(sk.ink, sk.dark ? 0.04 : 0.025)
    border.width: sk.drawing ? 1.5 : 1
    border.color: sk.drawing ? Qt.alpha(sk.editor.accent, 0.7) : Qt.alpha(sk.ink, sk.pointerIn ? 0.2 : 0.11)
    clip: true

    // The drawing, in the sketch's own units.
    Item {
      id: paper
      width: Sketch.WIDTH
      height: sk.sketch.height
      scale: sk.unit
      transformOrigin: Item.TopLeft

      // Dots or a grid, faint.
      Shape {
        anchors.fill: parent
        visible: sk.sketch.background !== "plain"
        ShapePath {
          strokeColor: Qt.alpha(sk.ink, sk.sketch.background === "grid" ? 0.08 : 0.2)
          strokeWidth: sk.sketch.background === "grid" ? 1 / Math.max(0.1, sk.unit) : 3
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathSvg { path: Sketch.backgroundPath(sk.sketch.background, sk.sketch.height, 25) }
        }
      }

      Repeater {
        model: sk.sketch.strokes
        delegate: Shape {
          required property var modelData
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: modelData.tool === "marker" ? Qt.alpha(sk.markerOf(modelData.color), sk.alphaOf(modelData.color)) : sk.colorOf(modelData.color)
            strokeWidth: modelData.width
            fillColor: "transparent"
            capStyle: modelData.tool === "marker" ? ShapePath.SquareCap : ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Sketch.pathOf(modelData.points) }
          }
        }
      }

      // The stroke being drawn.
      Shape {
        anchors.fill: parent
        visible: drawer.points.length > 0
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: sk.tool === "marker" ? Qt.alpha(sk.markerOf(sk.penColor), sk.alphaOf(sk.penColor)) : sk.colorOf(sk.penColor)
          strokeWidth: sk.tool === "marker" ? sk.nib * Sketch.MARKER : sk.nib
          fillColor: "transparent"
          capStyle: sk.tool === "marker" ? ShapePath.SquareCap : ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin
          PathSvg { path: Sketch.pathOf(drawer.points) }
        }
      }

      // Where the eraser is, while it's down.
      Rectangle {
        visible: sk.tool === "eraser" && drawer.active
        width: 2 * drawer.reach
        height: width
        radius: width / 2
        x: drawer.centroid.position.x - drawer.reach
        y: drawer.centroid.position.y - drawer.reach
        color: Qt.alpha(sk.ink, 0.08)
        border.width: 1.5 / Math.max(0.1, sk.unit)
        border.color: Qt.alpha(sk.ink, 0.45)
      }

      DragHandler {
        id: drawer
        objectName: "drawer"
        target: null
        enabled: sk.drawing && !sk.readOnly
        dragThreshold: 0
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        property var points: []
        property var before: null
        // Where the eraser was last (it erases all the way from there).
        property point last: Qt.point(0, 0)
        readonly property real reach: 14 / Math.max(0.2, sk.unit)

        function at(p) {
          return [Math.round(Math.max(0, Math.min(Sketch.WIDTH, p.x)) * 10) / 10, Math.round(Math.max(0, Math.min(sk.sketch.height, p.y)) * 10) / 10]
        }

        onActiveChanged: {
          if (active) {
            keys.forceActiveFocus()
            if (sk.tool === "eraser") {
              before = sk.sketch
              last = centroid.pressPosition
              sk.sketch = Sketch.erase(sk.sketch, last.x, last.y, reach).sketch
            } else {
              points = at(centroid.pressPosition)
            }
          } else if (sk.tool === "eraser") {
            var was = before
            before = null
            if (was && sk.sketch.strokes.length !== was.strokes.length) {
              var erased = sk.sketch
              sk.sketch = was
              sk.commit(erased)
            }
          } else {
            var pts = points
            points = []
            if (pts.length >= 2) sk.commit(Sketch.withStroke(sk.sketch, Sketch.stroke(sk.tool, sk.penColor, sk.nib, pts)))
          }
        }
        onCentroidChanged: {
          if (!active) return
          var p = centroid.position
          if (sk.tool === "eraser") {
            var r = Sketch.eraseAlong(sk.sketch, last.x, last.y, p.x, p.y, reach)
            last = p
            if (r.removed) sk.sketch = r.sketch
            return
          }
          var pts = points
          var n = pts.length
          var q = at(p)
          if (n >= 2 && Math.abs(pts[n - 2] - q[0]) + Math.abs(pts[n - 1] - q[1]) < 1.5 / Math.max(0.2, sk.unit)) return
          points = pts.concat(q)
        }
      }
    }

    // Not drawing: a click starts.
    TapHandler {
      enabled: !sk.drawing && !sk.readOnly
      onTapped: sk.startDrawing()
    }

    // An empty sketch says what it's for.
    Column {
      anchors.centerIn: parent
      visible: sk.sketch.strokes.length === 0 && !sk.drawing
      spacing: 4
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: "\u{f0f49}"
        font.family: sk.theme ? sk.theme.iconFont : "monospace"
        font.pixelSize: 26
        color: Qt.alpha(sk.ink, 0.3)
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: sk.readOnly ? "An empty sketch" : "Click to draw"
        font.family: sk.editor ? sk.editor.uiFamily : "sans-serif"
        font.pixelSize: 13
        color: Qt.alpha(sk.ink, 0.45)
      }
    }

    // Pointed at, not drawing: it says a click draws.
    Rectangle {
      visible: sk.pointerIn && !sk.drawing && !sk.readOnly && sk.sketch.strokes.length > 0
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 8
      width: hint.implicitWidth + 18
      height: 24
      radius: 12
      color: Qt.alpha(sk.ink, 0.07)
      Text {
        id: hint
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "Click to draw"
        font.family: sk.editor ? sk.editor.uiFamily : "sans-serif"
        font.pixelSize: 11
        color: Qt.alpha(sk.ink, 0.6)
      }
    }

    // The bottom edge: drag to make it taller or shorter. (It takes the
    // press outright, so the pen under it doesn't draw.)
    MouseArea {
      id: edge
      objectName: "sketchEdge"
      visible: !sk.readOnly
      width: parent.width
      height: 10
      y: parent.height - height
      preventStealing: true
      cursorShape: Qt.SizeVerCursor
      property real startH: 0
      property real startY: 0
      readonly property bool active: pressed
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 3
        width: 36
        height: 4
        radius: 2
        color: Qt.alpha(sk.ink, 0.35)
        visible: sk.onEdge || edge.pressed
      }
      onPressed: function(m) {
        startH = sk.sketch.height
        startY = mapToItem(sk, m.x, m.y).y
      }
      onPositionChanged: function(m) {
        if (!pressed) return
        var dy = mapToItem(sk, m.x, m.y).y - startY
        var x = Sketch.copy(sk.sketch)
        x.height = Math.round(Math.max(Sketch.MIN_HEIGHT, Math.min(Sketch.MAX_HEIGHT, startH + dy / Math.max(0.1, sk.unit))))
        sk.sketch = x
      }
      onReleased: if (sk.sketch.height !== startH) sk.commit(sk.sketch)
      onCanceled: { var x = Sketch.copy(sk.sketch); x.height = startH; sk.sketch = x }
    }

    // The pointer over the sheet. On top, as only the topmost thing under
    // the pointer is told it's there; it takes nothing from what's under it.
    Item {
      anchors.fill: parent
      HoverHandler {
        id: hover
        cursorShape: edge.pressed || sk.onEdge ? Qt.SizeVerCursor
          : sk.readOnly ? Qt.ArrowCursor
          : !sk.drawing ? Qt.PointingHandCursor
          : sk.tool === "eraser" ? Qt.PointingHandCursor : Qt.CrossCursor
      }
    }
  }

  readonly property bool pointerIn: hover.hovered
  readonly property bool onEdge: hover.hovered && !readOnly && hover.point.position.y > canvasH - 10

  // ---- the tools, under it, while drawing ---------------------------------------------------------

  Rectangle {
    id: barBack
    visible: sk.drawing && sk.theme !== null
    y: sk.canvasH + 6
    width: Math.min(sk.available, bar.width + 12)
    height: bar.height + 4
    radius: 12
    color: sk.theme ? sk.theme.surface : "white"
    border.width: 1
    border.color: sk.theme ? sk.theme.line : "gray"

    Flow {
      id: bar
      objectName: "sketchBar"
      x: 6
      y: 2
      width: Math.min(naturalW, sk.available - 12)
      spacing: 2
      // As wide as its tools in one row, or the sketch, whichever's less.
      readonly property real naturalW: {
        var w = 0
        for (var i = 0; i < children.length; i++) if (children[i].visible && children[i].width > 0) w += children[i].width + spacing
        return Math.max(0, w - spacing)
      }

      component Sep: Rectangle {
        width: 1
        height: 30
        color: sk.theme ? sk.theme.line : "gray"
      }

      IconButton {
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.check : ""; label: "Done"; tip: "Stop drawing  Esc"
        onClicked: sk.stopDrawing()
      }
      Sep {}
      IconButton {
        objectName: "penTool"
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.pen : ""; tip: "Pen  P"
        checked: sk.tool === "pen"
        onClicked: sk.pickTool("pen")
      }
      IconButton {
        objectName: "markerTool"
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.marker : ""; tip: "Highlighter  M"
        checked: sk.tool === "marker"
        onClicked: sk.pickTool("marker")
      }
      IconButton {
        objectName: "eraserTool"
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.eraser : ""; tip: "Eraser: lifts whole strokes  E"
        checked: sk.tool === "eraser"
        onClicked: sk.pickTool("eraser")
      }
      Sep {}
      // The color: the pen's (a dot) or the highlighter's (a bar), ringed,
      // with an arrow: it opens the colors.
      Item {
        id: colorButton
        objectName: "sketchColor"
        width: 44
        height: 32
        opacity: sk.tool === "eraser" ? 0.4 : 1
        Rectangle {
          anchors.fill: parent
          radius: 9
          color: colorTap.pressed ? sk.theme.pressed : colorHover.hovered ? sk.theme.hover : "transparent"
        }
        Rectangle {
          x: 6
          anchors.verticalCenter: parent.verticalCenter
          width: 22
          height: 22
          radius: 11
          color: "transparent"
          border.width: 1.5
          border.color: sk.theme.line
          Rectangle {
            anchors.centerIn: parent
            width: sk.tool === "marker" ? 16 : 14
            height: sk.tool === "marker" ? 8 : 14
            radius: sk.tool === "marker" ? 2 : 7
            rotation: sk.tool === "marker" ? -12 : 0
            color: sk.tool === "marker" ? Qt.alpha(sk.penShown, Math.min(1, sk.alphaOf(sk.penColor) + 0.3)) : sk.penShown
          }
        }
        Text {
          x: 31
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "\u{f0140}"
          font.family: sk.theme.iconFont
          font.pixelSize: 12
          color: sk.theme.muted
        }
        HoverHandler { id: colorHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: colorTap; onTapped: sk.askColors(colorButton) }
      }
      Sep {}
      Repeater {
        model: Sketch.NIBS
        delegate: Item {
          required property var modelData
          width: 30
          height: 30
          Rectangle {
            anchors.fill: parent
            radius: 9
            color: sk.nib === modelData ? sk.theme.accentSoft : nibHover.hovered ? sk.theme.hover : "transparent"
          }
          Rectangle {
            anchors.centerIn: parent
            width: Math.min(18, modelData * 2)
            height: width
            radius: width / 2
            color: sk.nib === modelData ? sk.theme.accent : sk.theme.text
          }
          HoverHandler { id: nibHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: sk.setNib(modelData) }
        }
      }
      Sep {}
      IconButton {
        theme: sk.theme; icon: "\u{f0763}"; tip: "Plain paper"
        checked: sk.sketch.background === "plain"
        onClicked: sk.setBackground("plain")
      }
      IconButton {
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.dots : ""; tip: "Dots"
        checked: sk.sketch.background === "dots"
        onClicked: sk.setBackground("dots")
      }
      IconButton {
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.grid : ""; tip: "Grid"
        checked: sk.sketch.background === "grid"
        onClicked: sk.setBackground("grid")
      }
      Sep {}
      IconButton {
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.undo : ""; tip: "Undo  Ctrl+Z"
        active: sk.editor.canUndo
        onClicked: { sk.editor.undo(); keys.forceActiveFocus() }
      }
      IconButton {
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.redo : ""; tip: "Redo  Ctrl+Shift+Z"
        active: sk.editor.canRedo
        onClicked: { sk.editor.redo(); keys.forceActiveFocus() }
      }
      IconButton {
        objectName: "clearSketch"
        theme: sk.theme; icon: sk.theme ? sk.theme.icons.trash : ""; tip: "Clear the sketch"
        active: sk.sketch.strokes.length > 0
        onClicked: sk.clearAll()
      }
    }
  }
}
