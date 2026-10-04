// Bookmark.js - a link on a page in Pages, as a card: its page's title, a
// line about it, the site, and its picture (copied into Pages/assets when
// it was added, so nothing's fetched when the page is shown):
//
//   { url: "https://example.com/post", title: "A post", description: "...",
//     site: "example.com", image: "assets/bm-20261002-...png", color: "", background: "" }
//
// It reads what a web page says about itself (its title, and the
// description and picture it gives for links: Open Graph, Twitter cards).
// Shared with tests/bookmark.test.cjs, so keep it plain JavaScript with no
// QML or Node APIs.
.pragma library
.import "Mindmap.js" as Mindmap

function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

// A link that may be fetched and opened: http or https, no spaces, not too long.
function cleanUrl(url) {
  var s = String(url || "").trim()
  if (/^www\./i.test(s)) s = "https://" + s
  if (!/^https?:\/\/[^\s\/?#]+\.[^\s\/?#]+([\/?#][^\s]*)?$/i.test(s) || s.length > 2000) return ""
  return s
}

// ---- a page's picture, fetched by itself ---------------------------------------------------
//
// A bookmark's picture is named by the page (its og:image), not by you, so
// it's fetched only from the internet: https, a host that's a name, every
// address it has a public one (not this computer, your network, or a
// reserved range), from that address, never redirected elsewhere.

// { url, host, port } to fetch a page's picture from, or null.
function imageTarget(url) {
  var s = cleanUrl(url)
  var m = /^https:\/\/([A-Za-z0-9.-]{1,253})(?::(\d{1,5}))?(?:[\/?#]|$)/.exec(s)
  if (!m) return null
  var host = m[1].toLowerCase().replace(/\.$/, "")
  if (/^[0-9.]+$/.test(host) || !/\.[a-z][a-z0-9-]*$/.test(host)) return null
  if (/(^|\.)(localhost|local|localdomain|internal|intranet|lan|home|corp|private|arpa|test|invalid|example)$/.test(host)) return null
  var port = m[2] ? Number(m[2]) : 443
  if (port < 1 || port > 65535) return null
  return { url: s, host: host, port: port }
}

// The addresses `getent ahosts` printed, one of each.
function addresses(output) {
  var out = []
  String(output || "").split("\n").forEach(function(l) {
    var a = l.trim().split(/\s+/)[0] || ""
    if (/^[0-9a-fA-F:.]{2,45}$/.test(a) && out.indexOf(a.toLowerCase()) < 0) out.push(a.toLowerCase())
  })
  return out
}

// An address on the internet: not this computer, a local network, or a
// reserved or special range (IPv4, or IPv6 as global unicast).
function isPublicIp(ip) {
  var s = String(ip || "").trim().toLowerCase()
  var m = /^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/.exec(s)
  if (m) {
    var a = Number(m[1]), b = Number(m[2]), c = Number(m[3]), d = Number(m[4])
    if (a > 255 || b > 255 || c > 255 || d > 255) return false
    if (a === 0 || a === 10 || a === 127 || a >= 224) return false
    if (a === 100 && b >= 64 && b <= 127) return false
    if (a === 169 && b === 254) return false
    if (a === 172 && b >= 16 && b <= 31) return false
    if (a === 192 && (b === 168 || (b === 0 && (c === 0 || c === 2)) || (b === 88 && c === 99))) return false
    if (a === 198 && (b === 18 || b === 19 || (b === 51 && c === 100))) return false
    if (a === 203 && b === 0 && c === 113) return false
    return true
  }
  if (!/^[0-9a-f:]{2,39}$/.test(s) || s.indexOf(":") < 0) return false
  // Global unicast (2000::/3), but documentation, 6to4 and Teredo (which can
  // carry a local IPv4 address).
  return /^[23][0-9a-f]{0,3}:/.test(s) && !/^2001:(0?db8|0{0,4}):/.test(s) && !/^2002:/.test(s)
}

function domain(url) {
  var m = /^https?:\/\/([^\/?#:]+)/i.exec(String(url || ""))
  return m ? m[1].replace(/^www\./i, "").toLowerCase() : ""
}

function cleanLine(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max)
}

function make() { return { url: "", title: "", description: "", site: "", image: "", color: "", background: "" } }

function clean(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var out = make()
  out.url = cleanUrl(raw.url)
  out.title = cleanLine(raw.title, 300)
  out.description = cleanLine(raw.description, 600)
  out.site = cleanLine(raw.site, 100)
  var img = typeof raw.image === "string" ? raw.image : ""
  out.image = /^assets\/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(img) && img.indexOf("..") < 0 ? img : ""
  out.color = cleanColor(raw.color)
  out.background = cleanColor(raw.background)
  return out
}

var ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " ", ndash: "\u2013", mdash: "\u2014", hellip: "\u2026", rsquo: "\u2019", lsquo: "\u2018", rdquo: "\u201d", ldquo: "\u201c", middot: "\u00b7", copy: "\u00a9" }

function decode(s) {
  return String(s || "").replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/gi, function(all, e) {
    if (e.charAt(0) === "#") {
      var n = e.charAt(1).toLowerCase() === "x" ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10)
      return n > 0 && n < 0x110000 ? String.fromCodePoint(n) : ""
    }
    return ENTITIES[e.toLowerCase()] !== undefined ? ENTITIES[e.toLowerCase()] : all
  })
}

// The meta tags at the top of a page, read once along it: [{ key, content }]
// (<meta property="og:title" content="...">, either order). A tag that isn't
// closed ends the reading (nothing after it is read again for each "<meta").
var MAX_TAGS = 500
var MAX_TAG = 16000
function metas(head) {
  var s = String(head)
  var out = []
  var opener = /<meta\b/gi
  var m
  while (out.length < MAX_TAGS && (m = opener.exec(s)) !== null) {
    var end = s.indexOf(">", m.index)
    if (end < 0) break
    opener.lastIndex = end + 1
    var t = s.slice(m.index, Math.min(end + 1, m.index + MAX_TAG))
    var key = /\b(?:property|name)\s*=\s*["']([^"']+)["']/i.exec(t)
    if (!key) continue
    var c = /\bcontent\s*=\s*"([^"]*)"/i.exec(t) || /\bcontent\s*=\s*'([^']*)'/i.exec(t)
    out.push({ key: key[1].toLowerCase(), content: c ? c[1] : "" })
  }
  return out
}
// The first of `names` a tag has, with something in it.
function meta(tags, names) {
  for (var n = 0; n < names.length; n++) {
    for (var i = 0; i < tags.length; i++) {
      if (tags[i].key === names[n] && tags[i].content.trim()) return decode(tags[i].content)
    }
  }
  return ""
}
// The page's <title>: from the first "<title", past its ">", to the first
// </title> after it (each found once, along the text).
function titleOf(head) {
  var s = String(head)
  var open = /<title/i.exec(s)
  if (!open) return ""
  var gt = s.indexOf(">", open.index)
  if (gt < 0) return ""
  var close = /<\/title>/ig
  close.lastIndex = gt + 1
  var c = close.exec(s)
  return c ? decode(s.slice(gt + 1, c.index)) : ""
}

