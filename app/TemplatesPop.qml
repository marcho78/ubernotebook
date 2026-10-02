import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// Your templates (the sidebar's foot): each a page, kept apart. A click
// opens one, to change it like any page; its + makes a new page from it.
// New template makes an empty one; a page's ⋯ menu saves one from a page.
Pop {
  id: pop

  property var workspace: null

  signal openRequested(string id)
  signal useRequested(string id)
  signal newRequested()

  width: 380
  height: Math.min(460, Math.max(150, list.contentHeight + 104))
  padding: 10

  readonly property var list_: {
    var r = workspace ? workspace.revision : 0
    return workspace ? Workspace.templates(workspace.index) : []
  }

  contentItem: Column {
    spacing: 6
    Item {
      width: parent.width
      height: 28
      Text {
        textFormat: Text.PlainText
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        text: "Templates"
        font.family: pop.theme.uiFont
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: pop.theme.text
      }
      IconButton {
        objectName: "newTemplate"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: pop.theme; icon: pop.theme.icons.plus; label: "New template"; size: 28; iconSize: 14
        onClicked: { pop.close(); pop.newRequested() }
      }
    }
    ListView {
      id: list
      width: parent.width
      height: pop.height - 2 * pop.padding - 34 - hint.height - 12
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: pop.list_
      delegate: Rectangle {
        id: row
        required property var modelData
        readonly property int inside: { var r = pop.workspace.revision; return Workspace.withDescendants(pop.workspace.index, modelData.id).length - 1 }
        objectName: "templateRow"
        width: list.width
        height: 44
        radius: 7
        color: rowHover.hovered ? pop.theme.hover : "transparent"
        Text {
          textFormat: Text.PlainText
          x: 8
          anchors.verticalCenter: parent.verticalCenter
          text: row.modelData.icon || "\u{1f4c4}"
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
            text: row.modelData.title
            font.family: pop.theme.uiFont
            font.pixelSize: 13
            color: pop.theme.text
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: (row.inside > 0 ? row.inside + (row.inside === 1 ? " page" : " pages") + " in it  \u00b7  " : "") + "click to change it"
            font.family: pop.theme.uiFont
            font.pixelSize: 11
            color: pop.theme.muted
          }
        }
        IconButton {
          id: use
          objectName: "useTemplate"
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          theme: pop.theme; icon: pop.theme.icons.newPage; size: 28; iconSize: 15; tip: "A new page from it"
          onClicked: { var id = row.modelData.id; pop.close(); pop.useRequested(id) }
        }
        HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: function(point) {
            var p = use.mapFromItem(row, point.position.x, point.position.y)
            if (use.contains(p)) return
            var id = row.modelData.id
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
        text: "No templates yet. Make a page the way you want new ones to start, then Save as template in its \u22ef menu; or New template."
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.muted
      }
    }
    Text {
      id: hint
      textFormat: Text.PlainText
      x: 6
      width: parent.width - 12
      wrapMode: Text.Wrap
      text: "In a template, {{date}}, {{weekday}}, {{time}} and {{month}} are filled in when it's used."
      font.family: pop.theme.uiFont
      font.pixelSize: 11
      color: pop.theme.faint
    }
  }
}
