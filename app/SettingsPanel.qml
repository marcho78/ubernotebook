import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Agent.js" as Agent
import "../Permissions.js" as Permissions
import "../Audio.js" as Audio
import "../Backups.js" as Backups
import "../Colors.js" as Colors
import "../Dates.js" as Dates
import "../Sidebar.js" as Sidebar

// Uber Notebook's settings, in sections (the list at the left): General,
// Appearance, Writing, Audio, Profiles, Backups and About. They apply as
// you change them and are kept on Uber Notebook's entry in
// ~/.config/omarchy/shell.json.
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
  // Whether there's a newer Uber Notebook (Updates.qml), and backups (Backups.qml).
  readonly property var updates: service && service.updates ? service.updates : null
  readonly property var backups: service && service.backups ? service.backups : null

  // The section shown.
  property string section: "general"
  // What's new (`own`: what's in the version you have).
  signal releaseNotesRequested(bool own)

  readonly property var icons: theme ? theme.icons : ({})
  readonly property var sections: [
    { id: "general", label: "General", icon: icons.cog || "", note: "Shortcuts, the window, and scrolling." },
    { id: "appearance", label: "Appearance", icon: icons.palette || "", note: "Colors of your own over the Omarchy theme's, what the sidebar shows, and motion." },
    { id: "writing", label: "Writing", icon: icons.pen || "", note: "Checklists, exports, and a Markdown copy of your notes." },
    { id: "ai", label: "AI", icon: icons.agent || "", note: "Your agent, and the model and effort it works with." },
    { id: "audio", label: "Audio", icon: icons.mic || "", note: "The microphone, dictation, and meetings." },
    { id: "profiles", label: "Profiles", icon: icons.people || "", note: "Notes kept apart, each profile in a folder of its own." },
    { id: "backups", label: "Backups", icon: icons.archive || "", note: "Your profiles in one file each, to keep safe or move, and put back." },
    { id: "about", label: "About", icon: icons.info || "", note: "The version you have, updates, and who makes Uber Notebook." }
  ]
  readonly property var current: sections.filter(function(x) { return x.id === panel.section })[0] || sections[0]

  // Settings open at a section (and at a part of it: its objectName).
  property string openPart: ""
  function openAt(id, part) {
    if (sections.some(function(x) { return x.id === id })) section = id
    openPart = part || ""
    open()
  }
  function findPart(item, name) {
    if (!item) return null
    if (item.objectName === name && item.visible) return item
    for (var i = 0; i < item.children.length; i++) {
      var found = findPart(item.children[i], name)
      if (found) return found
    }
    return null
  }

  anchors.centerIn: Overlay.overlay
  width: Math.min(920, (parent ? parent.width : 920) - 40)
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
    restoring = null
    restored = []
    if (backups) backups.refresh()
    if (section === "ai") loadAgents()
    flick.contentY = 0
    var part = openPart ? findPart(body, openPart) : null
    if (part) flick.contentY = Math.max(0, Math.min(part.mapToItem(body, 0, 0).y - 8, flick.contentHeight - flick.height))
    openPart = ""
    // (The keys come here, so Esc closes it, whatever had them before.)
    contentItem.forceActiveFocus()
  }
  onSectionChanged: { flick.contentY = 0; if (section === "backups" && backups) backups.refresh(); if (section === "ai") loadAgents() }

  function set(key, value) { if (service) service.setSetting(key, value) }

  // ---- appearance ----

  // The colors of your own over the theme's: which setting, what it's
  // called, what it colors, and the theme's color it stands in for.
  readonly property var colorRoles: [
    { key: "colorSidebar", label: "Sidebar", note: "Behind the list of pages", role: "sidebar", kind: "background" },
    { key: "colorPage", label: "Page background", note: "Behind your pages, the calendar, People and the Library", role: "background", kind: "background" },
    { key: "colorCards", label: "Sections and cards", note: "The sidebar's sections as cards (Projects, Pages, Tags…), and cards and menus", role: "surface", kind: "background" },
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

  // ---- audio ----

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
    : testing ? "Say a few words…"
    : "Say a few words: the bars show how loud you come through" + (s.audioBoost !== false ? ", made louder." : ".")
  readonly property string micLabel: {
    var name = s.audioInput || ""
    if (!name) return "The default one"
    var list = recorder ? recorder.sources : []
    for (var i = 0; i < list.length; i++) if (list[i].name === name) return list[i].label
    return name
  }

  // ---- backups ----

  // A backup being put back: { path, checking, ok, problem, manifest }, asked about first.
  property var restoring: null
  // What the last one put back: [{ id, name, folder }].
  property var restored: []
  function backUp(which) {
    if (!backups) return
    backups.backUp(which, false, function() {})
  }
  function askRestore(path) {
    restoring = { path: path, checking: true, ok: false, problem: "", manifest: null }
    restored = []
    backups.inspect(path, function(r) { panel.restoring = { path: path, checking: false, ok: r.ok, problem: r.problem, manifest: r.manifest } })
  }
  function chooseBackup() {
    if (!service) return
    service.pickFile("backup", function(path) { if (path) panel.askRestore(path) }, backups ? backups.folder : "")
  }
  function restoreNow() {
    var r = restoring
    if (!r || !r.ok) return
    restoring = null
    backups.restore(r.path, false, function(result) { if (result.ok) panel.restored = result.restored })
  }
  function whenLabel(ms) {
    var d = new Date(ms)
    var today = new Date()
    var same = d.toDateString() === today.toDateString()
    return (same ? "Today" : Qt.formatDate(d, d.getFullYear() === today.getFullYear() ? "d MMM" : "d MMM yyyy")) + ", " + Dates.clockOf(d)
  }

  // ---- your agent ----

  // The agents installed here (Omarchy's list: [{ name, label }]), the one
  // that's Omarchy's default, and the models Claude Code, Grok and Codex can
  // work with ({ claude: [...], grok: [...], codex: [...] }).
  property var agents: []
  property string agentName: ""
  property var modelLists: ({})
  readonly property var store: service && service.store ? service.store : null
  readonly property var hereAgents: agents.filter(function(a) { return Agent.runsHere(a.name) })
  function loadAgents() {
    if (!store || typeof store.listAgents !== "function") return
    store.listAgents(function(list) { panel.agents = list })
    store.defaultAgent(function(name) { panel.agentName = name })
    var lists = {}
    Agent.HERE.forEach(function(a) { store.agentModels(a, function(m) { lists[a] = m }) })
    modelLists = lists
  }
  function chooseAgent(name) {
    if (!store) return
    store.setDefaultAgent(name, function(ok) { if (ok) panel.agentName = name })
  }

  // ---- updates ----

  readonly property string updateNote: {
    var u = updates
    if (!u) return ""
    var clock = panel.theme.twelveHour
    var when = u.checkedAt ? " · checked " + Dates.clockOf(new Date(u.checkedAt)) : ""
    if (u.status === "checking") return "Checking…"
    if (u.status === "available") return "Version " + u.latest.version + " is available" + when
    if (u.status === "current") return "You have the newest version" + when
    if (u.status === "none") return "No releases published yet" + when
    if (u.status === "failed") return u.problem + when
    return u.automatic ? "Checked a minute after Uber Notebook starts, then once a day." : "Not checked yet."
  }

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 16; color: panel.theme.surface; border.width: 1; border.color: panel.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: panel.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 14; autoPaddingEnabled: true }
  }

  // ---- the parts each section is made of ----

  // A group of settings: a small heading, then its rows on a card; a line
  // under it, if it has one.
  component Group: Column {
    id: grp
    property string title: ""
    property string note: ""
    default property alias rows: rowsCol.data
    width: parent ? parent.width : 400
    spacing: 8
    Text {
      visible: grp.title !== ""
      leftPadding: 2
      textFormat: Text.PlainText
      text: grp.title
      font.family: panel.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 0.7
      color: panel.theme.muted
    }
    Rectangle {
      width: parent.width
      height: rowsCol.height
      radius: 10
      color: Qt.alpha(panel.theme.text, 0.025)
      border.width: 1
      border.color: panel.theme.line
      Column { id: rowsCol; width: parent.width }
    }
    Text {
      visible: grp.note !== ""
      width: parent.width
      leftPadding: 2
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: grp.note
      font.family: panel.theme.uiFont
      font.pixelSize: 12
      lineHeight: 1.15
      color: panel.theme.muted
    }
  }

  // A row on a card: what it is (and a line about it), and its control at the right.
  component Line: Item {
    id: line
    property string label: ""
    property string note: ""
    property color noteColor: panel.theme.muted
    default property alias control: slot.data
    width: parent ? parent.width : 400
    // As tall as its words, or its control (chips that wrap to more rows),
    // whichever's taller: nothing over the line above or below.
    height: Math.max(52, texts.implicitHeight + 22, slot.height + 16)
    Rectangle { visible: !line.Positioner.isFirstItem; x: 16; width: parent.width - 32; height: 1; color: panel.theme.line; opacity: 0.7 }
    Column {
      id: texts
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.right: slot.left
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Text { textFormat: Text.PlainText; width: parent.width; text: line.label; wrapMode: Text.WordWrap; font.family: panel.theme.uiFont; font.pixelSize: 14; color: panel.theme.text }
      Text { textFormat: Text.PlainText; visible: line.note !== ""; width: parent.width; text: line.note; wrapMode: Text.WordWrap; font.family: panel.theme.uiFont; font.pixelSize: 12; lineHeight: 1.1; color: line.noteColor }
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  // One of several, on or off: a box, ticked, and its name.
  component Pick: Rectangle {
    id: pick
    property string text: ""
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: pickRow.implicitWidth + 16
    implicitHeight: 30
    radius: 7
    color: pickHover.hovered ? panel.theme.hover : "transparent"
    Row {
      id: pickRow
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      spacing: 8
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: 4
        color: pick.checked ? panel.theme.accent : "transparent"
        border.width: pick.checked ? 0 : 1.5
        border.color: Qt.alpha(panel.theme.text, 0.35)
        Icon {
          anchors.centerIn: parent
          visible: pick.checked
          theme: panel.theme
          text: panel.theme.icons.check
          size: 12
          color: panel.theme.onAccent
        }
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: pick.text
        font.family: panel.theme.uiFont
        font.pixelSize: 13
        color: pick.checked ? panel.theme.text : panel.theme.muted
      }
    }
    HoverHandler { id: pickHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: pick.toggled(!pick.checked) }
  }

  // Chips, one of them chosen: [{ label, value }].
  component Choice: Row {
    id: choice
    property var options: []
    property var value: null
    property string prefix: ""
    signal picked(var value)
    spacing: 6
    Repeater {
      model: choice.options
      delegate: Chip {
        required property var modelData
        objectName: choice.prefix ? choice.prefix + modelData.value : ""
        theme: panel.theme
        text: modelData.label
        checked: choice.value === modelData.value
        onClicked: choice.picked(modelData.value)
      }
    }
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
    height: Math.max(64, rowBody.implicitHeight + 20)
    Rectangle { visible: !prow.Positioner.isFirstItem; x: 16; width: parent.width - 32; height: 1; color: panel.theme.line; opacity: 0.7 }
    Column {
      id: rowBody
      anchors.left: parent.left
      anchors.leftMargin: 16
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
          width: 180
          height: 30
          fontSize: 13
          maximumLength: 60
          text: prow.modelData.name
          onAccepted: { prow.error = panel.profiles.rename(prow.modelData.id, text); if (prow.error) text = prow.modelData.name }
          onEscaped: text = prow.modelData.name
          input.onActiveFocusChanged: if (!input.activeFocus && text !== prow.modelData.name) { prow.error = panel.profiles.rename(prow.modelData.id, text); if (prow.error) text = prow.modelData.name }
        }
        Rectangle {
          visible: prow.open || prow.modelData.demo
          anchors.verticalCenter: parent.verticalCenter
          width: badge.implicitWidth + 14
          height: 20
          radius: 10
          color: "transparent"
          border.width: 1
          border.color: panel.theme.line
          Text {
            id: badge
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: prow.open ? (prow.modelData.demo ? "Open · demo" : "Open") : "Demo"
            font.family: panel.theme.uiFont
            font.pixelSize: 11
            color: panel.theme.muted
          }
        }
      }
      Text {
        objectName: "settingsProfileFolder"
        width: parent.width
        elide: Text.ElideMiddle
        textFormat: Text.PlainText
        leftPadding: 2
        text: prow.modelData.folder || "~/Documents/Uber Notebook"
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
        text: prow.error || (prow.asking === "remove" ? "Take “" + prow.modelData.name + "” off the list? Its notes stay in their folder, to add again." : "Start the demo over? What you changed in it goes to the trash.")
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: prow.error ? panel.theme.urgent : panel.theme.text
      }
    }
    Row {
      id: rowTools
      anchors.right: parent.right
      anchors.rightMargin: 12
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
        text: "Folder…"
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
        onClicked: panel.service.store.openLocal(panel.profiles.pathOf(prow.modelData.folder))
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
  }

  contentItem: Item {
    // ---- the sections, at the left ----
    Rectangle {
      id: nav
      width: 212
      height: parent.height
      radius: 16
      color: Qt.alpha(panel.theme.text, 0.035)
      // (Square on the right, where it meets the section.)
      Rectangle { anchors.right: parent.right; width: 16; height: parent.height; color: parent.color }
      Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: panel.theme.line }

      Text {
        x: 22
        y: 22
        textFormat: Text.PlainText
        text: "Settings"
        font.family: panel.theme.uiFont
        font.pixelSize: 19
        font.weight: Font.DemiBold
        color: panel.theme.text
      }
      Column {
        x: 10
        y: 66
        width: parent.width - 20
        spacing: 2
        Repeater {
          model: panel.sections
          delegate: Rectangle {
            id: navRow
            required property var modelData
            readonly property bool chosen: panel.section === modelData.id
            objectName: "settingsSection_" + modelData.id
            width: parent.width
            height: 34
            radius: 8
            color: chosen ? panel.theme.pressed : navHover.hovered ? panel.theme.hover : "transparent"
            Icon {
              theme: panel.theme
              x: 12
              anchors.verticalCenter: parent.verticalCenter
              text: navRow.modelData.icon
              size: 16
              color: navRow.chosen ? panel.theme.text : panel.theme.muted
            }
            Text {
              x: 40
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: navRow.modelData.label
              font.family: panel.theme.uiFont
              font.pixelSize: 13
              font.weight: navRow.chosen ? Font.DemiBold : Font.Normal
              color: panel.theme.text
            }
            // A newer version, or a backup going: a dot.
            Rectangle {
              visible: (navRow.modelData.id === "about" && panel.updates !== null && panel.updates.available)
                || (navRow.modelData.id === "backups" && panel.backups !== null && panel.backups.working !== "")
              anchors.right: parent.right
              anchors.rightMargin: 12
              anchors.verticalCenter: parent.verticalCenter
              width: 7
              height: 7
              radius: 3.5
              color: panel.theme.accent
            }
            HoverHandler { id: navHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: panel.section = navRow.modelData.id }
          }
        }
      }
      Text {
        x: 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        textFormat: Text.PlainText
        text: "Uber Notebook " + (panel.service ? panel.service.version : "")
        font.family: panel.theme.uiFont
        font.pixelSize: 11
        color: panel.theme.faint
      }
    }

    // ---- the section ----
    Column {
      id: sectionHead
      x: nav.width + 32
      y: 24
      width: parent.width - x - 64
      spacing: 4
      Text {
        objectName: "settingsTitle"
        textFormat: Text.PlainText
        text: panel.current.label
        font.family: panel.theme.uiFont
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: panel.theme.text
      }
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: panel.current.note
        font.family: panel.theme.uiFont
        font.pixelSize: 13
        color: panel.theme.muted
      }
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
      objectName: "settingsFlick"
      x: nav.width + 32
      y: sectionHead.y + sectionHead.height + 20
      width: parent.width - x - 32
      height: parent.height - y
      contentHeight: body.height + 28
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: flick.contentHeight > flick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }

      Column {
        id: body
        width: flick.width - 6
        spacing: 22

        // ======== General ========

        Group {
          visible: panel.section === "general"
          title: "Shortcuts"
          Line {
            label: "Open and close Uber Notebook"
            note: panel.service ? panel.service.shortcutNote("toggle") : ""
            Field {
              id: toggleField
              theme: panel.theme
              width: 190
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
              width: 190
              placeholder: "None"
              onAccepted: panel.set("quickShortcut", text)
              input.onActiveFocusChanged: if (!input.activeFocus) panel.set("quickShortcut", text)
            }
          }
          Line {
            label: "Quick notes go to"
            note: panel.s.quickTo !== "notebook" ? "A page in your Pages Inbox: the first line is its title, the rest Markdown." : "A page in the Quick notes notebook."
            Choice {
              options: [{ label: "Pages Inbox", value: "pages" }, { label: "Quick notes", value: "notebook" }]
              value: panel.s.quickTo || "pages"
              onPicked: function(v) { panel.set("quickTo", v) }
            }
          }
        }

        Group {
          visible: panel.section === "general"
          title: "Window"
          Line {
            label: "Float in the middle of the screen"
            note: "Like a notebook on your desk. Off, it tiles like any other window."
            Toggle { theme: panel.theme; checked: panel.s.floating !== false; onToggled: function(on) { panel.set("floating", on) } }
          }
          Line {
            label: "Size"
            note: "When it floats."
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
            label: "Show Uber Notebook in the top bar"
            note: "Off, the notebook icon takes no space; Uber Notebook stays on."
            Toggle { theme: panel.theme; checked: panel.s.barIcon !== false; onToggled: function(on) { panel.set("barIcon", on) } }
          }
        }

        Group {
          visible: panel.section === "general"
          title: "Scrolling"
          Line {
            label: "Scrolling speed"
            note: "With a trackpad or a mouse wheel. A trackpad's quick strokes go further, as on a MacBook."
            Choice {
              prefix: "scrollSpeed_"
              options: [{ label: "Slower", value: "slower" }, { label: "Normal", value: "normal" }, { label: "Faster", value: "faster" }]
              value: panel.s.scrollSpeed || "normal"
              onPicked: function(v) { panel.set("scrollSpeed", v) }
            }
          }
        }

        // ======== Appearance ========

        Group {
          visible: panel.section === "appearance"
          title: "Colors"
          note: "Each one follows the Omarchy theme until you pick a color of your own."
          Repeater {
            model: panel.colorRoles
            delegate: Line {
              id: roleLine
              required property var modelData
              readonly property bool own: !!panel.s[modelData.key]
              readonly property real ratio: panel.contrastOf(modelData)
              label: modelData.label
              note: modelData.note + (ratio < 4.5 ? "  ·  Text is hard to read on it (" + ratio.toFixed(1) + ":1)" : "")
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
                  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: panel.pickColor(roleLine.modelData, swatch) }
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
                  // (Its click is its own, on a box a little bigger than the word.)
                  Item {
                    anchors.fill: parent
                    anchors.margins: -4
                    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: panel.set(roleLine.modelData.key, "") }
                  }
                }
              }
            }
          }
          Line {
            visible: panel.anyColor
            label: "Back to the theme's colors"
            note: "All four follow the Omarchy theme again."
            TextButton {
              objectName: "appearanceResetAll"
              theme: panel.theme
              text: "Reset all"
              onClicked: { panel.set("colorSidebar", ""); panel.set("colorPage", ""); panel.set("colorCards", ""); panel.set("colorText", "") }
            }
          }
        }

        Group {
          objectName: "sidebarChoices"
          visible: panel.section === "appearance"
          title: "Sidebar"
          note: "What Pages' sidebar shows. Pages and Settings are always there. A right-click in the sidebar hides what it's on, and a click on a section's name folds it."
          Repeater {
            model: [{ place: "top", label: "At the top" }, { place: "sections", label: "Sections" }, { place: "foot", label: "At the foot" }]
            delegate: Line {
              id: placeLine
              required property var modelData
              label: modelData.label
              Row {
                spacing: 2
                Repeater {
                  model: Sidebar.itemsAt(placeLine.modelData.place)
                  delegate: Pick {
                    required property var modelData
                    objectName: "sidebarItem_" + modelData.id
                    text: modelData.label
                    checked: (panel.s.sidebarHidden || []).indexOf(modelData.id) < 0
                    onToggled: function(on) { panel.set("sidebarHidden", Sidebar.setIn(panel.s.sidebarHidden || [], modelData.id, !on)) }
                  }
                }
              }
            }
          }
          Line {
            visible: (panel.s.sidebarHidden || []).length > 0
            label: "Everything back"
            note: "All of it in the sidebar again."
            TextButton {
              objectName: "sidebarShowAll"
              theme: panel.theme
              text: "Show all"
              onClicked: panel.set("sidebarHidden", [])
            }
          }
        }

        Group {
          visible: panel.section === "appearance"
          title: "Motion and sound"
          Line {
            label: "Reduce motion"
            note: "Pages and covers fade instead of turning."
            Toggle { theme: panel.theme; checked: panel.s.reduceMotion === true; onToggled: function(on) { panel.set("reduceMotion", on) } }
          }
          Line {
            label: "Paper sounds"
            note: "A soft rustle when a page turns and a notebook opens."
            Toggle { theme: panel.theme; checked: panel.s.sounds !== false; onToggled: function(on) { panel.set("sounds", on) } }
          }
        }

        // ======== Writing ========

        Group {
          visible: panel.section === "writing"
          title: "Checklists"
          Line {
            label: "Cross off checked items"
            note: "A line through what's done, as on paper."
            Toggle { theme: panel.theme; checked: panel.s.strikeDone !== false; onToggled: function(on) { panel.set("strikeDone", on) } }
          }
        }

        Group {
          visible: panel.section === "writing"
          title: "Times"
          Line {
            label: "Clock"
            note: "How times are shown: in the calendar, on events and reminders, in what's dated. You can type either way."
            Choice {
              objectName: "clockChoice"
              prefix: "clock_"
              options: [{ label: "1:30 pm", value: "12" }, { label: "13:30", value: "24" }]
              value: panel.s.clock === "24" ? "24" : "12"
              onPicked: function(v) { panel.set("clock", v) }
            }
          }
        }

        Group {
          visible: panel.section === "writing"
          title: "Exports"
          Line {
            label: "Exports go to"
            note: panel.s.exportTo === "folder" ? (panel.service ? panel.service.rootPath + "/Exports" : "The Exports folder") : "A folder picker asks where, each time."
            Choice {
              options: [{ label: "Ask where", value: "ask" }, { label: "Exports folder", value: "folder" }]
              value: panel.s.exportTo || "ask"
              onPicked: function(v) { panel.set("exportTo", v) }
            }
          }
        }

        Group {
          visible: panel.section === "writing"
          title: "Markdown copy"
          Line {
            label: "Keep a Markdown copy"
            note: panel.s.mirror === true && panel.service
              ? panel.service.mirror.status + (panel.service.mirror.status === "Up to date" && panel.service.mirror.lastSync
                ? " · " + panel.service.mirror.files + " files · " + (panel.theme.twelveHour, Dates.clockOf(new Date(panel.service.mirror.lastSync))) : "")
              : "A Markdown file of every page, kept up to date in a folder, for Obsidian, git or any editor."
            Toggle { theme: panel.theme; checked: panel.s.mirror === true; onToggled: function(on) { panel.set("mirror", on) } }
          }
          Line {
            visible: panel.s.mirror === true
            label: "Copy to"
            note: panel.service ? panel.service.mirrorPath + (panel.service.mirror.notPrivate ? " · some of the copy couldn't be made yours alone: another account on this computer may read it" : "") : ""
            Row {
              spacing: 6
              Field {
                id: mirrorField
                theme: panel.theme
                width: 200
                placeholder: "Default (Markdown)"
                onAccepted: panel.set("mirrorFolder", text)
                input.onActiveFocusChanged: if (!input.activeFocus) panel.set("mirrorFolder", text)
              }
              IconButton { theme: panel.theme; icon: panel.theme.icons.folder; tip: "Open the copy"; onClicked: panel.service.openMirror() }
            }
          }
        }

        // ======== AI ========

        Group {
          visible: panel.section === "ai"
          title: "Your agent"
          note: "Claude, Grok and Codex work right here, in a panel on the page. The others open in a terminal. It's Omarchy's default agent too."
          Line {
            label: "Agent"
            note: panel.agentName ? Agent.name(panel.agentName) + (Agent.runsHere(panel.agentName) ? ": works here" : ": opens in a terminal") : "None chosen yet"
            // Claude, Grok and Codex first, side by side (they work here);
            // then the others, which open in a terminal.
            Column {
              width: Math.min(380, panel.width * 0.46)
              spacing: 6
              AgentTiles {
                id: settingsTiles
                theme: panel.theme
                agents: panel.agents
                agent: panel.agentName
                namePrefix: "aiAgent_"
                width: parent.width
                onPicked: function(name) { panel.chooseAgent(name) }
              }
              Text {
                visible: settingsTiles.others().length > 0
                textFormat: Text.PlainText
                topPadding: 4
                text: "In a terminal"
                font.family: panel.theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: panel.theme.muted
              }
              Flow {
                width: parent.width
                spacing: 6
                Repeater {
                  model: settingsTiles.others()
                  delegate: Chip {
                    required property var modelData
                    objectName: "aiAgent_" + modelData.name
                    theme: panel.theme
                    text: modelData.label
                    checked: panel.agentName === modelData.name
                    onClicked: panel.chooseAgent(modelData.name)
                  }
                }
              }
            }
          }
        }

        Group {
          visible: panel.section === "ai"
          title: "Model and effort"
          note: panel.hereAgents.length ? "Default is as each agent is set up. A faster model, or less effort, answers sooner; more effort thinks longer." : "Install Claude Code, Grok or Codex to choose here (omarchy default agent claude)."
          Repeater {
            model: panel.hereAgents
            delegate: Line {
              id: aiLine
              required property var modelData
              readonly property string key: modelData.name
              objectName: "aiChoice_" + key
              label: modelData.label
              // What it works with: as it's set up, or the chosen model's description.
              readonly property var chosen: (panel.modelLists[key] || []).filter(function(m) { return m.id === (panel.s[aiLine.key + "Model"] || "") })[0] || null
              note: !(panel.s[key + "Model"] || "") ? "As " + Agent.name(key) + " is set up" + ((panel.s[key + "Effort"] || "") ? ", " + Agent.effortLabel(panel.s[key + "Effort"]).toLowerCase() + " effort" : "")
                : chosen && chosen.description ? chosen.description : Agent.choiceLabel(panel.modelLists[key] || [], panel.s[key + "Model"] || "", panel.s[key + "Effort"] || "")
              AgentChoice {
                theme: panel.theme
                namePrefix: "aiChoice_" + aiLine.key
                agentLabel: Agent.name(aiLine.key)
                models: panel.modelLists[aiLine.key] || []
                model: panel.s[aiLine.key + "Model"] || ""
                effort: panel.s[aiLine.key + "Effort"] || ""
                onPicked: function(m, e) { panel.set(aiLine.key + "Model", m); panel.set(aiLine.key + "Effort", e) }
              }
            }
          }
        }

        // What you've let agents have done for them without asking
        // (Permissions.js): sites Uber Notebook may contact for each.
        Group {
          visible: panel.section === "ai"
          title: "Commands"
          note: "When an agent in the panel wants to run a command, you're asked: for that command, or for the rest of the conversation. Here you can let it run any command without asking. A command runs programs that can read and change any file you can (your notes and Uber Notebook's settings too) and use the network, so this is off unless you turn it on."
          Repeater {
            model: [{ id: "claude", name: "Claude Code" }, { id: "grok", name: "Grok" }]
            delegate: Line {
              required property var modelData
              objectName: "aiShell_" + modelData.id
              label: modelData.name + " may run any command"
              note: "Without asking you"
              Toggle {
                theme: panel.theme
                checked: Permissions.allowed(panel.s.agentPermissions, modelData.id, "shell", "any")
                onToggled: function(on) {
                  panel.set("agentPermissions", on ? Permissions.withAllowed(panel.s.agentPermissions, modelData.id, "shell", "any")
                    : Permissions.without(panel.s.agentPermissions, modelData.id, "shell", "any"))
                }
              }
            }
          }
        }
        // The skill, for any AI (Service.copySkill...): Claude Code, Codex, pi
        // and Hermes find it themselves; anything else, given it.
        Group {
          id: skillGroup
          visible: panel.section === "ai"
          title: "Use with any AI"
          note: "Uber Notebook's skill tells an AI how to find, read and change your notes with omarchy-shell uber-notebook commands. Claude Code, Codex, pi and Hermes find it by themselves; give it to any other AI that can run commands on this computer (omarchy-shell uber-notebook skill prints it too)."
          property string said: ""
          Line {
            objectName: "aiSkill"
            label: "The skill"
            note: skillGroup.said || (panel.service && panel.service.skillPath ? String(panel.service.skillPath).replace(/^\/home\/[^\/]+/, "~") : "")
            Row {
              spacing: 6
              TextButton {
                objectName: "aiSkillCopy"
                theme: panel.theme
                text: "Copy"
                onClicked: skillGroup.said = panel.service && panel.service.copySkill() ? "Copied: paste it where your AI takes instructions" : "It couldn't be read"
              }
              TextButton {
                objectName: "aiSkillSave"
                theme: panel.theme
                text: "Save a copy\u2026"
                onClicked: if (panel.service) panel.service.saveSkillCopy(function(to, why) {
                  if (to) skillGroup.said = "Saved to " + to.replace(/^\/home\/[^\/]+/, "~")
                  else if (why) skillGroup.said = "Not saved: " + why
                })
              }
              TextButton {
                objectName: "aiSkillShow"
                theme: panel.theme
                text: "Show"
                onClicked: if (panel.service) panel.service.showSkill()
              }
            }
          }
        }
        Group {
          visible: panel.section === "ai"
          title: "What agents may do without asking"
          note: "When an agent in the panel wants to contact a site, search the web, use one of your connectors or move a page to the trash, you're asked in the panel first. Always puts it here, for that agent only. Agents can't change this list."
          Line {
            visible: Permissions.clean(panel.s.agentPermissions).length === 0
            label: "Nothing yet"
            note: "Everything is asked about."
          }
          Repeater {
            model: Permissions.clean(panel.s.agentPermissions)
            delegate: Line {
              required property var modelData
              objectName: "aiPermission"
              label: Permissions.describe(modelData).label
              note: Permissions.describe(modelData).note
              TextButton {
                objectName: "aiPermissionRemove"
                theme: panel.theme
                text: "Remove"
                onClicked: panel.set("agentPermissions", Permissions.without(panel.s.agentPermissions, modelData.agent, modelData.action, modelData.target))
              }
            }
          }
        }

        // ======== Audio ========

        Group {
          visible: panel.section === "audio"
          title: "Microphone"
          Line {
            label: "Microphone"
            note: "What audio notes and dictation record from."
            Rectangle {
              id: micButton
              objectName: "micPicker"
              width: Math.min(240, micText.implicitWidth + 40)
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
              TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { if (panel.recorder) panel.recorder.listSources(); micMenu.open() } }
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
        }

        Group {
          visible: panel.section === "audio"
          title: "Voice"
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
              : panel.meetings.enabled && panel.meetings.waiting ? panel.meetings.waitingText
              : panel.meetings.enabled ? "On: /meeting, or the people at the top of a page, records one. voxtype writes out who said what (you, and the other side of a call)."
              : "voxtype's meeting mode is off. Turning it on sets meeting.enabled in its settings; it takes effect when voxtype restarts."
            Chip {
              objectName: "meetingsEnable"
              visible: panel.meetings !== null && panel.meetings.available && !panel.meetings.enabled
              theme: panel.theme
              icon: panel.theme.icons.people
              text: panel.meetings && panel.meetings.working === "enable" ? "Turning it on…" : "Turn on"
              onClicked: if (!panel.meetings.working) panel.meetings.enable(function() {})
            }
          }
        }

        // ======== Profiles ========

        Group {
          visible: panel.section === "profiles" && panel.profiles !== null
          title: "Your profiles"
          note: "Each profile has its own notebooks, pages, calendar, people and templates. Switch between them at the top of the sidebar or the shelf."
          Repeater {
            model: panel.profiles ? panel.profiles.shown : []
            delegate: ProfileRow {}
          }
          Item {
            width: parent.width
            height: panel.addingProfile ? addForm.height + 28 : 56
            Rectangle { x: 16; width: parent.width - 32; height: 1; color: panel.theme.line; opacity: 0.7 }
            Row {
              visible: !panel.addingProfile
              x: 16
              anchors.verticalCenter: parent.verticalCenter
              spacing: 8
              TextButton {
                objectName: "settingsNewProfile"
                theme: panel.theme
                icon: panel.theme.icons.plus
                text: "New profile"
                onClicked: { panel.addingProfile = true; addForm.reset(""); Qt.callLater(addForm.focusName) }
              }
              TextButton {
                visible: panel.profiles !== null && panel.profiles.demo === null
                theme: panel.theme
                text: "Explore the demo"
                onClicked: { panel.close(); panel.profiles.openDemo() }
              }
            }
            ProfileForm {
              id: addForm
              visible: panel.addingProfile
              x: 16
              y: 14
              width: Math.min(440, parent.width - 32)
              theme: panel.theme
              service: panel.service
              onCreated: { panel.addingProfile = false; panel.close() }
              onCancelled: panel.addingProfile = false
            }
          }
        }

        // ======== Backups ========

        Group {
          visible: panel.section === "backups" && panel.backups !== null
          title: "Back up now"
          note: panel.backups ? (panel.backups.working === "backup" ? "Backing up…" : panel.backups.working === "restore" ? "Putting a backup back…" : panel.backups.note) : ""
          Line {
            label: panel.profiles && panel.profiles.current ? "“" + panel.profiles.current.name + "”" : "This profile"
            note: "This profile's notebooks, pages, calendar, people and templates, in one .tar.gz."
            TextButton {
              objectName: "backupNow"
              theme: panel.theme
              primary: true
              text: "Back up"
              onClicked: panel.backUp("")
            }
          }
          Line {
            label: "All profiles"
            note: "Every profile in one file (the demo can start over, so it's left out)."
            TextButton {
              objectName: "backupAll"
              theme: panel.theme
              text: "Back up all"
              onClicked: panel.backUp("all")
            }
          }
        }

        Group {
          visible: panel.section === "backups" && panel.backups !== null
          title: "Automatic backups"
          note: panel.s.backupEvery === "daily" || panel.s.backupEvery === "weekly" ? "Every profile, while Uber Notebook runs. The oldest automatic ones go to the trash; the ones you make are never cleared out." : ""
          Line {
            label: "Back up automatically"
            Choice {
              prefix: "backupEvery_"
              options: [{ label: "Off", value: "off" }, { label: "Daily", value: "daily" }, { label: "Weekly", value: "weekly" }]
              value: panel.s.backupEvery || "off"
              onPicked: function(v) { panel.set("backupEvery", v) }
            }
          }
          Line {
            visible: panel.s.backupEvery === "daily" || panel.s.backupEvery === "weekly"
            label: "Keep"
            note: "How many automatic backups."
            Choice {
              prefix: "backupKeep_"
              options: Backups.KEEP.map(function(n) { return { label: String(n), value: n } })
              value: panel.s.backupKeep || 10
              onPicked: function(v) { panel.set("backupKeep", v) }
            }
          }
          Line {
            label: "Folder"
            note: panel.backups ? panel.backups.folderShown + (panel.backups.notPrivate ? " · can't be made yours alone: another account on this computer may read your backups" : "") : ""
            Row {
              spacing: 4
              TextButton {
                objectName: "backupFolderChange"
                theme: panel.theme
                text: "Change…"
                onClicked: panel.service.pickFolder("Where backups go", function(path) {
                  if (!path) return
                  var home = panel.service.home || ""
                  panel.set("backupFolder", home && path.indexOf(home + "/") === 0 ? "~" + path.slice(home.length) : path)
                  panel.backups.refresh()
                })
              }
              TextButton {
                visible: !!panel.s.backupFolder
                theme: panel.theme
                text: "Default"
                onClicked: { panel.set("backupFolder", ""); Qt.callLater(function() { panel.backups.refresh() }) }
              }
              IconButton {
                theme: panel.theme; icon: panel.theme.icons.folder; size: 30; iconSize: 14
                tip: "Open the folder"
                onClicked: panel.service.store.openLocal(panel.backups.folder)
              }
            }
          }
        }

        Group {
          visible: panel.section === "backups" && panel.backups !== null
          title: "Restore"
          note: "A backup comes back as new profiles, each in a new folder. Nothing you have now is changed."
          // Asked first: what's in it, and Restore.
          Line {
            visible: panel.restoring !== null
            objectName: "restoreAsk"
            label: panel.restoring ? panel.restoring.path.split("/").pop() : ""
            noteColor: panel.restoring && !panel.restoring.checking && !panel.restoring.ok ? panel.theme.urgent : panel.theme.muted
            note: !panel.restoring ? "" : panel.restoring.checking ? "Looking inside…"
              : !panel.restoring.ok ? panel.restoring.problem
              : "Puts back " + panel.restoring.manifest.profiles.map(function(p) { return "“" + p.name + "”" }).join(", ")
                + (panel.restoring.manifest.created ? ", backed up " + panel.whenLabel(Date.parse(panel.restoring.manifest.created)) : "") + "."
            Row {
              spacing: 6
              TextButton {
                objectName: "restoreYes"
                visible: panel.restoring !== null && panel.restoring.ok
                theme: panel.theme
                primary: true
                text: "Restore"
                onClicked: panel.restoreNow()
              }
              TextButton { theme: panel.theme; text: panel.restoring && panel.restoring.ok ? "Cancel" : "Close"; onClicked: panel.restoring = null }
            }
          }
          // Just put back: open one.
          Repeater {
            model: panel.restored
            delegate: Line {
              required property var modelData
              objectName: "restoredProfile"
              label: "“" + modelData.name + "” is back"
              note: modelData.folder
              TextButton {
                objectName: "restoredOpen"
                theme: panel.theme
                text: "Open it"
                onClicked: { panel.close(); panel.profiles.use(modelData.id) }
              }
            }
          }
          Repeater {
            model: panel.backups ? panel.backups.list.slice(0, 8) : []
            delegate: Line {
              required property var modelData
              objectName: "backupRow"
              label: modelData.name.replace(/\.tar\.gz$/, "")
              note: (panel.theme.twelveHour, panel.whenLabel(modelData.time)) + " · " + Backups.sizeLabel(modelData.size) + (modelData.automatic ? " · automatic" : "")
              TextButton {
                objectName: "backupRestore"
                theme: panel.theme
                text: "Restore…"
                onClicked: panel.askRestore(modelData.path)
              }
            }
          }
          Line {
            label: panel.backups && panel.backups.list.length ? "Another backup" : "No backups here yet"
            note: "A backup from another folder or another computer."
            TextButton {
              objectName: "restoreFromFile"
              theme: panel.theme
              text: "Choose a file…"
              onClicked: panel.chooseBackup()
            }
          }
        }

        // ======== About ========

        Group {
          visible: panel.section === "about"
          title: "Updates"
          Line {
            objectName: "updateStatus"
            label: "Uber Notebook " + (panel.service ? panel.service.version : "")
            note: panel.updateNote
            noteColor: panel.updates && panel.updates.status === "failed" ? panel.theme.urgent : panel.theme.muted
            Row {
              spacing: 6
              TextButton {
                objectName: "updateNotes"
                visible: panel.updates !== null && panel.updates.available
                theme: panel.theme
                primary: true
                text: "What's new"
                onClicked: panel.releaseNotesRequested(false)
              }
              TextButton {
                objectName: "updateCheck"
                theme: panel.theme
                text: panel.updates && panel.updates.status === "checking" ? "Checking…" : "Check now"
                onClicked: if (panel.updates) panel.updates.check()
              }
            }
          }
          Line {
            label: "Check for updates automatically"
            note: "Once a day, Uber Notebook asks GitHub for its newest version. Nothing of yours goes with it."
            Toggle { objectName: "updateAuto"; theme: panel.theme; checked: panel.s.checkUpdates !== false; onToggled: function(on) { panel.set("checkUpdates", on) } }
          }
          Line {
            label: "Release notes"
            note: "What's in the version you have."
            TextButton {
              objectName: "releaseNotesOpen"
              theme: panel.theme
              text: "Read"
              onClicked: panel.releaseNotesRequested(true)
            }
          }
        }

        Group {
          visible: panel.section === "about"
          title: "Contact"
          Line {
            label: "Follow me on X"
            note: "@devsec_ai: news, what's next, and a place to say hello."
            TextButton {
              objectName: "aboutX"
              theme: panel.theme
              xMark: true
              text: "@devsec_ai"
              onClicked: if (panel.service && panel.service.store) panel.service.store.openUrl("https://x.com/devsec_ai")
            }
          }
          Line {
            visible: panel.updates !== null && panel.updates.homepage !== ""
            label: "Project page"
            note: panel.updates ? panel.updates.homepage.replace(/^https:\/\//, "") : ""
            TextButton {
              theme: panel.theme
              icon: panel.theme.icons.openExternal
              text: "Open"
              onClicked: panel.service.store.openUrl(panel.updates.homepage)
            }
          }
        }

        Group {
          visible: panel.section === "about"
          title: "Your notes"
          Line {
            label: "On your computer"
            note: "Every notebook is a folder of plain JSON files; pictures are copied in beside them. Nothing leaves your computer but the update check, which only asks GitHub for the newest version."
          }
        }
      }
    }
  }
}
