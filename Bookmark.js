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

// A meta tag's content: <meta property="og:title" content="..."> (either order).
function meta(html, names) {
  var tags = String(html).match(/<meta\b[^>]*>/gi) || []
  for (var n = 0; n < names.length; n++) {
    for (var i = 0; i < tags.length; i++) {
      var t = tags[i]
      var key = /\b(?:property|name)\s*=\s*["']([^"']+)["']/i.exec(t)
      if (!key || key[1].toLowerCase() !== names[n]) continue
      var c = /\bcontent\s*=\s*"([^"]*)"/i.exec(t) || /\bcontent\s*=\s*'([^']*)'/i.exec(t)
      if (c && c[1].trim()) return decode(c[1])
    }
  }
  return ""
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
  var head = h.split(/<\/head>/i)[0]
  var t = meta(head, ["og:title", "twitter:title"])
  if (!t) { var m = /<title[^>]*>([\s\S]*?)<\/title>/i.exec(head); t = m ? decode(m[1]) : "" }
  var d = meta(head, ["og:description", "twitter:description", "description"])
  var site = meta(head, ["og:site_name", "application-name"]) || domain(url)
  var img = meta(head, ["og:image", "og:image:url", "twitter:image", "twitter:image:src"])
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
