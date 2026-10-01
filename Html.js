// Html.js - the text inside one block of a page: rich text as Qt writes it,
// and every change the formatting bar makes to it.
//
// Each block of a page is its own Qt rich-text editor. What Omanote stores for
// a block is the inside of its paragraph, as Qt writes it out:
//
//   Hello <span style=" font-weight:700;">bold</span> <a href="https://…">link</a><br />next line
//
// Formatting a selection works on that text rather than through Qt's cursor
// API, which can only set one font over a whole selection (a selection with a
// heading-sized word and body text would all come out one size). The
// selection's HTML is read into runs of equally formatted text, changed, and
// written back, with every run's formatting spelled out.
//
// Shared by the editor (app/Editor.qml) and tests/html.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library

// ---- reading ---------------------------------------------------------------------

var ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: "\u00a0" }

function decodeEntities(text) {
  return String(text).replace(/&(#x[0-9a-fA-F]{1,6}|#[0-9]{1,7}|[a-zA-Z]{2,8});/g, function(whole, name) {
    if (name.charAt(0) === "#") {
      var code = name.charAt(1) === "x" || name.charAt(1) === "X" ? parseInt(name.slice(2), 16) : parseInt(name.slice(1), 10)
      if (!isFinite(code) || code <= 0 || code > 0x10ffff || (code >= 0xd800 && code < 0xe000)) return whole
      return String.fromCodePoint(code)
    }
    return Object.prototype.hasOwnProperty.call(ENTITIES, name) ? ENTITIES[name] : whole
  })
}

