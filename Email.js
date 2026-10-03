// Email.js - emails on pages in Pages (an .eml: one message in the standard
// internet format, RFC 5322 and MIME). It reads one: its headers (subjects
// and names in any charset, =?UTF-8?B?...?=), its plain and HTML bodies
// (base64, quoted-printable; UTF-8, Latin-1, Windows-1252), its attachments
// (their names, also RFC 2231's), and makes its HTML safe to show (no
// scripts, styles, pictures from the web or anything that runs; links to
// web pages and emails kept). An email block keeps the .eml in Pages/assets
// and what it says about itself, for the Library, search and agents:
//
//   { src: "assets/mail-20261002-093000-k3f-launch.eml", name: "Launch.eml", size: 52311,
//     subject: "Launch plan", from: "Sam Rivera <sam@acme.com>", to: "team@acme.com",
//     cc: "", date: "2026-10-02T07:30:00.000Z", preview: "Hi team, the launch...",
//     attachments: [{ name: "plan.pdf", size: 18342, type: "application/pdf", src: "" }],
//     open: false, color: "", background: "" }
//
// Shared with tests/email.test.cjs, so keep it plain JavaScript with no QML
// or Node APIs.
.pragma library
.import "Files.js" as Files

var MAX_PREVIEW = 600
var MAX_ATTACHMENTS = 50
var MAX_HTML = 400000

function line(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max || 300)
}

// ---- bytes ---------------------------------------------------------------------------------

var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

function base64Bytes(text) {
  var s = String(text || "").replace(/[^A-Za-z0-9+\/]/g, "")
  var out = []
  var buf = 0
  var bits = 0
  for (var i = 0; i < s.length; i++) {
    buf = (buf << 6) | B64.indexOf(s.charAt(i))
    bits += 6
    if (bits >= 8) {
      bits -= 8
      out.push((buf >> bits) & 0xff)
    }
  }
  return out
}

function bytesBase64(bytes) {
  var out = ""
  for (var i = 0; i < bytes.length; i += 3) {
    var a = bytes[i], b = bytes[i + 1], c = bytes[i + 2]
    var n = (a << 16) | ((b || 0) << 8) | (c || 0)
    out += B64.charAt((n >> 18) & 63) + B64.charAt((n >> 12) & 63)
      + (b === undefined ? "=" : B64.charAt((n >> 6) & 63))
      + (c === undefined ? "=" : B64.charAt(n & 63))
  }
  return out
}

// "=C3=A9" and soft line breaks ("=" at a line's end), as bytes.
function quotedBytes(text, inHeader) {
  var s = String(text || "").replace(/=\r?\n/g, "")
  if (inHeader) s = s.replace(/_/g, " ")
  var out = []
  for (var i = 0; i < s.length; i++) {
    var ch = s.charAt(i)
    if (ch === "=" && /^[0-9A-Fa-f]{2}$/.test(s.substr(i + 1, 2))) { out.push(parseInt(s.substr(i + 1, 2), 16)); i += 2 }
    else {
      var code = s.charCodeAt(i)
      if (code < 0x80) out.push(code)
      else utf8Of(ch).forEach(function(b) { out.push(b) })
    }
  }
  return out
}

// A string's characters as bytes (what's read is each byte a character
// when it came in raw: 8bit mail read as text keeps its UTF-8).
function rawBytes(text) {
  var out = []
  var s = String(text || "")
  for (var i = 0; i < s.length; i++) {
    var code = s.charCodeAt(i)
    if (code < 0x80) out.push(code)
    else utf8Of(s.charAt(i)).forEach(function(b) { out.push(b) })
  }
  return out
}

function utf8Of(ch) {
  var cp = ch.codePointAt ? ch.codePointAt(0) : ch.charCodeAt(0)
  if (cp < 0x80) return [cp]
  if (cp < 0x800) return [0xc0 | (cp >> 6), 0x80 | (cp & 63)]
  if (cp < 0x10000) return [0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63)]
  return [0xf0 | (cp >> 18), 0x80 | ((cp >> 12) & 63), 0x80 | ((cp >> 6) & 63), 0x80 | (cp & 63)]
}

