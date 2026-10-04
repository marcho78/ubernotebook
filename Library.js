// Library.js - the notebooks on disk: their ids and folder names, what a
// notebook's notebook.json and a page's JSON file may hold, and finding text
// in pages.
//
// The library is a folder (~/Documents/Uber Notebook by default) with a folder per
// notebook:
//
//   work-journal-k3f9/
//     notebook.json            title, cover, paper, the kind of page it makes,
//                              the pages in order
//     pages/<page id>.json     one page: its blocks, paper, tab, drawings, and
//                              the template and date it was made from
//     assets/<name>.png        pictures on its pages
//   library.json               the order of the notebooks on the shelf
//
// Everything read from these files is checked here before anything uses it,
// so a damaged or hand-edited file can't feed bad data onwards.
//
// Shared by the store (Store.qml) and tests/library.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library
.import "Blocks.js" as Blocks
.import "Papers.js" as Papers
.import "Covers.js" as Covers
.import "Templates.js" as Templates

var VERSION = 1
var MAX_TITLE = 120
var MAX_PAGES = 5000
var ID = /^[a-z0-9][a-z0-9-]{0,79}$/

function isId(value) {
  return typeof value === "string" && ID.test(value)
}

function pad(n, width) {
  var s = String(n)
  while (s.length < (width || 2)) s = "0" + s
  return s
}

function randomTail(length) {
  var out = ""
  var chars = "abcdefghijkmnpqrstuvwxyz23456789"
  for (var i = 0; i < (length || 4); i++) out += chars.charAt(Math.floor(Math.random() * chars.length))
  return out
}

// "Work Journal!" -> "work-journal"; letters beyond ASCII are kept where
// they're plain (é -> e), anything else becomes a dash.
function slugify(title) {
  var s = String(title || "").normalize ? String(title || "").normalize("NFKD") : String(title || "")
  s = s.replace(/[\u0300-\u036f]/g, "").toLowerCase().replace(/[^a-z0-9]+/g, "-").replace(/^-+|-+$/g, "")
  return s.slice(0, 40).replace(/-+$/, "") || "notebook"
}

// A notebook's id, which is also its folder's name: "work-journal-k3f9".
function notebookId(title, taken) {
  for (var tries = 0; tries < 30; tries++) {
    var id = slugify(title) + "-" + randomTail(4)
    if (!taken || !taken[id]) return id
  }
  return slugify(title) + "-" + randomTail(10)
}

// A page's id, which is also its file's name: "20260930-143201-k3f9".
function pageId(date, taken) {
  var d = date || new Date()
  var stamp = d.getFullYear() + pad(d.getMonth() + 1) + pad(d.getDate()) + "-" + pad(d.getHours()) + pad(d.getMinutes()) + pad(d.getSeconds())
  for (var tries = 0; tries < 30; tries++) {
    var id = stamp + "-" + randomTail(4)
    if (!taken || !taken[id]) return id
  }
  return stamp + "-" + randomTail(10)
}

function iso(date) {
  return (date || new Date()).toISOString()
}

function cleanDate(value, fallback) {
  if (typeof value !== "string" || value.length > 40) return fallback
  var t = Date.parse(value)
  return isFinite(t) ? new Date(t).toISOString() : fallback
}

function cleanTitle(value) {
  if (typeof value !== "string") return ""
  return value.replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, MAX_TITLE)
}

function choice(list, value, fallback) {
  for (var i = 0; i < list.length; i++) if (list[i].id === value) return value
  return fallback
}

// { pattern, color, spacing }, each one of its choices, or null.
function cleanPaper(raw) {
  if (!raw || typeof raw !== "object") return null
  return {
    pattern: choice(Papers.PATTERNS, raw.pattern, "ruled"),
    color: choice(Papers.PAPERS, raw.color, "ivory"),
    spacing: choice(Papers.SPACINGS, raw.spacing, "regular")
  }
}

