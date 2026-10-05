// Export.js - a page of Pages (and the pages inside it, if you like) as one
// HTML document, for a PDF (Chromium makes it), a Word file (LibreOffice
// does) and printing.
//
// Everything in it is written here: what's on a page goes in as text,
// escaped, never as markup; links only to the web and email (a page's link to
// another page in it goes there, in the document). Pictures are named, not
// linked: src="uber-notebook-asset:<name>" (in Pages/assets) and
// "uber-notebook-drawing:<name>" (a diagram drawn for it), which the files
// helper puts in (bin/uber-notebook-files export-html) before anything reads
// it, refusing a document that would load anything from anywhere else.
// Equations and sketches go in drawn (SVG, as data: addresses). Its colors
// are a light page's, on white paper, as printed.
//
// What moves or plays is shown as it stands: a toggle open, a board's columns
// side by side, an audio note what was said, a video its picture, a mind map
// its ideas as a list.
//
// Shared by app/Exporter.qml and tests/export.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html
.import "Blocks.js" as Blocks
.import "Docs.js" as Docs
.import "Highlight.js" as Highlight
.import "Equations.js" as Equations
.import "Diagram.js" as Diagram
.import "Notes.js" as Notes
.import "Table.js" as Table
.import "Mindmap.js" as Mindmap
.import "Sketch.js" as Sketch
.import "Audio.js" as Audio
.import "Meeting.js" as Meeting
.import "Files.js" as Files
.import "Calendar.js" as Calendar
.import "Dates.js" as Dates
.import "Contacts.js" as Contacts

var INK = "#1f2430"
var FAINT = "#787774"
var LINE = "#e3e2de"
// A sheet's width for what's on it, in CSS pixels (A4 or Letter, less margins).
var PAGE_WIDTH = 660
var ASSET = "uber-notebook-asset:"
// Styles on the elements themselves, as well as in the sheet: LibreOffice
// (the Word file) reads those, not a class's.
var TABLE = "border-collapse:collapse;width:100%;"
var CELL = "border:1px solid " + LINE + ";padding:4px 8px;vertical-align:top;text-align:left;"
var HEAD = CELL + "background:#f7f6f3;font-weight:600;"
var DRAWING = "uber-notebook-drawing:"
// Synced blocks inside synced blocks: this deep at most.
var MAX_SYNCED = 3

// ---- text ------------------------------------------------------------------------------

