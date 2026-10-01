// Papers.js - what a page is made of and written with: the paper (its color
// and printed pattern), how far apart the lines are, the pens (fonts), and
// the inks and highlighters.
//
// Colors a person picks are stored as the light-paper ink (the "canonical"
// color) and shown as their dark-paper twin on dark paper, so switching a page
// to night paper never leaves dark ink on a dark page.
//
// Shared by the notebook (app/*.qml) and tests/papers.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library

// The printed patterns, in the order the paper shader numbers them.
var PATTERNS = [
  { id: "blank", label: "Blank", shader: 0 },
  { id: "ruled", label: "Ruled", shader: 1 },
  { id: "grid", label: "Grid", shader: 2 },
  { id: "dots", label: "Dots", shader: 3 },
  { id: "graph", label: "Graph", shader: 4 },
  { id: "legal", label: "Legal pad", shader: 5 }
]

// How far apart the lines are, and the size of the writing on them.
var SPACINGS = [
  { id: "compact", label: "Narrow", pitch: 26, body: 15 },
  { id: "regular", label: "College", pitch: 30, body: 17 },
  { id: "roomy", label: "Wide", pitch: 36, body: 20 }
]

// Paper colors. line/margin/head are the printed rules; ink is what text is
// written in; grain and fiber are how much texture the paper has.
var PAPERS = [
  { id: "white", label: "White", paper: "#fdfdfb", line: "#5f8fd6", lineAlpha: 0.5, margin: "#e5838a", marginAlpha: 0.7, ink: "#1f2430", muted: "#6b7280", grain: 0.5, fiber: 0, dark: false },
  { id: "ivory", label: "Ivory", paper: "#fbf6e9", line: "#6a95d2", lineAlpha: 0.52, margin: "#df8f8f", marginAlpha: 0.72, ink: "#1f2430", muted: "#6f6a60", grain: 0.8, fiber: 0, dark: false },
  { id: "cream", label: "Aged", paper: "#f2e6cb", line: "#a38a64", lineAlpha: 0.42, margin: "#c47262", marginAlpha: 0.62, ink: "#2b2118", muted: "#65563f", grain: 1.0, fiber: 0.35, dark: false },
  { id: "yellow", label: "Legal yellow", paper: "#fcf3ae", line: "#5d8fcf", lineAlpha: 0.58, margin: "#dd6b58", marginAlpha: 0.72, ink: "#1d2433", muted: "#6d6a4e", grain: 0.6, fiber: 0, dark: false },
  { id: "kraft", label: "Kraft", paper: "#c9a676", line: "#5f4222", lineAlpha: 0.32, margin: "#7c2e1f", marginAlpha: 0.5, ink: "#23170c", muted: "#4a351d", grain: 1.0, fiber: 1.0, dark: false },
  { id: "gray", label: "Recycled", paper: "#e5e3dc", line: "#7d8794", lineAlpha: 0.42, margin: "#c27878", marginAlpha: 0.6, ink: "#22252b", muted: "#5b5e64", grain: 0.9, fiber: 0.55, dark: false },
  { id: "night", label: "Night", paper: "#1c1e23", line: "#ffffff", lineAlpha: 0.17, margin: "#d9807a", marginAlpha: 0.45, ink: "#e9e6de", muted: "#9a9993", grain: 0.7, fiber: 0, dark: true },
  { id: "blueprint", label: "Blueprint", paper: "#1f4471", line: "#d6e7ff", lineAlpha: 0.32, margin: "#ffffff", marginAlpha: 0.32, ink: "#eef5ff", muted: "#a9c3e6", grain: 0.5, fiber: 0, dark: true },
  { id: "theme", label: "Omarchy theme", paper: "", line: "", lineAlpha: 0.13, margin: "", marginAlpha: 0.6, ink: "", muted: "", grain: 0.6, fiber: 0, dark: null }
]

