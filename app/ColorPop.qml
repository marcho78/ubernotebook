import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs

// Colors in Pages: for text, or behind it. On the words selected ("words"),
// or on whole blocks ("blocks": their text, or their background).
Pop {
  id: pop

  property var editor: null
  property string mode: "words"
  property var uids: []

  focus: false
  width: 5 * 38 + 4 * 4 + 2 * padding
  padding: 12

  function pickText(c) {
    close()
    if (mode === "blocks") editor.setBlockColor(uids, c ? c.id : "")
    else editor.formatInline("color", c ? c.text[0] : "")
  }

  function pickBackground(c) {
    close()
    if (mode === "blocks") editor.setBlockColor(uids, c ? c.id + "_background" : "")
    else editor.formatInline("highlight", c ? c.background[0] : "")
  }

  component Heading: Text {
    textFormat: Text.PlainText
    font.family: pop.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    color: pop.theme.muted
  }

  component Tile: Rectangle {
    id: tile
    property var entry: null
    property bool back: false
    signal picked()
    readonly property string fg: entry ? entry.text[pop.theme.dark ? 1 : 0] : pop.theme.text
    readonly property string bg: entry ? entry.background[pop.theme.dark ? 1 : 0] : "transparent"
    width: 38
    height: 38
    radius: 7
    color: tileHover.hovered ? pop.theme.hover : "transparent"
    Rectangle {
      anchors.centerIn: parent
      width: 26
      height: 26
      radius: 5
      color: tile.back ? tile.bg : "transparent"
      border.width: 1
      border.color: pop.theme.line
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "A"
        font.family: pop.theme.uiFont
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: tile.back ? pop.theme.text : tile.fg
      }
    }
    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.picked() }
    ToolTip.visible: tileHover.hovered
    ToolTip.delay: 500
    ToolTip.text: (entry ? entry.label : "Default") + (back ? " background" : "")
  }

  contentItem: Column {
    spacing: 8
    Heading { text: pop.mode === "words" ? "Text color" : "Color" }
    Flow {
      width: parent.width
      spacing: 4
      Tile { entry: null; onPicked: pop.pickText(null) }
      Repeater {
        model: Docs.COLORS
        delegate: Tile {
          required property var modelData
          entry: modelData
          onPicked: pop.pickText(modelData)
        }
      }
    }
    Heading { text: "Background" }
    Flow {
      width: parent.width
      spacing: 4
      Tile { entry: null; back: true; onPicked: pop.pickBackground(null) }
      Repeater {
        model: Docs.COLORS
        delegate: Tile {
          required property var modelData
          entry: modelData
          back: true
          onPicked: pop.pickBackground(modelData)
        }
      }
    }
  }
}
