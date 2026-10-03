// Collection.js - what's been put on pages in Pages, gathered for the
// Library (the sidebar's Library: everything added, on every page): links
// (bookmark cards, and web links written in text), files (a PDF, a
// document...), videos, pictures, audio notes, meetings and sketches.
//
// A page's index entry keeps its things (Workspace.pageCollected, as the
// page is saved), so the Library is there without reading any page:
//
//   { block: "<block id>", kind: "link", title: "Omarchy 4", sub: "omarchy.org",
//     url: "https://omarchy.org/news", src: "", size: 0, thumb: "assets/bm-...png",
//     at: "2026-10-02T12:00:00.000Z", type: "bookmark", file: "", person: "" }
//
// People named on a page ("@Sam", or a contact block) are there by their id
// (`person`); emails written in text, as "mailto:..." links.
//
// A kind of block with something in it worth finding again says here how
// it's listed: KINDS (what it's called), and a line in ofBlock. Shared with
// tests/collection.test.cjs, so keep it plain JavaScript with no QML or Node
// APIs.
.pragma library
.import "Html.js" as Html
.import "Files.js" as Files
.import "Bookmark.js" as Bookmark
.import "Audio.js" as Audio
.import "Meeting.js" as Meeting
.import "Email.js" as Email

// The kinds, in the order the Library shows them: what each is called, and
// its icon (Theme.icons).
var KINDS = [
  { id: "link",    label: "Links",    one: "link",    icon: "link" },
  { id: "file",    label: "Files",    one: "file",    icon: "attach" },
  { id: "video",   label: "Videos",   one: "video",   icon: "video" },
  { id: "picture", label: "Pictures", one: "picture", icon: "image" },
  { id: "audio",   label: "Audio",    one: "audio note", icon: "waveform" },
  { id: "meeting", label: "Meetings", one: "meeting", icon: "people" },
  { id: "sketch",  label: "Sketches", one: "sketch",  icon: "sketch" },
  { id: "person",  label: "People",   one: "person",  icon: "person" },
  { id: "email",   label: "Emails",   one: "email",   icon: "mail" }
]
var MAX_PER_PAGE = 300
// What it gathers, as it is now: a page's list kept by an older one is read
// again (the index keeps which one made them).
var VERSION = 3
var MAX_TITLE = 200

function isKind(id) { return KINDS.some(function(k) { return k.id === id }) }
function kindOf(id) { return KINDS.filter(function(k) { return k.id === id })[0] || null }

function line(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max || MAX_TITLE)
}

// When a thing was added, from its file's name ("file-20261002-103012-...",
// "20261002-103012-k3f.png", "audio-20261002-..."): an ISO date, or "".
function dateOfAsset(src) {
  var m = /(?:^|[\/-])(\d{4})(\d{2})(\d{2})-(\d{2})(\d{2})(\d{2})/.exec(String(src || ""))
  if (!m) return ""
  var d = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), Number(m[4]), Number(m[5]), Number(m[6]))
  return isNaN(d.getTime()) ? "" : d.toISOString()
}

var MAILTO = /^mailto:[^\s@<>]+@[^\s@<>]+\.[A-Za-z]{2,}$/i
var PERSON = /^(?:uber-notebook|omanote):\/\/contact\/([A-Za-z0-9_-]{1,40})$/

function item(kind, block, fields) {
  var out = { block: block, kind: kind, title: "", sub: "", url: "", src: "", size: 0, thumb: "", at: "", type: "", file: "", person: "", who: "" }
  for (var k in fields) out[k] = fields[k]
  return out
}