function escapeText(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function escapeAttr(text) {
  return escapeText(text).replace(/"/g, "&quot;")
}

// Attributes of a start tag: name="value", name='value' or name=value.
function parseAttrs(text) {
  var attrs = {}
  var re = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)\s*(?:=\s*("([^"]*)"|'([^']*)'|([^\s"'>]+)))?/g
  var m
  while ((m = re.exec(text)) !== null) {
    var value = m[3] !== undefined ? m[3] : m[4] !== undefined ? m[4] : m[5] !== undefined ? m[5] : ""
    attrs[m[1].toLowerCase()] = decodeEntities(value)
  }
  return attrs
}

// "font-weight:700; color:#c00" -> { "font-weight": "700", color: "#c00" }.
function parseStyle(text) {
  var style = {}
  String(text || "").split(";").forEach(function(part) {
    var colon = part.indexOf(":")
    if (colon < 0) return
    var key = part.slice(0, colon).trim().toLowerCase()
    var value = part.slice(colon + 1).trim()
    if (key && value) style[key] = value
  })
  return style
}

function styleText(style) {
  return Object.keys(style).sort().map(function(key) { return key + ":" + style[key] + ";" }).join(" ")
}

// Tags, text and line breaks, in order.
function tokenize(html) {
  var tokens = []
  var re = /<!--[\s\S]*?-->|<(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:[^>"']|"[^"]*"|'[^']*')*)>|([^<]+)|(<)/g
  var m
  while ((m = re.exec(String(html || ""))) !== null) {
    if (m[0].indexOf("<!--") === 0) continue
    if (m[4] !== undefined) {
      tokens.push({ kind: "text", text: decodeEntities(m[4]) })
    } else if (m[5] !== undefined) {
      tokens.push({ kind: "text", text: "<" })
    } else {
      var tag = m[2].toLowerCase()
      var closing = m[1] === "/"
      var rest = m[3] || ""
      var selfClosing = /\/\s*$/.test(rest)
      tokens.push({ kind: closing ? "close" : "open", tag: tag, attrs: closing ? {} : parseAttrs(rest.replace(/\/\s*$/, "")), selfClosing: selfClosing })
    }
  }
  return tokens
}

// What a tag means for the text inside it, as style properties.
var TAG_STYLES = {
  b: { "font-weight": "700" }, strong: { "font-weight": "700" },
  i: { "font-style": "italic" }, em: { "font-style": "italic" },
  u: { "text-decoration": "underline" },
  s: { "text-decoration": "line-through" }, strike: { "text-decoration": "line-through" }, del: { "text-decoration": "line-through" },
  code: { "font-family": "monospace" }, tt: { "font-family": "monospace" },
  mark: { "background-color": "#fff176" },
  sub: { "vertical-align": "sub" }, sup: { "vertical-align": "super" }
}

function mergeStyle(base, extra) {
  var out = {}
  var key
  for (key in base) out[key] = base[key]
  for (key in extra) {
    if (key === "text-decoration" && out[key]) {
      var tokens = decorations(out[key])
      decorations(extra[key]).forEach(function(token) { if (tokens.indexOf(token) < 0) tokens.push(token) })
      out[key] = tokens.join(" ")
    } else {
      out[key] = extra[key]
    }
  }
  return out
}

// The inside of a block as runs: { text, style, href } for text, { br: true }
// for a line break, { img: {…} } for a picture. Nested spans are flattened,
// so each run carries all the formatting that applies to it.
function parse(inner) {
  var runs = []
  var stack = [{ tag: "", style: {}, href: "" }]
  tokenize(inner).forEach(function(token) {
    var top = stack[stack.length - 1]
    if (token.kind === "text") {
      // Qt writes the paragraph's own newlines around tags; inside a block
      // they're not text (a real line break is <br />).
      var text = token.text.replace(/[\r\n]+/g, "")
      if (text) runs.push({ text: text, style: top.style, href: top.href })
    } else if (token.kind === "open") {
      if (token.tag === "br") { runs.push({ br: true }); return }
      if (token.tag === "img") { runs.push({ img: token.attrs, href: top.href }); return }
      if (token.selfClosing) return
      var style = top.style
      if (TAG_STYLES[token.tag]) style = mergeStyle(style, TAG_STYLES[token.tag])
      if (token.attrs.style) style = mergeStyle(style, parseStyle(token.attrs.style))
      var href = top.href
      if (token.tag === "a" && token.attrs.href) href = token.attrs.href
      stack.push({ tag: token.tag, style: style, href: href })
    } else {
      // Close the innermost matching tag (and anything left open inside it).
      for (var i = stack.length - 1; i > 0; i--) {
        if (stack[i].tag === token.tag) { stack.length = i; break }
      }
    }
  })
  return merged(runs)
}

function sameStyle(a, b) {
  return styleText(a) === styleText(b)
}

// Joins neighbouring runs that look the same.
function merged(runs) {
  var out = []
  runs.forEach(function(run) {
    var last = out[out.length - 1]
    if (last && run.text !== undefined && last.text !== undefined && last.href === run.href && sameStyle(last.style, run.style)) {
      out[out.length - 1] = { text: last.text + run.text, style: last.style, href: last.href }
    } else {
      out.push(run)
    }
  })
  return out
}

// ---- writing ---------------------------------------------------------------------

function imgTag(attrs) {
  var out = "<img"
  Object.keys(attrs).sort().forEach(function(key) {
    if (/^[a-z-]+$/.test(key)) out += " " + key + "=\"" + escapeAttr(attrs[key]) + "\""
  })
  return out + " />"
}

// Runs back to HTML, flat: one span per run, links around their runs.
function serialize(runs) {
  var out = ""
  var openHref = ""
  function closeLink() {
    if (openHref) out += "</a>"
    openHref = ""
  }
  runs.forEach(function(run) {
    var href = run.href || ""
    if (href !== openHref) {
      closeLink()
      if (href) out += "<a href=\"" + escapeAttr(href) + "\">"
      openHref = href
    }
    if (run.br) { out += "<br />"; return }
    if (run.img) { out += imgTag(run.img); return }
    var css = styleText(run.style || {})
    var text = escapeText(run.text)
    out += css ? "<span style=\"" + css + "\">" + text + "</span>" : text
  })
  closeLink()
  return out
}

// ---- what the formatting bar shows --------------------------------------------------

function decorations(value) {
  return String(value || "").split(/\s+/).filter(function(token) { return token && token !== "none" })
}

function isBold(style) {
  var weight = String(style["font-weight"] || "")
  if (weight === "bold" || weight === "bolder") return true
  var n = parseInt(weight, 10)
  return isFinite(n) && n >= 600
}

function isItalic(style) {
  return /^(italic|oblique)$/.test(String(style["font-style"] || ""))
}

function hasDecoration(style, token) {
  return decorations(style["text-decoration"]).indexOf(token) >= 0
}

var MONO_FAMILIES = /monospace|mono\b|courier|consol/i

function isCode(style) {
  return MONO_FAMILIES.test(String(style["font-family"] || ""))
}

function textRuns(runs) {
  return runs.filter(function(run) { return run.text !== undefined && run.text.length > 0 })
}

// "all", "some" or "none" of the text has it.
function coverage(runs, test) {
  var list = textRuns(runs)
  if (list.length === 0) return "none"
  var count = 0
  list.forEach(function(run) { if (test(run)) count++ })
  return count === list.length ? "all" : count > 0 ? "some" : "none"
}

// One value if every run agrees, "" if none has one, null if they differ.
function common(runs, pick) {
  var list = textRuns(runs)
  var value
  for (var i = 0; i < list.length; i++) {
    var v = pick(list[i]) || ""
    if (value === undefined) value = v
    else if (value !== v) return null
  }
  return value === undefined ? "" : value
}

function summarize(inner) {
  var runs = parse(inner)
  return {
    bold: coverage(runs, function(r) { return isBold(r.style) }),
    italic: coverage(runs, function(r) { return isItalic(r.style) }),
    underline: coverage(runs, function(r) { return hasDecoration(r.style, "underline") }),
    strike: coverage(runs, function(r) { return hasDecoration(r.style, "line-through") }),
    code: coverage(runs, function(r) { return isCode(r.style) }),
    link: common(runs, function(r) { return r.href }),
    color: common(runs, function(r) { return normalColor(r.style.color) }),
    highlight: common(runs, function(r) { return normalColor(r.style["background-color"]) }),
    family: common(runs, function(r) { return unquoteFamily(r.style["font-family"]) }),
    size: common(runs, function(r) { return String(pxSize(r.style["font-size"]) || "") })
  }
}

function unquoteFamily(value) {
  var first = String(value || "").split(",")[0].trim()
  return first.replace(/^['"]|['"]$/g, "")
}

// "#AbC" / "#aabbcc" / "rgb(…)" -> "#aabbcc"; anything else as it was, lowercased.
function normalColor(value) {
  var v = String(value || "").trim().toLowerCase()
  if (!v) return ""
  var m = /^#([0-9a-f])([0-9a-f])([0-9a-f])$/.exec(v)
  if (m) return "#" + m[1] + m[1] + m[2] + m[2] + m[3] + m[3]
  if (/^#[0-9a-f]{6}$/.test(v)) return v
  m = /^rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)/.exec(v)
  if (m) return "#" + [m[1], m[2], m[3]].map(function(n) { return ("0" + Math.min(255, Number(n)).toString(16)).slice(-2) }).join("")
  return v
}

function pxSize(value) {
  var m = /^([0-9.]+)\s*(px|pt)?$/.exec(String(value || "").trim())
  if (!m) return 0
  var n = Number(m[1])
  return m[2] === "pt" ? Math.round(n * 4 / 3) : Math.round(n)
}

// The biggest text in it, in px (0: all of it the block's own size). Only
// text that shows counts; a big space draws nothing.
function maxSize(inner) {
  var max = 0
  parse(inner).forEach(function(run) {
    if (run.text === undefined || run.text.trim() === "") return
    var px = pxSize(run.style["font-size"])
    if (px > max) max = px
  })
  return max
}

// ---- changing it -----------------------------------------------------------------

function mapRuns(inner, change) {
  var runs = parse(inner).map(function(run) {
    if (run.text === undefined) return run
    var style = {}
    for (var key in run.style) style[key] = run.style[key]
    var next = change({ text: run.text, style: style, href: run.href }) || { text: run.text, style: style, href: run.href }
    return next
  })
  return serialize(merged(runs))
}

function setDecoration(style, token, on) {
  var tokens = decorations(style["text-decoration"]).filter(function(t) { return t !== token })
  if (on) tokens.push(token)
  if (tokens.length) style["text-decoration"] = tokens.join(" ")
  else delete style["text-decoration"]
}

// Bold, italic, underline, strikethrough or code: on for all of it unless all
// of it already has it, then off (like every word processor).
function toggle(inner, what, codeFamily) {
  var summary = summarize(inner)
  var on = summary[what] !== "all"
  return mapRuns(inner, function(run) {
    var s = run.style
    if (what === "bold") { if (on) s["font-weight"] = "700"; else delete s["font-weight"] }
    else if (what === "italic") { if (on) s["font-style"] = "italic"; else delete s["font-style"] }
    else if (what === "underline") setDecoration(s, "underline", on)
    else if (what === "strike") setDecoration(s, "line-through", on)
    else if (what === "code") {
      if (on) s["font-family"] = "'" + String(codeFamily || "monospace").replace(/'/g, "") + "'"
      else delete s["font-family"]
    }
    return run
  })
}

// Whether toggle(inner, what) would turn it on.
function wouldApply(inner, what) {
  return summarize(inner)[what] !== "all"
}

// Sets (or with an empty value, removes) one style property on all of it.
function setStyle(inner, property, value) {
  return mapRuns(inner, function(run) {
    if (value === "" || value === null || value === undefined) delete run.style[property]
    else run.style[property] = String(value)
    return run
  })
}

function setColor(inner, color) {
  return setStyle(inner, "color", color ? normalColor(color) : "")
}

function setHighlight(inner, color) {
  return setStyle(inner, "background-color", color ? normalColor(color) : "")
}

function setFamily(inner, family) {
  return setStyle(inner, "font-family", family ? "'" + String(family).replace(/'/g, "") + "'" : "")
}

function setSize(inner, px) {
  var n = Math.round(Number(px))
  return setStyle(inner, "font-size", isFinite(n) && n > 0 ? n + "px" : "")
}

// Swaps colors by a { "#from": "#to" } table (text and highlight colors), for
// showing the light-paper inks as their dark-paper twins and back.
function mapColors(inner, table) {
  if (!table || inner.indexOf("color") < 0) return inner
  return mapRuns(inner, function(run) {
    var c = normalColor(run.style.color)
    if (c && table[c]) run.style.color = table[c]
    var h = normalColor(run.style["background-color"])
    if (h && table[h]) run.style["background-color"] = table[h]
    return run
  })
}

// Links (or with an empty url, unlinks) all of it.
function setLink(inner, url) {
  return mapRuns(inner, function(run) {
    run.href = url ? String(url) : ""
    return run
  })
}

// Plain text again, but links and line breaks stay.
function clearFormatting(inner) {
  return mapRuns(inner, function(run) {
    run.style = {}
    return run
  })
}

// Pasted text keeps what it says (bold, italic, underline, strikethrough,
// links, line breaks) and drops how the page it came from looked (fonts,
// sizes, colors, backgrounds), unless keepLook: then only oddities go.
function sanitize(inner, keepLook) {
  var keep = keepLook
    ? ["font-weight", "font-style", "text-decoration", "color", "background-color", "font-family", "font-size", "vertical-align"]
    : ["font-weight", "font-style", "text-decoration", "vertical-align"]
  var runs = parse(inner).map(function(run) {
    if (run.img) return null
    if (run.text === undefined) return run
    var style = {}
    keep.forEach(function(key) { if (run.style[key]) style[key] = run.style[key] })
    if (style["font-weight"] && !isBold(style)) delete style["font-weight"]
    if (style["font-weight"]) style["font-weight"] = "700"
    if (style["font-style"] && !isItalic(style)) delete style["font-style"]
    if (style["text-decoration"]) {
      var tokens = decorations(style["text-decoration"]).filter(function(t) { return t === "underline" || t === "line-through" })
      if (tokens.length) style["text-decoration"] = tokens.join(" ")
      else delete style["text-decoration"]
    }
    if (style["vertical-align"] && !/^(sub|super)$/.test(style["vertical-align"])) delete style["vertical-align"]
    var href = /^(https?:|mailto:|file:)/i.test(run.href || "") || isInternal(run.href) ? run.href : ""
    return { text: run.text.replace(/[\u0000-\u0008\u000b-\u001f\u007f]/g, ""), style: style, href: href }
  }).filter(function(run) { return run && (run.br || run.text) })
  return serialize(merged(runs))
}

// ---- Qt's paragraph around it --------------------------------------------------

// The inside of the paragraph from Qt's HTML for a range (getFormattedText),
// without the colors Qt gives every link (Omanote draws links itself).
function extractInner(html) {
  var text = String(html || "")
  var start = text.indexOf("<!--StartFragment-->")
  var end = text.indexOf("<!--EndFragment-->")
  var inner
  if (start >= 0 && end >= start) {
    inner = text.slice(start + 20, end)
  } else if (end >= 0) {
    // Qt leaves the start marker out when the range starts a list item: the
    // text is then the inside of the block the end marker is in.
    var before = text.slice(0, end)
    var re = /<(p|li|h[1-6]|pre|blockquote|td|div)\b[^>]*>/gi
    var m
    var last = -1
    while ((m = re.exec(before)) !== null) last = m.index + m[0].length
    inner = last >= 0 ? before.slice(last) : before
  } else {
    var body = /<body[^>]*>([\s\S]*)<\/body>/i.exec(text)
    inner = body ? body[1] : text
    inner = inner.replace(/^\s*<p[^>]*>/i, "").replace(/<\/p>\s*$/i, "")
  }
  return normalizeLinks(inner)
}

function normalizeLinks(inner) {
  if (inner.indexOf("<a") < 0) return inner
  return mapRuns(inner, function(run) {
    if (run.href) {
      delete run.style.color
      if (run.style["text-decoration"] === "none") delete run.style["text-decoration"]
      setDecoration(run.style, "underline", false)
    }
    return run
  })
}

// Links inside Omanote (Pages): to a page, a date, a reminder.
//   omanote://page/<uuid>
//   omanote://date/2026-10-05, omanote://date/2026-10-05T09:30
//   omanote://remind/2026-10-05T09:30
var INTERNAL = /^omanote:\/\/(page\/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}|(date|remind)\/\d{4}-\d{2}-\d{2}(T\d{2}:\d{2})?)$/

function isInternal(url) {
  return INTERNAL.test(String(url || ""))
}

// The page a link goes to, or "".
function pageOf(url) {
  var m = /^omanote:\/\/page\/([0-9a-f-]{36})$/.exec(String(url || ""))
  return m && isInternal(url) ? m[1] : ""
}

// Links as Omanote draws them: the link color, underlined; a date or a
// reminder in the link color without the line.
function decorateLinks(inner, color) {
  if (inner.indexOf("<a") < 0) return inner
  return mapRuns(inner, function(run) {
    if (run.href) {
      run.style.color = normalColor(color) || "#2f6fd6"
      // (Qt underlines a link unless it's told not to.)
      if (/^omanote:\/\/(date|remind)\//.test(run.href)) run.style["text-decoration"] = "none"
      else setDecoration(run.style, "underline", true)
    }
    return run
  })
}

// Every link in it: [{ href, text }], a link split into runs as one.
function links(inner) {
  var out = []
  parse(inner).forEach(function(run) {
    if (run.text === undefined || !run.href) return
    var last = out[out.length - 1]
    if (last && last.href === run.href && last.open) last.text += run.text
    else out.push({ href: run.href, text: run.text, open: true })
  })
  return out.map(function(l) { return { href: l.href, text: l.text } })
}

// Links to pages written with the pages' names now: lookup(id) -> the text
// a link to it shows ("" to leave it as it is).
function refreshPageLinks(inner, lookup) {
  if (inner.indexOf("omanote://page/") < 0) return inner
  var runs = parse(inner)
  var out = []
  for (var i = 0; i < runs.length; i++) {
    var run = runs[i]
    var id = run.text !== undefined ? pageOf(run.href) : ""
    if (!id) { out.push(run); continue }
    // The link's runs become one, in the first run's look.
    var all = run.text
    while (i + 1 < runs.length && runs[i + 1].text !== undefined && runs[i + 1].href === run.href) all += runs[++i].text
    out.push({ text: lookup(id) || all, style: run.style, href: run.href })
  }
  return serialize(merged(out))
}

// The whole paragraph handed to a block's editor. Every line is exactly
// lineHeight tall with its baseline at 4/5 of it, whatever the font, which is
// what keeps text on the ruled lines. An empty paragraph needs Qt's own
// "empty" marker to keep its line height.
function wrapBlock(inner, lineHeight, linkColor) {
  var height = Math.max(1, Math.round(Number(lineHeight) || 30))
  // pre-wrap: spaces are kept as typed (Qt writes that in a stylesheet this
  // leaves out).
  var style = "white-space: pre-wrap; margin-top:0px; margin-bottom:0px; margin-left:0px; margin-right:0px; -qt-block-indent:0; text-indent:0px; "
    + "line-height:" + height + "px; -qt-line-height-type: fixed;"
  var content = String(inner || "")
  if (content === "") return "<p style=\"-qt-paragraph-type:empty; " + style + "\"><br /></p>"
  return "<p style=\"" + style + "\">" + decorateLinks(content, linkColor) + "</p>"
}

// ---- plain text -----------------------------------------------------------------

function plainText(inner) {
  return parse(inner).map(function(run) {
    if (run.br) return "\n"
    if (run.img) return ""
    return run.text.replace(/\u00a0/g, " ")
  }).join("")
}

// Plain text (with \n for line breaks) as a block's inside.
function fromPlainText(text) {
  return String(text || "").split(/\r?\n|\u2028/).map(escapeText).join("<br />")
}

// A link a person typed or pasted, made safe to open: http(s), mailto or file,
// else "" (a bare "example.com" gets https://).
function cleanUrl(text) {
  var url = String(text || "").trim()
  if (!url || url.length > 2000 || /[\u0000-\u001f\u007f\s]/.test(url)) return ""
  if (/^(https?:\/\/|mailto:|file:\/\/)/i.test(url)) return url
  if (/^[a-z][a-z0-9+.-]*:/i.test(url)) return ""
  if (/^[^\/@]+\.[a-z]{2,}(\/.*)?$/i.test(url)) return "https://" + url
  return ""
}
