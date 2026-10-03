import QtQuick

// Notebooks or Pages: the two ways to write in Uber Notebook, side by side in a
// pill, the one you're in filled.
Rectangle {
  id: sw

  property var theme: null
  // "notebooks" or "pages".
  property string space: "notebooks"

  signal picked(string space)

  implicitWidth: row.implicitWidth + 6
  implicitHeight: 32
  radius: height / 2
  color: theme.dark ? Qt.alpha("#000000", 0.2) : Qt.alpha(theme.foreground, 0.06)
  border.width: 1
  border.color: theme.line

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 0
    Repeater {
      model: [["notebooks", sw.theme.icons.notebook, "Notebooks"], ["pages", sw.theme.icons.page, "Pages"]]
      delegate: Rectangle {
        required property var modelData
        readonly property bool on: sw.space === modelData[0]
        width: inner.implicitWidth + 22
        height: sw.height - 6
        radius: height / 2
        color: on ? sw.theme.surfaceHigh : hover.hovered ? sw.theme.hover : "transparent"
        border.width: on ? 1 : 0
        border.color: sw.theme.line
        Row {
          id: inner
          anchors.centerIn: parent
          spacing: 6
          Icon {
            theme: sw.theme
            text: modelData[1]
            size: 14
            color: on ? sw.theme.accent : sw.theme.muted
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            textFormat: Text.PlainText
            text: modelData[2]
            font.family: sw.theme.uiFont
            font.pixelSize: 13
            font.weight: on ? Font.DemiBold : Font.Normal
            color: on ? sw.theme.text : sw.theme.muted
            anchors.verticalCenter: parent.verticalCenter
          }
        }
        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: if (!on) sw.picked(modelData[0]) }
      }
    }
  }
}
