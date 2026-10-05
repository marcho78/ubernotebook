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
                root.notesChecks(d)
              })
            })
          }, 1000)
        })
      })
    })
  }
  // The notes folder, by the files helper: what's read and written there,
  // never through a link; a file that can't be read said, not "not there".
  function notesChecks(d) {
    var notes = d + "/notes"
    store.exec(["/usr/bin/bash", "-c", "mkdir -p \"$1/Pages\" \"$1/nb1\" && printf SECRET > \"$2/secret.json\" && ln -s \"$2/secret.json\" \"$1/Pages/link.json\" && printf '{}' > \"$1/nb1/notebook.json\"", "x", notes, d], function(ok) {
      store.rootPath = notes
      store.notesRoot = notes
      store.writeFile(notes + "/Pages/a.json", '{"a":1}', function(wrote) {
        say("notes: written", wrote === true && store.notes !== null, "helper " + (store.notes !== null))
        store.readFiles([notes + "/Pages/a.json", notes + "/Pages/none.json", notes + "/Pages/link.json"], function(got, read, failed) {
          say("notes: read, by the files helper", read === true && got[notes + "/Pages/a.json"] === '{"a":1}', JSON.stringify(got))
          say("notes: a link can't be read, and it's said (not taken for not there)", JSON.stringify(failed) === JSON.stringify([notes + "/Pages/link.json"]) && got[notes + "/Pages/link.json"] === undefined, JSON.stringify(failed))
          store.readGlob(notes, "*/notebook.json", function(found, read2) {
            say("notes: found by pattern", read2 === true && found[notes + "/nb1/notebook.json"] === "{}", JSON.stringify(found))
            store.mkdirs([notes + "/Pages/assets"], function(made) {
              store.writeFile(notes + "/Pages/link.json", "OVERWRITTEN", function(wrote2) {
                store.readFiles([d + "/secret.json"], function(sec) {
                  say("notes: never written through a link", wrote2 === false && sec[d + "/secret.json"] === "SECRET", "wrote " + wrote2 + " secret " + sec[d + "/secret.json"])
                  store.exec(["/usr/bin/test", "-d", notes + "/Pages/assets"], function(isDir) {
                    say("notes: folders made", made === true && isDir, "")
                    root.fallbackChecks(d, notes)
                  })
                })
              })
            })
          })
        })
      })
    })
  }
  // When the helper doesn't answer, notes are read and written as before:
  // one stopped with a save waiting (paused first, so it can't answer it),
  // then one off (it failed too often).
  function fallbackChecks(d, notes) {
    var h = store.notes
    store.exec(["/usr/bin/bash", "-c", "/usr/bin/pkill -STOP -f -- \"uber-notebook-files serve $1\\$\"", "x", notes], function(paused) {
      if (!paused) { say("fallback: helper paused", false, ""); Qt.quit(); return }
      root.fallbackWrite(d, notes, h)
      h.run.stop()
    })
  }
  function fallbackWrite(d, notes, h) {
    store.writeFile(notes + "/Pages/b.json", '{"b":1}', function(wrote) {
      store.readFiles([notes + "/Pages/b.json"], function(got) {
        say("fallback: a save the stopped helper didn't answer is written as before", wrote === true && got[notes + "/Pages/b.json"] === '{"b":1}' && h.dead, "wrote " + wrote + " dead " + h.dead)
        // (Off: it failed 3 times. The one running now ends first.)
        store.notesFailures = 3
        if (store.notes) store.notes.run.stop()
        var wait = Qt.createQmlObject('import QtQuick; Timer { interval: 100; repeat: true; running: true }', root)
        var tries = 0
        wait.triggered.connect(function() {
          if (store.notes !== null && ++tries < 100) return
          wait.stop()
          root.helperOff(d, notes)
        })
      })
    })
  }
  function helperOff(d, notes) {
    store.writeFile(notes + "/Pages/c.json", '{"c":1}', function(wrote2) {
      store.readFiles([notes + "/Pages/a.json", notes + "/Pages/c.json"], function(got2, read2) {
        say("fallback: the helper off, read and written as before", wrote2 === true && read2 === true && store.notes === null
          && got2[notes + "/Pages/a.json"] === '{"a":1}' && got2[notes + "/Pages/c.json"] === '{"c":1}', JSON.stringify(got2))
        store.exec(["/usr/bin/rm", "-rf", "--", d], function() { console.log("DONE"); Qt.quit() })
      })
    })
  }
  Timer { interval: 30000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
