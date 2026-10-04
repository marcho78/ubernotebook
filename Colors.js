// Colors.js - colors of your own, picked in Pages' color picker
// (app/ColorPicker.qml): hex colors and their hue, saturation and value, how
// well two colors read against each other (as WCAG measures it), which text
// reads best on a color, and the colors you picked last.
//
// Shared with tests/colors.test.cjs, so keep it plain JavaScript with no QML
// or Node APIs.
.pragma library

var MAX_RECENT = 8

// "#F80", "ff8800", "#ff8800ee" (Qt's #aarrggbb too) -> "#ff8800"; "" when
// it isn't a hex color.
function normalize(value) {
  var v = String(value || "").trim().toLowerCase().replace(/^#/, "")
  if (/^[0-9a-f]{3}$/.test(v)) return "#" + v.charAt(0) + v.charAt(0) + v.charAt(1) + v.charAt(1) + v.charAt(2) + v.charAt(2)
  if (/^[0-9a-f]{6}$/.test(v)) return "#" + v
  if (/^[0-9a-f]{8}$/.test(v)) return "#" + v.slice(2)
  return ""
}

function isHex(value) { return normalize(value) !== "" && /^#?[0-9a-f]{3}([0-9a-f]{3})?$/i.test(String(value).trim()) }

function rgb(hex) {
  var h = normalize(hex)
  if (!h) return null
  return { r: parseInt(h.slice(1, 3), 16), g: parseInt(h.slice(3, 5), 16), b: parseInt(h.slice(5, 7), 16) }
}

function toHex(r, g, b) {
  function two(n) { return ("0" + Math.max(0, Math.min(255, Math.round(n))).toString(16)).slice(-2) }
  return "#" + two(r) + two(g) + two(b)
}

// { h: 0..360, s: 0..1, v: 0..1 }
function toHsv(hex) {
  var c = rgb(hex)
  if (!c) return { h: 0, s: 0, v: 0 }
  var r = c.r / 255, g = c.g / 255, b = c.b / 255
  var max = Math.max(r, g, b), min = Math.min(r, g, b), d = max - min
  var h = 0
  if (d > 0) {
    if (max === r) h = ((g - b) / d) % 6
    else if (max === g) h = (b - r) / d + 2
    else h = (r - g) / d + 4
    h *= 60
    if (h < 0) h += 360
  }
  return { h: h, s: max === 0 ? 0 : d / max, v: max }
}

function fromHsv(h, s, v) {
  var hh = ((Number(h) % 360) + 360) % 360
  var ss = Math.max(0, Math.min(1, Number(s)))
  var vv = Math.max(0, Math.min(1, Number(v)))
  var c = vv * ss
  var x = c * (1 - Math.abs((hh / 60) % 2 - 1))
  var m = vv - c
  var p = hh < 60 ? [c, x, 0] : hh < 120 ? [x, c, 0] : hh < 180 ? [0, c, x] : hh < 240 ? [0, x, c] : hh < 300 ? [x, 0, c] : [c, 0, x]
  return toHex((p[0] + m) * 255, (p[1] + m) * 255, (p[2] + m) * 255)
}

// Relative luminance, 0 (black) to 1 (white).
function luminance(hex) {
  var c = rgb(hex)
  if (!c) return 0
  function lin(n) { var x = n / 255; return x <= 0.03928 ? x / 12.92 : Math.pow((x + 0.055) / 1.055, 2.4) }
  return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
}

// How well two colors read against each other: 1 (not at all) to 21.
function contrast(a, b) {
  var x = luminance(a), y = luminance(b)
  return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
}

// Text on `back`: `ink` (the page's) when it reads well there, else the
// darker or the lighter of `dark` and `light`, whichever reads better.
function readableOn(back, ink, dark, light) {
  if (contrast(back, ink) >= 4.5) return normalize(ink)
  return contrast(back, dark || "#14161c") >= contrast(back, light || "#ffffff") ? normalize(dark || "#14161c") : normalize(light || "#ffffff")
}

// A color as a line on `paper`: as it is, or darker (lighter, on a dark
// page) until it shows (`least`: how well it has to read, 1.8 by default;
// 3 for words).
function visibleOn(color, paper, least) {
  var c = normalize(color)
  var need = least || 1.8
  if (!c || contrast(c, paper) >= need) return c
  var hsv = toHsv(c)
  var dark = luminance(paper) < 0.5
  for (var i = 0; i < 12 && contrast(c, paper) < need; i++) {
    if (dark) { hsv.v = Math.min(1, hsv.v + 0.08); hsv.s = Math.max(0, hsv.s - 0.04) }
    else hsv.v = Math.max(0, hsv.v - 0.08)
    c = fromHsv(hsv.h, hsv.s, hsv.v)
  }
  return c
}

// How a contrast reads, for the picker: "good", "fair" or "poor".
function rating(ratio) { return ratio >= 4.5 ? "good" : ratio >= 3 ? "fair" : "poor" }

// The colors you picked last, newest first: from "#aa0000,#00bb00", and
// with one more.
function recentList(value) {
  var seen = {}
  return String(value || "").split(",").map(normalize)
    .filter(function(c) { return c && !seen[c] && (seen[c] = true) }).slice(0, MAX_RECENT)
}

function withRecent(value, color) {
  var c = normalize(color)
  var list = recentList(value).filter(function(x) { return x !== c })
  if (c) list.unshift(c)
  return list.slice(0, MAX_RECENT).join(",")
}
