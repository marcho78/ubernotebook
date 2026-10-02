import QtQuick
import Quickshell
import Quickshell.Io
import "Audio.js" as Audio

// The microphone, for dictation and audio notes: one recording at a time.
// ffmpeg records from the microphone Settings picks (or the default one:
// PipeWire's, through its Pulse server), printing its level ten times a
// second (for the meter and the waveform); dictation goes to a 16 kHz WAV
// in the runtime folder, an audio note to an Opus file in Pages/assets.
// With `boost` (Settings: "Make my voice louder"), the voice is evened out
// once it's recorded (Audio.BOOST), and before voxtype (Omarchy's dictation,
// with the model its settings pick) writes out what was said.
//
// start(kind, owner, file, done) starts ("test": a few seconds, kept
// nowhere); stop() finishes (dictation is then written out); cancel() throws
// it away. done(ok, result) is told once, however it ends (stopped, its time
// up, or the microphone failing): { kind, owner, file, duration, peaks,
// levels, text, problem, canceled }. transcribe(file, seconds, done) writes
// out any recording: done(ok, text, problem). louder(file, to, done) makes a
// recording louder into a new file: done(ok, peaks). listSources() finds
// the microphones.
Item {
  id: rec

  // Store.qml: running a command once (checks, transcribing).
  property var files: null
  readonly property string tempDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/omanote-audio"

  // What's there: ffmpeg to record, voxtype to write out.
  property bool canRecord: false
  property bool canTranscribe: false
  property bool checked: false

  // Settings: the microphone ("" the default), and the voice made louder.
  property string input: ""
  property bool boost: true
  // The microphones there are: [{ name, label }].
  property var sources: []

  // The recording on now: its kind ("dictation", "audio"), who asked for it
  // (a block's uid, "page", "quick"), and where it is ("recording", then
  // "finishing", then for dictation "transcribing").
  property string kind: ""
  property string owner: ""
  property string phase: ""
  readonly property bool busy: phase !== ""
  property real elapsed: 0
  property real level: 0
  // The last levels (0 to 1), for a meter.
  property var recent: []

  property var _levels: []
  property string _file: ""
  // Where a note goes once it's made louder ("" when it isn't), and whether it is.
  property string _final: ""
  property bool _boosted: false
  property var _done: null
  property bool _stopping: false
  property bool _canceled: false
  property real _started: 0
  property string _err: ""

  Component.onCompleted: check()

  function listSources(done) {
    if (!files) { if (done) done([]); return }
    files.exec(["/usr/bin/pactl", "-f", "json", "list", "sources"], function(ok, out) {
      rec.sources = ok ? Audio.sourcesOf(out) : []
      if (done) done(rec.sources)
    }, { timeoutMs: 5000, maxBytes: 1024 * 1024 })
  }

  function check(done) {
    if (!files) { if (done) done(); return }
    files.exec(["/usr/bin/bash", "-c", "[ -x /usr/bin/ffmpeg ] && echo ffmpeg; [ -x /usr/bin/voxtype ] && echo voxtype; exit 0"], function(ok, out) {
      rec.canRecord = /ffmpeg/.test(out || "")
      rec.canTranscribe = /voxtype/.test(out || "")
      rec.checked = true
      if (done) done()
    })
  }

  // Starts recording: "" when it has, or what's in the way.
  function start(kind, owner, file, done) {
    if (busy) return "Already recording: stop that one first"
    if (!canRecord) return "Recording needs ffmpeg"
    if (kind === "dictation" && !canTranscribe) return "Dictation needs voxtype (Omarchy's dictation)"
    var path = kind === "dictation" ? tempDir + "/dictation-" + Date.now().toString(36) + ".wav" : kind === "test" ? tempDir : String(file || "")
    if (!path) return "There's nowhere to keep it"
    // A note to make louder once it's done is recorded beside it first.
    _final = kind === "audio" && boost ? path : ""
    if (_final) path = path.replace(/\.ogg$/, "") + ".recording.ogg"
    _boosted = boost
    rec.kind = kind
    rec.owner = owner || ""
    _file = path
    _done = done || null
    _levels = []
    _stopping = false
    _canceled = false
    _err = ""
    recent = []
    level = 0
    elapsed = 0
    _started = Date.now()
    phase = "recording"
    var dir = kind === "test" ? tempDir : path.replace(/\/[^\/]*$/, "")
    proc.command = ["/usr/bin/bash", "-c", "/usr/bin/mkdir -p -m 700 -- \"$1\" && shift && exec \"$@\"", "omanote-record", dir]
      .concat(Audio.recordCommand(kind, path, { input: input, boost: boost }))
    proc.running = true
    return ""
  }

  function stop() {
    if (phase !== "recording") return
    phase = "finishing"
    _stopping = true
    // ffmpeg finishes its file on SIGINT.
    proc.signal(2)
    killer.restart()
  }

  function cancel() {
    if (phase === "transcribing") {
      // (A run called off never reports.)
      transcriber.cancel()
      _remove(transcriber.file)
      _end(false, { canceled: true })
      return
    }
    // Being made louder: it's nearly done, and kept.
    if (finisher.running) return
    if (phase !== "recording" && phase !== "finishing") return
    _canceled = true
    stop()
  }

  Timer {
    id: killer
    interval: 4000
    onTriggered: if (proc.running) proc.signal(9)
  }

  Timer {
    interval: 100
    repeat: true
    running: rec.phase === "recording"
    onTriggered: rec.elapsed = (Date.now() - rec._started) / 1000
  }

  function _end(ok, result) {
    var done = _done
    var r = result || {}
    r.kind = kind
    r.owner = owner
    _done = null
    phase = ""
    kind = ""
    owner = ""
    level = 0
    recent = []
    if (done) done(ok, r)
  }

  function _remove(path) {
    if (path && files) files.exec(["/usr/bin/rm", "-f", "--", path], null)
  }

  Process {
    id: proc
    stdout: SplitParser {
      onRead: function(line) {
        var v = Audio.levelIn(line)
        if (v < 0) return
        rec._levels.push(v)
        rec.level = v
        var r = rec.recent.slice(-159)
        r.push(v)
        rec.recent = r
      }
    }
    stderr: SplitParser {
      onRead: function(line) { if (rec._err.length < 600) rec._err += line + "\n" }
    }
    onExited: function(exitCode) {
      killer.stop()
      var file = rec._file
      var seconds = rec._levels.length / Audio.RATE
      if (rec.kind === "test") {
        rec._end(rec._levels.length > 0, { levels: rec._levels.slice(), duration: seconds,
          problem: rec._levels.length === 0 ? "The microphone couldn't be opened" + (rec._err ? ": " + rec._err.trim().split("\n")[0] : "") : "" })
        return
      }
      if (rec._canceled) {
        rec._remove(file)
        rec._end(false, { canceled: true })
        return
      }
      // It ended by itself: its time was up (fine), or the microphone failed.
      var failed = !rec._stopping && (exitCode !== 0 || rec._levels.length === 0)
      if (failed || rec._levels.length === 0) {
        rec._remove(file)
        var why = rec._err.trim().split("\n")[0] || ""
        rec._end(false, { problem: rec._levels.length === 0 && rec._stopping ? "Nothing was recorded" : "The microphone couldn't be opened" + (why ? ": " + why : "") })
        return
      }
      if (rec.kind === "dictation") {
        rec.phase = "transcribing"
        transcriber.timeoutMs = Audio.transcribeTimeout(seconds)
        transcriber.file = file
        var even = rec._boosted ? file.replace(/\.wav$/, "") + "-even.wav" : ""
        transcriber.start(["/usr/bin/bash", "-c", Audio.TRANSCRIBE_SCRIPT, "omanote-transcribe", file, even, rec._boosted ? Audio.BOOST : ""])
        return
      }
      var result = { file: rec._final || file, duration: Math.round(seconds * 10) / 10, peaks: Audio.peaks(rec._levels, 120) }
      if (rec._final) {
        // Made louder, into its own file (or kept as it is, if that fails).
        rec.phase = "finishing"
        finisher.result = result
        finisher.timeoutMs = 60000 + Math.round(seconds * 1000)
        finisher.start(["/usr/bin/bash", "-c", Audio.LOUDER_SCRIPT, "omanote-louder", file, rec._final, Audio.BOOST])
        return
      }
      rec._end(true, result)
    }
  }

  // Dictation written out (its WAV taken away after).
  Run {
    id: transcriber
    property string file: ""
    maxBytes: 2 * 1024 * 1024
    onFinished: function(ok, output) {
      rec._remove(file)
      var text = ok ? Audio.transcriptOf(output) : ""
      rec._end(text !== "", { text: text, problem: !ok ? "voxtype couldn't write it out: " + String(output || "").split("\n")[0] : text === "" ? "No words were heard" : "" })
    }
  }

  // An audio note made louder once it's recorded.
  Run {
    id: finisher
    property var result: null
    maxBytes: 4 * 1024 * 1024
    onFinished: function(ok, output) {
      var r = result
      result = null
      // (The levels it prints are the louder note's.)
      var levels = ok ? Audio.levelsIn(output) : []
      if (levels.length) r.peaks = Audio.peaks(levels, 120)
      rec._end(true, r)
    }
  }

  // A recording made louder into a new file (it stays, for Undo): done(ok, peaks).
  function louder(file, to, done) {
    if (!files || !canRecord) { done(false, []); return }
    files.exec(["/usr/bin/bash", "-c", Audio.LOUDER_SCRIPT, "omanote-louder", file, to, Audio.BOOST, "keep"], function(ok, output) {
      done(ok, ok ? Audio.peaks(Audio.levelsIn(output), 120) : [])
    }, { timeoutMs: 600000, maxBytes: 4 * 1024 * 1024 })
  }

  // Any recording written out (an audio note's): done(ok, text, problem).
  function transcribe(file, seconds, done) {
    if (!files || !canTranscribe) { done(false, "", "Writing it out needs voxtype (Omarchy's dictation)"); return }
    var wav = tempDir + "/transcribe-" + Date.now().toString(36) + ".wav"
    files.exec(["/usr/bin/bash", "-c", "/usr/bin/mkdir -p -m 700 -- \"$1\" && shift && exec /usr/bin/bash -c \"$@\"", "omanote-transcribe", tempDir, Audio.TRANSCRIBE_SCRIPT, "omanote-transcribe", file, wav, boost ? Audio.BOOST : ""], function(ok, output) {
      var text = ok ? Audio.transcriptOf(output) : ""
      done(ok && text !== "", text, !ok ? "voxtype couldn't write it out" : text === "" ? "No words were heard" : "")
    }, { timeoutMs: Audio.transcribeTimeout(seconds), maxBytes: 2 * 1024 * 1024 })
  }
}
