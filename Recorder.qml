import QtQuick
import Quickshell
import Quickshell.Io
import "Audio.js" as Audio
import "Env.js" as Env

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
//
// ffmpeg runs as Run.qml's and Stream.qml's commands do: by its full path,
// never through a shell, as the leader of a process group of its own
// (setsid), with only the environment a tool needs (Env.js). It's stopped
// with SIGINT, which has it finish its file; if it doesn't, it's ended with
// anything it started (its group, SIGKILL), as it is when Uber Notebook
// closes. What it prints is read in pieces, a line at most 4 KB, 64 MB in
// all (counted in characters, as they're kept), and as many levels as its
// longest recording has.
Item {
  id: rec

  // Store.qml: running a command once (checks, transcribing).
  property var files: null
  // The program that records (tests give a stand-in).
  property string program: "/usr/bin/ffmpeg"
  readonly property string tempDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/uber-notebook-audio"

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
  // What it's printed (characters), the line it's in, its group's leader.
  property real _seen: 0
  property string _part: ""
  property bool _skipping: false
  property int _pid: 0
  property bool _launched: false
  property real outputMax: 64 * 1024 * 1024
  readonly property int lineMax: 4096

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
    _seen = 0
    _part = ""
    _skipping = false
    _pid = 0
    _launched = false
    recent = []
    level = 0
    elapsed = 0
    _started = Date.now()
    phase = "recording"
    var dir = kind === "test" ? tempDir : path.replace(/\/[^\/]*$/, "")
    var argv = Audio.recordCommand(kind, path, { input: input, boost: boost })
    argv[0] = program
    // Its folder first (not through a shell), then ffmpeg; stopped before it
    // started: nothing recorded.
    files.exec(["/usr/bin/mkdir", "-p", "-m", "700", "--", dir], function(made) {
      if (rec._file !== path || rec.phase === "") return
      if (!made || rec._stopping) {
        rec._end(false, rec._canceled ? { canceled: true } : { problem: made ? "Nothing was recorded" : "There's nowhere to keep it" })
        return
      }
      rec._launched = true
      proc.command = ["/usr/bin/setsid", "--wait"].concat(argv)
      proc.running = true
    })
    // (ffmpeg's own limit is the recording's length; a microphone that stops
    // sending could keep it waiting, so the clock has one too.)
    wallClock.interval = (Number(Audio.LIMITS[kind] || Audio.LIMITS.audio) + 30) * 1000
    wallClock.restart()
    return ""
  }

  function stop() {
    if (phase !== "recording") return
    phase = "finishing"
    _stopping = true
    if (!_launched) return
    // ffmpeg finishes its file on SIGINT (it leads its group: setsid).
    proc.signal(2)
    killer.restart()
  }

  // It, and anything it started: its group.
  function _killGroup() {
    var pid = proc.processId > 0 ? proc.processId : _pid
    if (pid > 0) Quickshell.execDetached(["/usr/bin/kill", "-KILL", "--", "-" + pid])
  }
  Component.onDestruction: if (proc.running) _killGroup()

  // What it prints: lines of levels, in pieces (no line past lineMax kept,
  // nothing past outputMax read: then it's stopped).
  function _counted(data) {
    _seen += data.length
    if (_seen <= outputMax) return true
    if (phase === "recording") stop()
    return false
  }
  function _takeOut(data) {
    if (!_counted(data)) return
    var from = 0
    var nl
    while ((nl = data.indexOf("\n", from)) >= 0) {
      var piece = data.slice(from, nl)
      from = nl + 1
      if (_skipping) { _skipping = false; _part = ""; continue }
      if (_part.length + piece.length > lineMax) { _part = ""; continue }
      var line = _part + piece
      _part = ""
      _level(line)
    }
    var rest = data.slice(from)
    if (_skipping || !rest) return
    if (_part.length + rest.length > lineMax) { _part = ""; _skipping = true; return }
    _part += rest
  }
  function _takeErr(data) {
    if (!_counted(data)) return
    if (_err.length < 600) _err += data.slice(0, 600 - _err.length)
  }
  function _level(line) {
    var v = Audio.levelIn(line)
    if (v < 0) return
    // (As many as its longest recording has, a minute more.)
    if (_levels.length < (Number(Audio.LIMITS[kind] || Audio.LIMITS.audio) + 60) * Audio.RATE) _levels.push(v)
    level = v
    var r = recent.slice(-159)
    r.push(v)
    recent = r
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
    onTriggered: if (proc.running) rec._killGroup()
  }
  Timer { id: wallClock; onTriggered: rec.stop() }

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
    clearEnvironment: true
    environment: Env.forTools(function(name) { return Quickshell.env(name) })
    onStarted: rec._pid = proc.processId > 0 ? proc.processId : 0
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(data) { rec._takeOut(data) }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) { rec._takeErr(data) }
    }
    onExited: function(exitCode) {
      killer.stop()
      wallClock.stop()
      // (Its last line, if it didn't end with one; then whatever it started
      // and left running ends with it.)
      if (rec._part && !rec._skipping) rec._level(rec._part)
      rec._part = ""
      rec._killGroup()
      rec._pid = 0
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
        // (What it says comes back ASCII, through the files helper's
        // to-json: no character cut in two on its way here.)
        transcriber.start(["/usr/bin/bash", "-c", "h=$1; n=$2; shift 2; set -o pipefail; \"$@\" | /usr/bin/python3 -I -S \"$h\" to-json \"$n\"", "uber-notebook-text",
          files.filesHelper, String(2 * 1024 * 1024), "/usr/bin/bash", "-c", Audio.TRANSCRIBE_SCRIPT, "uber-notebook-transcribe", file, even, rec._boosted ? Audio.BOOST : ""])
        return
      }
      var result = { file: rec._final || file, duration: Math.round(seconds * 10) / 10, peaks: Audio.peaks(rec._levels, 120) }
      if (rec._final) {
        // Made louder, into its own file (or kept as it is, if that fails).
        rec.phase = "finishing"
        finisher.result = result
        finisher.timeoutMs = 60000 + Math.round(seconds * 1000)
        finisher.start(["/usr/bin/bash", "-c", Audio.LOUDER_SCRIPT, "uber-notebook-louder", file, rec._final, Audio.BOOST])
        return
      }
      rec._end(true, result)
    }
  }

  // Dictation written out (its WAV taken away after).
  Run {
    id: transcriber
    property string file: ""
    maxBytes: 6 * 2 * 1024 * 1024 + 1024
    onFinished: function(ok, output) {
      rec._remove(file)
      var said = ok && rec.files ? rec.files.parseJson(String(output || "").trim()) : null
      var text = typeof said === "string" ? Audio.transcriptOf(said) : ""
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
    files.exec(["/usr/bin/bash", "-c", Audio.LOUDER_SCRIPT, "uber-notebook-louder", file, to, Audio.BOOST, "keep"], function(ok, output) {
      done(ok, ok ? Audio.peaks(Audio.levelsIn(output), 120) : [])
    }, { timeoutMs: 600000, maxBytes: 4 * 1024 * 1024 })
  }

  // Any recording written out (an audio note's): done(ok, text, problem).
  function transcribe(file, seconds, done) {
    if (!files || !canTranscribe) { done(false, "", "Writing it out needs voxtype (Omarchy's dictation)"); return }
    var wav = tempDir + "/transcribe-" + Date.now().toString(36) + ".wav"
    files.execText(["/usr/bin/bash", "-c", "/usr/bin/mkdir -p -m 700 -- \"$1\" && shift && exec /usr/bin/bash -c \"$@\"", "uber-notebook-transcribe", tempDir, Audio.TRANSCRIBE_SCRIPT, "uber-notebook-transcribe", file, wav, boost ? Audio.BOOST : ""], function(ok, output) {
      var text = ok ? Audio.transcriptOf(output) : ""
      done(ok && text !== "", text, !ok ? "voxtype couldn't write it out" : text === "" ? "No words were heard" : "")
    }, { timeoutMs: Audio.transcribeTimeout(seconds), maxBytes: 2 * 1024 * 1024 })
  }
}
