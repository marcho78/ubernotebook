// Table.js - tables in Pages: rows of cells, each cell a little rich text
// (bold, italic, links, colors, as a block's text is), the first row a header
// row unless it's switched off, and the columns' widths as shares of the
// table's, and the cells' colors (a text color and a background each, one
// of Pages' colors or one of your own, "#ff8800"; left out when none has
// any). A table block keeps it as `table`:
//
//   { rows: [["Name", "Qty"], ["Apples", "3"]], header: true, widths: [0.6, 0.4],
//     colors: [["", ""], ["red|", "|#fff3c4"]] }
//
// It cleans what's read, changes tables (rows and columns in and out, a
// cell's text), reads tables pasted from a spreadsheet (tab-separated), and
// writes them as Markdown. Shared with tests/table.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html
.import "Mindmap.js" as Mindmap

var MAX_ROWS = 500
var MAX_COLS = 30
var MAX_CELL = 20000
var MIN_SHARE = 0.03

function cleanCell(value) {
  return typeof value === "string" && value.length <= MAX_CELL ? Html.sanitize(value, true) : ""
}

// A table as it may be kept, or null when there's nothing in it: every row
// as long as the longest, cells cleaned, widths that add up to 1.
function clean(raw) {
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.rows)) return null
  var rows = raw.rows.filter(Array.isArray).slice(0, MAX_ROWS)
  var cols = 0
  rows.forEach(function(r) { cols = Math.max(cols, Math.min(MAX_COLS, r.length)) })
  if (rows.length === 0 || cols === 0) return null
  var out = {
    rows: rows.map(function(r) {
      var cells = []
      for (var c = 0; c < cols; c++) cells.push(cleanCell(r[c]))
      return cells
    }),
    header: raw.header !== false
  }
  out.widths = cleanWidths(raw.widths, cols)
  var colors = cleanColors(raw.colors, out.rows.length, cols)
  if (colors) out.colors = colors
  return out
}

// ---- colors --------------------------------------------------------------------------------

// A cell's colors as kept: "text|background", each one of Pages' colors
// ("red") or a hex ("#ff8800"), or "" for none.
function cleanPair(value) {
  if (typeof value !== "string" || value.length > 40) return ""
  var parts = value.split("|")
  var text = Mindmap.cleanColor(parts[0])
  var back = Mindmap.cleanColor(parts[1])
  return text || back ? text + "|" + back : ""
}

// The cells' colors, as many as there are cells, or null when none has any.
function cleanColors(raw, rows, cols) {
  if (!Array.isArray(raw)) return null
  var any = false
  var out = []
  for (var r = 0; r < rows; r++) {
    var src = Array.isArray(raw[r]) ? raw[r] : []
    var row = []
    for (var c = 0; c < cols; c++) {
      var v = cleanPair(src[c])
      if (v) any = true
      row.push(v)
    }
    out.push(row)
  }
  return any ? out : null
}

// A cell's colors: { color, background } ("" where it has none).
function colorOf(t, r, c) {
  var v = t && t.colors && t.colors[r] ? t.colors[r][c] || "" : ""
  var parts = v.split("|")
  return { color: parts[0] || "", background: parts[1] || "" }
}

// The cells of a row, of a column, or one cell: [[r, c]...].
function cellsIn(t, what, r, c) {
  var out = []
  if (what === "row") for (var k = 0; k < cols(t); k++) out.push([r, k])
  else if (what === "col") for (var i = 0; i < t.rows.length; i++) out.push([i, c])
  else out.push([r, c])
  return out
}

// Those cells' colors, if they all have the same: { color, background }.
function colorsOf(t, cells) {
  var first = null
  var same = true
  cells.forEach(function(rc) {
    var x = colorOf(t, rc[0], rc[1])
    if (!first) first = x
    else if (x.color !== first.color || x.background !== first.background) same = false
  })
  return first && same ? first : { color: "", background: "" }
}

