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

// Reading an email holds up the shell until it's done, so these keep any
// .eml (up to the 64 MB that's read) quick to read, however it's made;
// what's past them is left out.
var MAX_TEXT = 400000      // a plain body's characters
var MAX_PARTS = 500        // parts read, the message and its multiparts counted
var MAX_DEPTH = 12         // multiparts in multiparts (one deeper is just a part)
var MAX_DASHES = 1000000   // lines starting "--" looked at, for boundaries, in all
var MAX_HEAD = 256 * 1024  // a header block's characters (one longer has no body)
var MAX_FIELDS = 500       // a header block's lines read
var MAX_LINE = 16 * 1024   // a header's characters (its folded lines joined)
var MAX_PARAMS = 50        // a header's parameters read (name*0=, name*1=: one each)
var MAX_PIECES = 64        // RFC 2231's pieces of one read: name*0= to name*63=
var MAX_PARAM = 2000       // a parameter's characters, its pieces put together

function line(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max || 300)
}

// ---- bytes ---------------------------------------------------------------------------------

// Bytes are lists of numbers (no more than a `max` asked for), and text is
// made from them a few thousand characters at a time: in the shell's
// JavaScript, a string added to for each character is slow, and big.

var B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
// Each base64 character's value, by its code.
var B64_VALUES = b64Values()
function b64Values() {
  var out = []
  for (var i = 0; i < 128; i++) out.push(B64.indexOf(String.fromCharCode(i)))
  return out
}

// (Read a piece at a time, so a few bytes of a long one are quick.)
function base64Bytes(text, max) {
  var s = String(text || "")
  var most = max === undefined ? Infinity : max
  var values = B64_VALUES
  var out = []
  var buf = 0
  var bits = 0
  for (var at = 0; at < s.length && out.length < most; at += 65536) {
    var piece = s.slice(at, at + 65536).replace(/[^A-Za-z0-9+\/]+/g, "")
    for (var i = 0; i < piece.length && out.length < most; i++) {
      buf = (buf << 6) | values[piece.charCodeAt(i)]
      bits += 6
      if (bits >= 8) {
        bits -= 8
        out.push((buf >> bits) & 0xff)
      }
    }
  }
  return out
}

function bytesBase64(bytes) {
  var out = []
  var codes = []
  for (var i = 0; i < bytes.length; i += 3) {
    var a = bytes[i], b = bytes[i + 1], c = bytes[i + 2]
    var n = (a << 16) | ((b || 0) << 8) | (c || 0)
    codes.push(B64.charCodeAt((n >> 18) & 63), B64.charCodeAt((n >> 12) & 63),
               b === undefined ? 61 : B64.charCodeAt((n >> 6) & 63), c === undefined ? 61 : B64.charCodeAt(n & 63))
    if (codes.length >= 4096) { out.push(chars(codes)); codes = [] }
  }
  out.push(chars(codes))
  return out.join("")
}

// Character codes as text, a few thousand at a time.
function chars(codes) {
  var out = []
  for (var i = 0; i < codes.length; i += 4096) out.push(String.fromCharCode.apply(null, codes.slice(i, i + 4096)))
  return out.join("")
}

// A hex digit's value, by its code (-1: not one).
function hex(code) {
  if (code >= 48 && code <= 57) return code - 48
  if (code >= 65 && code <= 70) return code - 55
  if (code >= 97 && code <= 102) return code - 87
  return -1
}

// "=C3=A9" and soft line breaks ("=" at a line's end), as bytes.
function quotedBytes(text, inHeader, max) {
  var s = String(text || "").replace(/=\r?\n/g, "")
  if (inHeader) s = s.replace(/_/g, " ")
  var most = max === undefined ? Infinity : max
  var digit = hex
  var push = utf8Push
  var out = []
  for (var i = 0; i < s.length && out.length < most; i++) {
    var code = s.charCodeAt(i)
    var high = code === 61 ? digit(s.charCodeAt(i + 1)) : -1
    var low = high >= 0 ? digit(s.charCodeAt(i + 2)) : -1
    if (low >= 0) { out.push(high * 16 + low); i += 2 }
    else if (code < 0x80) out.push(code)
    else push(out, code)
  }
  return out
}

