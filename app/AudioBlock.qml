import QtQuick
import QtQuick.Controls
import QtMultimedia
import "../Audio.js" as Audio
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// An audio note on a page in Pages: a card with a button to record (then
// to stop, with the time and the level as it records), and once it's
// recorded, a player: play and pause, the waveform (the part played in the
// note's color; a click or a drag goes there), the time, and the speed. What
// was said is under it, written out by voxtype (as it's recorded, as
// Settings has it, or with "Write it out"), to read, search and correct.
// Its colors (the player's and the card's) are Pages' colors or your own.
// Enter or Space stops a recording, Esc throws it away. A locked page's
// note only plays.
Item {
  id: au

  property var editor: null
  // The block it's in (DocBlock).
  property var host: null
  property string uid: ""
  // The note as the page has it (JSON).
  property string source: ""
  property real available: 600
  property color ink: "black"
  readonly property bool readOnly: editor ? editor.readOnly : true
  readonly property var theme: editor ? editor.theme : null
  readonly property bool dark: editor ? editor.dark : false
  readonly property var recorder: editor ? editor.recorder : null

  property var audio: Audio.make()
  property string written: ""
  // Colors shown while they're picked (not kept yet): { color, background }.
  property var trying: null
  readonly property var look: trying || audio

  onSourceChanged: if (source !== written) load()
  Component.onCompleted: load()

  function load() {
    var a = null
    try { a = Audio.clean(JSON.parse(source)) } catch (e) { a = null }
    written = source
    var was = audio.src
    audio = a || Audio.make()
    if (audio.src !== was) { player.stop(); player.source = "" }
    if (!transcriptEdit.activeFocus) transcriptEdit.text = audio.transcript
  }

  // A change kept, as a step to undo.
  function change(fields) {
    var next = JSON.parse(JSON.stringify(audio))
    for (var k in fields) next[k] = fields[k]
    var clean = Audio.clean(next)
    if (!clean) return
    written = JSON.stringify(clean)
    audio = clean
    editor.setAudio(uid, clean)
  }

  // ---- where it is -----------------------------------------------------------------------

  readonly property bool hasFile: audio.src !== ""
  readonly property bool recordingHere: recorder !== null && recorder.kind === "audio" && recorder.owner === uid && recorder.busy
  readonly property bool writingOut: editor !== null && editor.audioWork[uid] === "transcribe"
  readonly property bool makingLouder: editor !== null && editor.audioWork[uid] === "louder"
  readonly property bool quiet: Audio.isQuiet(audio.peaks)
  readonly property bool canTranscribe: recorder !== null && recorder.canTranscribe
  readonly property bool transcriptShown: audio.open && (audio.transcript !== "" || writingOut)

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
  readonly property color recordRed: dark ? "#ff6b6b" : "#e5484d"
  // The button's mark: on the note's color, whichever of white and black reads.
  readonly property string markInk: Colors.contrast(Colors.normalize(String(tint)) || "#2456b3", "#ffffff") >= 2.6 ? "#ffffff" : "#14161c"

  // DocView's color menu and picker, for it.
  function askColors(anchor) {
    if (readOnly) return
    editor.audioColorsRequested(uid, anchor)
  }
  function scopeColors() { return { color: audio.color, background: audio.background } }
  // What the color picker shows as the sample: { text, fill, ownInk, pageInk }.
  function colorInfo() {
    return { text: audio.transcript.replace(/\s+/g, " ").trim().slice(0, 24) || "Audio note", fill: audio.background ? backOf(audio.background) : paperHex,
      ownInk: audio.color ? textOf(audio.color) : "", pageInk: inkHex }
  }
  function previewColor(kind, value) {
    var t = { color: audio.color, background: audio.background }
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

  // ---- playing -----------------------------------------------------------------------------

  readonly property var speeds: [1, 1.25, 1.5, 2]
  property int speedAt: 0
  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  readonly property real total: audio.duration > 0 ? audio.duration : player.duration / 1000
  // Where it is (s): the player's, or where a click put it before it loaded.
  property real seekTo: -1
  readonly property real at: seekTo >= 0 ? seekTo : player.position / 1000
  readonly property real played: total > 0 ? Math.max(0, Math.min(1, at / total)) : 0
  readonly property bool missing: player.error !== MediaPlayer.NoError

  function load_() {
    if (player.source.toString() === "" && hasFile) player.source = editor.assetUrl(audio.src)
  }
  function toggle() {
    if (!hasFile) return
    if (playing) { player.pause(); return }
    load_()
    if (editor) editor.playingUid = uid
    if (at >= total - 0.05) seek(0)
    player.play()
  }
  function seek(seconds) {
    var s = Math.max(0, Math.min(total, seconds))
    load_()
    seekTo = s
    if (player.mediaStatus === MediaPlayer.LoadedMedia || player.mediaStatus === MediaPlayer.BufferedMedia || player.mediaStatus === MediaPlayer.EndOfMedia || playing) {
      player.position = Math.round(s * 1000)
      seekTo = -1
    }
  }

  MediaPlayer {
    id: player
    audioOutput: AudioOutput {}
    playbackRate: au.speeds[au.speedAt]
    onMediaStatusChanged: {
      if ((mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) && au.seekTo >= 0) {
        position = Math.round(au.seekTo * 1000)
        au.seekTo = -1
      }
      if (mediaStatus === MediaPlayer.EndOfMedia) au.seekTo = 0
    }
  }
  Connections {
    target: au.editor
    function onPlayingUidChanged() { if (au.editor.playingUid !== au.uid && au.playing) player.pause() }
  }

  // ---- recording ---------------------------------------------------------------------------

  // The keys while it records: Enter or Space stop, Esc throws it away.
  function takeKeys() { keys.forceActiveFocus() }
  Item {
    id: keys
    Keys.onPressed: function(e) {
      if (!au.recordingHere) return
      if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space) { e.accepted = true; au.editor.audioAction(au.uid, "stop") }
      else if (e.key === Qt.Key_Escape) { e.accepted = true; au.editor.audioAction(au.uid, "cancel") }
    }
  }
  onRecordingHereChanged: if (recordingHere) takeKeys()

  function mainClicked() {
    if (recordingHere) { if (recorder.phase === "recording") editor.audioAction(uid, "stop"); return }
    if (hasFile) { toggle(); return }
    if (!readOnly) editor.audioAction(uid, "record")
  }

  // ---- the card ----------------------------------------------------------------------------

  width: available
  height: card.height

  readonly property bool pointerIn: hover.hovered
  HoverHandler { id: hover }

  Rectangle {
    id: card
    width: au.width
    height: head.height + (au.transcriptShown ? lower.height : 0)
    radius: 12
    color: au.fill
    border.width: 1
    border.color: au.recordingHere ? Qt.alpha(au.recordRed, 0.55) : Qt.alpha(au.words, au.pointerIn ? 0.14 : 0.08)
    Behavior on border.color { ColorAnimation { duration: 150 } }

    Item {
      id: head
      width: parent.width
      height: 60

      // Record, stop, play or pause.
      Rectangle {
        id: mainButton
        objectName: "audioMain"
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 38
        height: 38
        radius: 19
        readonly property bool red: au.recordingHere || !au.hasFile
        color: !au.hasFile && !au.recordingHere && (au.readOnly || (au.recorder && !au.recorder.canRecord)) ? Qt.alpha(au.words, 0.15)
          : red ? au.recordRed : au.tint
        opacity: mainHover.hovered ? 0.88 : 1
        scale: mainTap.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }
        // Recording: a square to stop. Not yet: a dot. Else play or pause.
        Rectangle {
          visible: au.recordingHere
          anchors.centerIn: parent
          width: 13
          height: 13
          radius: 3
          color: "white"
        }
        Rectangle {
          visible: !au.recordingHere && !au.hasFile
          anchors.centerIn: parent
          width: 14
          height: 14
          radius: 7
          color: "white"
        }
        Text {
          visible: !au.recordingHere && au.hasFile
          anchors.centerIn: parent
          anchors.horizontalCenterOffset: au.playing ? 0 : 1.5
          textFormat: Text.PlainText
          text: au.theme ? (au.playing ? au.theme.icons.pause : au.theme.icons.play) : ""
          font.family: au.theme ? au.theme.iconFont : ""
          font.pixelSize: 22
          color: au.markInk
        }
        HoverHandler { id: mainHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { id: mainTap; gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: au.mainClicked() }
        ToolTip.visible: mainHover.hovered
        ToolTip.delay: 600
        ToolTip.text: au.recordingHere ? "Stop  (Enter)" : au.hasFile ? (au.playing ? "Pause" : "Play") : au.recorder && !au.recorder.canRecord ? "Recording needs ffmpeg" : "Record"
      }

      // Not recorded yet: what it is.
      Column {
        visible: !au.hasFile && !au.recordingHere
        x: mainButton.x + mainButton.width + 14
        anchors.verticalCenter: parent.verticalCenter
        width: tools.x - x - 8
        spacing: 2
        Text {
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: au.readOnly ? "An audio note, not recorded" : "Record an audio note"
          font.family: au.editor ? au.editor.uiFamily : ""
          font.pixelSize: 14
          font.weight: Font.DemiBold
          color: au.words
        }
        Text {
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: au.recorder && !au.recorder.canRecord ? "Recording needs ffmpeg"
            : au.canTranscribe ? "Click to start. What you say is written out under it (voxtype)" : "Click to start"
          font.family: au.editor ? au.editor.uiFamily : ""
          font.pixelSize: 12
          color: au.faint
        }
      }

      // Recording: the time, and the level as it goes.
      Row {
        id: recInfo
        visible: au.recordingHere
        x: mainButton.x + mainButton.width + 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 9
          height: 9
          radius: 4.5
          color: au.recordRed
          SequentialAnimation on opacity {
            running: au.recordingHere && au.recorder.phase === "recording"
            loops: Animation.Infinite
            NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
          }
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: au.recordingHere && au.recorder.phase !== "recording" ? "Saving\u2026" : Audio.clock(au.recorder ? au.recorder.elapsed : 0)
          font.family: au.editor ? au.editor.uiFamily : ""
          font.pixelSize: 14
          font.weight: Font.DemiBold
          font.features: { "tnum": 1 }
          color: au.words
        }
      }

      // The waveform: as it records (the newest at the right), or the
      // recording's, the part played in its color.
      Item {
        id: wave
        objectName: "audioWave"
        readonly property real startX: au.recordingHere ? recInfo.x + recInfo.width + 16 : mainButton.x + mainButton.width + 14
        visible: au.recordingHere || au.hasFile
        x: startX
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(40, timeText.x - startX - 14)
        height: 30
        readonly property int count: Math.max(8, Math.floor(width / 5))
        readonly property var bars: au.recordingHere ? (au.recorder ? au.recorder.recent.map(function(v) { return Math.round(v * 100) }).slice(-count) : [])
          : Audio.fit(au.audio.peaks.length ? au.audio.peaks : [8], count)
        Row {
          anchors.right: au.recordingHere ? parent.right : undefined
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          Repeater {
            model: wave.bars
            delegate: Rectangle {
              required property var modelData
              required property int index
              anchors.verticalCenter: parent ? parent.verticalCenter : undefined
              width: 3
              height: Math.max(3, wave.height * modelData / 100)
              radius: 1.5
              color: au.recordingHere ? au.recordRed
                : (index + 0.5) / wave.bars.length <= au.played && (au.playing || au.at > 0) ? au.tint : Qt.alpha(au.words, 0.25)
            }
          }
        }
        Text {
          visible: au.missing && au.hasFile && !au.recordingHere
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: "The recording isn't there any more"
          font.family: au.editor ? au.editor.uiFamily : ""
          font.pixelSize: 12
          color: au.faint
        }
        HoverHandler { cursorShape: au.hasFile && !au.recordingHere ? Qt.PointingHandCursor : Qt.ArrowCursor }
        TapHandler {
          enabled: au.hasFile && !au.recordingHere
          onTapped: function(p) { au.seek(au.total * Math.max(0, Math.min(1, p.position.x / wave.width))) }
        }
        DragHandler {
          enabled: au.hasFile && !au.recordingHere
          target: null
          xAxis.enabled: true
          yAxis.enabled: false
          onCentroidChanged: if (active) au.seek(au.total * Math.max(0, Math.min(1, centroid.position.x / wave.width)))
        }
      }

      Text {
        id: timeText
        visible: au.hasFile && !au.recordingHere
        anchors.right: tools.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: (au.playing || au.at > 0 ? Audio.clock(au.at) + " / " : "") + Audio.clock(au.total)
        font.family: au.editor ? au.editor.uiFamily : ""
        font.pixelSize: 12
        font.features: { "tnum": 1 }
        color: au.faint
      }

      // Its tools: the speed, what was said, its colors; while it records, throwing it away.
      Row {
        id: tools
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton {
          objectName: "audioCancel"
          visible: au.recordingHere && au.recorder.phase === "recording"
          theme: au.theme; icon: au.theme ? au.theme.icons.close : ""; size: 30; iconSize: 15; tint: au.words
          tip: "Throw it away  (Esc)"
          onClicked: au.editor.audioAction(au.uid, "cancel")
        }
        // The speed.
        Rectangle {
          id: speedChip
          objectName: "audioSpeed"
          visible: au.hasFile && !au.recordingHere
          anchors.verticalCenter: parent.verticalCenter
          width: speedText.implicitWidth + 14
          height: 24
          radius: 6
          color: speedHover.hovered ? Qt.alpha(au.words, 0.09) : "transparent"
          Text {
            id: speedText
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: au.speeds[au.speedAt] + "\u00d7"
            font.family: au.editor ? au.editor.uiFamily : ""
            font.pixelSize: 12
            font.weight: au.speedAt > 0 ? Font.DemiBold : Font.Normal
            color: au.speedAt > 0 ? au.tint : au.faint
          }
          HoverHandler { id: speedHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: au.speedAt = (au.speedAt + 1) % au.speeds.length }
          ToolTip.visible: speedHover.hovered
          ToolTip.delay: 600
          ToolTip.text: "Speed"
        }
        // A quiet recording (one made before "Make my voice louder"): louder.
        IconButton {
          objectName: "audioLouder"
          visible: au.hasFile && !au.recordingHere && (au.quiet || au.makingLouder) && !au.readOnly
          active: !au.makingLouder
          theme: au.theme; icon: au.theme ? au.theme.icons.volume : ""; label: au.makingLouder ? "Making it louder\u2026" : "Louder"; size: 30; iconSize: 15; tint: au.words
          tip: "It's quiet: make it louder (your voice evened out; Undo takes it back)"
          onClicked: au.editor.audioAction(au.uid, "louder")
        }
        IconButton {
          objectName: "audioWriteOut"
          visible: au.hasFile && !au.recordingHere && au.audio.transcript === "" && !au.writingOut && au.canTranscribe && !au.readOnly
          theme: au.theme; icon: au.theme ? au.theme.icons.transcript : ""; label: "Write it out"; size: 30; iconSize: 15; tint: au.words
          tip: "Write out what was said (voxtype)"
          onClicked: au.editor.audioAction(au.uid, "transcribe")
        }
        IconButton {
          objectName: "audioTranscript"
          visible: au.hasFile && !au.recordingHere && au.audio.transcript !== ""
          theme: au.theme; icon: au.theme ? au.theme.icons.transcript : ""; size: 30; iconSize: 15; tint: au.words
          checked: au.audio.open
          tip: au.audio.open ? "Hide what was said" : "Show what was said"
          onClicked: au.change({ open: !au.audio.open })
        }
        IconButton {
          id: colorButton
          objectName: "audioColors"
          visible: !au.recordingHere && !au.readOnly && (au.pointerIn || au.trying !== null)
          theme: au.theme; icon: au.theme ? au.theme.icons.palette : ""; size: 30; iconSize: 15; tint: au.words
          tip: "Its colors"
          onClicked: au.askColors(colorButton)
        }
      }
    }

    // What was said.
    Item {
      id: lower
      y: head.height
      width: parent.width
      height: au.transcriptShown ? sep.height + 10 + body.height + 14 : 0
      visible: au.transcriptShown
      Rectangle { id: sep; x: 14; width: parent.width - 28; height: 1; color: Qt.alpha(au.words, 0.09) }
      Item {
        id: body
        x: 16
        y: sep.height + 10
        width: parent.width - 32
        height: au.writingOut && au.audio.transcript === "" ? 24 : Math.max(24, transcriptEdit.contentHeight)
        Text {
          visible: au.writingOut && au.audio.transcript === ""
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Writing it out\u2026"
          font.family: au.editor ? au.editor.uiFamily : ""
          font.pixelSize: 13
          font.italic: true
          color: au.faint
          SequentialAnimation on opacity {
            running: au.writingOut
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: 700 }
            NumberAnimation { to: 1; duration: 700 }
          }
        }
        TextEdit {
          id: transcriptEdit
          objectName: "audioTranscriptText"
          visible: au.audio.transcript !== "" || activeFocus
          width: parent.width
          textFormat: TextEdit.PlainText
          wrapMode: TextEdit.Wrap
          readOnly: au.readOnly
          selectByMouse: true
          font.family: au.editor ? au.editor.family : ""
          font.pixelSize: 15
          color: au.words
          selectionColor: au.editor ? au.editor.selectionColor : "#88aaff"
          onActiveFocusChanged: {
            if (activeFocus) { if (au.editor) au.editor.sketchFocused(au.uid) }
            else au.keepTranscript()
          }
          Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Escape) { e.accepted = true; au.keepTranscript(); au.forceActiveFocus() }
          }
        }
      }
    }
  }

  // What was said, corrected: kept when you leave it.
  function keepTranscript() {
    if (readOnly) return
    var t = transcriptEdit.text.replace(/\s+$/, "")
    if (t !== audio.transcript) change({ transcript: t })
  }
}
