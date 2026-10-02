import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// The quick note: a sticky note that pops up wherever you are. Write, then
// Ctrl+Enter (or Esc) keeps it as a page in the Quick notes notebook, or in
// the Pages Inbox (Settings, or the note's own "keeps it in" at its foot),
// its first line as the title; "- " lines become a list and "[] " lines
// checkboxes (in Pages, the rest is Markdown too). Only the ✕ throws it
// away, so nothing is lost by a stray Esc.
Item {
  id: note

  property var theme: null
  // Where it goes: "notebook" (Quick notes) or "pages" (the Pages Inbox).
  property string destination: "notebook"
  readonly property bool toPages: destination === "pages"

  signal kept(string text)
  signal thrownAway()
  // The other place picked, from the note's foot (kept as the setting).
  signal destinationPicked(string to)

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

    // Where it goes, which a click changes.
    Row {
      id: foot
      anchors.left: parent.left
      anchors.leftMargin: 22
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 9
      spacing: 6
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Ctrl+Enter keeps it in"
        font.family: note.theme ? note.theme.uiFont : "sans-serif"
        font.pixelSize: 11
        color: "#8a7a2e"
      }
      Rectangle {
        id: where
        objectName: "destination"
        anchors.verticalCenter: parent.verticalCenter
        width: whereRow.implicitWidth + 16
        height: 22
        radius: 11
        color: whereHover.hovered ? Qt.rgba(0.55, 0.45, 0.05, 0.22) : Qt.rgba(0.55, 0.45, 0.05, 0.12)
        Row {
          id: whereRow
          anchors.centerIn: parent
          spacing: 5
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: note.theme ? (note.toPages ? note.theme.icons.pages : note.theme.icons.notebook) : ""
            font.family: note.theme ? note.theme.iconFont : "monospace"
            font.pixelSize: 12
            color: "#6e5f1a"
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: note.toPages ? "your Pages Inbox" : "Quick notes"
            font.family: note.theme ? note.theme.uiFont : "sans-serif"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: "#6e5f1a"
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: note.theme ? note.theme.icons.swap : ""
            font.family: note.theme ? note.theme.iconFont : "monospace"
            font.pixelSize: 11
            color: "#8a7a2e"
          }
        }
        HoverHandler { id: whereHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          onTapped: {
            note.destinationPicked(note.toPages ? "notebook" : "pages")
            edit.forceActiveFocus()
          }
        }
        ToolTip.visible: whereHover.hovered
        ToolTip.delay: 500
        ToolTip.text: note.toPages ? "Keep quick notes in the Quick notes notebook instead" : "Keep quick notes in your Pages Inbox instead (Markdown works there)"
      }
    }
    Text {
      visible: note.toPages
      anchors.right: parent.right
      anchors.rightMargin: 18
      anchors.verticalCenter: foot.verticalCenter
      textFormat: Text.PlainText
      text: "Markdown works"
      font.family: note.theme ? note.theme.uiFont : "sans-serif"
      font.pixelSize: 11
      color: "#a2924a"
    }
  }
}
