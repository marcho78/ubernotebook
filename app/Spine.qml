import QtQuick
import QtQuick.Shapes

// What holds the pages together, drawn over the left edge of the page: a
// wire spiral through punched holes, or the fold of a sewn or hardcover
// notebook, with its shadow.
Item {
  id: spine

  property string binding: "spiral"
  property bool dark: false
  // Where the page's left edge is, in this item.
  property real edge: 16

  // ---- spiral ------------------------------------------------------------------

  Repeater {
    model: spine.binding === "spiral" ? Math.max(0, Math.floor((spine.height - 30) / 22)) : 0
    delegate: Item {
      required property int index
      x: 0
      y: 16 + index * 22
      width: spine.edge + 26
      height: 14

      // The hole punched in the page.
      Rectangle {
        x: spine.edge + 12
        y: 3
        width: 9
        height: 9
        radius: 4.5
        color: spine.dark ? "#0b0c0e" : "#3a3631"
        opacity: 0.8
        Rectangle {
          anchors.fill: parent
          anchors.margins: -1
          radius: width / 2
          color: "transparent"
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, spine.dark ? 0.06 : 0.35)
        }
      }

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // Its shadow on the paper.
        ShapePath {
          strokeColor: Qt.rgba(0, 0, 0, 0.22)
          strokeWidth: 3
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: spine.edge + 17; startY: 9
          PathCubic { x: spine.edge - 13; y: 11; control1X: spine.edge + 9; control1Y: 1; control2X: spine.edge - 6; control2Y: 1 }
        }
        // The wire, and the light along it.
        ShapePath {
          strokeColor: spine.dark ? "#8d939c" : "#7b828c"
          strokeWidth: 3.4
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: spine.edge + 16; startY: 7
          PathCubic { x: spine.edge - 14; y: 8; control1X: spine.edge + 8; control1Y: -2; control2X: spine.edge - 7; control2Y: -2 }
        }
        ShapePath {
          strokeColor: spine.dark ? "#d7dbe1" : "#eef1f4"
          strokeWidth: 1.2
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: spine.edge + 13; startY: 3.6
          PathCubic { x: spine.edge - 10; y: 3.6; control1X: spine.edge + 6; control1Y: -1.5; control2X: spine.edge - 4; control2Y: -1.5 }
        }
      }
    }
  }

  // ---- a fold (sewn or hardcover) -------------------------------------------------

  Rectangle {
    visible: spine.binding !== "spiral"
    x: spine.edge
    width: spine.binding === "hardcover" ? 34 : 26
    height: spine.height
    gradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, spine.dark ? 0.45 : 0.2) }
      GradientStop { position: 0.35; color: Qt.rgba(0, 0, 0, spine.dark ? 0.16 : 0.07) }
      GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
    }
  }

  // The thread of a sewn notebook, where the pages fold.
  Repeater {
    model: spine.binding === "stitched" ? Math.max(0, Math.floor((spine.height - 60) / 64)) : 0
    delegate: Rectangle {
      required property int index
      x: spine.edge + 3
      y: 40 + index * 64
      width: 2
      height: 22
      radius: 1
      color: spine.dark ? "#cfc8b8" : "#b9ad93"
      opacity: 0.7
    }
  }
}
