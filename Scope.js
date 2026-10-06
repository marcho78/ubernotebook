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
// saves them in its session for this conversation), and only a picture. A
// command not named here isn't one an agent may use (one added later is
// refused until it's put here). Stopping (`frozen`), it may change nothing.
// The scope: { agent (its name), dir (its folder), pictures, frozen }; null
// when no agent is working.
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
// The folder a file the agent gives is read from, every step through no
// link: its own, or (a picture) a folder of pictures it made; "" if neither.
function within(scope, path) {
  if (!scope) return ""
  return inFolder(scope, path) ? String(scope.dir) : inPictures(scope, path)
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
      if (inFolder(scope, list[k]) || (PICTURE_FILES.indexOf(name) >= 0 && inPictures(scope, list[k]))) continue
      // (What to do instead, said: never a dead end.)
      var pics = Array.isArray(scope.pictures) && scope.pictures.length ? "; a picture you made yourself is taken from " + scope.pictures.join(" or ") + " too" : ""
      return "not while " + who + " is working in Uber Notebook's panel: the files its commands read come only from its own folder (" + scope.dir + "): save or copy the file there and give that path" + pics
    }
  }
  return ""
}
