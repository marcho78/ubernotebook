import QtQuick
import QtQuick.Shapes

// X's logo (formerly Twitter), drawn: the mark from Simple Icons (CC0), in
// the color given, `size` pixels square.
Item {
  id: logo

  property real size: 12
  property color color: "black"

  width: size
  height: size

  Shape {
    width: 24
    height: 24
    scale: logo.size / 24
    transformOrigin: Item.TopLeft
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: logo.color
      strokeWidth: -1
      strokeColor: "transparent"
      fillRule: ShapePath.OddEvenFill
      PathSvg { path: "M18.901 1.153h3.68l-8.04 9.19L24 22.846h-7.406l-5.8-7.584-6.638 7.584H.474l8.6-9.83L0 1.154h7.594l5.243 6.932ZM17.61 20.644h2.039L6.486 3.24H4.298Z" }
    }
  }
}