// A block's things for the Library: [] for most blocks.
function ofBlock(b) {
  if (!b || typeof b !== "object") return []
  var uid = b.uid || b.id || ""
  var d = b.data || null
  if (b.type === "bookmark" && d && d.url) {
    return [item("link", uid, { type: "bookmark", title: line(d.title) || Bookmark.domain(d.url) || d.url, sub: line(d.site, 80) || Bookmark.domain(d.url), url: d.url, thumb: d.image || "", at: dateOfAsset(d.image) })]
  }
  if (b.type === "file" && d && d.src) {
    return [item(d.kind === "video" ? "video" : d.kind === "image" ? "picture" : "file", uid, { type: "file", title: line(d.name) || "File", src: d.src, size: d.size || 0, file: d.kind || Files.kindOf(d.name), thumb: d.kind === "image" ? d.src : "", at: dateOfAsset(d.src) })]
  }
  if (b.type === "video" && d && d.src) {
    return [item("video", uid, { type: "video", title: line(d.name) || "Video", src: d.src, size: d.size || 0, file: "video", thumb: d.poster || "", at: dateOfAsset(d.src) })]
  }
  if (b.type === "gallery" && d && d.images) {
    return d.images.map(function(x) { return item("picture", uid, { type: "gallery", title: line(x.caption) || "Picture", src: x.src, file: "image", thumb: x.src, at: dateOfAsset(x.src) }) })
  }
  if (b.type === "image" && b.src) {
    return [item("picture", uid, { type: "image", title: "Picture", src: b.src, file: "image", thumb: b.src, at: dateOfAsset(b.src) })]
  }
  if (b.type === "audio" && b.audio && b.audio.src) {
    var words = line(b.audio.transcript, 80)
    return [item("audio", uid, { type: "audio", title: words || "Audio note", sub: Audio.clock(b.audio.duration), src: b.audio.src, file: "audio", at: dateOfAsset(b.audio.src) })]
  }
  if (b.type === "meeting" && b.meeting && b.meeting.id) {
    var m = b.meeting
    return [item("meeting", uid, { type: "meeting", title: line(m.title) || "Meeting", sub: m.duration ? Audio.clock(m.duration) : "", at: m.startedAt || "" })]
  }
  // An email: its subject, who it's from and to, when it was sent.
  if (b.type === "email" && d && d.src) {
    var to = Email.shortNames(d.to, 2)
    return [item("email", uid, { type: "message", title: line(d.subject) || "(no subject)", sub: "From " + (Email.shortName(d.from) || "?") + (to ? " to " + to : ""),
      who: line([d.from, d.to, d.cc].join(" "), 600), src: d.src, size: d.size || 0, file: "eml", at: d.date || dateOfAsset(d.src) })]
  }
  if (b.type === "contact" && d && d.contact) {
    return [item("person", uid, { type: "contact", title: line(d.name) || "Contact", person: d.contact })]
  }
  if (b.type === "sketch" && b.sketch && b.sketch.strokes && b.sketch.strokes.length) {
    return [item("sketch", uid, { type: "sketch", title: "Sketch", sub: b.sketch.strokes.length + (b.sketch.strokes.length === 1 ? " stroke" : " strokes") })]
  }
  // Web links written in text, or in a table's cells (not links to pages,
  // tags or dates).
  var html = b.type === "code" ? "" : b.html ? b.html : b.type === "table" && b.table && Array.isArray(b.table.rows) ? b.table.rows.map(function(r) { return r.join(" ") }).join(" ") : ""
  if (html) {
    var seen = {}
    var out = []
    Html.links(html).forEach(function(l) {
      if (seen[l.href]) return
      seen[l.href] = true
      var text = line(l.text)
      var who = PERSON.exec(l.href)
      if (who) { out.push(item("person", uid, { type: "mention", title: text.replace(/^@/, "") || "Someone", person: who[1] })); return }
      if (MAILTO.test(l.href)) { out.push(item("email", uid, { type: "text", title: l.href.slice(7).toLowerCase(), url: l.href.toLowerCase() })); return }
      var url = Bookmark.cleanUrl(l.href)
      if (!url || url !== l.href) return
      out.push(item("link", uid, { type: "text", title: text && text !== l.href ? text : Bookmark.domain(l.href) || l.href, sub: Bookmark.domain(l.href), url: l.href }))
    })
    return out
  }
  return []
}

