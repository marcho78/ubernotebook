import QtQuick
import QtQuick.Effects
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// Over words you select in Pages: turn the block into another kind, bold,
// italic, underline, strikethrough, code, a link, and colors. It never takes
// the keyboard (or the selection) from the page.
Item {
  id: bubble

  property var theme: null
  property var editor: null

  // The colors you picked last (for words, as for everything in Pages).
  property var recent: []

  signal linkRequested(Item anchor)
  signal agentRequested()
  // Custom…: a color of your own for the words ("color" or "background").
  signal customColorRequested(string kind)

  // The words' color, if it's one of your own ("" for none, or Pages').
  function ownColor(value) {
    var h = Colors.normalize(value || "")
    return h && Docs.darkMap()[h] === undefined && Docs.lightMap()[h] === undefined ? h : ""
  }

  readonly property var st: editor ? editor.formatState : ({})
  readonly property var words: st && st.inline ? st.inline : ({})

  width: row.implicitWidth + 10
  height: 38

  Rectangle {
    id: plate
    anchors.fill: parent
    radius: 9
    color: bubble.theme.surfaceHigh
    border.width: 1
    border.color: bubble.theme.line
    visible: false
  }
  MultiEffect {
    source: plate
    anchors.fill: plate
    shadowEnabled: true
    shadowColor: bubble.theme.shadow
    shadowBlur: 0.8
    shadowVerticalOffset: 4
    autoPaddingEnabled: true
  }

  Row {
    id: row
    anchors.centerIn: parent
    spacing: 1

    component Sep: Rectangle {
      width: 1
      height: 20
      anchors.verticalCenter: parent ? parent.verticalCenter : undefined
      color: bubble.theme.line
    }

    IconButton {
      theme: bubble.theme
      size: 30
      icon: bubble.theme.icons.agent
      label: "Ask"
      tip: "Ask your agent about these words  Ctrl+J"
      onClicked: bubble.agentRequested()
    }
    Sep {}
    IconButton {
      id: kindButton
      theme: bubble.theme
      size: 30
      label: Docs.kindLabel(bubble.st.type, bubble.st.toggle) + "  \u25be"
      tip: "Turn into"
      onClicked: turnPop.open()
      Pop {
        id: turnPop
        theme: bubble.theme
        focus: false
        y: kindButton.height + 6
        contentItem: Column {
          spacing: 2
          Repeater {
            model: Docs.TURN_INTO
            delegate: MenuRow {
              required property var modelData
              theme: bubble.theme
              icon: bubble.theme.icons[modelData.icon] || ""
              text: modelData.label
              checked: bubble.st.type === modelData.type && !!bubble.st.toggle === !!modelData.toggle
              onClicked: {
                turnPop.close()
                bubble.editor.turnInto([bubble.editor.focusUid], modelData.type, modelData.toggle === true)
              }
            }
          }
        }
      }
    }
    Sep {}
    IconButton { theme: bubble.theme; size: 30; icon: bubble.theme.icons.bold; tip: "Bold  Ctrl+B"; checked: bubble.words.bold === "all"; onClicked: bubble.editor.formatInline("bold") }
    IconButton { theme: bubble.theme; size: 30; icon: bubble.theme.icons.italic; tip: "Italic  Ctrl+I"; checked: bubble.words.italic === "all"; onClicked: bubble.editor.formatInline("italic") }
    IconButton { theme: bubble.theme; size: 30; icon: bubble.theme.icons.underline; tip: "Underline  Ctrl+U"; checked: bubble.words.underline === "all"; onClicked: bubble.editor.formatInline("underline") }
    IconButton { theme: bubble.theme; size: 30; icon: bubble.theme.icons.strike; tip: "Strikethrough  Ctrl+Shift+X"; checked: bubble.words.strike === "all"; onClicked: bubble.editor.formatInline("strike") }
    IconButton { theme: bubble.theme; size: 30; icon: bubble.theme.icons.code; tip: "Code  Ctrl+E"; checked: bubble.words.code === "all"; onClicked: bubble.editor.formatInline("code") }
    Sep {}
    IconButton {
      id: linkButton
      theme: bubble.theme; size: 30; icon: bubble.theme.icons.link; tip: "Link  Ctrl+K"
      checked: !!bubble.words.link
      onClicked: bubble.linkRequested(linkButton)
    }
    IconButton {
      id: colorButton
      theme: bubble.theme; size: 30; icon: bubble.theme.icons.textColor; tip: "Color"
      swatch: bubble.words.color ? bubble.words.color : "transparent"
      onClicked: {
        colorPop.mode = "words"
        colorPop.currentText = bubble.ownColor(bubble.words.color)
        colorPop.currentBack = bubble.ownColor(bubble.words.highlight)
        colorPop.open()
      }
      ColorPop {
        id: colorPop
        theme: bubble.theme
        editor: bubble.editor
        recent: bubble.recent
        onCustomRequested: function(kind) { bubble.customColorRequested(kind) }
        x: colorButton.width - width
        y: colorButton.height + 6
      }
    }
  }
}