// Windows-1252's characters from 0x80 to 0x9f (else as Latin-1).
var CP1252 = [0x20ac, 0xfffd, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030, 0x0160, 0x2039, 0x0152, 0xfffd, 0x017d, 0xfffd,
              0xfffd, 0x2018, 0x2019, 0x201c, 0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0xfffd, 0x017e, 0x0178]

// Bytes in a charset, as text (UTF-8 for one it doesn't know; Latin-1 if
// that's not UTF-8 after all).
function decode(bytes, charset) {
  var cs = String(charset || "utf-8").toLowerCase().replace(/^"|"$/g, "")
  if (/^(iso-8859-1|latin-?1|us-ascii|ascii|iso8859-1)$/.test(cs)) return latin1(bytes)
  if (/^(windows-1252|cp1252|x-cp1252)$/.test(cs)) return cp1252(bytes)
  var u = utf8(bytes)
  return u === null ? cp1252(bytes) : u
}
function latin1(bytes) {
  var out = ""
  for (var i = 0; i < bytes.length; i++) out += String.fromCharCode(bytes[i])
  return out
}
function cp1252(bytes) {
  var out = ""
  for (var i = 0; i < bytes.length; i++) {
    var b = bytes[i]
    out += String.fromCharCode(b >= 0x80 && b < 0xa0 ? CP1252[b - 0x80] : b)
  }
  return out
}
// UTF-8, or null if it isn't.
function utf8(bytes) {
  var out = ""
  for (var i = 0; i < bytes.length; i++) {
    var b = bytes[i]
    var cp
    var more
    if (b < 0x80) { out += String.fromCharCode(b); continue }
    else if (b >= 0xc2 && b < 0xe0) { cp = b & 0x1f; more = 1 }
    else if (b >= 0xe0 && b < 0xf0) { cp = b & 0x0f; more = 2 }
    else if (b >= 0xf0 && b < 0xf5) { cp = b & 0x07; more = 3 }
    else return null
    for (var k = 0; k < more; k++) {
      var c = bytes[++i]
      if (c === undefined || (c & 0xc0) !== 0x80) return null
      cp = (cp << 6) | (c & 0x3f)
    }
    out += String.fromCodePoint(cp)
  }
  return out
}

// ---- headers -------------------------------------------------------------------------------

// "=?UTF-8?B?...?=" and "=?iso-8859-1?Q?...?=" in a header, as text (two
// next to each other joined, the space between them dropped).
function words(text) {
  var s = String(text || "").replace(/(=\?[^?]+\?[BbQq]\?[^?]*\?=)\s+(?==\?[^?]+\?[BbQq]\?)/g, "$1")
  return s.replace(/=\?([^?*]+)(?:\*[^?]*)?\?([BbQq])\?([^?]*)\?=/g, function(all, charset, enc, data) {
    var bytes = enc.toUpperCase() === "B" ? base64Bytes(data) : quotedBytes(data, true)
    return decode(bytes, charset)
  })
}

// A message (or a part): { headers: { name: value }, body } (names in lower
// case, lines folded onto the next joined, the first of each kept).
function split(source) {
  var s = String(source || "")
  var m = /\r?\n\r?\n/.exec(s)
  var head = m ? s.slice(0, m.index) : s
  var body = m ? s.slice(m.index + m[0].length) : ""
  var headers = {}
  head.replace(/\r?\n[ \t]+/g, " ").split(/\r?\n/).forEach(function(l) {
    var colon = l.indexOf(":")
    if (colon <= 0) return
    var name = l.slice(0, colon).trim().toLowerCase()
    if (!/^[a-z0-9-]+$/.test(name) || headers[name] !== undefined) return
    headers[name] = l.slice(colon + 1).trim()
  })
  return { headers: headers, body: body }
}