// A link against the page it's on: absolute.
function absolute(link, base) {
  var l = String(link || "").trim()
  if (!l) return ""
  if (/^https?:\/\//i.test(l)) return l
  var m = /^(https?:)\/\/([^\/?#]+)(\/[^?#]*)?/i.exec(base)
  if (!m) return ""
  if (l.indexOf("//") === 0) return m[1] + l
  if (l.charAt(0) === "/") return m[1] + "//" + m[2] + l
  var dir = (m[3] || "/").replace(/[^\/]*$/, "")
  return m[1] + "//" + m[2] + dir + l
}

// What a web page says about itself: { title, description, site, image (a link) }.
function parse(html, url) {
  var h = String(html || "").slice(0, 600000)
  var cut = h.search(/<\/head>/i)
  var head = cut >= 0 ? h.slice(0, cut) : h
  var tags = metas(head)
  var t = meta(tags, ["og:title", "twitter:title"])
  if (!t) t = titleOf(head)
  var d = meta(tags, ["og:description", "twitter:description", "description"])
  var site = meta(tags, ["og:site_name", "application-name"]) || domain(url)
  var img = meta(tags, ["og:image", "og:image:url", "twitter:image", "twitter:image:src"])
  return { title: cleanLine(t, 300), description: cleanLine(d, 600), site: cleanLine(site, 100), image: absolute(img, url) }
}

// A picture's name in assets, by its type: "bm-20261002-103012-k3f.png", or "".
function imageName(contentType, url, now, salt) {
  var ct = String(contentType || "").toLowerCase()
  var ext = /png/.test(ct) ? "png" : /jpe?g/.test(ct) ? "jpg" : /webp/.test(ct) ? "webp" : /gif/.test(ct) ? "gif" : ""
  if (!ext) { var m = /\.(png|jpe?g|webp|gif)(\?|#|$)/i.exec(String(url || "")); ext = m ? m[1].toLowerCase().replace("jpeg", "jpg") : "" }
  if (!ext) return ""
  var d = now || new Date()
  function two(n) { return (n < 10 ? "0" : "") + n }
  var tail = String(salt || Math.random().toString(36).slice(2, 5)).replace(/[^a-z0-9]/g, "").slice(0, 6) || "a"
  return "bm-" + d.getFullYear() + two(d.getMonth() + 1) + two(d.getDate()) + "-" + two(d.getHours()) + two(d.getMinutes()) + two(d.getSeconds()) + "-" + tail + "." + ext
}

function toMarkdown(b, prefix) {
  if (!b || !b.url) return "*(A bookmark, not added yet)*"
  var line = "[\u{1f516} " + (b.title || b.url).replace(/[\[\]]/g, "") + "](" + b.url + ")"
  return b.description ? line + "\n\n> " + b.description : line
}
