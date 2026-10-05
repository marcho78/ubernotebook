import QtQuick
import "../Agent.js" as Agent

// The agents that work right here, in a panel on the page (Agent.HERE):
// Claude, Grok and Codex, side by side, each with who makes it; yours
// picked; one that isn't installed, greyed and said. `agents`: those
// installed ([{ name, label }], Omarchy's list); `agent`: yours. The others
// (they open in a terminal) are shown by what this is in (others()).
Row {
  id: tiles

  property var theme: null
  property var agents: []
  property string agent: ""
  // A name for each tile, for tests: namePrefix + its agent.
  property string namePrefix: "agentTile_"
  signal picked(string name)

  readonly property var here: ["claude", "grok", "codex"]
  readonly property var makers: ({ claude: "Anthropic", grok: "xAI", codex: "OpenAI" })
  function installed(name) { return (agents || []).some(function(a) { return a.name === name }) }
  function labelOf(name) {
    var a = (agents || []).filter(function(x) { return x.name === name })[0]
    return a ? a.label : Agent.name(name)
  }
  // The agents installed that open in a terminal, in Omarchy's order.
  function others() { return (agents || []).filter(function(a) { return tiles.here.indexOf(a.name) < 0 }) }

  spacing: 6

  Repeater {
    model: tiles.here
    delegate: Rectangle {
      id: tile
      required property string modelData
      objectName: tiles.namePrefix + modelData
      readonly property bool there: tiles.installed(modelData)
      readonly property bool checked: tiles.agent === modelData
      width: Math.max(96, Math.floor((tiles.width - tiles.spacing * 2) / 3))
      height: 62
      radius: 10
      color: checked ? tiles.theme.accentSoft : hover.hovered && there ? tiles.theme.hover : "transparent"
      border.width: 1
      border.color: checked ? Qt.alpha(tiles.theme.accent, 0.7) : tiles.theme.line
      opacity: there ? 1 : 0.5
      Behavior on color { ColorAnimation { duration: 90 } }

      Column {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        Row {
          spacing: 5
          Icon {
            visible: tile.checked
            theme: tiles.theme
            text: tiles.theme.icons.check
            size: 12
            color: tiles.theme.accent
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            textFormat: Text.PlainText
            text: tiles.labelOf(tile.modelData)
            font.family: tiles.theme.uiFont
            font.pixelSize: 13
            font.weight: Font.DemiBold
            color: tile.checked ? tiles.theme.accent : tiles.theme.text
          }
        }
        Text {
          textFormat: Text.PlainText
          text: tiles.makers[tile.modelData] || ""
          font.family: tiles.theme.uiFont
          font.pixelSize: 11
          color: tiles.theme.muted
        }
        Text {
          objectName: "agentTileStatus"
          textFormat: Text.PlainText
          text: tile.there ? "Works here" : "Not installed"
          font.family: tiles.theme.uiFont
          font.pixelSize: 11
          color: tiles.theme.faint
        }
      }

      HoverHandler { id: hover; cursorShape: tile.there ? Qt.PointingHandCursor : Qt.ArrowCursor }
      // (Taken by it alone, even when it isn't installed: nothing under it,
      // in a menu, is clicked instead.)
      TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: if (tile.there) tiles.picked(tile.modelData)
      }
    }
  }
}
