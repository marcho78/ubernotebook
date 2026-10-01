import QtQuick
import QtQuick.Controls

// A button with an icon (and a label, if it has one), a hover and pressed
// state, an on state, and a tooltip that names its shortcut.
Item {
  id: button

  property var theme: null
  property string icon: ""
  property string label: ""
  property string tip: ""
  property bool checked: false
  property bool active: true
  property real size: 32
  property real iconSize: 17
  property color tint: theme ? theme.text : "white"
  // A small color bar under the icon (the ink or highlighter in use).
  property color swatch: "transparent"

  signal clicked()

  implicitWidth: label ? row.implicitWidth + 20 : size
  implicitHeight: size
  opacity: active ? 1 : 0.38

  Rectangle {
    anchors.fill: parent
    radius: Math.min(height / 2, 9)
    color: tap.pressed ? button.theme.pressed
      : button.checked ? button.theme.accentSoft
      : hover.hovered ? button.theme.hover : "transparent"
    Behavior on color { ColorAnimation { duration: 90 } }
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 7
    Icon {
      visible: button.icon !== ""
      theme: button.theme
      text: button.icon
      size: button.iconSize
      color: button.checked ? button.theme.accent : button.tint
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      visible: button.label !== ""
      text: button.label
      font.family: button.theme ? button.theme.uiFont : "sans-serif"
      font.pixelSize: 13
      font.weight: Font.Medium
      color: button.checked ? button.theme.accent : button.tint
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Rectangle {
    visible: button.swatch.a > 0
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 4
    width: button.iconSize * 0.9
    height: 3
    radius: 1.5
    color: button.swatch
  }

  HoverHandler { id: hover; cursorShape: button.active ? Qt.PointingHandCursor : Qt.ArrowCursor }
  TapHandler {
    id: tap
    enabled: button.active
    onTapped: button.clicked()
  }

  ToolTip {
    visible: hover.hovered && button.tip !== "" && !tap.pressed
    delay: 650
    timeout: 5000
    y: -implicitHeight - 6
    x: (button.width - implicitWidth) / 2
    padding: 6
    leftPadding: 9
    rightPadding: 9
    contentItem: Text {
      textFormat: Text.PlainText
      text: button.tip
      font.family: button.theme ? button.theme.uiFont : "sans-serif"
      font.pixelSize: 12
      color: button.theme ? button.theme.text : "white"
    }
    background: Rectangle {
      radius: 7
      color: button.theme ? button.theme.surfaceHigh : "#333"
      border.width: 1
      border.color: button.theme ? button.theme.line : "#444"
    }
  }
}