function cleanCover(raw) {
  var c = raw && typeof raw === "object" ? raw : {}
  var out = {
    color: choice(Covers.COLORS, c.color, "navy"),
    material: choice(Covers.MATERIALS, c.material, "leather")
  }
  if (typeof c.band === "boolean") out.band = c.band
  return out
}

function cleanTab(raw) {
  if (!raw || typeof raw !== "object") return null
  var color = Papers.hex(raw.color)
  if (!color) return null
  return { color: color, label: cleanTitle(raw.label).slice(0, 24) }
}

// ---- notebooks ------------------------------------------------------------------

function newNotebook(options, date, taken) {
  var o = options || {}
  var now = iso(date)
  var title = cleanTitle(o.title) || "Untitled notebook"
  return {
    version: VERSION,
    id: isId(o.id) ? o.id : notebookId(title, taken),
    title: title,
    created: now,
    modified: now,
    cover: cleanCover(o.cover),
    binding: choice(Covers.BINDINGS, o.binding, "spiral"),
    paper: cleanPaper(o.paper) || { pattern: "ruled", color: "ivory", spacing: "regular" },
    pen: choice(Papers.PENS, o.pen, "sans"),
    template: cleanKind(o.template),
    pages: [],
    lastPage: "",
    role: o.role === "quick" ? "quick" : ""
  }
}

// The kind of page a notebook makes (Templates.PAGE_KINDS): "" is blank.
function cleanKind(value) {
  return Templates.isPageKind(value) && value !== "blank" ? value : ""
}

// The template a page was made from ("" for none), and the day it's for.
function cleanTemplate(value) {
  return Templates.isTemplate(value) && value !== "blank" ? value : ""
}

function cleanDay(value) {
  return Templates.isIsoDate(value) ? value : ""
}

// notebook.json as it may be used, or null when it isn't a notebook. `id`
// is the folder it was found in, which wins over what the file says.
function cleanNotebook(raw, id) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  if (!isId(id)) return null
  var created = cleanDate(raw.created, new Date(0).toISOString())
  var pages = []
  var seen = {}
  if (Array.isArray(raw.pages)) {
    for (var i = 0; i < raw.pages.length && pages.length < MAX_PAGES; i++) {
      var p = raw.pages[i]
      if (isId(p) && !seen[p]) { seen[p] = true; pages.push(p) }
    }
  }
  return {
    version: VERSION,
    id: id,
    title: cleanTitle(raw.title) || "Untitled notebook",
    created: created,
    modified: cleanDate(raw.modified, created),
    cover: cleanCover(raw.cover),
    binding: choice(Covers.BINDINGS, raw.binding, "spiral"),
    paper: cleanPaper(raw.paper) || { pattern: "ruled", color: "ivory", spacing: "regular" },
    pen: choice(Papers.PENS, raw.pen, "sans"),
    template: cleanKind(raw.template),
    pages: pages,
    lastPage: isId(raw.lastPage) && seen[raw.lastPage] ? raw.lastPage : "",
    role: raw.role === "quick" ? "quick" : ""
  }
}

// The pages in the notebook's order, then any page file it didn't list (a
// page written just before a crash, or synced in from elsewhere), oldest
// first; listed pages whose files are gone are left out.
function reconcilePages(listed, onDisk) {
  var present = {}
  ;(onDisk || []).forEach(function(id) { if (isId(id)) present[id] = true })
  var out = []
  var used = {}
  ;(listed || []).forEach(function(id) {
    if (present[id] && !used[id]) { out.push(id); used[id] = true }
  })
  Object.keys(present).sort().forEach(function(id) {
    if (!used[id]) { out.push(id); used[id] = true }
  })
  return out
}

// The shelf's order: library.json's, then notebooks it didn't know, oldest first.
function shelfOrder(saved, notebooks) {
  var byId = {}
  notebooks.forEach(function(nb) { byId[nb.id] = nb })
  var out = []
  var used = {}
  ;(Array.isArray(saved) ? saved : []).forEach(function(id) {
    if (byId[id] && !used[id]) { out.push(byId[id]); used[id] = true }
  })
  notebooks.slice().sort(function(a, b) { return a.created < b.created ? -1 : a.created > b.created ? 1 : 0 }).forEach(function(nb) {
    if (!used[nb.id]) { out.push(nb); used[nb.id] = true }
  })
  return out
}