// The pens: the fonts writing can be in. `families` are tried in order (the
// bundled fonts are loaded by the app under these names); `scale` evens out
// how big each font looks at the same size.
var PENS = [
  { id: "sans", label: "Clean", families: ["Adwaita Sans", "Inter", "Noto Sans"], scale: 1.0, bold: true },
  { id: "serif", label: "Book", families: ["Lora", "Noto Serif"], scale: 1.02, bold: true },
  { id: "hand", label: "Handwriting", families: ["Caveat"], scale: 1.34, bold: true },
  { id: "print", label: "Print", families: ["Patrick Hand"], scale: 1.14, bold: false },
  { id: "typewriter", label: "Typewriter", families: ["Special Elite"], scale: 0.98, bold: false },
  { id: "mono", label: "Mono", families: ["iA Writer Mono S", "JetBrainsMono Nerd Font", "Noto Sans Mono"], scale: 0.9, bold: true },
  { id: "duo", label: "Writer", families: ["iA Writer Duo S", "iA Writer Mono S", "Noto Sans Mono"], scale: 0.94, bold: true }
]

// Ink colors for writing, as [light paper, dark paper].
var INKS = [
  { id: "blue", label: "Blue", light: "#1e4fa3", dark: "#8ab4f8" },
  { id: "red", label: "Red", light: "#b13428", dark: "#ff8a80" },
  { id: "green", label: "Green", light: "#1d7044", dark: "#8ce0b0" },
  { id: "purple", label: "Purple", light: "#6a3fa0", dark: "#c7a7ff" },
  { id: "orange", label: "Orange", light: "#9f4a10", dark: "#ffb56b" },
  { id: "gray", label: "Pencil", light: "#5b6270", dark: "#a9adb5" }
]

// Highlighters, as [light paper, dark paper].
var HIGHLIGHTS = [
  { id: "yellow", label: "Yellow", light: "#fff27a", dark: "#5e5316" },
  { id: "green", label: "Green", light: "#b8f5c8", dark: "#1f5236" },
  { id: "pink", label: "Pink", light: "#ffc4e1", dark: "#5f2647" },
  { id: "blue", label: "Blue", light: "#b5e3fb", dark: "#1b4862" },
  { id: "orange", label: "Orange", light: "#ffd3a3", dark: "#6a3c15" },
  { id: "purple", label: "Purple", light: "#e2cbff", dark: "#43305f" }
]

// Sticky-note (callout) colors, as [light paper, dark paper] backgrounds.
var TONES = {
  yellow: { light: "#fff4b3", dark: "#4a4320", icon: "\u270e" },
  blue: { light: "#dcefff", dark: "#1e3a52", icon: "\u2139" },
  green: { light: "#dcf6e2", dark: "#1f3f2c", icon: "\u2714" },
  pink: { light: "#ffe0ee", dark: "#4c2236", icon: "\u2665" },
  purple: { light: "#ece0ff", dark: "#352850", icon: "\u2605" },
  gray: { light: "#ecebe6", dark: "#33353a", icon: "\u2022" }
}

function byId(list, id, fallback) {
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return fallback === undefined ? list[0] : fallback
}

function pattern(id) { return byId(PATTERNS, id, PATTERNS[1]) }
function spacing(id) { return byId(SPACINGS, id, SPACINGS[1]) }
function pen(id) { return byId(PENS, id, PENS[0]) }

// ---- colors ------------------------------------------------------------------------

