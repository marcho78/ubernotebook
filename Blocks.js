// Blocks.js - a page is a list of blocks: paragraphs, headings, lists,
// checklists, quotes, code, callouts, dividers and pictures, and the parts of
// planners: time slots, habits to tick off day by day, and a month's
// calendar. This file knows
// what each kind is and how they behave: what Enter and Backspace turn them
// into, how numbered lists count, which Markdown shortcuts make which kind,
// and how a page read from disk is checked before anything uses it.
//
// Shared by the editor (app/Editor.qml) and tests/blocks.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html
.import "Mindmap.js" as Mindmap
.import "Table.js" as Table
.import "Sketch.js" as Sketch
.import "Audio.js" as Audio

// Every kind of block. `rows` is how many ruled lines one line of its text
// takes (a big heading takes two, so the text below stays on the lines).
var KINDS = {
  p:       { label: "Text",        text: true,  rows: 1 },
  h1:      { label: "Title",       text: true,  rows: 2 },
  h2:      { label: "Heading",     text: true,  rows: 1 },
  h3:      { label: "Subheading",  text: true,  rows: 1 },
  bullet:  { label: "Bulleted list", text: true, rows: 1, list: true },
  number:  { label: "Numbered list", text: true, rows: 1, list: true },
  check:   { label: "Checklist",   text: true,  rows: 1, list: true },
  quote:   { label: "Quote",       text: true,  rows: 1 },
  callout: { label: "Sticky note", text: true,  rows: 1 },
  code:    { label: "Code",        text: true,  rows: 1 },
  time:    { label: "Time slot",   text: true,  rows: 1 },
  habit:   { label: "Habit",       text: true,  rows: 1 },
  divider: { label: "Divider",     text: false, rows: 1 },
  image:   { label: "Picture",     text: false, rows: 1 },
  calendar: { label: "Month calendar", text: false, rows: 1 },
  // Pages (Workspace.js) have these too: a toggle folds the blocks inside
  // it away; a page block is a page inside the page (its id is that page's),
  // a link one points to a page elsewhere; a table of contents lists the
  // page's headings.
  toggle:  { label: "Toggle list", text: true,  rows: 1 },
  page:    { label: "Page",        text: false, rows: 1 },
  link:    { label: "Link to page", text: false, rows: 1 },
  toc:     { label: "Table of contents", text: false, rows: 1 },
  // Columns side by side: a columns block holds two or more column blocks,
  // and each column holds blocks. Neither shows itself.
  columns: { label: "Columns",     text: false, rows: 1 },
  column:  { label: "Column",      text: false, rows: 1 },
  // A mind map (Pages only): its ideas as an outline (Mindmap.js).
  mindmap: { label: "Mind map",    text: false, rows: 1 },
  // A table (Pages only): rows of cells (Table.js).
  table:   { label: "Table",       text: false, rows: 1 },
  // A drawing (Pages only): pen and highlighter strokes (Sketch.js).
  sketch:  { label: "Sketch",      text: false, rows: 1 },
  // An audio note (Pages only): a recording, and what was said (Audio.js).
  audio:   { label: "Audio",       text: false, rows: 1 }
}

// Colors a block (or its background) can have in Pages: "blue" is blue text,
// "blue_background" a blue background. Docs.js has what they look like.
var COLORS = ["gray", "brown", "orange", "yellow", "green", "blue", "purple", "pink", "red"]

function isColor(value) {
  if (typeof value !== "string") return false
  var name = value.replace(/_background$/, "")
  return COLORS.indexOf(name) >= 0
}

var TONES = ["yellow", "blue", "green", "pink", "purple", "gray"]
var ALIGNS = ["left", "center", "right", "justify"]
var DIVIDERS = ["line", "dots", "wave"]
var MAX_INDENT = 6
// In Pages any block can be inside another, this deep.
var MAX_DEPTH = 12
var MAX_BLOCKS = 5000

function isKind(type) {
  return Object.prototype.hasOwnProperty.call(KINDS, type)
}

function isText(type) {
  return isKind(type) && KINDS[type].text === true
}

function isList(type) {
  return isKind(type) && KINDS[type].list === true
}

