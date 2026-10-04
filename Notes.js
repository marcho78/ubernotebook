// Notes.js - footnotes in Pages. A footnote is kept in the line it belongs
// to as a link that holds its words, uber-notebook://note/<words>, so search
// and agents read it there (and the Markdown copy has it as [^1], its words
// at the end of the page). The editor shows it as its number, small and
// raised: an image (one character to the cursor, so what's typed after it
// isn't part of it), whose address says which footnote it is. They're
// numbered down the page; the same words twice are one footnote.
//
// Shared with tests/notes.test.cjs, so keep it plain JavaScript with no QML
// or Node APIs.
.pragma library
.import "Html.js" as Html

var PREFIX = "uber-notebook://note/"
var MARK = "uber-notebook-note"
var MAX_NOTE = 2000

function clean(text) {
  return String(text === undefined || text === null ? "" : text).replace(/[\r\n\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, MAX_NOTE)
}

function href(text) { return PREFIX + encodeURIComponent(clean(text)) }
function isLink(url) { return String(url || "").indexOf(PREFIX) === 0 }

function textOf(url) {
  if (!isLink(url)) return ""
  try { return clean(decodeURIComponent(String(url).slice(PREFIX.length))) } catch (e) { return "" }
}

// The link it's kept as: its words, written out.
function link(text) {
  var t = clean(text)
  return t ? "<a href=\"" + Html.escapeAttr(href(t)) + "\">" + Html.escapeText(t) + "</a>" : ""
}

// The footnotes in a block's text, in order: [words].
function inText(inner) {
  var out = []
  if (String(inner || "").indexOf(PREFIX) < 0) return out
  Html.links(inner).forEach(function(l) { if (isLink(l.href)) { var t = textOf(l.href); if (t) out.push(t) } })
  return out
}

// A page's footnotes in order, each once, from its blocks' texts in order.
function order(inners) {
  var out = []
  ;(inners || []).forEach(function(inner) {
    inText(inner).forEach(function(t) { if (out.indexOf(t) < 0) out.push(t) })
  })
  return out
}

// ---- as an image in the editor ----------------------------------------------------

// Its number, small and raised, in `color`, for text `em` px tall.
function numberSvg(n, em, color) {
  var label = String(n)
  var size = em * 0.7
  var w = Math.max(size * 0.62 * label.length + size * 0.35, size * 0.9)
  var h = em * 1.1
  return "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"" + w.toFixed(2) + "px\" height=\"" + h.toFixed(2) + "px\" viewBox=\"0 0 " + w.toFixed(2) + " " + h.toFixed(2) + "\">"
    + "<text x=\"" + (w / 2).toFixed(2) + "\" y=\"" + (size * 0.78).toFixed(2) + "\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"" + size.toFixed(2) + "\" font-weight=\"600\" fill=\"" + color + "\">" + label + "</text></svg>"
}

function imageUrl(svg, text) {
  return "data:image/svg+xml;" + MARK + "=" + encodeURIComponent(clean(text)) + "," + encodeURIComponent(String(svg || ""))
}

// The words an image's address says it's the footnote of, or "".
function textOfImage(src) {
  var m = /^data:image\/svg\+xml;uber-notebook-note=([^,;"]*)[,;]/.exec(String(src || ""))
  if (!m) return ""
  try { return clean(decodeURIComponent(m[1])) } catch (e) { return "" }
}

// A block's text as the editor shows it: each footnote's link as its
// number (`numberOf(words)`), `em` px text, in `color`.
function toImages(inner, numberOf, em, color) {
  var text = String(inner || "")
  if (text.indexOf(PREFIX) < 0) return text
  return text.replace(/<a\b[^>]*?\bhref="(uber-notebook:\/\/note\/[^"]*)"[^>]*>[\s\S]*?<\/a>/g, function(all, url) {
    var t = textOf(Html.decodeEntities(url))
    if (!t) return all
    var n = typeof numberOf === "function" ? numberOf(t) : 1
    var svg = numberSvg(n, em, color)
    var size = /width="([\d.]+)px" height="([\d.]+)px"/.exec(svg)
    return "<img src=\"" + imageUrl(svg, t) + "\" width=\"" + Math.round(parseFloat(size[1])) + "\" height=\"" + Math.round(parseFloat(size[2])) + "\" style=\"vertical-align: middle;\" />"
  })
}

// And back, as it's kept: each footnote's image as its link.
function toLinks(inner) {
  var text = String(inner || "")
  if (text.indexOf(MARK) < 0) return text
  return text.replace(/<img\b[^>]*?\bsrc="(data:image\/svg\+xml;uber-notebook-note=[^"]*)"[^>]*>/g, function(all, src) {
    var t = textOfImage(Html.decodeEntities(src))
    return t ? link(t) : ""
  })
}

// Where in a block's shown text (counting each equation and footnote as one
// character, as the editor does) its `nth` footnote with these words is, or -1.
function positionIn(inner, words, nth) {
  var want = clean(words)
  var at = 0
  var seen = 0
  var lastHref = ""
  var runs = Html.parse(inner || "")
  for (var i = 0; i < runs.length; i++) {
    var r = runs[i]
    if (r.br) { at++; lastHref = ""; continue }
    if (r.img) { at++; lastHref = ""; continue }
    var token = r.href && (isLink(r.href) || String(r.href).indexOf("uber-notebook://math/") === 0)
    if (token) {
      if (r.href === lastHref) continue
      lastHref = r.href
      if (isLink(r.href) && textOf(r.href) === want) {
        if (seen === (nth || 0)) return at
        seen++
      }
      at++
      continue
    }
    lastHref = ""
    at += r.text.length
  }
  return -1
}

// ---- Markdown ------------------------------------------------------------------------

// A footnote's words written in Markdown, as they read (a footnote's words
// are plain): **bold**, *italics*, `code` and ~~struck~~ without their
// marks, a link's words with its address after them.
function fromMarkdown(text) {
  var t = String(text || "")
    .replace(/!?\[([^\]]*)\]\(<?([^)\s>]+)>?(?:\s+"[^"]*")?\)/g, function(m, words, url) { return words && words !== url ? words + " (" + url + ")" : url })
    .replace(/`([^`]+)`/g, "$1")
    .replace(/(\*\*|__)(?=\S)([\s\S]*?\S)\1/g, "$2")
    .replace(/~~(?=\S)([\s\S]*?\S)~~/g, "$1")
    .replace(/(^|[^\w*])\*(?=\S)([^*]*?\S)\*(?!\w)/g, "$1$2")
    .replace(/(^|[^\w_])_(?=\S)([^_]*?\S)_(?!\w)/g, "$1$2")
  return clean(t)
}

// Footnotes' words written at the end ("[^1]: words", lines indented under
// it going on with it), taken out of the lines: { lines, notes: { label:
// words } }.
function definitions(lines) {
  var out = []
  var notes = {}
  var current = ""
  var inFence = false
  ;(lines || []).forEach(function(line) {
    if (/^ {0,3}(```|~~~)/.test(line)) { inFence = !inFence; current = ""; out.push(line); return }
    if (inFence) { out.push(line); return }
    var m = /^ {0,3}\[\^([^\]\s]+)\]:\s?(.*)$/.exec(line)
    if (m) {
      current = m[1]
      notes[current] = m[2]
      return
    }
    if (current && /^( {4}|\t)\S/.test(line)) {
      notes[current] += " " + line.trim()
      return
    }
    current = ""
    out.push(line)
  })
  for (var k in notes) notes[k] = clean(notes[k])
  return { lines: out, notes: notes }
}