function hex(color) {
  var c = String(color || "").trim().toLowerCase()
  if (/^#[0-9a-f]{6}$/.test(c)) return c
  if (/^#[0-9a-f]{8}$/.test(c)) return "#" + c.slice(3)
  var m = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/.exec(c)
  if (m) return "#" + m[1] + m[1] + m[2] + m[2] + m[3] + m[3]
  return ""
}

function rgb(color) {
  var h = hex(color) || "#808080"
  return [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255]
}

function toHex(r, g, b) {
  return "#" + [r, g, b].map(function(v) {
    var n = Math.round(Math.max(0, Math.min(1, v)) * 255)
    return ("0" + n.toString(16)).slice(-2)
  }).join("")
}

function luminance(color) {
  var c = rgb(color)
  return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2]
}

// WCAG contrast ratio between two colors (1..21).
function contrast(a, b) {
  function lin(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  function rel(c) { var x = rgb(c); return 0.2126 * lin(x[0]) + 0.7152 * lin(x[1]) + 0.0722 * lin(x[2]) }
  var la = rel(a)
  var lb = rel(b)
  return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05)
}

// Whichever of two colors reads better on a background.
function readable(background, first, second) {
  return contrast(background, first) >= contrast(background, second) ? first : second
}

// a mixed toward b by t (0..1).
function mix(a, b, t) {
  var x = rgb(a)
  var y = rgb(b)
  return toHex(x[0] + (y[0] - x[0]) * t, x[1] + (y[1] - x[1]) * t, x[2] + (y[2] - x[2]) * t)
}

// canonical -> dark twin for inks and highlighters.
function darkMap() {
  var map = {}
  INKS.concat(HIGHLIGHTS).forEach(function(c) { map[c.light] = c.dark })
  return map
}

// dark twin -> canonical.
function lightMap() {
  var map = {}
  INKS.concat(HIGHLIGHTS).forEach(function(c) { map[c.dark] = c.light })
  return map
}

// ---- a page's paper, ready to draw -----------------------------------------------------

// Everything the paper and the editor need, from a page's (or notebook's)
// paper choice { pattern, color, spacing } and the Omarchy theme's colors
// { background, foreground, accent }.
function resolve(choice, theme) {
  var c = choice || {}
  var t = theme || {}
  var pat = pattern(c.pattern)
  var sp = spacing(c.spacing)
  var paper = byId(PAPERS, c.color, PAPERS[1])
  var out = {
    pattern: pat.id,
    shader: pat.shader,
    color: paper.id,
    spacing: sp.id,
    pitch: sp.pitch,
    body: sp.body,
    grain: paper.grain,
    fiber: paper.fiber
  }
  if (paper.id === "theme") {
    var bg = hex(t.background) || "#1c1e23"
    var fg = hex(t.foreground) || "#e9e6de"
    var accent = hex(t.accent) || fg
    var dark = luminance(bg) < 0.5
    // The theme's background, lifted a little toward its text so the page
    // stands off the desk.
    out.paper = mix(bg, fg, dark ? 0.045 : 0.02)
    out.line = fg
    out.lineAlpha = dark ? 0.17 : 0.2
    out.margin = accent
    out.marginAlpha = 0.55
    out.ink = fg
    out.muted = mix(fg, bg, 0.45)
    out.dark = dark
  } else {
    out.paper = paper.paper
    out.line = paper.line
    out.lineAlpha = paper.lineAlpha
    out.margin = paper.margin
    out.marginAlpha = paper.marginAlpha
    out.ink = paper.ink
    out.muted = paper.muted
    out.dark = paper.dark
  }
  // Legal pads get their double margin; plain paper no margin at all.
  out.hasMargin = pat.id === "ruled" || pat.id === "legal"
  out.headRule = pat.id === "ruled" || pat.id === "legal"
  out.link = out.dark ? "#8ab4f8" : "#2456b3"
  out.selection = out.dark ? "#3b5b8f" : "#b9d3f5"
  // The edge of the page and the paper under it, a shade darker.
  out.edge = mix(out.paper, out.dark ? "#000000" : "#6b5a3a", out.dark ? 0.35 : 0.16)
  out.back = mix(out.paper, out.dark ? "#ffffff" : "#000000", 0.04)
  return out
}

function inkColor(id, dark) {
  var ink = byId(INKS, id, null)
  return ink ? (dark ? ink.dark : ink.light) : ""
}

function highlightColor(id, dark) {
  var h = byId(HIGHLIGHTS, id, null)
  return h ? (dark ? h.dark : h.light) : ""
}

function toneColor(id, dark) {
  var tone = TONES[id] || TONES.yellow
  return dark ? tone.dark : tone.light
}

// ---- type -------------------------------------------------------------------------

// Size, weight and style for each kind of block in a pen at a spacing.
function typeStyle(type, penId, spacingId) {
  var p = pen(penId)
  var sp = spacing(spacingId)
  var base = sp.body * p.scale
  var style = { size: Math.round(base), bold: false, italic: false, mono: false, rows: 1, caps: false }
  if (type === "h1") { style.size = Math.round(base * 1.72); style.bold = p.bold; style.rows = 2 }
  else if (type === "h2") { style.size = Math.round(base * 1.28); style.bold = p.bold }
  else if (type === "h3") { style.size = Math.round(base * 1.04); style.bold = true; style.caps = !p.bold }
  else if (type === "quote") { style.italic = true }
  else if (type === "code") { style.size = Math.round(sp.body * 0.88); style.mono = true }
  // A heading that doesn't fit its line gets smaller rather than overlap.
  var room = sp.pitch * style.rows
  if (style.size > room * 0.9) style.size = Math.floor(room * 0.9)
  return style
}
