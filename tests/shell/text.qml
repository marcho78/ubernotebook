import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL: Quickshell only
// imports folders outside the test's own that way.)
import "@PLUGIN@" as UN

// Text in any script, read through real pipes, in a real Quickshell (tests/run
// starts it offscreen): Quickshell decodes what a program prints a piece at a
// time, so every way Uber Notebook reads long text has it arrive ASCII, and
// nothing comes back with a character cut in two (U+FFFD). Megabytes of
// "é中😀" through the notes helper, the fallback read, execText, and the
// agents' line filter. Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  UN.Store { id: store; active: false }
  UN.Stream { id: stream }

  readonly property string unit: "\u00e9\u4e2d\ud83d\ude00 "
  readonly property string text: new Array(150001).join(unit)
  function bad(t) { return String(t).split("\ufffd").length - 1 }

  Component.onCompleted: {
    // A page of it, the same as a file, and three lines of JSON an agent might print.
    store.exec(["/usr/bin/bash", "-c", "d=$(/usr/bin/mktemp -d) || exit 1; /usr/bin/mkdir -p \"$d/notes/Pages\"; "
      + "/usr/bin/python3 -I -S -c 'import json,sys; t=\"\\u00e9\\u4e2d\\U0001F600 \"*150000; d=sys.argv[1]; "
      + "open(d+\"/notes/Pages/big.json\",\"w\",encoding=\"utf-8\").write(json.dumps({\"t\":t},ensure_ascii=False)); "
      + "open(d+\"/plain.txt\",\"w\",encoding=\"utf-8\").write(t); "
      + "open(d+\"/lines.jsonl\",\"w\",encoding=\"utf-8\").write(\"\".join(json.dumps({\"n\":i,\"t\":t[:60000]},ensure_ascii=False)+\"\\n\" for i in range(3)))' \"$d\"; /usr/bin/mkfifo \"$d/pipe\"; printf '%s' \"$d\""], function(ok, out) {
      var d = String(out).trim()
      if (!ok || !d) { console.log("FAIL setup"); Qt.quit(); return }
      store.rootPath = d + "/notes"
      store.notesRoot = d + "/notes"
      store.readFiles([d + "/notes/Pages/big.json"], function(got) {
        var page = store.parseJson(got[d + "/notes/Pages/big.json"] || "")
        say("the notes helper: every character as it is", page !== null && page.t === root.text, page ? "replacements " + root.bad(page.t) : "unreadable")
        store.readFilesAsBefore([d + "/pipe", d + "/plain.txt"], function(got2, read2, failed2) {
          var t2 = got2[d + "/plain.txt"] || ""
          say("the fallback read: every character as it is", t2 === root.text, "replacements " + root.bad(t2) + " length " + t2.length)
          say("the fallback read: one it couldn't read is said, not empty", read2 === true && JSON.stringify(failed2) === JSON.stringify([d + "/pipe"]) && got2[d + "/pipe"] === undefined, JSON.stringify(failed2))
          store.execText(["/usr/bin/cat", "--", d + "/plain.txt"], function(ok3, t3) {
            say("execText: every character as it is", ok3 && t3 === root.text, "replacements " + root.bad(t3))
            var lines = []
            stream.line.connect(function(l) { lines.push(l) })
            stream.finished.connect(function() {
              var parsed = lines.map(function(l) { return store.parseJson(l) })
              var good = parsed.length === 3 && parsed.every(function(o, i) { return o && o.n === i && o.t === root.text.slice(0, o.t.length) && root.bad(o.t) === 0 })
              say("an agent's lines, through ascii-lines: every character as it is", good, parsed.length + " lines, replacements " + parsed.map(function(o) { return o ? root.bad(o.t) : -1 }).join(","))
              store.exec(["/usr/bin/rm", "-rf", "--", d], function() { console.log("DONE"); Qt.quit() })
            })
            stream.start(["/usr/bin/bash", "-c", "h=$1; shift; set -o pipefail; \"$@\" | /usr/bin/python3 -I -S \"$h\" ascii-lines", "uber-notebook-agent", store.filesHelper, "/usr/bin/cat", "--", d + "/lines.jsonl"])
          }, { maxBytes: 4 * 1024 * 1024 })
        })
      })
    }, { timeoutMs: 30000 })
  }
  Timer { interval: 60000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
