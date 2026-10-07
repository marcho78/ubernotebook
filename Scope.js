// Scope.js - what an agent working in Uber Notebook's panel may do through
// Uber Notebook's commands while it works: it calls them under their own
// name (omarchy-shell uber-notebook-agent ..., Service.qml's IPC), so yours,
// scripts' and a terminal's agent's (omarchy-shell uber-notebook ...) go on
// as always meanwhile.
//
// It works for you, on what you asked: it may read your notes and change
// them (pages, People, the calendar, templates, tags, notebooks' pages). It
// may not change Uber Notebook itself: its settings (the permissions you gave
// agents among them), profiles, backups. A file a command reads comes only
// from the agent's own folder; a picture it puts on a page, from there or
// from a folder of pictures it makes itself (`pictures`: Grok's image tool
// saves them in its session for this conversation), and only a picture; a
// file from anywhere else, once you've said yes to it (`approved`: Service
// asks you, Api.askForFiles). A command not named here isn't one an agent
// may use (one added later is refused until it's put here). Stopping
// (`frozen`), it may change nothing. The scope: { agent (its name), dir (its
// folder), pictures, approved, frozen }; null when no agent is working.
//
// Shared by Service.qml and tests/scope.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library

// Commands that only read (or show Uber Notebook).
var READS = ["help", "list", "find", "read", "blocks", "tags", "library", "contacts", "contact", "tagged", "projects", "templates",
  "events", "trashed", "history", "version", "preferences", "notebooks", "notebook", "readNotebook", "profiles", "backups",
  "appVersion", "checkUpdate", "releaseNotes", "skill", "status", "toggle", "show", "hide", "search", "shelf", "pages", "calendar", "open", "settings"]

// Commands that change your notes.
var CHANGES = ["add", "addTo", "append", "replace", "insertAfter", "check", "color", "removeBlock", "board", "picture", "setLink",
  "bookmark", "attach", "addGallery", "gallery", "rename", "icon", "cover", "lock", "favorite", "trash", "restore", "project", "archive",
  "unarchive", "restoreVersion", "move", "duplicate", "fromTemplate", "makeTemplate", "describeTemplate", "addTemplate", "addContact",
  "editContact", "removeContact", "importContacts", "tagColor", "renameTag", "removeTag", "addEvent", "editEvent", "removeEvent",
  "importCalendar", "addToNotebook"]

// Which of a command's arguments are files (by place; "list:n": a list of
// them, one a line or | between).
var FILES = {
  add: [1], addTo: [2], append: [1], replace: [2], insertAfter: [2], attach: [1], addGallery: ["list:1"], gallery: ["list:3"],
  addTemplate: [1], addToNotebook: [1], importContacts: [0], importCalendar: [0]
}

// A file in the agent's own folder (by its full path, nothing that leaves it).
function inFolder(scope, path) {
  var p = String(path || "").trim()
  var dir = String(scope.dir || "")
  return dir.length > 1 && p.indexOf(dir + "/") === 0 && !/(^|\/)\.\.(\/|$)/.test(p) && !/[\u0000-\u001f]/.test(p)
}

// A picture (by its name) in one of the agent's folders of pictures it made:
// that folder, or "". (Its contents are checked as it's copied in: a real
// picture, through no link: the files helper's copy-picture.)
var PICTURE = /\.(png|jpe?g|gif|webp|bmp|svg)$/i
function inPictures(scope, path) {
  var p = String(path || "").trim()
  if (!PICTURE.test(p) || /(^|\/)\.\.(\/|$)/.test(p) || /[\u0000-\u001f]/.test(p)) return ""
  var list = scope && Array.isArray(scope.pictures) ? scope.pictures : []
  for (var i = 0; i < list.length; i++) {
    var d = String(list[i] || "")
    if (d.length > 1 && d.charAt(0) === "/" && p.indexOf(d + "/") === 0) return d
  }
  return ""
}
// A file you've said yes to (the very path): the folder it's read from,
// every step below it through no link (the one you said Always to, or "/"
// for a yes to that file alone: every step of it), or "".
function approvedFolder(scope, path) {
  var p = String(path || "").trim()
  var list = scope && Array.isArray(scope.approved) ? scope.approved : []
  if (!/^\/[^\u0000-\u001f]+$/.test(p) || /(^|\/)\.\.?(\/|$)/.test(p)) return ""
  for (var i = 0; i < list.length; i++) {
    var e = list[i]
    var path_ = typeof e === "string" ? e : e && e.path
    if (path_ !== p) continue
    var root = typeof e === "string" ? "/" : String(e.root || "/")
    return root === "/" || p.indexOf(root + "/") === 0 ? root : ""
  }
  return ""
}
// The scope with those files said yes to ([{ path, root }], or paths: "/").
function withApproved(scope, entries) {
  if (!scope) return scope
  var out = {}
  for (var k in scope) out[k] = scope[k]
  out.approved = (Array.isArray(scope.approved) ? scope.approved : []).concat((entries || []).map(function(e) {
    return typeof e === "string" ? { path: e, root: "/" } : { path: String(e.path || ""), root: String(e.root || "/") }
  }))
  return out
}
// The folder a file the agent gives is read from, every step through no
// link: its own, a folder of pictures it made (a picture), or the folder a
// file you've said yes to is in (the file itself through no link); "" if
// none.
function within(scope, path) {
  if (!scope) return ""
  return inFolder(scope, path) ? String(scope.dir) : inPictures(scope, path) || approvedFolder(scope, path)
}
// The commands whose files are pictures (a picture attached, a gallery's).
var PICTURE_FILES = ["attach", "addGallery", "gallery"]

