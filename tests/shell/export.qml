import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL: Quickshell only
// imports folders outside the test's own that way.)
import "@PLUGIN@" as UN
import "@PLUGIN@/app" as UNA

// app/Exporter.qml with the real programs, in a real Quickshell (tests/run
// starts it offscreen): a page in a folder of its own made a PDF (Chromium)
// and a Word file (LibreOffice), with its picture; into the Exports folder
// (Settings), and its working folder taken away after. Skipped (said) where
// Chromium or LibreOffice isn't installed. Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  UN.Store { id: store; active: false }

  // What the exporter needs of the workspace.
  QtObject {
    id: ws
    property var files: store
    property var index: ({ pages: {} })
    property var calendar: null
    function readPages(ids, done) { done([]) }
    function contactById(id) { return null }
    function readPageNow(id) { return null }
  }

  UNA.Exporter {
    id: exporter
    workspace: ws
    settings: ({ exportTo: "folder" })
    onToast: function(text) { root.said.push(text) }
  }
  property var said: []

  readonly property string pngB64: "iVBORw0KGgoAAAANSUhEUgAAACgAAAAUCAIAAABwJOjsAAAAGUlEQVR4nO3BMQEAAADCoPVPbQo/oAAAeBsJdAABQs/f3QAAAABJRU5ErkJggg=="
  property var page: ({ id: "11111111-1111-4111-8111-111111111111", title: "Export test", icon: "", content: ["a", "b", "c"], blocks: {
    a: { id: "a", type: "h2", html: "A heading" },
    b: { id: "b", type: "p", html: "Some <span style=\"font-weight:700;\">bold</span> words and <a href=\"https://example.org\">a link</a>." },
    c: { id: "c", type: "image", src: "assets/pic.png", width: 0.5 } } })

  Component.onCompleted: {
    store.exec(["/usr/bin/bash", "-c", "d=$(/usr/bin/mktemp -d) || exit 1; /usr/bin/mkdir -p \"$d/Pages/assets\"; printf '%s' \"$1\" | /usr/bin/base64 -d > \"$d/Pages/assets/pic.png\"; printf '%s' \"$d\"", "x", pngB64], function(ok, out) {
      var d = String(out).trim()
      if (!ok || !d) { console.log("FAIL setup"); Qt.quit(); return }
      store.rootPath = d
      // (A picture copied in for real, by the files helper: a picture, and
      // never a pipe.)
      store.exec(["/usr/bin/mkfifo", d + "/pipe.png"], function() {
        store.copyPictureIn(d + "/Pages/assets/pic.png", d, "copy.png", function(ok) {
          store.copyPictureIn(d + "/pipe.png", d, "pipe-copy.png", function(ok2, why) {
            store.exec(["/usr/bin/test", "-s", d + "/copy.png"], function(there) {
              say("a picture copied in, by the files helper", ok === true && there, "")
              say("never a pipe: said, not waited on", ok2 === false && /not a plain file/.test(why), why)
              root.exports(d)
            })
          })
        })
      })
    })
  }
  function exports(d) {
      exporter.probe(function(t) {
        if (!t.browser || !t.office) { console.log("PASS skipped: no " + (!t.browser ? "Chromium" : "LibreOffice")); root.finish(d); return }
        root.make("pdf", d, function() { root.make("docx", d, function() { root.finish(d) }) })
      })
  }

  function make(kind, d, next) {
    exporter.run(kind, JSON.parse(JSON.stringify(page)), false)
    var check = Qt.createQmlObject('import QtQuick; Timer { interval: 250; repeat: true; running: true }', root)
    var tries = 0
    check.triggered.connect(function() {
      if (exporter.busy && ++tries < 160) return
      check.stop()
      // What's in the Exports folder: the file, what it starts with, and
      // whether its picture's in it.
      store.exec(["/usr/bin/bash", "-c", "for f in \"$1\"/Exports/*.\"$2\"; do [ -f \"$f\" ] || continue; printf '%s\\t' \"${f##*/}\"; /usr/bin/head -c 4 \"$f\" | /usr/bin/od -An -c | /usr/bin/tr -d ' \\n'; "
        + "if [ \"$2\" = docx ]; then printf '\\t'; /usr/bin/python3 -I -S -c 'import sys,zipfile; z=zipfile.ZipFile(sys.argv[1]); import re; rels=\"\".join(z.read(n).decode(\"utf-8\",\"replace\") for n in z.namelist() if n.endswith(\".rels\")); print(sum(1 for n in z.namelist() if n.startswith(\"word/media/\")), any(\"/image\\\"\" in r and \"External\" in r for r in re.findall(\"<Relationship [^>]*>\", rels)))' \"$f\"; else echo; fi; done; "
        + "ls -d \"$XDG_RUNTIME_DIR\"/uber-notebook-export-* 2>/dev/null | /usr/bin/wc -l", "x", d, kind], function(ok, out) {
        var lines = String(out).trim().split("\n")
        var row = lines[0] ? lines[0].split("\t") : []
        if (kind === "pdf") say("a PDF, by Chromium, in the Exports folder", /^Export test \d{4}-\d\d-\d\d \d{4}\.pdf$/.test(row[0] || "") && row[1] === "%PDF", lines.join(" | ") + " :: " + root.said.join(" / "))
        else {
          say("a Word file, by LibreOffice, in the Exports folder", /^Export test \d{4}-\d\d-\d\d \d{4}\.docx$/.test(row[0] || "") && row[1] === "PK003004", lines.join(" | ") + " :: " + root.said.join(" / "))
          say("its picture in it, not a link to a file", row[2] === "1 False", row[2])
        }
        say(kind + ": its working folder taken away", lines[lines.length - 1] === "0", lines[lines.length - 1])
        next()
      }, { timeoutMs: 20000 })
    })
  }

  function finish(d) {
    store.exec(["/usr/bin/rm", "-rf", "--", d], function() { console.log("DONE"); Qt.quit() })
  }
  Timer { interval: 110000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
