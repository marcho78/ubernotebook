import QtQuick
import "../Notes.js" as Notes

// A footnote, written or changed: its words. Enter (or Done) keeps them,
// Esc leaves it as it was, Remove takes it out of the line.
Pop {
  id: pop

  // Its number on the page (0: a new one).
  property int number: 0

  signal accepted(string words)
  signal removed()

  width: 420
  padding: 12

  function start(words, n) {
    number = n || 0
    field.text = Notes.clean(words)
    open()
    field.focusField()
  }
  function done() {
    var t = Notes.clean(field.text)
    close()
    if (t) accepted(t)
    else removed()
  }

  contentItem: Column {
    spacing: 10

    Text {
      textFormat: Text.PlainText
      text: pop.number > 0 ? "Footnote " + pop.number : "A footnote"
      font.family: pop.theme.uiFont
      font.pixelSize: 12
      font.weight: Font.DemiBold
      color: pop.theme.muted
    }
    Field {
      id: field
      objectName: "noteField"
      theme: pop.theme
      width: parent.width
      height: 36
      fontSize: 14
      maximumLength: Notes.MAX_NOTE
      placeholder: "Where it's from, or a word more about it"
      onAccepted: pop.done()
      onEscaped: pop.close()
    }
    Row {
      anchors.right: parent.right
      spacing: 6
      TextButton {
        objectName: "noteRemove"
        visible: pop.number > 0
        theme: pop.theme
        text: "Remove"
        onClicked: { pop.close(); pop.removed() }
      }
      TextButton {
        objectName: "noteDone"
        theme: pop.theme
        text: "Done"
        onClicked: pop.done()
      }
    }
  }
}
