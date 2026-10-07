import QtQuick
import QtQuick.Controls
import "../Meeting.js" as Meeting
import "../Audio.js" as Audio
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// A meeting on a page in Pages, recorded by voxtype's meeting mode: your
// microphone and what the computer plays (the other side of a call). Before
// it starts: Start (or turning meeting mode on in voxtype, or bringing in
// one voxtype recorded). While it records: the time, Pause and Resume, Stop.
// voxtype writes it out when it ends; then it's who said what, turn by
// turn, each speaker in a color, a click on a name to name them ("Remote"
// as "Sam"). Summarize asks your agent for the summary, the decisions and
// the to-dos, on the page under it. Its colors (its own, the card's) are
// Pages' colors or your own.
Item {
  id: mb

  property var editor: null
  property string uid: ""
  // The meeting as the page has it (JSON).
  property string source: ""
  property real available: 600
  property color ink: "black"
  readonly property bool readOnly: editor ? editor.readOnly : true
  readonly property var theme: editor ? editor.theme : null
  readonly property bool dark: editor ? editor.dark : false
  readonly property var meetings: editor ? editor.meetings : null

  property var meeting: Meeting.make()
  property string written: ""
  property var trying: null
  readonly property var look: trying || meeting
  property bool showAll: false

  onSourceChanged: if (source !== written) load()
  Component.onCompleted: { load(); askIfDone() }

  function load() {
    var m = null
    try { m = Meeting.clean(JSON.parse(source)) } catch (e) { m = null }
    written = source
    meeting = m || Meeting.make()
  }

  // A change kept, as a step to undo.
  function change(fields) {
    var next = JSON.parse(JSON.stringify(meeting))
    for (var k in fields) next[k] = fields[k]
    var clean = Meeting.clean(next)
    if (!clean) return
    written = JSON.stringify(clean)
    meeting = clean
    editor.setMeeting(uid, clean)
  }

  // ---- where it is -------------------------------------------------------------------------

  readonly property bool started: meeting.id !== ""
  readonly property bool live: meetings !== null && started && meetings.meetingId === meeting.id && meetings.status !== "idle"
  readonly property bool paused: live && meetings.status === "paused"
  readonly property bool finishing: started && meetings !== null && (meetings.finishing === meeting.id || editor.meetingWork[uid] === true)
  readonly property bool done: started && !live && !finishing
  readonly property var turns: Meeting.turns(meeting)
  readonly property var speakerList: Meeting.speakers(meeting)

  // A meeting that ended while it wasn't shown (Uber Notebook wasn't running, or
  // it was stopped elsewhere): its transcript, from voxtype.
  function askIfDone() {
    if (done && meeting.segments.length === 0 && !readOnly && meetings && meetings.known) Qt.callLater(function() { if (mb.editor) mb.editor.meetingAction(mb.uid, "autofetch", null) })
  }
  onLiveChanged: askIfDone()
  Connections { target: mb.meetings; function onKnownChanged() { mb.askIfDone() } }

  // The time it's been going.
  property real now: Date.now()
  Timer { interval: 1000; repeat: true; running: mb.live && !mb.paused; onTriggered: mb.now = Date.now() }
  readonly property real elapsed: meeting.startedAt ? Math.max(0, (now - Date.parse(meeting.startedAt)) / 1000) : 0

  // ---- colors ----------------------------------------------------------------------------

  function textOf(id) { var c = Docs.colorEntry(id); return c ? c.text[dark ? 1 : 0] : Colors.normalize(id) }
  function backOf(id) { var c = Docs.colorEntry(id); return c ? c.background[dark ? 1 : 0] : Colors.normalize(id) }
  readonly property string inkHex: Colors.normalize(String(ink)) || "#000000"
  readonly property string paperHex: Colors.normalize(String(editor ? editor.paper : "#ffffff")) || "#ffffff"
  readonly property color tint: look.color ? textOf(look.color) : (editor ? editor.accent : "#2456b3")
  readonly property string fillHex: look.background ? backOf(look.background) : ""
  readonly property color fill: fillHex ? fillHex : Qt.alpha(ink, dark ? 0.06 : 0.035)
  readonly property color words: fillHex && Colors.isHex(look.background) ? Colors.readableOn(fillHex, inkHex) : ink
  readonly property color faint: Qt.alpha(words, 0.55)
  readonly property color red: dark ? "#ff6b6b" : "#e5484d"
  readonly property string markInk: Colors.contrast(Colors.normalize(String(tint)) || "#2456b3", "#ffffff") >= 2.6 ? "#ffffff" : "#14161c"
  // Each speaker's color: you in the meeting's, the others in Pages' colors.
  readonly property var others: ["purple", "green", "orange", "pink", "brown", "red", "yellow", "gray"]
  function speakerColor(speaker) {
    // (With no "You", voxtype's first speaker has the meeting's color.)
    var mine = speakerList.indexOf("You") >= 0 ? "You" : speakerList[0]
    if (speaker === mine) return tint
    var k = speakerList.filter(function(s) { return s !== mine }).indexOf(speaker)
    return textOf(others[Math.max(0, k) % others.length])
  }

  function askColors(anchor) { if (!readOnly) editor.meetingColorsRequested(uid, anchor) }
  function scopeColors() { return { color: meeting.color, background: meeting.background } }
  function colorInfo() {
    return { text: meeting.title || "Meeting", fill: meeting.background ? backOf(meeting.background) : paperHex,
      ownInk: meeting.color ? textOf(meeting.color) : "", pageInk: inkHex }
  }
  function previewColor(kind, value) {
    var t = { color: meeting.color, background: meeting.background }
    t[kind === "background" ? "background" : "color"] = value
    trying = t
  }
  function applyColor(kind, value) {
    trying = null
    var f = {}
    f[kind === "background" ? "background" : "color"] = value
    change(f)
  }
  function cancelColor() { trying = null }
  function colorsClosed(refocus) { trying = null }

  // A speaker named ("" puts voxtype's name back).
  function nameSpeaker(speaker, name) {
    var names = JSON.parse(JSON.stringify(meeting.names))
    var n = String(name || "").replace(/\s+/g, " ").trim()
    if (n && n !== speaker) names[speaker] = n
    else delete names[speaker]
    change({ names: names })
  }

  function act(what) { editor.meetingAction(uid, what, null) }

  readonly property string whenText: {
    if (!meeting.startedAt) return ""
    var d = new Date(meeting.startedAt)
    return Qt.formatDateTime(d, "ddd d MMM, HH:mm")
  }
  readonly property string whoText: {
    var names = speakerList.map(function(s) { return Meeting.speakerName(mb.meeting, s) })
    return names.length === 0 ? "" : names.length === 1 ? names[0] : names.slice(0, -1).join(", ") + " and " + names[names.length - 1]
  }

  // ---- the card ----------------------------------------------------------------------------

  width: available
  height: card.height

  readonly property bool pointerIn: hover.hovered
  HoverHandler { id: hover }

  Rectangle {
    id: card
    width: mb.width
    height: head.height + (lower.visible ? lower.height : 0)
    radius: 12
    color: mb.fill
    border.width: 1
    border.color: mb.live ? Qt.alpha(mb.red, 0.55) : Qt.alpha(mb.words, mb.pointerIn ? 0.14 : 0.08)
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Item {
      id: head
      width: parent.width
      // Narrow (a column): the buttons on a line of their own, under the words.
      readonly property bool narrow: width < 12 + 38 + 14 + 150 + tools.oneLine + 10
      // Narrower still: the words under the badge too.
      readonly property bool tiny: width < 12 + 38 + 14 + 120
      height: !narrow ? 64 : (tiny ? 13 + 38 + 8 + headWords.implicitHeight : Math.max(64, headWords.implicitHeight + 24)) + tools.height + 10

      Rectangle {
        id: badge
        x: 12
        y: head.narrow ? 13 : (64 - height) / 2
        width: 38
        height: 38
        radius: 19
        color: mb.live ? (mb.paused ? Qt.alpha(mb.words, 0.25) : mb.red) : mb.tint
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: mb.theme ? (mb.paused ? mb.theme.icons.pause : mb.theme.icons.people) : ""
          font.family: mb.theme ? mb.theme.iconFont : ""
          font.pixelSize: 19
          color: mb.live ? "white" : mb.markInk
        }
        SequentialAnimation on opacity {
          running: mb.live && !mb.paused
          loops: Animation.Infinite
          NumberAnimation { to: 0.55; duration: 900; easing.type: Easing.InOutSine }
          NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
        }
      }

      Column {
        id: headWords
        objectName: "meetingWords"
        x: head.tiny ? 12 : badge.x + badge.width + 14
        y: head.tiny ? badge.y + badge.height + 8 : head.narrow ? 12 : (64 - height) / 2
        width: head.narrow ? head.width - x - 12 : Math.max(60, tools.x - x - 10)
        spacing: 2
        Text {
          objectName: "meetingHeadline"
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: !mb.started ? (mb.readOnly ? "A meeting, not recorded" : "Record a meeting")
            : mb.live ? (mb.paused ? "Paused" : "Recording") + "  \u00b7  " + Audio.clock(mb.elapsed)
            : mb.finishing ? "Writing it out\u2026"
            : (mb.meeting.title || "Meeting")
          font.family: mb.editor ? mb.editor.uiFamily : ""
          font.pixelSize: 14
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
          color: mb.live && !mb.paused ? mb.red : mb.words
        }
        Text {
          objectName: "meetingNote"
          width: parent.width
          elide: Text.ElideRight
          // (Waiting for voxtype: what to do, in full.)
          wrapMode: Text.Wrap
          maximumLineCount: 3
          textFormat: Text.PlainText
          text: {
            var m = mb.meetings
            if (!mb.started) {
              if (m && m.checked && !m.available) return "Meetings need voxtype, Omarchy's dictation (omarchy voxtype install)"
              if (m && m.checked && !m.enabled) return "voxtype's meeting mode is off: turn it on to record meetings"
              if (m && m.enabled && m.waiting) return m.waitingText
              if (m && m.status !== "idle") return "voxtype is recording another meeting"
              return "Your microphone and the other side of a call. voxtype writes out who said what when it ends"
            }
            if (mb.live) return (mb.meeting.title ? mb.meeting.title + "  \u00b7  " : "") + "voxtype writes it out when it ends"
            if (mb.finishing) return "voxtype is writing out the last of it"
            var parts = []
            if (mb.whenText) parts.push(mb.whenText)
            if (mb.meeting.duration) parts.push(Audio.clock(mb.meeting.duration))
            if (mb.whoText) parts.push(mb.whoText)
            if (mb.meeting.segments.length === 0) parts.push("nothing written out")
            else parts.push(Meeting.wordCount(mb.meeting) + " words")
            return parts.join("  \u00b7  ")
          }
          font.family: mb.editor ? mb.editor.uiFamily : ""
          font.pixelSize: 12
          color: mb.faint
        }
      }

      Flow {
        id: tools
        objectName: "meetingTools"
        // (On one line; narrow, as many lines as it takes.)
        readonly property real oneLine: { var w = 0, n = 0; for (var i = 0; i < children.length; i++) if (children[i].visible) { w += children[i].width; n++ } return w + Math.max(0, n - 1) * spacing }
        width: head.narrow ? Math.min(oneLine, head.width - 24) : oneLine
        x: head.narrow ? 12 : head.width - width - 10
        y: head.narrow ? head.height - height - 10 : (64 - height) / 2
        spacing: 4

        // Not started: bring one in, turn meeting mode on, start.
        IconButton {
          objectName: "meetingImport"
          visible: !mb.started && !mb.readOnly && mb.meetings !== null && mb.meetings.available
          theme: mb.theme; icon: mb.theme ? mb.theme.icons.history : ""; label: head.tiny ? "" : "Bring one in"; size: 30; iconSize: 14; tint: mb.words
          tip: "A meeting voxtype recorded, put here"
          onClicked: mb.act("import")
        }
        Pill {
          objectName: "meetingEnable"
          visible: !mb.started && !mb.readOnly && mb.meetings !== null && mb.meetings.available && mb.meetings.checked && !mb.meetings.enabled
          label: mb.meetings && mb.meetings.working === "enable" ? "Turning it on\u2026" : "Turn on meeting mode"
          fillColor: mb.tint
          tip: "Sets meeting.enabled in voxtype's settings; it takes effect when voxtype restarts"
          onClicked: if (!mb.meetings.working) mb.act("enable")
        }
        Pill {
          objectName: "meetingStart"
          visible: !mb.started && !mb.readOnly && mb.meetings !== null && mb.meetings.enabled && !mb.meetings.waiting
          label: mb.meetings && mb.meetings.working === "start" ? "Starting\u2026" : "Start"
          fillColor: mb.red
          tip: "Start recording the meeting"
          onClicked: if (!mb.meetings.working) mb.act("start")
        }
        // Recording: pause or go on, stop.
        IconButton {
          objectName: "meetingPause"
          visible: mb.live && !mb.readOnly
          theme: mb.theme; icon: mb.theme ? (mb.paused ? mb.theme.icons.play : mb.theme.icons.pause) : ""; size: 32; iconSize: 17; tint: mb.words
          tip: mb.paused ? "Go on recording" : "Pause (what's said meanwhile isn't recorded)"
          onClicked: mb.act(mb.paused ? "resume" : "pause")
        }
        Pill {
          objectName: "meetingStop"
          visible: mb.live && !mb.readOnly
          label: "Stop"
          fillColor: mb.red
          tip: "End the meeting: voxtype writes it out"
          onClicked: mb.act("stop")
        }
        // Done: what it was, summarized; who said what, shown or not; its colors.
        IconButton {
          objectName: "meetingFetch"
          visible: mb.done && mb.meeting.segments.length === 0 && !mb.readOnly
          theme: mb.theme; icon: mb.theme ? mb.theme.icons.restore : ""; label: head.tiny ? "" : "Get it again"; size: 30; iconSize: 14; tint: mb.words
          tip: "Ask voxtype for what it wrote out"
          onClicked: mb.act("fetch")
        }
        IconButton {
          objectName: "meetingSummarize"
          visible: mb.done && mb.meeting.segments.length > 0 && !mb.readOnly
          theme: mb.theme; icon: mb.theme ? mb.theme.icons.agent : ""; label: "Summarize"; size: 30; iconSize: 15; tint: mb.words
          tip: "Your agent writes the summary, the decisions and the to-dos under it"
          onClicked: mb.act("summarize")
        }
        IconButton {
          objectName: "meetingTranscript"
          visible: mb.done && mb.meeting.segments.length > 0
          theme: mb.theme; icon: mb.theme ? mb.theme.icons.transcript : ""; size: 30; iconSize: 15; tint: mb.words
          checked: mb.meeting.open
          tip: mb.meeting.open ? "Hide who said what" : "Show who said what"
          onClicked: mb.change({ open: !mb.meeting.open })
        }
        IconButton {
          id: colorButton
          objectName: "meetingColors"
          visible: !mb.live && !mb.readOnly && (mb.pointerIn || mb.trying !== null)
          theme: mb.theme; icon: mb.theme ? mb.theme.icons.palette : ""; size: 30; iconSize: 15; tint: mb.words
          tip: "Its colors"
          onClicked: mb.askColors(colorButton)
        }
      }
    }

    // Who said what, turn by turn.
    Item {
      id: lower
      visible: mb.done && mb.meeting.open && mb.meeting.segments.length > 0
      y: head.height
      width: parent.width
      height: sep.height + 12 + turnsCol.height + 14
      Rectangle { id: sep; x: 14; width: parent.width - 28; height: 1; color: Qt.alpha(mb.words, 0.09) }
      Column {
        id: turnsCol
        x: 16
        y: sep.height + 12
        width: parent.width - 32
        spacing: 12
        Repeater {
          model: mb.showAll || mb.turns.length <= 40 ? mb.turns : mb.turns.slice(0, 30)
          delegate: Column {
            id: turn
            required property var modelData
            width: turnsCol.width
            spacing: 2
            Row {
              spacing: 8
              Rectangle {
                id: chip
                objectName: "speakerChip"
                readonly property string speaker: turn.modelData.speaker
                width: chipText.implicitWidth + 14
                height: 22
                radius: 11
                color: Qt.alpha(mb.speakerColor(speaker), chipHover.hovered && !mb.readOnly ? 0.22 : 0.14)
                Text {
                  id: chipText
                  anchors.centerIn: parent
                  textFormat: Text.PlainText
                  text: Meeting.speakerName(mb.meeting, chip.speaker)
                  font.family: mb.editor ? mb.editor.uiFamily : ""
                  font.pixelSize: 12
                  font.weight: Font.DemiBold
                  color: mb.speakerColor(chip.speaker)
                }
                HoverHandler { id: chipHover; cursorShape: mb.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor }
                TapHandler { enabled: !mb.readOnly; onTapped: namePop.openFor(chip, chip.speaker) }
                ToolTip.visible: chipHover.hovered && !mb.readOnly
                ToolTip.delay: 700
                ToolTip.text: "Name them"
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: Audio.clock(turn.modelData.start / 1000)
                font.family: mb.editor ? mb.editor.uiFamily : ""
                font.pixelSize: 11
                font.features: { "tnum": 1 }
                color: mb.faint
              }
            }
            TextEdit {
              width: parent.width
              readOnly: true
              selectByMouse: true
              textFormat: TextEdit.PlainText
              wrapMode: TextEdit.Wrap
              text: turn.modelData.text
              font.family: mb.editor ? mb.editor.family : ""
              font.pixelSize: 15
              color: mb.words
              selectionColor: mb.editor ? mb.editor.selectionColor : "#88aaff"
            }
          }
        }
        IconButton {
          objectName: "meetingShowAll"
          visible: !mb.showAll && mb.turns.length > 40
          theme: mb.theme; icon: mb.theme ? mb.theme.icons.down : ""; label: "Show all " + mb.turns.length + " turns"; size: 30; iconSize: 14; tint: mb.words
          onClicked: mb.showAll = true
        }
      }
    }
  }

  // A filled button with words ("Start", "Stop").
  component Pill: Rectangle {
    id: pill
    property string label: ""
    property color fillColor: "gray"
    property string tip: ""
    signal clicked()
    width: pillText.implicitWidth + 26
    height: 32
    radius: 16
    color: pillHover.hovered ? Qt.darker(fillColor, 1.08) : fillColor
    scale: pillTap.pressed ? 0.96 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Text {
      id: pillText
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: pill.label
      font.family: mb.editor ? mb.editor.uiFamily : ""
      font.pixelSize: 13
      font.weight: Font.DemiBold
      color: Colors.contrast(Colors.normalize(String(pill.fillColor)) || "#2456b3", "#ffffff") >= 2.6 ? "white" : "#14161c"
    }
    HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { id: pillTap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: pill.clicked() }
    ToolTip.visible: pillHover.hovered && pill.tip !== ""
    ToolTip.delay: 600
    ToolTip.text: pill.tip
  }

  // A speaker's name, typed.
  Pop {
    id: namePop
    theme: mb.theme
    width: 240
    property string speaker: ""
    function openFor(anchor, speaker) {
      namePop.speaker = speaker
      parent = anchor
      x = 0
      y = anchor.height + 6
      nameField.text = Meeting.speakerName(mb.meeting, speaker)
      open()
      nameField.focusField()
    }
    contentItem: Column {
      spacing: 6
      Text {
        textFormat: Text.PlainText
        text: "Who's " + (namePop.speaker === "You" ? "\u201cYou\u201d" : "this") + "?"
        font.family: mb.theme ? mb.theme.uiFont : ""
        font.pixelSize: 12
        color: mb.theme ? mb.theme.muted : "gray"
      }
      Field {
        id: nameField
        objectName: "speakerName"
        theme: mb.theme
        width: parent.width
        height: 34
        placeholder: namePop.speaker
        onAccepted: { mb.nameSpeaker(namePop.speaker, text); namePop.close() }
        onEscaped: namePop.close()
      }
    }
  }
}
