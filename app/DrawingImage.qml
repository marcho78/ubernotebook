import QtQuick
import "../Equations.js" as Equations

// A diagram or an equation made a picture: drawn as it's drawn on the page
// (the same DiagramView, the same equation), at twice its size so it's sharp
// (smaller for a huge one: never more than 8192 px across), on its block's
// background with a margin round it, out of sight (beside the window, not in
// it), then grabbed (take). Store.qml's saveGrab writes the PNG.
Item {
  id: shot

  // The editor: the fonts, and equations drawn (mathOf).
  property var editor: null
  // "diagram" (Mermaid) or "math" (LaTeX), what's written, and its colors.
  property string kind: ""
  property string source: ""
  property color ink: "#000000"
  property color paper: "#ffffff"

  readonly property real margin: 24
  // An equation at 100%: as the viewer has it.
  readonly property real mathEm: 26
  readonly property var mathDrawing: { var r = editor ? editor.mathRevision : 0; return kind === "math" && editor ? editor.mathOf(source, true) : null }
  readonly property var mathNatural: mathDrawing && mathDrawing.svg ? Equations.sized(mathDrawing.svg, mathEm, "#000000") : null
  readonly property real naturalW: kind === "diagram" ? (diagram.lay ? diagram.lay.w : 0) : mathNatural ? mathNatural.width : 0
  readonly property real naturalH: kind === "diagram" ? (diagram.lay ? diagram.lay.h : 0) : mathNatural ? mathNatural.height : 0
  readonly property real scale: Math.min(2, 8192 / Math.max(1, naturalW + 2 * margin, naturalH + 2 * margin))
  readonly property var mathShown: mathDrawing && mathDrawing.svg ? Equations.sized(mathDrawing.svg, mathEm * scale, String(ink)) : null
  // Drawn, and ready to be grabbed.
  readonly property bool ready: naturalW > 0 && (kind === "diagram" || mathPicture.status === Image.Ready)

  x: -width - 4000
  width: canvas.width
  height: canvas.height

  Rectangle {
    id: canvas
    objectName: "drawingImageCanvas"
    width: Math.ceil((shot.naturalW + 2 * shot.margin) * shot.scale)
    height: Math.ceil((shot.naturalH + 2 * shot.margin) * shot.scale)
    color: shot.paper

    DiagramView {
      id: diagram
      visible: shot.kind === "diagram"
      x: shot.margin * shot.scale
      y: shot.margin * shot.scale
      width: implicitWidth
      height: implicitHeight
      source: shot.kind === "diagram" ? shot.source : ""
      zoom: shot.scale
      ink: shot.ink
      paper: shot.paper
      family: shot.editor ? shot.editor.uiFamily : "sans-serif"
      iconFamily: shot.editor && shot.editor.theme ? shot.editor.theme.iconFont : "monospace"
    }
    Image {
      id: mathPicture
      visible: shot.kind === "math"
      x: shot.margin * shot.scale
      y: shot.margin * shot.scale
      width: shot.mathShown ? shot.mathShown.width : 0
      height: shot.mathShown ? shot.mathShown.height : 0
      sourceSize.width: Math.ceil(width)
      sourceSize.height: Math.ceil(height)
      smooth: true
      source: shot.mathShown ? "data:image/svg+xml;utf8," + encodeURIComponent(shot.mathShown.svg) : ""
    }
  }

  // done(the grab), or done(null) when there's nothing drawn to grab.
  function take(done) {
    if (!ready || !canvas.grabToImage(function(result) { done(result) })) done(null)
  }
}
