// Mirror.js - a Markdown copy of your notes, kept in a folder (Settings:
// "Markdown copy") so Obsidian, git, grep or any editor can read them. Pages
// keeps its tree there (Pages/Parent.md, and Parent's pages in Pages/Parent/),
// links between pages are links between the files, pictures are copied
// beside them and sketches are SVG files; each notebook is a folder of its
// pages, in order (Notebooks/Recipes/001 Shakshuka.md).
//
// The copy only goes one way: Omanote writes it, and reads nothing from it.
// It writes a file only when what's in it changed (so git sees real changes),
// and takes away only files it wrote itself, as its manifest
// (.omanote-mirror.json) lists them: anything else in the folder is never
// touched, and a file of yours with a name it wants keeps it (Omanote's
// takes "Name (2).md").
//
// Shared with tests/mirror.test.cjs, so keep it plain JavaScript with no QML
// or Node APIs.
.pragma library

var MANIFEST = ".omanote-mirror.json"
// Folders in the notes folder that are Omanote's own.
var RESERVED = ["Pages", ".trash", "Exports", "assets"]

// A title as a file or folder name: no slashes or other characters a file
// system or a sync service refuses, no leading dot (a hidden file), not too long.
function safeName(title, fallback) {
  var t = String(title || "").replace(/[\/\\:*?"<>|\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim()
  t = t.replace(/^\.+/, "").trim()
  if (t.length > 80) t = t.slice(0, 80).trim()
  return t || fallback || "Untitled"
}

// Pages' files, following the tree: { id: "Pages/Parent/Child.md" }. A
// page's pages are in a folder named as it is, beside its file; pages in the
// trash are left out; siblings with one name are "Name", "Name 2"...
function pagePaths(index) {
  var out = {}
  var seen = {}
  function walk(ids, dir) {
    var used = {}
    ;(ids || []).forEach(function(id) {
      var e = index.pages[id]
      if (!e || e.trashed || seen[id]) return
      seen[id] = true
      var base = safeName(e.title, "Untitled")
      var name = base
      for (var n = 2; used[name.toLowerCase()]; n++) name = base + " " + n
      used[name.toLowerCase()] = true
      out[id] = dir + "/" + name + ".md"
      if (e.children && e.children.length) walk(e.children, dir + "/" + name)
    })
  }
  walk(index.top, "Pages")
  return out
}

// A notebook's folder names: [{ id, dir: "Notebooks/Recipes" }], in shelf order.
function notebookDirs(notebooks) {
  var used = {}
  return notebooks.map(function(nb) {
    var base = safeName(nb.title, "Notebook")
    var name = base
    for (var n = 2; used[name.toLowerCase()]; n++) name = base + " " + n
    used[name.toLowerCase()] = true
    return { id: nb.id, dir: "Notebooks/" + name }
  })
}

// A notebook page's file in its folder: "001 Title.md" (its place, then its name).
function notebookFile(dir, index, name) {
  return dir + "/" + ("00" + (index + 1)).slice(-3) + " " + name
}

// A file of yours already at a path Omanote wants (and isn't its own): its
// takes the next free "Name (2).md". `paths` is { key: path }, changed in place.
function claim(paths, manifest, existing) {
  var taken = {}
  for (var k in paths) taken[paths[k]] = true
  for (var key in paths) {
    var p = paths[key]
    if (manifest[p] !== undefined || !existing[p]) continue
    var stem = p.replace(/\.md$/, "")
    var next = p
    for (var n = 2; existing[next] || (taken[next] && next !== p) || next === p; n++) next = stem + " (" + n + ").md"
    delete taken[p]
    taken[next] = true
    paths[key] = next
  }
  return paths
}

function encodeSegment(s) {
  return encodeURIComponent(s).replace(/\(/g, "%28").replace(/\)/g, "%29")
}

// A link from one file to another in the folder: "../Other/Page%202.md".
function relative(fromFile, toFile) {
  var a = String(fromFile).split("/").slice(0, -1)
  var b = String(toFile).split("/")
  var i = 0
  while (i < a.length && i < b.length - 1 && a[i] === b[i]) i++
  var up = a.slice(i).map(function() { return ".." })
  return up.concat(b.slice(i).map(encodeSegment)).join("/")
}

// From a file's folder to the top of the mirror: "", "../", "../../"...
function toTop(file) {
  var depth = String(file).split("/").length - 1
  return new Array(depth + 1).join("../")
}

// A short fingerprint of a file's text, to know when it changed.
function hash(text) {
  var s = String(text)
  var h = 0x811c9dc5
  for (var i = 0; i < s.length; i++) {
    h ^= s.charCodeAt(i)
    h = (h + ((h << 1) + (h << 4) + (h << 7) + (h << 8) + (h << 24))) >>> 0
  }
  return ("0000000" + h.toString(16)).slice(-8) + ":" + s.length
}

// What to do: { write: [path], remove: [path] }. A file is written when it's
// new, changed, or gone from the folder; a file of the mirror's that isn't
// wanted any more goes. `desired` is { path: text }, `manifest` { path: hash },
// `existing` { path: true } for the files in the folder.
function plan(manifest, desired, existing) {
  var write = []
  var remove = []
  for (var p in desired) if (manifest[p] !== hash(desired[p]) || !existing[p]) write.push(p)
  for (var q in manifest) if (desired[q] === undefined) remove.push(q)
  write.sort()
  remove.sort()
  return { write: write, remove: remove }
}

// The manifest kept after a sync: { path: hash } for every file written.
function manifestOf(desired) {
  var out = {}
  for (var p in desired) out[p] = hash(desired[p])
  return out
}

function cleanManifest(raw) {
  var out = {}
  var files = raw && typeof raw === "object" && raw.files && typeof raw.files === "object" ? raw.files : {}
  for (var p in files) {
    if (typeof files[p] === "string" && isMirrorPath(p)) out[p] = files[p]
  }
  return out
}

// Only files the mirror itself would write: under Pages/, Notebooks/ or
// sketches/, ending .md or .svg, with no way out of the folder.
function isMirrorPath(p) {
  return typeof p === "string" && /^(Pages|Notebooks|sketches)\//.test(p) && /\.(md|svg)$/.test(p)
    && !/(^|\/)\.\.?(\/|$)/.test(p) && p.indexOf("\u0000") < 0
}

// Can the copy go in that folder? "" if it can, else why not. Not your home
// folder or the top of the disk, not the notes folder or a folder it's in,
// and not Omanote's own folders in it (its Pages, a notebook's folder, the
// trash, Exports).
function folderProblem(folder, root, home, notebookIds) {
  function norm(p) { return String(p || "").replace(/\/+$/, "") || "/" }
  var f = norm(folder)
  var r = norm(root)
  if (!/^\//.test(f)) return "a folder's full path, please"
  if (f === "/" || f === norm(home)) return "not your whole home folder: a folder in it"
  if (f === r || r.indexOf(f + "/") === 0) return "that's where your notes are: a folder inside it, like " + r + "/Markdown"
  if (f.indexOf(r + "/") === 0) {
    var first = f.slice(r.length + 1).split("/")[0]
    if (RESERVED.indexOf(first) >= 0 || (notebookIds || []).indexOf(first) >= 0) return "that's one of Omanote's own folders: pick another, like " + r + "/Markdown"
  }
  return ""
}
