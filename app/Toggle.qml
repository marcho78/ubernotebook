import QtQuick

// On or off.
Item {
  id: toggle

  property var theme: null
  property bool checked: false

  signal toggled(bool checked)

  implicitWidth: 40
  implicitHeight: 24

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: toggle.checked ? toggle.theme.accent : toggle.theme.surfaceHigh
    border.width: 1
    border.color: toggle.checked ? "transparent" : toggle.theme.line
    Behavior on color { ColorAnimation { duration: 120 } }
    Rectangle {
      width: parent.height - 6
      height: width
      radius: width / 2
      y: 3
      x: toggle.checked ? parent.width - width - 3 : 3
      color: toggle.checked ? toggle.theme.onAccent : toggle.theme.text
      Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
    }
  }

  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: toggle.toggled(!toggle.checked) }
}
