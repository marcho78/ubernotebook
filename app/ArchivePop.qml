import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// The archive (the sidebar's foot): pages put away, with the pages inside
// them, the last changed first. A click opens one (it stays in the archive);
// its arrow brings it back into the tree, where it was.
Pop {
  id: pop

  property var workspace: null

  signal openRequested(string id)
  signal unarchiveRequested(string id)

  width: 380
  height: Math.min(440, Math.max(120, list.contentHeight + 60))
  padding: 10

  readonly property var pages: {
    var r = workspace ? workspace.revision : 0
    return workspace ? Workspace.archived(workspace.index) : []
  }

  contentItem: Column {
    spacing: 6
    Text {
      textFormat: Text.PlainText
      leftPadding: 6
      text: "Archive"
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
        id: row
        required property var modelData
        readonly property var e: pop.workspace.index.pages[modelData] || ({ title: "", icon: "", modified: "", project: null })
        readonly property int inside: { var r = pop.workspace.revision; return Workspace.withDescendants(pop.workspace.index, modelData).length - 1 }
        objectName: "archivedRow"
        width: list.width
        height: 44
        radius: 7
        color: rowHover.hovered ? pop.theme.hover : "transparent"
        Text {
          textFormat: Text.PlainText
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          text: row.e.icon || "\u{1f4c4}"
          font.family: "Noto Color Emoji"
          font.pixelSize: 15
        }
        Column {
          x: 36
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - 44
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: row.e.title || "Untitled"
            font.family: pop.theme.uiFont
            font.pixelSize: 13
            color: pop.theme.text
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: (row.e.project ? Workspace.statusOf(row.e.project.status).label + " project  \u00b7  " : "")
              + (row.inside > 0 ? row.inside + (row.inside === 1 ? " page" : " pages") + " in it  \u00b7  " : "")
              + "edited " + Qt.formatDate(new Date(row.e.modified), "d MMM yyyy")
            font.family: pop.theme.uiFont
            font.pixelSize: 11
            color: pop.theme.muted
          }
        }
        IconButton {
          id: back
          objectName: "unarchive"
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          theme: pop.theme; icon: pop.theme.icons.unarchive; size: 28; iconSize: 15; tip: "Bring it back"
          onClicked: pop.unarchiveRequested(row.modelData)
        }
        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: function(point) {
            var p = back.mapFromItem(row, point.position.x, point.position.y)
            if (back.contains(p)) return
            var id = row.modelData
            pop.close()
            pop.openRequested(id)
          }
        }
      }
      Text {
        textFormat: Text.PlainText
        visible: list.count === 0
        x: 8
        y: 8
        width: list.width - 16
        wrapMode: Text.Wrap
        text: "Nothing in the archive. A page's \u22ef menu puts it here (a project that's done, a page you're finished with): out of the way, still there to find."
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.muted
      }
    }
  }
}
