import QtQuick
import QtQuick.Controls
import "../Equations.js" as Equations

// A diagram or an equation, large, over everything: zoomed with Ctrl+scroll
// or a pinch (round the pointer), + and − (or the buttons), moved by
// dragging or scrolling (Shift+scroll sideways, or the arrows); Fit (0)
// shows all of it, 100% (1) as big as it is. It's drawn again at each size,
// so it stays sharp. Esc (or ✕) closes it. Copy and Save (Ctrl+C, Ctrl+S)
// make it a picture. It's on its block's colors. Nothing on the page under
// it is clicked or scrolled through it.
Popup {
  id: viewer

  property var theme: null
  // The editor: the page's ink and fonts, and equations drawn (mathOf).
  property var editor: null
  // "diagram" (Mermaid) or "math" (LaTeX), and what's written.
  property string kind: ""
  property string source: ""
  // Its block's colors: its words', and behind it.
  property var look: null
  readonly property color drawnInk: look && look.ink ? look.ink : editor ? editor.ink : "#000000"
  readonly property color drawnBack: look && look.back ? look.back : theme.background
  property real zoom: 1
  // Laid out and fitted to the window, once opened; zoomed or moved since.
  property bool fitted: false
  property bool touched: false
  readonly property real minZoom: 0.2
  // (An equation no bigger than Equations.js draws one: maxEm.)
  readonly property real maxZoom: kind === "math" && mathDrawing && mathDrawing.svg ? Math.max(minZoom, Math.min(6, Equations.maxEm(mathDrawing.svg) / mathEm)) : 6
  readonly property real margin: 40

  // An equation at 100%: as big as the page's text, a little bigger.
  readonly property real mathEm: 26
  readonly property var mathDrawing: { var r = editor ? editor.mathRevision : 0; return kind === "math" && editor ? editor.mathOf(source, true) : null }
  readonly property var mathNatural: mathDrawing && mathDrawing.svg ? Equations.sized(mathDrawing.svg, mathEm, "#000000") : null
  readonly property var mathShown: mathDrawing && mathDrawing.svg ? Equations.sized(mathDrawing.svg, mathEm * zoom, String(drawnInk)) : null

  // How big it is at 100%.
  readonly property real naturalW: kind === "diagram" ? (diagram.lay ? diagram.lay.w : 0) : mathNatural ? mathNatural.width : 0
  readonly property real naturalH: kind === "diagram" ? (diagram.lay ? diagram.lay.h : 0) : mathNatural ? mathNatural.height : 0
  readonly property real drawnW: naturalW * zoom
  readonly property real drawnH: naturalH * zoom

  parent: Overlay.overlay
  x: 0
  y: 0
  width: parent ? parent.width : 800
  height: parent ? parent.height : 600
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape
  background: Rectangle { color: viewer.drawnBack }
  Overlay.modal: Item {}

  objectName: "drawingViewer"
  // (The keys come here, not to the page under it.)
  onOpened: contentItem.forceActiveFocus()

  function show(k, src, colors) {
    kind = k
    source = String(src || "")
    look = colors || null
    said = ""
    zoom = 1
    fitted = false
    touched = false
    open()
    later.restart()
  }
  // (Once it's laid out: all of it, as big as the window lets it be, at
  // most twice its size; an equation still being drawn, once it is.)
  Timer { id: later; interval: 30; onTriggered: viewer.fit() }
  onNaturalWChanged: if (opened && !fitted && naturalW > 0) later.restart()

  // Made a picture: copied, or saved where you say.
  function copy() { if (editor) editor.copyDrawing(kind, source, look) }
  function save() { if (editor) editor.saveDrawing(kind, source, look) }
  // What's said (copied, saved), where the hint is, a moment.
  property string said: ""
  function say(text) { said = String(text || ""); sayTimer.restart() }
  Timer { id: sayTimer; interval: 3000; onTriggered: viewer.said = "" }

  function clamp(z) { return Math.max(minZoom, Math.min(maxZoom, z)) }
  // Where it sits in the canvas (centered while it's smaller than the window).
  function offsetX(z) { return Math.max(margin, (flick.width - naturalW * z) / 2) }
  function offsetY(z) { return Math.max(margin, (flick.height - naturalH * z) / 2) }

  function fit() {
    if (naturalW <= 0 || naturalH <= 0) return
    zoom = clamp(Math.min((flick.width - margin * 2) / naturalW, (flick.height - margin * 2) / naturalH, 2))
    flick.contentX = 0
    flick.contentY = 0
    fitted = true
  }
  // Zoomed by `factor` round a point in the window (its middle, by default),
  // what's under it staying under it.
  function zoomBy(factor, px, py) { zoomTo(zoom * factor, px, py) }
  function zoomTo(target, px, py) {
    var old = zoom
    var next = clamp(target)
    if (next === old) return
    touched = true
    var x = px === undefined ? flick.width / 2 : px
    var y = py === undefined ? flick.height / 2 : py
    var dx = (flick.contentX + x - offsetX(old)) / old
    var dy = (flick.contentY + y - offsetY(old)) / old
    zoom = next
    flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, dx * next + offsetX(next) - x))
    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, dy * next + offsetY(next) - y))
  }
  function actual() { zoomTo(1) }
  // A wheel's notch (or a touchpad's move), in pixels moved.
  function wheelPx(pixels, angle) { return pixels !== 0 ? pixels : angle / 120 * 60 }
  function pan(dx, dy) {
    if (dx !== 0 || dy !== 0) touched = true
    flick.contentX = Math.max(0, Math.min(flick.contentWidth - flick.width, flick.contentX + dx))
    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy))
  }

  contentItem: FocusScope {
    focus: true
    Keys.onPressed: function(e) {
      if (e.matches(StandardKey.Copy)) viewer.copy()
      else if (e.matches(StandardKey.Save)) viewer.save()
      else if (e.key === Qt.Key_Plus || e.key === Qt.Key_Equal) viewer.zoomBy(1.25)
      else if (e.key === Qt.Key_Minus || e.key === Qt.Key_Underscore) viewer.zoomBy(0.8)
      else if (e.key === Qt.Key_0) viewer.fit()
      else if (e.key === Qt.Key_1) viewer.actual()
      else if (e.key === Qt.Key_Left) viewer.pan(-60, 0)
      else if (e.key === Qt.Key_Right) viewer.pan(60, 0)
      else if (e.key === Qt.Key_Up) viewer.pan(0, -60)
      else if (e.key === Qt.Key_Down) viewer.pan(0, 60)
      else return
      e.accepted = true
    }

    // A press anywhere on it is its own: nothing on the page under it is
    // clicked through it (a tap on its buttons would also reach a button
    // there otherwise).
    Item {
      anchors.fill: parent
      TapHandler { gesturePolicy: TapHandler.WithinBounds }
    }

    // (Under the bar at the top.)
    Flickable {
      id: flick
      objectName: "drawingViewerArea"
      anchors.fill: parent
      anchors.topMargin: bar.height
      contentWidth: Math.max(width, viewer.drawnW + viewer.margin * 2)
      contentHeight: Math.max(height, viewer.drawnH + viewer.margin * 2)
      clip: true
      // (Moved and zoomed by the surface over it; kept in bounds when the
      // window's resized.)
      interactive: false
      boundsBehavior: Flickable.StopAtBounds
      onWidthChanged: viewer.pan(0, 0)
      onHeightChanged: viewer.pan(0, 0)
      ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      // The diagram, drawn at the zoom.
      DiagramView {
        id: diagram
        objectName: "viewerDiagram"
        visible: viewer.kind === "diagram"
        x: viewer.offsetX(viewer.zoom)
        y: viewer.offsetY(viewer.zoom)
        width: implicitWidth
        height: implicitHeight
        source: viewer.kind === "diagram" ? viewer.source : ""
        zoom: viewer.zoom
        ink: viewer.drawnInk
        paper: viewer.drawnBack
        family: viewer.editor ? viewer.editor.uiFamily : "sans-serif"
        iconFamily: viewer.theme.iconFont
      }
      // The equation, drawn again at the zoom (sharp on a dense screen,
      // never larger than a graphics card takes).
      Image {
        objectName: "viewerMath"
        // (In the screen's own pixels: Qt draws it that much bigger again.)
        readonly property real density: Math.min(2, 8192 / Math.max(1, width, height)) / Math.max(1, Screen.devicePixelRatio)
        visible: viewer.kind === "math" && viewer.mathShown !== null
        x: viewer.offsetX(viewer.zoom)
        y: viewer.offsetY(viewer.zoom)
        width: viewer.mathShown ? viewer.mathShown.width : 0
        height: viewer.mathShown ? viewer.mathShown.height : 0
        sourceSize.width: Math.ceil(width * density)
        sourceSize.height: Math.ceil(height * density)
        smooth: true
        source: viewer.mathShown ? "data:image/svg+xml;utf8," + encodeURIComponent(viewer.mathShown.svg) : ""
      }
    }
    // Over it: dragged, it moves; scrolled, it moves; Ctrl+scrolled or
    // pinched, it's zoomed round the pointer.
    Item {
      id: surface
      objectName: "drawingViewerSurface"
      anchors.fill: flick
      anchors.rightMargin: 12
      anchors.bottomMargin: 12
      DragHandler {
        id: drag
        target: null
        property real lastX: 0
        property real lastY: 0
        cursorShape: active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onActiveChanged: { lastX = 0; lastY = 0 }
        onTranslationChanged: {
          viewer.pan(-(translation.x - lastX), -(translation.y - lastY))
          lastX = translation.x
          lastY = translation.y
        }
      }
      WheelHandler {
        target: null
        acceptedModifiers: Qt.ControlModifier
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(e) {
          var steps = e.angleDelta.y !== 0 ? e.angleDelta.y / 120 : e.pixelDelta.y / 60
          if (steps !== 0) viewer.zoomBy(Math.pow(1.2, steps), point.position.x, point.position.y)
        }
      }
      // Up and down; sideways with a sideways wheel (or a touchpad), or
      // with Shift held.
      WheelHandler {
        target: null
        acceptedModifiers: Qt.NoModifier
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(e) { viewer.pan(0, -viewer.wheelPx(e.pixelDelta.y, e.angleDelta.y)) }
      }
      WheelHandler {
        target: null
        orientation: Qt.Horizontal
        acceptedModifiers: Qt.NoModifier
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(e) { viewer.pan(-viewer.wheelPx(e.pixelDelta.x, e.angleDelta.x), 0) }
      }
      WheelHandler {
        target: null
        acceptedModifiers: Qt.ShiftModifier
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: function(e) { viewer.pan(-viewer.wheelPx(e.pixelDelta.y, e.angleDelta.y), 0) }
      }
      PinchHandler {
        target: null
        property real last: 1
        onActiveChanged: last = 1
        onActiveScaleChanged: {
          if (!active || activeScale <= 0) return
          viewer.zoomBy(activeScale / last, centroid.position.x, centroid.position.y)
          last = activeScale
        }
      }
    }

    // What it is, and the controls, at the top.
    Rectangle {
      id: bar
      anchors.left: parent.left
      anchors.right: parent.right
      height: 52
      color: viewer.theme.background
      Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: viewer.theme.line }
      Text {
        x: 20
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: viewer.kind === "math" ? "Equation" : "Diagram"
        font.family: viewer.theme.uiFont
        font.pixelSize: 14
        font.weight: Font.DemiBold
        color: viewer.theme.text
      }
      Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4
        IconButton {
          objectName: "viewerCopy"
          theme: viewer.theme; icon: viewer.theme.icons.copy; size: 32; iconSize: 16; tip: "Copy as a picture  Ctrl+C"
          onClicked: viewer.copy()
        }
        IconButton {
          objectName: "viewerSave"
          theme: viewer.theme; icon: viewer.theme.icons.download; size: 32; iconSize: 17; tip: "Save as a picture  Ctrl+S"
          onClicked: viewer.save()
        }
        Item { width: 8; height: 1 }
        IconButton {
          objectName: "viewerZoomOut"
          theme: viewer.theme; icon: viewer.theme.icons.zoomOut; size: 32; iconSize: 17; tip: "Smaller  \u2212"
          active: viewer.zoom > viewer.minZoom + 0.001
          onClicked: viewer.zoomBy(0.8)
        }
        // How big (a click: as big as it is).
        Rectangle {
          objectName: "viewerZoom"
          anchors.verticalCenter: parent.verticalCenter
          width: 58
          height: 28
          radius: 6
          color: zoomHover.hovered ? viewer.theme.hover : "transparent"
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: Math.round(viewer.zoom * 100) + "%"
            font.family: viewer.theme.uiFont
            font.pixelSize: 13
            font.features: { "tnum": 1 }
            color: viewer.theme.text
          }
          HoverHandler { id: zoomHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: viewer.actual() }
        }
        IconButton {
          objectName: "viewerZoomIn"
          theme: viewer.theme; icon: viewer.theme.icons.zoomIn; size: 32; iconSize: 17; tip: "Bigger  +"
          active: viewer.zoom < viewer.maxZoom - 0.001
          onClicked: viewer.zoomBy(1.25)
        }
        IconButton {
          objectName: "viewerFit"
          theme: viewer.theme; icon: viewer.theme.icons.fitScreen; size: 32; iconSize: 17; tip: "All of it  0"
          onClicked: viewer.fit()
        }
        Item { width: 8; height: 1 }
        IconButton {
          objectName: "viewerClose"
          theme: viewer.theme; icon: viewer.theme.icons.close; size: 32; iconSize: 16; tip: "Close  Esc"
          onClicked: viewer.close()
        }
      }
    }
    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 14
      textFormat: Text.PlainText
      text: "Ctrl+scroll or pinch to zoom \u00b7 drag or scroll to move \u00b7 0 all of it \u00b7 1 as big as it is \u00b7 Esc to close"
      font.family: viewer.theme.uiFont
      font.pixelSize: 12
      color: viewer.theme.faint
      // (Out of the way once it's been zoomed or moved, or something's said.)
      opacity: viewer.touched || viewer.said !== "" ? 0 : 1
      Behavior on opacity { NumberAnimation { duration: 250 } }
    }
    // What's said: copied, saved (or why not).
    Rectangle {
      objectName: "viewerSaid"
      readonly property string text: viewer.said
      visible: viewer.said !== ""
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 10
      width: saidText.implicitWidth + 28
      height: 30
      radius: 15
      color: viewer.theme.surfaceHigh
      border.width: 1
      border.color: viewer.theme.line
      Text {
        id: saidText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: viewer.said
        font.family: viewer.theme.uiFont
        font.pixelSize: 13
        color: viewer.theme.text
      }
    }
  }
}
