import QtQuick
import QtQuick.Controls
import "../Html.js" as Html

// A link on the selected words (or the word at the cursor): type or paste
// where it goes. Ctrl+click a link on the page to open it.
Pop {
  id: pop

  property var editor: null

  width: 380
  padding: 12

  function openAt(anchor) {
    parent = anchor
    x = (anchor.width - width) / 2
    y = -implicitHeight - 12
    var link = editor ? editor.currentLink() : ""
    var sel = editor ? editor.selectedText() : ""
    field.text = link || (Html.cleanUrl(sel) ? sel : "")
    open()
    field.focusField()
  }

  function apply() {
    var url = field.text.trim()
    close()
    if (!editor) return
    if (url === "") editor.setLink("")
    else editor.setLink(url)
  }

  onClosed: {
    if (!editor) return
    var item = editor.items[editor.focusUid]
    if (item && item.edit) item.edit.forceActiveFocus()
  }

  contentItem: Column {
    spacing: 10
    Field {
      id: field
      theme: pop.theme
      width: parent.width
      icon: pop.theme.icons.link
      placeholder: "https://\u2026"
      maximumLength: 2000
      onAccepted: pop.apply()
      onEscaped: pop.close()
    }
    Row {
      spacing: 6
      layoutDirection: Qt.RightToLeft
      width: parent.width
      Chip { theme: pop.theme; text: "Link"; checked: true; onClicked: pop.apply() }
      Chip { theme: pop.theme; text: "Remove link"; visible: pop.editor && pop.editor.currentLink() !== ""; onClicked: { pop.close(); pop.editor.setLink("") } }
      Text {
        textFormat: Text.PlainText
        visible: field.text.trim() !== "" && Html.cleanUrl(field.text) === ""
        text: "That doesn't look like a web address"
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.urgent
        anchors.verticalCenter: parent.verticalCenter
      }
    }
  }
}
