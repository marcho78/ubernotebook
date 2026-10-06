import QtQuick
import Quickshell
// (tests/run writes the plugin folder here, as a file: URL.)
import "@PLUGIN@" as UN

// voxtype's meeting mode turned on (Meetings.qml), each command it runs
// answered here (nothing reaches voxtype or your settings): its setting set,
// never a service restarted; until voxtype's daemon has started again it's
// waiting, says what to do, and a meeting doesn't start; once it has, one
// does. Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  QtObject {
    id: runner
    property var ran: []
    property bool enabled: false
    // When voxtype's daemon started (seconds), as Meeting.DAEMON_SCRIPT says.
    property real daemon: 1000
    function exec(argv, done, options) {
      ran = ran.concat([argv])
      if (argv[0] === "/usr/bin/voxtype" && argv[1] === "config" && argv[2] === "set") {
        enabled = argv[4] === "true"
        Qt.callLater(function() { done(true, "") })
        return
      }
      if (argv[0] === "/usr/bin/bash" && argv[3] === "uber-notebook-meetings") {
        var out = "voxtype\n" + (enabled ? "true" : "false") + "\n" + (argv[2].indexOf("daemon $n") >= 0 ? "daemon " + daemon + "\n" : "")
        Qt.callLater(function() { done(true, out) })
        return
      }
      if (argv[0] === "/usr/bin/voxtype" && argv[1] === "meeting") { Qt.callLater(function() { done(true, "") }); return }
      Qt.callLater(function() { done(false, "not here") })
    }
  }

  UN.Meetings { id: mt; files: runner }

  function after(ms, fn) {
    var t = Qt.createQmlObject("import QtQuick; Timer { repeat: false }", root)
    t.interval = ms
    t.triggered.connect(function() { t.destroy(); fn() })
    t.start()
  }

  Component.onCompleted: after(300, function() {
    say("off at first", mt.checked && mt.available && !mt.enabled && !mt.waiting)
    mt.enable(function(ok, problem) {
      say("turned on in voxtype's settings", ok && mt.enabled, problem)
      say("waiting for voxtype to restart, and says what to do", mt.waiting
        && mt.waitingText.indexOf("log out and back in, or restart the voxtype service yourself") >= 0)
      var set = runner.ran.some(function(a) { return a.join(" ") === "/usr/bin/voxtype config set meeting.enabled true" })
      var restarted = runner.ran.some(function(a) { return a.join(" ").indexOf("systemctl") >= 0 })
      say("its setting set; no service restarted", set && !restarted)
      mt.start("Sync", function(ok2, why) {
        say("no meeting while waiting", !ok2 && why === mt.waitingText, why)
        // Asked again, voxtype's daemon the one from before: still waiting.
        mt.check(function() {
          say("voxtype not started again: still waiting", mt.waiting)
          // voxtype started again, after it was turned on.
          runner.daemon = Math.ceil(mt.changedAt / 1000) + 5
          mt.check(function() {
            say("voxtype started again: in effect", !mt.waiting)
            mt.start("Sync", function(ok3, why3) {
              var asked = runner.ran.some(function(a) { return a[0] === "/usr/bin/voxtype" && a[1] === "meeting" && a[2] === "start" })
              say("a meeting starts", ok3 && asked, why3)
              console.log("DONE")
              Qt.quit()
            })
          })
        })
      })
    })
  })
}
