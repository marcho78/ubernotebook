import QtQuick

// The microphone, for tests: Recorder.qml's side the app sees. A recording
// goes on until stop() (or cancel()); `levels` are fed in by hand. Dictation
// comes out as `nextText`, an audio note as a file of `nextDuration`
// seconds; transcribe() says `nextTranscript`.
QtObject {
  property bool canRecord: true
  property bool canTranscribe: true
  property bool checked: true
  property string input: ""
  property bool boost: true
  property var sources: []
  property var louders: []
  // What a test of the microphone hears.
  property var testLevels: [0.1, 0.5, 0.7, 0.6, 0.2]
  property string kind: ""
  property string owner: ""
  property string phase: ""
  readonly property bool busy: phase !== ""
  property real elapsed: 0
  property real level: 0
  property var recent: []

  property string nextText: "hello from the microphone"
  property real nextDuration: 3.2
  property string nextTranscript: "What was said in it."
  property string startProblem: ""
  property var starts: []
  property var transcribed: []
  property var _done: null
  property string _file: ""

  function check(done) { if (done) done() }
  function listSources(done) {
    sources = [{ name: "alsa_input.internal", label: "Internal Microphone" }, { name: "alsa_input.usb", label: "USB Microphone" }]
    if (done) done(sources)
  }
  function louder(file, to, done) {
    louders = louders.concat([{ file: file, to: to }])
    Qt.callLater(function() { done(true, [30, 70, 95, 60]) })
  }

  function start(kind, owner, file, done) {
    if (startProblem) return startProblem
    if (busy) return "Already recording: stop that one first"
    this.kind = kind
    this.owner = owner || ""
    _file = file || ""
    _done = done || null
    phase = "recording"
    starts = starts.concat([{ kind: kind, owner: owner, file: file, input: input, boost: boost }])
    return ""
  }

  function feed(v) {
    level = v
    var r = recent.slice(-159)
    r.push(v)
    recent = r
    elapsed += 0.1
  }

  function _end(ok, r) {
    var done = _done
    r.kind = kind
    r.owner = owner
    _done = null
    phase = ""
    kind = ""
    owner = ""
    recent = []
    elapsed = 0
    if (done) done(ok, r)
  }

  function stop() {
    if (phase !== "recording") return
    if (kind === "test") { _end(true, { levels: testLevels }); return }
    if (kind === "dictation") {
      phase = "transcribing"
      Qt.callLater(function() { if (phase === "transcribing") _end(nextText !== "", { text: nextText, problem: nextText ? "" : "No words were heard" }) })
      return
    }
    _end(true, { file: _file, duration: nextDuration, peaks: [10, 40, 80, 60, 20, 5, 50, 90, 30] })
  }

  function cancel() {
    if (phase === "") return
    _end(false, { canceled: true })
  }

  function transcribe(file, seconds, done) {
    transcribed = transcribed.concat([file])
    var text = nextTranscript
    Qt.callLater(function() { done(text !== "", text, text ? "" : "No words were heard") })
  }
}
