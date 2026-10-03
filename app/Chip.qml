import QtQuick

// A choice among a few: a pill that's filled when picked.
Rectangle {
  id: chip

  property var theme: null
  property string text: ""
  property string icon: ""
  property bool checked: false

  signal clicked()

  implicitWidth: row.implicitWidth + 22
  implicitHeight: 30
  radius: height / 2
  color: checked ? theme.accentSoft : hover.hovered ? theme.hover : "transparent"
  border.width: 1
  border.color: checked ? Qt.alpha(theme.accent, 0.7) : theme.line
  Behavior on color { ColorAnimation { duration: 90 } }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 6
    Icon {
      visible: chip.icon !== ""
      theme: chip.theme
      text: chip.icon
      size: 14
      color: chip.checked ? chip.theme.accent : chip.theme.text
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      text: chip.text
      font.family: chip.theme.uiFont
      font.pixelSize: 13
      color: chip.checked ? chip.theme.accent : chip.theme.text
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  // (Its press is its own: not a click on what's under a menu it's in.)
  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: chip.clicked() }
}
