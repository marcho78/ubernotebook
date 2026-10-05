// Mirror.js - a Markdown copy of your notes, kept in a folder (Settings:
// "Markdown copy") so Obsidian, git, grep or any editor can read them. Pages
// keeps its tree there (Pages/Parent.md, and Parent's pages in Pages/Parent/),
// links between pages are links between the files, pictures are copied
// beside them and sketches are SVG files; each notebook is a folder of its
// pages, in order (Notebooks/Recipes/001 Shakshuka.md).
//
// The copy only goes one way: Uber Notebook writes it, and reads nothing from it.
// It writes a file only when what's in it changed (so git sees real changes),
// and takes away only files it wrote itself, as its manifest
// (.uber-notebook-mirror.json) lists them: anything else in the folder is never
// touched, and a file of yours with a name it wants keeps it (Uber Notebook's
// takes "Name (2).md").
//
// Shared with tests/mirror.test.cjs, so keep it plain JavaScript with no QML
// or Node APIs.
.pragma library

var MANIFEST = ".uber-notebook-mirror.json"
// A copy made before Uber Notebook was renamed: its manifest, read when
// there's no new one (and written as the new one from then on).
var LEGACY_MANIFEST = ".omanote-mirror.json"
// Folders in the notes folder that are Uber Notebook's own.
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
  var seen = Object.create(null)
  // (A folder at a time, without calling itself: a tree thousands of pages
  // deep mustn't run the shell out of stack. Each folder's names are its own.)
  var stack = [{ ids: index.top || [], i: 0, dir: "Pages", used: Object.create(null) }]
  while (stack.length) {
    var f = stack[stack.length - 1]
    if (f.i >= f.ids.length) { stack.pop(); continue }
    var id = f.ids[f.i++]
    var e = index.pages[id]
    if (!e || e.trashed || seen[id]) continue
    seen[id] = true
    var base = safeName(e.title, "Untitled")
    var name = base
    for (var n = 2; f.used[name.toLowerCase()]; n++) name = base + " " + n
    f.used[name.toLowerCase()] = true
    out[id] = f.dir + "/" + name + ".md"
    if (e.children && e.children.length) stack.push({ ids: e.children, i: 0, dir: f.dir + "/" + name, used: Object.create(null) })
  }
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

// A file of yours already at a path Uber Notebook wants (and isn't its own): its
// takes the next free "Name (2).md". `paths` is { key: path }, changed in place.
function claim(paths, manifest, existing) {
  var taken = {}
  for (var k in paths) taken[paths[k]] = true
  for (var key in paths) {
    var p = paths[key]
    if (manifest[p] !== undefined || !existing[p]) continue
    var stem = p.replace(/\.md$/, "")
    var next = p
    // (A name it already has, from before, is still its: kept, not passed over.)
    for (var n = 2; (existing[next] && manifest[next] === undefined) || (taken[next] && next !== p) || next === p; n++) next = stem + " (" + n + ").md"
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

// A file's fingerprint, to know it's still as the copy wrote it: SHA-256
// of its bytes (its text as UTF-8), "s256:<hex>". The files helper works it
// out from a file's bytes the same way (mirror-apply). A copy made before
// kept a short one ("<8 hex>:<length>"): never taken as proof (isHash).
function hash(text) {
  return "s256:" + sha256(text)
}
function isHash(value) {
  return /^s256:[0-9a-f]{64}$/.test(String(value || ""))
}

// (Of a text's UTF-8 bytes, as hex.)
var K256 = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2]
function utf8(text) {
  var s = String(text)
  var out = []
  for (var i = 0; i < s.length; i++) {
    var c = s.charCodeAt(i)
    if (c >= 0xd800 && c < 0xdc00 && i + 1 < s.length) {
      var d = s.charCodeAt(i + 1)
      if (d >= 0xdc00 && d < 0xe000) { c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00); i++ }
    }
    if (c < 0x80) out.push(c)
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63))
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
  }
  return out
}
function sha256(text) {
  var bytes = utf8(text)
  var n = bytes.length
  bytes.push(0x80)
  while (bytes.length % 64 !== 56) bytes.push(0)
  var bits = n * 8
  var hi = Math.floor(bits / 0x100000000)
  bytes.push((hi >>> 24) & 255, (hi >>> 16) & 255, (hi >>> 8) & 255, hi & 255, (bits >>> 24) & 255, (bits >>> 16) & 255, (bits >>> 8) & 255, bits & 255)
  var h = [0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19]
  var w = new Array(64)
  for (var off = 0; off < bytes.length; off += 64) {
    for (var t = 0; t < 16; t++) w[t] = (bytes[off + 4 * t] << 24) | (bytes[off + 4 * t + 1] << 16) | (bytes[off + 4 * t + 2] << 8) | bytes[off + 4 * t + 3]
    for (t = 16; t < 64; t++) {
      var x = w[t - 15], y = w[t - 2]
      var s0 = ((x >>> 7) | (x << 25)) ^ ((x >>> 18) | (x << 14)) ^ (x >>> 3)
      var s1 = ((y >>> 17) | (y << 15)) ^ ((y >>> 19) | (y << 13)) ^ (y >>> 10)
      w[t] = (w[t - 16] + s0 + w[t - 7] + s1) | 0
    }
    var a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], k = h[7]
    for (t = 0; t < 64; t++) {
      var S1 = ((e >>> 6) | (e << 26)) ^ ((e >>> 11) | (e << 21)) ^ ((e >>> 25) | (e << 7))
      var ch = (e & f) ^ (~e & g)
      var t1 = (k + S1 + ch + K256[t] + w[t]) | 0
      var S0 = ((a >>> 2) | (a << 30)) ^ ((a >>> 13) | (a << 19)) ^ ((a >>> 22) | (a << 10))
      var maj = (a & b) ^ (a & c) ^ (b & c)
      var t2 = (S0 + maj) | 0
      k = g; g = f; f = e; e = (d + t1) | 0; d = c; c = b; b = a; a = (t1 + t2) | 0
    }
    h[0] = (h[0] + a) | 0; h[1] = (h[1] + b) | 0; h[2] = (h[2] + c) | 0; h[3] = (h[3] + d) | 0
    h[4] = (h[4] + e) | 0; h[5] = (h[5] + f) | 0; h[6] = (h[6] + g) | 0; h[7] = (h[7] + k) | 0
  }
  return h.map(function(v) { return ("0000000" + (v >>> 0).toString(16)).slice(-8) }).join("")
}

// What to do: { write: [path], remove: [path] }. A file is written when it's
// new, changed, or gone from the folder; a file of the mirror's that isn't
// wanted any more goes. `desired` is { path: text }, `manifest` { path: hash },
// `existing` { path: true } for the files in the folder.
// (`hashOf(path, text)`, if given, gives a file's fingerprint: Mirror.qml
// keeps them, to work one out again only when its text changed.)
function plan(manifest, desired, existing, hashOf) {
  var fp = typeof hashOf === "function" ? hashOf : function(p, text) { return hash(text) }
  var write = []
  var remove = []
  for (var p in desired) if (manifest[p] !== fp(p, desired[p]) || !existing[p]) write.push(p)
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
// and not Uber Notebook's own folders in it (its Pages, a notebook's folder, the
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
    if (RESERVED.indexOf(first) >= 0 || (notebookIds || []).indexOf(first) >= 0) return "that's one of Uber Notebook's own folders: pick another, like " + r + "/Markdown"
  }
  return ""
}