// Those cells in a color (kind "color" or "background"; "" takes it off).
function setColors(t, cells, kind, value) {
  var x = copy(t)
  var v = Mindmap.cleanColor(value)
  var n = cols(x)
  if (!x.colors) x.colors = x.rows.map(function() { var row = []; for (var k = 0; k < n; k++) row.push(""); return row })
  cells.forEach(function(rc) {
    var r = rc[0], c = rc[1]
    if (r < 0 || r >= x.rows.length || c < 0 || c >= n) return
    var now = colorOf(x, r, c)
    now[kind === "background" ? "background" : "color"] = v
    x.colors[r][c] = now.color || now.background ? now.color + "|" + now.background : ""
  })
  var kept = cleanColors(x.colors, x.rows.length, n)
  if (kept) x.colors = kept
  else delete x.colors
  return x
}

function emptyRow(n) { var row = []; for (var k = 0; k < n; k++) row.push(""); return row }

function cleanWidths(widths, cols) {
  var w = []
  for (var c = 0; c < cols; c++) {
    var n = Array.isArray(widths) ? Number(widths[c]) : NaN
    w.push(isFinite(n) && n > 0 ? Math.max(MIN_SHARE, n) : 1 / cols)
  }
  var sum = w.reduce(function(a, b) { return a + b }, 0)
  return w.map(function(x) { return Math.round(x / sum * 10000) / 10000 })
}

// A new table: `cols` columns, `rows` rows (the first the header).
function make(cols, rows) {
  var c = Math.max(1, Math.min(MAX_COLS, cols || 3))
  var r = Math.max(1, Math.min(MAX_ROWS, rows || 3))
  var list = []
  for (var i = 0; i < r; i++) {
    var row = []
    for (var k = 0; k < c; k++) row.push("")
    list.push(row)
  }
  return clean({ rows: list, header: true })
}

function copy(t) { return JSON.parse(JSON.stringify(t)) }
function cols(t) { return t && t.rows.length ? t.rows[0].length : 0 }

// ---- changing a table ----------------------------------------------------------------------

function insertRow(t, at) {
  var x = copy(t)
  if (x.rows.length >= MAX_ROWS) return x
  var row = []
  for (var k = 0; k < cols(x); k++) row.push("")
  x.rows.splice(Math.max(0, Math.min(x.rows.length, at)), 0, row)
  if (x.colors) x.colors.splice(Math.max(0, Math.min(x.colors.length, at)), 0, emptyRow(cols(x)))
  return x
}

function deleteRow(t, at) {
  var x = copy(t)
  if (x.rows.length <= 1 || at < 0 || at >= x.rows.length) return x
  x.rows.splice(at, 1)
  if (x.colors) x.colors.splice(at, 1)
  return x
}

// A column put in at `at`, taking its share from the others.
function insertCol(t, at) {
  var x = copy(t)
  var n = cols(x)
  if (n >= MAX_COLS) return x
  var i = Math.max(0, Math.min(n, at))
  x.rows.forEach(function(r) { r.splice(i, 0, "") })
  if (x.colors) x.colors.forEach(function(r) { r.splice(i, 0, "") })
  var share = 1 / (n + 1)
  x.widths = x.widths.map(function(w) { return w * (1 - share) })
  x.widths.splice(i, 0, share)
  x.widths = cleanWidths(x.widths, n + 1)
  return x
}

function deleteCol(t, at) {
  var x = copy(t)
  var n = cols(x)
  if (n <= 1 || at < 0 || at >= n) return x
  x.rows.forEach(function(r) { r.splice(at, 1) })
  if (x.colors) x.colors.forEach(function(r) { r.splice(at, 1) })
  x.widths.splice(at, 1)
  x.widths = cleanWidths(x.widths, n - 1)
  return x
}

function setCell(t, row, col, html) {
  var x = copy(t)
  if (row < 0 || row >= x.rows.length || col < 0 || col >= cols(x)) return x
  x.rows[row][col] = cleanCell(html)
  return x
}

// A row moved up (dir -1) or down (dir 1); a column left or right with its width.
function moveRow(t, at, dir) {
  var x = copy(t)
  var to = at + dir
  if (at < 0 || at >= x.rows.length || to < 0 || to >= x.rows.length) return x
  var r = x.rows.splice(at, 1)[0]
  x.rows.splice(to, 0, r)
  if (x.colors) x.colors.splice(to, 0, x.colors.splice(at, 1)[0])
  return x
}