// ---- pages ---------------------------------------------------------------------------

function newPage(options, date, taken) {
  var o = options || {}
  var now = iso(date)
  return {
    version: VERSION,
    id: isId(o.id) ? o.id : pageId(date, taken),
    title: cleanTitle(o.title),
    created: now,
    modified: now,
    paper: cleanPaper(o.paper),
    tab: cleanTab(o.tab),
    template: cleanTemplate(o.template),
    day: cleanDay(o.day),
    blocks: Blocks.cleanList(o.blocks),
    ink: cleanInk(o.ink),
    text: ""
  }
}

// A page file as it may be used, or null. `id` is its file's name.
function cleanPage(raw, id) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  if (!isId(id)) return null
  var created = cleanDate(raw.created, new Date(0).toISOString())
  var blocks = Blocks.cleanList(raw.blocks)
  return {
    version: VERSION,
    id: id,
    title: cleanTitle(raw.title),
    created: created,
    modified: cleanDate(raw.modified, created),
    paper: cleanPaper(raw.paper),
    tab: cleanTab(raw.tab),
    template: cleanTemplate(raw.template),
    day: cleanDay(raw.day),
    blocks: blocks,
    ink: cleanInk(raw.ink),
    text: Blocks.plainText(blocks)
  }
}

// What a page is called: its title, else what its template calls it (a
// meeting's page is "Meeting notes" before it has a name), else its first line.
function pageTitle(page, max) {
  if (page.title) return page.title
  if (page.template) return Templates.byId(page.template).label
  return Blocks.firstLine(page.blocks || [], max || 60)
}

// What the page list shows for a page, without its blocks.
function summary(page) {
  var progress = Blocks.checklistProgress(page.blocks)
  return {
    id: page.id,
    title: pageTitle(page, 60),
    named: !!page.title,
    created: page.created,
    modified: page.modified,
    tab: page.tab,
    words: Blocks.wordCount(page.blocks),
    checks: progress.total,
    done: progress.done,
    blank: !page.title && Blocks.isBlank(page.blocks)
  }
}

// Drawings on a page: strokes of a pen or a highlighter, as flat x,y lists.
function cleanInk(raw) {
  var out = []
  if (!Array.isArray(raw)) return out
  for (var i = 0; i < raw.length && out.length < 4000; i++) {
    var s = raw[i]
    if (!s || typeof s !== "object" || !Array.isArray(s.points)) continue
    var color = Papers.hex(s.color)
    if (!color) continue
    var points = []
    for (var j = 0; j + 1 < s.points.length && j < 40000; j += 2) {
      var x = s.points[j]
      var y = s.points[j + 1]
      if (typeof x !== "number" || typeof y !== "number" || !isFinite(x) || !isFinite(y)) { points = null; break }
      points.push(Math.round(x * 10) / 10, Math.round(y * 10) / 10)
    }
    if (!points || points.length < 2) continue
    out.push({
      tool: s.tool === "marker" ? "marker" : "pen",
      color: color,
      width: typeof s.width === "number" && isFinite(s.width) ? Math.min(40, Math.max(0.5, s.width)) : 2,
      points: points
    })
  }
  return out
}

// ---- finding text ---------------------------------------------------------------------

function terms(query) {
  return String(query || "").toLowerCase().split(/\s+/).filter(function(t) { return t.length > 0 }).slice(0, 8)
}

// How well a page matches every term (0: not at all). The title counts most.
function score(title, text, query) {
  var list = terms(query)
  if (list.length === 0) return 0
  var t = String(title || "").toLowerCase()
  var body = String(text || "").toLowerCase()
  var total = 0
  for (var i = 0; i < list.length; i++) {
    var inTitle = t.indexOf(list[i]) >= 0
    var inBody = body.indexOf(list[i]) >= 0
    if (!inTitle && !inBody) return 0
    total += (inTitle ? 3 : 0) + (inBody ? 1 : 0)
    if (t.indexOf(list[i]) === 0) total += 2
  }
  return total
}

