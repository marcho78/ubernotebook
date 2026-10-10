import QtQuick
import Quickshell
import Quickshell.Io
// (tests/run writes the plugin folder here, as a file: URL.)
import "@PLUGIN@" as UN

// Uber Notebook's skill links: made when it's turned on (one from an install
// before, gone, pointed here; anyone else's left); its own taken out when
// it's turned off (an install before's too); made only once the lock is
// free; turned on and off, or on, off and on, quickly: as it was left. Then
// Uber Notebook taking itself out as it stops, when its folder may be gone
// already (`omarchy plugin remove` moves it away as soon as it's unloaded):
// by the files helper run from its text, kept as it started, not from its
// file; a link being made then taken out after it's made; one asked for
// before then and made after, never made; none made once it's stopping. In
// a home of its own (never yours). Prints PASS/FAIL lines, then DONE.
ShellRoot {
  id: root
  function say(name, ok, extra) { console.log((ok ? "PASS " : "FAIL ") + name + (extra ? " :: " + extra : "")) }

  UN.Store { id: store; active: false }

  property string h: ""
  property string target: ""
  property string older: ""
  property string text: ""
  // Where each of claude, agents, codex, hermes links ("none" for no link).
  readonly property string links: "for d in claude agents codex hermes; do /usr/bin/readlink -- \"$1/.$d/skills/uber-notebook\" || echo none; done"
  function read(done) { store.exec(["/usr/bin/bash", "-c", links, "x", h], function(ok, out) { done(String(out).trim().split("\n")) }) }

  // One step after another, each handed the next.
  function run(steps) {
    if (!steps.length) { store.exec(["/usr/bin/rm", "-rf", "--", h], function() { console.log("DONE"); Qt.quit() }); return }
    steps[0](function() { root.run(steps.slice(1)) })
  }

  Component.onCompleted: {
    store.exec(["/usr/bin/bash", "-c", "h=$(/usr/bin/mktemp -d) || exit 1; "
      + "/usr/bin/mkdir -p \"$h/.claude/skills\" \"$h/.agents/skills\" \"$h/.codex/skills\" \"$h/.hermes/skills\" \"$h/plugins/marcho78.uber-notebook/skills/uber-notebook\" \"$h/older/marcho78.uber-notebook/skills/uber-notebook\"; "
      + "/usr/bin/ln -s \"$h/older/marcho78.uber-notebook/skills/uber-notebook\" \"$h/.hermes/skills/uber-notebook\"; "
      + "/usr/bin/ln -s \"$h/old/marcho78.uber-notebook/skills/uber-notebook\" \"$h/.agents/skills/uber-notebook\"; "
      + "/usr/bin/ln -s \"$h/someone-else\" \"$h/.codex/skills/uber-notebook\"; printf '%s' \"$h\""], function(ok, out) {
      root.h = String(out).trim()
      if (!ok || !root.h) { console.log("FAIL setup"); Qt.quit(); return }
      store.home = root.h
      store.skillLock = root.h + "/skills.lock"
      root.target = root.h + "/plugins/marcho78.uber-notebook/skills/uber-notebook"
      root.older = root.h + "/older/marcho78.uber-notebook/skills/uber-notebook"
      root.text = store.readNow(store.filesHelper, 512 * 1024) || ""
      root.run(root.steps())
    })
  }

  function steps() {
    var h = root.h, target = root.target, older = root.older
    var else_ = h + "/someone-else"
    return [
      function(next) {
        store.setSkillLinks(true, target)
        after(800, function() { read(function(l) {
          say("its skill linked when turned on; one from an install before, gone, pointed here; anyone else's left",
            l[0] === target && l[1] === target && l[2] === else_ && l[3] === older, l.join(" | "))
          next()
        }) })
      },
      function(next) {
        store.setSkillLinks(false, target)
        after(800, function() { read(function(o) {
          say("turned off, its own links taken out (an install before's too); anyone else's left",
            o[0] === "none" && o[1] === "none" && o[2] === else_ && o[3] === "none", o.join(" | "))
          next()
        }) })
      },
      // Linking waits for the lock: held elsewhere, nothing yet; let go, linked.
      function(next) {
        store.exec(["/usr/bin/bash", "-c", "(/usr/bin/flock \"$1\" /usr/bin/sleep 1.2) >/dev/null 2>&1 & /usr/bin/sleep 0.2", "x", store.skillLock], function() {
          store.setSkillLinks(true, target)
          after(500, function() { read(function(a) {
            after(1500, function() { read(function(b) {
              say("linking waits for the lock", a[0] === "none" && a[1] === "none" && b[0] === target && b[1] === target, a.join(" | ") + " -> " + b.join(" | "))
              store.setSkillLinks(false, target)
              after(800, next)
            }) })
          }) })
        }, { keepChildren: true })
      },
      // On and off at once: not linked, as it was left.
      function(next) {
        store.setSkillLinks(true, target)
        store.setSkillLinks(false, target)
        after(1200, function() { read(function(n) {
          say("on and off quickly: not linked", n[0] === "none" && n[1] === "none" && n[3] === "none", n.join(" | "))
          next()
        }) })
      },
      // On, off and on again at once: linked, as it was left.
      function(next) {
        store.setSkillLinks(true, target)
        store.setSkillLinks(false, target)
        store.setSkillLinks(true, target)
        after(1200, function() { read(function(q) {
          say("on, off and on quickly: linked", q[0] === target && q[1] === target && q[2] === else_ && q[3] === target, q.join(" | "))
          next()
        }) })
      },
      // As it stops, the helper run from its text, its file not read.
      function(next) {
        store.unlinkSkill(target, ["/usr/bin/python3", "-I", "-S", "-c", root.text])
        after(1500, function() { read(function(g) {
          say("as it stops, its links taken out by the helper's text; anyone else's left",
            root.text.length > 1000 && g[0] === "none" && g[1] === "none" && g[2] === else_ && g[3] === "none", g.join(" | "))
          next()
        }) })
      },
      // A link still being made as it stops (the lock held, the link made
      // at the end): taken out after it's made, not before.
      function(next) {
        store.exec(["/usr/bin/bash", "-c", "(/usr/bin/flock \"$1\" /usr/bin/bash -c '/usr/bin/sleep 1; /usr/bin/ln -sT -- \"$1\" \"$2\"' x \"$2\" \"$3\") >/dev/null 2>&1 & /usr/bin/sleep 0.2",
          "x", store.skillLock, target, h + "/.claude/skills/uber-notebook"], function() {
          store.unlinkSkill(target, ["/usr/bin/python3", "-I", "-S", "-c", root.text])
          after(2500, function() { read(function(m) {
            say("a link made as it stops: taken out after", m[0] === "none", m.join(" | "))
            next()
          }) })
        }, { keepChildren: true })
      },
      // A link asked for before it stopped, under way only after its links
      // were taken out: nothing linked. Another run's: linked.
      function(next) {
        var late = ["/usr/bin/bash", "-c", store.skillScript, "x", "link", target, store.skillLock]
        store.exec(late.concat([store.skillToken], store.skillDirs()), function() { read(function(w) {
          say("asked for before it stopped, made after: nothing linked", w[0] === "none" && w[1] === "none" && w[3] === "none", w.join(" | "))
          store.exec(late.concat(["another1run"], store.skillDirs()), function() { read(function(y) {
            store.exec(["/usr/bin/bash", "-c", "read -r s < \"$1\"; echo \"$s\"", "x", store.skillLock + ".stopped"], function(okm, mark) {
              say("another run's: linked; the mark is this run's", y[0] === target && y[1] === target && String(mark).trim() === store.skillToken, y.join(" | "))
              store.exec(["/usr/bin/bash", "-c", "for d in claude agents hermes; do /usr/bin/rm -f -- \"$1/.$d/skills/uber-notebook\"; done", "x", h], function() { next() })
            })
          }) })
        }) })
      },
      // Stopping: never linked again.
      function(next) {
        store.skillsStopped = true
        store.setSkillLinks(true, target)
        after(800, function() { read(function(z) {
          say("stopping: not linked", z[0] === "none" && z[1] === "none" && z[2] === else_ && z[3] === "none", z.join(" | "))
          next()
        }) })
      }
    ]
  }

  function after(ms, fn) {
    var t = Qt.createQmlObject('import QtQuick; Timer { running: true }', root)
    t.interval = ms
    t.triggered.connect(function() { t.destroy(); fn() })
  }
  Timer { interval: 45000; running: true; onTriggered: { console.log("FAIL timeout"); Qt.quit() } }
}
