import QtQuick
import "Profiles.js" as Profiles
import "Settings.js" as Settings
import "Backups.js" as Backups

// Profiles (Profiles.js): notes kept apart, each a folder of its own. The
// list, the one open, and what changes them; Service.qml has one (and the
// tests' FakeService), and the window's dropdown, first run and Settings
// use it. Switching writes what's open first, then the settings change and
// the notebooks and Pages read the next folder.
QtObject {
  id: pm

  // The service: settings, setSettings(changes), saveOpen() (what's open in
  // the window written), pickFolder(title, done).
  property var service: null
  // Store.qml: home, and programs to run (exec).
  property var files: null
  // Uber Notebook's own data folder ("~/.local/share/uber-notebook"): the demo's is in it.
  property string dataFolder: "~/.local/share/uber-notebook"

  readonly property var list: service ? service.settings.profiles : []
  readonly property var current: service ? Profiles.find(list, service.settings.profile) : null
  // Looked, once the settings were in, for notes from before profiles.
  property bool settled: false
  // None yet: the window asks for the first (or the demo).
  readonly property bool firstRun: settled && current === null
  // Each with its folder as it is now (the open one's, the settings').
  readonly property var shown: service ? Profiles.withCurrent(list, service.settings) : []

  function apply(changes) { if (changes) service.setSettings(changes) }
  // A profile's folder as a real path ("" is the usual place).
  function pathOf(folder) { return Settings.resolveFolder(folder || "", home(), true) }
  function home() { return files && files.home ? files.home : "" }

  // Once the settings are in: one open (a profile made of the notes from
  // before profiles, the first time), or none, and the first run asks.
  // For each folder: whether it has notes, and the Inbox, the page and the
  // notebook the settings name ("1 0 1"...).
  readonly property string notesScript: "i=$1; p=$2; n=$3; shift 3; for d in \"$@\"; do a=0; b=0; c=0; e=0; { [ -e \"$d/library.json\" ] || [ -e \"$d/Pages/index.json\" ]; } && a=1; [ -n \"$i\" ] && [ -e \"$d/Pages/$i.json\" ] && b=1; [ -n \"$p\" ] && [ -e \"$d/Pages/$p.json\" ] && c=1; [ -n \"$n\" ] && [ -e \"$d/$n/notebook.json\" ] && e=1; echo \"$a $b $c $e\"; done"
  function settle() {
    if (settled || !service || !files) return
    if (list.length) {
      if (!current) apply(Profiles.switchTo(list, service.settings, list[0].id))
      settled = true
      return
    }
    // The folder set in Settings, or the default places.
    var set = service.settings.folder || ""
    var places = set ? [set, "~/Documents/Uber Notebook"] : ["~/Documents/Uber Notebook", "~/Uber Notebook"]
    var paths = places.map(function(p) { return Settings.resolveFolder(p, pm.home(), true) })
    var s = service.settings
    files.exec(["/usr/bin/bash", "-c", notesScript, "uber-notebook-notes", s.inbox || "", s.lastPage || "", s.lastNotebook || ""].concat(paths), function(ok, out) {
      var rows = String(out || "").split("\n").filter(function(l) { return l.trim() }).map(function(l) { return l.trim().split(/\s+/).map(function(x) { return x === "1" }) })
      var had = rows.map(function(r) { return r[0] === true })
      var made = null
      if (set) {
        // The folder Uber Notebook's been using is open; the default place, if it
        // has notes and isn't that one, is a profile too: "Personal", with
        // the Inbox, the page and the notebook the settings name if they're its.
        made = Profiles.fromBefore(set)
        if (paths[1] !== paths[0] && had[1]) {
          made.profiles[0].name = set.replace(/\/+$/, "").split("/").pop() || "Notes"
          var personal = Profiles.make(made.profiles, "Personal", places[1])
          ;[["inbox", 1], ["lastPage", 2], ["lastNotebook", 3]].forEach(function(k) {
            var mine = rows[1] && rows[1][k[1]], theirs = rows[0] && rows[0][k[1]]
            if (mine && !theirs) { personal.saved[k[0]] = s[k[0]]; made[k[0]] = "" }
          })
          made.profiles.push(personal)
        }
      } else if (had[0] || had[1]) made = Profiles.fromBefore(had[0] ? places[0] : places[1])
      if (made) pm.apply(made)
      pm.settled = true
    }, { okCodes: [0, 1] })
  }

  // Another one open ("" if it's open already, else what's wrong).
  function use(id) {
    var next = Profiles.find(list, id)
    if (!next) return "There's no profile like that"
    if (current && current.id === next.id) return ""
    if (typeof service.saveOpen === "function") service.saveOpen()
    apply(Profiles.switchTo(list, service.settings, next.id))
    return ""
  }

  // A new one ("" or what's wrong), opened if `open`.
  function add(name, folder, open) {
    var problem = Profiles.nameProblem(list, name, "") || Profiles.folderProblem(shown, folder, "", home())
    if (problem) return problem
    var p = Profiles.make(list, name, folder)
    var next = shown.concat([p])
    if (!open) { apply({ profiles: next }); return "" }
    if (typeof service.saveOpen === "function") service.saveOpen()
    apply(Profiles.switchTo(next, service.settings, p.id))
    return ""
  }

  function rename(id, name) {
    var problem = Profiles.nameProblem(list, name, id)
    if (problem) return problem
    apply({ profiles: shown.map(function(p) { if (p.id === id) p.name = Profiles.line(name, 60); return p }) })
    return ""
  }

  // Its notes looked for in another folder (nothing is moved).
  function setFolder(id, folder) {
    var problem = Profiles.folderProblem(shown, folder, id, home())
    if (problem) return problem
    var f = Settings.cleanFolder(String(folder))
    var changes = { profiles: shown.map(function(p) { if (p.id === id) p.folder = f; return p }) }
    if (current && current.id === id) {
      if (typeof service.saveOpen === "function") service.saveOpen()
      changes.folder = f
    }
    apply(changes)
    return ""
  }

  // Profiles put back from a backup ([{ name, folder, saved }]): each a new
  // one, its name or "Name (restored)" if that's taken, with the page, the
  // notebook and the Inbox it had; the first opened if `open`. The ones
  // made: [{ id, name, folder }].
  function addRestored(items, open) {
    var next = shown.slice()
    var made = []
    ;(items || []).forEach(function(it) {
      if (next.length >= Profiles.MAX) return
      var p = Profiles.make(next, Backups.restoredName(next.map(function(x) { return x.name }), it.name), it.folder)
      p.saved = Backups.savedOf(it.saved)
      next.push(p)
      made.push({ id: p.id, name: p.name, folder: p.folder })
    })
    if (!made.length) return made
    if (!open) { apply({ profiles: next }); return made }
    if (typeof service.saveOpen === "function") service.saveOpen()
    apply(Profiles.switchTo(next, service.settings, made[0].id))
    return made
  }

  // Off the list; its notes stay where they are.
  function remove(id) {
    if (current && current.id === id) return "Open another profile first"
    apply({ profiles: shown.filter(function(p) { return p.id !== id }) })
    return ""
  }

  // The demo: its profile open (made the first time, in Uber Notebook's data folder).
  readonly property var demo: list.filter(function(p) { return p.demo })[0] || null
  function openDemo() {
    if (demo) return use(demo.id)
    var p = Profiles.demo(list, dataFolder + "/demo")
    var next = shown.concat([p])
    if (typeof service.saveOpen === "function") service.saveOpen()
    apply(Profiles.switchTo(next, service.settings, p.id))
    return ""
  }
  // The demo as new: a new folder for it, open; the one it had goes to the trash.
  function restartDemo() {
    if (!demo) return openDemo()
    var old = Settings.resolveFolder(current && current.id === demo.id ? service.settings.folder : demo.folder, home(), true)
    var base = Settings.resolveFolder(dataFolder, home(), true)
    var fresh = dataFolder + "/demo-" + Date.now().toString(36)
    if (typeof service.saveOpen === "function") service.saveOpen()
    var list2 = shown.map(function(p) { if (p.id === pm.demo.id) { p.folder = fresh; p.saved = {} } return p })
    // (Open, its own settings start again; else the open one keeps its.)
    var demoOpen = current !== null && current.id === demo.id
    var changes = Profiles.switchTo(list2, demoOpen ? { profile: "" } : service.settings, demo.id)
    apply(changes)
    // (Only ever a demo folder of Uber Notebook's own: "demo", or "demo-" and
    // the time it was made, in its own data folder.)
    if (old.indexOf(base + "/") === 0 && /^demo(-[0-9a-z]{1,13})?$/.test(old.slice(base.length + 1))) files.exec(["/usr/bin/gio", "trash", "--", old], function() {})
    return ""
  }
}
