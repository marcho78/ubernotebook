import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs

// A page's menu (⋯ at the top right): its font, small text, full width;
// copying or exporting it as Markdown, moving it, putting it in the trash.
Pop {
  id: menu

  property var view: null

  focus: false
  width: 270
  padding: 8

  readonly property var format: view ? view.format : ({ width: "normal", size: "normal", font: "sans" })

  contentItem: Column {
    spacing: 4

    Row {
      spacing: 6
      Repeater {
        model: Docs.FONTS
        delegate: Rectangle {
          required property var modelData
          readonly property bool on: menu.format.font === modelData.id
          width: 80
          height: 62
          radius: 8
          color: on ? menu.theme.accentSoft : fontHover.hovered ? menu.theme.hover : "transparent"
          border.width: 1
          border.color: on ? Qt.alpha(menu.theme.accent, 0.7) : menu.theme.line
          Column {
            anchors.centerIn: parent
            Text {
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              text: "Ag"
              font.family: menu.theme.penFamily(modelData.families)
              font.pixelSize: 22
              color: on ? menu.theme.accent : menu.theme.text
            }
            Text {
              textFormat: Text.PlainText
              anchors.horizontalCenter: parent.horizontalCenter
              text: modelData.label
              font.family: menu.theme.uiFont
              font.pixelSize: 11
              color: menu.theme.muted
            }
          }
          HoverHandler { id: fontHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: menu.view.setFormat("font", modelData.id) }
        }
      }
    }
    Rectangle { width: parent.width; height: 1; color: menu.theme.line }

    component Switch: Item {
      id: sw
      property string text: ""
      property bool checked: false
      signal toggled(bool on)
      width: parent ? parent.width : 250
      height: 34
      Text {
        textFormat: Text.PlainText
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        text: sw.text
        font.family: menu.theme.uiFont
        font.pixelSize: 13
        color: menu.theme.text
      }
      Toggle {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        theme: menu.theme
        checked: sw.checked
        onToggled: function(on) { sw.toggled(on) }
      }
    }
    Switch { text: "Small text"; checked: menu.format.size === "small"; onToggled: function(on) { menu.view.setFormat("size", on ? "small" : "normal") } }
    Switch { text: "Full width"; checked: menu.format.width === "full"; onToggled: function(on) { menu.view.setFormat("width", on ? "full" : "normal") } }
    Rectangle { width: parent.width; height: 1; color: menu.theme.line }

    Switch { text: "Lock the page"; checked: menu.format.locked === true; onToggled: function(on) { menu.view.setFormat("locked", on) } }
    Rectangle { width: parent.width; height: 1; color: menu.theme.line }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.view && menu.view.favorite ? menu.theme.icons.star : menu.theme.icons.starOutline; text: menu.view && menu.view.favorite ? "Out of Favorites" : "Add to Favorites"; onClicked: { menu.close(); menu.view.toggleFavorite(menu.view.page.id) } }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.theme.icons.agent; text: "Ask agent about this page"; hint: "Ctrl+J"; onClicked: { menu.close(); menu.view.openAgent("page") } }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.theme.icons.duplicate; text: "Duplicate"; onClicked: { menu.close(); menu.view.duplicatePage(menu.view.page.id) } }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.theme.icons.copy; text: "Copy as Markdown"; onClicked: { menu.close(); menu.view.copyMarkdown() } }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.theme.icons.export; text: "Export with its pages\u2026"; onClicked: { menu.close(); menu.view.exportPage() } }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.theme.icons.move; text: "Move to\u2026"; onClicked: { menu.close(); menu.view.movePageAsk(menu.view.page ? menu.view.page.id : "") } }
    Rectangle { width: parent.width; height: 1; color: menu.theme.line }
    MenuRow { width: parent.width; theme: menu.theme; icon: menu.theme.icons.trash; text: "Move to the trash"; danger: true; onClicked: { menu.close(); menu.view.trashPage(menu.view.page ? menu.view.page.id : "") } }
  }
}
