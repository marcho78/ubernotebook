// Sketch.js - drawings in Pages. A sketch block keeps its strokes in its own
// coordinates, WIDTH wide and as tall as the sketch is (so a drawing keeps its
// shape on any page width, in a column too), each a pen's or a
// highlighter's, in the page's ink (""), one of Pages' colors ("blue", which
// follow a light or dark theme) or one of your own ("#ff8800"); and a
// background: plain, dots or a grid. A block keeps it as `sketch`:
//
//   { height: 420, background: "dots",
//     strokes: [{ tool: "pen", color: "blue", width: 4, points: [x, y, x, y...] }] }
//
// It cleans what's read, finds the strokes the eraser touches, and writes a
// sketch as SVG (for exports and the Markdown mirror). Shared with
// tests/sketch.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Docs.js" as Docs
.import "Mindmap.js" as Mindmap

var WIDTH = 1000
var HEIGHT = 420
var MIN_HEIGHT = 120
var MAX_HEIGHT = 3000
var MAX_STROKES = 3000
var MAX_POINTS = 20000
var MAX_TOTAL = 400000
var BACKGROUNDS = ["plain", "dots", "grid"]
// The pen's nibs (in the sketch's own units); a highlighter's is six times as wide.
var NIBS = [2.5, 4, 7]
var MARKER = 6
// The page's ink, as SVG has it (a light page's, a dark one's).
var INK = ["#1f2430", "#e6e3dc"]

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function round(v) { return Math.round(v * 10) / 10 }

// A stroke's color as kept: "" (the page's ink), one of Pages' colors, or a hex.
function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

// A new, empty sketch.
function make(background) {
  return { height: HEIGHT, background: BACKGROUNDS.indexOf(background) >= 0 ? background : "dots", strokes: [] }
}

// A sketch as it may be kept, or null when it isn't one.
function clean(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var h = typeof raw.height === "number" && isFinite(raw.height) ? Math.round(clamp(raw.height, MIN_HEIGHT, MAX_HEIGHT)) : HEIGHT
  var out = { height: h, background: BACKGROUNDS.indexOf(raw.background) >= 0 ? raw.background : "dots", strokes: [] }
  var list = Array.isArray(raw.strokes) ? raw.strokes : []
  var total = 0
  for (var i = 0; i < list.length && out.strokes.length < MAX_STROKES && total < MAX_TOTAL; i++) {
    var s = cleanStroke(list[i], h)
    if (!s) continue
    total += s.points.length
    out.strokes.push(s)
  }
  return out
}

function cleanStroke(s, height) {
  if (!s || typeof s !== "object" || !Array.isArray(s.points)) return null
  // (A color it can't read is the page's ink.)
  var color = cleanColor(s.color)
  var points = []
  for (var j = 0; j + 1 < s.points.length && j < MAX_POINTS; j += 2) {
    var x = s.points[j]
    var y = s.points[j + 1]
    if (typeof x !== "number" || typeof y !== "number" || !isFinite(x) || !isFinite(y)) return null
    points.push(round(clamp(x, -20, WIDTH + 20)), round(clamp(y, -20, height + 20)))
  }
  if (points.length < 2) return null
  var marker = s.tool === "marker"
  var w = typeof s.width === "number" && isFinite(s.width) ? s.width : (marker ? NIBS[1] * MARKER : NIBS[1])
  return { tool: marker ? "marker" : "pen", color: color, width: round(clamp(w, 0.5, 80)), points: points }
}

function copy(sketch) { return JSON.parse(JSON.stringify(sketch)) }

// A stroke drawn: [x, y...] in the sketch's units, with a tool, a color and a nib.
function stroke(tool, color, nib, points) {
  var marker = tool === "marker"
  return { tool: marker ? "marker" : "pen", color: cleanColor(color), width: round(marker ? nib * MARKER : nib), points: points.map(round) }
}

function withStroke(sketch, s) {
  var x = copy(sketch)
  if (x.strokes.length >= MAX_STROKES) x.strokes.shift()
  x.strokes.push(s)
  return x
}

// ---- the eraser -----------------------------------------------------------------------------

// Whether a stroke passes within `reach` of (x, y).
function near(stroke, x, y, reach) {
  var p = stroke.points
  var r = reach + stroke.width / 2
  for (var i = 0; i + 1 < p.length; i += 2) {
    var ax = p[i], ay = p[i + 1]
    var bx = i + 3 < p.length ? p[i + 2] : ax
    var by = i + 3 < p.length ? p[i + 3] : ay
    var dx = bx - ax, dy = by - ay
    var len = dx * dx + dy * dy
    var t = len > 0 ? clamp(((x - ax) * dx + (y - ay) * dy) / len, 0, 1) : 0
    var cx = ax + t * dx - x
    var cy = ay + t * dy - y
    if (cx * cx + cy * cy <= r * r) return true
  }
  return false
}

