// Board.js - a board on a page in Pages (kanban): columns of cards, each
// card a line of text, in a color (its text and its background, Pages'
// colors or your own) and maybe the page it's become ("Open as page"):
//
//   { columns: [{ id, name: "To do", color: "gray", background: "", width: 0, cards: [
//       { id, text: "Write the post", color: "", background: "yellow", page: "" }] }],
//     height: 0 }
//
// A column's color is its name's (and its dot's), its background its box's.
// A column's width is 0 while it fits the board (else what it was dragged
// to); the board's height is 0 while it's as tall as its cards (else it
// scrolls inside).
//
// It cleans what's read, moves cards and columns, and writes a board as
// Markdown (a column a heading, its cards a list). Shared with
// tests/board.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Mindmap.js" as Mindmap

var MAX_COLUMNS = 20
var MAX_CARDS = 500
var MIN_WIDTH = 160
var MAX_WIDTH = 600
var MIN_HEIGHT = 160
var MAX_HEIGHT = 2000
var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

function cleanLine(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max)
}

function cleanWidth(value) {
  var n = Number(value)
  return isFinite(n) && n >= MIN_WIDTH ? Math.round(Math.min(MAX_WIDTH, n)) : 0
}

function cleanHeight(value) {
  var n = Number(value)
  return isFinite(n) && n >= MIN_HEIGHT ? Math.round(Math.min(MAX_HEIGHT, n)) : 0
}

var counter = 0
function newId() { counter++; return "k" + Date.now().toString(36) + counter.toString(36) + Math.random().toString(36).slice(2, 6) }

function make() {
  return { columns: [
    { id: newId(), name: "To do", color: "gray", background: "", width: 0, cards: [] },
    { id: newId(), name: "Doing", color: "blue", background: "", width: 0, cards: [] },
    { id: newId(), name: "Done", color: "green", background: "", width: 0, cards: [] }
  ], height: 0 }
}

function clean(raw) {
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.columns)) return null
  var seen = {}
  function id(v) {
    var s = typeof v === "string" && /^[A-Za-z0-9_-]{1,40}$/.test(v) && !seen[v] ? v : newId()
    seen[s] = true
    return s
  }
  var total = 0
  var cols = raw.columns.slice(0, MAX_COLUMNS).filter(function(c) { return c && typeof c === "object" }).map(function(c) {
    var cards = (Array.isArray(c.cards) ? c.cards : []).filter(function(k) { return k && typeof k === "object" && total++ < MAX_CARDS }).map(function(k) {
      return { id: id(k.id), text: cleanLine(k.text, 1000), color: cleanColor(k.color), background: cleanColor(k.background), page: UUID.test(k.page) ? k.page : "" }
    })
    return { id: id(c.id), name: cleanLine(c.name, 80), color: cleanColor(c.color), background: cleanColor(c.background), width: cleanWidth(c.width), cards: cards }
  })
  if (cols.length === 0) return null
  return { columns: cols, height: cleanHeight(raw.height) }
}

function copy(b) { return JSON.parse(JSON.stringify(b)) }

// A board as a ```board block's lines (what agents read and write): each
// column a "## Name" line, its cards "- " lines under it.
function toFence(b) {
  if (!b || !b.columns) return ""
  return b.columns.map(function(c) {
    return ["## " + (c.name || "Untitled")].concat(c.cards.map(function(k) { return "- " + (k.text || "") })).join("\n")
  }).join("\n\n")
}

// A ```board block's lines as a board ({ columns }), or null: "## Name",
// "# Name", "**Name**" or "Name:" starts a column; "- text" (or "* ", "1. ",
// "- [ ] ") is a card in it.
function fromFence(text) {
  var cols = []
  String(text || "").split("\n").forEach(function(l) {
    var t = l.trim()
    if (!t) return
    var head = /^#{1,6}\s+(.+)$/.exec(t) || /^\*\*(.+)\*\*$/.exec(t) || /^([^-*\d].{0,79}):$/.exec(t)
    if (head) { cols.push({ name: head[1].trim(), cards: [] }); return }
    var card = /^(?:[-*+]|\d+[.)])\s+(?:\[[ xX]\]\s+)?(.*)$/.exec(t)
    if (card) {
      if (!cols.length) cols.push({ name: "To do", cards: [] })
      cols[cols.length - 1].cards.push({ text: card[1] })
    }
  })
  return cols.length ? clean({ columns: cols }) : null
}

