// Equations.js - equations in Pages, written in LaTeX and drawn by MathJax
// (vendor/mathjax), in a worker thread (app/MathWorker.mjs), as SVG.
//
// An equation on a line of its own is a code block in Math (`$$ … $$` in
// Markdown). One in a line of text (`$ … $`) is kept as a link that holds
// its LaTeX, uber-notebook://math/<LaTeX>, so search, agents and the
// Markdown copy read it as it's written; the editor shows it as its drawing:
// an image (one character to the cursor), whose address says which
// equation it is, so what's typed around it, copied or pasted keeps it.
//
// Shared with tests/equations.test.cjs, so keep it plain JavaScript with no
// QML or Node APIs.
.pragma library
.import "Html.js" as Html

// The code block language that's drawn as an equation.
var LANG = "Math"
var PREFIX = "uber-notebook://math/"
// What an image of one says about itself in its address.
var MARK = "uber-notebook-math"
var MAX_TEX = 4000
// TeX's letters are shorter than a UI font's at the same size: one in a
// line is drawn this much bigger, to look the size of the words around it.
var INLINE_SCALE = 1.2

// How big a drawing can be. MathJax draws what it's asked to: a
// `\rule{1000000em}{1000000em}` is under 500 bytes of SVG, and as an image
// more pixels than any memory holds. Real math is far smaller: the biggest
// matrix MAX_TEX characters make is about 67 × 61 em, a 30-line aligned
// derivation about 20 × 100 em (525 × 2500 px at 26 px an em, the large
// view's 100%), in at most about 470 KB of SVG and 16000 tags. Past these
// it's too big to draw (tooBig says why).
// Ems across or down, and across times down.
var MAX_EM = 400
var MAX_EM_AREA = 10000
// Characters of SVG, and tags in it (each "<").
var MAX_SVG = 1000000
var MAX_TAGS = 40000
// As an image, at any size (`sized`): pixels across or down (what graphics
// cards take), and in all (256 MB at four bytes each).
var MAX_PX = 16384
var MAX_PX_AREA = 8192 * 8192

function isLang(lang) { return String(lang || "").trim().toLowerCase() === "math" }

function clean(tex) {
  return String(tex === undefined || tex === null ? "" : tex).replace(/\r/g, "").replace(/[\u2028\u2029]/g, "\n").trim().slice(0, MAX_TEX)
}

// ---- what's been drawn -------------------------------------------------------------

// Drawings kept while Uber Notebook runs, shared by every editor: key ("D:"
// on its own, "I:" in a line, then its LaTeX) -> { svg, error }. Up to
// MAX_DRAWN of them, with up to MAX_DRAWN_SVG characters of SVG in all;
// then they're all let go (and drawn again as they're needed).
var drawn = {}
var drawnCount = 0
var drawnChars = 0
var MAX_DRAWN = 600
var MAX_DRAWN_SVG = 16000000

function cached(key) { return Object.prototype.hasOwnProperty.call(drawn, key) ? drawn[key] : null }

// One too big to draw is kept as what's wrong with it, without its SVG.
function remember(key, value) {
  var why = value && value.svg ? tooBig(value.svg) : ""
  var kept = why ? { svg: "", error: value.error || why } : value
  if (drawnCount >= MAX_DRAWN || drawnChars + charsOf(kept) > MAX_DRAWN_SVG) forget()
  if (Object.prototype.hasOwnProperty.call(drawn, key)) drawnChars -= charsOf(drawn[key])
  else drawnCount++
  drawn[key] = kept
  drawnChars += charsOf(kept)
}

function charsOf(value) { return value && value.svg ? String(value.svg).length : 0 }

function forget() {
  drawn = {}
  drawnCount = 0
  drawnChars = 0
}

function key(tex, display) { return (display ? "D:" : "I:") + clean(tex) }

// ---- one in a line of text ------------------------------------------------------

function href(tex) { return PREFIX + encodeURIComponent(clean(tex)) }
function isLink(url) { return String(url || "").indexOf(PREFIX) === 0 }

