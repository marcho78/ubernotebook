import QtQuick

// One line in a menu: an icon, what it does, and its shortcut.
Rectangle {
  id: rowItem

  property var theme: null
  property string icon: ""
  property string text: ""
  property string hint: ""
  property bool danger: false
  property bool checked: false
  property bool active: true

  signal clicked()

  implicitWidth: Math.max(200, content.implicitWidth + 24)
  implicitHeight: 32
  radius: 8
  color: hover.hovered && active ? theme.hover : "transparent"
  opacity: active ? 1 : 0.4

  Row {
    id: content
    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10
    Icon {
      theme: rowItem.theme
      text: rowItem.checked ? rowItem.theme.icons.check : rowItem.icon
      size: 15
      width: 18
      color: rowItem.danger ? rowItem.theme.urgent : rowItem.checked ? rowItem.theme.accent : rowItem.theme.muted
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      textFormat: Text.PlainText
      text: rowItem.text
      font.family: rowItem.theme.uiFont
      font.pixelSize: 13
      color: rowItem.danger ? rowItem.theme.urgent : rowItem.theme.text
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  Text {
    textFormat: Text.PlainText
    anchors.right: parent.right
    anchors.rightMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    text: rowItem.hint
    font.family: rowItem.theme.uiFont
    font.pixelSize: 12
    color: rowItem.theme.faint
  }

  HoverHandler { id: hover; cursorShape: rowItem.active ? Qt.PointingHandCursor : Qt.ArrowCursor }
  // (It takes the click for itself: nothing under the menu gets it too.)
  TapHandler { enabled: rowItem.active; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: rowItem.clicked() }
}
