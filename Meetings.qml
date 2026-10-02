import QtQuick
import Quickshell
import Quickshell.Io
import "Meeting.js" as Meeting

// voxtype's meeting mode, for meeting blocks in Pages. voxtype's daemon
// records (your microphone, and what the computer plays: the other side of
// a call) and writes it out in pieces; it keeps the meeting, and saves its
// transcript when it ends. This only asks: `voxtype meeting start`, `stop`,
// `pause`, `resume`, `list`, `export`; and it follows the meeting from the
// file the daemon keeps ($XDG_RUNTIME_DIR/voxtype/meeting_state: its status
// and its id).
//
// Meeting mode is off until voxtype's settings turn it on: enable() does
// (`voxtype config set meeting.enabled true`, then restarts voxtype), when
// you ask it to.
Item {
  id: mt

  // Store.qml: running a command once.
  property var files: null
  readonly property string stateDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/voxtype"

  // voxtype is there; its meeting mode is on.
  property bool available: false
  property bool enabled: false
  property bool checked: false
  // The meeting on now: "recording", "paused" or "idle", and its id.
  property string status: "idle"
  property string meetingId: ""
  // A meeting stopped, being written out (its id), until voxtype's done.
  property string finishing: ""
  // A command going (start, stop, turning meeting mode on).
  property string working: ""
  // The daemon's file read once: what's recording is known.
  property bool known: false

  // A meeting ended, its transcript saved: export(id) has it now.
  signal finished(string id)

  Component.onCompleted: check()

  function check(done) {
    if (!files) { if (done) done(); return }
    files.exec(["/usr/bin/bash", "-c", "[ -x /usr/bin/voxtype ] || exit 0; echo voxtype; /usr/bin/voxtype config get meeting.enabled 2>/dev/null; exit 0"], function(ok, out) {
      var o = String(out || "")
      mt.available = /voxtype/.test(o)
      mt.enabled = mt.available && /\btrue\b/.test(o)
      mt.checked = true
      if (done) done()
    })
  }

  function take(text) {
    known = true
    var s = Meeting.parseState(text)
    var was = meetingId
    if (s.status !== "idle" && s.id) {
      meetingId = s.id
      status = s.status
      return
    }
    status = "idle"
    if (was) {
      meetingId = ""
      // Stopped (here or elsewhere): its transcript is saved.
      finishing = ""
      finished(was)
    }
  }

  FileView {
    id: stateFile
    path: mt.stateDir + "/meeting_state"
    watchChanges: true
    printErrors: false
    onLoaded: mt.take(text())
    onLoadFailed: mt.take("")
    onFileChanged: reload()
  }
  // (The file comes and goes: while something's on, it's read every second too.)
  Timer {
    interval: 1000
    repeat: true
    running: mt.status !== "idle" || mt.finishing !== "" || mt.working !== ""
    onTriggered: stateFile.reload()
  }

  function run(argv, done, options) {
    if (!files) { done(false, "Omanote runs without the shell"); return }
    files.exec(argv, function(ok, out) {
      var problem = ok ? "" : String(out || "").replace(/^Error:\s*/m, "").split("\n").filter(function(l) { return l.trim() !== "" })[0] || "voxtype couldn't do it"
      done(ok, ok ? out : problem)
    }, options || { timeoutMs: 15000, maxBytes: 64 * 1024 })
  }

  // A meeting started, named `title`: done(ok, problem). Its id comes with
  // the daemon's file a moment later.
  function start(title, done) {
    if (!available) { done(false, "Meetings need voxtype (omarchy voxtype install)"); return }
    if (!enabled) { done(false, "Meeting mode is off in voxtype's settings"); return }
    if (status !== "idle") { done(false, "A meeting is already being recorded"); return }
    working = "start"
    var argv = ["/usr/bin/voxtype", "meeting", "start"]
    var t = String(title || "").replace(/\s+/g, " ").trim().slice(0, 200)
    if (t) argv = argv.concat(["--title", t])
    run(argv, function(ok, problem) {
      mt.working = ""
      stateFile.reload()
      done(ok, ok ? "" : problem)
    })
  }

  function stop(done) {
    if (status === "idle") { if (done) done(false, "No meeting is being recorded"); return }
    finishing = meetingId
    run(["/usr/bin/voxtype", "meeting", "stop"], function(ok, problem) {
      if (!ok) mt.finishing = ""
      stateFile.reload()
      if (done) done(ok, ok ? "" : problem)
    })
  }

  function pause(done) {
    run(["/usr/bin/voxtype", "meeting", "pause"], function(ok, problem) { stateFile.reload(); if (done) done(ok, problem) })
  }

  function resume(done) {
    run(["/usr/bin/voxtype", "meeting", "resume"], function(ok, problem) { stateFile.reload(); if (done) done(ok, problem) })
  }

  // A meeting's transcript (voxtype's JSON export): done(ok, export or problem).
  function fetch(id, done) {
    var clean = Meeting.cleanId(id)
    if (!clean) { done(false, "That isn't a meeting"); return }
    run(["/usr/bin/voxtype", "meeting", "export", clean, "--format", "json"], function(ok, out) {
      done(ok, out)
    }, { timeoutMs: 20000, maxBytes: 32 * 1024 * 1024 })
  }

  // The meetings voxtype kept: done([{ id, title, date, duration, status }]).
  function list(done) {
    run(["/usr/bin/voxtype", "meeting", "list", "--limit", "30"], function(ok, out) {
      done(ok ? Meeting.parseList(out) : [])
    })
  }

  // Meeting mode turned on in voxtype's settings, and voxtype restarted.
  function enable(done) {
    if (!available) { done(false, "Meetings need voxtype (omarchy voxtype install)"); return }
    working = "enable"
    run(["/usr/bin/bash", "-c", "/usr/bin/voxtype config set meeting.enabled true && /usr/bin/systemctl --user restart voxtype.service"], function(ok, problem) {
      // (voxtype takes a moment to come back.)
      enableCheck.done = done
      enableCheck.ok = ok
      enableCheck.problem = problem
      enableCheck.restart()
    }, { timeoutMs: 30000, maxBytes: 64 * 1024 })
  }
  Timer {
    id: enableCheck
    property var done: null
    property bool ok: false
    property string problem: ""
    interval: 1500
    onTriggered: mt.check(function() {
      mt.working = ""
      var d = done
      done = null
      if (d) d(mt.enabled, mt.enabled ? "" : (problem || "Meeting mode is still off"))
    })
  }
}
