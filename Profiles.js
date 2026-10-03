// Profiles.js - notes kept apart: personal, business, the demo... each a
// profile, a folder of its own (its notebooks, Pages, calendar, People,
// templates). One is open at a time; switching keeps what's the open one's
// own (where agents' pages go, the page you were on, the notebook, the
// Markdown copy) on it, and puts the next one's back.
//
// Kept in the settings (Defaults.js): `profiles` [{ id, name, folder, demo,
// saved }] and `profile`, the open one's id; the open one's own settings are
// the settings themselves (folder, inbox...), and its `saved` is what they
// were when it was last left.
//
// Shared by Profiles.qml and tests/profiles.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library
.import "Settings.js" as Settings
.import "Defaults.js" as Defaults

var MAX = 30
// A profile's own settings, besides its folder.
var KEYS = Settings.PROFILE_KEYS
// The demo's folder, under Uber Notebook's data folder (a new one each time it starts over).
var DEMO_NAME = "Demo"

function line(value, max) {
  return typeof value === "string" ? value.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max) : ""
}

function newId(list, random) {
  var r = random || Math.random
  var taken = {}
  ;(list || []).forEach(function(p) { taken[p.id] = true })
  for (;;) {
    var id = "p-" + Math.floor(r() * 0x100000000).toString(36)
    if (!taken[id]) return id
  }
}

// One by its id, or its name (any case), or null.
function find(list, which) {
  var w = String(which || "").trim()
  if (!w) return null
  var l = w.toLowerCase()
  return (list || []).filter(function(p) { return p.id === w })[0] || (list || []).filter(function(p) { return p.name.toLowerCase() === l })[0] || null
}

// The folder as a real path, for telling two apart ("" is the default place).
function realFolder(folder, home) {
  return Settings.resolveFolder(folder || "", home || "", true)
}

// What's wrong with a name, or "".
function nameProblem(list, name, exceptId) {
  var n = line(name, 60)
  if (!n) return "Give it a name"
  if ((list || []).some(function(p) { return p.id !== exceptId && p.name.toLowerCase() === n.toLowerCase() })) return "There's a profile called that already"
  return ""
}

// What's wrong with a folder, or "": it's a folder (absolute, or ~/...),
// and no other profile keeps its notes there (or in a folder inside it).
function folderProblem(list, folder, exceptId, home) {
  var f = Settings.cleanFolder(String(folder || ""))
  if (f === null || f === "") return "Choose a folder: a full path, or one under ~/"
  var real = realFolder(f, home)
  var clash = (list || []).filter(function(p) {
    if (p.id === exceptId) return false
    var other = realFolder(p.folder, home)
    return other === real || real.indexOf(other + "/") === 0 || other.indexOf(real + "/") === 0
  })[0]
  return clash ? "“" + clash.name + "” keeps its notes there" : ""
}

// Where a new profile's notes go, unless said: the usual place for the
// first, else beside it, named for it ("~/Documents/Uber Notebook Work").
function suggestFolder(list, name) {
  var n = String(name || "").trim().replace(/[\/\\:*?"<>|]+/g, " ").replace(/\s+/g, " ").slice(0, 40)
  return !list || !list.length ? "~/Documents/Uber Notebook" : "~/Documents/Uber Notebook" + (n ? " " + n : "")
}

// A new profile: { id, name, folder, demo: false, saved: {} }.
function make(list, name, folder, random) {
  return { id: newId(list, random), name: line(name, 60), folder: Settings.cleanFolder(String(folder || "")) || "", demo: false, saved: {} }
}

// The list with the open profile's own settings put on it (its folder, and
// `saved`), as they are now.
function withCurrent(list, settings) {
  return (list || []).map(function(p) {
    var c = JSON.parse(JSON.stringify(p))
    if (p.id === settings.profile) {
      c.folder = settings.folder || ""
      c.saved = {}
      KEYS.forEach(function(k) { c.saved[k] = settings[k] })
    }
    return c
  })
}

// Opening another: the settings to change ({ profiles, profile, folder,
// inbox, ... }), the one left keeping its own, the next one's back (or as
// a new profile starts, for what it hasn't got).
function switchTo(list, settings, id) {
  var next = find(list, id)
  if (!next) return null
  var out = { profiles: withCurrent(list, settings), profile: next.id, folder: next.folder }
  KEYS.forEach(function(k) { out[k] = next.saved && next.saved[k] !== undefined ? next.saved[k] : Defaults.DEFAULTS[k] })
  return out
}

// Before profiles there was one folder: its notes (in `folder`, where they
// were found) are a profile, "Personal", its own settings what they are now.
function fromBefore(folder, random) {
  var p = make([], "Personal", folder, random)
  return { profiles: [p], profile: p.id, folder: p.folder }
}

// The demo, a profile like any other, with its own folder.
function demo(list, folder, random) {
  var p = make(list, DEMO_NAME, folder, random)
  p.demo = true
  return p
}