function texOf(url) {
  if (!isLink(url)) return ""
  try { return clean(decodeURIComponent(String(url).slice(PREFIX.length))) } catch (e) { return "" }
}

// The link it's kept as: its LaTeX, written out.
function link(tex) {
  var t = clean(tex)
  return t ? "<a href=\"" + Html.escapeAttr(href(t)) + "\">" + Html.escapeText(t) + "</a>" : ""
}

// The equations in a block's text, in order: [LaTeX].
function inText(inner) {
  var out = []
  Html.links(inner || "").forEach(function(l) { if (isLink(l.href)) { var t = texOf(l.href); if (t) out.push(t) } })
  return out
}

// ---- what MathJax draws -----------------------------------------------------------

// Its size in ems (the viewBox counts a thousandth of an em): how wide, how
// tall, and how far it goes below the line it's on; or null.
function measure(svg) {
  var m = /viewBox="(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)"/.exec(String(svg || ""))
  if (!m) return null
  var minY = parseFloat(m[2])
  var w = parseFloat(m[3])
  var h = parseFloat(m[4])
  if (!isFinite(w) || !isFinite(h) || w <= 0 || h <= 0) return null
  return { w: w / 1000, h: h / 1000, depth: Math.max(0, (h + minY) / 1000) }
}

// What's wrong with the LaTeX, when MathJax drew an error (in red) instead.
function errorOf(svg) {
  var m = /data-mjx-error="([^"]*)"/.exec(String(svg || ""))
  return m ? Html.decodeEntities(m[1]) : ""
}

// Why it's too big to draw, in a few plain words to show in its place; or
// "" (it isn't). Its box is read however MathJax wrote it (1e+28, Infinity).
function tooBig(svg) {
  var text = String(svg || "")
  var much = tooMuch(text)
  if (much) return much
  var m = /viewBox="[^"\s]+ [^"\s]+ ([^"\s]+) ([^"\s]+)"/.exec(text)
  var w = m ? parseFloat(m[1]) / 1000 : 0
  var h = m ? parseFloat(m[2]) / 1000 : 0
  if (w > MAX_EM || h > MAX_EM) return "Too big to draw: " + amount(w) + " \u00d7 " + amount(h) + " em, at most " + MAX_EM + " a side"
  if (w * h > MAX_EM_AREA) return "Too big to draw: " + amount(w) + " \u00d7 " + amount(h) + " em, at most " + MAX_EM_AREA + " em\u00b2 in all"
  return ""
}

// Why there's too much SVG to read, or too many tags in it; or "".
function tooMuch(svg) {
  var text = String(svg || "")
  if (text.length > MAX_SVG) return "Too much to draw: " + Math.ceil(text.length / 1000) + " KB, at most " + MAX_SVG / 1000 + " KB"
  if (tagCount(text, MAX_TAGS + 1) > MAX_TAGS) return "Too much to draw: more than " + MAX_TAGS + " parts"
  return ""
}

// Its tags ("<"), counted up to `most`.
function tagCount(text, most) {
  var n = 0
  for (var i = text.indexOf("<"); i >= 0 && n < most; i = text.indexOf("<", i + 1)) n++
  return n
}

// A size in ems, as it's said: whole ones (rounded up) from 10, tenths under.
function amount(n) { return String(n >= 10 ? Math.ceil(n) : Math.ceil(n * 10) / 10) }

// The most px an em it can be drawn at on its own (past that `sized` gives
// null, its image too big), for zooming in on it; 0 when it's too big at
// any size.
function maxEm(svg) {
  var b = measure(svg)
  if (!b || tooBig(svg)) return 0
  // (A hair under, so it's still drawn at that, rounding and all.)
  return Math.min(MAX_PX / b.w, MAX_PX / b.h, Math.sqrt(MAX_PX_AREA / (b.w * b.h))) * 0.999999
}

// Drawn `em` px an em, in `color` ("#rrggbb"): { svg, width, height, depth }
// (px), or null (as when it's too big: tooBig, maxEm). `middle` (px; for
// one in a line of text): it's made taller above or below, so its middle is
// that far above its baseline; Qt puts an image's middle half the text's
// x-height above the line (as CSS's "middle"), so then the two baselines
// are one.
function sized(svg, em, color, middle) {
  var b = measure(svg)
  if (!b || tooBig(svg)) return null
  var text = String(svg)
  if (middle > 0) {
    var vb = /viewBox="(-?[\d.]+) (-?[\d.]+) (-?[\d.]+) (-?[\d.]+)"/.exec(text)
    var minY = parseFloat(vb[2])
    var vh = parseFloat(vb[4])
    var above = -minY
    var below = vh + minY
    var mid = middle / em * 1000
    var top = Math.max(0, 2 * mid - above + below)
    var bottom = Math.max(0, above - below - 2 * mid)
    minY -= top
    vh += top + bottom
    text = text.replace(vb[0], "viewBox=\"" + vb[1] + " " + minY.toFixed(1) + " " + vb[3] + " " + vh.toFixed(1) + "\"")
    b = { w: b.w, h: vh / 1000, depth: (vh + minY) / 1000 }
  }
  var w = Math.max(1, b.w * em)
  var h = Math.max(1, b.h * em)
  if (!(w <= MAX_PX && h <= MAX_PX && w * h <= MAX_PX_AREA)) return null
  var out = text
    .replace(/^<svg\b([^>]*?)\swidth="[^"]*"/, "<svg$1 width=\"" + w.toFixed(2) + "px\"")
    .replace(/^<svg\b([^>]*?)\sheight="[^"]*"/, "<svg$1 height=\"" + h.toFixed(2) + "px\"")
    .replace(/^<svg\b([^>]*?)\sstyle="[^"]*"/, "<svg$1")
    .replace(/currentColor/g, String(color || "#000000"))
  return { svg: out, width: w, height: h, depth: b.depth * em }
}

