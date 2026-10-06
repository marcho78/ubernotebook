import QtQuick
import QtQuick.Controls

// Every page in the notebook: its number, title, date and tab. Click one to
// turn to it; move pages up and down, or start a new one.
Pop {
  id: pop

  property var view: null

  width: 380
  height: Math.min(560, list.contentHeight + footer.height + fromTemplate.height + 30)
  padding: 8
  focus: false

  onOpened: list.positionViewAtIndex(view.pageIndex, ListView.Center)

  contentItem: Column {
    spacing: 6
    ListView {
      id: list
      width: parent.width
      height: pop.height - footer.height - fromTemplate.height - 30
      clip: true
      model: pop.opened ? pop.view.summaries() : []
      boundsBehavior: Flickable.StopAtBounds
      delegate: Rectangle {
        id: row
        required property var modelData
        required property int index
        width: list.width
        height: 44
        radius: 8
        color: index === pop.view.pageIndex ? pop.theme.accentSoft : rowHover.hovered ? pop.theme.hover : "transparent"

        Text {
          textFormat: Text.PlainText
          id: num
          x: 8
          width: 26
          anchors.verticalCenter: parent.verticalCenter
          horizontalAlignment: Text.AlignRight
          text: row.index + 1
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          font.features: { "tnum": 1 }
          color: pop.theme.muted
        }
        Rectangle {
          x: 42
          width: 4
          height: 26
          radius: 2
          anchors.verticalCenter: parent.verticalCenter
          color: row.modelData.tab ? row.modelData.tab.color : "transparent"
        }
        Column {
          x: 54
          width: parent.width - 54 - 70
          anchors.verticalCenter: parent.verticalCenter
          spacing: 1
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: row.modelData.title || (row.modelData.blank ? "Blank page" : "Untitled")
            elide: Text.ElideRight
            font.family: pop.theme.uiFont
            font.pixelSize: 13
            font.italic: !row.modelData.title
            color: row.modelData.title ? pop.theme.text : pop.theme.muted
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            text: Qt.formatDate(new Date(row.modelData.modified), "d MMM yyyy")
              + (row.modelData.tab && row.modelData.tab.label ? "  \u00b7  " + row.modelData.tab.label : "")
              + (row.modelData.checks ? "  \u00b7  " + row.modelData.done + "/" + row.modelData.checks + " done" : "")
            elide: Text.ElideRight
            font.family: pop.theme.uiFont
            font.pixelSize: 11
            color: pop.theme.faint
          }
        }
        Row {
          anchors.right: parent.right
          anchors.rightMargin: 4
          anchors.verticalCenter: parent.verticalCenter
          visible: rowHover.hovered
          IconButton { theme: pop.theme; icon: pop.theme.icons.up; size: 28; iconSize: 15; tip: "Move up"; active: row.index > 0; onClicked: pop.view.movePage(row.index, row.index - 1) }
          IconButton { theme: pop.theme; icon: pop.theme.icons.down; size: 28; iconSize: 15; tip: "Move down"; active: row.index < pop.view.pageCount - 1; onClicked: pop.view.movePage(row.index, row.index + 1) }
        }
        HoverHandler { id: rowHover }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: {
            pop.close()
            pop.view.turnTo(row.index)
          }
        }
      }
    }
    Row {
      id: footer
      spacing: 4
      MenuRow {
        theme: pop.theme
        icon: pop.theme.icons.plus
        text: "New page after this one"
        hint: "Ctrl+N"
        width: list.width
        onClicked: { pop.close(); pop.view.newPage(pop.view.pageIndex + 1) }
      }
    }
    MenuRow {
      id: fromTemplate
      theme: pop.theme
      icon: pop.theme.icons.templates
      text: "A page from a template\u2026"
      hint: "Ctrl+T"
      width: list.width
      onClicked: { pop.close(); pop.view.openTemplates() }
    }
  }
}
