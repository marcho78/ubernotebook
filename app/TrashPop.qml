import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// Pages in the trash (with the pages inside them): put one back where it
// was, or throw it out of Pages for good (its file goes to .trash in your
// notebooks folder, so even then it isn't gone).
Pop {
  id: pop

  property var workspace: null

  signal restoreRequested(string id)
  signal deleteRequested(string id)

  width: 380
  height: Math.min(440, Math.max(120, list.contentHeight + 60))
  padding: 10

  readonly property var pages: {
    var r = workspace ? workspace.revision : 0
    return workspace ? Workspace.trashed(workspace.index) : []
  }

  contentItem: Column {
    spacing: 6
    Text {
      textFormat: Text.PlainText
      leftPadding: 6
      text: "Trash"
      font.family: pop.theme.uiFont
      font.pixelSize: 13
      font.weight: Font.DemiBold
      color: pop.theme.text
    }
    ListView {
      id: list
      width: parent.width
      height: pop.height - 2 * pop.padding - 26
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: pop.pages
      delegate: Rectangle {
        required property var modelData
        readonly property var e: pop.workspace.index.pages[modelData] || ({ title: "", icon: "", modified: "" })
        width: list.width
        height: 44
        radius: 7
        color: rowHover.hovered ? pop.theme.hover : "transparent"
        Text {
          id: icon
          textFormat: Text.PlainText
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          text: parent.e.icon || "\u{1f4c4}"
          font.family: "Noto Color Emoji"
          font.pixelSize: 15
        }
        Column {
          x: 36
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - 70
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: parent.parent.e.title || "Untitled"
            font.family: pop.theme.uiFont
            font.pixelSize: 13
            color: pop.theme.text
          }
          Text {
            textFormat: Text.PlainText
            text: "Thrown away " + Qt.formatDate(new Date(parent.parent.e.modified), "d MMM yyyy")
            font.family: pop.theme.uiFont
            font.pixelSize: 11
            color: pop.theme.muted
          }
        }
        Row {
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          IconButton { theme: pop.theme; icon: pop.theme.icons.restore; size: 28; iconSize: 15; tip: "Put it back"; onClicked: pop.restoreRequested(modelData) }
          IconButton { theme: pop.theme; icon: pop.theme.icons.deleteForever; size: 28; iconSize: 15; tint: pop.theme.urgent; tip: "Delete it from Pages"; onClicked: pop.deleteRequested(modelData) }
        }
        HoverHandler { id: rowHover }
      }
      Text {
        textFormat: Text.PlainText
        visible: list.count === 0
        x: 8
        y: 8
        text: "Nothing in the trash."
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.muted
      }
    }
  }
}