function rowsPerLine(type) {
  return isKind(type) ? KINDS[type].rows : 1
}

// Blocks that can be indented (lists, and text under them).
function canIndent(type) {
  return isList(type) || type === "p"
}

var counter = 0

// A short id, unique within a page (`taken` lists the ids in use).
function newUid(taken) {
  for (var tries = 0; tries < 50; tries++) {
    counter = (counter + 1) % 1296
    var uid = "b" + Math.floor(Math.random() * 0x7fffffff).toString(36) + counter.toString(36)
    if (!taken || !taken[uid]) return uid
  }
  return "b" + Date.now().toString(36) + Math.floor(Math.random() * 1e9).toString(36)
}

// A new block of the given kind, with its kind's defaults (`options` as for clean).
function make(type, props, taken, options) {
  var block = { uid: newUid(taken), type: isKind(type) ? type : "p" }
  if (isText(block.type)) block.html = ""
  block.indent = 0
  if (block.type === "check") block.checked = false
  if (block.type === "callout") block.tone = "yellow"
  if (block.type === "divider") block.style = "line"
  if (block.type === "image") { block.src = ""; block.width = 0.6; block.align = "center" }
  if (block.type === "time") block.label = ""
  if (block.type === "habit") block.days = NO_DAYS
  if (block.type === "calendar") { block.month = thisMonth(); block.marks = "" }
  if (props) for (var key in props) if (key !== "uid" && key !== "type") block[key] = props[key]
  return clean(block, options) || make("p")
}

function copy(block) {
  var out = {}
  for (var key in block) out[key] = block[key]
  return out
}

// ---- checking what's read from disk ----------------------------------------------

function cleanNumber(value, min, max, fallback) {
  var n = Number(value)
  if (typeof value !== "number" || !isFinite(n)) return fallback
  return Math.min(max, Math.max(min, n))
}

// A line of plain text, as short as it's allowed to be: a time slot's time,
// or the faint hint in an empty block of a template.
function cleanLine(value, max) {
  if (typeof value !== "string") return ""
  return value.replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max)
}

// The month a calendar shows, "2026-09".
function isMonth(value) {
  return typeof value === "string" && /^\d{4}-(0[1-9]|1[0-2])$/.test(value)
}

function thisMonth() {
  var d = new Date()
  return d.getFullYear() + "-" + (d.getMonth() < 9 ? "0" : "") + (d.getMonth() + 1)
}

// Days marked on a calendar, "3,14,21": each 1 to 31, once, in order.
function cleanMarks(value) {
  var seen = {}
  var out = []
  String(typeof value === "string" ? value : "").split(",").forEach(function(part) {
    var n = /^\s*\d{1,2}\s*$/.test(part) ? Number(part) : 0
    if (n >= 1 && n <= 31 && !seen[n]) { seen[n] = true; out.push(n) }
  })
  return out.sort(function(a, b) { return a - b }).join(",")
}

// A habit's week, Monday first: "1" for a day it was done.
var NO_DAYS = "0000000"

function cleanDays(value) {
  return typeof value === "string" && /^[01]{7}$/.test(value) ? value : NO_DAYS
}

var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