// Where a card is: { col, at } (indexes), or null.
function find(b, cardId) {
  for (var c = 0; c < b.columns.length; c++)
    for (var i = 0; i < b.columns[c].cards.length; i++)
      if (b.columns[c].cards[i].id === cardId) return { col: c, at: i }
  return null
}

function card(b, cardId) { var f = find(b, cardId); return f ? b.columns[f.col].cards[f.at] : null }

// A new card in a column (at `at`, or the end): [the board, its id].
function addCard(b, colId, text, at) {
  var n = copy(b)
  var col = n.columns.filter(function(c) { return c.id === colId })[0]
  if (!col) return [n, ""]
  var k = { id: newId(), text: cleanLine(text, 1000), color: "", background: "", page: "" }
  var i = typeof at === "number" && at >= 0 && at <= col.cards.length ? at : col.cards.length
  col.cards.splice(i, 0, k)
  return [n, k.id]
}

// A card moved to column `colId`, at `at` (among the cards there, not counting it).
function moveCard(b, cardId, colId, at) {
  var n = copy(b)
  var f = find(n, cardId)
  if (!f) return n
  var k = n.columns[f.col].cards.splice(f.at, 1)[0]
  var col = n.columns.filter(function(c) { return c.id === colId })[0] || n.columns[f.col]
  var i = typeof at === "number" ? Math.max(0, Math.min(col.cards.length, at)) : col.cards.length
  col.cards.splice(i, 0, k)
  return n
}

function setCard(b, cardId, fields) {
  var n = copy(b)
  var k = card(n, cardId)
  if (!k) return n
  for (var key in fields) k[key] = fields[key]
  return clean(n) || n
}

function removeCard(b, cardId) {
  var n = copy(b)
  var f = find(n, cardId)
  if (f) n.columns[f.col].cards.splice(f.at, 1)
  return n
}

function addColumn(b, name) {
  var n = copy(b)
  if (n.columns.length >= MAX_COLUMNS) return n
  n.columns.push({ id: newId(), name: cleanLine(name, 80) || "New column", color: "", background: "", width: 0, cards: [] })
  return n
}

function setColumn(b, colId, fields) {
  var n = copy(b)
  n.columns.forEach(function(c) { if (c.id === colId) for (var k in fields) c[k] = fields[k] })
  return clean(n) || n
}

// A column taken away (its cards with it); the last one stays.
function removeColumn(b, colId) {
  var n = copy(b)
  if (n.columns.length <= 1) return n
  n.columns = n.columns.filter(function(c) { return c.id !== colId })
  return n
}

// A column moved left (-1) or right (1).
function moveColumn(b, colId, step) {
  var n = copy(b)
  var i = n.columns.map(function(c) { return c.id }).indexOf(colId)
  var j = i + step
  if (i < 0 || j < 0 || j >= n.columns.length) return n
  var c = n.columns.splice(i, 1)[0]
  n.columns.splice(j, 0, c)
  return n
}

function count(b) { var n = 0; b.columns.forEach(function(c) { n += c.cards.length }); return n }

// The board as Markdown: a column a bold line, its cards a list.
function toMarkdown(b) {
  if (!b) return ""
  return b.columns.map(function(c) {
    return "**" + (c.name || "Column") + "**" + (c.cards.length ? "\n" + c.cards.map(function(k) { return "- " + (k.text || "Untitled") }).join("\n") : "")
  }).join("\n\n")
}

// Its words (search, agents): "To do: Write the post; ..."
function text(b) {
  if (!b) return ""
  return b.columns.map(function(c) { return (c.name || "Column") + ": " + c.cards.map(function(k) { return k.text }).join("; ") }).join("\n")
}