// A line of text around the first term found: { before, match, after }.
function snippet(text, query, radius) {
  var list = terms(query)
  var body = String(text || "").replace(/\s+/g, " ").trim()
  var lower = body.toLowerCase()
  var r = radius || 48
  var at = -1
  var term = ""
  for (var i = 0; i < list.length; i++) {
    var found = lower.indexOf(list[i])
    if (found >= 0 && (at < 0 || found < at)) { at = found; term = list[i] }
  }
  if (at < 0) return { before: body.slice(0, r * 2), match: "", after: "" }
  var start = Math.max(0, at - r)
  var end = Math.min(body.length, at + term.length + r)
  return {
    before: (start > 0 ? "\u2026" : "") + body.slice(start, at),
    match: body.slice(at, at + term.length),
    after: body.slice(at + term.length, end) + (end < body.length ? "\u2026" : "")
  }
}

// ---- files --------------------------------------------------------------------------

function notebookFile(root, id) { return root + "/" + id + "/notebook.json" }
function pagesDir(root, id) { return root + "/" + id + "/pages" }
function pageFile(root, id, page) { return root + "/" + id + "/pages/" + page + ".json" }
function assetsDir(root, id) { return root + "/" + id + "/assets" }
function libraryFile(root) { return root + "/library.json" }
function trashDir(root) { return root + "/.trash" }

// A picture's name in the notebook's assets: "20260930-143201-k3f9.png".
function assetName(sourcePath, date) {
  var m = /\.([A-Za-z0-9]{1,5})$/.exec(String(sourcePath || ""))
  var ext = m ? m[1].toLowerCase() : "png"
  if (["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"].indexOf(ext) < 0) ext = "png"
  return pageId(date) + "." + ext
}

// A folder's folders ("d\t0\tname") and files ("f\t<modified>\tname"),
// hidden ones left out: bash -c LIST_SCRIPT <name> <folder>.
var LIST_SCRIPT = "cd -- \"$1\" 2>/dev/null || exit 1; /usr/bin/find . -mindepth 1 -maxdepth 1 ! -name '.*' \\( -type d -printf 'd\\t0\\t%f\\n' -o -type f -printf 'f\\t%T@\\t%f\\n' \\) 2>/dev/null | /usr/bin/head -n 5000"

function isImagePath(path) {
  return /^\/[^\u0000-\u001f\u007f]{1,4000}\.(png|jpe?g|gif|webp|bmp|svg)$/i.test(String(path || ""))
}

// A picture's kind as the clipboard names it ("image/png"), from its
// name; "" for one that isn't a picture.
function pictureType(path) {
  var m = /\.([A-Za-z0-9]{1,5})$/.exec(String(path || ""))
  var types = { png: "image/png", jpg: "image/jpeg", jpeg: "image/jpeg", gif: "image/gif", webp: "image/webp", bmp: "image/bmp", svg: "image/svg+xml" }
  return m && Object.prototype.hasOwnProperty.call(types, m[1].toLowerCase()) ? types[m[1].toLowerCase()] : ""
}

// A name to save a copy of a picture as: `title` (its caption, its page's
// title) made a file's name, with the picture's own ending ("Trip to
// Lisbon.png"); "Picture.png" with none.
function saveName(title, src) {
  var m = /\.([A-Za-z0-9]{1,5})$/.exec(String(src || ""))
  var ext = m ? m[1].toLowerCase() : "png"
  var base = String(title || "").replace(/[\/\\:*?"<>|\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().replace(/^\.+/, "").slice(0, 80).trim()
  return (base || "Picture") + "." + ext
}

function stringify(value) {
  return JSON.stringify(value, null, 1) + "\n"
}