// "text/plain; charset=utf-8; name=\"a b.txt\"" -> { value: "text/plain",
// params: { charset, name } } (RFC 2231's name*=UTF-8''... and name*0=, name*1= too).
function params(header) {
  var s = String(header || "")
  var parts = []
  var cur = ""
  var quoted = false
  for (var i = 0; i < s.length; i++) {
    var ch = s.charAt(i)
    if (ch === "\"" && s.charAt(i - 1) !== "\\") quoted = !quoted
    if (ch === ";" && !quoted) { parts.push(cur); cur = "" } else cur += ch
  }
  parts.push(cur)
  var out = { value: parts[0].trim().toLowerCase(), params: {} }
  var pieces = {}
  parts.slice(1).forEach(function(p) {
    var eq = p.indexOf("=")
    if (eq < 0) return
    var key = p.slice(0, eq).trim().toLowerCase()
    var val = p.slice(eq + 1).trim().replace(/^"([\s\S]*)"$/, "$1").replace(/\\"/g, "\"")
    var cont = /^([a-z0-9-]+)\*(\d+)(\*?)$/.exec(key)
    if (cont) { (pieces[cont[1]] = pieces[cont[1]] || [])[Number(cont[2])] = { v: val, enc: cont[3] === "*" }; return }
    if (/\*$/.test(key)) { out.params[key.slice(0, -1)] = ext(val, true); return }
    out.params[key] = words(val)
  })
  for (var k in pieces) {
    var list = pieces[k].filter(function(x) { return x })
    var charset = "utf-8"
    var text = list.map(function(x, i) {
      if (!x.enc) return x.v
      var v = x.v
      if (i === 0) { var m = /^([^']*)'[^']*'([\s\S]*)$/.exec(v); if (m) { charset = m[1] || "utf-8"; v = m[2] } }
      return v
    }).join("")
    out.params[k] = list.some(function(x) { return x.enc }) ? decode(percentBytes(text), charset) : text
  }
  return out
}
// RFC 2231: "UTF-8''%E2%82%AC%20rates.pdf".
function ext(value, encoded) {
  var m = /^([^']*)'[^']*'([\s\S]*)$/.exec(value)
  if (!m) return encoded ? decode(percentBytes(value), "utf-8") : value
  return decode(percentBytes(m[2]), m[1] || "utf-8")
}
function percentBytes(text) {
  var out = []
  var s = String(text || "")
  for (var i = 0; i < s.length; i++) {
    if (s.charAt(i) === "%" && /^[0-9A-Fa-f]{2}$/.test(s.substr(i + 1, 2))) { out.push(parseInt(s.substr(i + 1, 2), 16)); i += 2 }
    else rawBytes(s.charAt(i)).forEach(function(b) { out.push(b) })
  }
  return out
}

// "Sam Rivera <sam@acme.com>, \"Doe, Jane\" <jane@x.com>, bob@y.org" ->
// [{ name, address }].
function addresses(header) {
  var s = words(String(header || ""))
  var list = []
  var cur = ""
  var quoted = false
  var angle = 0
  for (var i = 0; i < s.length; i++) {
    var ch = s.charAt(i)
    if (ch === "\"") quoted = !quoted
    else if (ch === "<" && !quoted) angle++
    else if (ch === ">" && !quoted) angle = Math.max(0, angle - 1)
    if ((ch === "," || ch === ";") && !quoted && angle === 0) { list.push(cur); cur = "" } else cur += ch
  }
  list.push(cur)
  return list.map(function(a) {
    var t = a.trim()
    if (!t) return null
    var m = /^([\s\S]*?)<([^<>]+)>\s*$/.exec(t)
    var name = m ? m[1].trim().replace(/^"|"$/g, "").replace(/\\"/g, "\"").trim() : ""
    var address = (m ? m[2] : t).trim().replace(/^mailto:/i, "")
    if (!m && /\s/.test(address)) { name = address; address = "" }
    return { name: line(name, 120), address: line(address, 200).toLowerCase() }
  }).filter(function(x) { return x && (x.name || x.address) }).slice(0, 100)
}
// "Sam Rivera <sam@acme.com>" for one; names (or addresses) joined for many.
function addressText(list) {
  return (list || []).map(function(a) { return a.name && a.address ? a.name + " <" + a.address + ">" : a.name || a.address }).join(", ")
}
function names(list) {
  return (list || []).map(function(a) { return a.name || a.address }).join(", ")
}

// "Fri, 02 Oct 2026 09:30:00 +0200" -> an ISO date, or "".
var MONTHS = { jan: 0, feb: 1, mar: 2, apr: 3, may: 4, jun: 5, jul: 6, aug: 7, sep: 8, oct: 9, nov: 10, dec: 11 }
var ZONES = { ut: 0, utc: 0, gmt: 0, z: 0, est: -300, edt: -240, cst: -360, cdt: -300, mst: -420, mdt: -360, pst: -480, pdt: -420 }
function date(header) {
  var m = /(\d{1,2})\s+([A-Za-z]{3})[a-z]*\.?\s+(\d{2,4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([+-]\d{4}|[A-Za-z]{1,4})?/.exec(String(header || ""))
  if (!m || MONTHS[m[2].toLowerCase()] === undefined) return ""
  var year = Number(m[3])
  if (year < 100) year += year < 50 ? 2000 : 1900
  var off = 0
  if (m[7]) {
    if (/^[+-]\d{4}$/.test(m[7])) off = (m[7].charAt(0) === "-" ? -1 : 1) * (Number(m[7].slice(1, 3)) * 60 + Number(m[7].slice(3)))
    else off = ZONES[m[7].toLowerCase()] || 0
  }
  var t = Date.UTC(year, MONTHS[m[2].toLowerCase()], Number(m[1]), Number(m[4]), Number(m[5]), Number(m[6] || 0)) - off * 60000
  var d = new Date(t)
  return isNaN(d.getTime()) ? "" : d.toISOString()
}

// ---- the message ---------------------------------------------------------------------------

// One part's body as bytes, by its Content-Transfer-Encoding.
function partBytes(part) {
  var enc = String(part.headers["content-transfer-encoding"] || "").trim().toLowerCase()
  if (enc === "base64") return base64Bytes(part.body)
  if (enc === "quoted-printable") return quotedBytes(part.body, false)
  return rawBytes(part.body)
}

// The parts of a message, flattened: [{ type, charset, name, cid, disposition, part }].
function walk(part, out, depth) {
  var ct = params(part.headers["content-type"] || "text/plain")
  var cd = params(part.headers["content-disposition"] || "")
  if (/^multipart\//.test(ct.value) && ct.params.boundary && depth < 12) {
    var b = "--" + ct.params.boundary
    var chunks = String(part.body).split(b)
    chunks.slice(1).forEach(function(chunk) {
      if (/^--/.test(chunk)) return
      // (The line break before a boundary is the boundary's, not the part's.)
      walk(split(chunk.replace(/^[ \t]*\r?\n/, "").replace(/\r?\n$/, "")), out, depth + 1)
    })
    return out
  }
  if (ct.value === "message/rfc822" && depth < 12) {
    out.push({ type: ct.value, charset: "", name: cd.params.filename || ct.params.name || "Forwarded message.eml", cid: "", disposition: "attachment", part: part })
    return out
  }
  out.push({
    type: ct.value || "text/plain",
    charset: ct.params.charset || "",
    name: cd.params.filename || ct.params.name || "",
    cid: String(part.headers["content-id"] || "").replace(/^<|>$/g, ""),
    disposition: cd.value,
    part: part
  })
  return out
}

// A message, read: { subject, from, to, cc, date, text, html, attachments:
// [{ name, type, size, index }] }, or null if it isn't one.
function parse(source) {
  var top = split(source)
  var h = top.headers
  if (!h.from && !h.subject && !h.to && !h["content-type"]) return null
  var parts = walk(top, [], 0)
  var text = ""
  var html = ""
  var attachments = []
  parts.forEach(function(p, i) {
    var isAttachment = p.disposition === "attachment" || (p.name && p.disposition !== "inline") || (!/^text\/(plain|html)$/.test(p.type) && !p.cid)
    if (isAttachment) {
      if (attachments.length < MAX_ATTACHMENTS) attachments.push({ name: line(p.name, 200) || "Attachment " + (attachments.length + 1), type: p.type, size: partBytes(p.part).length, index: i })
      return
    }
    if (p.type === "text/plain" && !text) text = decode(partBytes(p.part), p.charset).replace(/\r\n?/g, "\n")
    else if (p.type === "text/html" && !html) html = decode(partBytes(p.part), p.charset)
  })
  return {
    subject: line(words(h.subject || ""), 300),
    from: addresses(h.from),
    to: addresses(h.to),
    cc: addresses(h.cc),
    date: date(h.date),
    text: text,
    html: html.slice(0, MAX_HTML),
    attachments: attachments,
    parts: parts
  }
}

// An attachment's bytes, as base64 (to be written as a file).
function attachmentBase64(message, index) {
  var p = message && message.parts ? message.parts[index] : null
  if (!p) return ""
  var enc = String(p.part.headers["content-transfer-encoding"] || "").trim().toLowerCase()
  if (p.type === "message/rfc822") return bytesBase64(rawBytes(p.part.body))
  if (enc === "base64") return String(p.part.body).replace(/[^A-Za-z0-9+\/=]/g, "")
  return bytesBase64(partBytes(p.part))
}

// An attachment's words (a calendar file, a contact card), in its charset.
function attachmentText(message, index) {
  var p = message && message.parts ? message.parts[index] : null
  return p ? decode(partBytes(p.part), p.charset || "utf-8") : ""
}

// ---- showing it ----------------------------------------------------------------------------

function escape(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;")
}
function entities(text) {
  var named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " ", ndash: "\u2013", mdash: "\u2014", hellip: "\u2026", rsquo: "\u2019", lsquo: "\u2018", rdquo: "\u201d", ldquo: "\u201c", copy: "\u00a9", reg: "\u00ae", trade: "\u2122", euro: "\u20ac", bull: "\u2022", middot: "\u00b7" }
  return String(text).replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, function(all, e) {
    if (e.charAt(0) === "#") {
      var n = e.charAt(1).toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)
      return n > 0 && n < 0x110000 ? String.fromCodePoint(n) : ""
    }
    var v = named[e.toLowerCase()]
    return v !== undefined ? v : all
  })
}

// HTML as plain text (for the preview and search).
function htmlText(html) {
  return entities(String(html || "")
    .replace(/<(head|style|script|title)[\s\S]*?<\/\1\s*>/gi, " ")
    .replace(/<!--[\s\S]*?-->/g, " ")
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/(p|div|li|tr|h[1-6]|blockquote)\s*>/gi, "\n")
    .replace(/<[^>]*>/g, " "))
    .replace(/[ \t\u00a0]+/g, " ").split("\n").map(function(l) { return l.trim() }).join("\n")
    .replace(/\n{3,}/g, "\n\n").trim()
}

// The words in it, plainly: its text, else its HTML's.
function bodyText(message) {
  if (!message) return ""
  return message.text ? message.text.trim() : htmlText(message.html)
}

// The first lines, for the card (quoted replies left out).
function preview(message) {
  var t = bodyText(message).split("\n").filter(function(l) { return !/^\s*>/.test(l) }).join(" ")
  return line(t, MAX_PREVIEW)
}

// HTML safe to show in Pages (Qt's rich text): its structure and links,
// without scripts, styles, forms, pictures (from the web: they'd say you
// opened it), or attributes but a link's address (to the web or an email).
var KEEP = { a: 1, b: 1, strong: 1, i: 1, em: 1, u: 1, s: 1, strike: 1, del: 1, br: 1, p: 1, div: 1, span: 1, ul: 1, ol: 1, li: 1,
             h1: 1, h2: 1, h3: 1, h4: 1, h5: 1, h6: 1, blockquote: 1, pre: 1, code: 1, table: 1, thead: 1, tbody: 1, tr: 1, td: 1, th: 1, hr: 1, sub: 1, sup: 1 }
function safeHtml(html) {
  var s = String(html || "")
    .replace(/<(head|style|script|title|template|noscript|object|iframe|svg|math|form|select|textarea|button)\b[\s\S]*?<\/\1\s*>/gi, "")
    .replace(/<!--[\s\S]*?-->/g, "")
    .replace(/<!\[CDATA\[[\s\S]*?\]\]>/g, "")
    .replace(/<!doctype[^>]*>/gi, "")
  var out = s.replace(/<(\/?)([a-zA-Z][a-zA-Z0-9]*)\b([^>]*)>/g, function(all, close, tag, attrs) {
    var t = tag.toLowerCase()
    if (t === "img") {
      var alt = /\balt\s*=\s*("([^"]*)"|'([^']*)')/i.exec(attrs)
      var words_ = alt ? (alt[2] || alt[3] || "").trim() : ""
      return words_ ? "[" + escape(entities(words_)) + "]" : ""
    }
    if (!KEEP[t]) return ""
    if (close) return "</" + t + ">"
    if (t === "a") {
      var hm = /\bhref\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))/i.exec(attrs)
      var href = hm ? entities(hm[2] || hm[3] || hm[4] || "").trim() : ""
      return /^(https?:\/\/|mailto:)/i.test(href) ? "<a href=\"" + escape(href) + "\">" : "<a>"
    }
    return "<" + t + (t === "br" || t === "hr" ? " /" : "") + ">"
  })
  return out.replace(/<\/?(html|body|meta|link|base)[^>]*>/gi, "")
}

// Plain text as HTML: lines kept, web links and emails made links, quoted
// replies ("> ") faint.
function textHtml(text, faintColor) {
  return String(text || "").split("\n").map(function(l) {
    var e = escape(l)
      .replace(/(https?:\/\/[^\s<>"]+[^\s<>".,;:!?)\]])/g, "<a href=\"$1\">$1</a>")
      .replace(/(^|[\s(])([A-Za-z0-9._%+-]+@[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,})/g, "$1<a href=\"mailto:$2\">$2</a>")
    return /^\s*&gt;/.test(e) && faintColor ? "<span style=\"color:" + faintColor + ";\">" + e + "</span>" : e
  }).join("<br />")
}

