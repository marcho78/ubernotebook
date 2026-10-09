// Backups.js - a profile's notes (or every profile's) kept in one file, and
// put back as profiles of their own.
//
// A backup is a .tar.gz any archive tool opens: `uber-notebook-backup.json` (what's
// in it: which profiles, when, which Uber Notebook made it), and each profile's
// folder as it was, under p1/, p2/... Putting one back never writes over
// anything: each profile in it comes back as a new profile, in a new folder.
// Automatic ones (daily or weekly, in Settings) are named so they're told
// apart from the ones you make, and only they are ever cleared out (to the
// trash), the oldest first, past how many Settings keeps.
//
// Shared by Backups.qml and tests/backups.test.cjs (which runs the scripts
// with the real tar), so keep it plain JavaScript with no QML or Node APIs.
.pragma library

var APP = "Uber Notebook"
var APP_ID = "uber-notebook"
var FORMAT = 1
var MANIFEST = "uber-notebook-backup.json"
var EVERY = ["off", "daily", "weekly"]
var KEEP = [3, 5, 10, 20, 50]
var DAY = 24 * 3600 * 1000
var PERIOD = { daily: DAY, weekly: 7 * DAY }
// At most this many profiles in one backup (as many as there can be).
var MAX_PROFILES = 30
var SAVED_KEYS = ["inbox", "lastPage", "lastNotebook"]

function pad(n) { return (n < 10 ? "0" : "") + n }
// "2026-10-03 0130", in local time.
function stamp(d) {
  return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) + " " + pad(d.getHours()) + pad(d.getMinutes())
}

