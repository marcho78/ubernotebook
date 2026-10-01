import QtQuick
import QtQuick.Effects

// The quick note: a sticky note that pops up wherever you are. Write, then
// Ctrl+Enter (or Esc) keeps it as a page in the Quick notes notebook, its
// first line as the title; "- " lines become a list and "[] " lines
// checkboxes. Only the ✕ throws it away, so nothing is lost by a stray Esc.
Item {
  id: note

  property var theme: null

  signal kept(string text)
  signal thrownAway()

  function start(text) {
    edit.text = text || ""
    edit.cursorPosition = edit.length
    edit.forceActiveFocus()
    pop.restart()
  }

  function keep() {
    var text = edit.text.trim()
    if (text) kept(text)
    else thrownAway()
  }

  SequentialAnimation {
    id: pop
    NumberAnimation { target: sticky; property: "scale"; from: 0.92; to: 1.0; duration: 220; easing.type: Easing.OutBack }
  }

  Rectangle {
    id: stickyShape
    anchors.fill: sticky
    color: "black"
    visible: false
    rotation: sticky.rotation
  }
  MultiEffect {
    source: stickyShape
    anchors.fill: stickyShape
    rotation: sticky.rotation
    shadowEnabled: true
    shadowColor: Qt.rgba(0, 0, 0, 0.45)
    shadowBlur: 1.0
    shadowVerticalOffset: 10
    shadowHorizontalOffset: 2
    autoPaddingEnabled: true
  }

  Rectangle {
    id: sticky
    anchors.centerIn: parent
    width: parent.width - 70
    height: parent.height - 70
    rotation: -1.4
    antialiasing: true
    gradient: Gradient {
      GradientStop { position: 0.0; color: "#fff49c" }
      GradientStop { position: 0.12; color: "#fff5a8" }
      GradientStop { position: 1.0; color: "#fbe983" }
    }

    // The sticky strip at the top, a shade darker.
    Rectangle {
      width: parent.width
      height: 30
      color: Qt.rgba(0.85, 0.72, 0.1, 0.12)
    }

    Text {
      textFormat: Text.PlainText
      x: 22
      y: 7
      text: "Quick note"
      font.family: note.theme ? note.theme.markerFont : "sans-serif"
      font.pixelSize: 15
      color: "#7a6a1e"
    }

    IconButton {
      anchors.right: parent.right
      anchors.rightMargin: 6
      y: 2
      size: 28
      iconSize: 15
      theme: note.theme
      tint: "#7a6a1e"
      icon: note.theme ? note.theme.icons.close : ""
      tip: "Throw it away"
      onClicked: note.thrownAway()
    }

    Flickable {
      id: flick
      x: 22
      y: 42
      width: parent.width - 44
      height: parent.height - 84
      contentHeight: edit.contentHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      TextEdit {
        id: edit
        width: flick.width
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        font.family: note.theme ? note.theme.handFont : "sans-serif"
        font.pixelSize: 27
        color: "#262314"
        selectionColor: "#e8cf4f"
        selectedTextColor: "#262314"
        selectByMouse: true
        onCursorRectangleChanged: {
          var r = cursorRectangle
          if (r.y < flick.contentY) flick.contentY = r.y
          else if (r.y + r.height > flick.contentY + flick.height) flick.contentY = r.y + r.height - flick.height
        }
        Keys.onPressed: function(e) {
          var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
          if ((ctrl && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_S)) || e.key === Qt.Key_Escape) {
            e.accepted = true
            note.keep()
          }
        }

        Text {
          textFormat: Text.PlainText
          visible: edit.text === "" && !edit.inputMethodComposing
          text: "What's on your mind?"
          font: edit.font
          color: Qt.rgba(0.15, 0.14, 0.08, 0.35)
        }
      }
    }

    Text {
      textFormat: Text.PlainText
      anchors.left: parent.left
      anchors.leftMargin: 22
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 12
      text: "Ctrl+Enter keeps it in Quick notes"
      font.family: note.theme ? note.theme.uiFont : "sans-serif"
      font.pixelSize: 11
      color: "#8a7a2e"
    }
  }
}