// A string's characters as bytes (what's read is each byte a character
// when it came in raw: 8bit mail read as text keeps its UTF-8).
function rawBytes(text, max) {
  var s = String(text || "")
  var most = max === undefined ? Infinity : max
  var out = []
  for (var i = 0; i < s.length && out.length < most; i++) {
    var code = s.charCodeAt(i)
    if (code < 0x80) out.push(code)
    else if (code < 0x800) out.push(0xc0 | (code >> 6), 0x80 | (code & 63))
    else out.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63))
  }
  return out
}

// A character's UTF-8 bytes, added to `out` (each UTF-16 unit on its own).
function utf8Push(out, code) {
  if (code < 0x80) out.push(code)
  else if (code < 0x800) out.push(0xc0 | (code >> 6), 0x80 | (code & 63))
  else out.push(0xe0 | (code >> 12), 0x80 | ((code >> 6) & 63), 0x80 | (code & 63))
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
  return chars(bytes)
}
function cp1252(bytes) {
  return chars(bytes.map(function(b) { return b >= 0x80 && b < 0xa0 ? CP1252[b - 0x80] : b }))
}
// UTF-8, or null if it isn't.
function utf8(bytes) {
  var out = []
  var codes = []
  for (var i = 0; i < bytes.length; i++) {
    var b = bytes[i]
    var cp = b
    var more = 0
    if (b >= 0x80) {
      if (b >= 0xc2 && b < 0xe0) { cp = b & 0x1f; more = 1 }
      else if (b >= 0xe0 && b < 0xf0) { cp = b & 0x0f; more = 2 }
      else if (b >= 0xf0 && b < 0xf5) { cp = b & 0x07; more = 3 }
      else return null
    }
    for (var k = 0; k < more; k++) {
      var c = bytes[++i]
      if (c === undefined || (c & 0xc0) !== 0x80) return null
      cp = (cp << 6) | (c & 0x3f)
    }
    if (cp > 0x10ffff) return null
    if (cp < 0x10000) codes.push(cp)
    else codes.push(0xd800 + ((cp - 0x10000) >> 10), 0xdc00 + ((cp - 0x10000) & 0x3ff))
    if (codes.length >= 4096) { out.push(chars(codes)); codes = [] }
  }
  out.push(chars(codes))
  return out.join("")
}