// A list as kept (the index read back), cleaned: what isn't right, left out.
function clean(list) {
  if (!Array.isArray(list)) return []
  var out = []
  list.forEach(function(r) {
    if (out.length >= MAX_PER_PAGE || !r || typeof r !== "object" || !isKind(r.kind)) return
    if (typeof r.block !== "string" || !/^[A-Za-z0-9_-]{1,64}$/.test(r.block)) return
    var url = r.kind === "email" ? (MAILTO.test(r.url || "") ? r.url : "") : r.url ? Bookmark.cleanUrl(r.url) : ""
    var src = r.src ? Files.cleanSrc(r.src) : ""
    var person = typeof r.person === "string" && /^[A-Za-z0-9_-]{1,40}$/.test(r.person) ? r.person : ""
    if (r.kind === "link" && !url) return
    if (r.kind === "email" && !url && !src) return
    if (r.kind === "person" && !person) return
    if ((r.kind === "file" || r.kind === "video" || r.kind === "picture" || r.kind === "audio") && !src) return
    var at = typeof r.at === "string" && !isNaN(new Date(r.at).getTime()) ? r.at : ""
    var size = Number(r.size)
    out.push({
      block: r.block, kind: r.kind, title: line(r.title) || (kindOf(r.kind).one), sub: line(r.sub, 80),
      url: url, src: src, size: isFinite(size) && size > 0 ? Math.round(size) : 0,
      thumb: r.thumb ? Files.cleanSrc(r.thumb) : "", at: at,
      type: line(r.type, 20), file: line(r.file, 20), person: person, who: line(r.who, 600)
    })
  })
  return out
}

// Everything on the pages (not the trash's or the templates'), newest
// first: each thing with its page { page, pageTitle, pageIcon }; someone
// named (or a link written) more than once on a page, once (a contact card
// for them, if there's one). `skip(id)` says which pages to leave out.
function gather(index, skip) {
  var out = []
  for (var id in index.pages) {
    var e = index.pages[id]
    if (!e.collected || !e.collected.length || (skip && skip(id))) continue
    var seen = {}
    e.collected.forEach(function(r, i) {
      var key = r.kind === "person" ? "p:" + r.person : r.kind === "link" && r.url ? "l:" + r.url : ""
      if (key && seen[key]) {
        if (r.type === "contact") { seen[key].type = "contact"; seen[key].block = r.block }
        return
      }
      var o = {}
      for (var k in r) o[k] = r[k]
      o.page = id
      o.pageTitle = e.title || ""
      o.pageIcon = e.icon || ""
      o.when = r.at || e.modified || ""
      o.order = i
      if (key) seen[key] = o
      out.push(o)
    })
  }
  out.sort(function(a, b) {
    if (a.when !== b.when) return a.when < b.when ? 1 : -1
    if (a.page !== b.page) return a.page < b.page ? -1 : 1
    return a.order - b.order
  })
  return out
}

// How many of each kind: { link: 3, file: 1, ... , all: 4 }.
function counts(list) {
  var out = { all: list.length }
  KINDS.forEach(function(k) { out[k.id] = 0 })
  list.forEach(function(r) { out[r.kind]++ })
  return out
}

// Those of a kind ("" for all) with all the words in them (their name,
// what's under it, the link, the page they're on).
function filter(list, kind, query) {
  var words = String(query || "").toLowerCase().split(/\s+/).filter(function(w) { return w })
  return list.filter(function(r) {
    if (kind && r.kind !== kind) return false
    if (!words.length) return true
    var hay = (r.title + " " + r.sub + " " + r.url + " " + r.pageTitle + " " + (r.file || "") + " " + (r.who || "")).toLowerCase()
    return words.every(function(w) { return hay.indexOf(w) >= 0 })
  })
}

// What's under a thing's name in the Library: "PDF · 2.1 MB", "omarchy.org",
// "3:12"...
var FILE_LABELS = { pdf: "PDF", video: "Video", audio: "Audio", image: "Picture", doc: "Document", sheet: "Spreadsheet", slides: "Slides", archive: "Archive", code: "Code", other: "File" }
function detail(r) {
  var parts = []
  if (r.kind === "file") parts.push(FILE_LABELS[r.file] || "File")
  if (r.size && r.kind !== "email") parts.push(Files.sizeLabel(r.size))
  if (r.sub) parts.push(r.sub)
  if (r.kind === "link" && r.type === "text") parts.push("in the text")
  if (r.kind === "email" && r.type !== "message") parts.push("Email address")
  if (r.kind === "person") parts.push(r.type === "contact" ? "A contact card" : "Named")
  return parts.join("  \u00b7  ")
}

// Its icon (Theme.icons): a file's by its kind.
function iconOf(r) {
  if (r.kind === "file") return ({ pdf: "pdf", doc: "fileDoc", sheet: "fileSheet", slides: "fileSlides", archive: "fileZip", code: "fileCode", audio: "fileMusic", image: "fileImage" })[r.file] || "attach"
  if (r.kind === "link" && r.type === "bookmark") return "bookmark"
  var k = kindOf(r.kind)
  return k ? k.icon : "attach"
}
