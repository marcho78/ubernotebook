import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html
import "../../Docs.js" as Docs

// Audio notes and dictation in Pages: "/audio" recording at once, Enter
// stopping it, the note written out (as Settings has it, or with "Write it
// out"), each a step to undo, kept in the page's file; throwing a recording
// away; its colors; its speed; Markdown. Dictation (Ctrl+Shift+D, the
// microphone at the top, "/dictate") writing what you said where you are.
// And the quick note's microphone. The microphone is FakeRecorder.qml.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  property string lastToast: ""

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToast: function(text) { root.lastToast = text }
  }

  SettingsPanel {
    id: settingsPanel
    theme: th
    service: service
  }

  QuickNote {
    id: quick
    width: 520
    height: 440
    visible: false
    theme: th
    recorder: service.recorder
  }

  TestCase {
    name: "Audio"
    when: windowShown

    readonly property var rec: service.recorder

    function fresh() {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      view.editor.readOnly = false
      rec.cancel()
      rec.startProblem = ""
      rec.nextText = "hello from the microphone"
      rec.nextTranscript = "What was said in it."
      rec.starts = []
      rec.transcribed = []
      rec.louders = []
      service.user = ({ sounds: false })
      root.lastToast = ""
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i))
    }
    function find(item, test) {
      if (!item) return null
      if (item.visible && test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    function audioAt(i) { return view.editor.serialize()[i].audio }
    function indexOfType(t) { return view.editor.serialize().map(function(b) { return b.type }).indexOf(t) }
    function put(audio) {
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "audio", audio: audio || {}, indent: 0 }])
      var uid = e.uidAt(0)
      tryVerify(function() { return e.items[uid] && e.items[uid].audioView }, 1000)
      waitForRendering(e.items[uid].audioView)
      return e.items[uid].audioView
    }
    function plainAt(i) { return Html.plainText(view.editor.serialize()[i].html || "") }
    function findText(text) { return find(win(), function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }) }
    // A color tile in the color menu that's open.
    function tile(test) {
      var t = null
      tryVerify(function() { t = find(win(), test); return t !== null }, 1000, "the color is on screen")
      wait(250)
      return find(win(), test)
    }
    function pickColor(id, background) {
      mouseClick(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === id && it.back === background }))
      // (The menu fades out before what's under it can be clicked.)
      wait(200)
    }
    // Its color button (there while the pointer's over it).
    function colorButton(av) {
      mouseMove(av, 120, 20)
      var b = null
      tryVerify(function() { b = named(av, "audioColors"); return b !== null }, 1000, "its color button")
      wait(100)
      return b
    }
    // Clicked once it's laid out.
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }

    function test_1_slash_audio_records_and_writes_out() {
      fresh()
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/audio")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "audio")
      keyClick(Qt.Key_Return)
      var at = indexOfType("audio")
      verify(at >= 0, "an audio note on the page")
      var uid = e.uidAt(at)
      tryCompare(rec, "phase", "recording", 1000, "recording at once")
      compare(rec.kind, "audio")
      compare(rec.owner, uid)
      verify(/\/Pages\/assets\/audio-\d{8}-\d{6}-[a-z0-9]+\.ogg$/.test(rec.starts[0].file), rec.starts[0].file)
      var av = e.items[uid].audioView
      verify(named(av, "audioCancel") !== null, "it can be thrown away")
      rec.feed(0.4); rec.feed(0.9)
      tryVerify(function() { return named(av, "audioWave") !== null }, 1000, "the level as it records")
      // Enter stops it; it's kept, then written out.
      keyClick(Qt.Key_Return)
      tryVerify(function() { return audioAt(at).src !== "" }, 1000, "kept")
      var a = audioAt(at)
      verify(/^assets\/audio-.*\.ogg$/.test(a.src), a.src)
      compare(a.duration, 3.2)
      compare(a.peaks.length, 9)
      tryVerify(function() { return audioAt(at).transcript === "What was said in it." }, 2000, "written out")
      compare(rec.transcribed.length, 1)
      verify(rec.transcribed[0].indexOf("/Pages/" + a.src) > 0, rec.transcribed[0])
      tryVerify(function() { var t = named(av, "audioTranscriptText"); return t !== null && t.text === "What was said in it." }, 1000, "under it")
      // Kept in the page's file.
      view.commit()
      var page = ws.readPageNow(view.page.id)
      var kept = Workspace.flatten(page).filter(function(b) { return b.type === "audio" })[0]
      compare(kept.audio.src, a.src)
      compare(kept.audio.transcript, "What was said in it.")
      // Each a step to undo.
      e.undo()
      tryVerify(function() { return audioAt(at).transcript === "" && audioAt(at).src !== "" }, 1000, "undone: not written out")
      e.undo()
      tryVerify(function() { return audioAt(at).src === "" }, 1000, "undone: not recorded")
    }

    function test_2_thrown_away_and_what_gets_in_the_way() {
      fresh()
      var av = put()
      wait(100)
      click(named(av, "audioMain"))
      tryCompare(rec, "phase", "recording", 1000)
      click(named(av, "audioCancel"))
      tryCompare(rec, "phase", "", 1000)
      compare(audioAt(0).src, "", "nothing kept")
      // Esc throws it away too.
      click(named(av, "audioMain"))
      tryCompare(rec, "phase", "recording", 1000)
      keyClick(Qt.Key_Escape)
      tryCompare(rec, "phase", "", 1000)
      compare(audioAt(0).src, "")
      // No microphone: it says why.
      rec.startProblem = "Recording needs ffmpeg"
      click(named(av, "audioMain"))
      compare(root.lastToast, "Recording needs ffmpeg")
      compare(rec.phase, "")
      rec.startProblem = ""
      // Not written out as it's recorded (Settings): "Write it out" does it.
      service.setSetting("audioTranscribe", false)
      click(named(av, "audioMain"))
      tryCompare(rec, "phase", "recording", 1000)
      rec.stop()
      tryVerify(function() { return audioAt(0).src !== "" }, 1000)
      wait(100)
      compare(audioAt(0).transcript, "")
      compare(rec.transcribed.length, 0)
      var write = null
      tryVerify(function() { write = named(av, "audioWriteOut"); return write !== null }, 1000, "Write it out")
      click(write)
      tryVerify(function() { return audioAt(0).transcript === "What was said in it." }, 2000)
      // Hidden, and shown again.
      click(named(av, "audioTranscript"))
      tryVerify(function() { return audioAt(0).open === false }, 1000)
      verify(named(av, "audioTranscriptText") === null)
      // Corrected by hand.
      click(named(av, "audioTranscript"))
      tryVerify(function() { return named(av, "audioTranscriptText") !== null }, 1000)
      var t = named(av, "audioTranscriptText")
      t.forceActiveFocus()
      t.text = "What was really said."
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return audioAt(0).transcript === "What was really said." }, 1000)
    }

    function test_3_colors_speed_and_markdown() {
      fresh()
      var av = put({ src: "assets/audio-20261002-101010-abc.ogg", duration: 75, peaks: [10, 50, 90, 40], transcript: "Buy milk." })
      // Its colors: Pages' colors, or your own (shown as it's picked).
      wait(100)
      mouseClick(colorButton(av))
      pickColor("yellow", true)
      tryVerify(function() { return audioAt(0).background === "yellow" }, 1000)
      compare(String(av.fill), String(Qt.color(Docs.colorEntry("yellow").background[th.dark ? 1 : 0])), "drawn in it")
      mouseClick(colorButton(av))
      pickColor("purple", false)
      tryVerify(function() { return audioAt(0).color === "purple" }, 1000)
      compare(String(av.tint), String(Qt.color(Docs.colorEntry("purple").text[th.dark ? 1 : 0])))
      mouseClick(colorButton(av))
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText("Text color of your own") !== null }, 1000, "the color picker")
      wait(200)
      var hex = "#ff8800"
      for (var i = 0; i < hex.length; i++) keyClick(hex.charAt(i))
      tryVerify(function() { return av.look.color === hex }, 1000, "shown as it's picked")
      compare(audioAt(0).color, "purple", "not kept yet")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return audioAt(0).color === hex }, 1000)
      tryVerify(function() { return findText("Text color of your own") === null }, 1000)
      wait(200)
      // The speed, a click at a time.
      click(named(av, "audioSpeed"))
      compare(av.speeds[av.speedAt], 1.25)
      click(named(av, "audioSpeed"))
      click(named(av, "audioSpeed"))
      click(named(av, "audioSpeed"))
      compare(av.speeds[av.speedAt], 1)
      // As Markdown: a link to it, what was said quoted.
      view.copyMarkdown()
      verify(files.copied.indexOf("Audio note, 1:15](assets/audio-20261002-101010-abc.ogg)") > 0, files.copied)
      verify(files.copied.indexOf("> Buy milk.") > 0)
    }

    function test_4_dictation() {
      fresh()
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      type("Groceries:")
      var at = e.indexOf(last)
      // Ctrl+Shift+D: listening; again: written where you are.
      keyClick(Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier)
      tryCompare(rec, "phase", "recording", 1000)
      compare(rec.kind, "dictation")
      compare(rec.owner, "page")
      tryVerify(function() { return named(win(), "recordingBar") !== null }, 1000, "the bar at the foot")
      keyClick(Qt.Key_D, Qt.ControlModifier | Qt.ShiftModifier)
      tryVerify(function() { return plainAt(at) === "Groceries: hello from the microphone" }, 2000, "written where you were: " + plainAt(at))
      tryVerify(function() { return named(win(), "recordingBar") === null }, 1000)
      // The microphone at the top; Done.
      wait(100)
      click(named(win(), "dictateButton"))
      tryCompare(rec, "phase", "recording", 1000)
      rec.nextText = "and bread"
      click(named(win(), "recordingDone"))
      tryVerify(function() { return plainAt(at) === "Groceries: hello from the microphone and bread" }, 2000, plainAt(at))
      // Thrown away: nothing written.
      wait(100)
      click(named(win(), "dictateButton"))
      tryCompare(rec, "phase", "recording", 1000)
      click(named(win(), "recordingCancel"))
      tryCompare(rec, "phase", "", 1000)
      wait(50)
      compare(plainAt(at), "Groceries: hello from the microphone and bread")
      // Nothing heard: it says so.
      rec.nextText = ""
      view.dictate()
      view.dictate()
      tryVerify(function() { return root.lastToast === "No words were heard" }, 1000)
      // "/dictate".
      rec.nextText = "from the menu"
      e.focusBlock(last, -1)
      keyClick(Qt.Key_Return)
      type("/dictate")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "dictate")
      keyClick(Qt.Key_Return)
      tryCompare(rec, "phase", "recording", 1000)
      rec.stop()
      tryVerify(function() { return plainAt(at + 1) === "from the menu" }, 2000, plainAt(at + 1))
      // A locked page: no.
      view.setFormat("locked", true)
      view.dictate()
      compare(rec.phase, "")
      verify(root.lastToast.indexOf("locked") >= 0)
      view.setFormat("locked", false)
    }

    // Dictation still being written down when another profile's notes are
    // opened: never put on a page of theirs; copied, and said so.
    function test_4b_dictation_written_down_as_another_profile_opens() {
      fresh()
      var root0 = files.rootPath
      var other = "/tmp/other-dictation-notes"
      var words = "only for the first profile"
      view.dictate()
      tryCompare(rec, "phase", "recording", 1000)
      // (Done pressed: voxtype at work.)
      rec.phase = "transcribing"
      try {
        files.rootPath = other
        tryVerify(function() { return ws.ready && view.page !== null && ws.folder === other + "/Pages" }, 3000, "the other open")
        var theirs = view.page.id
        root.lastToast = ""
        rec._end(true, { text: words })
        compare(files.copied, words, "copied")
        compare(root.lastToast, "Copied what you said: paste it where you want it")
        verify(view.editor.serialize().every(function(b) { return Html.plainText(b.html || "").indexOf(words) < 0 }), "not on their page")
        wait(900)
        verify(!Object.keys(files.disk).some(function(p) { return p.indexOf(other + "/") === 0 && String(files.disk[p]).indexOf(words) >= 0 }), "nothing of it in their files")
        compare(view.page.id, theirs)
      } finally {
        rec.cancel()
        files.rootPath = root0
        tryCompare(ws, "ready", true, 2000)
      }
    }

    // An audio note written out, or made louder, as another profile opens:
    // what it brings isn't put in a page of that one (nor its files).
    function test_4c_written_out_or_louder_as_another_profile_opens() {
      fresh()
      var root0 = files.rootPath
      var other = "/tmp/other-transcript-notes"
      put({ src: "assets/audio-20261002-101010-abc.ogg", duration: 75, peaks: [10, 50, 90, 40] })
      put({ src: "assets/audio-20261002-101011-def.ogg", duration: 30, peaks: [5, 9, 7, 4] })
      var uid = view.editor.uidAt(0)
      var uid2 = view.editor.uidAt(1)
      rec.nextTranscript = "Only for the first profile."
      // (The other profile a backup of this one put back: its pages, and
      // their blocks, the same ids.)
      view.commit()
      wait(900)
      Object.keys(files.disk).forEach(function(p) { if (p.indexOf(root0 + "/") === 0) files.disk[other + p.slice(root0.length)] = files.disk[p] })
      rec.holdWork = true
      try {
        view.transcribeAudio(view.page.id, uid)
        view.louderAudio(uid2)
        compare(rec.heldWork.length, 2, "both under way")
        files.rootPath = other
        tryVerify(function() { return ws.ready && view.page !== null && ws.folder === other + "/Pages" }, 3000, "the other open")
        var theirs = view.page.id
        var before = JSON.stringify(view.editor.serialize())
        rec.releaseWork()
        wait(900)
        compare(JSON.stringify(view.editor.serialize()), before, "their page as it was")
        verify(!Object.keys(files.disk).some(function(p) { return p.indexOf(other + "/") === 0 && String(files.disk[p]).indexOf("audio-2026") >= 0 && String(files.disk[p]).indexOf("louder") >= 0 }), "no louder copy put in their page")
        verify(!Object.keys(files.disk).some(function(p) { return p.indexOf(other + "/") === 0 && String(files.disk[p]).indexOf("Only for the first profile") >= 0 }), "nothing of it in their files")
        compare(view.page.id, theirs)
      } finally {
        rec.holdWork = false
        rec.releaseWork()
        files.rootPath = root0
        tryCompare(ws, "ready", true, 2000)
      }
    }

    function test_6_settings_the_microphone_louder_and_a_test() {
      fresh()
      settingsPanel.openAt("audio")
      tryVerify(function() { return settingsPanel.opened }, 1000)
      tryVerify(function() { return rec.sources.length === 2 }, 1000, "the microphones, listed")
      var picker = null
      tryVerify(function() { picker = named(win(), "micPicker"); return picker !== null }, 1000)
      compare(settingsPanel.micLabel, "The default one")
      // Another microphone.
      var flick = named(win(), "settingsFlick")
      flick.contentY = Math.max(0, picker.mapToItem(flick.contentItem, 0, 0).y - 40)
      wait(200)
      click(picker)
      var usb = null
      tryVerify(function() { usb = find(win(), function(it) { return it.objectName === "micChoice" && it.text === "USB Microphone" }); return usb !== null }, 1000)
      wait(200)
      mouseClick(usb)
      tryCompare(service.settings, "audioInput", "alsa_input.usb", 1000)
      compare(settingsPanel.micLabel, "USB Microphone")
      compare(rec.input, "alsa_input.usb", "what it records from")
      // A test: the level, then how it sounded.
      wait(200)
      click(named(win(), "micTest"))
      tryCompare(rec, "kind", "test", 1000)
      verify(settingsPanel.testing)
      compare(rec.starts[rec.starts.length - 1].input, "alsa_input.usb")
      click(named(win(), "micTest"))
      tryCompare(settingsPanel, "heard", "good", 1000)
      compare(settingsPanel.heardNote, "Sounds good.")
      rec.testLevels = [0.01, 0.02]
      click(named(win(), "micTest"))
      click(named(win(), "micTest"))
      tryCompare(settingsPanel, "heard", "silent", 1000)
      // The voice made louder, or not.
      compare(rec.boost, true, "made louder at first")
      service.setSetting("audioBoost", false)
      compare(rec.boost, false)
      // What gets in the way.
      rec.startProblem = "Recording needs ffmpeg"
      settingsPanel.testMicrophone()
      compare(settingsPanel.heardNote, "Recording needs ffmpeg")
      rec.startProblem = ""
      settingsPanel.close()
      rec.testLevels = [0.1, 0.5, 0.7, 0.6, 0.2]
    }

    function test_7_a_quiet_note_made_louder() {
      fresh()
      var av = put({ src: "assets/audio-20261002-113837-jvm.ogg", duration: 5.5, peaks: [5, 20, 40, 30] })
      var louder = null
      tryVerify(function() { louder = named(av, "audioLouder"); return louder !== null }, 1000, "a quiet one offers it")
      click(louder)
      tryVerify(function() { return audioAt(0).src !== "assets/audio-20261002-113837-jvm.ogg" }, 2000, "a new file")
      compare(rec.louders.length, 1)
      verify(/\/Pages\/assets\/audio-20261002-113837-jvm\.ogg$/.test(rec.louders[0].file))
      compare(audioAt(0).peaks.join(), "30,70,95,60", "its waveform, louder")
      tryVerify(function() { return named(av, "audioLouder") === null }, 1000, "not quiet any more")
      view.editor.undo()
      tryVerify(function() { return audioAt(0).src === "assets/audio-20261002-113837-jvm.ogg" }, 1000, "Undo: the one before")
    }

    function test_8_the_record_button() {
      fresh()
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      type("Before")
      click(named(win(), "recordButton"))
      tryCompare(rec, "phase", "recording", 1000)
      var at = indexOfType("audio")
      compare(at, e.indexOf(last) + 1, "right after where you were")
      compare(rec.owner, e.uidAt(at))
      compare(rec.starts[rec.starts.length - 1].boost, true)
      // Again: it stops.
      click(named(win(), "recordButton"))
      tryVerify(function() { return audioAt(at).src !== "" }, 1000)
      // Ctrl+Shift+R, from the page.
      e.focusBlock(last, -1)
      keyClick(Qt.Key_R, Qt.ControlModifier | Qt.ShiftModifier)
      tryCompare(rec, "phase", "recording", 1000)
      keyClick(Qt.Key_Escape)
      tryCompare(rec, "phase", "", 1000)
      // Not while dictating.
      view.dictate()
      view.newAudioNote()
      verify(root.lastToast.indexOf("Already recording") === 0, root.lastToast)
      rec.cancel()
    }

    function test_5_the_quick_notes_microphone() {
      fresh()
      quick.visible = true
      quick.start("Remember")
      quick.dictate()
      compare(rec.owner, "quick")
      verify(quick.dictating)
      quick.dictate()
      tryVerify(function() { return !quick.dictating }, 1000)
      var edit = find(quick, function(it) { return it.textFormat === TextEdit.PlainText && typeof it.cursorPosition === "number" && it.font.pixelSize === 27 })
      tryCompare(edit, "text", "Remember hello from the microphone")
      // Kept while it listens: the listening stops.
      quick.dictate()
      verify(quick.dictating)
      quick.keep()
      compare(rec.phase, "")
      // What gets in the way, on the note.
      rec.startProblem = "Dictation needs voxtype (Omarchy's dictation)"
      quick.start("")
      quick.dictate()
      compare(quick.problem, "Dictation needs voxtype (Omarchy's dictation)")
      quick.visible = false
    }
  }
}
