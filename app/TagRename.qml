import QtQuick
import QtQuick.Controls
import "../Tags.js" as Tags

// Renaming a tag everywhere (the tag view's pen): its new name, as it'll be
// written. A name another tag has makes the two one.
Pop {
  id: pop

  property string was: ""
  property var known: []
  signal renamed(string to)

  width: 300
  padding: 12

  readonly property string name: Tags.clean(field.text)
  readonly property bool merges: name !== "" && name !== Tags.clean(was) && known.indexOf(name) >= 0

  function start(label) {
    was = label
    field.text = label
    open()
    field.focusField()
  }

  function take() {
    if (!name) return
    close()
    if (Tags.label(field.text) !== was) renamed(Tags.label(field.text))
  }

  contentItem: Column {
    spacing: 8
    Text {
      textFormat: Text.PlainText
      text: "Rename " + pop.was
      font.family: pop.theme.uiFont
      font.pixelSize: 13
      font.weight: Font.DemiBold
      color: pop.theme.text
    }
    Field {
      id: field
      objectName: "tagName"
      theme: pop.theme
      width: parent.width
      height: 36
      placeholder: "#name"
      onAccepted: pop.take()
      onEscaped: pop.close()
    }
    Text {
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: field.text.trim() && !pop.name ? "Letters, digits, - _ and /, and not only digits."
        : pop.merges ? Tags.label(field.text) + " is a tag already: they'll be one."
        : "On every page with it. Enter renames."
      font.family: pop.theme.uiFont
      font.pixelSize: 11
      color: field.text.trim() && !pop.name ? pop.theme.urgent : pop.theme.muted
    }
  }
}
