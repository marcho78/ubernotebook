import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL: Quickshell only
// imports folders outside the test's own that way.)
import "@PLUGIN@" as UN

// Store.qml's reads with real files, in a real Quickshell (tests/run starts it
// offscreen; nothing is shown, and the store looks for no notes folder:
// active is false): many files read in one go, each only as itself (what's in
// one can't pass for another), only what was asked for, and a read that
// didn't go through said so. Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  UN.Store { id: store; active: false }

  property string dir: ""
  Component.onCompleted: {
    // A folder of files: a page, one whose text tries to pass for another
    // file (with marks it can't know), one too big for a small read.
    store.exec(["/usr/bin/bash", "-c", "d=$(/usr/bin/mktemp -d) || exit 1; printf '{\"a\":1}' > \"$d/a.json\"; "
      + "printf 'x\\036guess\\037%s/b.json\\037{\"evil\":1}\\036\\037%s/b.json\\037{\"evil\":2}' \"$d\" \"$d\" > \"$d/c.json\"; "
      + "/usr/bin/head -c 5000 /dev/zero | /usr/bin/tr '\\0' x > \"$d/big.json\"; printf '%s' \"$d\""], function(ok, out) {
      root.dir = String(out).trim()
      if (!ok || !root.dir) { console.log("FAIL setup"); Qt.quit(); return }
      var d = root.dir
      store.readFiles([d + "/a.json", d + "/b.json", d + "/c.json"], function(got, read) {
        say("read: it went through", read === true)
        say("read: each file as itself", got[d + "/a.json"] === '{"a":1}', JSON.stringify(got[d + "/a.json"]))
        say("read: what's in one can't pass for another", got[d + "/b.json"] === undefined && String(got[d + "/c.json"]).indexOf('{"evil":2}') > 0, JSON.stringify(Object.keys(got)))
        store.readGlob(d, "*.json", function(all, read2) {
          var names = Object.keys(all).map(function(p) { return p.slice(d.length + 1) }).sort()
          say("glob: the files there, only", read2 === true && JSON.stringify(names) === JSON.stringify(["a.json", "big.json", "c.json"]), JSON.stringify(names))
          store.readFiles([d + "/a.json", d + "/big.json"], function(got3, read3) {
            say("a read over its size: said, nothing in it", read3 === false && Object.keys(got3).length === 0, String(read3))
            // Saves of one file while it's being written: the newest is
            // written, and everyone waiting hears when it's done.
            var heard = []
            for (var k = 1; k <= 4; k++) (function(n) { store.writeFile(d + "/w.json", '{"n":' + n + '}', function(ok) { heard.push(n + ":" + ok) }) })(k)
            var check = Qt.createQmlObject('import QtQuick; Timer { interval: 100; repeat: true; running: true }', root)
            var tries = 0
            check.triggered.connect(function() {
              if (heard.length < 4 && ++tries < 50) return
              check.stop()
              store.readFiles([d + "/w.json"], function(got4) {
                say("saves of one file: every waiter hears", heard.length === 4, JSON.stringify(heard))
                say("saves of one file: the newest is there", got4[d + "/w.json"] === '{"n":4}', JSON.stringify(got4[d + "/w.json"]))
                store.exec(["/usr/bin/rm", "-rf", "--", d], function() { console.log("DONE"); Qt.quit() })
              })
            })
          }, 1000)
        })
      })
    })
  }
  Timer { interval: 20000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
