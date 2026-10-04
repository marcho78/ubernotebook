import QtQuick
import QtQuick.Shapes
import "../Diagram.js" as Diagram
import "../Colors.js" as Colors

// A Mermaid flowchart, drawn (Diagram.js reads and lays it out): boxes in
// their shapes with their icons and words, the lines between them with
// their arrowheads and words, groups round what's in them. In the page's
// colors, one ink: lines and outlines faint, words in the ink; or in
// colors of their own, as Mermaid gives them (classDef, class, style,
// linkStyle), kept readable on the page (Diagram.look). Wider than the
// room it has, it's drawn smaller (`shrunk`); `zoom` draws it at a size of
// its own instead (1: as big as it is), as the viewer does.
Item {
  id: view

  property string source: ""
  property color ink: "#1f2430"
  property color paper: "#ffffff"
  property string family: "sans-serif"
  property string iconFamily: "monospace"
  // The room it has across.
  property real maxWidth: 600
  // A size of its own (0: as big as fits in maxWidth, at most its own).
  property real zoom: 0

  readonly property var graph: Diagram.parse(source)
  // What's wrong, or what it can't draw ("" when it's drawn).
  readonly property string problem: Diagram.problem(graph)
  readonly property bool drawable: !graph.unsupported && graph.nodes.length > 0
  readonly property var lay: drawable ? Diagram.layout(graph, function(t, bold) { return (bold ? boldMetrics : metrics).advanceWidth(t) }, { lineHeight: Math.ceil(metrics.height) + 2, icon: 22, maxText: 180 }) : null
  readonly property real fit: zoom > 0 ? zoom : lay ? Math.min(1, maxWidth / Math.max(1, lay.w)) : 1
  // Drawn smaller than it is, to fit.
  readonly property bool shrunk: zoom <= 0 && lay !== null && fit < 0.999
  readonly property var nodeList: lay ? Object.keys(lay.nodes).map(function(id) { return lay.nodes[id] }) : []

  readonly property color line: Qt.alpha(ink, 0.42)
  readonly property color fill: Qt.tint(paper, Qt.alpha(ink, 0.045))
  // The page's colors as "#rrggbb", for colors of their own (Diagram.look).
  readonly property string inkHex: Colors.normalize(String(ink)) || "#000000"
  readonly property string paperHex: Colors.normalize(String(paper)) || "#ffffff"
  // A dash pattern in px, as ShapePath takes it (in widths of the line).
  function dashes(px, width) { return px && px.length ? px.map(function(d) { return Math.max(0.5, d) / Math.max(0.5, width) }) : [3, 3] }

  implicitWidth: lay ? lay.w * fit : 0
  implicitHeight: lay ? lay.h * fit : 0

  FontMetrics { id: metrics; font.family: view.family; font.pixelSize: 14 }
  FontMetrics { id: boldMetrics; font.family: view.family; font.pixelSize: 14; font.weight: Font.Bold }

  Item {
    width: view.lay ? view.lay.w : 0
    height: view.lay ? view.lay.h : 0
    scale: view.fit
    transformOrigin: Item.TopLeft

    // Groups (outer ones first).
    Repeater {
      model: view.lay ? view.lay.groups : []
      delegate: Item {
        id: group
        required property var modelData
        objectName: "diagramGroup"
        readonly property var look: Diagram.look(modelData.paint, view.inkHex, view.paperHex, false)
        readonly property color fillColor: look.fill || Qt.alpha(view.ink, 0.025)
        readonly property color strokeColor: look.width === 0 ? "transparent" : look.stroke || Qt.alpha(view.ink, 0.16)
        readonly property color textColor: look.text || Qt.alpha(view.ink, 0.6)
        x: modelData.x
        y: modelData.y
        width: modelData.w
        height: modelData.h
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: group.fillColor
            strokeColor: group.strokeColor
            strokeWidth: group.look.width > 0 ? group.look.width : 1
            strokeStyle: group.look.dash && group.look.dash.length ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: view.dashes(group.look.dash, strokeWidth)
            PathSvg { path: Diagram.shapePath("group", group.width, group.height) }
          }
        }
        Text {
          x: 10
          y: 5
          width: parent.width - 20
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: group.modelData.label
          font.family: view.family
          font.pixelSize: 11
          font.weight: group.look.bold ? Font.Bold : Font.DemiBold
          font.italic: group.look.italic
          color: group.textColor
        }
      }
    }

    // The lines, and what's at their ends.
    Repeater {
      model: view.lay ? view.lay.edges.filter(function(e) { return e.style !== "invisible" }) : []
      delegate: Shape {
        id: edge
        required property var modelData
        objectName: "diagramEdge"
        readonly property var look: Diagram.look(modelData.paint, view.inkHex, view.paperHex, true)
        readonly property color lineColor: look.width === 0 ? "transparent" : look.stroke || view.line
        readonly property real lineWidth: look.width > 0 ? look.width : modelData.style === "thick" ? 2.4 : 1.4
        readonly property bool dashed: look.dash ? look.dash.length > 0 : modelData.style === "dotted"
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: edge.lineColor
          strokeWidth: edge.lineWidth
          strokeStyle: edge.dashed ? ShapePath.DashLine : ShapePath.SolidLine
          dashPattern: view.dashes(edge.look.dash, edge.lineWidth)
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          joinStyle: ShapePath.RoundJoin
          PathSvg { path: Diagram.edgePath(edge.modelData.points, Diagram.cutFor(edge.modelData.arrowStart), Diagram.cutFor(edge.modelData.arrowEnd)) }
        }
        ShapePath {
          strokeColor: edge.lineColor
          strokeWidth: 1.4
          fillColor: edge.modelData.arrowEnd === "cross" ? "transparent" : edge.lineColor
          PathSvg { path: Diagram.endPath(edge.modelData.points, false, edge.modelData.arrowEnd) }
        }
        ShapePath {
          strokeColor: edge.lineColor
          strokeWidth: 1.4
          fillColor: edge.modelData.arrowStart === "cross" ? "transparent" : edge.lineColor
          PathSvg { path: Diagram.endPath(edge.modelData.points, true, edge.modelData.arrowStart) }
        }
      }
    }

    // The boxes: their shapes, icons and words.
    Repeater {
      model: view.nodeList
      delegate: Item {
        id: box
        required property var modelData
        objectName: "diagramNode"
        readonly property string label: modelData.label
        readonly property var look: Diagram.look(modelData.paint, view.inkHex, view.paperHex, false)
        readonly property color fillColor: look.fill || view.fill
        readonly property color strokeColor: look.width === 0 ? "transparent" : look.stroke || Qt.alpha(view.ink, 0.38)
        readonly property color textColor: look.text || view.ink
        x: modelData.x
        y: modelData.y
        width: modelData.w
        height: modelData.h
        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: box.strokeColor
            strokeWidth: box.look.width > 0 ? box.look.width : 1.2
            strokeStyle: box.look.dash && box.look.dash.length ? ShapePath.DashLine : ShapePath.SolidLine
            dashPattern: view.dashes(box.look.dash, strokeWidth)
            fillColor: box.fillColor
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: Diagram.shapePath(box.modelData.shape, box.width, box.height) }
          }
          ShapePath {
            strokeColor: box.strokeColor
            strokeWidth: box.look.width > 0 ? box.look.width : 1.2
            fillColor: "transparent"
            PathSvg { path: Diagram.shapeLines(box.modelData.shape, box.width, box.height) }
          }
        }
        Column {
          anchors.centerIn: parent
          anchors.verticalCenterOffset: box.modelData.shape === "cylinder" ? 4 : 0
          spacing: 4
          Text {
            visible: box.modelData.icon !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            textFormat: Text.PlainText
            text: Diagram.glyph(box.modelData.icon)
            font.family: view.iconFamily
            font.pixelSize: 20
            color: box.look.text ? Qt.alpha(box.textColor, 0.85) : Qt.alpha(view.ink, 0.72)
          }
          Repeater {
            model: box.modelData.lines
            delegate: Text {
              required property string modelData
              anchors.horizontalCenter: parent.horizontalCenter
              textFormat: Text.PlainText
              text: modelData
              font.family: view.family
              font.pixelSize: 14
              font.weight: box.look.bold ? Font.Bold : Font.Normal
              font.italic: box.look.italic
              color: box.textColor
            }
          }
        }
      }
    }

    // The words on the lines, on the page's color.
    Repeater {
      model: view.lay ? view.lay.edges.filter(function(e) { return e.label && e.labelAt }) : []
      delegate: Rectangle {
        id: words
        required property var modelData
        readonly property var look: Diagram.look(modelData.paint, view.inkHex, view.paperHex, true)
        x: modelData.labelAt.x - width / 2
        y: modelData.labelAt.y - height / 2
        width: edgeWords.implicitWidth + 10
        height: edgeWords.implicitHeight + 4
        radius: 4
        color: view.paper
        Text {
          id: edgeWords
          anchors.centerIn: parent
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: (modelData.labelLines && modelData.labelLines.length ? modelData.labelLines : [modelData.label]).join("\n")
          font.family: view.family
          font.pixelSize: 12
          font.weight: words.look.bold ? Font.DemiBold : Font.Normal
          font.italic: words.look.italic
          color: words.look.text || Qt.alpha(view.ink, 0.75)
        }
      }
    }
  }
}
