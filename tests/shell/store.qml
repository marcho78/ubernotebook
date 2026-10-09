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
          store.readFiles([d + "/a.json", d + "/big.json"], function(got3, read3, failed3) {
            say("a file over its size: said (failed), not read; the others read", read3 === true && got3[d + "/big.json"] === undefined
              && JSON.stringify(failed3) === JSON.stringify([d + "/big.json"]) && got3[d + "/a.json"] === '{"a":1}', JSON.stringify(failed3))
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
                    root.trashWhileWriting(d, notes)
                  })
                })
              })
            })
          })
        })
      })
    })
  }
  // A page put in the trash while its save is under way (the helper held):
  // what was waiting to be written is dropped, the move waits for the save,
  // and then the page is gone, never written back.
  function trashWhileWriting(d, notes) {
    var doomed = notes + "/Pages/doomed.json"
    function sig(s, done) { store.exec(["/usr/bin/bash", "-c", "/usr/bin/pkill -" + s + " -f -- \"uber-notebook-files serve $1\\$\"", "x", notes], function(ok) { done(ok) }) }
    sig("STOP", function(paused) {
      store.writeKept(doomed, "one", function() {})
      store.writeKept(doomed, "two", function() {})
      store.trash(doomed, "doomed")
      var held = store.trashLater.length === 1 && store.queued[doomed] === undefined
      // (Another profile opened meanwhile: it still goes into this one's trash.)
      store.rootPath = d + "/elsewhere"
      sig("CONT", function() {
        var wait = Qt.createQmlObject('import QtQuick; Timer { interval: 100; repeat: true; running: true }', root)
        var tries = 0
        wait.triggered.connect(function() {
          if ((store.trashLater.length || store.writing[doomed]) && ++tries < 50) return
          wait.stop()
          // (The move itself, after the save: a moment more.)
          store.exec(["/usr/bin/bash", "-c", "/usr/bin/sleep 0.5; [ -e \"$1\" ] && echo there || echo gone; /usr/bin/ls \"$2\" 2>/dev/null | /usr/bin/grep -c doomed; /usr/bin/ls \"$3\" 2>/dev/null | /usr/bin/grep -c doomed", "x", doomed, notes + "/.trash", d + "/elsewhere/.trash"], function(ok, out) {
            var lines = String(out).trim().split("\n")
            say("notes: trashed while being written: waits, then gone, into its own profile's trash", paused && held && lines[0] === "gone" && lines[1] === "1" && lines[2] === "0" && store.unsaved[doomed] === undefined, "held " + held + " " + lines.join(" | "))
            store.rootPath = notes
            root.fallbackChecks(d, notes)
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
  // A save of your notes that fails (here, a folder it can't write in) is
  // kept, its newest text, said once; tried again once it can be, saved,
  // and said; an older text never written over a newer one.
  function keptChecks(d) {
    var fails = 0
    var back = 0
    store.failed.connect(function() { fails++ })
    store.recovered.connect(function(n) { back += n })
    function sh(script, done) { store.exec(["/usr/bin/bash", "-c", script, "x", d], function() { done() }) }
    var p = d + "/ro/x.json"
    var q = d + "/ro/y.json"
    sh("/usr/bin/mkdir -p \"$1/ro\" && /usr/bin/chmod 500 \"$1/ro\"", function() {
      store.writeKept(p, "one", function(ok1) {
        store.writeKept(p, "two", function(ok2) {
          say("kept: a save that failed is kept, its newest text, said once", ok1 === false && ok2 === false && store.unsaved[p] !== undefined && store.unsaved[p].text === "two" && fails === 1,
            "ok " + ok1 + "," + ok2 + " fails " + fails + " " + JSON.stringify(store.unsaved))
          store.writeKept(q, "old", function(okOld) {
            sh("/usr/bin/chmod 700 \"$1/ro\"", function() {
              store.writeKept(q, "new", function(okNew) {
                store.retryUnsaved(function(left) {
                  store.readFiles([p, q], function(got) {
                    say("kept: tried again, saved, and said (that one, and the one a newer save saved)", left === 0 && got[p] === "two" && back === 2 && store.unsavedCount === 0, "left " + left + " back " + back + " " + JSON.stringify(got))
                    say("kept: an older text never over a newer one", okOld === false && okNew === true && got[q] === "new", JSON.stringify(got[q]))
                    root.raceCheck(d)
                  })
                })
              })
            })
          })
        })
      })
    })
  }
  // A retry while a newer text is being written (the window closing just
  // after an edit): never queued behind it, so the newer text stays.
  function raceCheck(d) {
    var r = d + "/ro/z.json"
    var said = 0
    store.recovered.connect(function(n) { said += n })
    function sh(script, done) { store.exec(["/usr/bin/bash", "-c", script, "x", d], function() { done() }) }
    sh("/usr/bin/chmod 500 \"$1/ro\"", function() {
      store.writeKept(r, "old", function(ok1) {
        sh("/usr/bin/chmod 700 \"$1/ro\"", function() {
          var newOk = null
          store.writeKept(r, "new", function(ok2) { newOk = ok2 })
          // (In the same moment: "new" is being written.)
          store.retryUnsaved(function() {})
          var wait = Qt.createQmlObject('import QtQuick; Timer { interval: 100; repeat: true; running: true }', root)
          var tries = 0
          wait.triggered.connect(function() {
            if ((newOk === null || store.writing[r] || store.queued[r]) && ++tries < 50) return
            wait.stop()
            store.readFiles([r], function(got) {
              say("kept: a retry while a newer text is written never lands after it", ok1 === false && newOk === true && got[r] === "new" && store.unsavedCount === 0, JSON.stringify(got[r]) + " left " + store.unsavedCount)
              say("kept: saved after all by the next save: said", said === 1, "said " + said)
              root.goneCheck(d)
            })
          })
        })
      })
    })
  }
  // A page you took away whose save had failed: never written again (it
  // would come back).
  function goneCheck(d) {
    var g = d + "/ro/gone/page.json"
    function sh(script, done) { store.exec(["/usr/bin/bash", "-c", script, "x", d], function() { done() }) }
    sh("/usr/bin/mkdir -p \"$1/ro/gone\" && /usr/bin/chmod 500 \"$1/ro/gone\"", function() {
      store.writeKept(g, "text", function(ok1) {
        var kept = store.unsaved[g] !== undefined
        store.trash(d + "/ro/gone", "gone")
        sh("/usr/bin/chmod 700 \"$1/ro/gone\" 2>/dev/null; true", function() {
          store.retryUnsaved(function(left) {
            store.exec(["/usr/bin/test", "-e", g], function(there) {
              say("kept: what's taken away isn't written again", ok1 === false && kept && left === 0 && !there && store.unsaved[g] === undefined, "kept " + kept + " left " + left + " there " + there)
              root.privateChecks(d)
            })
          })
        })
      })
    })
  }
  // Nothing Uber Notebook writes can be read by another account: notes and
  // their folders (by the files helper), whatever a program it runs writes,
  // folders made with mkdir -p, a notes folder from before (755) made 700,
  // and an agent's request in a file of its own, never on a command line.
  function privateChecks(d) {
    var notes = d + "/notes"
    function modes(paths, done) {
      store.exec(["/usr/bin/stat", "-c", "%a"].concat(paths), function(ok, out) { done(String(out).trim().split("\n")) }, { okCodes: [0, 1] })
    }
    store.rootPath = notes
    store.notesRoot = notes
    store.writeFile(notes + "/Pages/private.json", '{"p":1}', function(wrote) {
      store.mkdirs([notes + "/Pages/sub", d + "/out/deep"], function() {
        store.exec(["/usr/bin/bash", "-c", "printf x > \"$1/child.txt\"; /usr/bin/mkdir -p \"$1/open\"; /usr/bin/chmod 755 \"$1/open\"", "x", d], function() {
          store.makePrivate(d + "/open")
          store.agentLauncher = ["/usr/bin/true"]
          store.agentRequests = d + "/agent"
          store.launchAgent("Summarize my secret page", function(launched) {
            store.exec(["/usr/bin/bash", "-c", "/usr/bin/sleep 0.3; for f in \"$1\"/agent/request-*.md; do /usr/bin/stat -c %a \"$f\"; /usr/bin/cat \"$f\"; echo; done", "x", d], function(ok, out) {
              var req = String(out).trim().split("\n")
              modes([notes + "/Pages/private.json", notes + "/Pages/sub", d + "/out", d + "/out/deep", d + "/child.txt", d + "/open", d + "/agent"], function(m) {
                say("private: a note written by the helper is 600, its folder 700", wrote === true && m[0] === "600" && m[1] === "700", m.slice(0, 2).join(" "))
                say("private: folders made with mkdir -p are 700", m[2] === "700" && m[3] === "700", m.slice(2, 4).join(" "))
                say("private: what a program it runs writes is 600", m[4] === "600", m[4])
                say("private: a folder of its own from before (755) is made 700", m[5] === "700", m[5])
                say("private: an agent's request is in a file of its own (600, in a 700 folder), never on a command line", launched === true && m[6] === "700" && req[0] === "600" && req[1] === "Summarize my secret page", req.join(" | ") + " folder " + m[6])
                store.exec(["/usr/bin/rm", "-rf", "--", d], function() { console.log("DONE"); Qt.quit() })
              })
            })
          })
        })
      })
    })
  }
  function helperOff(d, notes) {
    store.writeFile(notes + "/Pages/c.json", '{"c":1}', function(wrote2) {
      store.readFiles([notes + "/Pages/a.json", notes + "/Pages/c.json"], function(got2, read2) {
        say("fallback: the helper off, read and written as before", wrote2 === true && read2 === true && store.notes === null
          && got2[notes + "/Pages/a.json"] === '{"a":1}' && got2[notes + "/Pages/c.json"] === '{"c":1}', JSON.stringify(got2))
        root.keptChecks(d)
      })
    })
  }
  Timer { interval: 30000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
