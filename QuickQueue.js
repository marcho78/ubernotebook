// QuickQueue.js - quick notes that can't be written yet (Service.qml): the
// profile's notes still opening (a switch a moment ago, or the shell just
// started), or Pages not loaded. Each waits with the profile it was made in
// (its id: the same whatever folder it's given), and is only ever written
// into that one, once its notes folder is the one open and read; another
// profile opening first, those of the one being left go to its Quick notes
// notebook, while it's still open (never lost, never in another's).
//
// Shared with tests/quickqueue.test.cjs, so keep it plain JavaScript with no
// QML or Node APIs.
.pragma library
.import "Settings.js" as Settings

// The queue with one more: [{ text, root }] (`root`: the profile's id).
function add(list, text, root) {
  return (list || []).concat([{ text: String(text || ""), root: String(root || "") }])
}

// Those of the profile `root` (to write now), and the rest (kept for when
// theirs is open again): { mine: [text], rest: [{ text, root }] }.
function take(list, root) {
  var mine = []
  var rest = []
  ;(list || []).forEach(function(e) {
    if (e && e.root && e.root === root) mine.push(e.text)
    else if (e && e.root) rest.push(e)
  })
  return { mine: mine, rest: rest }
}

// The queue after those of the profile `root` are written: each given to
// `write(text)`, which says whether it's kept; one that isn't (its profile
// still loading) stays, under its profile, to be tried again. A note is
// never let go of before it's written. The others stay as they are.
function flush(list, root, write) {
  var t = take(list, root)
  var left = t.rest
  t.mine.forEach(function(text) { if (!write(text)) left = add(left, text, root) })
  return left
}

// Whether `path` is the folder the notes folder setting `folder` opens (the
// default place: in Documents, or in your home folder when there's none).
function isFolder(path, folder, home) {
  if (!path) return false
  return path === Settings.resolveFolder(folder, home, true) || path === Settings.resolveFolder(folder, home, false)
}

// The open profile's id once its notes folder is the one open and read, ""
// till then (s, as Store.qml has it: { profile, folder, home, rootPath,
// switching, ready }): not while it's being opened, nor while the folder of
// the one before is still there a moment.
function openProfile(s) {
  if (!s || !s.profile || s.switching || !s.ready) return ""
  return isFolder(s.rootPath, s.folder, s.home) ? s.profile : ""
}

// Whether the open profile's notes folder can't be used (Store.qml's
// blockedFolder, its own: not the one of a profile left a moment ago).
function blocked(s) {
  return !!s && !!s.blockedFolder && !s.switching && isFolder(s.blockedFolder, s.folder, s.home)
}

// What's done with a quick note now: "write" it (its profile's notes are
// open), "wait" (they're being opened: kept for that profile, written once
// they are), or "refuse" (no profile known yet, or its folder can't be
// used: said, and the note left with you).
function now(s) {
  if (!s || !s.profile || blocked(s)) return "refuse"
  return openProfile(s) ? "write" : "wait"
}
