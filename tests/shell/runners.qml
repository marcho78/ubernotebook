import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL: Quickshell only
// imports folders outside the test's own that way.)
import "@PLUGIN@" as UN

// Run.qml and Stream.qml with real programs, in a real Quickshell (tests/run
// starts it offscreen; nothing is shown): the environment a command gets,
// what it's given on stdin, what's left running ending with it, lines cut
// as they come, and the budgets. Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  property var results: []
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }
  property int pending: 0
  function begin() { pending++ }
  function end() { if (--pending === 0) { console.log("DONE"); Qt.quit() } }

  Component { id: runC; UN.Run {} }
  Component { id: streamC; UN.Stream {} }

  function run(argv, opts, done) {
    begin()
    var r = runC.createObject(root, opts || {})
    r.finished.connect(function(ok, out) { done(ok, out); r.destroy(); end() })
    r.start(argv)
  }
  function stream(argv, opts, done) {
    begin()
    var s = streamC.createObject(root, opts || {})
    var lines = []
    s.line.connect(function(t) { lines.push(t) })
    s.finished.connect(function(code, errors) { done(code, errors, lines); s.destroy(); end() })
    s.start(argv)
  }
  function alive(pid, done) {
    run(["/usr/bin/bash", "-c", "s=$(cut -d' ' -f3 /proc/$1/stat 2>/dev/null); case \"$s\" in ''|Z|X) echo no;; *) echo yes;; esac", "x", String(pid)], {}, function(ok, out) { done(String(out).trim() === "yes") })
  }

  Component.onCompleted: {
    run(["/usr/bin/env"], {}, function(ok, out) {
      say("run env: PATH is the system's", /^PATH=\/usr\/bin$/m.test(out), "")
      say("run env: no BASH_ENV/LD_PRELOAD/TAR_OPTIONS", !/^(BASH_ENV|LD_PRELOAD|TAR_OPTIONS)=/m.test(out), "")
      say("run env: HOME and XDG_RUNTIME_DIR kept", /^HOME=/m.test(out) && /^XDG_RUNTIME_DIR=/m.test(out), "")
      say("run env: nothing else (e.g. UBER_NOTEBOOK_TEST_SECRET)", !/^UBER_NOTEBOOK_TEST_SECRET=/m.test(out), "")
    })
    run(["/usr/bin/wc", "-c"], { input: "hello wörld" }, function(ok, out) { say("run stdin", ok && String(out).trim() === "12", out) })
    run(["/usr/bin/bash", "-c", "/usr/bin/sleep 30 & echo $!"], {}, function(ok, out) {
      var pid = parseInt(out)
      Qt.callLater(function() { begin(); delay.start(); delay.then = function() { alive(pid, function(yes) { say("run: what it left running ends with it", pid > 0 && !yes, "pid " + pid); end() }) } })
    })
    run(["/usr/bin/bash", "-c", "/usr/bin/sleep 30 & echo $!"], { keepChildren: true }, function(ok, out) {
      var pid = parseInt(out)
      Qt.callLater(function() { begin(); delay2.start(); delay2.then = function() { alive(pid, function(yes) {
        say("run keepChildren: it stays", pid > 0 && yes, "pid " + pid)
        if (pid > 0) run(["/usr/bin/kill", "--", String(pid)], { okCodes: [0, 1] }, function() {})
        end() }) } })
    })
    stream(["/usr/bin/bash", "-c", "printf 'one\\ntw'; sleep 0.2; printf 'o\\nthree'"], {}, function(code, errors, lines) {
      say("stream lines across pieces, last without newline", code === 0 && JSON.stringify(lines) === JSON.stringify(["one", "two", "three"]), JSON.stringify(lines))
    })
    stream(["/usr/bin/bash", "-c", "printf 'a\\n'; head -c 3000 /dev/zero | tr '\\\\0' x; printf '\\nb\\n'"], { maxLine: 1000 }, function(code, errors, lines) {
      say("stream: a line over maxLine left out, the rest kept", JSON.stringify(lines) === JSON.stringify(["a", "b"]) && /longer than/.test(errors), JSON.stringify(lines) + " / " + errors)
    })
    stream(["/usr/bin/bash", "-c", "yes 0123456789"], { maxBytes: 200000 }, function(code, errors, lines) {
      say("stream: past maxBytes it's stopped, a failure", code === 1 && /printed more than/.test(errors), "code " + code + " lines " + lines.length + " " + errors)
    })
    stream(["/usr/bin/bash", "-c", "yes 0123456789 >&2"], { maxBytes: 200000 }, function(code, errors, lines) {
      say("stream: its errors count too: past maxBytes it's stopped", code === 1 && /printed more than/.test(errors) && errors.length <= 8200, "code " + code + " errors " + errors.length)
    })
    // (An agent's: its output has six times the room, being made ASCII on
    // its way; its errors aren't, and keep theirs.)
    stream(["/usr/bin/bash", "-c", "yes 0123456789 >&2"], { maxBytes: 6000000, maxErrors: 200000 }, function(code, errors, lines) {
      say("stream: its errors past their own room: stopped", code === 1 && errors.indexOf("printed more than 195 KB") >= 0, "code " + code + " " + errors.slice(-60))
    })
    stream(["/usr/bin/bash", "-c", "/usr/bin/sleep 30 & echo $!"], {}, function(code, errors, lines) {
      var pid = parseInt(lines[0])
      Qt.callLater(function() { begin(); delay3.start(); delay3.then = function() { alive(pid, function(yes) { say("stream: what it left running ends with it", pid > 0 && !yes, "pid " + pid); end() }) } })
    })
    // With input: what's sent is read as lines (sent before it started and
    // after, in order), and it ends when its input's closed.
    begin()
    var talk = streamC.createObject(root, { input: true })
    var heard = []
    talk.line.connect(function(t) { heard.push(t); if (t === "got:second") talk.closeInput() })
    talk.finished.connect(function(code, errors) {
      say("stream input: lines sent before it started and after, in order; it ends when its input's closed",
        code === 0 && JSON.stringify(heard) === JSON.stringify(["got:first", "got:second", "end"]), JSON.stringify(heard) + " " + errors)
      talk.destroy()
      end()
    })
    talk.send("first\n")
    talk.start(["/usr/bin/bash", "-c", "while IFS= read -r l; do echo \"got:$l\"; done; echo end"])
    Qt.callLater(function() { talk.send("second\n") })
    stream(["/usr/bin/env"], {}, function(code, errors, lines) {
      var t = lines.join("\n")
      say("stream env: the agent's own (HOME, UBER_NOTEBOOK_TEST_SECRET kept), but no BASH_ENV/LD_PRELOAD", /^HOME=/m.test(t) && /^UBER_NOTEBOOK_TEST_SECRET=/m.test(t) && !/^(BASH_ENV|LD_PRELOAD)=/m.test(t), "")
    })
  }
  Timer { id: delay; interval: 600; property var then: null; onTriggered: then() }
  Timer { id: delay2; interval: 600; property var then: null; onTriggered: then() }
  Timer { id: delay3; interval: 600; property var then: null; onTriggered: then() }
  Timer { interval: 20000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