// Bytes cut at `max`, and back to where a character starts (half of a UTF-8
// one at the end would make all of it look like it isn't UTF-8).
function cut(bytes, max) {
  var end = Math.min(bytes.length, max)
  var start = end
  while (start > 0 && end - start < 3 && (bytes[start - 1] & 0xc0) === 0x80) start--
  var lead = bytes[start - 1]
  if (start > 0 && lead >= 0xc0 && start - 1 + (lead >= 0xf0 ? 4 : lead >= 0xe0 ? 3 : 2) > end) end = start - 1
  return bytes.slice(0, end)
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

// A message, or one of its parts (in `source`, from start to end): { headers:
// { name: value }, source, start, end }, its body being source from start to
// end (left where it is, not copied out again for each multipart it's in).
// Its header block ends at its first blank line, if that's in its first
// MAX_HEAD characters; else it's all header.
function split(source, start, end) {
  var s = String(source || "")
  var from = start || 0
  var to = end === undefined ? s.length : end
  var head = s.slice(from, Math.min(to, from + MAX_HEAD + 4))
  var m = /\r?\n\r?\n/.exec(head)
  if (m && m.index > MAX_HEAD) m = null
  return { headers: fields(m ? head.slice(0, m.index) : head), source: s, start: m ? from + m.index + m[0].length : to, end: to }
}

// A header block's fields: { name: value } (names in lower case, lines
// folded onto the next joined, the first of each kept; of its first
// MAX_HEAD characters, MAX_FIELDS lines read, MAX_LINE characters of each).
function fields(head) {
  var s = String(head || "").slice(0, MAX_HEAD).replace(/\r?\n[ \t]+/g, " ")
  var headers = {}
  for (var at = 0, n = 0; at < s.length && n < MAX_FIELDS; n++) {
    var nl = s.indexOf("\n", at)
    if (nl < 0) nl = s.length
    var l = s.slice(at, nl)
    at = nl + 1
    var colon = l.indexOf(":")
    if (colon <= 0) continue
    var name = l.slice(0, colon).trim().toLowerCase()
    if (!/^[a-z0-9-]+$/.test(name) || headers[name] !== undefined) continue
    headers[name] = l.slice(colon + 1).trim().slice(0, MAX_LINE)
  }
  return headers
}

// "text/plain; charset=utf-8; name=\"a b.txt\"" -> { value: "text/plain",
// params: { charset, name } } (RFC 2231's name*=UTF-8''... and name*0=, name*1= too;
// the first MAX_PARAMS read, MAX_PARAM characters of each).
function params(header) {
  var s = String(header || "")
  var parts = []
  var from = 0
  var quoted = false
  var most = MAX_PARAMS
  for (var i = 0; i < s.length && parts.length <= most; i++) {
    var ch = s.charCodeAt(i)
    if (ch === 34 && s.charCodeAt(i - 1) !== 92) quoted = !quoted
    else if (ch === 59 && !quoted) { parts.push(s.slice(from, i)); from = i + 1 }
  }
  if (parts.length <= most) parts.push(s.slice(from))
  var out = { value: parts[0].trim().toLowerCase(), params: {} }
  // RFC 2231's pieces, by name, then by number: only the numbers read are
  // kept, and they're put together in order.
  var pieces = Object.create(null)
  parts.slice(1).forEach(function(p) {
    var eq = p.indexOf("=")
    if (eq < 0) return
    var key = p.slice(0, eq).trim().toLowerCase()
    var val = p.slice(eq + 1).trim().replace(/^"([\s\S]*)"$/, "$1").replace(/\\"/g, "\"")
    var cont = /^([a-z0-9-]+)\*(\d+)(\*?)$/.exec(key)
    if (cont) {
      var at = Number(cont[2])
      if (at < MAX_PIECES) (pieces[cont[1]] = pieces[cont[1]] || Object.create(null))[at] = { v: val, enc: cont[3] === "*" }
      return
    }
    if (/\*$/.test(key)) { out.params[key.slice(0, -1)] = ext(val, true).slice(0, MAX_PARAM); return }
    out.params[key] = words(val).slice(0, MAX_PARAM)
  })
  for (var k in pieces) {
    var list = []
    for (var n = 0; n < MAX_PIECES; n++) if (pieces[k][n]) list.push(pieces[k][n])
    var charset = "utf-8"
    var text = list.map(function(x, i) {
      if (!x.enc) return x.v
      var v = x.v
      if (i === 0) { var m = /^([^']*)'[^']*'([\s\S]*)$/.exec(v); if (m) { charset = m[1] || "utf-8"; v = m[2] } }
      return v
    }).join("")
    out.params[k] = (list.some(function(x) { return x.enc }) ? decode(percentBytes(text), charset) : text).slice(0, MAX_PARAM)
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
    var code = s.charCodeAt(i)
    var high = code === 37 ? hex(s.charCodeAt(i + 1)) : -1
    var low = high >= 0 ? hex(s.charCodeAt(i + 2)) : -1
    if (low >= 0) { out.push(high * 16 + low); i += 2 }
    else utf8Push(out, code)
  }
  return out
}

// "Sam Rivera <sam@acme.com>, \"Doe, Jane\" <jane@x.com>, bob@y.org" ->
// [{ name, address }].
function addresses(header) {
  var s = words(String(header || ""))
  var list = []
  var from = 0
  var quoted = false
  var angle = 0
  for (var i = 0; i < s.length; i++) {
    var ch = s.charCodeAt(i)
    if (ch === 34) quoted = !quoted
    else if (ch === 60 && !quoted) angle++
    else if (ch === 62 && !quoted) angle = Math.max(0, angle - 1)
    else if ((ch === 44 || ch === 59) && !quoted && angle === 0) { list.push(s.slice(from, i)); from = i + 1 }
  }
  list.push(s.slice(from))
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

function encoding(part) {
  return String(part.headers["content-transfer-encoding"] || "").trim().toLowerCase()
}
// A part's body (copied out of the message, so only when it's needed): all
// of it, or its first `max` characters.
function body(part, max) {
  return part.source.slice(part.start, max === undefined ? part.end : Math.min(part.end, part.start + max))
}

// One part's body as bytes, by its Content-Transfer-Encoding: all of them,
// or at most `max` (from at most four characters each: none takes more).
function partBytes(part, max) {
  var enc = encoding(part)
  var s = body(part, max === undefined ? undefined : 4 * max)
  var bytes = enc === "base64" ? base64Bytes(s, max) : enc === "quoted-printable" ? quotedBytes(s, false, max) : rawBytes(s, max)
  return max !== undefined && (bytes.length >= max || part.start + s.length < part.end) ? cut(bytes, max) : bytes
}

// How many bytes a part's body is: counted, not decoded, a million
// characters at a time.
function partSize(part) {
  var enc = encoding(part)
  var n = 0
  for (var at = part.start; at < part.end; ) {
    var s = part.source.slice(at, Math.min(part.end, at + 1048576))
    // (Quoted-printable is counted a line at a time, so nothing escaped is cut in two.)
    var nl = enc === "quoted-printable" && at + s.length < part.end ? s.lastIndexOf("\n") : -1
    if (nl >= 0) s = s.slice(0, nl + 1)
    at += s.length
    if (enc === "base64") n += s.replace(/[^A-Za-z0-9+\/]+/g, "").length
    else n += utf8Length(enc === "quoted-printable" ? s.replace(/=\r?\n/g, "").replace(/=[0-9A-Fa-f]{2}/g, "=") : s)
  }
  return enc === "base64" ? Math.floor(n * 3 / 4) : n
}
// How many bytes text is in UTF-8 (each UTF-16 unit on its own, as rawBytes has it).
function utf8Length(s) {
  var high = s.replace(/[\u0000-\u007f]+/g, "")
  return s.length + high.length + high.replace(/[\u0080-\u07ff]+/g, "").length
}

// The parts of a message, flattened: [{ type, charset, name, cid, disposition, part }]
// (at most MAX_PARTS read in all, the message and its multiparts counted;
// past MAX_DASHES lines looked at for boundaries, no more).
function walk(top) {
  var out = []
  var read = 0
  var dashes = MAX_DASHES
  visit(top, 0)
  return out

  function visit(part, depth) {
    read++
    var ct = params(part.headers["content-type"] || "text/plain")
    var cd = params(part.headers["content-disposition"] || "")
    var boundary = ct.params.boundary || ""
    if (/^multipart\//.test(ct.value) && boundary && depth < MAX_DEPTH) {
      // (A boundary is on a line of its own: one with a line break in it isn't found.)
      if (boundary.indexOf("\n") >= 0) return
      var s = part.source
      var b = "--" + boundary
      for (var at = delimiter(part, b, part.start); at >= 0 && read < MAX_PARTS; ) {
        var next = delimiter(part, b, at + b.length)
        if (read >= MAX_PARTS) return
        var from = at + b.length
        var to = next >= 0 ? next : part.end
        at = next
        if (to - from >= 2 && s.startsWith("--", from)) continue
        // (The rest of the boundary's line is the boundary's, and so is the
        // line break before the next one.)
        var nl = s.indexOf("\n", from)
        if (nl >= 0 && nl < to && /^[ \t]*\r?$/.test(s.slice(from, nl))) from = nl + 1
        if (to > from && s.charAt(to - 1) === "\n") { to--; if (to > from && s.charAt(to - 1) === "\r") to-- }
        visit(split(s, from, to), depth + 1)
      }
      return
    }
    if (ct.value === "message/rfc822" && depth < MAX_DEPTH) {
      out.push({ type: ct.value, charset: "", name: cd.params.filename || ct.params.name || "Forwarded message.eml", cid: "", disposition: "attachment", part: part })
      return
    }
    out.push({
      type: ct.value || "text/plain",
      charset: ct.params.charset || "",
      name: cd.params.filename || ct.params.name || "",
      cid: String(part.headers["content-id"] || "").replace(/^<|>$/g, ""),
      disposition: cd.value,
      part: part
    })
  }

  // Where the next "--boundary" in a multipart's body starts, from `from`
  // on, or -1. One starts a line, so it's found by its line's "\n--" and
  // then compared: no boundary, however long or odd, makes that slow. (With
  // too many such lines looked at, -1, and no more parts are read.)
  function delimiter(part, b, from) {
    var s = part.source
    var q = s.indexOf("\n--", Math.max(from - 1, 0))
    while (q >= 0 && q + 1 + b.length <= part.end) {
      if (--dashes < 0) { read = MAX_PARTS; return -1 }
      if (s.startsWith(b, q + 1)) return q + 1
      q = s.indexOf("\n--", q + 1)
    }
    return -1
  }
}

// A message, read: { subject, from, to, cc, date, text, html, attachments:
// [{ name, type, size, index }] }, or null if it isn't one.
function parse(source) {
  var top = split(source)
  var h = top.headers
  if (!h.from && !h.subject && !h.to && !h["content-type"]) return null
  var parts = walk(top)
  var text = ""
  var html = ""
  var attachments = []
  parts.forEach(function(p, i) {
    var isAttachment = p.disposition === "attachment" || (p.name && p.disposition !== "inline") || (!/^text\/(plain|html)$/.test(p.type) && !p.cid)
    if (isAttachment) {
      if (attachments.length < MAX_ATTACHMENTS) attachments.push({ name: line(p.name, 200) || "Attachment " + (attachments.length + 1), type: p.type, size: partSize(p.part), index: i })
      return
    }
    if (p.type === "text/plain" && !text) text = partText(p, MAX_TEXT).replace(/\r\n?/g, "\n")
    else if (p.type === "text/html" && !html) html = partText(p, MAX_HTML)
  })
  return {
    subject: line(words(h.subject || ""), 300),
    from: addresses(h.from),
    to: addresses(h.to),
    cc: addresses(h.cc),
    date: date(h.date),
    text: text,
    html: html,
    attachments: attachments,
    parts: parts
  }
}

// A part's words in its charset: at most `max` characters (from at most
// three bytes each, the most one takes).
function partText(p, max) {
  return decode(partBytes(p.part, 3 * max), p.charset).slice(0, max)
}

// An attachment's bytes, as base64 (to be written as a file).
function attachmentBase64(message, index) {
  var p = message && message.parts ? message.parts[index] : null
  if (!p) return ""
  if (p.type === "message/rfc822") return bytesBase64(rawBytes(body(p.part)))
  if (encoding(p.part) === "base64") return body(p.part).replace(/[^A-Za-z0-9+\/=]/g, "")
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
    return typeof v === "string" ? v : all
  })
}

// HTML read once through, the way a browser reads it: its words (as they're
// written, entities and all) to text(words), its tags to tag(name, closing,
// { href, alt }) (the name in lower case). A "<" that doesn't start a tag is
// words; a comment, <!doctype ...>, <?xml ...?> or CDATA is a tag named "!";
// an element named in `hidden` is just its two tags, what's between them
// skipped (with no end tag after it, just its tag). A tag the HTML ends in
// the middle of is left out, and so is all after it. (Not with regexes:
// [\s\S]*? and [^>]* look for an end again from each "<", and some HTML
// makes that take minutes.)
function readHtml(html, hidden, text, tag) {
  var s = String(html || "")
  var ends = {}
  var from = 0  // (where the words not given yet start)
  var at = 0
  for (var lt = s.indexOf("<"); lt >= 0; lt = s.indexOf("<", at)) {
    var c = s.charCodeAt(lt + 1)
    var closing = c === 47
    var first = closing ? s.charCodeAt(lt + 2) : c
    var named = (first >= 65 && first <= 90) || (first >= 97 && first <= 122)
    var mark = c === 33 ? (s.startsWith("<!--", lt) ? "-->" : s.startsWith("<![CDATA[", lt) ? "]]>" : ">") : c === 63 || (closing && !named) ? ">" : ""
    // (A "<" that's words stays with the words around it.)
    if (!mark && !named) { at = lt + 1; continue }
    if (lt > from) text(s.slice(from, lt))
    if (mark) {
      var end = s.indexOf(mark, lt + (mark === "-->" ? 4 : mark === "]]>" ? 9 : 2))
      if (end < 0) return
      tag("!", false, null)
      at = from = end + mark.length
      continue
    }
    var t = tagAt(s, closing ? lt + 2 : lt + 1)
    if (!t) return
    at = from = t.end
    if (!closing && hidden[t.name] === 1 && ends[t.name] !== false) {
      var re = ends[t.name] || (ends[t.name] = new RegExp("</" + t.name + "\\s*>", "gi"))
      re.lastIndex = at
      var m = re.exec(s)
      if (m) { tag(t.name, false, t.attrs); tag(t.name, true, null); at = from = m.index + m[0].length; continue }
      // (None after this one, so none after any later one either.)
      ends[t.name] = false
    }
    tag(t.name, closing, t.attrs)
  }
  if (s.length > from) text(s.slice(from))
}

// A tag, from just past its "<" or "</": { name (in lower case), attrs:
// { href, alt } (as written, or null), end (just past its ">") }, or null if
// the HTML ends first. As a browser reads one: a "/" between attributes is
// a space, and a value in quotes is all one, ">" and all.
function tagAt(s, i) {
  var space = isSpace
  var n = s.length
  var from = i
  while (i < n && !space(s.charCodeAt(i)) && s.charCodeAt(i) !== 47 && s.charCodeAt(i) !== 62) i++
  var t = { name: s.slice(from, i).toLowerCase(), attrs: { href: null, alt: null }, end: 0 }
  for (;;) {
    while (i < n && (space(s.charCodeAt(i)) || s.charCodeAt(i) === 47)) i++
    if (i >= n) return null
    if (s.charCodeAt(i) === 62) { t.end = i + 1; return t }
    from = i++
    while (i < n && !space(s.charCodeAt(i)) && s.charCodeAt(i) !== 47 && s.charCodeAt(i) !== 62 && s.charCodeAt(i) !== 61) i++
    var key = s.slice(from, i).toLowerCase()
    while (i < n && space(s.charCodeAt(i))) i++
    var value = ""
    if (s.charCodeAt(i) === 61) {
      i++
      while (i < n && space(s.charCodeAt(i))) i++
      var q = s.charCodeAt(i)
      if (q === 34 || q === 39) {
        var close = s.indexOf(s.charAt(i), i + 1)
        if (close < 0) return null
        value = s.slice(i + 1, close)
        i = close + 1
      } else {
        from = i
        while (i < n && !space(s.charCodeAt(i)) && s.charCodeAt(i) !== 62) i++
        value = s.slice(from, i)
      }
    }
    if ((key === "href" || key === "alt") && t.attrs[key] === null) t.attrs[key] = value
  }
}
// HTML's spaces: space, tab, line feed, form feed and return.
function isSpace(c) {
  return c === 32 || c === 9 || c === 10 || c === 12 || c === 13
}

// HTML as plain text (for the preview and search).
var BREAKS = { p: 1, div: 1, li: 1, tr: 1, h1: 1, h2: 1, h3: 1, h4: 1, h5: 1, h6: 1, blockquote: 1 }
function htmlText(html) {
  var out = []
  readHtml(html, { head: 1, style: 1, script: 1, title: 1 }, function(words) { out.push(words) }, function(t, closing) {
    out.push(t === "br" || (closing && BREAKS[t] === 1) ? "\n" : " ")
  })
  return entities(out.join(""))
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

// HTML safe to show in Pages (Qt's rich text): its structure and links, and
// nothing else. What's shown is made anew, not passed on: these tags, with
// no attributes but a link's address (to the web or an email); every word
// escaped (entities left as written); a picture, its words (from the web,
// it'd say you opened it); scripts, styles, forms and the like left out,
// with what's in them. So no "<" comes out but these tags'.
var KEEP = { a: 1, b: 1, strong: 1, i: 1, em: 1, u: 1, s: 1, strike: 1, del: 1, br: 1, p: 1, div: 1, span: 1, ul: 1, ol: 1, li: 1,
             h1: 1, h2: 1, h3: 1, h4: 1, h5: 1, h6: 1, blockquote: 1, pre: 1, code: 1, table: 1, thead: 1, tbody: 1, tr: 1, td: 1, th: 1, hr: 1, sub: 1, sup: 1 }
var HIDDEN = { head: 1, style: 1, script: 1, title: 1, template: 1, noscript: 1, object: 1, iframe: 1, svg: 1, math: 1, form: 1, select: 1, textarea: 1, button: 1 }
function safeHtml(html) {
  var out = []
  readHtml(html, HIDDEN, function(words) { out.push(safeWords(words)) }, function(t, closing, attrs) {
    if (t === "img") {
      var alt = !closing && attrs && attrs.alt !== null ? attrs.alt.trim() : ""
      if (alt) out.push("[" + escape(entities(alt)) + "]")
      return
    }
    if (KEEP[t] !== 1) return
    if (closing) out.push("</" + t + ">")
    else if (t === "a") {
      var href = attrs && attrs.href !== null ? entities(attrs.href).trim() : ""
      out.push(/^(https?:\/\/|mailto:)/i.test(href) ? "<a href=\"" + escape(href) + "\">" : "<a>")
    }
    else out.push("<" + t + (t === "br" || t === "hr" ? " /" : "") + ">")
  })
  return out.join("")
}
// Words as HTML: "<", ">" and a "&" that doesn't start an entity escaped
// (entities left as they're written, for Qt).
function safeWords(text) {
  return String(text).replace(/&(?!(#x[0-9a-f]+|#\d+|[a-z][a-z0-9]*);)/gi, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
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
