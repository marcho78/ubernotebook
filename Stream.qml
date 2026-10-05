import QtQuick
import Quickshell
import Quickshell.Io
import "Env.js" as Env

// Runs one command from an argument list, by absolute path, and hands on
// what it prints a line at a time, as it prints it: line(text) for each line
// of its output, then finished(code, errors) once (code -1: stopped). For an
// agent working without a terminal (Agent.js), which says each step as a
// line of JSON.
//
// Like Run.qml, the command leads its own process group (setsid), so stop()
// (or the deadline) ends it together with anything it started: a gentle
// stop first, and a hard one if it's still there a few seconds later; and
// when it's done, or Uber Notebook closes, whatever it left running ends too.
// What it prints is read in pieces and cut into lines here, within budgets:
// a line longer than maxLine is left out (and said, in errors), and once it
// has printed more than maxBytes in all, on its output and its errors
// together, it's stopped. (Budgets count characters, as they're kept: a
// character of UTF-8 may have been up to 4 bytes of output.) It gets the shell's
// environment, but what would change how a program starts (Env.js). With
// `input`, it's written to as it works (send: a line of JSON for Claude Code,
// its request, then its answers to what it asks; closeInput when that's all),
// what's sent before it's started going once it has.
Item {
  id: st

  property string workingDirectory: ""
  property bool input: false
  // What's in its environment besides (Agent.env: Grok's sandbox).
  property var extraEnv: ({})
  property int timeoutMs: 30 * 60 * 1000
  property int maxLine: 4 * 1024 * 1024
  property real maxBytes: 64 * 1024 * 1024
  // Its errors on their own, at most this (as they're printed: an agent's
  // output is made ASCII on its way here, and has the room that takes; its
  // errors aren't, and don't).
  property real maxErrors: maxBytes
  readonly property bool running: proc.running

  signal line(string text)
  signal finished(int code, string errors)

  property string _err: ""
  property bool _stopped: false
  property string _part: ""
  property bool _skipping: false
  property real _seen: 0
  property real _errSeen: 0
  property string _over: ""
  property int _pid: 0
  property var _queue: []
  property bool _started: false
  property bool _closing: false

  function start(argv) {
    if (proc.running) return false
    _err = ""
    _stopped = false
    _part = ""
    _skipping = false
    _seen = 0
    _errSeen = 0
    _over = ""
    _pid = 0
    // (What was sent, or closed, before it starts stays for it.)
    _started = false
    proc.stdinEnabled = input
    if (workingDirectory) proc.workingDirectory = workingDirectory
    proc.command = ["/usr/bin/setsid", "--wait"].concat(argv)
    proc.running = true
    deadline.restart()
    return true
  }

  // A line for it to read (with `input`), and its input closed.
  function send(text) {
    if (!input || _closing) return
    if (!_started) { _queue = _queue.concat([String(text)]); return }
    if (proc.running && proc.stdinEnabled) proc.write(String(text))
  }
  function closeInput() {
    if (!input) return
    _closing = true
    if (_started && proc.running && proc.stdinEnabled) proc.stdinEnabled = false
  }

  function stop() {
    if (!proc.running || _stopped) return
    _stopped = true
    _signal("-TERM")
    hardStop.restart()
  }

  function _signal(sig) {
    var pid = proc.processId > 0 ? proc.processId : _pid
    if (pid > 0) Quickshell.execDetached(["/usr/bin/kill", sig, "--", "-" + pid])
  }

  function _size(n) { return n >= 1048576 ? Math.round(n / 1048576) + " MB" : Math.round(n / 1024) + " KB" }

  function _note(text) {
    if (_err.length < 8000) _err += (_err ? "\n" : "") + text
  }

  // A piece of what it printed: whole lines handed on, the rest kept.
  function _take(data) {
    if (_over) return
    _seen += data.length
    if (_seen > maxBytes) {
      _over = "printed more than " + _size(maxBytes)
      _note(_over)
      stop()
      return
    }
    var from = 0
    var nl
    while ((nl = data.indexOf("\n", from)) >= 0) {
      var piece = data.slice(from, nl)
      from = nl + 1
      if (_skipping) { _skipping = false; _part = ""; continue }
      if (_part.length + piece.length > maxLine) { _part = ""; _note("left out a line longer than " + _size(maxLine)); continue }
      var text = _part + piece
      _part = ""
      line(text)
    }
    var rest = data.slice(from)
    if (_skipping || !rest) return
    if (_part.length + rest.length > maxLine) {
      _part = ""
      _skipping = true
      _note("left out a line longer than " + _size(maxLine))
      return
    }
    _part += rest
  }

  // Its errors: counted with its output, the first 8000 characters kept.
  function _takeErr(data) {
    if (_over) return
    _seen += data.length
    _errSeen += data.length
    if (_seen > maxBytes || _errSeen > maxErrors) {
      _over = "printed more than " + _size(_errSeen > maxErrors ? maxErrors : maxBytes)
      _note(_over)
      stop()
      return
    }
    if (_err.length < 8000) _err += data.slice(0, 8000 - _err.length)
  }

  Component.onDestruction: if (proc.running) _signal("-KILL")

  Timer { id: deadline; interval: st.timeoutMs; onTriggered: st.stop() }
  Timer { id: hardStop; interval: 4000; onTriggered: if (proc.running) st._signal("-KILL") }

  Process {
    id: proc
    environment: { var e = Env.forAgent(); for (var k in st.extraEnv) e[k] = String(st.extraEnv[k]); return e }
    onStarted: {
      st._pid = proc.processId > 0 ? proc.processId : 0
      st._started = true
      if (proc.stdinEnabled) {
        st._queue.forEach(function(t) { proc.write(t) })
        st._queue = []
        if (st._closing) proc.stdinEnabled = false
      }
    }
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(data) { st._take(data) }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) { st._takeErr(data) }
    }
    onExited: function(exitCode) {
      deadline.stop()
      hardStop.stop()
      // The last line, if it didn't end with a newline.
      if (st._part && !st._skipping && !st._over) st.line(st._part)
      st._part = ""
      // Whatever it started and left running ends with it.
      st._signal("-KILL")
      st._pid = 0
      // (Stopped for printing too much is a failure, said in errors.)
      st.finished(st._over ? 1 : st._stopped ? -1 : exitCode, st._err.trim())
    }
  }
}
