import QtQuick
import Quickshell
import Quickshell.Io

// Runs one command from an argument list, by absolute path and never through
// a shell, then reports once: finished(ok, output).
//
// The command runs as the leader of its own process group (setsid), so a
// deadline, an output overrun or cancel() ends it together with anything it
// started. Output is counted as it arrives, stdout and stderr together, and
// nothing past the budget is kept. On failure, `output` says why: the budget
// or deadline it broke, or what the command printed on stderr.
//
// replace(argv) is for searches that follow your typing: it stops the command
// in flight (its result is never reported) and starts the new one.
Item {
  id: run

  property int timeoutMs: 5000
  property int maxBytes: 64 * 1024
  // Exit codes that still count as success (find and stat use 1 for "some
  // paths were missing").
  property var okCodes: [0]
  readonly property bool running: proc.running

  signal finished(bool ok, string output)

  property string _out: ""
  property string _err: ""
  property int _seen: 0
  property string _failed: ""
  property bool _cancelled: false
  property var _pending: null

  function start(argv) {
    if (proc.running) return false
    _begin(argv)
    return true
  }

  function replace(argv) {
    if (proc.running) {
      _pending = argv
      _stop()
    } else {
      _pending = null
      _begin(argv)
    }
  }

  function cancel() {
    _pending = null
    _stop()
  }

  function _begin(argv) {
    _out = ""
    _err = ""
    _seen = 0
    _failed = ""
    _cancelled = false
    proc.command = ["/usr/bin/setsid", "--wait"].concat(argv)
    proc.running = true
    deadline.restart()
  }

  // What replace() asked for, if nothing has called it off since.
  function _startPending() {
    var next = _pending
    _pending = null
    if (next && !proc.running) _begin(next)
  }

  function _kill() {
    if (proc.processId > 0) Quickshell.execDetached(["/usr/bin/kill", "-KILL", "--", "-" + proc.processId])
  }

  function _stop() {
    if (!proc.running || _cancelled) return
    _cancelled = true
    _kill()
  }

  function _fail(reason) {
    if (_failed) return
    _failed = reason
    _kill()
  }

  function _take(data, isError) {
    if (_failed || _cancelled) return
    _seen += data.length
    if (_seen > maxBytes) {
      _fail("printed more than " + maxBytes + " bytes")
      return
    }
    if (isError) {
      if (_err.length < 2000) _err += data
    } else {
      _out += data
    }
  }

  Timer {
    id: deadline
    interval: run.timeoutMs
    onTriggered: run._fail("took longer than " + run.timeoutMs + "ms")
  }

  Process {
    id: proc
    stdout: SplitParser {
      splitMarker: ""
      onRead: function(data) { run._take(data, false) }
    }
    stderr: SplitParser {
      splitMarker: ""
      onRead: function(data) { run._take(data, true) }
    }
    onExited: function(exitCode) {
      deadline.stop()
      if (run._cancelled) {
        run._cancelled = false
        run._out = ""
        run._err = ""
        if (run._pending) Qt.callLater(run._startPending)
        return
      }
      var ok = run.okCodes.indexOf(exitCode) >= 0 && !run._failed
      var out = ok ? run._out : (run._failed || (run._err.trim() + (run._out ? "\n" + run._out : "")).trim() || ("exited with " + exitCode))
      run._out = ""
      run._err = ""
      run.finished(ok, out)
    }
  }
}
