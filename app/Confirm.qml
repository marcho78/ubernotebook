import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Asks before doing something that's hard to take back.
Popup {
  id: dialog

  property var theme: null
  property string heading: ""
  property string message: ""
  property string action: "OK"
  property var confirmAction: null

  anchors.centerIn: Overlay.overlay
  width: 400
  modal: true
  focus: true
  padding: 22
  closePolicy: Popup.CloseOnEscape

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, dialog.theme && dialog.theme.dark ? 0.5 : 0.3) }

  function ask(heading, message, action, then) {
    dialog.heading = heading
    dialog.message = message
    dialog.action = action
    dialog.confirmAction = then
    open()
    keyCatcher.forceActiveFocus()
  }

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 14; color: dialog.theme.surface; border.width: 1; border.color: dialog.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: dialog.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 12; autoPaddingEnabled: true }
  }

  contentItem: Column {
    spacing: 12
    Item {
      id: keyCatcher
      width: 1; height: 1
      Keys.onReturnPressed: { var f = dialog.confirmAction; dialog.close(); if (f) f() }
    }
    Text { textFormat: Text.PlainText; width: parent.width; text: dialog.heading; wrapMode: Text.WordWrap; font.family: dialog.theme.uiFont; font.pixelSize: 16; font.weight: Font.DemiBold; color: dialog.theme.text }
    Text { textFormat: Text.PlainText; width: parent.width; text: dialog.message; wrapMode: Text.WordWrap; font.family: dialog.theme.uiFont; font.pixelSize: 13; color: dialog.theme.muted; lineHeight: 1.2 }
    Row {
      anchors.right: parent.right
      spacing: 8
      IconButton { theme: dialog.theme; label: "Cancel"; onClicked: dialog.close() }
      Rectangle {
        width: actionLabel.implicitWidth + 32
        height: 34
        radius: 17
        color: actionTap.pressed ? Qt.darker(dialog.theme.urgent, 1.15) : dialog.theme.urgent
        Text { textFormat: Text.PlainText; id: actionLabel; anchors.centerIn: parent; text: dialog.action; font.family: dialog.theme.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: "white" }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { id: actionTap; onTapped: { var f = dialog.confirmAction; dialog.close(); if (f) f() } }
      }
    }
  }
}
