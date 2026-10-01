import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs

// The "/" menu: every kind of block, found by what's typed after the "/"
// (the editor keeps the keyboard: ↑ ↓ pick, Enter takes it, Esc closes).
Pop {
  id: menu

  property var editor: null

  focus: false
  closePolicy: Popup.CloseOnPressOutside
  width: 330
  height: Math.max(44, Math.min(380, list.contentHeight + 12))
  padding: 6

  onClosed: if (editor && editor.slash) editor.closeSlash()

  // Keeps the one picked in view.
  Connections {
    target: menu.editor
    function onSlashIndexChanged() { list.positionViewAtIndex(menu.editor.slashIndex, ListView.Contain) }
  }

  contentItem: ListView {
    id: list
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: menu.editor ? menu.editor.slashItems : []
    delegate: Column {
      id: entry
      required property var modelData
      required property int index
      readonly property bool picked: menu.editor && menu.editor.slashIndex === index
      readonly property bool newGroup: index === 0 || menu.editor.slashItems[index - 1].group !== modelData.group
      readonly property var swatch: modelData.color !== undefined ? Docs.blockColors(modelData.color, menu.theme.dark) : null
      width: list.width
      Text {
        textFormat: Text.PlainText
        visible: entry.newGroup
        leftPadding: 10
        topPadding: entry.index === 0 ? 4 : 10
        bottomPadding: 4
        text: entry.modelData.group
        font.family: menu.theme.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: menu.theme.muted
      }
      Rectangle {
        width: parent.width
        height: 46
        radius: 7
        color: entry.picked ? menu.theme.hover : "transparent"
        Rectangle {
          x: 6
          anchors.verticalCenter: parent.verticalCenter
          width: 34
          height: 34
          radius: 6
          color: entry.swatch && entry.swatch.background ? entry.swatch.background : menu.theme.surfaceHigh
          border.width: 1
          border.color: menu.theme.line
          Icon {
            visible: !entry.swatch
            anchors.centerIn: parent
            theme: menu.theme
            text: menu.theme.icons[entry.modelData.icon] || menu.theme.icons.text
            size: 17
            color: menu.theme.text
          }
          Text {
            textFormat: Text.PlainText
            visible: !!entry.swatch
            anchors.centerIn: parent
            text: "A"
            font.family: menu.theme.uiFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
            color: entry.swatch && entry.swatch.text ? entry.swatch.text : menu.theme.text
          }
        }
        Column {
          x: 50
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 58
          spacing: 1
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: entry.modelData.label
            font.family: menu.theme.uiFont
            font.pixelSize: 13
            color: menu.theme.text
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: entry.modelData.hint
            font.family: menu.theme.uiFont
            font.pixelSize: 11
            color: menu.theme.muted
          }
        }
        HoverHandler {
          cursorShape: Qt.PointingHandCursor
          onHoveredChanged: if (hovered && menu.editor) menu.editor.slashIndex = entry.index
        }
        TapHandler { onTapped: menu.editor.applySlash(entry.modelData) }
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: list.count === 0
      x: 12
      y: 10
      text: "Nothing like that. Esc to keep the \u201c/\u201d as it is."
      font.family: menu.theme.uiFont
      font.pixelSize: 12
      color: menu.theme.muted
    }
  }
}
