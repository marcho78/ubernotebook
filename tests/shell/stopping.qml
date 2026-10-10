import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL.)
import "@PLUGIN@" as UN

// Uber Notebook's skill links: made when it's turned on (one from an install
// before, gone, pointed here; anyone else's left); its own taken out when
// it's turned off; turned on, off and on quickly, linked. Then Uber Notebook
// taking itself out as it stops, when its folder may be gone already
// (`omarchy plugin remove` moves it away as soon as it's unloaded): by the
// files helper run from its text, kept as it started, not from its file. In
// a home of its own (never yours). Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  UN.Store { id: store; active: false }

  Component.onCompleted: {
    store.exec(["/usr/bin/bash", "-c", "h=$(/usr/bin/mktemp -d) || exit 1; "
      + "/usr/bin/mkdir -p \"$h/.claude/skills\" \"$h/.agents/skills\" \"$h/.codex/skills\" \"$h/plugins/marcho78.uber-notebook/skills/uber-notebook\"; "
      + "/usr/bin/ln -s \"$h/old/marcho78.uber-notebook/skills/uber-notebook\" \"$h/.agents/skills/uber-notebook\"; "
      + "/usr/bin/ln -s \"$h/someone-else\" \"$h/.codex/skills/uber-notebook\"; printf '%s' \"$h\""], function(ok, out) {
      var h = String(out).trim()
      if (!ok || !h) { console.log("FAIL setup"); Qt.quit(); return }
      store.home = h
      var target = h + "/plugins/marcho78.uber-notebook/skills/uber-notebook"
      var links = "for d in claude agents codex; do /usr/bin/readlink -- \"$1/.$d/skills/uber-notebook\" || echo none; done"
      store.setSkillLinks(true, target)
      root.after(800, function() {
        store.exec(["/usr/bin/bash", "-c", links, "x", h], function(ok2, out2) {
          var l = String(out2).trim().split("\n")
          say("its skill linked when turned on; one from an install before, gone, pointed here; anyone else's left",
            l[0] === target && l[1] === target && l[2] === h + "/someone-else", l.join(" | "))
          store.setSkillLinks(false, target)
          root.after(800, function() {
          store.exec(["/usr/bin/bash", "-c", links, "x", h], function(ok4, out4) {
          var o = String(out4).trim().split("\n")
          say("turned off, its own links taken out; anyone else's left", o[0] === "none" && o[1] === "none" && o[2] === h + "/someone-else", o.join(" | "))
          // On, off and on again at once: linked, as it was left.
          store.setSkillLinks(true, target)
          store.setSkillLinks(false, target)
          store.setSkillLinks(true, target)
          root.after(1200, function() {
          store.exec(["/usr/bin/bash", "-c", links, "x", h], function(ok5, out5) {
          var q = String(out5).trim().split("\n")
          say("on, off and on quickly: linked", q[0] === target && q[1] === target && q[2] === h + "/someone-else", q.join(" | "))
          // As it stops, the helper run from its text, its file not read.
          var text = store.readNow(store.filesHelper, 512 * 1024) || ""
          store.unlinkSkill(target, ["/usr/bin/python3", "-I", "-S", "-c", text])
          root.after(1500, function() {
            store.exec(["/usr/bin/bash", "-c", "for d in claude agents codex; do [ -L \"$1/.$d/skills/uber-notebook\" ] && echo there || echo gone; done", "x", h], function(ok3, out3) {
              var g = String(out3).trim().split("\n")
              say("as it stops, its links taken out by the helper's text; anyone else's left", text.length > 1000 && g[0] === "gone" && g[1] === "gone" && g[2] === "there", g.join(" | "))
              store.exec(["/usr/bin/rm", "-rf", "--", h], function() { console.log("DONE"); Qt.quit() })
            })
          })
          })
          })
          })
          })
        })
      })
    })
  }
  function after(ms, fn) {
    var t = Qt.createQmlObject('import QtQuick; Timer { running: true }', root)
    t.interval = ms
    t.triggered.connect(function() { t.destroy(); fn() })
  }
  Timer { interval: 30000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
