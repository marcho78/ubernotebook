import QtQuick
import Quickshell
import Quickshell.Io

// Runs one command from an argument list, by absolute path, and hands on
// what it prints a line at a time, as it prints it: line(text) for each line
// of its output, then finished(code, errors) once (code -1: stopped). For an
// agent working without a terminal (Agent.js), which says each step as a
// line of JSON.
//
// Like Run.qml, the command leads its own process group (setsid), so stop()
// (or the deadline) ends it together with anything it started: a gentle
// stop first, and a hard one if it's still there a few seconds later.
Item {
  id: st

  property string workingDirectory: ""
  property int timeoutMs: 30 * 60 * 1000
  readonly property bool running: proc.running

  signal line(string text)
  signal finished(int code, string errors)

  property string _err: ""
  property bool _stopped: false

  function start(argv) {
    if (proc.running) return false
    _err = ""
    _stopped = false
    if (workingDirectory) proc.workingDirectory = workingDirectory
    proc.command = ["/usr/bin/setsid", "--wait"].concat(argv)
    proc.running = true
    deadline.restart()
    return true
  }

  function stop() {
    if (!proc.running || _stopped) return
    _stopped = true
    _signal("-TERM")
    hardStop.restart()
  }

  function _signal(sig) {
    if (proc.processId > 0) Quickshell.execDetached(["/usr/bin/kill", sig, "--", "-" + proc.processId])
  }

  Timer { id: deadline; interval: st.timeoutMs; onTriggered: st.stop() }
  Timer { id: hardStop; interval: 4000; onTriggered: if (proc.running) st._signal("-KILL") }

  Process {
    id: proc
    stdout: SplitParser { onRead: function(data) { st.line(data) } }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) { if (st._err.length < 8000) st._err += data }
    }
    onExited: function(exitCode) {
      deadline.stop()
      hardStop.stop()
      st.finished(st._stopped ? -1 : exitCode, st._err.trim())
    }
  }
}
