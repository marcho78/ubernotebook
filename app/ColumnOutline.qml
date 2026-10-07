import QtQuick
import QtQuick.Shapes

// A column's outline in Pages: a thin dashed line round it, rounded at the
// corners (and filled, for the new one a dragged block would make).
Shape {
  id: outline

  property color stroke: "gray"
  property color fill: "transparent"

  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    strokeColor: outline.stroke
    strokeWidth: 1
    strokeStyle: ShapePath.DashLine
    dashPattern: [4, 3]
    fillColor: outline.fill
    PathRectangle {
      x: 0.5
      y: 0.5
      width: Math.max(0, outline.width - 1)
      height: Math.max(0, outline.height - 1)
      radius: 6
    }
  }
}
