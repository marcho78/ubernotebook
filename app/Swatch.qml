import QtQuick

// A color to pick: a dot, ringed when it's the one in use.
Item {
  id: swatch

  property var theme: null
  property color color: "#000000"
  property bool checked: false
  property string tip: ""
  property real size: 24
  // Highlighters show as a soft bar, like a marker's stroke.
  property bool marker: false

  signal clicked()

  implicitWidth: size + 6
  implicitHeight: size + 6

  Rectangle {
    anchors.centerIn: parent
    width: swatch.size + 6
    height: swatch.size + 6
    radius: width / 2
    color: "transparent"
    border.width: 2
    border.color: swatch.checked ? swatch.theme.accent : hover.hovered ? swatch.theme.line : "transparent"
  }

  Rectangle {
    anchors.centerIn: parent
    width: swatch.size
    height: swatch.marker ? swatch.size * 0.62 : swatch.size
    radius: swatch.marker ? 4 : width / 2
    rotation: swatch.marker ? -8 : 0
    color: swatch.color
    border.width: 1
    border.color: Qt.alpha("#000000", 0.18)
    scale: tap.pressed ? 0.9 : hover.hovered ? 1.08 : 1
    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutBack } }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; id: tap; onTapped: swatch.clicked() }
}
