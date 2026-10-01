import QtQuick

// A Nerd Font icon.
Text {
  textFormat: Text.PlainText
  property var theme: null
  property real size: 17
  font.family: theme ? theme.iconFont : "monospace"
  font.pixelSize: size
  color: theme ? theme.text : "white"
  horizontalAlignment: Text.AlignHCenter
  verticalAlignment: Text.AlignVCenter
  renderType: Text.NativeRendering
}
