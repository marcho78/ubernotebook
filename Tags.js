// Tags.js - tags in Pages: "#idea" in any line. A tag is a link in the
// block's text, uber-notebook://tag/<name>, its words "#Idea" as they were written;
// its name is those words in lowercase, so #Idea and #idea are one tag. A
// name is letters, digits, "_", "-" and "/" (#project/uber-notebook), not only
// digits (#1 is a number), at most 60 long.
//
// It reads and writes tag links, finds the tags in a block and in a page,
// turns "#words" in text into tags (Markdown and Obsidian notes coming in),
// and renames and takes away a tag in a block's text. Shared with
// tests/tags.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html

var PREFIX = "uber-notebook://tag/"
// (What tags' links said before Uber Notebook was renamed: read the same.)
var LEGACY_PREFIX = "omanote://tag/"
var MAX = 60
// What a tag's name is made of (no white space, no punctuation but _ - /).
var CHARS = "[^\\s#,.;:!?()\\[\\]{}<>\"'`|\\\\@*~=+&^%$\\u2018\\u2019\\u201c\\u201d\\u00a0\\u2026]"
// "#name" where a tag can start: at the start, or after a space or a bracket.
var IN_TEXT = new RegExp("(^|[\\s(\\[{\"'\\u201c\\u2018])#(" + CHARS + "+)", "g")
var NAME = new RegExp("^" + CHARS + "+$")

// A tag's name from what's written ("Idea", "#Idea"), or "" if it isn't one.
function clean(value) {
  var t = String(value || "").trim().replace(/^#/, "").replace(/[\/-]+$/, "")
  if (!t || t.length > MAX || !NAME.test(t) || /^[\/-]/.test(t) || /^\d+$/.test(t)) return ""
  // (A tag's name is a key in what's kept: never the one that isn't.)
  if (t.toLowerCase() === "__proto__") return ""
  return t.toLowerCase()
}

// What a tag looks like in a line: "#" and its words as written.
function label(value) {
  var t = String(value || "").trim().replace(/^#/, "").replace(/[\/-]+$/, "")
  return clean(t) ? "#" + t : ""
}

function href(name) {
  var n = clean(name)
  return n ? PREFIX + encodeURIComponent(n) : ""
}

// The tag a link is, or "".
function of(url) {
  var s = String(url || "")
  var pre = s.indexOf(PREFIX) === 0 ? PREFIX : s.indexOf(LEGACY_PREFIX) === 0 ? LEGACY_PREFIX : ""
  if (!pre) return ""
  var name = ""
  try { name = decodeURIComponent(s.slice(pre.length)) } catch (e) { return "" }
  return clean(name) === name ? name : ""
}

// Is it a tag's link, as Uber Notebook writes them?
function isLink(url) { return of(url) !== "" }

// A tag's link in a block's text.
function html(value) {
  var name = clean(value)
  if (!name) return ""
  return "<a href=\"" + Html.escapeAttr(href(name)) + "\">" + Html.escapeText(label(value)) + "</a>"
}

// The tags in a block's text: [{ name, label }], each once, in order.
function inHtml(inner) {
  var out = []
  var seen = {}
  Html.links(inner || "").forEach(function(l) {
    var name = of(l.href)
    if (!name || seen[name]) return
    seen[name] = true
    out.push({ name: name, label: label(l.text) || "#" + name })
  })
  return out
}

// "#words" in a block's text (not in code or a link already) as tags.
function linkify(inner) {
  var s = String(inner || "")
  if (s.indexOf("#") < 0) return s
  var runs = Html.parse(s)
  var out = []
  var before = ""
  runs.forEach(function(run) {
    if (run.text === undefined || run.href || Html.isCode(run.style || {})) {
      out.push(run)
      before = run.br ? "\n" : run.text !== undefined ? run.text.slice(-1) : before
      return
    }
    var text = run.text
    var at = 0
    var m
    IN_TEXT.lastIndex = 0
    var found = false
    while ((m = IN_TEXT.exec(text)) !== null) {
      var lead = m[1]
      var start = m.index + lead.length
      // At the very start of the run, it's a tag only if what came before ends a word.
      if (m.index === 0 && lead === "" && before !== "" && !/[\s(\[{"'\u201c\u2018]/.test(before)) continue
      var word = m[2].replace(/[\/-]+$/, "")
      var name = clean(word)
      if (!name) continue
      found = true
      if (start > at) out.push({ text: text.slice(at, start), style: run.style, href: "" })
      out.push({ text: "#" + word, style: run.style, href: href(name) })
      at = start + 1 + word.length
      IN_TEXT.lastIndex = at
    }
    if (!found) out.push(run)
    else if (at < text.length) out.push({ text: text.slice(at), style: run.style, href: "" })
    before = text.slice(-1)
  })
  return Html.serialize(out)
}

// The tag `from` as `to` in a block's text (its link and its words).
function rename(inner, from, to) {
  var a = clean(from)
  var b = clean(to)
  if (!a || !b) return inner
  return Html.mapRuns(inner, function(run) {
    if (of(run.href) !== a) return run
    run.href = href(b)
    run.text = run.text.charAt(0) === "#" ? label(to) : run.text
    return run
  })
}

// The tag taken out of a block's text (its words and a space beside them).
function remove(inner, name) {
  var n = clean(name)
  if (!n) return inner
  var runs = Html.parse(inner || "")
  var out = []
  for (var i = 0; i < runs.length; i++) {
    var run = runs[i]
    if (run.text !== undefined && of(run.href) === n) {
      // One space goes with it: the one after it, else the one before.
      var next = runs[i + 1]
      var prev = out[out.length - 1]
      if (next && next.text !== undefined && /^ /.test(next.text) && (!prev || prev.br || /\s$/.test(prev.text || "") || out.length === 0)) next.text = next.text.slice(1)
      else if (prev && prev.text !== undefined && / $/.test(prev.text)) prev.text = prev.text.slice(0, -1)
      continue
    }
    out.push(run)
  }
  return Html.serialize(out.filter(function(r) { return r.br || r.img || r.text }))
}

// Tags whose names start with (or have) what's typed, best first: [name].
function matching(names, query, max) {
  var q = String(query || "").toLowerCase().replace(/^#/, "")
  var starts = []
  var has = []
  names.forEach(function(n) {
    if (!q || n.indexOf(q) === 0) starts.push(n)
    else if (n.indexOf(q) > 0) has.push(n)
  })
  return starts.concat(has).slice(0, max || 8)
}