// While it's being drawn (or if it can't be): its LaTeX, faint, in a box
// about as big.
function placeholder(tex, em, color) {
  var t = clean(tex).replace(/\s+/g, " ")
  var shown = t.length > 40 ? t.slice(0, 39) + "\u2026" : t
  var w = Math.max(em, shown.length * em * 0.55 + em * 0.5)
  var h = em * 1.25
  var esc = shown.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
  return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + w.toFixed(2) + "px\" height=\"" + h.toFixed(2) + "px\" viewBox=\"0 0 " + w.toFixed(2) + " " + h.toFixed(2) + "\">"
    + "<rect x=\"0.5\" y=\"0.5\" width=\"" + (w - 1).toFixed(2) + "\" height=\"" + (h - 1).toFixed(2) + "\" rx=\"3\" fill=\"none\" stroke=\"" + color + "\" stroke-opacity=\"0.25\"/>"
    + "<text x=\"" + (em * 0.25).toFixed(2) + "\" y=\"" + (em * 0.9).toFixed(2) + "\" font-family=\"monospace\" font-size=\"" + (em * 0.8).toFixed(2) + "\" fill=\"" + color + "\" fill-opacity=\"0.55\">" + esc + "</text></svg>"
}

// ---- as an image in the editor ----------------------------------------------------

function imageUrl(svg, tex) {
  return "data:image/svg+xml;" + MARK + "=" + encodeURIComponent(clean(tex)) + "," + encodeURIComponent(String(svg || ""))
}

