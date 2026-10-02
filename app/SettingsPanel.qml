import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Audio.js" as Audio

// Omanote's settings. They apply as you change them and are kept on
// Omanote's entry in ~/.config/omarchy/shell.json.
Popup {
  id: panel

  property var theme: null
  // The service: settings, setSetting(), the shortcuts' state, the folder.
  property var service: null
  readonly property var s: service ? service.settings : ({})
  // The microphone (Recorder.qml), and what its test heard: "" (not tested),
  // "silent", "quiet", "good", "loud", or "failed: why".
  readonly property var recorder: service && service.recorder ? service.recorder : null
  readonly property bool testing: recorder !== null && recorder.busy && recorder.kind === "test"
  property string heard: ""

  anchors.centerIn: Overlay.overlay
  width: Math.min(620, (parent ? parent.width : 620) - 40)
  height: Math.min(680, (parent ? parent.height : 680) - 40)
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, panel.theme && panel.theme.dark ? 0.5 : 0.3) }

  onClosed: if (testing) recorder.cancel()
  onOpened: {
    heard = ""
    if (recorder) recorder.listSources()
    toggleField.text = s.shortcut || ""
    quickField.text = s.quickShortcut || ""
    folderField.text = s.folder || ""
    mirrorField.text = s.mirrorFolder || ""
  }

  function set(key, value) { if (service) service.setSetting(key, value) }

  // A few seconds of the microphone, its level shown, then how it sounded.
  function testMicrophone() {
    if (!recorder) return
    if (testing) { recorder.stop(); return }
    heard = ""
    var problem = recorder.start("test", "settings", "", function(ok, r) {
      panel.heard = ok ? Audio.verdict(r.levels) : "failed: " + (r.problem || "the microphone couldn't be opened")
    })
    if (problem) heard = "failed: " + problem
  }
  readonly property string heardNote: heard === "silent" ? "Nothing heard. Is the right microphone picked, and is it on?"
    : heard === "quiet" ? (s.audioBoost !== false ? "Quiet, even made louder: speak up, or come closer." : "Quiet. Turn on Make my voice louder, or come closer.")
    : heard === "good" ? "Sounds good."
    : heard === "loud" ? "Loud: it may distort. Move back a little."
    : heard.indexOf("failed: ") === 0 ? heard.slice(8)
    : testing ? "Say a few words\u2026"
    : "Say a few words: the bars show how loud you come through" + (s.audioBoost !== false ? ", made louder." : ".")
  readonly property string micLabel: {
    var name = s.audioInput || ""
    if (!name) return "The default one"
    var list = recorder ? recorder.sources : []
    for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i].label
    return name
  }

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
        Line {
          label: "Quick notes go to"
          note: panel.s.quickTo === "pages" ? "A page in your Pages Inbox: the first line is its title, the rest Markdown." : "A page in the Quick notes notebook."
          Row {
            spacing: 6
            Repeater {
              model: [{ label: "Quick notes", value: "notebook" }, { label: "Pages Inbox", value: "pages" }]
              delegate: Chip {
                required property var modelData
                theme: panel.theme
                text: modelData.label
                checked: (panel.s.quickTo || "notebook") === modelData.value
                onClicked: panel.set("quickTo", modelData.value)
              }
            }
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
        Line {
          label: "Exports"
          note: panel.s.exportTo === "folder" ? (panel.service ? panel.service.rootPath + "/Exports" : "The Exports folder") : "A folder picker asks where, each time."
          Row {
            spacing: 6
            Repeater {
              model: [{ label: "Ask where", value: "ask" }, { label: "Exports folder", value: "folder" }]
              delegate: Chip {
                required property var modelData
                theme: panel.theme
                text: modelData.label
                checked: (panel.s.exportTo || "ask") === modelData.value
                onClicked: panel.set("exportTo", modelData.value)
              }
            }
          }
        }

        Line {
          label: "Markdown copy"
          note: panel.s.mirror === true && panel.service
            ? panel.service.mirror.status + (panel.service.mirror.status === "Up to date" && panel.service.mirror.lastSync
              ? " \u00b7 " + panel.service.mirror.files + " files \u00b7 " + Qt.formatTime(panel.service.mirror.lastSync, "HH:mm") : "")
            : "A Markdown file of every page, kept up to date in a folder, for Obsidian, git or any editor."
          Toggle { theme: panel.theme; checked: panel.s.mirror === true; onToggled: function(on) { panel.set("mirror", on) } }
        }
        Line {
          visible: panel.s.mirror === true
          label: "Copy to"
          note: panel.service ? panel.service.mirrorPath : ""
          Row {
            spacing: 6
            Field {
              id: mirrorField
              theme: panel.theme
              width: 190
              placeholder: "Default (Markdown)"
              onAccepted: panel.set("mirrorFolder", text)
              input.onActiveFocusChanged: if (!input.activeFocus) panel.set("mirrorFolder", text)
            }
            IconButton { theme: panel.theme; icon: panel.theme.icons.folder; tip: "Open the copy"; onClicked: panel.service.openMirror() }
          }
        }

        Heading { text: "Writing" }
        Line {
          label: "Cross off checked items"
          Toggle { theme: panel.theme; checked: panel.s.strikeDone !== false; onToggled: function(on) { panel.set("strikeDone", on) } }
        }


        Heading { text: "Audio" }
        Line {
          label: "Microphone"
          note: "What audio notes and dictation record from."
          Rectangle {
            id: micButton
            objectName: "micPicker"
            width: Math.min(230, micText.implicitWidth + 40)
            height: 32
            radius: 8
            color: micHover.hovered ? panel.theme.hover : "transparent"
            border.width: 1
            border.color: panel.theme.line
            Text {
              id: micText
              x: 12
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - 36
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: panel.micLabel
              font.family: panel.theme.uiFont
              font.pixelSize: 13
              color: panel.theme.text
            }
            Icon {
              theme: panel.theme
              anchors.right: parent.right
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              text: panel.theme.icons.down
              size: 14
              color: panel.theme.muted
            }
            HoverHandler { id: micHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: { if (panel.recorder) panel.recorder.listSources(); micMenu.open() } }
            Pop {
              id: micMenu
              theme: panel.theme
              width: 300
              y: micButton.height + 6
              x: micButton.width - width
              contentItem: Column {
                spacing: 2
                Repeater {
                  model: [{ name: "", label: "The default one" }].concat(panel.recorder ? panel.recorder.sources : [])
                  delegate: MenuRow {
                    required property var modelData
                    objectName: "micChoice"
                    width: parent.width
                    theme: panel.theme
                    icon: panel.theme.icons.mic
                    text: modelData.label
                    checked: (panel.s.audioInput || "") === modelData.name
                    onClicked: { micMenu.close(); panel.set("audioInput", modelData.name); panel.heard = "" }
                  }
                }
              }
            }
          }
        }
        Line {
          label: "Make my voice louder"
          note: "Evens out your voice once it's recorded, so a quiet microphone (a laptop's) comes out loud and clear without turning up the hiss. Dictation too."
          Toggle { theme: panel.theme; checked: panel.s.audioBoost !== false; onToggled: function(on) { panel.set("audioBoost", on); panel.heard = "" } }
        }
        Line {
          label: "Test the microphone"
          note: panel.heardNote
          Row {
            spacing: 10
            // The level as you speak, the newest at the right.
            Item {
              anchors.verticalCenter: parent.verticalCenter
              width: 30 * 4
              height: 24
              Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Repeater {
                  model: panel.testing && panel.recorder ? panel.recorder.recent.slice(-30) : []
                  delegate: Rectangle {
                    required property var modelData
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    width: 3
                    height: Math.max(3, 24 * modelData)
                    radius: 1.5
                    color: modelData > 0.97 ? "#e5484d" : panel.theme.accent
                  }
                }
              }
              Rectangle {
                visible: !panel.testing
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 2
                radius: 1
                color: panel.theme.line
              }
            }
            Chip {
              objectName: "micTest"
              anchors.verticalCenter: parent.verticalCenter
              theme: panel.theme
              icon: panel.testing ? panel.theme.icons.stop : panel.theme.icons.mic
              text: panel.testing ? "Stop" : "Test"
              checked: panel.testing
              onClicked: panel.testMicrophone()
            }
          }
        }
        Line {
          label: "Write out audio notes"
          note: panel.recorder && panel.recorder.checked && !panel.recorder.canTranscribe
            ? "Needs voxtype, Omarchy's dictation (omarchy voxtype install). Audio notes still record and play without it."
            : "What you say in an audio note, written out under it by voxtype as soon as it's recorded. Ctrl+Shift+D dictates into a page."
          Toggle { theme: panel.theme; checked: panel.s.audioTranscribe !== false; onToggled: function(on) { panel.set("audioTranscribe", on) } }
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
