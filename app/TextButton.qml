import QtQuick

// A button with words: outlined; the main one (`primary`) in the page's ink.
Rectangle {
  id: btn

  property var theme: null
  property string text: ""
  property string icon: ""
  property bool primary: false
  signal clicked()

  implicitWidth: btnRow.implicitWidth + 24
  implicitHeight: 32
  radius: 8
  color: primary ? (btnTap.pressed ? Qt.alpha(theme.text, 0.75) : btnHover.hovered ? Qt.alpha(theme.text, 0.86) : theme.text)
    : btnTap.pressed ? theme.pressed : btnHover.hovered ? theme.hover : "transparent"
  border.width: primary ? 0 : 1
  border.color: theme.line

  Row {
    id: btnRow
    anchors.centerIn: parent
    spacing: 6
    Text {
      visible: btn.icon !== ""
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: btn.icon
      font.family: btn.theme.iconFont
      font.pixelSize: 14
      color: btn.primary ? btn.theme.background : btn.theme.text
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: btn.text
      font.family: btn.theme.uiFont
      font.pixelSize: 13
      font.weight: btn.primary ? Font.DemiBold : Font.Normal
      color: btn.primary ? btn.theme.background : btn.theme.text
    }
  }
  HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
  TapHandler { id: btnTap; onTapped: btn.clicked() }
}