// The LaTeX an image's address says it is, or "" (not one of these).
function texOfImage(src) {
  var m = /^data:image\/svg\+xml;uber-notebook-math=([^,;"]*)[,;]/.exec(String(src || ""))
  if (!m) return ""
  try { return clean(decodeURIComponent(m[1])) } catch (e) { return "" }
}

// A block's text as the editor shows it: each equation's link as its
// image. `drawing(tex)` gives what's drawn ({ svg }, Qt-ready: `sized`) or
// null while it's being drawn (then its placeholder, `em` px an em in
// `color`; as for one that isn't Qt-ready, or too big to be an image).
function toImages(inner, drawing, em, color) {
  var text = String(inner || "")
  if (text.indexOf(PREFIX) < 0) return text
  return text.replace(/<a\b[^>]*?\bhref="(uber-notebook:\/\/math\/[^"]*)"[^>]*>[\s\S]*?<\/a>/g, function(all, url) {
    var tex = texOf(Html.decodeEntities(url))
    if (!tex) return all
    var d = typeof drawing === "function" ? drawing(tex) : null
    var svg = d && d.svg ? d.svg : ""
    var size = svg ? imageSize(svg) : null
    if (!size || tooMuch(svg) || !(size[0] <= MAX_PX && size[1] <= MAX_PX && size[0] * size[1] <= MAX_PX_AREA)) {
      svg = placeholder(tex, em, color)
      size = imageSize(svg) || [Math.round(em * 2), Math.round(em)]
    }
    return "<img src=\"" + imageUrl(svg, tex) + "\" width=\"" + size[0] + "\" height=\"" + size[1] + "\" style=\"vertical-align: middle;\" />"
  })
}

// The whole px an image of it is, as its <svg> says: [width, height], or
// null (not in px).
function imageSize(svg) {
  var tag = /^<svg\b[^>]*>/.exec(String(svg || ""))
  var w = tag ? /\swidth="([\d.]+)px"/.exec(tag[0]) : null
  var h = tag ? /\sheight="([\d.]+)px"/.exec(tag[0]) : null
  return w && h ? [Math.round(parseFloat(w[1])), Math.round(parseFloat(h[1]))] : null
}

// And back, as it's kept: each equation's image as its link.
function toLinks(inner) {
  var text = String(inner || "")
  if (text.indexOf(MARK) < 0) return text
  return text.replace(/<img\b[^>]*?\bsrc="(data:image\/svg\+xml;uber-notebook-math=[^"]*)"[^>]*>/g, function(all, src) {
    var tex = texOfImage(Html.decodeEntities(src))
    return tex ? link(tex) : ""
  })
}

// ---- Markdown ------------------------------------------------------------------------

// An equation on its own, as Markdown, and what it's read from: "$$" lines
// around it, "$$ … $$" on one line, or a ```math fence.
function fence(tex) { return "$$\n" + clean(tex) + "\n$$" }

// `$…$` in a line of Markdown, as pandoc reads it: the opening `$` not
// followed by a space, the closing one not after a space nor before a digit
// (so "$5 and $10" stays money); and `$$…$$` in a line. The one starting
// at `i` in `text`: { end (just past it), tex }, or null.
function spanAt(text, i) {
  var s = String(text || "")
  if (s.charAt(i) !== "$") return null
  if (s.charAt(i + 1) === "$") {
    var close2 = s.indexOf("$$", i + 2)
    if (close2 > i + 2 && s.slice(i + 2, close2).trim()) return { end: close2 + 2, tex: s.slice(i + 2, close2) }
    return null
  }
  var first = s.charAt(i + 1)
  if (first === "" || /\s/.test(first)) return null
  for (var j = i + 1; j < s.length; j++) {
    var d = s.charAt(j)
    if (d === "\\") { j++; continue }
    if (d === "\n" && s.charAt(j + 1) === "\n") return null
    if (d !== "$") continue
    if (/\s/.test(s.charAt(j - 1)) || /[0-9]/.test(s.charAt(j + 1) || "")) return null
    return j > i + 1 ? { end: j + 1, tex: s.slice(i + 1, j) } : null
  }
  return null
}

// Every one in a line of Markdown (not in `code`, nor after a backslash):
// [{ start, end, tex }].
function inlineSpans(text) {
  var s = String(text || "")
  var out = []
  var i = 0
  while (i < s.length) {
    var c = s.charAt(i)
    if (c === "\\") { i += 2; continue }
    if (c === "`") {
      var close = s.indexOf("`", i + 1)
      i = close < 0 ? s.length : close + 1
      continue
    }
    if (c === "$") {
      var span = spanAt(s, i)
      if (span) {
        out.push({ start: i, end: span.end, tex: span.tex })
        i = span.end
        continue
      }
      i += s.charAt(i + 1) === "$" ? 2 : 1
      continue
    }
    i++
  }
  return out
}
