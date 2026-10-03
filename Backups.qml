import QtQuick
import "Backups.js" as Backups
import "Profiles.js" as Profiles
import "Settings.js" as Settings

// Backups (Backups.js): a profile's notes, or every profile's, kept in one
// .tar.gz in the backup folder; the ones there, listed; one put back, each
// profile in it a new profile in a new folder (nothing that's there is
// written over). Automatic ones, daily or weekly as Settings says, of every
// profile, the oldest past how many are kept going to the trash (only
// automatic ones, never yours).
Item {
  id: bk

  // The service: settings, saveOpen() (what's open in the window written).
  property var service: null
  // Store.qml: home, exec.
  property var files: null
  // Profiles.qml: the profiles, and pathOf(folder).
  property var profiles: null
  property string version: ""

  readonly property var settings: service ? service.settings : ({})
  readonly property string home: files && files.home ? files.home : ""
  // Where they go, as a path.
  readonly property string folder: {
    var f = settings.backupFolder || ""
    if (!f) return home ? home + "/Documents/" + Backups.APP + " Backups" : ""
    return f.indexOf("~/") === 0 ? home + f.slice(1) : f
  }
  readonly property string folderShown: home && folder.indexOf(home + "/") === 0 ? "~" + folder.slice(home.length) : folder

  // The backups there, newest first: [{ name, path, time, size, automatic }].
  property var list: []
  // "" (nothing going on), "backup" or "restore".
  property string working: ""
  // What the last one did, for Settings: "" or a line (`failed` if it didn't go).
  property string note: ""
  property bool failed: false

  // The profiles a backup takes: "" (the open one), "all" (every one but the
  // demo, which starts over as new), or one by its id or name.
  function chosen(which) {
    var shown = profiles ? profiles.shown : []
    var w = String(which || "").trim()
    if (w === "all") return shown.filter(function(p) { return !p.demo })
    if (!w) return profiles && profiles.current ? shown.filter(function(p) { return p.id === profiles.current.id }) : []
    var p = Profiles.find(shown, w)
    return p ? [p] : []
  }

  function refresh(done) {
    if (!files || !folder) { if (done) done(); return }
    files.exec(["/usr/bin/bash", "-c", Backups.LIST_SCRIPT, "omanote-backups", folder], function(ok, out) {
      bk.list = ok ? Backups.listed(out, bk.folder) : []
      if (done) done()
    }, { okCodes: [0], timeoutMs: 8000, maxBytes: 512 * 1024 })
  }

  // A backup: done({ ok, path, size, profiles, error }).
  function backUp(which, automatic, done) {
    function finish(r) {
      bk.working = ""
      bk.failed = !r.ok
      bk.note = r.ok ? (automatic ? "Automatic backup made " : "Backed up ") + Qt.formatDateTime(new Date(), "d MMM, HH:mm") + ": " + r.name : r.error
      if (done) done(r)
    }
    if (working) { if (done) done({ ok: false, error: "A backup is being " + (working === "backup" ? "made" : "put back") + " already." }); return }
    var picked = chosen(which)
    if (!picked.length) {
      var w = String(which || "").trim()
      if (done) done({ ok: false, error: w === "all" ? "There's no profile to back up." : !w ? "No profile is open." : "There's no profile like that." })
      return
    }
    if (!folder) { if (done) done({ ok: false, error: "There's no folder to put it in." }); return }
    working = "backup"
    note = ""
    if (service && typeof service.saveOpen === "function") service.saveOpen()
    var paths = picked.map(function(p) { return bk.profiles.pathOf(p.folder) })
    files.exec(["/usr/bin/bash", "-c", Backups.EXISTS_SCRIPT, "omanote-backup-has"].concat(paths), function(ok, out) {
      var there = String(out || "").split("\n")
      var take = []
      picked.forEach(function(p, i) { if (there[i] === "1") take.push({ profile: p, path: paths[i] }) })
      if (!take.length) { finish({ ok: false, error: "Nothing's been written in " + (picked.length === 1 ? "that profile" : "those profiles") + " yet, so there's nothing to back up." }); return }
      var now = new Date()
      var label = picked.length > 1 || String(which) === "all" ? "All profiles" : picked[0].name
      var name = Backups.fileName(label, now, automatic)
      var m = Backups.manifest(take.map(function(t) { return t.profile }), bk.version, now)
      var args = [bk.folder, name.stem, name.suffix, JSON.stringify(m)]
      take.forEach(function(t, i) { args.push(t.path, "p" + (i + 1), Backups.inside(bk.folder, t.path)) })
      bk.files.exec(["/usr/bin/bash", "-c", Backups.BACKUP_SCRIPT, "omanote-backup"].concat(args), function(made, said) {
        var lines = String(said || "").trim().split("\n")
        var path = made ? lines[lines.length - 1] : ""
        if (!made || !path) { finish({ ok: false, error: "The backup didn't go: " + (String(said || "").trim().split("\n").pop() || "tar stopped") }); return }
        bk.refresh(function() {
          finish({ ok: true, path: path, name: path.split("/").pop(), size: Number(lines[lines.length - 2]) || 0, profiles: take.map(function(t) { return t.profile.name }) })
        })
      }, { timeoutMs: 30 * 60 * 1000, maxBytes: 64 * 1024 })
    }, { timeoutMs: 8000 })
  }

  // What's in a file, before it's put back: done({ ok, problem, manifest }).
  function inspect(path, done) {
    var p = String(path || "").trim()
    if (p.indexOf("~/") === 0) p = home + p.slice(1)
    if (!p || p.charAt(0) !== "/") { done({ ok: false, problem: "Give the backup's full path.", manifest: null }); return }
    files.exec(["/usr/bin/bash", "-c", Backups.CHECK_SCRIPT, "omanote-backup-check", p], function(ok, out) {
      var r = ok ? Backups.checked(out) : { ok: false, problem: "That backup couldn't be read.", manifest: null }
      r.path = p
      done(r)
    }, { timeoutMs: 5 * 60 * 1000, maxBytes: 512 * 1024 })
  }

  // A backup put back: each profile in it a new profile, in a new folder
  // beside the others (~/Documents/Omanote <name> (restored)), opened if
  // `open` (the first). done({ ok, restored: [{ id, name, folder }], error }).
  function restore(path, open, done) {
    if (working) { done({ ok: false, error: "A backup is being " + (working === "backup" ? "made" : "put back") + " already." }); return }
    working = "restore"
    note = ""
    inspect(path, function(c) {
      if (!c.ok) { bk.working = ""; bk.failed = true; bk.note = c.problem; done({ ok: false, error: c.problem }); return }
      var todo = c.manifest.profiles.slice()
      var made = []
      function next() {
        if (!todo.length) { bk.added(made, open, done); return }
        var p = todo.shift()
        var base = Backups.restoreFolder(p.name)
        bk.files.exec(["/usr/bin/bash", "-c", Backups.RESTORE_SCRIPT, "omanote-restore", c.path, p.dir, bk.home + base.slice(1)], function(ok, out) {
          var at = ok ? String(out || "").trim().split("\n").pop() : ""
          if (at) made.push({ name: p.name, folder: bk.home && at.indexOf(bk.home + "/") === 0 ? "~" + at.slice(bk.home.length) : at, saved: p.saved })
          next()
        }, { timeoutMs: 30 * 60 * 1000, maxBytes: 64 * 1024 })
      }
      next()
    })
  }
  function added(made, open, done) {
    working = ""
    if (!made.length) { failed = true; note = "Nothing could be put back from that backup."; done({ ok: false, error: note }); return }
    var r = profiles.addRestored(made, open)
    failed = false
    note = "Put back as " + r.map(function(p) { return "“" + p.name + "”" }).join(", ") + "."
    done({ ok: true, restored: r })
  }

  // ---- automatic ones ----

  readonly property string every: Backups.PERIOD[settings.backupEvery] ? settings.backupEvery : "off"
  function automaticNow() {
    if (every === "off" || working || !profiles || !profiles.settled || profiles.current === null) return
    refresh(function() {
      if (!Backups.due(bk.list, bk.every, Date.now())) return
      bk.backUp("all", true, function(r) {
        if (!r.ok) return
        var old = Backups.toPrune(bk.list, bk.settings.backupKeep)
        if (!old.length) return
        bk.files.exec(["/usr/bin/gio", "trash", "--"].concat(old.map(function(b) { return b.path })), function() { bk.refresh() }, { okCodes: [0, 1, 2] })
      })
    })
  }
  // A few minutes after starting, then every half hour, it looks.
  Timer { interval: 3 * 60 * 1000; running: bk.every !== "off"; onTriggered: bk.automaticNow() }
  Timer { interval: 30 * 60 * 1000; running: bk.every !== "off"; repeat: true; onTriggered: bk.automaticNow() }

  // For agents.
  function listing() {
    return list.map(function(b) {
      return { name: b.name, file: b.path, made: new Date(b.time).toISOString(), size: Backups.sizeLabel(b.size), automatic: b.automatic }
    })
  }
}
