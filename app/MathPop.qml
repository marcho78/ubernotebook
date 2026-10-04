import QtQuick
import "../Equations.js" as Equations

// An equation in a line of text, changed: its LaTeX, and its drawing as
// it's written. Enter (or Done) keeps it, Esc leaves it as it was, Remove
// takes it out of the line.
Pop {
  id: pop

  // The editor: it draws equations (mathOf, mathRevision).
  property var editor: null
  property string tex: ""
  // As it's written, drawn a moment after each change.
  property string shown: ""
  readonly property var drawing: { var r = editor ? editor.mathRevision : 0; return editor && shown ? editor.mathOf(shown, false) : null }
  readonly property var sized: drawing && drawing.svg ? Equations.sized(drawing.svg, 22, String(theme.text)) : null
  readonly property string error: drawing ? (drawing.error || Equations.errorOf(drawing.svg)) : ""

  signal accepted(string tex)
  signal removed()

  width: 420
  padding: 12

  function start(value) {
    tex = Equations.clean(value)
    shown = tex
    field.text = tex
    open()
    field.focusField()
  }
  function done() {
    var t = Equations.clean(field.text)
    close()
    if (t) accepted(t)
    else removed()
  }

  Timer { id: later; interval: 200; onTriggered: pop.shown = Equations.clean(field.text) }

  contentItem: Column {
    spacing: 10

    Field {
      id: field
      objectName: "mathField"
      theme: pop.theme
      width: parent.width
      height: 36
      fontSize: 14
      maximumLength: Equations.MAX_TEX
      placeholder: "LaTeX, like x^2 or \\frac{a}{b}"
      onEdited: later.restart()
      onAccepted: pop.done()
      onEscaped: pop.close()
    }

    // As it's written.
    Item {
      width: parent.width
      height: Math.max(36, preview.height + 12)
      Image {
        id: preview
        objectName: "mathPreview"
        anchors.centerIn: parent
        visible: pop.sized !== null
        source: pop.sized ? "data:image/svg+xml;utf8," + encodeURIComponent(pop.sized.svg) : ""
        sourceSize.width: pop.sized ? Math.round(pop.sized.width) : 0
        sourceSize.height: pop.sized ? Math.round(pop.sized.height) : 0
        width: pop.sized ? Math.min(pop.sized.width, parent.width) : 0
        height: pop.sized ? pop.sized.height * width / Math.max(1, pop.sized.width) : 0
      }
      Text {
        anchors.centerIn: parent
        visible: pop.sized === null
        textFormat: Text.PlainText
        text: pop.shown ? "Drawing\u2026" : "Nothing yet"
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.faint
      }
    }
    Text {
      visible: pop.error !== ""
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: pop.error
      font.family: pop.theme.uiFont
      font.pixelSize: 12
      color: pop.theme.urgent
    }

    Row {
      anchors.right: parent.right
      spacing: 6
      TextButton {
        objectName: "mathRemove"
        theme: pop.theme
        text: "Remove"
        onClicked: { pop.close(); pop.removed() }
      }
      TextButton {
        objectName: "mathDone"
        theme: pop.theme
        text: "Done"
        onClicked: pop.done()
      }
    }
  }
}