// The sketch without the strokes the eraser at (x, y) touches: { sketch, removed }.
function erase(sketch, x, y, reach) {
  var keep = []
  var removed = 0
  sketch.strokes.forEach(function(s) {
    if (near(s, x, y, reach)) removed++
    else keep.push(s)
  })
  if (!removed) return { sketch: sketch, removed: 0 }
  var out = copy(sketch)
  out.strokes = keep
  return { sketch: out, removed: removed }
}

// The same, all along the eraser's way from (x0, y0) to (x1, y1) (a fast
// swipe is reported a few points apart; every stroke it crosses goes).
function eraseAlong(sketch, x0, y0, x1, y1, reach) {
  var dx = x1 - x0, dy = y1 - y0
  var steps = Math.max(1, Math.ceil(Math.sqrt(dx * dx + dy * dy) / Math.max(1, reach / 2)))
  var s = sketch
  var removed = 0
  for (var i = 0; i <= steps; i++) {
    var r = erase(s, x0 + dx * i / steps, y0 + dy * i / steps, reach)
    s = r.sketch
    removed += r.removed
  }
  return { sketch: s, removed: removed }
}

// ---- drawing it -----------------------------------------------------------------------------

// A stroke's points as a smooth path: straight to the first midpoint, then
// curves through each point to the next midpoint.
function pathOf(points) {
  if (!points || points.length < 2) return ""
  var d = "M " + points[0] + " " + points[1]
  if (points.length === 2) return d + " L " + (points[0] + 0.01) + " " + points[1]
  for (var i = 2; i + 3 < points.length; i += 2) {
    var mx = round((points[i] + points[i + 2]) / 2)
    var my = round((points[i + 1] + points[i + 3]) / 2)
    d += " Q " + points[i] + " " + points[i + 1] + " " + mx + " " + my
  }
  var n = points.length
  return d + " L " + points[n - 2] + " " + points[n - 1]
}

// A color as it's drawn: the page's ink (`ink`), one of Pages' colors in its
// light or dark shade, or one of your own as it is.
function colorHex(color, dark, ink) {
  if (!color) return ink || INK[dark ? 1 : 0]
  var e = Docs.colorEntry(color)
  return e ? e.text[dark ? 1 : 0] : color
}

// A highlighter's colors, brighter than the text's (as [light page, dark page]).
var MARKERS = {
  yellow: ["#ffdf3d", "#c9b23a"], orange: ["#ffae52", "#c9813f"], green: ["#7fe09a", "#4aa267"],
  blue: ["#86cbff", "#4d8dbd"], purple: ["#cfa8ff", "#8f6bc2"], pink: ["#ff9fcd", "#c06491"],
  red: ["#ff958a", "#c45a50"], gray: ["#c4c4c4", "#7d7d7d"], brown: ["#d8b08a", "#9b7552"]
}
var MARKER_ALPHA = [0.5, 0.42]

// A highlighter's color as it's drawn (`ink`: the page's text color, for "").
function markerHex(color, dark, ink) {
  if (!color) return ink || INK[dark ? 1 : 0]
  var m = MARKERS[color]
  return m ? m[dark ? 1 : 0] : colorHex(color, dark, ink)
}

// A stroke's color as it's drawn: a pen's, or a highlighter's (see-through).
function strokeHex(stroke, dark, ink) {
  return stroke.tool === "marker" ? markerHex(stroke.color, dark, ink) : colorHex(stroke.color, dark, ink)
}

// The background's lines or dots, as one path (`step` apart).
function backgroundPath(kind, height, step) {
  var s = step || 25
  var d = ""
  if (kind === "grid") {
    for (var x = s; x < WIDTH; x += s) d += "M " + x + " 0 L " + x + " " + height + " "
    for (var y = s; y < height; y += s) d += "M 0 " + y + " L " + WIDTH + " " + y + " "
  } else if (kind === "dots") {
    for (var dy = s; dy < height; dy += s) for (var dx = s; dx < WIDTH; dx += s) d += "M " + dx + " " + dy + " l 0.01 0 "
  }
  return d.trim()
}

function escapeAttr(t) { return String(t).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;") }

// The sketch as an SVG file (on a light page, its background left out).
function toSvg(sketch, title) {
  var s = clean(sketch) || make()
  var out = ['<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ' + WIDTH + " " + s.height + '" width="' + WIDTH + '" height="' + s.height + '">']
  if (title) out.push("  <title>" + escapeAttr(title) + "</title>")
  s.strokes.forEach(function(k) {
    var marker = k.tool === "marker"
    out.push('  <path d="' + pathOf(k.points) + '" fill="none" stroke="' + escapeAttr(strokeHex(k, false)) + '" stroke-width="' + k.width
      + '" stroke-linecap="' + (marker ? "square" : "round") + '" stroke-linejoin="round"' + (marker ? ' stroke-opacity="' + (k.color ? MARKER_ALPHA[0] : 0.25) + '"' : "") + "/>")
  })
  out.push("</svg>")
  return out.join("\n") + "\n"
}