// A block as it may be used, or null. Only known kinds and known properties
// come through, each of the right type and size. `options.nest`: any block
// can be inside another (in Pages; in a notebook only lists indent).
function clean(raw, options) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var type = isKind(raw.type) ? raw.type : null
  if (!type) return null
  var nest = !!(options && options.nest)
  var uid = typeof raw.uid === "string" && /^[A-Za-z0-9_-]{1,40}$/.test(raw.uid) ? raw.uid : newUid()
  var block = { uid: uid, type: type }
  block.indent = nest ? Math.round(cleanNumber(raw.indent, 0, MAX_DEPTH, 0))
    : canIndent(type) ? Math.round(cleanNumber(raw.indent, 0, MAX_INDENT, 0)) : 0
  if (isText(type)) {
    // Only the formatting Omanote itself writes: no pictures, stylesheets or
    // odd links inside the text, whatever a page file says.
    block.html = typeof raw.html === "string" && raw.html.length <= 200000 ? Html.sanitize(raw.html, true) : ""
    if (ALIGNS.indexOf(raw.align) > 0) block.align = raw.align
    var hint = cleanLine(raw.hint, 60)
    if (hint) block.hint = hint
  }
  if (type === "check") block.checked = raw.checked === true
  if (type === "callout") {
    block.tone = TONES.indexOf(raw.tone) >= 0 ? raw.tone : "yellow"
    if (typeof raw.icon === "string" && raw.icon.length > 0 && raw.icon.length <= 16 && !/[<>&\s]/.test(raw.icon)) block.icon = raw.icon
  }
  if (isColor(raw.color)) block.color = raw.color
  if ((type === "h1" || type === "h2" || type === "h3") && raw.toggle === true) block.toggle = true
  if ((type === "toggle" || block.toggle) && raw.collapsed === true) block.collapsed = true
  if (type === "code" && typeof raw.lang === "string" && /^[A-Za-z0-9+#._ -]{1,24}$/.test(raw.lang)) block.lang = raw.lang
  if (type === "link") {
    if (typeof raw.target !== "string" || !UUID.test(raw.target)) return null
    block.target = raw.target
  }
  // A column's share of the width (0: an equal share).
  if (type === "column") {
    var share = cleanNumber(raw.width, 0.05, 1, 0)
    if (share > 0) block.width = share
  }
  if (type === "divider") block.style = DIVIDERS.indexOf(raw.style) >= 0 ? raw.style : "line"
  if (type === "image") {
    block.src = cleanAsset(raw.src)
    block.width = cleanNumber(raw.width, 0.15, 1, 0.6)
    block.align = ["left", "center", "right"].indexOf(raw.align) >= 0 ? raw.align : "center"
    if (typeof raw.ratio === "number" && isFinite(raw.ratio) && raw.ratio > 0.02 && raw.ratio < 50) block.ratio = raw.ratio
  }
  if (type === "time") block.label = cleanLine(raw.label, 12)
  if (type === "habit") block.days = cleanDays(raw.days)
  if (type === "calendar") {
    block.month = isMonth(raw.month) ? raw.month : thisMonth()
    block.marks = cleanMarks(raw.marks)
  }
  if (type === "mindmap") {
    // Only in Pages, and only with something in it.
    var outline = nest && typeof raw.outline === "string" && raw.outline.length <= 100000 ? Mindmap.clean(raw.outline) : ""
    if (!outline) return null
    block.outline = outline
    block.folds = Mindmap.cleanFolds(raw.folds, Mindmap.count(outline))
  }
  if (type === "table") {
    var table = nest ? Table.clean(raw.table) : null
    if (!table) return null
    block.table = table
  }
  if (type === "sketch") {
    // Only in Pages; a new one is empty.
    if (!nest) return null
    block.sketch = Sketch.clean(raw.sketch) || Sketch.make()
  }
  if (type === "audio") {
    // Only in Pages; a new one has no recording yet.
    if (!nest) return null
    block.audio = Audio.clean(raw.audio) || Audio.make()
  }
  return block
}

// A picture lives in the notebook's own assets folder: "assets/<name>".
function cleanAsset(src) {
  var s = typeof src === "string" ? src : ""
  return /^assets\/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(s) && s.indexOf("..") < 0 ? s : ""
}

// A page's blocks as they may be used: at least one, each clean, ids unique.
function cleanList(raw, options) {
  var out = []
  var seen = {}
  if (Array.isArray(raw)) {
    for (var i = 0; i < raw.length && out.length < MAX_BLOCKS; i++) {
      var block = clean(raw[i], options)
      if (!block) continue
      if (block.type === "image" && !block.src) continue
      if (seen[block.uid]) block.uid = newUid(seen)
      seen[block.uid] = true
      out.push(block)
    }
  }
  if (out.length === 0) out.push(make("p", null, seen))
  return out
}

// ---- numbering ------------------------------------------------------------------

var ROMAN = [[1000, "m"], [900, "cm"], [500, "d"], [400, "cd"], [100, "c"], [90, "xc"], [50, "l"], [40, "xl"], [10, "x"], [9, "ix"], [5, "v"], [4, "iv"], [1, "i"]]

function roman(n) {
  var out = ""
  for (var i = 0; i < ROMAN.length; i++) {
    while (n >= ROMAN[i][0]) { out += ROMAN[i][1]; n -= ROMAN[i][0] }
  }
  return out
}

function letters(n) {
  var out = ""
  while (n > 0) {
    n -= 1
    out = String.fromCharCode(97 + (n % 26)) + out
    n = Math.floor(n / 26)
  }
  return out
}

// 1. / a. / i. by how deep the item is, like a written outline.
function numberLabel(n, indent) {
  var level = indent % 3
  if (level === 1) return letters(n) + "."
  if (level === 2) return roman(n) + "."
  return n + "."
}

// uid -> the number shown before each numbered item. A list counts on
// through deeper items under it, and starts again after anything else at its
// own depth or shallower. 1, a, i go with how deep an item is; in Pages
// (`doc`), where any block can hold others (and columns hold everything),
// with how many list items it's inside.
function numbering(blocks, doc) {
  var labels = {}
  var counts = []
  var kinds = []
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    var level = b.indent || 0
    kinds.length = Math.min(kinds.length, level)
    counts.length = Math.min(counts.length, b.type === "number" ? level + 1 : level)
    if (b.type === "number") {
      counts[level] = (counts[level] || 0) + 1
      var style = level
      if (doc) {
        style = 0
        for (var k = 0; k < level; k++) if (kinds[k] === "bullet" || kinds[k] === "number") style++
      }
      labels[b.uid] = numberLabel(counts[level], style)
    } else if (isList(b.type) || b.type === "p") {
      counts.length = Math.min(counts.length, level)
    } else {
      counts.length = 0
    }
    kinds[level] = b.type
  }
  return labels
}