// A name as part of a file name: no slashes, no control characters.
function safeLabel(text) {
  return String(text || "").replace(/[\/\\:*?"<>|\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, 40)
}

// A backup's file name, before ".tar.gz" (and the " 2" that tells two
// made in the same minute apart): { stem, suffix }.
//   "Uber Notebook Personal 2026-10-03 0130" + ".tar.gz"
//   "Uber Notebook 2026-10-03 0130" + " (automatic).tar.gz"
function fileName(label, date, automatic) {
  if (automatic) return { stem: APP + " " + stamp(date), suffix: " (automatic).tar.gz" }
  return { stem: APP + " " + (safeLabel(label) || "backup") + " " + stamp(date), suffix: ".tar.gz" }
}
function isAutomatic(name) {
  var n = String(name || "")
  var pre = APP + " "
  return n.indexOf(pre) === 0 && /^\d{4}-\d{2}-\d{2} \d{4}( \d+)? \(automatic\)\.tar\.gz$/.test(n.slice(pre.length))
}

// What a backup holds, as its uber-notebook-backup.json says: the profiles, each
// under its own folder in it (p1, p2...), with the page and notebook it was
// on and its Inbox.
function savedOf(saved) {
  var s = saved && typeof saved === "object" ? saved : {}
  var out = {}
  SAVED_KEYS.forEach(function(k) { if (typeof s[k] === "string" && /^[a-z0-9-]{1,80}$/.test(s[k])) out[k] = s[k] })
  return out
}
function manifest(entries, version, date) {
  return {
    app: APP_ID,
    format: FORMAT,
    version: String(version || ""),
    created: date.toISOString(),
    profiles: entries.slice(0, MAX_PROFILES).map(function(e, i) {
      return { dir: "p" + (i + 1), name: String(e.name || "").slice(0, 60), demo: e.demo === true, saved: savedOf(e.saved) }
    })
  }
}

function line(value, max) {
  return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : ""
}

// A backup's uber-notebook-backup.json, checked: { version, created, profiles:
// [{ dir, name, demo, saved }] }, or null if it isn't one.
function readManifest(text) {
  var m = null
  try { m = JSON.parse(String(text || "")) } catch (e) { return null }
  if (!m || typeof m !== "object" || m.app !== APP_ID || typeof m.format !== "number" || m.format < 1 || m.format > FORMAT) return null
  if (!Array.isArray(m.profiles) || m.profiles.length === 0) return null
  var seen = {}
  var list = []
  for (var i = 0; i < m.profiles.length && list.length < MAX_PROFILES; i++) {
    var p = m.profiles[i]
    if (!p || typeof p !== "object" || typeof p.dir !== "string" || !/^p\d{1,2}$/.test(p.dir) || seen[p.dir]) return null
    seen[p.dir] = true
    list.push({ dir: p.dir, name: line(p.name, 60) || "Restored", demo: p.demo === true, saved: savedOf(p.saved) })
  }
  var created = typeof m.created === "string" && !isNaN(Date.parse(m.created)) ? m.created : ""
  return { version: line(m.version, 20), created: created, profiles: list }
}

// What the check script says about a file: { ok, problem, manifest, leftOut }.
// A backup holds only uber-notebook-backup.json and its profiles' folders
// (p1/...), nothing reaching outside them. Links and special files in it (one
// synced into a profile, say) are left out when it's put back (`leftOut`);
// a sparse file, or one of a kind it doesn't know, refuses it.
function checked(output) {
  var text = String(output || "")
  var cut = text.indexOf("\n---\n")
  var head = cut >= 0 ? text.slice(0, cut) : text
  var fields = {}
  head.split("\n").forEach(function(l) { var i = l.indexOf(":"); if (i > 0) fields[l.slice(0, i)] = l.slice(i + 1) })
  var notOurs = "That isn't a backup " + APP + " can read (a .tar.gz it made)."
  if (cut < 0 || fields.readable !== "1") return { ok: false, problem: notOurs, manifest: null }
  if (Number(fields.outside) > 0 || Number(fields.dots) > 0) return { ok: false, problem: "That file holds more than " + APP + "'s notes, so it isn't put back.", manifest: null }
  if (/[^-dlhcbp]/.test(fields.types || "")) return { ok: false, problem: "That backup has sparse or unknown kinds of files in it, so it isn't put back.", manifest: null }
  var m = readManifest(text.slice(cut + 5))
  if (!m) return { ok: false, problem: notOurs, manifest: null }
  // (What restoring it checks it still is.)
  var hash = /^[0-9a-f]{64}$/.test(fields.hash || "") ? fields.hash : ""
  return { ok: true, problem: "", manifest: m, hash: hash, leftOut: /[lhcbp]/.test(fields.types || "") }
}

// The backups in a folder (the list script's lines: "<modified>\t<size>\t<name>"),
// newest first: [{ name, path, time, size, automatic }].
function listed(output, folder) {
  var dir = String(folder || "").replace(/\/+$/, "")
  return String(output || "").split("\n").map(function(l) {
    var m = /^([0-9.]+)\t(\d+)\t(.+\.tar\.gz)$/.exec(l)
    if (!m) return null
    return { name: m[3], path: dir + "/" + m[3], time: Math.round(Number(m[1]) * 1000), size: Number(m[2]), automatic: isAutomatic(m[3]) }
  }).filter(function(b) { return b !== null }).sort(function(a, b) { return b.time - a.time || (a.name < b.name ? 1 : -1) })
}

// Whether an automatic backup is due: never made, or the last one a day
// (or a week) ago, give or take a few minutes.
function due(list, every, now) {
  var period = PERIOD[every]
  if (!period) return false
  var last = (list || []).filter(function(b) { return b.automatic })[0]
  return !last || now - last.time >= period - 10 * 60 * 1000
}

// The automatic backups past the newest `keep` (the oldest), to clear out.
function toPrune(list, keep) {
  var n = keep === null || keep === undefined || keep === "" ? NaN : Number(keep)
  var k = Math.max(1, isFinite(n) ? Math.round(n) : 10)
  return (list || []).filter(function(b) { return b.automatic }).slice(k)
}

// A name for a profile put back: its own, or "Name (restored)", "Name
// (restored 2)"... if that's taken.
function restoredName(taken, name) {
  var base = line(name, 48) || "Restored"
  var lower = (taken || []).map(function(n) { return String(n).toLowerCase() })
  if (lower.indexOf(base.toLowerCase()) < 0) return base
  for (var i = 1; ; i++) {
    var n = base + " (restored" + (i > 1 ? " " + i : "") + ")"
    if (lower.indexOf(n.toLowerCase()) < 0) return n
  }
}

// Where a profile put back goes (a new folder; the script adds " 2"... if
// it's there already): "~/Documents/Uber Notebook Personal (restored)".
function restoreFolder(name) {
  return "~/Documents/" + APP + " " + (safeLabel(name) || "Restored") + " (restored)"
}

// A profile not put back because where it goes is on a drive that can't
// keep files private (~/Documents a link to an exFAT or NTFS partition, a
// share): what the files helper says then (restore-backup), and how it's
// said ("~/Documents can't keep ...").
function notPrivate(said) {
  return /can't keep your notes private/.test(String(said || ""))
}
function notPrivateNote(folder) {
  return folder + " can't keep your notes private: another account on this computer could read them there"
}

// The backup folder as a path relative to a profile's folder, if it's
// inside it (left out of the backup, or each would hold the ones before),
// else "".
function inside(backupDir, profileDir) {
  var b = String(backupDir || "").replace(/\/+$/, "")
  var p = String(profileDir || "").replace(/\/+$/, "")
  if (!b || !p) return ""
  if (b === p) return "."
  return b.indexOf(p + "/") === 0 ? b.slice(p.length + 1) : ""
}

function sizeLabel(bytes) {
  var n = Number(bytes) || 0
  if (n < 1024) return n + " B"
  if (n < 1024 * 1024) return Math.round(n / 1024) + " KB"
  if (n < 1024 * 1024 * 1024) return (n / 1024 / 1024).toFixed(n < 10 * 1024 * 1024 ? 1 : 0) + " MB"
  return (n / 1024 / 1024 / 1024).toFixed(1) + " GB"
}

// ---- the scripts (bash -c <script> <name> <args...>) ----

// Which folders are there: "1" or "0" a line, for each argument.
var EXISTS_SCRIPT = "for d in \"$@\"; do if [ -d \"$d\" ]; then echo 1; else echo 0; fi; done"

// The backups in a folder: "<modified>\t<size>\t<name>" a line. (The
// folder made yours alone as it's looked in: one from before was open to
// other accounts, and backups hold all your notes. "open" on a line of its
// own when it can't be: a drive that can't keep modes, a folder not yours,
// a share that takes every account for the same one.)
var LIST_SCRIPT = "[ -d \"$1\" ] || exit 0; /usr/bin/chmod go-rwx -- \"$1\" 2>/dev/null; m=$(/usr/bin/stat -L -c %a -- \"$1\" 2>/dev/null); u=$(/usr/bin/stat -L -c %u -- \"$1\" 2>/dev/null); "
  + "[ -n \"$m\" ] && [ \"$u\" = \"$UID\" ] && [ $(( 8#$m & 077 )) -eq 0 ] || echo open; /usr/bin/find \"$1\" -mindepth 1 -maxdepth 1 -type f -name '*.tar.gz' ! -name '.*' -printf '%T@\\t%s\\t%f\\n' 2>/dev/null | /usr/bin/head -n 2000"

// A backup made: <folder> <stem> <suffix> then, for each profile, <its
// folder> <p1...> <a folder in it to leave out, or "">; its
// uber-notebook-backup.json (the profiles' names) on its input, never on a
// command line, where every account on the computer can read it. Everything
// it makes is yours alone (umask 077), the backups' folder too (700, one
// from before as well): backups hold all your notes.
// It's written beside where it goes, in files of its own (mktemp: made new,
// never one that's there), and named when it's done, never over a file
// that's there (mv --update=none-fail: the next free name then), so a backup
// that's there is a whole one. Prints its size, then its path.
var BACKUP_SCRIPT = [
  "umask 077",
  "dir=$1; stem=$2; suffix=$3; shift 3",
  "/usr/bin/mkdir -p -- \"$dir\" || exit 3",
  "/usr/bin/chmod go-rwx -- \"$dir\" 2>/dev/null",
  // (A drive that can't keep files private (exFAT, some shares), a folder
  // that isn't yours (a share that takes every account for the same one):
  // no backup of your notes is written there; said, after "open" on a
  // line of its own (exit 4).)
  "m=$(/usr/bin/stat -L -c %a -- \"$dir\") || exit 3",
  "u=$(/usr/bin/stat -L -c %u -- \"$dir\") || exit 3",
  "[ \"$u\" = \"$UID\" ] && [ $(( 8#$m & 077 )) -eq 0 ] || { printf 'open\\n%s\\n' \"That folder can't keep your backups private: another account on this computer could read them there. Pick another folder for backups\" >&2; exit 4; }",
  "tmp=$(/usr/bin/mktemp -d) || exit 3",
  "part=$(/usr/bin/mktemp -p \"$dir\" \".$stem.part-XXXXXXXX\") || exit 3",
  "gz=$(/usr/bin/mktemp -p \"$dir\" \".$stem.part-XXXXXXXX\") || exit 3",
  "trap '/usr/bin/rm -rf -- \"$tmp\"; /usr/bin/rm -f -- \"$part\" \"$gz\"' EXIT",
  "/usr/bin/cat > \"$tmp/" + MANIFEST + "\" || exit 3",
  "/usr/bin/tar -cf \"$part\" -C \"$tmp\" " + MANIFEST + " || exit 3",
  "while [ $# -ge 3 ]; do",
  "  src=$1; name=$2; skip=$3; shift 3",
  "  if [ -n \"$skip\" ]; then /usr/bin/tar -rf \"$part\" -C \"$src\" --exclude=\"./$skip\" --transform=\"s|^\\.|$name|\" .; else /usr/bin/tar -rf \"$part\" -C \"$src\" --transform=\"s|^\\.|$name|\" .; fi",
  // (1: a file changed while it was read; what was read is kept.)
  "  rc=$?; [ $rc -le 1 ] || exit 3",
  "done",
  "/usr/bin/gzip -6 -c -- \"$part\" > \"$gz\" || exit 3",
  "out=\"$dir/$stem$suffix\"; i=2",
  "until /usr/bin/mv --update=none-fail -- \"$gz\" \"$out\" 2>/dev/null; do",
  "  [ -e \"$out\" ] && [ $i -lt 1000 ] || exit 3",
  "  out=\"$dir/$stem $i$suffix\"; i=$((i+1))",
  "done",
  "/usr/bin/stat -c '%s' -- \"$out\"",
  "printf '%s\\n' \"$out\""
].join("\n")

// Looking into a backup and putting one back is the archive helper's
// (bin/uber-notebook-files): inspect-backup prints whether it's readable,
// the kinds of things in it ("-" files, "d" folders), how many names fall
// outside what a backup holds or reach up (..), the file's sha256, then its
// uber-notebook-backup.json (checked() reads that); restore-backup puts one
// profile back from that same file (if it's still the one looked into),
// into a new folder.