// What a message shows in full: its HTML made safe, else its text.
function displayHtml(message, faintColor) {
  if (!message) return ""
  return message.html ? safeHtml(message.html) : textHtml(message.text, faintColor)
}

// ---- the block -----------------------------------------------------------------------------

function make() {
  return { src: "", name: "", size: 0, subject: "", from: "", to: "", cc: "", date: "", preview: "", attachments: [], open: false, color: "", background: "" }
}

// What a block keeps of a message it was made from.
function summary(message) {
  if (!message) return null
  return {
    subject: message.subject,
    from: addressText(message.from).slice(0, 300),
    to: addressText(message.to).slice(0, 600),
    cc: addressText(message.cc).slice(0, 600),
    date: message.date,
    preview: preview(message),
    attachments: message.attachments.map(function(a) { return { name: a.name, size: a.size, type: a.type, src: "" } })
  }
}

function clean(raw) {
  var r = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  var out = make()
  out.src = Files.cleanSrc(r.src)
  out.name = line(r.name, 200)
  var n = Number(r.size)
  out.size = isFinite(n) && n > 0 ? Math.round(n) : 0
  out.subject = line(r.subject, 300)
  out.from = line(r.from, 300)
  out.to = line(r.to, 600)
  out.cc = line(r.cc, 600)
  out.date = typeof r.date === "string" && !isNaN(new Date(r.date).getTime()) ? r.date : ""
  out.preview = line(r.preview, MAX_PREVIEW)
  out.attachments = (Array.isArray(r.attachments) ? r.attachments : []).slice(0, MAX_ATTACHMENTS).map(function(a) {
    var s = Number(a && a.size)
    return { name: line(a && a.name, 200) || "Attachment", size: isFinite(s) && s > 0 ? Math.round(s) : 0, type: line(a && a.type, 100), src: Files.cleanSrc(a && a.src) }
  })
  out.open = r.open === true
  out.color = Files.cleanColor(r.color)
  out.background = Files.cleanColor(r.background)
  return out
}

