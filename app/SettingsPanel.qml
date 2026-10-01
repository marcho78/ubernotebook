import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// Omanote's settings. They apply as you change them and are kept on
// Omanote's entry in ~/.config/omarchy/shell.json.
Popup {
  id: panel

  property var theme: null
  // The service: settings, setSetting(), the shortcuts' state, the folder.
  property var service: null
  readonly property var s: service ? service.settings : ({})

  anchors.centerIn: Overlay.overlay
  width: Math.min(620, (parent ? parent.width : 620) - 40)
  height: Math.min(680, (parent ? parent.height : 680) - 40)
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, panel.theme && panel.theme.dark ? 0.5 : 0.3) }

  onOpened: {
    toggleField.text = s.shortcut || ""
    quickField.text = s.quickShortcut || ""
    folderField.text = s.folder || ""
  }

  function set(key, value) { if (service) service.setSetting(key, value) }

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 16; color: panel.theme.surface; border.width: 1; border.color: panel.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: panel.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 14; autoPaddingEnabled: true }
  }

  component Heading: Text {
    topPadding: 10
    font.family: panel.theme.uiFont
    font.pixelSize: 11
    font.capitalization: Font.AllUppercase
    font.letterSpacing: 0.8
    color: panel.theme.muted
  }

  component Line: Item {
    id: line
    property string label: ""
    property string note: ""
    default property alias control: slot.data
    width: parent ? parent.width : 400
    height: Math.max(40, texts.implicitHeight + 12)
    Column {
      id: texts
      anchors.left: parent.left
      anchors.right: slot.left
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text { textFormat: Text.PlainText; width: parent.width; text: line.label; wrapMode: Text.WordWrap; font.family: panel.theme.uiFont; font.pixelSize: 14; color: panel.theme.text }
      Text { textFormat: Text.PlainText; visible: line.note !== ""; width: parent.width; text: line.note; wrapMode: Text.WordWrap; font.family: panel.theme.uiFont; font.pixelSize: 12; color: panel.theme.muted }
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  contentItem: Item {
    Text {
      textFormat: Text.PlainText
      x: 26
      y: 20
      text: "Settings"
      font.family: panel.theme.uiFont
      font.pixelSize: 19
      font.weight: Font.DemiBold
      color: panel.theme.text
    }
    IconButton {
      anchors.right: parent.right
      anchors.rightMargin: 14
      y: 14
      theme: panel.theme
      icon: panel.theme.icons.close
      onClicked: panel.close()
    }

    Flickable {
      id: flick
      x: 26
      y: 58
      width: parent.width - 52
      height: parent.height - 70
      contentHeight: body.height + 20
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: body
        width: flick.width
        spacing: 2

        Heading { text: "Shortcuts" }
        Line {
          label: "Open and close Omanote"
          note: panel.service ? panel.service.shortcutNote("toggle") : ""
          Field {
            id: toggleField
            theme: panel.theme
            width: 180
            placeholder: "None"
            onAccepted: panel.set("shortcut", text)
            input.onActiveFocusChanged: if (!input.activeFocus) panel.set("shortcut", text)
          }
        }
        Line {
          label: "Jot a quick note"
          note: panel.service ? panel.service.shortcutNote("quick") : ""
          Field {
            id: quickField
            theme: panel.theme
            width: 180
            placeholder: "None"
            onAccepted: panel.set("quickShortcut", text)
            input.onActiveFocusChanged: if (!input.activeFocus) panel.set("quickShortcut", text)
          }
        }

        Heading { text: "Window" }
        Line {
          label: "Float in the middle of the screen"
          note: "Like a notebook on your desk. Off, it tiles like any other window."
          Toggle { theme: panel.theme; checked: panel.s.floating !== false; onToggled: function(on) { panel.set("floating", on) } }
        }
        Line {
          label: "Size"
          Row {
            spacing: 6
            Repeater {
              model: [{ label: "Small", w: 1100, h: 760 }, { label: "Medium", w: 1320, h: 900 }, { label: "Large", w: 1560, h: 1040 }]
              delegate: Chip {
                required property var modelData
                theme: panel.theme
                text: modelData.label
                checked: panel.s.width === modelData.w && panel.s.height === modelData.h
                onClicked: { panel.set("width", modelData.w); panel.set("height", modelData.h) }
              }
            }
          }
        }
        Line {
          label: "Show Omanote in the top bar"
          note: "Off, the notebook icon takes no space; Omanote stays on."
          Toggle { theme: panel.theme; checked: panel.s.barIcon !== false; onToggled: function(on) { panel.set("barIcon", on) } }
        }

        Heading { text: "Notebooks" }
        Line {
          label: "Folder"
          note: panel.service ? panel.service.rootPath : ""
          Row {
            spacing: 6
            Field {
              id: folderField
              theme: panel.theme
              width: 190
              placeholder: "~/Documents/Omanote"
              onAccepted: panel.set("folder", text)
            }
            IconButton { theme: panel.theme; icon: panel.theme.icons.folder; tip: "Open the folder"; onClicked: panel.service.store.openFolder() }
          }
        }

        Heading { text: "Writing" }
        Line {
          label: "Cross off checked items"
          Toggle { theme: panel.theme; checked: panel.s.strikeDone !== false; onToggled: function(on) { panel.set("strikeDone", on) } }
        }

        Heading { text: "Sound and motion" }
        Line {
          label: "Paper sounds"
          note: "A soft rustle when a page turns and a notebook opens."
          Toggle { theme: panel.theme; checked: panel.s.sounds !== false; onToggled: function(on) { panel.set("sounds", on) } }
        }
        Line {
          label: "Reduce motion"
          note: "Pages and covers fade instead of turning."
          Toggle { theme: panel.theme; checked: panel.s.reduceMotion === true; onToggled: function(on) { panel.set("reduceMotion", on) } }
        }

        Heading { text: "About" }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          topPadding: 4
          text: "Omanote " + (panel.service ? panel.service.version : "") + ". Every notebook is a folder of plain JSON files; pictures are copied in beside them. Nothing leaves your computer."
          wrapMode: Text.WordWrap
          font.family: panel.theme.uiFont
          font.pixelSize: 13
          lineHeight: 1.25
          color: panel.theme.muted
        }
      }
    }
  }
}