function moveCol(t, at, dir) {
  var x = copy(t)
  var to = at + dir
  if (at < 0 || at >= cols(x) || to < 0 || to >= cols(x)) return x
  x.rows.forEach(function(r) { var c = r.splice(at, 1)[0]; r.splice(to, 0, c) })
  if (x.colors) x.colors.forEach(function(r) { var c = r.splice(at, 1)[0]; r.splice(to, 0, c) })
  var w = x.widths.splice(at, 1)[0]
  x.widths.splice(to, 0, w)
  return x
}

// Cells (rows of cell text, as fromTSV gives) put in from (row, col) on,
// the table growing to take them.
function pasteInto(t, row, col, cells) {
  var x = copy(t)
  if (!Array.isArray(cells)) return x
  var wide = 0
  cells.forEach(function(r) { wide = Math.max(wide, r.length) })
  while (cols(x) < Math.min(MAX_COLS, col + wide)) x = insertCol(x, cols(x))
  while (x.rows.length < Math.min(MAX_ROWS, row + cells.length)) x = insertRow(x, x.rows.length)
  cells.forEach(function(r, i) {
    r.forEach(function(c, k) {
      if (row + i < x.rows.length && col + k < cols(x)) x.rows[row + i][col + k] = cleanCell(c)
    })
  })
  return x
}

// Column `col` widened by `delta` (a share), the one after it narrowed as much.
function resize(t, col, delta) {
  var x = copy(t)
  if (col < 0 || col + 1 >= cols(x)) return x
  var a = x.widths[col], b = x.widths[col + 1]
  var d = Math.max(MIN_SHARE - a, Math.min(b - MIN_SHARE, delta))
  x.widths[col] = a + d
  x.widths[col + 1] = b - d
  x.widths = cleanWidths(x.widths, cols(x))
  return x
}

// ---- in and out ----------------------------------------------------------------------------

// Text pasted from a spreadsheet (a row a line, cells between tabs): its
// rows of plain text, or null when it isn't one (one column, or one line).
function fromTSV(text) {
  var lines = String(text || "").replace(/\r\n?/g, "\n").replace(/\n+$/, "").split("\n")
  if (lines.length < 1 || lines.join("").indexOf("\t") < 0) return null
  var rows = lines.map(function(l) { return l.split("\t") })
  var width = 0
  rows.forEach(function(r) { width = Math.max(width, r.length) })
  if (width < 2 || (rows.length < 2 && width < 3)) return null
  return rows.slice(0, MAX_ROWS).map(function(r) { return r.slice(0, MAX_COLS).map(function(c) { return Html.escapeText(c.trim()) }) })
}

// Text pasted into a cell that's cells (it has a tab): its rows, else null.
function cellsOf(text) {
  var t = String(text || "").replace(/\r\n?/g, "\n").replace(/\n+$/, "")
  if (t.indexOf("\t") < 0) return null
  return t.split("\n").slice(0, MAX_ROWS).map(function(l) { return l.split("\t").slice(0, MAX_COLS).map(function(c) { return Html.escapeText(c.trim()) }) })
}

// Its words, a row a line (for search).
function text(t) {
  if (!t) return ""
  return t.rows.map(function(r) { return r.map(function(c) { return Html.plainText(c).replace(/\s+/g, " ").trim() }).join(" | ") }).join("\n")
}

// As a Markdown table, each cell's text by `inline(html)` (Markdown.inline,
// which escapes the pipes in it). One with no header row gets an empty one:
// Markdown's tables have one.
function toMarkdown(t, inline) {
  if (!t || !t.rows.length) return ""
  var f = typeof inline === "function" ? inline : function(h) { return Html.plainText(h).replace(/[\\|]/g, "\\$&") }
  // A line break (Markdown's "\" or two spaces at the end of a line) is a <br> in a table.
  function cell(h) { return String(f(h || "")).replace(/(\\| {2,})?\n/g, "<br>").trim() }
  function line(cells) { return "| " + cells.join(" | ") + " |" }
  var n = cols(t)
  var head = t.header ? t.rows[0].map(cell) : new Array(n + 1).join("x").split("").map(function() { return " " })
  var body = (t.header ? t.rows.slice(1) : t.rows).map(function(r) { return line(r.map(cell)) })
  var rule = "|" + new Array(n + 1).join(" --- |")
  return [line(head), rule].concat(body).join("\n")
}