// Who it's from: their name (else their address).
function shortName(field) {
  var a = addresses(field)
  return a.length ? names(a.slice(0, 1)) : ""
}
function shortNames(field, max) {
  var a = addresses(field)
  if (!a.length) return ""
  var shown = names(a.slice(0, max || 2))
  return a.length > (max || 2) ? shown + " +" + (a.length - (max || 2)) : shown
}

// A block as Markdown: who, when, what it's about, the first lines, and a
// link to the .eml.
function toMarkdown(d, prefix) {
  if (!d || !d.src) return "*(An email, not added yet)*"
  var out = ["> \u2709 **" + (d.subject || "(no subject)") + "**"]
  out.push("> From " + (d.from || "?") + (d.to ? " \u00b7 to " + d.to : "") + (d.date ? " \u00b7 " + d.date.slice(0, 10) : ""))
  if (d.preview) { out.push(">"); out.push("> " + d.preview) }
  out.push("")
  out.push("[" + (d.name || "the email") + "](" + (prefix || "") + d.src + ")")
  return out.join("\n")
}

// An email's file in Pages/assets ("mail-20261002-093000-k3f-launch-plan.eml").
function assetName(original, now, salt) {
  return Files.assetName(original || "email.eml", now, salt).replace(/^file-/, "mail-").replace(/(\.[A-Za-z0-9]+)?$/, function(e) { return e && e.toLowerCase() === ".eml" ? e : (e || "") + ".eml" })
}