function paths(value) {
  return String(value || "").split(/\n|\|/).map(function(p) { return p.trim() }).filter(function(p) { return p !== "" })
}

// A command from you (`forAgent` false: the uber-notebook commands, from a
// script, a terminal's agent or you) goes ahead as always; from the panel's
// agent (the uber-notebook-agent commands), as check() says while it works,
// and not at all when no agent is working there. "" or why not.
function forCaller(forAgent, scope, command, args) {
  if (!forAgent) return ""
  if (!scope) return "no agent is working in Uber Notebook's panel: the uber-notebook-agent commands work only for the agent working there, while it works"
  return check(scope, command, args)
}

// The files a command gives that are from outside the agent's folders, to
// ask you about: [paths], [] when there are none, null when one can't be
// asked about (not a full path, or with .. or a control character in it).
function outsideFiles(scope, command, args) {
  var name = String(command || "")
  if (!scope || CHANGES.indexOf(name) < 0 || !Object.prototype.hasOwnProperty.call(FILES, name)) return []
  var a = args || []
  var out = []
  var files = FILES[name]
  for (var i = 0; i < files.length; i++) {
    var f = files[i]
    if (typeof f === "string" && name === "gallery" && String(a[2] || "") !== "add") continue
    var list = typeof f === "string" ? paths(a[Number(f.slice(5))]) : [a[f]]
    for (var k = 0; k < list.length; k++) {
      var p = String(list[k] || "").trim()
      if (inFolder(scope, p) || (PICTURE_FILES.indexOf(name) >= 0 && inPictures(scope, p)) || approvedFolder(scope, p)) continue
      if (!/^\/[^\u0000-\u001f\u007f]{1,4000}$/.test(p) || /(^|\/)\.\.?(\/|$)/.test(p) || /\/$/.test(p)) return null
      // (A gallery's: each picture by its own path; a folder of them from
      // outside isn't taken.)
      if (PICTURE_FILES.indexOf(name) >= 0 && name !== "attach" && !PICTURE.test(p)) return null
      if (out.indexOf(p) < 0) out.push(p)
    }
  }
  return out
}

// "" when `command` with `args` may go ahead, else why not.
function check(scope, command, args) {
  if (!scope) return ""
  var name = String(command || "")
  if (READS.indexOf(name) >= 0) return ""
  var who = String(scope.agent || "An agent")
  if (CHANGES.indexOf(name) < 0) return "not while " + who + " is working in Uber Notebook's panel: it can read and change your notes, not Uber Notebook's settings, profiles or backups"
  if (scope.frozen) return "not now: " + who + " is being stopped"
  var a = args || []
  var files = Object.prototype.hasOwnProperty.call(FILES, name) ? FILES[name] : []
  for (var i = 0; i < files.length; i++) {
    var f = files[i]
    var list = typeof f === "string" ? paths(a[Number(f.slice(5))]) : [a[f]]
    if (typeof f === "string" && name === "gallery" && String(a[2] || "") !== "add") continue
    for (var k = 0; k < list.length; k++) {
      if (inFolder(scope, list[k]) || (PICTURE_FILES.indexOf(name) >= 0 && inPictures(scope, list[k])) || approvedFolder(scope, list[k])) continue
      // (What to do instead, said: never a dead end.)
      var pics = Array.isArray(scope.pictures) && scope.pictures.length ? "; a picture you made yourself is taken from " + scope.pictures.join(" or ") + " too" : ""
      if (PICTURE_FILES.indexOf(name) >= 0 && name !== "attach" && !PICTURE.test(String(list[k] || ""))) pics += "; for a gallery, give each picture's own path (a folder of them from outside it isn't taken)"
      return "not while " + who + " is working in Uber Notebook's panel: the files its commands read come only from its own folder (" + scope.dir + "): save or copy the file there and give that path" + pics
    }
  }
  return ""
}
