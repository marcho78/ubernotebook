import QtQuick
import QtQuick.Controls
import "../Tags.js" as Tags

// The "@" menu (dates, and reminders then), the "[[" menu (pages, and a
// new page with the name typed), the ":" menu (emoji by name) and the "#"
// menu (tags, and a new tag with the name typed). The
// editor keeps the keyboard: ↑ ↓ pick, Enter takes it, Esc closes.
Pop {
  id: menu

  property var editor: null

  focus: false
  closePolicy: Popup.CloseOnPressOutside
  readonly property string kind: editor && editor.mention ? editor.mention.kind : ""

  width: kind === "emoji" || kind === "tag" ? 280 : 340
  height: Math.max(44, Math.min(340, list.contentHeight + 12))
  padding: 6

  onClosed: if (editor && editor.mention) editor.closeMention()

  Connections {
    target: menu.editor
    function onMentionIndexChanged() { list.positionViewAtIndex(menu.editor.mentionIndex, ListView.Contain) }
  }

  contentItem: ListView {
    id: list
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: menu.editor ? menu.editor.mentionItems : []
    header: Text {
      textFormat: Text.PlainText
      leftPadding: 10
      topPadding: 4
      bottomPadding: 6
      text: menu.kind === "page" ? "Link to a page" : menu.kind === "emoji" ? "Emoji" : menu.kind === "tag" ? "Tags" : "A date, or a reminder"
      font.family: menu.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      color: menu.theme.muted
    }
    delegate: Rectangle {
      id: entry
      required property var modelData
      required property int index
      readonly property bool picked: menu.editor && menu.editor.mentionIndex === index
      width: list.width
      height: modelData.hint ? 44 : 34
      radius: 7
      color: picked ? menu.theme.hover : "transparent"
      // A tag: "#" in its colors.
      Rectangle {
        visible: entry.modelData.kind === "tag"
        x: 9
        anchors.verticalCenter: parent.verticalCenter
        width: 24
        height: 22
        radius: 6
        readonly property var look: menu.editor && entry.modelData.kind === "tag" ? (menu.editor.tagStyle(Tags.href(entry.modelData.name)) || { color: String(menu.theme.muted), background: "transparent" }) : ({ color: "black", background: "transparent" })
        color: look.background
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "#"
          font.family: menu.theme.uiFont
          font.pixelSize: 14
          font.weight: Font.Bold
          color: parent.look.color
        }
      }
      Text {
        id: glyph
        visible: entry.modelData.kind !== "tag"
        textFormat: Text.PlainText
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        horizontalAlignment: Text.AlignHCenter
        readonly property bool tag: entry.modelData.kind === "tag" || entry.modelData.kind === "tagnew"
        text: entry.modelData.kind === "page" ? (entry.modelData.icon || "\u{1f4c4}")
          : entry.modelData.kind === "emoji" ? entry.modelData.emoji
          : entry.modelData.kind === "create" || entry.modelData.kind === "tagnew" ? (tag ? "+" : "\u2795")
          : tag ? "#"
          : entry.modelData.remind ? "\u23f0" : "\u{1f4c5}"
        font.family: tag ? menu.theme.uiFont : "Noto Color Emoji"
        font.weight: tag ? Font.DemiBold : Font.Normal
        color: menu.theme.muted
        font.pixelSize: entry.modelData.kind === "emoji" ? 17 : 15
      }
      Column {
        x: 40
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 48
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
          visible: !!entry.modelData.hint
          width: parent.width
          elide: Text.ElideRight
          text: entry.modelData.hint || ""
          font.family: menu.theme.uiFont
          font.pixelSize: 11
          color: menu.theme.muted
        }
      }
      HoverHandler {
        cursorShape: Qt.PointingHandCursor
        onHoveredChanged: if (hovered && menu.editor) menu.editor.mentionIndex = entry.index
      }
      TapHandler { onTapped: menu.editor.applyMention(entry.modelData) }
    }

    Text {
      textFormat: Text.PlainText
      visible: list.count === 0
      x: 12
      y: 30
      text: menu.kind === "date"
        ? "Try \u201ctomorrow 9am\u201d, \u201cfri\u201d, \u201cin 2 hours\u201d, \u201coct 3\u201d"
        : menu.kind === "tag" ? "Type a tag: #idea, #project/omanote"
        : "No page is called that."
      font.family: menu.theme.uiFont
      font.pixelSize: 12
      color: menu.theme.muted
    }
  }
}