// ---- typing -----------------------------------------------------------------------

// What typing a prefix and then a space at the start of a text block turns it
// into, Markdown style: "- " a bulleted list, "1. " numbered, "[] " a
// checklist, "# " a title, "> " a quote, "``` " code. null for anything else.
// In Pages (`doc`), as in Notion, "> " is a toggle, and times are just text.
function shortcut(prefix, doc) {
  var p = String(prefix || "")
  if (doc && p === ">") return { type: "toggle" }
  if (doc && /^\d{1,2}:\d{2}$/.test(p)) return null
  if (/^[-*+\u2022]$/.test(p)) return { type: "bullet" }
  if (/^\d{1,3}[.)]$/.test(p)) return { type: "number" }
  if (/^\[ ?\]$/.test(p)) return { type: "check", checked: false }
  if (/^\[[xX]\]$/.test(p)) return { type: "check", checked: true }
  if (p === "#") return { type: "h1" }
  if (p === "##") return { type: "h2" }
  if (p === "###") return { type: "h3" }
  if (p === ">" || p === "\"") return { type: "quote" }
  if (p === "```") return { type: "code" }
  if (p === "!!") return { type: "callout" }
  // "9:30 " starts a time slot at half past nine.
  var t = parseTime(p)
  if (t >= 0) return { type: "time", label: formatTime(t) }
  return null
}

// Typing just "---" (or "***", "___") and Enter makes a divider.
function isDividerText(text) {
  return /^\s*(-{3,}|\*{3,}|_{3,})\s*$/.test(String(text || ""))
}

// The kind the new block gets when Enter splits a block of this kind: lists,
// quotes, notes and habits carry on, a heading is followed by text (unless it
// was split in the middle, then both halves stay headings).
function kindAfterEnter(type, atEnd) {
  if (type === "h1" || type === "h2" || type === "h3") return atEnd ? "p" : type
  if (isList(type) || type === "quote" || type === "callout" || type === "habit" || type === "toggle") return type
  return "p"
}

// ---- time slots -----------------------------------------------------------------

function pad2(n) { return (n < 10 ? "0" : "") + n }

// "9:30" or "09:30" -> minutes after midnight; -1 when it isn't a time.
function parseTime(label) {
  var m = /^([01]?\d|2[0-3]):([0-5]\d)$/.exec(String(label || ""))
  return m ? Number(m[1]) * 60 + Number(m[2]) : -1
}

