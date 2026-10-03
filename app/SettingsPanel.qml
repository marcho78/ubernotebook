import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Audio.js" as Audio
import "../Colors.js" as Colors

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
  // voxtype's meeting mode (Meetings.qml).
  readonly property var meetings: service && service.meetings ? service.meetings : null
  // Profiles (Profiles.qml): notes kept apart, each in a folder of its own.
  readonly property var profiles: service && service.profiles ? service.profiles : null
  property bool addingProfile: false

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
    addingProfile = false
    mirrorField.text = s.mirrorFolder || ""
  }

  function set(key, value) { if (service) service.setSetting(key, value) }

  // ---- appearance ----

  // The colors of your own over the theme's: which setting, what it's
  // called, what it colors, and the theme's color it stands in for.
  readonly property var colorRoles: [
    { key: "colorSidebar", label: "Sidebar", note: "Behind the list of pages", role: "sidebar", kind: "background" },
    { key: "colorPage", label: "Page background", note: "Behind your pages, the calendar, People and the Library", role: "background", kind: "background" },
    { key: "colorCards", label: "Sections and cards", note: "The sidebar's sections as cards (Projects, Pages, Tags\u2026), and cards and menus", role: "surface", kind: "background" },
    { key: "colorText", label: "Text", note: "All the text; the dimmer text follows it", role: "text", kind: "color" }
  ]
  function hexOf(c) { return Colors.normalize(String(c)) || "#000000" }
  // How well the text reads on a color (and the text, on the page).
  function contrastOf(r) {
    return r.kind === "color" ? Colors.contrast(hexOf(theme.text), hexOf(theme.background)) : Colors.contrast(hexOf(theme.text), hexOf(theme[r.role]))
  }
  readonly property bool anyColor: !!(s.colorSidebar || s.colorPage || s.colorCards || s.colorText)
  property var picking: null
  property string pickedBefore: ""
  function pickColor(r, anchor) {
    picking = r
    pickedBefore = s[r.key] || ""
    var fill = r.kind === "color" ? hexOf(theme.background) : hexOf(theme[r.role])
    colorPicker.recent = String(s.recentColors || "").split(",").filter(function(c) { return /^#[0-9a-f]{6}$/i.test(c) })
    colorPicker.start(r.kind, r.kind === "color" ? hexOf(theme.text) : fill, { text: "Sample text", fill: fill, ownInk: r.kind === "color" ? hexOf(theme.text) : "", pageInk: hexOf(theme.text) })
  }
  function remember(hex) {
    var list = [hex].concat(String(s.recentColors || "").split(",").filter(function(c) { return /^#[0-9a-f]{6}$/i.test(c) && c.toLowerCase() !== hex.toLowerCase() }))
    set("recentColors", list.slice(0, 8).join(","))
  }

  // The color picker: what's picked shows at once; Apply keeps it, Cancel
  // puts back what was there.
  ColorPicker {
    id: colorPicker
    objectName: "appearancePicker"
    theme: panel.theme
    parent: panel.contentItem
    x: (panel.width - width) / 2
    y: 70
    onPreview: function(hex) { if (panel.picking) panel.set(panel.picking.key, hex) }
    onPicked: function(hex) { if (panel.picking) { panel.set(panel.picking.key, hex); panel.remember(hex) } panel.picking = null }
    onCanceled: { if (panel.picking) panel.set(panel.picking.key, panel.pickedBefore); panel.picking = null }
  }

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

  // A profile: its name (written in place), its folder, and Open (or that
  // it's open), Folder… (its notes looked for elsewhere: nothing's moved),
  // the folder in the file manager, and Remove (its notes stay; asked
  // first); the demo's, Start over (asked first).
  component ProfileRow: Item {
    id: prow
    required property var modelData
    readonly property bool open: panel.profiles.current !== null && panel.profiles.current.id === modelData.id
    property string error: ""
    property string asking: ""
    objectName: "settingsProfile"
    width: parent ? parent.width : 400
    height: Math.max(58, rowBody.implicitHeight + 14)
    Column {
      id: rowBody
      anchors.left: parent.left
      anchors.right: rowTools.left
      anchors.rightMargin: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Row {
        spacing: 8
        Field {
          id: nameEdit
          objectName: "settingsProfileName"
          theme: panel.theme
          width: 170
          height: 30
          fontSize: 13
          maximumLength: 60
          text: prow.modelData.name
          onAccepted: { prow.error = panel.profiles.rename(prow.modelData.id, text); if (prow.error) text = prow.modelData.name }
          onEscaped: text = prow.modelData.name
          input.onActiveFocusChanged: if (!input.activeFocus && text !== prow.modelData.name) { prow.error = panel.profiles.rename(prow.modelData.id, text); if (prow.error) text = prow.modelData.name }
        }
        Text {
          visible: prow.open || prow.modelData.demo
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: prow.open ? (prow.modelData.demo ? "open · demo" : "open") : "demo"
          font.family: panel.theme.uiFont
          font.pixelSize: 11
          color: panel.theme.muted
        }
      }
      Text {
        objectName: "settingsProfileFolder"
        width: parent.width
        elide: Text.ElideMiddle
        textFormat: Text.PlainText
        leftPadding: 2
        text: prow.modelData.folder || "~/Documents/Omanote"
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: panel.theme.muted
      }
      Text {
        visible: prow.error !== "" || prow.asking !== ""
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        leftPadding: 2
        text: prow.error || (prow.asking === "remove" ? "Take \u201c" + prow.modelData.name + "\u201d off the list? Its notes stay in their folder, to add again." : "Start the demo over? What you changed in it goes to the trash.")
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: prow.error ? panel.theme.urgent : panel.theme.text
      }
    }
    Row {
      id: rowTools
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      spacing: 4
      // Asked first: yes, or no.
      TextButton {
        visible: prow.asking !== ""
        objectName: "settingsProfileYes"
        theme: panel.theme
        primary: true
        text: prow.asking === "remove" ? "Remove" : "Start over"
        onClicked: {
          var what = prow.asking
          prow.asking = ""
          if (what === "remove") prow.error = panel.profiles.remove(prow.modelData.id)
          else { panel.close(); panel.profiles.restartDemo() }
        }
      }
      TextButton { visible: prow.asking !== ""; theme: panel.theme; text: "Cancel"; onClicked: prow.asking = "" }
      TextButton {
        visible: prow.asking === "" && !prow.open
        objectName: "settingsProfileOpen"
        theme: panel.theme
        text: "Open"
        onClicked: { panel.close(); panel.profiles.use(prow.modelData.id) }
      }
      TextButton {
        visible: prow.asking === "" && !prow.modelData.demo
        objectName: "settingsProfileMove"
        theme: panel.theme
        text: "Folder\u2026"
        onClicked: panel.service.pickFolder("Where " + prow.modelData.name + "'s notes are", function(path) {
          if (!path) return
          var home = panel.service.home || ""
          prow.error = panel.profiles.setFolder(prow.modelData.id, home && path.indexOf(home + "/") === 0 ? "~" + path.slice(home.length) : path)
        })
      }
      IconButton {
        visible: prow.asking === ""
        theme: panel.theme; icon: panel.theme.icons.folder; size: 30; iconSize: 14
        tip: "Open the folder"
        onClicked: panel.service.store.openUrl("file://" + panel.profiles.pathOf(prow.modelData.folder))
      }
      IconButton {
        visible: prow.asking === "" && prow.modelData.demo
        objectName: "settingsDemoRestart"
        theme: panel.theme; icon: panel.theme.icons.undo || panel.theme.icons.back; size: 30; iconSize: 14
        tip: "Start the demo over"
        onClicked: { prow.error = ""; prow.asking = "restart" }
      }
      IconButton {
        visible: prow.asking === "" && !prow.open
        objectName: "settingsProfileRemove"
        theme: panel.theme; icon: panel.theme.icons.trash; size: 30; iconSize: 14
        tip: "Take it off the list (its notes stay)"
        onClicked: { prow.error = ""; prow.asking = "remove" }
      }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: panel.theme.line; opacity: 0.6 }
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

        Heading { text: "Profiles"; visible: panel.profiles !== null }
        Text {
          visible: panel.profiles !== null
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          bottomPadding: 6
          text: "Notes kept apart: each profile has a folder of its own, with its notebooks, pages, calendar, people and templates. Switch at the top of the sidebar or the shelf."
          font.family: panel.theme.uiFont
          font.pixelSize: 12
          color: panel.theme.muted
        }
        Repeater {
          model: panel.profiles ? panel.profiles.shown : []
          delegate: ProfileRow {}
        }
        Item {
          visible: panel.profiles !== null
          width: parent.width
          height: panel.addingProfile ? addForm.height + 20 : 44
          TextButton {
            objectName: "settingsNewProfile"
            visible: !panel.addingProfile
            anchors.verticalCenter: parent.verticalCenter
            theme: panel.theme
            icon: panel.theme.icons.plus
            text: "New profile"
            onClicked: { panel.addingProfile = true; addForm.reset(""); Qt.callLater(addForm.focusName) }
          }
          TextButton {
            visible: !panel.addingProfile && panel.profiles !== null && panel.profiles.demo === null
            x: 140
            anchors.verticalCenter: parent.verticalCenter
            theme: panel.theme
            text: "Explore the demo"
            onClicked: { panel.close(); panel.profiles.openDemo() }
          }
          ProfileForm {
            id: addForm
            visible: panel.addingProfile
            y: 10
            width: Math.min(420, parent.width)
            theme: panel.theme
            service: panel.service
            onCreated: { panel.addingProfile = false; panel.close() }
            onCancelled: panel.addingProfile = false
          }
        }

        Heading { text: "Appearance" }
        Repeater {
          model: panel.colorRoles
          delegate: Line {
            id: roleLine
            required property var modelData
            readonly property bool own: !!panel.s[modelData.key]
            readonly property real ratio: panel.contrastOf(modelData)
            label: modelData.label
            note: modelData.note + (ratio < 4.5 ? "  \u00b7  Text is hard to read on it (" + ratio.toFixed(1) + ":1)" : "")
            Row {
              spacing: 10
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: roleLine.own ? panel.s[roleLine.modelData.key] : "Theme"
                font.family: panel.theme.uiFont
                font.pixelSize: 12
                color: panel.theme.muted
              }
              Rectangle {
                id: swatch
                objectName: "appearanceSwatch_" + roleLine.modelData.key
                anchors.verticalCenter: parent.verticalCenter
                width: 44
                height: 26
                radius: 7
                // (The text's: "Aa" in it, on the page.)
                color: roleLine.modelData.kind === "color" ? panel.theme.background : panel.theme[roleLine.modelData.role]
                border.width: 1
                border.color: swatchHover.hovered ? Qt.alpha(panel.theme.text, 0.5) : panel.theme.line
                Text {
                  visible: roleLine.modelData.kind === "color"
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: "Aa"
                  font.family: panel.theme.uiFont
                  font.pixelSize: 12
                  font.weight: Font.DemiBold
                  color: panel.theme.text
                }
                HoverHandler { id: swatchHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: panel.pickColor(roleLine.modelData, swatch) }
                ToolTip.visible: swatchHover.hovered
                ToolTip.delay: 500
                ToolTip.text: "Pick a color"
              }
              Text {
                objectName: "appearanceReset_" + roleLine.modelData.key
                visible: roleLine.own
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: "Reset"
                font.family: panel.theme.uiFont
                font.pixelSize: 12
                font.underline: resetHover.hovered
                color: panel.theme.muted
                HoverHandler { id: resetHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: panel.set(roleLine.modelData.key, "") }
              }
            }
          }
        }
        Text {
          objectName: "appearanceResetAll"
          visible: panel.anyColor
          topPadding: 2
          bottomPadding: 6
          textFormat: Text.PlainText
          text: "Back to the theme's colors"
          font.family: panel.theme.uiFont
          font.pixelSize: 12
          font.underline: resetAllHover.hovered
          color: panel.theme.muted
          HoverHandler { id: resetAllHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: { panel.set("colorSidebar", ""); panel.set("colorPage", ""); panel.set("colorCards", ""); panel.set("colorText", "") } }
        }

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
        Line {
          label: "Meetings"
          note: !panel.meetings || (panel.meetings.checked && !panel.meetings.available) ? "Need voxtype, Omarchy's dictation (omarchy voxtype install)."
            : panel.meetings.enabled ? "On: /meeting, or the people at the top of a page, records one. voxtype writes out who said what (you, and the other side of a call)."
            : "voxtype's meeting mode is off. Turning it on sets meeting.enabled in its settings and restarts it."
          Chip {
            objectName: "meetingsEnable"
            visible: panel.meetings !== null && panel.meetings.available && !panel.meetings.enabled
            theme: panel.theme
            icon: panel.theme.icons.people
            text: panel.meetings && panel.meetings.working === "enable" ? "Turning it on\u2026" : "Turn on"
            onClicked: if (!panel.meetings.working) panel.meetings.enable(function() {})
          }
        }

        Heading { text: "Sound and motion" }
        Line {
          label: "Paper sounds"
          note: "A soft rustle when a page turns and a notebook opens."
          Toggle { theme: panel.theme; checked: panel.s.sounds !== false; onToggled: function(on) { panel.set("sounds", on) } }
        }
        Line {
          label: "Scrolling speed"
          note: "With a trackpad or a mouse wheel. A trackpad's quick strokes go further, as on a MacBook."
          Row {
            spacing: 6
            Repeater {
              model: [{ label: "Slower", value: "slower" }, { label: "Normal", value: "normal" }, { label: "Faster", value: "faster" }]
              delegate: Chip {
                required property var modelData
                objectName: "scrollSpeed_" + modelData.value
                theme: panel.theme
                text: modelData.label
                checked: (panel.s.scrollSpeed || "normal") === modelData.value
                onClicked: panel.set("scrollSpeed", modelData.value)
              }
            }
          }
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