function esc(text) {
  return String(text === undefined || text === null ? "" : text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;").replace(/'/g, "&#39;")
}

// A link that may be followed from a PDF or a Word file: the web or email.
function safeHref(url) {
  var u = String(url || "").trim()
  return /^(https?:\/\/[^\s"'<>\u0000-\u001f]{1,2000}|mailto:[^\s"'<>\u0000-\u001f]{1,500})$/i.test(u) ? u : ""
}

// A color as CSS may have it: a hex, one of Pages' names (as a light page has
// it), or a plain CSS name; else "".
function colorOf(value, background) {
  var v = String(value || "").trim().toLowerCase()
  if (/^#[0-9a-f]{3,8}$/.test(v)) return v
  var c = Docs.colorEntry(v)
  if (c) return background ? c.background[0] : c.text[0]
  return /^[a-z]{3,20}$/.test(v) ? v : ""
}

// A block's color ("blue", "blue_background") as a style.
function blockStyle(b) {
  var c = Docs.blockColors(b.color, false)
  var out = ""
  if (c.text) out += "color:" + c.text + ";"
  if (c.background) out += "background:" + c.background + ";padding:2px 4px;"
  if (b.align === "center" || b.align === "right" || b.align === "justify") out += "text-align:" + b.align + ";"
  return out
}

function attrStyle(style) { return style ? " style=\"" + esc(style) + "\"" : "" }

// ---- pictures in it -------------------------------------------------------------------

var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function utf8(text) {
  var s = String(text)
  var out = []
  for (var i = 0; i < s.length; i++) {
    var c = s.charCodeAt(i)
    if (c >= 0xd800 && c < 0xdc00 && i + 1 < s.length) {
      var d = s.charCodeAt(i + 1)
      if (d >= 0xdc00 && d < 0xe000) { c = 0x10000 + ((c - 0xd800) << 10) + (d - 0xdc00); i++ }
    }
    if (c < 0x80) out.push(c)
    else if (c < 0x800) out.push(0xc0 | (c >> 6), 0x80 | (c & 63))
    else if (c < 0x10000) out.push(0xe0 | (c >> 12), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
    else out.push(0xf0 | (c >> 18), 0x80 | ((c >> 12) & 63), 0x80 | ((c >> 6) & 63), 0x80 | (c & 63))
  }
  return out
}

function base64(text) {
  var b = utf8(text)
  var out = []
  for (var i = 0; i < b.length; i += 3) {
    var n = (b[i] << 16) | ((b[i + 1] || 0) << 8) | (b[i + 2] || 0)
    out.push(B64.charAt((n >> 18) & 63) + B64.charAt((n >> 12) & 63) + (i + 1 < b.length ? B64.charAt((n >> 6) & 63) : "=") + (i + 2 < b.length ? B64.charAt(n & 63) : "="))
  }
  return out.join("")
}

// An SVG drawn in, as a picture.
function svgImage(svg, width, height, alt, style) {
  return "<img src=\"data:image/svg+xml;base64," + base64(svg) + "\"" + (width ? " width=\"" + Math.round(width) + "\"" : "")
    + (height ? " height=\"" + Math.round(height) + "\"" : "") + " alt=\"" + esc(alt || "") + "\"" + attrStyle(style) + " />"
}

// A picture in Pages/assets ("assets/x.png"), named for the helper to put
// in; "" for one that isn't.
function assetImage(src, alt, style) {
  var s = String(src || "")
  if (!/^assets\/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(s) || s.indexOf("..") >= 0) return ""
  return "<img src=\"" + ASSET + s.slice(7) + "\" alt=\"" + esc(alt || "") + "\"" + attrStyle(style) + " />"
}

// ---- a block's words ------------------------------------------------------------------------

// `ctx`: { notes (the page's footnotes, in order), math(tex, display) -> svg
// or null, here(pageId) -> its anchor in the document or "", em (px) }.
function inline(inner, ctx) {
  var runs = Html.parse(String(inner || ""))
  var out = ""
  var lastHref = ""
  runs.forEach(function(run) {
    var seen = lastHref
    lastHref = run.href || ""
    if (run.br) { out += "<br />"; lastHref = ""; return }
    if (run.img) return
    var href = String(run.href || "").replace(/^omanote:\/\//, "uber-notebook://")
    // A footnote: its number (its words at the page's end).
    if (Notes.isLink(href)) {
      if (seen === run.href) return
      var words = Notes.textOf(href)
      var n = ctx.notes.indexOf(words)
      if (n < 0) { ctx.notes.push(words); n = ctx.notes.length - 1 }
      out += "<sup class=\"fn\">" + (n + 1) + "</sup>"
      return
    }
    // An equation in the line, drawn (or its LaTeX, if it couldn't be).
    if (Equations.isLink(href)) {
      if (seen === run.href) return
      out += mathImage(Equations.texOf(href), false, ctx)
      return
    }
    var text = esc(run.text).replace(/\n/g, "<br />")
    if (!text) return
    var s = run.style || {}
    if (Html.isCode(s)) text = "<code>" + text + "</code>"
    if (Html.isBold(s)) text = "<strong>" + text + "</strong>"
    if (Html.isItalic(s)) text = "<em>" + text + "</em>"
    if (Html.hasDecoration(s, "underline")) text = "<u>" + text + "</u>"
    if (Html.hasDecoration(s, "line-through")) text = "<s>" + text + "</s>"
    if (s["vertical-align"] === "super") text = "<sup>" + text + "</sup>"
    else if (s["vertical-align"] === "sub") text = "<sub>" + text + "</sub>"
    var css = ""
    var color = colorOf(s.color, false)
    if (color) css += "color:" + color + ";"
    var size = /^(\d{1,3})px$/.exec(String(s["font-size"] || ""))
    if (size) css += "font-size:" + Math.max(8, Math.min(72, Number(size[1]))) + "px;"
    if (css) text = "<span style=\"" + css + "\">" + text + "</span>"
    var mark = colorOf(s["background-color"], true)
    if (mark) text = "<mark style=\"background:" + mark + ";\">" + text + "</mark>"
    var web = safeHref(href)
    var page = /^uber-notebook:\/\/page\/([0-9a-f-]{36})/.exec(href)
    var anchor = page && typeof ctx.here === "function" ? ctx.here(page[1]) : ""
    if (web) text = "<a href=\"" + esc(web) + "\">" + text + "</a>"
    else if (anchor) text = "<a href=\"#" + anchor + "\">" + text + "</a>"
    out += text
  })
  return out
}

// An equation, drawn: in a line (`display` false) or on its own.
function mathImage(tex, display, ctx) {
  var em = (ctx.em || 16) * (display ? 1.25 : Equations.INLINE_SCALE)
  var svg = typeof ctx.math === "function" ? ctx.math(tex, display) : null
  var d = svg ? Equations.sized(svg, em, INK) : null
  if (!d) return "<code class=\"tex\">" + esc(tex) + "</code>"
  return svgImage(d.svg, d.width, d.height, tex, display ? "" : "vertical-align:" + (-d.depth).toFixed(1) + "px;")
}

// ---- blocks ------------------------------------------------------------------------------

var LISTS = { bullet: "ul", toggle: "ul", check: "ul", number: "ol" }

// A page's blocks as HTML. `ctx` as inline's, and page, lookup(id) ->
// { title, icon }, drawing(blockId) -> a drawn diagram's name, calendar,
// contactOf(id), syncedPage(id), depth (synced blocks within).
function blocksHtml(ids, ctx) {
  var blocks = ctx.page.blocks || {}
  var out = []
  var k = 0
  var list = (ids || []).filter(function(id) { return !!blocks[id] })
  while (k < list.length) {
    var b = blocks[list[k]]
    var tag = LISTS[b.type]
    if (tag) {
      // A run of list items of one kind, a list.
      var items = []
      while (k < list.length && LISTS[blocks[list[k]].type] === tag && (tag === "ol") === (blocks[list[k]].type === "number")) {
        var item = blocks[list[k]]
        // (Bullets, to-dos and toggles each a list of their own.)
        if (tag === "ul" && items.length && item.type !== blocks[list[k - 1]].type) break
        items.push(item)
        k++
      }
      var kind = items[0].type === "check" ? " class=\"checks\"" : items[0].type === "toggle" ? " class=\"toggles\"" : ""
      out.push("<" + tag + kind + ">" + items.map(function(it) { return listItem(it, ctx) }).join("") + "</" + tag + ">")
      continue
    }
    if (b.type === "habit") {
      var run = []
      while (k < list.length && blocks[list[k]].type === "habit") { run.push(blocks[list[k]]); k++ }
      out.push(habitTable(run, ctx))
      continue
    }
    out.push(block(b, ctx))
    k++
  }
  return out.join("\n")
}

function listItem(b, ctx) {
  var text = inline(b.html || "", ctx)
  // (Drawn as text, not as an emoji: \ufe0e.)
  var box = b.type === "check" ? "<span class=\"box\">" + (b.checked ? "\u2611\ufe0e" : "\u2610\ufe0e") + "</span> " : ""
  var kids = b.content && b.content.length ? blocksHtml(b.content, ctx) : ""
  var css = blockStyle(b) + (b.type === "check" && b.checked ? "color:" + FAINT + ";" : "")
  return "<li id=\"b-" + esc(b.id) + "\"" + attrStyle(css) + ">" + box + (text || "&#8203;") + kids + "</li>"
}

function block(b, ctx) {
  var id = " id=\"b-" + esc(b.id) + "\""
  var style = attrStyle(blockStyle(b))
  var kids = b.content && b.content.length ? blocksHtml(b.content, ctx) : ""
  var text = Blocks.isText(b.type) ? inline(b.html || "", ctx) : ""
  switch (b.type) {
  case "p":
    return "<p" + id + style + ">" + (text || "&#8203;") + "</p>" + (kids ? "<div class=\"in\">" + kids + "</div>" : "")
  case "h1": case "h2": case "h3":
    return "<" + b.type + id + style + ">" + (text || "&#8203;") + "</" + b.type + ">" + kids
  case "quote":
    return "<blockquote" + id + attrStyle("border-left:3px solid " + INK + ";padding-left:14px;" + blockStyle(b)) + "><p>" + text + "</p>" + kids + "</blockquote>"
  case "callout":
    var back = Docs.blockColors(b.color, false).background || Docs.calloutBackground(false)
    var fore = Docs.blockColors(b.color, false).text
    return "<table class=\"callout\"" + id + " style=\"" + TABLE + "\"><tr><td class=\"icon\" style=\"width:1.6em;vertical-align:top;padding:10px 0 10px 12px;background:" + back + ";\">" + esc(b.icon || "\u{1f4a1}") + "</td><td style=\"vertical-align:top;padding:10px 12px;background:" + back + ";" + (fore ? "color:" + fore + ";" : "") + "\">"
      + "<p>" + text + "</p>" + kids + "</td></tr></table>"
  case "code":
    return code(b, ctx, id)
  case "divider":
    return "<hr" + id + " />"
  case "image":
    var w = Math.max(0.15, Math.min(1, Number(b.width) || 1))
    var pic = assetImage(b.src, "A picture", "width:" + Math.round(w * 100) + "%;")
    // (Its size in pixels is the files helper's to put in, from the picture's own.)
    return pic ? "<p class=\"pic\"" + id + " style=\"text-align:" + (b.align === "left" || b.align === "right" ? b.align : "center") + ";\">" + pic + "</p>" : ""
  case "gallery":
    return gallery(b, id)
  case "page":
    return pageLine(b.id, false, ctx, id)
  case "link":
    return pageLine(b.target, true, ctx, id)
  case "toc":
    return toc(ctx, id)
  case "columns":
    var cols = (b.content || []).map(function(cid) { return ctx.page.blocks[cid] }).filter(function(c) { return c && c.type === "column" })
    if (!cols.length) return ""
    var total = 0
    cols.forEach(function(c) { total += Number(c.width) > 0 ? Number(c.width) : 1 })
    return "<table class=\"cols\"" + id + " style=\"" + TABLE + "\"><tr>" + cols.map(function(c) {
      var share = (Number(c.width) > 0 ? Number(c.width) : 1) / total
      return "<td style=\"width:" + Math.round(share * 100) + "%;vertical-align:top;padding:0 10px 0 0;\">" + blocksHtml(c.content || [], ctx) + "</td>"
    }).join("") + "</tr></table>"
  case "column":
    return kids
  case "mindmap":
    var tree = Mindmap.parse(b.outline || "")
    return tree ? "<div class=\"mindmap\"" + id + "><p><strong>" + esc(tree.text) + "</strong></p>" + ideas(tree.children) + "</div>" : ""
  case "table":
    return table(b.table, ctx, id)
  case "sketch":
    var svg = Sketch.toSvg(b.sketch, "")
    var sw = /\swidth="([\d.]+)"/.exec(svg)
    var sh = /\sheight="([\d.]+)"/.exec(svg)
    var scale = sw && sh ? Math.min(1, PAGE_WIDTH / Number(sw[1])) : 0
    return "<p class=\"pic\"" + id + ">" + svgImage(svg, scale ? Number(sw[1]) * scale : 0, scale ? Number(sh[1]) * scale : 0, "A sketch", scale ? "" : "width:100%;") + "</p>"
  case "audio":
    var au = b.audio || {}
    return "<div class=\"card\"" + id + "><p>\u{1f399}\u{fe0f} <strong>Audio note</strong>" + (au.duration ? " \u00b7 " + esc(Audio.clock(au.duration)) : "") + "</p>"
      + (au.transcript ? "<blockquote><p>" + esc(au.transcript).replace(/\n/g, "<br />") + "</p></blockquote>" : "") + "</div>"
  case "meeting":
    return meeting(b.meeting, id)
  case "board":
    return board(b.data, id)
  case "file": case "video":
    return fileCard(b.data, b.type, id)
  case "bookmark":
    return bookmark(b.data, id)
  case "email":
    return email(b.data, id)
  case "contact":
    return contact(b.data, ctx, id)
  case "agenda": case "event":
    return calendarLines(b, ctx, id)
  case "calendar":
    return month(b, id)
  case "synced":
    return synced(b, ctx, id)
  case "button":
    return ""
  }
  return text ? "<p" + id + style + ">" + text + "</p>" + kids : kids
}

// Code in its colors; an equation drawn; a diagram as the picture drawn of it
// (or its Mermaid, when there's none).
function code(b, ctx, id) {
  var src = Html.plainText(b.html || "")
  if (Equations.isLang(b.lang)) return "<p class=\"math\"" + id + ">" + mathImage(src, true, ctx) + "</p>"
  if (Diagram.isLang(b.lang)) {
    var name = typeof ctx.drawing === "function" ? String(ctx.drawing(b.id) || "") : ""
    if (/^[A-Za-z0-9][A-Za-z0-9._-]{0,80}\.png$/.test(name)) return "<p class=\"pic\"" + id + "><img src=\"" + DRAWING + name + "\" alt=\"A diagram\" style=\"max-width:100%;\" /></p>"
  }
  var lang = String(b.lang || "").trim()
  return "<pre class=\"code\"" + id + " style=\"background:#f7f6f3;padding:10px 12px;\">" + (lang ? "<span class=\"lang\">" + esc(lang) + "</span><br />" : "") + Highlight.html(src, lang, false) + "</pre>"
}

function gallery(b, id) {
  var d = b.data || {}
  var images = (d.images || []).filter(function(x) { return x && x.src })
  if (!images.length) return ""
  var n = Math.max(2, Math.min(4, Number(d.columns) || 3))
  var rows = []
  for (var i = 0; i < images.length; i += n) {
    var cells = images.slice(i, i + n).map(function(x) {
      return "<td style=\"width:" + Math.floor(100 / n) + "%;vertical-align:top;padding:4px;\">" + assetImage(x.src, x.caption || "A picture", "width:" + (Math.floor(100 / n) - 2) + "%;") + (x.caption ? "<p class=\"caption\">" + esc(x.caption) + "</p>" : "") + "</td>"
    })
    while (cells.length < n) cells.push("<td></td>")
    rows.push("<tr>" + cells.join("") + "</tr>")
  }
  return "<table class=\"gallery\"" + id + " style=\"" + TABLE + "\">" + rows.join("") + "</table>"
}

// A page on it, or a link to one: its icon and title (a link to it, when
// it's in the document).
function pageLine(pid, arrow, ctx, id) {
  var p = typeof ctx.lookup === "function" ? ctx.lookup(pid) : null
  if (!p) return ""
  var label = esc((p.icon ? p.icon + " " : "\u{1f4c4} ") + (p.title || "Untitled")) + (arrow ? " \u2197" : "")
  var anchor = typeof ctx.here === "function" ? ctx.here(pid) : ""
  return "<p class=\"pagelink\"" + id + ">" + (anchor ? "<a href=\"#" + anchor + "\">" + label + "</a>" : label) + "</p>"
}

// The page's headings, as a list.
function toc(ctx, id) {
  var heads = []
  ;(function walk(ids) {
    (ids || []).forEach(function(bid) {
      var b = ctx.page.blocks[bid]
      if (!b) return
      if (b.type === "h1" || b.type === "h2" || b.type === "h3") heads.push(b)
      if (b.content) walk(b.content)
    })
  })(ctx.page.content)
  if (!heads.length) return ""
  return "<div class=\"toc\"" + id + ">" + heads.map(function(h) {
    return "<p class=\"toc" + h.type.charAt(1) + "\"><a href=\"#b-" + esc(h.id) + "\">" + esc(Html.plainText(h.html || "") || "Untitled") + "</a></p>"
  }).join("") + "</div>"
}

function ideas(list) {
  if (!list || !list.length) return ""
  return "<ul>" + list.map(function(n) { return "<li>" + esc(n.text) + ideas(n.children) + "</li>" }).join("") + "</ul>"
}

function table(t, ctx, id) {
  if (!t || !t.rows || !t.rows.length) return ""
  var widths = t.widths && t.widths.length === t.rows[0].length ? t.widths : null
  var head = widths ? "<colgroup>" + widths.map(function(w) { return "<col width=\"" + Math.round(w * 100) + "%\" />" }).join("") + "</colgroup>" : ""
  var rows = t.rows.map(function(row, r) {
    var th = r === 0 && t.header !== false
    return "<tr>" + row.map(function(cell, c) {
      var col = Table.colorOf(t, r, c)
      var css = (colorOf(col.color, false) ? "color:" + colorOf(col.color, false) + ";" : "") + (colorOf(col.background, true) ? "background:" + colorOf(col.background, true) + ";" : "")
      var tag = th ? "th" : "td"
      return "<" + tag + attrStyle((th ? HEAD : CELL) + css) + ">" + (inline(cell, ctx) || "&#8203;") + "</" + tag + ">"
    }).join("") + "</tr>"
  })
  return "<table class=\"grid\"" + id + " style=\"" + TABLE + "\">" + head + rows.join("") + "</table>"
}

function meeting(m, id) {
  if (!m) return ""
  var head = "<p>\u{1f465} <strong>" + esc(m.title || "Meeting") + "</strong>" + (m.duration ? " \u00b7 " + esc(Audio.clock(m.duration)) : "") + "</p>"
  var turns = Meeting.turns(m).map(function(t) {
    return "<p><strong>" + esc(Meeting.speakerName(m, t.speaker)) + "</strong> <span class=\"faint\">" + esc(Audio.clock(t.start / 1000)) + "</span><br />" + esc(t.text) + "</p>"
  })
  return "<div class=\"card\"" + id + ">" + head + turns.join("") + "</div>"
}

function board(d, id) {
  if (!d || !d.columns || !d.columns.length) return ""
  return "<table class=\"board\"" + id + " style=\"" + TABLE + "\"><tr>" + d.columns.map(function(c) {
    return "<th style=\"" + HEAD + "\">" + esc(c.name || "Column") + "</th>"
  }).join("") + "</tr><tr>" + d.columns.map(function(c) {
    return "<td style=\"" + CELL + "\">" + (c.cards || []).map(function(k) { return "<p class=\"cardline\">" + esc(k.text || "Untitled") + "</p>" }).join("") + "</td>"
  }).join("") + "</tr></table>"
}

function fileCard(d, type, id) {
  if (!d || !d.src) return ""
  var icon = type === "video" ? "\u{1f3ac}" : d.kind === "pdf" ? "\u{1f4c4}" : "\u{1f4ce}"
  var poster = type === "video" && d.poster ? assetImage(d.poster, d.name || "A video", "width:100%;") : ""
  return "<div class=\"card\"" + id + ">" + (poster ? "<p class=\"pic\">" + poster + "</p>" : "")
    + "<p>" + icon + " " + esc(d.name || "A file") + (d.size ? " <span class=\"faint\">(" + esc(Files.sizeLabel(d.size)) + ")</span>" : "") + "</p></div>"
}

function bookmark(d, id) {
  if (!d || !d.url) return ""
  var url = safeHref(d.url)
  var title = esc(d.title || d.url)
  var pic = d.image ? assetImage(d.image, "", "width:120px;") : ""
  return "<table class=\"bookmark\"" + id + " style=\"" + TABLE + "\"><tr><td style=\"" + CELL + "padding:8px 12px;\">"
    + "<p><strong>" + (url ? "<a href=\"" + esc(url) + "\">" + title + "</a>" : title) + "</strong></p>"
    + (d.description ? "<p class=\"faint\">" + esc(d.description) + "</p>" : "")
    + "<p class=\"faint\">" + esc(d.site || d.url) + "</p></td>" + (pic ? "<td class=\"thumb\" style=\"" + CELL + "width:130px;\">" + pic + "</td>" : "") + "</tr></table>"
}

function email(d, id) {
  if (!d || !d.src) return ""
  var lines = ["<p>\u2709 <strong>" + esc(d.subject || "(no subject)") + "</strong></p>",
    "<p class=\"faint\">From " + esc(d.from || "?") + (d.to ? " \u00b7 to " + esc(d.to) : "") + (d.date ? " \u00b7 " + esc(String(d.date).slice(0, 10)) : "") + "</p>"]
  if (d.preview) lines.push("<p>" + esc(d.preview) + "</p>")
  var att = (d.attachments || []).map(function(a) { return a && a.name ? esc(a.name) : "" }).filter(function(x) { return x })
  if (att.length) lines.push("<p class=\"faint\">\u{1f4ce} " + att.join(", ") + "</p>")
  return "<div class=\"card\"" + id + ">" + lines.join("") + "</div>"
}

function contact(d, ctx, id) {
  if (!d || !d.contact) return ""
  var c = typeof ctx.contactOf === "function" ? ctx.contactOf(d.contact) : null
  if (!c) return "<p" + id + "><strong>" + esc(d.name || "Someone") + "</strong></p>"
  var lines = ["<p><strong>" + esc(Contacts.nameOf(c)) + "</strong>" + (Contacts.subtitle(c) ? " <span class=\"faint\">\u00b7 " + esc(Contacts.subtitle(c)) + "</span>" : "") + "</p>"]
  ;(c.phones || []).forEach(function(p) { lines.push("<p>\u260e " + esc(p.value) + (p.label ? " <span class=\"faint\">(" + esc(p.label) + ")</span>" : "") + "</p>") })
  ;(c.emails || []).forEach(function(e) {
    var m = safeHref("mailto:" + e.value)
    lines.push("<p>\u2709 " + (m ? "<a href=\"" + esc(m) + "\">" + esc(e.value) + "</a>" : esc(e.value)) + "</p>")
  })
  return "<div class=\"card\"" + id + ">" + lines.join("") + "</div>"
}

// An agenda (the day's events) or an event, as the calendar has them.
function calendarLines(b, ctx, id) {
  var cal = ctx.calendar
  var ref = b.calendar || {}
  var now = new Date()
  if (b.type === "event") {
    var ev = cal ? Calendar.byId(cal, ref.id) : null
    return ev ? "<p" + id + ">\u{1f4c5} " + esc(Calendar.line(Calendar.nextOf(ev, now), now)) + "</p>" : ""
  }
  var d = ref.day ? Dates.fromIso(ref.day).at : new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var head = "<p><strong>\u{1f4c5} " + esc(Dates.label(d, false, now)) + "</strong></p>"
  var list = cal ? Calendar.occurrences(cal, d, new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1)) : []
  var items = list.map(function(o) { return "<li>" + esc(Calendar.span(o, d)) + ": " + esc(o.title || "Untitled") + (o.place ? " <span class=\"faint\">(" + esc(o.place) + ")</span>" : "") + "</li>" })
  return "<div" + id + ">" + head + (items.length ? "<ul>" + items.join("") + "</ul>" : "<p class=\"faint\">Nothing on the calendar</p>") + "</div>"
}

var WEEKDAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

function habitTable(list, ctx) {
  var rows = list.map(function(b) {
    var days = String(b.days || "").split("")
    return "<tr><td style=\"" + CELL + "\">" + (inline(b.html || "", ctx) || "&#8203;") + "</td>" + WEEKDAYS.map(function(w, i) { return "<td class=\"day\" style=\"" + CELL + "text-align:center;\">" + (days[i] === "1" ? "\u2713" : "") + "</td>" }).join("") + "</tr>"
  })
  return "<table class=\"grid\" style=\"" + TABLE + "\"><tr><th style=\"" + HEAD + "\">Habit</th>" + WEEKDAYS.map(function(w) { return "<th class=\"day\" style=\"" + HEAD + "text-align:center;\">" + w + "</th>" }).join("") + "</tr>" + rows.join("") + "</table>"
}

function month(b, id) {
  if (!/^\d{4}-\d{2}$/.test(String(b.month || ""))) return ""
  var layout = Blocks.monthLayout(b.month)
  var name = MONTHS[Number(String(b.month).slice(5, 7)) - 1] + " " + String(b.month).slice(0, 4)
  var rows = []
  for (var w = 0; w < layout.weeks; w++) {
    var cells = []
    for (var c = 0; c < 7; c++) {
      var day = w * 7 + c - layout.offset + 1
      var shown = day < 1 || day > layout.days ? "" : Blocks.hasMark(b.marks || "", day) ? "<strong>(" + day + ")</strong>" : String(day)
      cells.push("<td class=\"day\" style=\"" + CELL + "text-align:center;\">" + shown + "</td>")
    }
    rows.push("<tr>" + cells.join("") + "</tr>")
  }
  return "<div class=\"month\"" + id + "><p><strong>" + esc(name) + "</strong></p><table class=\"grid\" style=\"" + TABLE + "\"><tr>" + WEEKDAYS.map(function(x) { return "<th class=\"day\" style=\"" + HEAD + "text-align:center;\">" + x + "</th>" }).join("") + "</tr>" + rows.join("") + "</table></div>"
}

// A synced block: its page's blocks (not too deep).
function synced(b, ctx, id) {
  var pid = b.data ? b.data.page : ""
  var p = pid && (ctx.depth || 0) < MAX_SYNCED && typeof ctx.syncedPage === "function" ? ctx.syncedPage(pid) : null
  if (!p) return ""
  var sub = { page: p, notes: ctx.notes, math: ctx.math, here: ctx.here, em: ctx.em, lookup: ctx.lookup, drawing: ctx.drawing,
    calendar: ctx.calendar, contactOf: ctx.contactOf, syncedPage: ctx.syncedPage, depth: (ctx.depth || 0) + 1 }
  return "<div class=\"synced\"" + id + ">" + blocksHtml(p.content || [], sub) + "</div>"
}

// ---- the document ---------------------------------------------------------------------------

function anchorOf(pid) { return "p-" + pid }

// One page, as a section: its cover, icon and title, its project line, its
// blocks, its footnotes.
function pageSection(page, o, first) {
  var ctx = {
    page: page, notes: [], math: o.math, em: o.small ? 14 : 16, lookup: o.lookup, drawing: o.drawing,
    calendar: o.calendar, contactOf: o.contactOf, syncedPage: o.syncedPage, depth: 0,
    here: function(pid) { return o.included && o.included[pid] ? anchorOf(pid) : "" }
  }
  var out = ["<section class=\"page" + (first ? "" : " next") + "\" id=\"" + esc(anchorOf(page.id)) + "\">"]
  var cover = String(page.cover || "")
  var stops = Docs.coverStops(cover)
  if (stops) out.push("<div class=\"cover\" style=\"background:linear-gradient(90deg," + stops.join(",") + ");\"></div>")
  else if (/^assets\//.test(cover)) { var c = assetImage(cover, "", "width:100%;max-height:200px;"); if (c) out.push("<p class=\"cover\">" + c + "</p>") }
  // (A page after the first starts a sheet: on its title too, which LibreOffice reads.)
  out.push("<h1 class=\"title\"" + (first ? "" : " style=\"page-break-before:always;\"") + ">" + (page.icon ? "<span class=\"icon\">" + esc(page.icon) + "</span> " : "") + esc(page.title || "Untitled") + "</h1>")
  if (page.project) out.push("<p class=\"faint\">" + esc(String(page.project.status || "").replace(/^./, function(x) { return x.toUpperCase() })) + (page.project.due ? " \u00b7 due " + esc(page.project.due) : "") + "</p>")
  out.push(blocksHtml(page.content || [], ctx))
  if (ctx.notes.length) out.push("<ol class=\"notes\">" + ctx.notes.map(function(t) { return "<li>" + esc(t) + "</li>" }).join("") + "</ol>")
  out.push("</section>")
  return out.join("\n")
}

// The document: `pages` ([page], the first the one asked for), and `o`:
// { title, paper ("A4" or "Letter"), small, font ("sans", "serif",
// "mono"), lookup(id) -> { title, icon }, math(tex, display) -> svg or null,
// drawing(blockId) -> name, calendar, contactOf(id), syncedPage(id) }.
function toHtml(pages, options) {
  var o = options || {}
  var list = (pages || []).filter(function(p) { return p && p.id })
  var included = {}
  list.forEach(function(p) { included[p.id] = true })
  var opts = {}
  for (var k in o) opts[k] = o[k]
  opts.included = included
  var families = Docs.font(o.font).families.map(function(f) { return "\"" + f.replace(/["\\]/g, "") + "\"" }).join(", ")
  var generic = o.font === "serif" ? "serif" : o.font === "mono" ? "monospace" : "sans-serif"
  var size = o.small ? 14 : 16
  var paper = o.paper === "Letter" ? "letter" : "A4"
  var title = esc(o.title || (list[0] ? list[0].title : "") || "Untitled")
  return "<!doctype html>\n<html><head><meta charset=\"utf-8\" />\n"
    + "<meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; img-src data:; style-src 'unsafe-inline'\" />\n"
    + "<title>" + title + "</title>\n<style>\n" + css(families + ", " + generic, size, paper) + "</style></head>\n<body>\n"
    + list.map(function(p, i) { return pageSection(p, opts, i === 0) }).join("\n") + "\n</body></html>\n"
}

function css(family, size, paper) {
  return [
    "@page { size: " + paper + "; margin: 18mm 16mm; }",
    "html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }",
    "body { font-family: " + family + "; font-size: " + size + "px; line-height: 1.5; color: " + INK + "; background: #ffffff; margin: 0; }",
    "section.next { break-before: page; page-break-before: always; }",
    "h1, h2, h3 { font-family: " + family + "; line-height: 1.3; margin: 1.1em 0 0.3em; break-after: avoid; page-break-after: avoid; }",
    "h1 { font-size: " + Math.round(size * 1.85) + "px; } h2 { font-size: " + Math.round(size * 1.5) + "px; } h3 { font-size: " + Math.round(size * 1.25) + "px; }",
    "h1.title { font-size: " + Math.round(size * 2.4) + "px; margin: 0.2em 0 0.4em; }",
    "p { margin: 0.25em 0; white-space: pre-wrap; }",
    "a { color: #337ea9; }",
    "code { font-family: \"iA Writer Mono S\", \"JetBrainsMono Nerd Font\", \"Noto Sans Mono\", monospace; font-size: 0.9em; background: #f1f1ef; padding: 0 3px; border-radius: 3px; }",
    "pre.code { font-family: \"iA Writer Mono S\", \"JetBrainsMono Nerd Font\", \"Noto Sans Mono\", monospace; font-size: " + Math.round(size * 0.85) + "px; background: #f7f6f3; padding: 10px 12px; border-radius: 4px; white-space: pre-wrap; word-wrap: break-word; }",
    "pre.code .lang { color: " + FAINT + "; font-size: 0.85em; }",
    "blockquote { margin: 0.5em 0; padding-left: 14px; border-left: 3px solid " + INK + "; }",
    "ul, ol { margin: 0.2em 0; padding-left: 1.6em; }",
    "ul.checks { list-style: none; padding-left: 0.4em; } ul.checks ul.checks { padding-left: 1.6em; }",
    "ul.toggles { list-style-type: \"\u25b8  \"; }",
    "li { margin: 0.1em 0; } .box { font-size: 1.1em; }",
    "hr { border: none; border-top: 1px solid " + LINE + "; margin: 1em 0; }",
    "table { border-collapse: collapse; width: 100%; margin: 0.5em 0; break-inside: auto; }",
    "table.grid th, table.grid td, table.board th, table.board td { border: 1px solid " + LINE + "; padding: 4px 8px; vertical-align: top; text-align: left; }",
    "table.grid th, table.board th { background: #f7f6f3; font-weight: 600; }",
    "td.day, th.day { text-align: center; width: 2.4em; }",
    "table.cols td { vertical-align: top; padding: 0 10px 0 0; }",
    "table.callout td { vertical-align: top; padding: 10px 12px; } table.callout td.icon { width: 1.6em; padding-right: 0; background: transparent; }",
    "table.gallery td { vertical-align: top; padding: 4px; }",
    "table.bookmark td { border: 1px solid " + LINE + "; padding: 8px 12px; vertical-align: top; } table.bookmark td.thumb { width: 130px; }",
    ".card { border: 1px solid " + LINE + "; border-radius: 4px; padding: 6px 12px; margin: 0.5em 0; break-inside: avoid; }",
    ".faint { color: " + FAINT + "; } .caption { color: " + FAINT + "; font-size: 0.85em; text-align: center; }",
    "p.pic, p.math { text-align: center; margin: 0.6em 0; } img { max-width: 100%; break-inside: avoid; }",
    // (A tall picture no taller than half a sheet, so it stays by what it's under.)
    "img { height: auto; }",
    "tr { break-inside: avoid; page-break-inside: avoid; } div.month, .mindmap { break-inside: avoid; page-break-inside: avoid; }",
    "p.pagelink a { color: " + INK + "; }",
    "div.cover { height: 150px; margin: 0 0 1em; border-radius: 4px; } p.cover { margin: 0 0 1em; text-align: center; }",
    "div.toc p { margin: 0.1em 0; } p.toc2 { padding-left: 1.2em; } p.toc3 { padding-left: 2.4em; }",
    "mark { padding: 0 2px; } sup.fn { font-size: 0.7em; }",
    "ol.notes { border-top: 1px solid " + LINE + "; margin-top: 2em; padding-top: 0.6em; font-size: 0.85em; color: " + FAINT + "; }",
    "div.in { padding-left: 1.6em; }",
    ""
  ].join("\n")
}