function formatTime(minutes) {
  var m = ((minutes % 1440) + 1440) % 1440
  return pad2(Math.floor(m / 60)) + ":" + pad2(m % 60)
}

// The time of the slot after one: as far on as it is from the slot before it
// (half an hour, two hours), else an hour. "" when the label isn't a time.
function nextLabel(label, prevLabel) {
  var t = parseTime(label)
  if (t < 0) return ""
  var p = parseTime(prevLabel)
  var step = p >= 0 && t - p > 0 && t - p <= 180 ? t - p : 60
  return formatTime(t + step)
}

// ---- calendars ------------------------------------------------------------------

// A month's calendar laid out Monday first: { offset (empty days before the
// 1st), days, weeks }.
function monthLayout(month) {
  var m = isMonth(month) ? month : thisMonth()
  var year = Number(m.slice(0, 4))
  var index = Number(m.slice(5, 7)) - 1
  var offset = (new Date(year, index, 1).getDay() + 6) % 7
  var days = new Date(year, index + 1, 0).getDate()
  return { offset: offset, days: days, weeks: Math.ceil((offset + days) / 7) }
}

// The month `delta` months from this one.
function shiftMonth(month, delta) {
  var m = isMonth(month) ? month : thisMonth()
  var d = new Date(Number(m.slice(0, 4)), Number(m.slice(5, 7)) - 1 + delta, 1)
  return d.getFullYear() + "-" + pad2(d.getMonth() + 1)
}

// A day marked, or unmarked.
function toggleMark(marks, day) {
  var list = cleanMarks(marks).split(",").filter(function(x) { return x !== "" }).map(Number)
  var at = list.indexOf(day)
  if (at >= 0) list.splice(at, 1)
  else if (day >= 1 && day <= 31) list.push(day)
  return cleanMarks(list.join(","))
}

function hasMark(marks, day) {
  return ("," + marks + ",").indexOf("," + day + ",") >= 0
}

// A habit done, or not, on one day of the week (0 is Monday).
function toggleDay(days, i) {
  var d = cleanDays(days)
  if (i < 0 || i > 6) return d
  return d.slice(0, i) + (d.charAt(i) === "1" ? "0" : "1") + d.slice(i + 1)
}

// What Backspace at the very start of a block does: "convert" it to text,
// "outdent" it, or "merge" it into the block above.
function backspaceAction(block) {
  if (!block) return "merge"
  if (block.type !== "p") return "convert"
  if ((block.indent || 0) > 0) return "outdent"
  return "merge"
}

// ---- moving blocks ------------------------------------------------------------------

// Where a run of blocks [from, to] goes when moved by `delta` (±1): the
// index range it lands on, or null at the edge.
function moveRange(count, from, to, delta) {
  if (delta < 0 && from <= 0) return null
  if (delta > 0 && to >= count - 1) return null
  return { from: from + delta, to: to + delta }
}

// ---- text -----------------------------------------------------------------------

function plainText(blocks) {
  var lines = []
  for (var i = 0; i < blocks.length; i++) {
    if (isText(blocks[i].type)) lines.push(Html.plainText(blocks[i].html || ""))
  }
  return lines.join("\n")
}

// The page's title when none was typed: its first line of text.
function firstLine(blocks, max) {
  for (var i = 0; i < blocks.length; i++) {
    if (!isText(blocks[i].type)) continue
    var text = Html.plainText(blocks[i].html || "").replace(/\s+/g, " ").trim()
    if (text) return text.length > (max || 60) ? text.slice(0, (max || 60) - 1).trim() + "\u2026" : text
  }
  return ""
}

function wordCount(blocks) {
  var text = plainText(blocks).trim()
  if (!text) return 0
  return text.split(/\s+/).length
}

function checklistProgress(blocks) {
  var total = 0
  var done = 0
  for (var i = 0; i < blocks.length; i++) {
    if (blocks[i].type !== "check") continue
    total++
    if (blocks[i].checked) done++
  }
  return { total: total, done: done }
}

// Is this page empty: one block, no text?
function isBlank(blocks) {
  if (!blocks || blocks.length === 0) return true
  if (blocks.length > 1) return false
  var b = blocks[0]
  return isText(b.type) && Html.plainText(b.html || "").trim() === ""
}
