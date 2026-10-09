import QtQuick
import "Backups.js" as Backups
import "Profiles.js" as Profiles
import "Settings.js" as Settings
import "Dates.js" as Dates

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

  // Whether their folder couldn't be made yours alone (Settings says so).
  property bool notPrivate: false
  // The backups there, newest first: [{ name, path, time, size, automatic }].
  property var list: []
  // "" (nothing going on), "backup" or "restore".
  property string working: ""
  // What the last one did, for Settings: "" or a line (`failed` if it didn't go).
  property string note: ""
  property bool failed: false
  // The most a profile put back may take: bytes, files (an archive that says
  // more is stopped, and what it made taken away).
  readonly property real restoreMaxBytes: 64 * 1024 * 1024 * 1024
  readonly property int restoreMaxFiles: 2000000

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
    files.exec(["/usr/bin/bash", "-c", Backups.LIST_SCRIPT, "uber-notebook-backups", folder], function(ok, out) {
      bk.list = ok ? Backups.listed(out, bk.folder) : []
      bk.notPrivate = ok && /^open$/m.test(String(out || ""))
      if (bk.notPrivate && bk.every !== "off") bk.sayStopped()
      if (done) done()
    }, { okCodes: [0], timeoutMs: 8000, maxBytes: 512 * 1024 })
  }
  // (Once the profiles are in, the settings with them: their folder looked
  // in, so made yours alone, as each profile's is.)
  Connections {
    target: bk.profiles
    ignoreUnknownSignals: true
    function onSettledChanged() { if (bk.profiles.settled) bk.refresh() }
  }

  // Automatic backups refused by their folder (it can't keep them private):
  // said outside Settings too, in the window and as a notification, once a
  // session for each folder, or they'd stop without a word.
  property var warned: ({})
  function sayStopped() {
    if (!folder || warned[folder] || !profiles || !profiles.settled) return
    var w = {}
    for (var k in warned) w[k] = warned[k]
    w[folder] = true
    warned = w
    var text = "Automatic backups stopped: " + folderShown + " can't keep them private (another account on this computer could read them there). Pick another folder (Settings, Backups)"
    if (typeof files.failed === "function") files.failed(text)
    if (typeof files.notify === "function") files.notify("Backups stopped", text, "", "")
  }

  // A backup: done({ ok, path, size, profiles, error }).
  function backUp(which, automatic, done) {
    function finish(r) {
      bk.working = ""
      bk.failed = !r.ok
      bk.note = r.ok ? (automatic ? "Automatic backup made " : "Backed up ") + Qt.formatDate(new Date(), "d MMM") + ", " + Dates.clockOf(new Date()) + ": " + r.name : r.error
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
    files.exec(["/usr/bin/bash", "-c", Backups.EXISTS_SCRIPT, "uber-notebook-backup-has"].concat(paths), function(ok, out) {
      var there = String(out || "").split("\n")
      var take = []
      picked.forEach(function(p, i) { if (there[i] === "1") take.push({ profile: p, path: paths[i] }) })
      if (!take.length) { finish({ ok: false, error: "Nothing's been written in " + (picked.length === 1 ? "that profile" : "those profiles") + " yet, so there's nothing to back up." }); return }
      var now = new Date()
      var label = picked.length > 1 || String(which) === "all" ? "All profiles" : picked[0].name
      var name = Backups.fileName(label, now, automatic)
      var m = Backups.manifest(take.map(function(t) { return t.profile }), bk.version, now)
      var args = [bk.folder, name.stem, name.suffix]
      take.forEach(function(t, i) { args.push(t.path, "p" + (i + 1), Backups.inside(bk.folder, t.path)) })
      bk.files.exec(["/usr/bin/bash", "-c", Backups.BACKUP_SCRIPT, "uber-notebook-backup"].concat(args), function(made, said) {
        var lines = String(said || "").trim().split("\n")
        var path = made ? lines[lines.length - 1] : ""
        // (Its folder can't keep it private: said in Settings, and, for an
        // automatic one, outside it too.)
        if (!made && /^open$/m.test(String(said || ""))) {
          bk.notPrivate = true
          if (automatic) bk.sayStopped()
        }
        if (!made || !path) { finish({ ok: false, error: "The backup didn't go: " + (String(said || "").trim().split("\n").pop() || "tar stopped") }); return }
        bk.refresh(function() {
          finish({ ok: true, path: path, name: path.split("/").pop(), size: Number(lines[lines.length - 2]) || 0, profiles: take.map(function(t) { return t.profile.name }) })
        })
      }, { input: JSON.stringify(m), timeoutMs: 30 * 60 * 1000, maxBytes: 64 * 1024 })
    }, { timeoutMs: 8000 })
  }

  // What's in a file, before it's put back: done({ ok, problem, manifest }).
  function inspect(path, done) {
    var p = String(path || "").trim()
    if (p.indexOf("~/") === 0) p = home + p.slice(1)
    if (!p || p.charAt(0) !== "/") { done({ ok: false, problem: "Give the backup's full path.", manifest: null }); return }
    files.helper(["inspect-backup", p], function(ok, out) {
      var r = ok ? Backups.checked(out) : { ok: false, problem: "That backup couldn't be read.", manifest: null }
      if (r.ok && !r.hash) r = { ok: false, problem: "That backup couldn't be read.", manifest: null }
      r.path = p
      done(r)
    }, { timeoutMs: 5 * 60 * 1000, maxBytes: 512 * 1024 })
  }

  // A backup put back: each profile in it a new profile, in a new folder
  // beside the others (~/Documents/Uber Notebook <name> (restored)), opened if
  // `open` (the first). done({ ok, restored: [{ id, name, folder }], error }).
  function restore(path, open, done) {
    if (working) { done({ ok: false, error: "A backup is being " + (working === "backup" ? "made" : "put back") + " already." }); return }
    working = "restore"
    note = ""
    inspect(path, function(c) {
      if (!c.ok) { bk.working = ""; bk.failed = true; bk.note = c.problem; done({ ok: false, error: c.problem }); return }
      var todo = c.manifest.profiles.slice()
      var made = []
      var leftOut = 0
      // (Not put back because where it goes can't keep your notes private:
      // their names, and that folder.)
      var refused = { names: [], folder: "" }
      function next() {
        if (!todo.length) { bk.added(made, open, done, leftOut, refused); return }
        var p = todo.shift()
        var base = Backups.restoreFolder(p.name)
        // (From the file looked into: if it isn't that any more, nothing.)
        bk.files.helper(["restore-backup", c.path, p.dir, bk.home + base.slice(1), c.hash, String(bk.restoreMaxBytes), String(bk.restoreMaxFiles)], function(ok, out) {
          if (!ok && Backups.notPrivate(out)) { refused.names.push(p.name); refused.folder = base.replace(/\/[^\/]*$/, "") }
          var lines = ok ? String(out || "").trim().split("\n") : []
          var at = lines.length ? lines[lines.length - 1] : ""
          // (Links and special files in it, left out: counted.)
          lines.forEach(function(l) { var m = /^left-out:(\d{1,9})$/.exec(l); if (m && at) leftOut += Number(m[1]) })
          if (at && at.charAt(0) !== "/") at = ""
          if (at) made.push({ name: p.name, folder: bk.home && at.indexOf(bk.home + "/") === 0 ? "~" + at.slice(bk.home.length) : at, saved: p.saved })
          next()
        }, { timeoutMs: 30 * 60 * 1000, maxBytes: 64 * 1024 })
      }
      next()
    })
  }
  function added(made, open, done, leftOut, refused) {
    working = ""
    var notPrivate = refused && refused.names.length ? Backups.notPrivateNote(refused.folder) + "." : ""
    if (!made.length) { failed = true; note = notPrivate ? "Nothing was put back: " + notPrivate : "Nothing could be put back from that backup."; done({ ok: false, error: note }); return }
    var r = profiles.addRestored(made, open)
    failed = false
    note = "Put back as " + r.map(function(p) { return "“" + p.name + "”" }).join(", ") + "."
      + (notPrivate ? " " + refused.names.map(function(n) { return "“" + n + "”" }).join(", ") + (refused.names.length === 1 ? " wasn't: " : " weren't: ") + notPrivate : "")
      + (leftOut ? " " + leftOut + (leftOut === 1 ? " link (or special file) in it was" : " links (or special files) in it were") + " left out." : "")
    done({ ok: true, restored: r, leftOut: leftOut || 0 })
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
