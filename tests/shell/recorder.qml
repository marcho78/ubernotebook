import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL: Quickshell only
// imports folders outside the test's own that way.)
import "@PLUGIN@" as UN

// Recorder.qml with a real process, in a real Quickshell (tests/run starts it
// offscreen): a stand-in for ffmpeg (a script, no microphone) that prints
// levels, a line far too long and errors, starts a child of its own, and
// finishes its file on SIGINT. The recording: its file finished, its levels
// read, the environment a tool gets, and what it started ended with it; one
// that won't stop ended anyway; one that prints too much stopped. Prints
// PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  UN.Store { id: store; active: false }
  UN.Recorder { id: rec; files: store }

  // The stand-in: its last argument is the file it records to.
  // $1 of the script is what it does on SIGINT: "finish" or "ignore";
  // FLOOD=1 in its file's name: it prints far too much.
  readonly property string fake: "#!/usr/bin/bash\n"
    + "for a in \"$@\"; do out=$a; done; d=${out%/*}\n"
    + "/usr/bin/env > \"$d/env.txt\"\n"
    + "/usr/bin/sleep 300 & echo $! > \"$d/child.pid\"\n"
    + "case \"$out\" in *stubborn*) trap '' INT ;; *) trap 'echo finished > \"$out\"; exit 0' INT ;; esac\n"
    + "/usr/bin/head -c 100000 /dev/zero | /usr/bin/tr '\\0' x; echo\n"
    + "for i in $(/usr/bin/seq 1 30); do echo \"noise $i\" >&2; done\n"
    + "case \"$out\" in *flood*) while :; do /usr/bin/head -c 65536 /dev/zero | /usr/bin/tr '\\0' y; done ;; esac\n"
    + "while :; do echo 'lavfi.astats.Overall.RMS_level=-20.0'; /usr/bin/sleep 0.1; done\n"

  property string dir: ""
  Component.onCompleted: {
    store.exec(["/usr/bin/bash", "-c", "d=$(/usr/bin/mktemp -d) || exit 1; printf '%s' \"$1\" > \"$d/ffmpeg\"; /usr/bin/chmod +x \"$d/ffmpeg\"; printf '%s' \"$d\"", "x", fake], function(ok, out) {
      root.dir = String(out).trim()
      if (!ok || !root.dir) { console.log("FAIL setup"); Qt.quit(); return }
      rec.program = root.dir + "/ffmpeg"
      rec.canRecord = true
      rec.boost = false
      root.first()
    })
  }
  function after(ms, fn) {
    var t = Qt.createQmlObject('import QtQuick; Timer { running: true }', root)
    t.interval = ms
    t.triggered.connect(function() { t.destroy(); fn() })
  }
  function shell(script, args, done) { store.exec(["/usr/bin/bash", "-c", script, "x"].concat(args || []), function(ok, out) { done(ok, String(out || "")) }) }

  // Recorded, then stopped: its file finished, its levels, its environment,
  // and its child ended with it.
  function first() {
    var file = root.dir + "/one/note.ogg"
    var why = rec.start("audio", "test", file, function(ok, r) {
      say("stopped: its file finished on SIGINT", ok === true && r.file === file, JSON.stringify(r).slice(0, 200))
      say("its levels read (the line too long left out)", r.peaks && r.peaks.length > 0 && rec._err.length <= 600, "err " + rec._err.length)
      shell("cat \"$1/one/note.ogg\"; echo; grep -c '' \"$1/one/env.txt\"; grep -E '^(PATH|UBER_NOTEBOOK_TEST_SECRET|BASH_ENV)=' \"$1/one/env.txt\"; sleep 0.5; kill -0 $(cat \"$1/one/child.pid\") 2>/dev/null && echo child-alive || echo child-gone", [root.dir], function(ok2, out) {
        var lines = out.split("\n")
        say("the file it made", lines[0] === "finished", lines[0])
        say("a tool's environment only (no secret, no BASH_ENV, PATH /usr/bin)", out.indexOf("UBER_NOTEBOOK_TEST_SECRET") < 0 && out.indexOf("BASH_ENV") < 0 && out.indexOf("PATH=/usr/bin\n") >= 0, out.replace(/\n/g, " | "))
        say("what it started, ended with it", /child-gone/.test(out), out.replace(/\n/g, " | "))
        root.second()
      })
    })
    if (why) { say("started", false, why); Qt.quit(); return }
    after(1200, function() { rec.stop() })
  }

  // One that won't stop on SIGINT: ended a few seconds later, with its child.
  function second() {
    var file = root.dir + "/two/stubborn.ogg"
    var t0 = Date.now()
    rec.start("audio", "test", file, function(ok, r) {
      var took = Date.now() - t0
      shell("sleep 0.5; kill -0 $(cat \"$1/two/child.pid\") 2>/dev/null && echo child-alive || echo child-gone", [root.dir], function(ok2, out) {
        say("one that won't stop: ended anyway, with what it started", took < 9000 && /child-gone/.test(out), took + "ms " + out.trim())
        root.third()
      })
    })
    after(800, function() { rec.stop() })
  }

  // One that prints far too much: stopped by itself.
  function third() {
    rec.outputMax = 2 * 1024 * 1024
    var file = root.dir + "/three/flood.ogg"
    var t0 = Date.now()
    rec.start("audio", "test", file, function(ok, r) {
      say("one that prints too much: stopped", Date.now() - t0 < 8000 && rec._seen > rec.outputMax, (Date.now() - t0) + "ms seen " + rec._seen)
      shell("rm -rf -- \"$1\"", [root.dir], function() { console.log("DONE"); Qt.quit() })
    })
  }
  Timer { interval: 40000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
