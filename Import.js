// Import.js - other people's notes as Pages: Markdown (Notion's, Obsidian's,
// GitHub's, anyone's), HTML (Notion's export too), plain text and Evernote's
// .enex, read into blocks with as little lost as possible: headings, bold,
// italics, strikethrough, highlights, code, links, nested lists, to-dos and
// whether they're ticked, quotes, callouts, code blocks and their language,
// dividers, pictures, toggles, columns (from Notion's HTML), colors, tables
// (their cells' formatting too), links between the pages imported.
//
// Every reader gives { title, icon, blocks }: blocks as the editor has them
// (in order, each with its depth), their text sanitized as any page's is.
// `ctx` says what can't be known here: ctx.link(href) -> the href to use
// (a link to another imported page becomes uber-notebook://page/<id>);
// ctx.image(src) -> "assets/<name>" for a picture that was copied in, or "";
// ctx.wiki(name) -> the id of the imported page called that, or "".
//
// A file can be anything, and this runs in the desktop shell: reading one
// takes time in step with its size (never more), goes no further than the
// limits below, and never ends in an error (a reader gives what it had read).
//
// Shared by the store (Workspace.qml), the editor (pasting Markdown) and
// tests/import.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html
.import "Blocks.js" as Blocks
.import "Mindmap.js" as Mindmap
.import "Tags.js" as Tags
.import "Board.js" as Board
.import "Bookmark.js" as Bookmark
.import "Equations.js" as Equations
.import "Notes.js" as Notes
.import "Library.js" as Library
.import "Papers.js" as Papers
.import "Sketch.js" as Sketch
.import "Table.js" as Table

var MONO = "'iA Writer Mono S'"
var HIGHLIGHT = "#fbf3db"

// ---- how far it reads ---------------------------------------------------------------------

// Quotes, lists, toggles and callouts inside each other this deep (Pages
// shows 12): what's in them deeper still is kept as text, at the deepest.
var MAX_NEST = 32
// HTML elements inside each other this deep: one deeper is read as if it
// were next to the deepest (as browsers do).
var MAX_HTML_DEPTH = 64
// Links inside links this deep (a picture in a link is one).
var MAX_LINK_NEST = 8
// HTML elements and runs of text read from one file.
var MAX_NODES = 200000
// Blocks read from one file (a page keeps Blocks.MAX_BLOCKS of them).
var MAX_BLOCKS = 2 * Blocks.MAX_BLOCKS
// A block's text is read this far: Pages keeps a block's text only when it's
// shorter (Blocks.clean).
var MAX_TEXT = 200000
// Text read from one file: about as much as a page can hold and still be
// opened again (a page's file is read up to 32 MiB, Workspace.qml).
var MAX_FILE_TEXT = 8000000
// Lines read from one Markdown or text file (far more than a page keeps).
var MAX_LINES = 200000
// Formatting (a bold word, a link, a code span…) read in one block's text: a
// block with more has more html than Pages keeps of one, so past it the
// text is read as it's written. And in one file.
var MAX_MARKS = 10000
var MAX_FILE_MARKS = 200000
// Footnotes read from one file.
var MAX_FOOTNOTES = 1000
// Notes read from one .enex file (each one a page).
var MAX_NOTES = 5000
// The longest link label looked up (as CommonMark has it).
var MAX_LABEL = 999

// (Marks a context that's been made, so it's passed on as it is.)
var MADE = {}

function context(ctx) {
  var c = ctx || {}
  return {
    made: MADE,
    link: given(c.link, function(h) { return h }),
    image: given(c.image, function(s) { return "" }),
    wiki: given(c.wiki, function(n) { return "" }),
    // A person in People by id, name, email or number (their id, or "").
    contact: given(c.contact, function(q) { return "" }),
    // An event on the calendar by id (true if it's there).
    event: given(c.event, function(id) { return false }),
    // Footnotes' words by their labels ([^1]: …, at the end).
    notes: c.notes && typeof c.notes === "object" ? c.notes : {},
    // How much of the file has been read, by everything reading it.
    read: { blocks: 0, text: 0, marks: 0, footnotes: 0, said: {}, label: -1 }
  }
}

// One of ctx's functions, or `otherwise` when there isn't one; and what
// `otherwise` gives for something the function goes wrong on.
function given(f, otherwise) {
  if (typeof f !== "function") return otherwise
  return function(x) {
    try { return f(x) } catch (e) { return otherwise(x) }
  }
}

// Has as much been read from the file as is read from one?
function full(read) {
  return read.blocks >= MAX_BLOCKS || read.text >= MAX_FILE_TEXT
}

// Text no longer than `max` (not cut between the halves of a character).
function cut(text, max) {
  if (text.length <= max) return text
  var n = Math.max(0, max)
  var c = text.charCodeAt(n - 1)
  if (c >= 0xd800 && c < 0xdc00) n--
  return text.slice(0, n)
}

// As much of a block's text as is read, counted as read.
function taken(read, text) {
  var t = cut(text, Math.min(MAX_TEXT, MAX_FILE_TEXT - read.text))
  read.text += t.length
  return t
}

// `list` joined with `sep`, no further than `max` characters.
function joinUpTo(list, sep, max) {
  var out = []
  var size = 0
  for (var i = 0; i < list.length && size <= max; i++) {
    out.push(list[i])
    size += list[i].length + sep.length
  }
  return cut(out.join(sep), max)
}

// Where `needle` is in `src`, from a place on: find(needle, from) -> its
// place, or -1. Each needle's places are found once, when first asked for,
// so asking costs little however often it's asked.
function finder(src) {
  var places = {}
  return function(needle, from) {
    var list = places[needle]
    if (!list) {
      list = places[needle] = []
      var at = src.indexOf(needle)
      while (at >= 0) { list.push(at); at = src.indexOf(needle, at + 1) }
    }
    var lo = 0
    var hi = list.length
    while (lo < hi) {
      var mid = (lo + hi) >> 1
      if (list[mid] < from) lo = mid + 1
      else hi = mid
    }
    return lo < list.length ? list[lo] : -1
  }
}

// As finder, for text that can be a whole file: nothing's found ahead of
// time, and what was found is used again when it can be (it can when
// places are asked about in order).
function scanner(src) {
  var last = {}
  return function(needle, from) {
    var l = last[needle]
    if (l && l.from <= from && (l.at < 0 || l.at >= from)) return l.at
    var at = src.indexOf(needle, from)
    last[needle] = { from: from, at: at }
    return at
  }
}

// A sticky pattern's end when it's matched at `at` (`at` when it isn't).
function skip(re, src, at) {
  re.lastIndex = at
  var m = re.exec(src)
  return m ? at + m[0].length : at
}

function own(table, key) {
  return Object.prototype.hasOwnProperty.call(table, key) ? table[key] : undefined
}

// A line break in a line of text (where "." stops).
var TERMINATOR = /[\n\r\u2028\u2029]/
var SPACES = /\s*/y

// ---- inline Markdown ----------------------------------------------------------------------

var PUNCT = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"
// Characters that are only ever text in a line of Markdown (read a run at a time).
var PLAIN = /[^\\`$\n<\[\^!*_~=hw]+/y
var AUTOLINK = /<((?:https?|mailto|file):[^\s<>]+)>/iy
var BARE_URL = /(?:https?:\/\/|www\.)[^\s<]*[^\s<.,:;"')\]]/iy
var TAG_OPEN = /<(\/?)([a-zA-Z][a-zA-Z0-9]*)/y
var HREF_RUN = /[^\s()]*/y
var TAG_STYLES = { b: { "font-weight": "700" }, strong: { "font-weight": "700" }, i: { "font-style": "italic" }, em: { "font-style": "italic" },
  u: { "text-decoration": "underline" }, ins: { "text-decoration": "underline" }, s: { "text-decoration": "line-through" }, del: { "text-decoration": "line-through" },
  strike: { "text-decoration": "line-through" }, mark: { "background-color": HIGHLIGHT }, code: { "font-family": MONO }, kbd: { "font-family": MONO },
  sup: { "vertical-align": "super" }, sub: { "vertical-align": "sub" } }

function styleWith(base, extra) {
  var s = {}
  for (var k in base) s[k] = base[k]
  for (var j in extra) {
    if (j === "text-decoration" && s[j]) s[j] = decorations(s[j], extra[j])
    else s[j] = extra[j]
  }
  return s
}

// "underline" and "line-through" together, each once.
function decorations(a, b) {
  var all = String(a).split(" ")
  String(b).split(" ").forEach(function(t) { if (t && all.indexOf(t) < 0) all.push(t) })
  return all.join(" ")
}

// A line (or lines) of Markdown text -> runs { text, style, href }, { br }.
// `nest`: how many links it's inside.
function inlineRuns(text, ctx, refs, nest) {
  var src = String(text || "")
  var atoms = []
  var i = 0
  // The spaces at the end of the last atom, when it's text.
  var tail = 0
  var find = finder(src)
  // Where code spans end, found at the first one.
  var codes = null
  // The text as links are read in it (see closeOf).
  var t = { src: src, find: find, closes: {}, steps: 0, limit: 4 * src.length + 4096, refs: false }
  for (var key in refs) if (Object.prototype.hasOwnProperty.call(refs, key)) { t.refs = true; break }
  var links = (nest || 0) < MAX_LINK_NEST
  var marks = 0
  function push(a) {
    if (a.t !== "text" && a.t !== "br") { marks++; ctx.read.marks++ }
    atoms.push(a)
  }
  function textAtom(s) {
    if (s === "") return
    var k = 0
    while (k < s.length && s.charCodeAt(s.length - 1 - k) === 32) k++
    var last = atoms[atoms.length - 1]
    if (last && last.t === "text") { last.v += s; tail = k === s.length ? tail + k : k }
    else { push({ t: "text", v: s }); tail = k }
  }
  while (i < src.length) {
    // Past as much formatting as is read, the rest as it's written.
    if (marks >= MAX_MARKS || ctx.read.marks >= MAX_FILE_MARKS) { textAtom(src.slice(i).replace(/\n/g, " ")); break }
    PLAIN.lastIndex = i
    var plain = PLAIN.exec(src)
    if (plain) { textAtom(plain[0]); i += plain[0].length; continue }
    var ch = src.charAt(i)
    // A backslash: the character after it as it is (or a line break).
    if (ch === "\\") {
      var nx = src.charAt(i + 1)
      if (nx === "\n") { push({ t: "br" }); i += 2; continue }
      if (nx && PUNCT.indexOf(nx) >= 0) { textAtom(nx); i += 2; continue }
      textAtom(ch); i++; continue
    }
    // Code: `...` (as many backticks either side).
    if (ch === "`") {
      var n = 0
      while (src.charAt(i + n) === "`") n++
      if (!codes) codes = codeEnds(src)
      var close = codes(n, i + n)
      if (close >= 0) {
        var code = src.slice(i + n, close).replace(/\n/g, " ")
        if (/^ .* $/.test(code) && /[^ ]/.test(code)) code = code.slice(1, -1)
        push({ t: "code", v: code })
        i = close + n
        continue
      }
      textAtom(src.substr(i, n)); i += n; continue
    }
    // An equation in the line: $…$ (or $$…$$), its LaTeX as written.
    if (ch === "$") {
      var eq = Equations.spanAt(src, i)
      if (eq && Equations.clean(eq.tex)) {
        push({ t: "link", href: Equations.href(eq.tex), runs: [{ text: Equations.clean(eq.tex), style: {}, href: "" }] })
        i = eq.end
        continue
      }
    }
    // A hard line break (two spaces before it) or a soft one.
    if (ch === "\n") {
      var before = atoms[atoms.length - 1]
      if (before && before.t === "text" && tail >= 2) { before.v = before.v.slice(0, before.v.length - tail); push({ t: "br" }) }
      else textAtom(" ")
      i++
      continue
    }
    // <https://...> and <mailto:...>
    if (ch === "<") {
      AUTOLINK.lastIndex = i
      var auto = AUTOLINK.exec(src)
      if (auto) { push({ t: "link", href: auto[1], runs: [{ text: auto[1], style: {}, href: "" }] }); i += auto[0].length; continue }
      var tag = inlineTag(src, i, find)
      if (tag) { push({ t: "tag", close: tag.close, name: tag.name, attrs: tag.attrs }); i = tag.end; continue }
    }
    // A footnote: [^label] (its words written at the end), or ^[its words].
    if (ch === "[" && src.charAt(i + 1) === "^") {
      var fn = footnoteAt(src, i, ctx)
      if (fn) {
        push({ t: "link", href: fn.href, runs: [{ text: fn.words, style: {}, href: "" }] })
        i = fn.end
        continue
      }
    }
    if (ch === "^" && src.charAt(i + 1) === "[" && ctx.read.footnotes < MAX_FOOTNOTES) {
      var fe = find("]", i + 2)
      if (fe > i + 2) {
        var said = Notes.fromMarkdown(cut(src.slice(i + 2, fe), 2 * Notes.MAX_NOTE))
        if (said) {
          ctx.read.footnotes++
          push({ t: "link", href: Notes.href(said), runs: [{ text: said, style: {}, href: "" }] })
          i = fe + 1
          continue
        }
      }
    }
    // [[Page]], [[Page|shown as]] (Obsidian, and others).
    if (ch === "[" && src.charAt(i + 1) === "[") {
      var wend = find("]]", i + 2)
      var nl = wend > i + 2 ? find("\n", i + 2) : -1
      if (wend > i + 2 && (nl < 0 || nl > wend)) {
        var inner = src.slice(i + 2, wend)
        var bar = inner.indexOf("|")
        var target = withoutHeading(bar >= 0 ? inner.slice(0, bar) : inner).trim()
        var shown = (bar >= 0 ? inner.slice(bar + 1) : inner).trim()
        var id = ctx.wiki(target)
        if (id) push({ t: "link", href: "uber-notebook://page/" + id, runs: [{ text: shown, style: {}, href: "" }] })
        else textAtom(shown)
        i = wend + 2
        continue
      }
    }
    // Pictures and links: ![alt](src "title"), [text](href "title"), [text][ref], [ref].
    if (links && (ch === "[" || (ch === "!" && src.charAt(i + 1) === "["))) {
      var isImage = ch === "!"
      var open = isImage ? i + 1 : i
      var link = parseLink(t, open, refs)
      if (link) {
        if (isImage) {
          // A picture in a line of text: a link to it (a picture of its own
          // line becomes a picture block, see readBlocks).
          var alt = link.text || "picture"
          var local = ctx.image(link.href)
          if (/^https?:/i.test(link.href)) push({ t: "link", href: link.href, runs: [{ text: alt, style: {}, href: "" }] })
          else textAtom(local ? alt : alt)
        } else {
          var hrefOut = ctx.link(link.href)
          push({ t: "link", href: hrefOut, runs: inlineRuns(link.text, ctx, refs, (nest || 0) + 1) })
        }
        i = link.end
        continue
      }
    }
    // Delimiters: * _ ~ = (bold, italics, strikethrough, highlights).
    if (ch === "*" || ch === "_" || ch === "~" || ch === "=") {
      var m = 0
      while (src.charAt(i + m) === ch) m++
      var prev = i > 0 ? src.charAt(i - 1) : " "
      var next = src.charAt(i + m) || " "
      var ws = /\s/
      var pu = /[!-/:-@[-`{-~]/
      var leftFlank = !ws.test(next) && (!pu.test(next) || ws.test(prev) || pu.test(prev))
      var rightFlank = !ws.test(prev) && (!pu.test(prev) || ws.test(next) || pu.test(next))
      var canOpen = leftFlank
      var canClose = rightFlank
      // snake_case isn't italics.
      if (ch === "_") {
        canOpen = leftFlank && (!rightFlank || pu.test(prev))
        canClose = rightFlank && (!leftFlank || pu.test(next))
      }
      if ((ch === "~" || ch === "=") && m !== 2) { textAtom(src.substr(i, m)); i += m; continue }
      push({ t: "delim", ch: ch, n: m, open: canOpen, close: canClose, orig: m })
      i += m
      continue
    }
    // A bare web address (as GitHub makes into a link).
    if ((ch === "h" || ch === "w") && (i === 0 || /[\s(]/.test(src.charAt(i - 1)))) {
      BARE_URL.lastIndex = i
      var bare = BARE_URL.exec(src)
      if (bare) {
        var url = /^www\./i.test(bare[0]) ? "https://" + bare[0] : bare[0]
        push({ t: "link", href: url, runs: [{ text: bare[0], style: {}, href: "" }] })
        i += bare[0].length
        continue
      }
    }
    textAtom(ch)
    i++
  }
  return resolve(atoms)
}

// Where code spans in `src` end: a function (n, from) -> where the n
// backticks that end one opened with n (just before `from`) are, or -1. As
// they always have: in the first run of backticks after it that's n long,
// or 2n+1, 3n+2... (the last n end it; the ones before them are code).
function codeEnds(src) {
  var starts = []
  var lengths = []
  var at = src.indexOf("`")
  while (at >= 0) {
    var k = at
    while (src.charAt(k) === "`") k++
    starts.push(at)
    lengths.push(k - at)
    at = src.indexOf("`", k)
  }
  // For each n, the runs that can end a span of n, in order: a run L long
  // can when n + 1 divides L + 1.
  var runs = {}
  function add(n, r) { if (n >= 1) (runs[n] || (runs[n] = [])).push(r) }
  for (var r = 0; r < starts.length; r++) {
    var whole = lengths[r] + 1
    for (var d = 1; d * d <= whole; d++) {
      if (whole % d !== 0) continue
      add(d - 1, r)
      if (d * d !== whole) add(whole / d - 1, r)
    }
  }
  var next = {}
  return function(n, from) {
    var list = runs[n]
    if (!list) return -1
    var j = next[n] || 0
    while (j < list.length && starts[list[j]] < from) j++
    next[n] = j
    return j < list.length ? starts[list[j]] + lengths[list[j]] - n : -1
  }
}

// An html tag in a line of Markdown at `i` ("<b>", "</span>", "<br/>"):
// { close, name, attrs, end }, or null. As the pattern
//   <(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[^<>]*?)?)\s*(\/?)>
// finds one: it ends at the first ">", with no "<" before it.
function inlineTag(src, i, find) {
  TAG_OPEN.lastIndex = i
  var m = TAG_OPEN.exec(src)
  if (!m) return null
  var gt = find(">", i + 1)
  var lt = find("<", i + 1)
  if (gt < 0 || (lt >= 0 && lt < gt)) return null
  var x = src.slice(i + m[0].length, gt)
  var attrs = ""
  if (x !== "" && x !== "/") {
    var lead = skip(SPACES, x, 0)
    if (lead === 0) return null
    var e = x.length
    if (x.charAt(e - 1) === "/") e--
    while (e > lead && /\s/.test(x.charAt(e - 1))) e--
    attrs = x.slice(0, e)
  }
  return { close: m[1] === "/", name: m[2].toLowerCase(), attrs: attrs, end: gt + 1 }
}

// A footnote's mark at `i` ("[^1]", its words written at the end of the
// file): { words, href, end }, or null.
function footnoteAt(src, i, ctx) {
  var read = ctx.read
  if (read.footnotes >= MAX_FOOTNOTES) return null
  // (The longest label, so a mark is looked for no further.)
  if (read.label < 0) {
    read.label = 0
    for (var key in ctx.notes) if (Object.prototype.hasOwnProperty.call(ctx.notes, key)) read.label = Math.max(read.label, key.length)
  }
  var j = i + 2
  var stop = Math.min(src.length, j + read.label + 1)
  while (j < stop && src.charAt(j) !== "]" && !/\s/.test(src.charAt(j))) j++
  if (j === i + 2 || src.charAt(j) !== "]") return null
  var label = src.slice(i + 2, j)
  if (!Object.prototype.hasOwnProperty.call(ctx.notes, label)) return null
  // Its words, worked out once however often it's marked.
  var said = own(read.said, "[^" + label)
  if (!said) {
    var words = Notes.fromMarkdown(cut(String(ctx.notes[label] || ""), 2 * Notes.MAX_NOTE))
    said = read.said["[^" + label] = { words: words, href: words ? Notes.href(words) : "" }
  }
  if (!said.words) return null
  read.footnotes++
  return { words: said.words, href: said.href, end: j + 1 }
}

// `text` without a "#heading" at its end (as /#.*$/ takes one off).
function withoutHeading(text) {
  var last = Math.max(text.lastIndexOf("\r"), text.lastIndexOf("\u2028"), text.lastIndexOf("\u2029"), text.lastIndexOf("\n"))
  var hash = text.indexOf("#", last + 1)
  return hash >= 0 ? text.slice(0, hash) : text
}

// [text](href "title") at `open` (the "["): { text, href, end }, or null.
// `t`: the text it's in, as inlineRuns reads it.
function parseLink(t, open, refs) {
  var src = t.src
  var j = closeOf(t, open)
  if (j < 0) return null
  var text = src.slice(open + 1, j)
  var inl = inlineLink(t, j + 1)
  if (inl) return { text: text, href: decodeHref(inl.href.replace(/^<|>$/g, "")), end: inl.end }
  if (!t.refs) return null
  var ref = null
  if (src.charAt(j + 1) === "[") {
    var k = t.find("]", j + 2)
    if (k >= 0) ref = { label: src.slice(j + 2, k), length: k - j }
  }
  var raw = ref && ref.label ? ref.label : text
  if (raw.length > MAX_LABEL) return null
  var key = raw.toLowerCase().replace(/\s+/g, " ").trim()
  var href = own(refs, key)
  return href ? { text: text, href: href, end: j + 1 + (ref ? ref.length : 0) } : null
}

// Where the "]" for the "[" at `open` is (past a backslash's character,
// and code between backticks, as it's always been looked for), or -1. Every
// "[" on the way is remembered too, so a text is gone through about once
// however many it has; one that would take much longer than that keeps the
// rest of its brackets as they are.
function closeOf(t, open) {
  var known = t.closes[open]
  if (known !== undefined) return known
  var src = t.src
  var stack = []
  for (var j = open; j < src.length; j++) {
    if (++t.steps > t.limit) { t.closes[open] = -1; return -1 }
    var c = src.charCodeAt(j)
    if (c === 92) { j++; continue }
    if (c === 96) { var k = t.find("`", j + 1); if (k > j) j = k; continue }
    if (c === 91) {
      var done = t.closes[j]
      if (done === undefined) { stack.push(j); continue }
      // (One already found: past it; or never closed, nor is what's around it.)
      if (done < 0) break
      j = done
      continue
    }
    if (c === 93 && stack.length) {
      var o = stack.pop()
      t.closes[o] = j
      if (o === open) return j
    }
  }
  for (var s = 0; s < stack.length; s++) t.closes[stack[s]] = -1
  return -1
}

// "(href "title")" at `at`: { href, end }, or null. As the pattern
//   \(\s*(<[^>]*>|[^\s()]*(?:\([^\s()]*\)[^\s()]*)*)(?:\s+("[^"]*"|'[^']*'|\([^)]*\)))?\s*\)
// finds it, in the order it tries things.
function inlineLink(t, at) {
  var src = t.src
  if (src.charAt(at) !== "(") return null
  var d = skip(SPACES, src, at + 1)
  if (src.charAt(d) === "<") {
    var gt = t.find(">", d + 1)
    if (gt >= 0) {
      var e1 = linkEnd(t, gt + 1)
      if (e1 >= 0) return { href: src.slice(d, gt + 1), end: e1 }
    }
  }
  // An address with brackets in it (one deep).
  var e = skip(HREF_RUN, src, d)
  while (src.charAt(e) === "(") {
    var f = skip(HREF_RUN, src, e + 1)
    if (src.charAt(f) !== ")") break
    e = skip(HREF_RUN, src, f + 1)
  }
  var e2 = linkEnd(t, e)
  if (e2 >= 0) return { href: src.slice(d, e), end: e2 }
  // No address, then a title after the white space.
  if (d > at + 1) {
    var e3 = titleEnd(t, d)
    if (e3 >= 0) {
      var c3 = skip(SPACES, src, e3)
      if (src.charAt(c3) === ")") return { href: "", end: c3 + 1 }
    }
  }
  return null
}

// After a link's address at `e`: a title (or not), then ")". Just past it, or -1.
function linkEnd(t, e) {
  var src = t.src
  var w = skip(SPACES, src, e)
  if (w > e) {
    var te = titleEnd(t, w)
    if (te >= 0) {
      var c = skip(SPACES, src, te)
      if (src.charAt(c) === ")") return c + 1
    }
  }
  return src.charAt(w) === ")" ? w + 1 : -1
}

// A link's title at `w` ("…", '…' or (…)): just past it, or -1.
function titleEnd(t, w) {
  var c = t.src.charAt(w)
  var close = c === "\"" ? "\"" : c === "'" ? "'" : c === "(" ? ")" : ""
  if (!close) return -1
  var k = t.find(close, w + 1)
  return k >= 0 ? k + 1 : -1
}

function decodeHref(href) {
  return String(href).replace(/\\([!-\/:-@\[-`{-~])/g, "$1")
}

// Matches delimiters (* ** _ __ ~~ ==) into styles, then gives the runs.
function resolve(atoms) {
  var spans = []
  var stack = []
  // For each kind of closer (its character, its length's remainder by 3,
  // whether it opens too): below here on the stack is nothing it can close.
  var floor = {}
  for (var i = 0; i < atoms.length; i++) {
    var a = atoms[i]
    if (a.t !== "delim") continue
    var kind = a.ch + (a.orig % 3) + (a.open ? "+" : "-")
    // A closer takes the nearest opener of its kind, as much of it as it can.
    var matched = a.close
    while (matched && a.n > 0) {
      matched = false
      for (var s = stack.length - 1; s >= (floor[kind] || 0); s--) {
        var o = atoms[stack[s]]
        if (o.ch !== a.ch || o.n === 0) continue
        // "Rule of three": *a**b* isn't a match of * with **.
        if ((o.close || a.open) && (o.orig + a.orig) % 3 === 0 && !(o.orig % 3 === 0 && a.orig % 3 === 0) && o.ch !== "~" && o.ch !== "=") continue
        var use = a.ch === "~" || a.ch === "=" ? 2 : (o.n >= 2 && a.n >= 2 ? 2 : 1)
        spans.push({ from: stack[s], to: i, kind: a.ch === "~" ? "s" : a.ch === "=" ? "m" : use === 2 ? "b" : "i" })
        o.n -= use
        a.n -= use
        // Openers after it can't close any more.
        stack.length = o.n > 0 ? s + 1 : s
        for (var f in floor) if (floor[f] > stack.length) floor[f] = stack.length
        matched = true
        break
      }
      if (!matched) floor[kind] = stack.length
    }
    if (a.n > 0 && a.open) stack.push(i)
  }
  // Each span's style applies between its delimiters: from the atom after
  // its first to the one before its last.
  var starts = []
  var ends = []
  spans.forEach(function(sp) {
    (starts[sp.from + 1] || (starts[sp.from + 1] = [])).push(sp.kind)
    ;(ends[sp.to] || (ends[sp.to] = [])).push(sp.kind)
  })
  var on = { b: 0, i: 0, s: 0, m: 0 }
  // Styles from html tags: <b>, <i>, <u>, <s>, <mark>, <code>, <sup>, <sub>, <span style>.
  var tags = []
  var tagStyle = {}
  function styleNow() {
    var st = {}
    for (var k in tagStyle) st[k] = tagStyle[k]
    if (on.b > 0) st["font-weight"] = "700"
    if (on.i > 0) st["font-style"] = "italic"
    if (on.s > 0) st["text-decoration"] = st["text-decoration"] ? decorations(st["text-decoration"], "line-through") : "line-through"
    if (on.m > 0) st["background-color"] = HIGHLIGHT
    return st
  }
  var runs = []
  for (var k = 0; k < atoms.length; k++) {
    if (ends[k]) ends[k].forEach(function(name) { on[name]-- })
    if (starts[k]) starts[k].forEach(function(name) { on[name]++ })
    var at = atoms[k]
    if (at.t === "text") runs.push({ text: at.v, style: styleNow(), href: "" })
    else if (at.t === "br") runs.push({ br: true })
    else if (at.t === "code") runs.push({ text: at.v, style: styleWith(styleNow(), { "font-family": MONO }), href: "" })
    else if (at.t === "delim" && at.n > 0) runs.push({ text: new Array(at.n + 1).join(at.ch), style: styleNow(), href: "" })
    else if (at.t === "link") {
      var outer = styleNow()
      at.runs.forEach(function(r) {
        if (r.br) { runs.push(r); return }
        runs.push({ text: r.text, style: styleWith(outer, r.style), href: at.href })
      })
    } else if (at.t === "tag") {
      var name = at.name
      if (name === "br") { runs.push({ br: true }); continue }
      if (at.close) {
        for (var q = tags.length - 1; q >= 0; q--) {
          if (tags[q].name !== name) continue
          tags.splice(q, 1)
          tagStyle = {}
          tags.forEach(function(tg) { tagStyle = styleWith(tagStyle, tg.style) })
          break
        }
      } else if (tags.length < MAX_HTML_DEPTH && (own(TAG_STYLES, name) || name === "span" || name === "font")) {
        var st2 = own(TAG_STYLES, name) || {}
        if (name === "span" || name === "font") {
          var css = /style\s*=\s*"([^"]*)"/i.exec(at.attrs)
          if (css) css[1].split(";").forEach(function(decl) {
            var p = decl.split(":")
            if (p.length < 2) return
            var key = p[0].trim().toLowerCase()
            var val = p.slice(1).join(":").trim()
            if (key === "color" || key === "background-color") st2[key] = val
          })
          var color = /color\s*=\s*"([^"]*)"/i.exec(at.attrs)
          if (name === "font" && color) st2.color = color[1]
        }
        tags.push({ name: name, style: st2 })
        tagStyle = styleWith(tagStyle, st2)
      }
    }
  }
  return runs
}

// (Obsidian's "#tags" are tags.)
function inlineHtml(text, ctx, refs) {
  var c = ctx && ctx.made === MADE ? ctx : context(ctx)
  var html = Html.sanitize(Html.serialize(inlineRuns(taken(c.read, String(text || "")), c, refs || {}, 0)), true)
  return tagSafe(html) ? Tags.linkify(html) : html
}

// Tags.js takes long over a "#word" with a long run of "-" or "/" inside it
// (none is a tag: a tag is at most 60 long), so text with such a run isn't
// read for tags.
var LONG_RUN = /[\/-]{61,}/g
var TAG_CHAR = new RegExp("^" + Tags.CHARS + "$")

function tagSafe(html) {
  if (html.indexOf("#") < 0) return true
  LONG_RUN.lastIndex = 0
  var m
  while ((m = LONG_RUN.exec(html)) !== null) {
    if (TAG_CHAR.test(html.charAt(m.index + m[0].length))) return false
  }
  return true
}

// ---- Markdown blocks ----------------------------------------------------------------------

var CALLOUTS = {
  note: { icon: "\u2139\ufe0f", color: "blue_background" }, info: { icon: "\u2139\ufe0f", color: "blue_background" },
  tip: { icon: "\u{1f4a1}", color: "green_background" }, hint: { icon: "\u{1f4a1}", color: "green_background" },
  important: { icon: "\u2757", color: "purple_background" }, warning: { icon: "\u26a0\ufe0f", color: "yellow_background" },
  caution: { icon: "\u{1f525}", color: "red_background" }, danger: { icon: "\u{1f525}", color: "red_background" },
  todo: { icon: "\u2611\ufe0f", color: "gray_background" }, example: { icon: "\u{1f4dd}", color: "gray_background" },
  quote: { icon: "\u{1f4ac}", color: "gray_background" }, success: { icon: "\u2705", color: "green_background" },
  question: { icon: "\u2753", color: "yellow_background" }, bug: { icon: "\u{1f41b}", color: "red_background" },
  abstract: { icon: "\u{1f4cb}", color: "blue_background" }, summary: { icon: "\u{1f4cb}", color: "blue_background" }
}

function isBlank(line) {
  // (Most lines have words at one end or the other: no need to read them through.)
  if (line !== "" && (/\S/.test(line.charAt(0)) || /\S/.test(line.charAt(line.length - 1)))) return false
  return /^\s*$/.test(line)
}

// The spaces a line starts with (counted to 32: nothing needs more, and a
// line in a list in a list... is counted again at each).
function leading(line) {
  var n = 0
  while (n < 32 && line.charCodeAt(n) === 32) n++
  return n
}

// What follows a line's start (a pattern's match there) up to its end, or
// null when there's a line break in it ((.*)$ can't reach the end then).
function restOf(line, m) {
  var rest = line.slice(m[0].length)
  return TERMINATOR.test(rest) ? null : rest
}

function listMarker(line) {
  var m = /^( {0,3})([-*+]|\d{1,9}[.)])( +|$)/.exec(line)
  var rest = m ? restOf(line, m) : null
  if (rest === null) return null
  if (m[3] === "" && rest === "") return { indent: m[1].length, ordered: /\d/.test(m[2]), start: m[1].length + m[2].length + 1, rest: "", marker: m[2] }
  var pad = m[3].length > 4 ? 1 : m[3].length
  return { indent: m[1].length, ordered: /\d/.test(m[2]), start: m[1].length + m[2].length + pad, rest: m[3].length > 4 ? m[3].slice(1) + rest : rest, marker: m[2] }
}

// ``` or ~~~ (or more), then the language, and no backtick after.
function fenceStart(line) {
  var m = /^( {0,3})(`{3,}|~{3,})/.exec(line)
  if (!m) return null
  var rest = line.slice(m[0].length)
  if (rest.indexOf("`") >= 0) return null
  return { indent: m[1].length, fence: m[2], lang: /^\s*([^`\s]*)/.exec(rest)[1] }
}

// A fence's end: as many of its character (or more) and only white space after.
function fenceEnd(line, f) {
  var i = leading(line) > 3 ? 3 : leading(line)
  var c = f.fence.charAt(0)
  var k = i
  while (line.charAt(k) === c) k++
  return k - i >= f.fence.length && isBlank(line.slice(k))
}

// Tabs as four spaces, for reading where things are; but code in a fence
// keeps its own (a Makefile needs them).
function expandTabs(lines) {
  var fence = null
  return lines.map(function(raw) {
    var line = raw.replace(/\t/g, "    ")
    if (fence) {
      if (!fenceEnd(line, fence)) return raw
      fence = null
      return line
    }
    fence = fenceStart(line)
    return line
  })
}

function isRule(line) {
  return /^ {0,3}((\*[ \t]*){3,}|(-[ \t]*){3,}|(_[ \t]*){3,})$/.test(line)
}

// "# Heading" (to "######"): { level, text } (closing #s left out), or null.
function heading(line) {
  var m = /^ {0,3}(#{1,6})(?=[ \t]|$)/.exec(line)
  var rest = m ? restOf(line, m) : null
  if (rest === null) return null
  function blank(at) { var c = rest.charAt(at); return c === " " || c === "\t" }
  var a = 0
  while (a < rest.length && blank(a)) a++
  var b = rest.length
  while (b > a && blank(b - 1)) b--
  var h = b
  while (h > a && rest.charAt(h - 1) === "#") h--
  if (h < b && h > a && blank(h - 1)) {
    b = h
    while (b > a && blank(b - 1)) b--
  }
  return { level: m[1].length, text: rest.slice(a, b) }
}

// A table's row: its cells (at most `max`), or null.
function tableRow(line, max) {
  var t = line.trim()
  if (t.indexOf("|") < 0) return null
  if (t.charAt(0) === "|") t = t.slice(1)
  if (t.charAt(t.length - 1) === "|" && t.charAt(t.length - 2) !== "\\") t = t.slice(0, -1)
  var cells = []
  var cell = ""
  var from = 0
  for (var i = 0; i < t.length; i++) {
    var c = t.charCodeAt(i)
    if (c === 92 && t.charCodeAt(i + 1) === 124) { cell += t.slice(from, i) + "|"; i++; from = i + 1; continue }
    if (c !== 124) continue
    cells.push((cell + t.slice(from, i)).trim())
    cell = ""
    from = i + 1
    if (max && cells.length >= max) return cells
  }
  cells.push((cell + t.slice(from)).trim())
  return cells
}

// "| --- | :-: |": each cell dashes (colons at their ends), pipes between.
function isTableRule(line) {
  if (line.indexOf("-") < 0) return false
  var a = skip(SPACES, line, 0)
  var b = line.length
  while (b > a && /\s/.test(line.charAt(b - 1))) b--
  var t = line.slice(a, b)
  if (t.charAt(0) === "|") t = t.slice(1)
  if (t.charAt(t.length - 1) === "|") t = t.slice(0, -1)
  return t.split("|").every(function(cell) { return /^\s*:?-+:?\s*$/.test(cell) })
}

// Link references anywhere: [id]: href "title" (taken out of the text).
function collectRefs(lines) {
  var refs = {}
  var out = []
  var inFence = false
  lines.forEach(function(line) {
    if (fenceStart(line)) inFence = !inFence
    var m = !inFence ? /^ {0,3}\[([^\]]+)\]:\s*<?([^\s>]+)>?(?:\s+("[^"]*"|'[^']*'|\([^)]*\)))?\s*$/.exec(line) : null
    if (m && m[1].charAt(0) !== "^") refs[m[1].toLowerCase().replace(/\s+/g, " ").trim()] = m[2]
    else out.push(line)
  })
  return { refs: refs, lines: out }
}

// A toggle's <summary>…</summary>: { text, rest } (rest: what's around
// it), or null. As /<summary[^>]*>([\s\S]*?)<\/summary>/i finds it.
function summaryOf(all) {
  var open = /<summary/i.exec(all)
  if (!open) return null
  var gt = all.indexOf(">", open.index + 8)
  if (gt < 0) return null
  var end = /<\/summary>/ig
  end.lastIndex = gt + 1
  var close = end.exec(all)
  if (!close) return null
  return { text: all.slice(gt + 1, close.index), rest: all.slice(0, open.index) + all.slice(close.index + close[0].length) }
}

// "> [!NOTE] words": [, kind, words], or null.
function calloutStart(line) {
  var m = /^\s*\[!(\w+)\][+-]?\s*/.exec(line)
  var rest = m ? restOf(line, m) : null
  return rest === null ? null : [line, m[1], rest]
}

// Notion's callout's first line, its emoji first: [, emoji, words], or null.
function iconStart(line) {
  var m = /^\s*(\S{1,16})\s+/.exec(line)
  var rest = m ? restOf(line, m) : null
  return rest === null ? null : [line, m[1], rest]
}

// A to-do's "[ ] " or "[x] ": [, mark, words], or null.
function taskStart(line) {
  var m = /^\[([ xX])\](?:[ \t]+|$)/.exec(line)
  var rest = m ? restOf(line, m) : null
  return rest === null ? null : [line, m[1], rest]
}

// A line that's only an <img> tag: [, src], or null. (One that says "src"
// many times isn't read as one: the pattern would take too long over it.)
function imgLine(line) {
  if (!/^\s*<img\b/i.test(line)) return null
  var lower = line.toLowerCase()
  var n = 0
  for (var at = lower.indexOf("src"); at >= 0 && n <= 8; at = lower.indexOf("src", at + 3)) n++
  return n > 8 ? null : /^\s*<img\b[^>]*\bsrc\s*=\s*"([^"]+)"[^>]*>\s*$/i.exec(line)
}

// Lines of Markdown -> blocks (flat, with depths from 0). `depth`: how deep
// in quotes, lists and toggles the lines are; the blocks go in `out`.
function readBlocks(lines, ctx, refs, depth, out) {
  var blocks = out || []
  var read = ctx.read
  // Deeper than this, what's in a quote, a list or a toggle is text.
  var nest = (depth || 0) < MAX_NEST
  var i = 0
  // (No line closes a "$$" from here on.)
  var noCloser = false
  function emit(b) { read.blocks++; blocks.push(b) }
  function within(list) { list.forEach(function(b) { b.indent += 1; blocks.push(b) }) }
  function inside(list) { return readBlocks(list, ctx, refs, (depth || 0) + 1) }
  function para(text) {
    var html = inlineHtml(text, ctx, refs)
    return { type: "p", html: html, indent: 0 }
  }
  function startsBlock(line) {
    return heading(line) || fenceStart(line) || isRule(line) || /^ {0,3}>/.test(line) || listMarker(line) || /^ {0,3}<(details|aside)\b/i.test(line) || /^ {0,3}\$\$/.test(line)
  }
  while (i < lines.length && !full(read)) {
    var line = lines[i]
    if (isBlank(line)) { i++; continue }

    // Code: ``` or ~~~, with its language.
    var f = fenceStart(line)
    if (f) {
      var code = []
      var size = 0
      i++
      while (i < lines.length && !fenceEnd(lines[i], f)) {
        if (size <= MAX_TEXT) { code.push(lines[i].slice(Math.min(f.indent, leading(lines[i])))); size += lines[i].length + 1 }
        i++
      }
      i++
      var text = taken(read, joinUpTo(code, "\n", MAX_TEXT))
      // A board, a person's card, a day's agenda, an event, a bookmark.
      var made = fenced(f.lang, text, ctx)
      if (made) { emit(made); continue }
      var map = mindMap(f.lang, text)
      if (map) emit({ type: "mindmap", outline: map, indent: 0 })
      else emit({ type: "code", html: Html.fromPlainText(text), lang: langName(f.lang), indent: 0 })
      continue
    }

    // An equation on its own: "$$" lines around it, or "$$ … $$" on one line.
    var dd = /^ {0,3}\$\$(.*)$/.exec(line)
    if (dd) {
      var one = /^(.*)\$\$\s*$/.exec(dd[1])
      var eqLines = null
      var eqEnd = i + 1
      if (one && one[1].trim()) eqLines = [one[1]]
      else if (!one && !noCloser) {
        var body = dd[1].trim() ? [dd[1]] : []
        var bodySize = 0
        for (var j = i + 1; j < lines.length; j++) {
          var closing = /^(.*?)\$\$\s*$/.exec(lines[j])
          if (closing) {
            if (closing[1].trim()) body.push(closing[1])
            eqLines = body
            eqEnd = j + 1
            break
          }
          if (bodySize <= MAX_TEXT) { body.push(lines[j]); bodySize += lines[j].length + 1 }
        }
        if (!eqLines) noCloser = true
      }
      var tex = eqLines ? Equations.clean(joinUpTo(eqLines, "\n", MAX_TEXT)) : ""
      if (tex) {
        emit({ type: "code", html: Html.fromPlainText(tex), lang: Equations.LANG, indent: 0 })
        i = eqEnd
        continue
      }
    }

    var h = heading(line)
    if (h) {
      emit({ type: h.level === 1 ? "h1" : h.level === 2 ? "h2" : "h3", html: inlineHtml(h.text, ctx, refs), indent: 0 })
      i++
      continue
    }

    if (isRule(line)) { emit({ type: "divider", indent: 0 }); i++; continue }

    // A quote (or a callout: "> [!NOTE]"), and what's inside it.
    if (nest && /^ {0,3}>/.test(line)) {
      var q = []
      while (i < lines.length && (/^ {0,3}>/.test(lines[i]) || (!isBlank(lines[i]) && q.length && !isBlank(q[q.length - 1]) && !startsBlock(lines[i])))) {
        q.push(lines[i].replace(/^ {0,3}> ?/, ""))
        i++
      }
      var callout = calloutStart(q[0] || "")
      var inner = inside(callout ? [callout[2]].concat(q.slice(1)) : q)
      var head = inner.length && inner[0].type === "p" && inner[0].indent === 0 ? inner.shift() : { html: "" }
      var kind = callout ? own(CALLOUTS, callout[1].toLowerCase()) || CALLOUTS.note : null
      emit(kind ? { type: "callout", icon: kind.icon, color: kind.color, html: head.html, indent: 0 } : { type: "quote", html: head.html, indent: 0 })
      within(inner)
      continue
    }

    // Toggles and callouts written as HTML (GitHub's <details>, Notion's <aside>).
    var det = nest ? /^ {0,3}<(details|aside)\b[^>]*>(.*)$/i.exec(line) : null
    if (det) {
      var tagName = det[1].toLowerCase()
      var lines2 = [det[2]]
      i++
      var closeRe = new RegExp("</" + tagName + ">", "i")
      if (!closeRe.test(det[2])) {
        while (i < lines.length && !closeRe.test(lines[i])) { lines2.push(lines[i]); i++ }
        if (i < lines.length) { lines2.push(lines[i]); i++ }
      }
      var all = lines2.join("\n").replace(closeRe, "")
      if (tagName === "details") {
        var sum = summaryOf(all)
        emit({ type: "toggle", html: inlineHtml(sum ? sum.text.trim() : "", ctx, refs), indent: 0 })
        within(inside((sum ? sum.rest : all).split("\n")))
      } else {
        var parts = all.trim().split("\n")
        // Notion starts an <aside> with the callout's emoji.
        var em = iconStart(parts[0] || "")
        var iconWord = em && !/[A-Za-z0-9<>&*_`#\[\]]/.test(em[1]) ? em[1] : ""
        var insideAside = inside(iconWord ? [em[2]].concat(parts.slice(1)) : parts)
        var first = insideAside.length && insideAside[0].type === "p" && insideAside[0].indent === 0 ? insideAside.shift() : { html: "" }
        emit({ type: "callout", icon: iconWord || "\u{1f4a1}", color: "gray_background", html: first.html, indent: 0 })
        within(insideAside)
      }
      continue
    }

    // Lists: bullets, numbers, to-dos, and everything inside each item.
    var lm = nest ? listMarker(line) : null
    if (lm) {
      var item = [lm.rest]
      i++
      var sawBlank = false
      while (i < lines.length) {
        var l = lines[i]
        if (isBlank(l)) { item.push(""); sawBlank = true; i++; continue }
        if (leading(l) >= lm.start) { item.push(l.slice(lm.start)); sawBlank = false; i++; continue }
        // A line that just goes on with the item's text.
        if (!sawBlank && !startsBlock(l) && !isTableRule(l)) { item.push(l); i++; continue }
        break
      }
      while (item.length && isBlank(item[item.length - 1])) item.pop()
      var task = taskStart(item[0])
      if (task) item[0] = task[2] || ""
      var parts2 = inside(item)
      var first2 = parts2.length && parts2[0].type === "p" && parts2[0].indent === 0 ? parts2.shift() : { html: "" }
      var type = task ? "check" : lm.ordered ? "number" : "bullet"
      var b0 = { type: type, html: first2.html, indent: 0 }
      if (task) b0.checked = task[1] !== " "
      emit(b0)
      within(parts2)
      continue
    }

    // A table, its first row the header (as many rows and columns as a table has).
    if (i + 1 < lines.length && line.indexOf("|") >= 0 && isTableRule(lines[i + 1])) {
      var rows = [tableRow(line, Table.MAX_COLS)]
      i += 2
      while (i < lines.length && !isBlank(lines[i]) && lines[i].indexOf("|") >= 0) {
        if (rows.length < Table.MAX_ROWS) rows.push(tableRow(lines[i], Table.MAX_COLS))
        i++
      }
      emit({ type: "table", table: { rows: rows.map(function(r) { return r.map(function(c) { return inlineHtml(c, ctx, refs) }) }), header: true }, indent: 0 })
      continue
    }

    // Code indented by four spaces.
    if (leading(line) >= 4) {
      var ind = []
      var indSize = 0
      while (i < lines.length && (leading(lines[i]) >= 4 || isBlank(lines[i]))) {
        if (indSize <= MAX_TEXT) { ind.push(lines[i].slice(4)); indSize += lines[i].length + 1 }
        i++
      }
      while (ind.length && isBlank(ind[ind.length - 1])) ind.pop()
      var kept = taken(read, joinUpTo(ind, "\n", MAX_TEXT)).split("\n")
      emit({ type: "code", html: kept.map(function(l) { return Html.escapeText(l).replace(/  /g, " &nbsp;") }).join("<br />"), indent: 0 })
      continue
    }

    // A picture on a line of its own.
    var pic = /^\s*!\[([^\]]*)\]\(\s*<?([^\s>)]+)>?(?:\s+"[^"]*")?\s*\)\s*$/.exec(line) || imgLine(line)
    if (pic) {
      var srcPic = pic.length > 2 ? pic[2] : pic[1]
      var local = ctx.image(decodeHref(srcPic))
      if (local) emit({ type: "image", src: local, width: 1, align: "center", indent: 0 })
      else emit(para(line))
      i++
      continue
    }

    // Text: its lines, up to a blank line or something else (or a line of
    // === or --- under it: a heading).
    var words = [line]
    i++
    while (i < lines.length && !isBlank(lines[i]) && !startsBlock(lines[i]) && !(/^ {0,3}(=+|-+)\s*$/.test(lines[i]))) {
      if (i + 1 < lines.length && lines[i].indexOf("|") >= 0 && isTableRule(lines[i + 1])) break
      words.push(lines[i])
      i++
    }
    if (i < lines.length && /^ {0,3}(=+|-+)\s*$/.test(lines[i])) {
      emit({ type: /=/.test(lines[i]) ? "h1" : "h2", html: inlineHtml(joinUpTo(words, " ", MAX_TEXT).trim(), ctx, refs), indent: 0 })
      i++
      continue
    }
    var shown = []
    var shownSize = 0
    for (var w = 0; w < words.length && shownSize <= MAX_TEXT; w++) {
      shown.push(words[w].replace(/^\s+/, ""))
      shownSize += shown[w].length + 1
    }
    emit(para(shown.join("\n")))
  }
  return blocks
}

var LANGS = { js: "JavaScript", javascript: "JavaScript", ts: "TypeScript", typescript: "TypeScript", py: "Python", python: "Python", sh: "Bash", bash: "Bash",
  shell: "Bash", zsh: "Bash", console: "Bash", c: "C", cpp: "C++", "c++": "C++", cs: "C#", csharp: "C#", css: "CSS", go: "Go", golang: "Go", html: "HTML",
  java: "Java", json: "JSON", kotlin: "Kotlin", kt: "Kotlin", lua: "Lua", make: "Makefile", makefile: "Makefile", md: "Markdown", markdown: "Markdown",
  nix: "Nix", php: "PHP", qml: "QML", rb: "Ruby", ruby: "Ruby", rs: "Rust", rust: "Rust", sql: "SQL", swift: "Swift", toml: "TOML", yaml: "YAML", yml: "YAML",
  zig: "Zig", dockerfile: "Dockerfile", docker: "Dockerfile", xml: "XML", svg: "XML", diff: "Diff", patch: "Diff", ini: "INI",
  scss: "SCSS", jsx: "JavaScript", tsx: "TypeScript", text: "", plaintext: "", "plain text": "", math: "Math", katex: "Math", mermaid: "Mermaid" }

// A code block that's one of Pages' own blocks (what agents write, and get
// back from `read`): ```board ("## Column", "- card"), ```contact (a name,
// an email or a number in People), ```agenda (a day: 2026-10-05, or
// nothing for the day it's read), ```event (an event's id), ```bookmark (a
// link). A block, or null (then it's code).
function fenced(lang, text, ctx) {
  var l = String(lang || "").trim().toLowerCase()
  var body = String(text || "").trim()
  if (l === "board" || l === "kanban") {
    var b = Board.fromFence(body)
    return b ? { type: "board", indent: 0, data: b } : null
  }
  if (l === "contact" || l === "person") {
    var q = body.split("\n")[0].trim()
    if (!q) return null
    return { type: "contact", indent: 0, data: { contact: ctx.contact(q) || "", name: q } }
  }
  if (l === "agenda") {
    var d = /^\d{4}-\d{2}-\d{2}$/.test(body) ? body : ""
    if (body && !d && body.toLowerCase() !== "today") return null
    return { type: "agenda", indent: 0, calendar: { day: d } }
  }
  if (l === "event") return body && ctx.event(body) ? { type: "event", indent: 0, calendar: { id: body } } : null
  // A link to a page: its id, or its title.
  if (l === "link" || l === "page-link") {
    var w = body.split("\n")[0].trim()
    var target = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/.test(w) ? w : ctx.wiki(w)
    return target ? { type: "link", indent: 0, target: target } : null
  }
  // A gallery: "columns: 3", "height: 240", and its pictures as Markdown
  // pictures of Pages/assets ("![A caption](assets/x.png)").
  if (l === "gallery") {
    var g = { images: [], columns: 3, height: 0 }
    body.split("\n").forEach(function(line) {
      var t = line.trim()
      var m = /^columns\s*:\s*(\d)$/i.exec(t)
      if (m) { g.columns = Number(m[1]); return }
      m = /^height\s*:\s*(\d+)$/i.exec(t)
      if (m) { g.height = Number(m[1]); return }
      m = /^!\[([^\]]*)\]\(([^)\s]+)\)$/.exec(t)
      if (m) g.images.push({ src: m[2], caption: m[1] })
    })
    var clean = Blocks.cleanData("gallery", g)
    return clean.images.length ? { type: "gallery", indent: 0, data: clean } : null
  }
  if (l === "bookmark") {
    var url = Bookmark.cleanUrl(body.split("\n")[0].trim())
    return url ? { type: "bookmark", indent: 0, data: { url: url } } : null
  }
  return null
}

// A code block that's a mind map: ```mindmap (an outline), or a Mermaid
// mind map (```mermaid starting "mindmap"). Its outline, or "".
function mindMap(lang, text) {
  var l = String(lang || "").trim().toLowerCase()
  if (l === "mindmap" || l === "mind-map" || l === "mind map") return Mindmap.clean(text)
  if (l === "mermaid" && /^\s*mindmap\s*(\n|$)/.test(String(text || ""))) return Mindmap.clean(text)
  return ""
}

// A code block's language as Pages names it (kept as written if it's not
// one it knows, so nothing's lost).
function langName(lang) {
  var l = String(lang || "").trim()
  if (!l) return ""
  var k = l.toLowerCase()
  if (Object.prototype.hasOwnProperty.call(LANGS, k)) return LANGS[k]
  return /^[A-Za-z0-9+#._ -]{1,24}$/.test(l) ? l : ""
}

// A line of front matter: { key, value } (title, name, icon, status or
// due), or null. As /^(key)\s*:\s*["']?(.*?)["']?\s*$/i reads it.
function frontMatter(line) {
  var m = /^(title|name|icon|status|due)\s*:\s*/i.exec(line)
  if (!m) return null
  var v = line.slice(m[0].length)
  if (/^["']/.test(v)) v = v.slice(1)
  var e = v.length
  while (e > 0 && /\s/.test(v.charAt(e - 1))) e--
  if (e > 0 && /["']/.test(v.charAt(e - 1))) e--
  v = v.slice(0, e)
  return TERMINATOR.test(v) ? null : { key: m[1].toLowerCase(), value: v }
}

// Columns, in an agent's Markdown (options.columns; as `read` gives them):
// "::columns" (each one's share, if you like: "::columns 60 40"), a column's
// blocks, "::next" and the next one's, "::end". Six at most: what's past the
// sixth goes in it. Columns don't go in columns: markers inside them just go,
// and so do a "::next" or "::end" outside any. (Not in code: a fence's lines
// are its own.)
var COLUMN_MARK = /^::(columns|next|end)(?:[ \t]+(.*?))?[ \t]*$/

function readColumns(lines, c, refs, blocks) {
  var run = []
  var cols = null
  var depth = 0
  var widths = ""
  var fence = null
  function into() { return cols ? cols[cols.length - 1] : run }
  function flush() {
    if (run.length) readBlocks(run, c, refs, 0, blocks)
    run = []
  }
  function close() {
    var shares = widths ? widths.split(/\s+/).map(Number) : []
    var fits = shares.length === cols.length && shares.every(function(w) { return isFinite(w) && w > 0 })
    var total = fits ? shares.reduce(function(a, w) { return a + w }, 0) : 0
    c.read.blocks++
    blocks.push({ type: "columns", indent: 0 })
    cols.forEach(function(list, k) {
      var col = { type: "column", indent: 1 }
      if (fits) col.width = Math.round(shares[k] / total * 100) / 100
      c.read.blocks++
      blocks.push(col)
      var inner = readBlocks(list, c, refs, 0)
      if (!inner.length) inner.push({ type: "p", html: "", indent: 0 })
      inner.forEach(function(b) { b.indent += 2; blocks.push(b) })
    })
    cols = null
  }
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (fence) {
      into().push(line)
      if (fenceEnd(line, fence)) fence = null
      continue
    }
    fence = fenceStart(line)
    var m = fence ? null : COLUMN_MARK.exec(line)
    if (!m) { into().push(line); continue }
    // (A marker that goes leaves a blank line: what's either side stays apart.)
    if (m[1] === "columns") {
      if (cols) { depth++; into().push(""); continue }
      flush()
      cols = [[]]
      depth = 0
      widths = (m[2] || "").trim()
    } else if (!cols) {
      run.push("")
    } else if (m[1] === "end") {
      if (depth > 0) { depth--; into().push("") }
      else close()
    } else if (depth === 0 && cols.length < 6) {
      cols.push([])
    } else {
      into().push("")
    }
  }
  if (cols) close()
  flush()
}

// Markdown -> { title, icon, blocks }. The title comes from front matter
// ("title: ..."), or a first "# Title" when options.titleFromHeading;
// options.columns reads "::columns" (see readColumns).
function fromMarkdown(text, ctx, options) {
  var o = options || {}
  var c = context(ctx)
  var blocks = []
  var out = { title: "", icon: "", blocks: blocks }
  try {
    var lines = expandTabs(String(text || "").replace(/^\ufeff/, "").replace(/\r\n?/g, "\n").split("\n", MAX_LINES))
    var title = ""
    var icon = ""
    var status = ""
    var due = ""
    // Front matter (--- at the top, key: value lines, ---): a title, an icon,
    // and a project's status and due date.
    if (lines[0] === "---") {
      var end = lines.slice(0, 80).indexOf("---", 1)
      if (end > 0) {
        lines.slice(1, end).forEach(function(l) {
          var m = frontMatter(l)
          if (!m) return
          if (m.key === "icon") icon = m.value
          else if (m.key === "status") status = m.value.toLowerCase()
          else if (m.key === "due") due = m.value
          else if (!title) title = m.value
        })
        lines = lines.slice(end + 1)
      }
    }
    out.title = title.trim()
    out.icon = icon
    // Footnotes' words, taken out of the lines (read where they're used).
    var defs = Notes.definitions(lines)
    c.notes = defs.notes
    var r = collectRefs(defs.lines)
    if (o.columns) readColumns(r.lines, c, r.refs, blocks)
    else readBlocks(r.lines, c, r.refs, 0, blocks)
    if (blocks.length > MAX_BLOCKS) blocks.length = MAX_BLOCKS
    if (o.titleFromHeading && !title) {
      var firstText = -1
      for (var k = 0; k < blocks.length; k++) { if (blocks[k].type !== "divider") { firstText = k; break } }
      if (firstText >= 0 && blocks[firstText].type === "h1" && blocks[firstText].indent === 0) {
        out.title = Html.plainText(blocks[firstText].html).trim()
        blocks.splice(firstText, 1)
      }
    }
    // A page Notion exported starts with its title, then maybe its icon.
    if (/^(planning|active|paused|done)$/.test(status)) out.project = { status: status, due: /^\d{4}-\d{2}-\d{2}$/.test(due) ? due : "" }
  } catch (e) {
    // (Whatever went wrong, what was read before it.)
  }
  return out
}

// A quick note (Super+Alt+N) as a page: { title, markdown }, or null when
// there's nothing in it. Its first line is the title (a "# heading" too);
// a first line that's a list item, a to-do or a quote names the page and
// stays in it, and so does a long first line (the title is its start). The
// quick note's own "[] " and "[x] " to-dos are Markdown's "- [ ] ".
function quickNote(text) {
  try {
    return readQuickNote(text)
  } catch (e) {
    // (Whatever went wrong, the note is kept, all of it as it was written.)
    var all = ""
    try { all = String(text || "").trim() } catch (e2) {}
    return all ? { title: "Quick note", markdown: all } : null
  }
}

function readQuickNote(text) {
  var lines = String(text || "").replace(/\r\n?/g, "\n").split("\n").map(function(l) {
    var m = /^(\s*)\[( |x|X)?\]\s+/.exec(l)
    var rest = m ? restOf(l, m) : null
    return rest !== null ? m[1] + "- [" + (m[2] && m[2] !== " " ? "x" : " ") + "] " + rest : l
  })
  while (lines.length && lines[0].trim() === "") lines.shift()
  while (lines.length && lines[lines.length - 1].trim() === "") lines.pop()
  if (lines.length === 0) return null
  var first = lines[0].trim()
  function words(line) { return Html.plainText(inlineHtml(line)).replace(/\s+/g, " ").trim() }
  function shorten(t) {
    if (t.length <= 80) return t
    var cut = t.lastIndexOf(" ", 77)
    return t.slice(0, cut > 40 ? cut : 77).replace(/[\s,;:.\-]+$/, "") + "\u2026"
  }
  // Each line its own line (Markdown would run plain lines together into one
  // paragraph); lists, quotes, tables and code as they are.
  function body(list) {
    var out = []
    var fence = null
    var plainBefore = false
    list.forEach(function(l) {
      if (fence) { out.push(l); if (fenceEnd(l, fence)) fence = null; return }
      var f = fenceStart(l)
      if (f) { out.push("", l); fence = f; plainBefore = false; return }
      if (/^\s*$/.test(l)) { out.push(""); plainBefore = false; return }
      if (/^\s*(?:[-*+]\s|\d+[.)]\s|>|\||#)/.test(l) || /^\s{2,}\S/.test(l)) {
        if (plainBefore) out.push("")
        out.push(l)
        plainBefore = false
        return
      }
      out.push("", l, "")
      plainBefore = true
    })
    return out.join("\n").replace(/\n{3,}/g, "\n\n").replace(/^\n+|\n+$/g, "")
  }
  var h = heading(first)
  if (h && h.text.trim()) return { title: shorten(words(h.text)), markdown: body(lines.slice(1)) }
  var start = /^(?:[-*+]\s+(?:\[[ xX]\]\s+)?|\d+[.)]\s+|>\s*(?:\[![A-Za-z]+\]\s*)?)/.exec(first)
  var item = start ? restOf(first, start) : null
  if (item !== null || fenceStart(first) || /^\|/.test(first)) {
    var named = item !== null ? words(item) : ""
    return { title: shorten(named) || "Quick note", markdown: body(lines) }
  }
  var plain = words(first)
  if (plain.length > 100) return { title: shorten(plain), markdown: body(lines) }
  return { title: plain, markdown: body(lines.slice(1)) }
}

// Does pasted text look like Markdown (so it becomes blocks)?
var MARKDOWN_LINE = /(?:^|[\n\r\u2028\u2029])(?:#{1,6} |[^\S\n\r\u2028\u2029]*[-*+] |[^\S\n\r\u2028\u2029]*\d+[.)] |> |```|~~~|---[^\S\n\r\u2028\u2029]*(?:[\n\r\u2028\u2029]|$)|\|.*\|)/

function looksLikeMarkdown(text) {
  var t = String(text || "")
  if (t.indexOf("\n") < 0 && t.indexOf("**") < 0 && t.indexOf("__") < 0 && t.indexOf("`") < 0 && !bracketLink(t, false)) return false
  return MARKDOWN_LINE.test(t) || /\*\*[^*\n]+\*\*|`[^`\n]+`/.test(t) || bracketLink(t, true)
}

// Is there "[words](" in it (with "address)" after, on that line, when
// `oneLine`)? As /\[[^\]]+\]\(/ and /\[[^\]\n]+\]\([^)\n]+\)/ find one.
function bracketLink(t, oneLine) {
  var first = -1
  var stop = -1
  for (var i = 0; i < t.length; i++) {
    var c = t.charCodeAt(i)
    if (c === 91) { if (first < 0) first = i; continue }
    if (oneLine && c === 10) { first = -1; continue }
    if (c !== 93) continue
    if (first >= 0 && first <= i - 2 && t.charCodeAt(i + 1) === 40) {
      if (!oneLine) return true
      // (Where the next ")" or line break is, from where it was last looked for.)
      if (stop < i + 2) {
        stop = i + 2
        while (stop < t.length && t.charCodeAt(stop) !== 41 && t.charCodeAt(stop) !== 10) stop++
      }
      if (stop > i + 2 && t.charCodeAt(stop) === 41) return true
    }
    first = -1
  }
  return false
}

// ---- plain text -------------------------------------------------------------------------------

// Plain text: a paragraph a line (a blank line keeps its place).
function fromText(text) {
  var blocks = []
  try {
    var lines = String(text || "").replace(/^\ufeff/, "").replace(/\r\n?/g, "\n").split("\n", MAX_LINES)
    while (lines.length && isBlank(lines[lines.length - 1])) lines.pop()
    var read = context(null).read
    var blank = false
    for (var i = 0; i < lines.length && blocks.length < MAX_BLOCKS && !full(read); i++) {
      var l = lines[i]
      if (isBlank(l)) {
        if (!blank && blocks.length) blocks.push({ type: "p", html: "", indent: 0 })
        blank = true
        continue
      }
      blank = false
      blocks.push({ type: "p", html: Html.escapeText(taken(read, l).replace(/\t/g, "    ")).replace(/  /g, " &nbsp;"), indent: 0 })
    }
  } catch (e) {
    // (Whatever went wrong, what was read before it.)
  }
  return { title: "", icon: "", blocks: blocks }
}

// ---- HTML ---------------------------------------------------------------------------------------

var VOID = { br: 1, img: 1, hr: 1, input: 1, meta: 1, link: 1, col: 1, source: 1, wbr: 1, area: 1, base: 1, embed: 1, param: 1, track: 1 }
var SKIP = { script: 1, style: 1, head: 1, noscript: 1, template: 1, svg: 1, iframe: 1, object: 1, button: 1, select: 1, textarea: 1 }
var BLOCK = { p: 1, div: 1, section: 1, article: 1, main: 1, header: 1, footer: 1, nav: 1, aside: 1, figure: 1, figcaption: 1, h1: 1, h2: 1, h3: 1, h4: 1, h5: 1, h6: 1,
  ul: 1, ol: 1, li: 1, blockquote: 1, pre: 1, hr: 1, table: 1, details: 1, summary: 1, img: 1, dl: 1, dt: 1, dd: 1, body: 1, html: 1, form: 1, fieldset: 1, center: 1 }

function attrsOf(text) {
  var out = {}
  var re = /([a-zA-Z_:][-a-zA-Z0-9_:.]*)(?:\s*=\s*("[^"]*"|'[^']*'|[^\s"'=<>`]+))?/g
  var m
  while ((m = re.exec(text || "")) !== null) {
    var v = m[2] === undefined ? "" : m[2].replace(/^["']|["']$/g, "")
    out[m[1].toLowerCase()] = Html.decodeEntities(v)
  }
  return out
}

var CDATA_START = /<!\[CDATA\[/iy
var DOCTYPE_START = /<!doctype/iy
var CLOSE_TAG = /<\/\s*([a-zA-Z][a-zA-Z0-9-]*)\s*>/y
var TAG_NAME = /[a-zA-Z][a-zA-Z0-9-]*/y
var ATTR_NAME = /[^\s>\/=]*/y
var UNQUOTED = /[^\s>]*/y

// HTML -> a tree of { tag, attrs, kids } and { text } (forgiving, as browsers
// are; comments and the doctype left out). An element that would be deeper
// than MAX_HTML_DEPTH goes next to the deepest instead.
function tree(html) {
  var root = { tag: "#root", attrs: {}, kids: [] }
  var stack = [root]
  // How many of each element are open (so a stray end tag isn't looked for).
  var open = Object.create(null)
  var src = String(html || "")
  var find = scanner(src)
  // Start tags' attributes as they're read (see tagEnd), shared by every tag.
  var tags = { src: src, find: find, memo: {}, steps: 0, limit: 8 * src.length + 4096 }
  var nodes = 0
  var at = 0
  function popTo(s) {
    while (stack.length > s) open[stack.pop().tag]--
  }
  while (at < src.length && nodes < MAX_NODES) {
    var top = stack[stack.length - 1]
    var lt = src.indexOf("<", at)
    if (lt < 0) lt = src.length
    if (lt > at) { top.kids.push({ text: Html.decodeEntities(src.slice(at, lt)) }); nodes++; at = lt; continue }
    var e = -1
    if (src.substr(at, 4) === "<!--") {
      e = find("-->", at + 4)
      if (e >= 0) { at = e + 3; continue }
    }
    CDATA_START.lastIndex = at
    if (CDATA_START.test(src)) {
      e = find("]]>", at + 9)
      if (e >= 0) { top.kids.push({ text: src.slice(at + 9, e) }); nodes++; at = e + 3; continue }
    }
    DOCTYPE_START.lastIndex = at
    if (DOCTYPE_START.test(src)) {
      e = find(">", at + 9)
      if (e >= 0) { at = e + 1; continue }
    }
    CLOSE_TAG.lastIndex = at
    var close = CLOSE_TAG.exec(src)
    if (close) {
      var name = close[1].toLowerCase()
      if (open[name]) {
        for (var s = stack.length - 1; s > 0; s--) {
          if (stack[s].tag === name) { popTo(s); break }
        }
      }
      at += close[0].length
      continue
    }
    var st = startTag(tags, at)
    if (st) {
      var tag = st.name.toLowerCase()
      // An open <p> or <li> ends where the next one starts.
      if ((tag === "p" || tag === "li" || tag === "dt" || tag === "dd") && top.tag === tag) { popTo(stack.length - 1); top = stack[stack.length - 1] }
      var node = { tag: tag, attrs: attrsOf(st.attrs), kids: [] }
      nodes++
      ;(stack.length > MAX_HTML_DEPTH ? stack[MAX_HTML_DEPTH - 1] : top).kids.push(node)
      if (!VOID[tag] && !st.slash) { stack.push(node); open[tag] = (open[tag] || 0) + 1 }
      at = st.end
      continue
    }
    top.kids.push({ text: "<" })
    nodes++
    at++
  }
  return root
}

// A start tag at `at` ("<p", "<a href=…>", "<br/>"): { name, attrs, slash,
// end }, or null. As the pattern
//   <([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^\s>\/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>
// reads one, without the time the pattern can take over one that doesn't end.
function startTag(tags, at) {
  var src = tags.src
  TAG_NAME.lastIndex = at + 1
  var m = TAG_NAME.exec(src)
  if (!m) return null
  var from = at + 1 + m[0].length
  var end = tagEnd(tags, from)
  return end ? { name: m[0], attrs: src.slice(from, end.attrs), slash: end.slash, end: end.end } : null
}

// How a start tag's attributes from `p0` go on to its ">": { attrs (where
// they end), slash, end }, or null. A value in quotes is read to its closing
// quote, unless the tag can't end after that: then to a space or ">". Each
// place is worked out once (for every tag), and a file that would take
// much longer than reading it has the rest of its tags read as text.
function tagEnd(tags, p0) {
  var memo = tags.memo
  var frames = [{ p: p0, next: null, k: 0 }]
  var got
  while (frames.length) {
    if (++tags.steps > tags.limit) return null
    var f = frames[frames.length - 1]
    if (got !== undefined) {
      // What the way just tried gave: the tag's end (so this way's too), or no end.
      if (got) { memo[f.p] = got; frames.pop(); continue }
      got = undefined
    }
    if (memo[f.p] !== undefined) { got = memo[f.p]; frames.pop(); continue }
    if (!f.next) f.next = attrNext(tags, f.p)
    if (f.k < f.next.length) {
      var q = f.next[f.k++]
      if (memo[q] !== undefined) got = memo[q]
      else frames.push({ p: q, next: null, k: 0 })
      continue
    }
    got = tagClose(tags.src, f.p)
    memo[f.p] = got
    frames.pop()
  }
  return got || null
}

// Where an attribute from `p` can end, in the order they're tried: after
// its value in quotes, then after it as it is up to a space or ">".
function attrNext(tags, p) {
  var src = tags.src
  var w = skip(SPACES, src, p)
  if (w === p) return []
  var n = skip(ATTR_NAME, src, w)
  if (n === w) return []
  var e = skip(SPACES, src, n)
  tags.steps += e - p
  if (src.charAt(e) !== "=") return [n]
  var v = skip(SPACES, src, e + 1)
  var out = []
  var c = src.charAt(v)
  if (c === "\"" || c === "'") {
    var q = tags.find(c, v + 1)
    if (q >= 0) out.push(q + 1)
  }
  var u = skip(UNQUOTED, src, v)
  tags.steps += u - e
  if (u > v) out.push(u)
  return out
}

// The end of a start tag at `p`: white space, maybe "/", then ">".
function tagClose(src, p) {
  var t = skip(SPACES, src, p)
  if (src.charAt(t) === ">") return { attrs: p, slash: "", end: t + 1 }
  if (src.charAt(t) === "/" && src.charAt(t + 1) === ">") return { attrs: p, slash: "/", end: t + 2 }
  return false
}

function hasClass(node, name) {
  return (" " + (node.attrs && node.attrs["class"] || "") + " ").indexOf(" " + name + " ") >= 0
}

function find(node, test) {
  if (!node.kids) return null
  for (var i = 0; i < node.kids.length; i++) {
    var k = node.kids[i]
    if (k.tag && test(k)) return k
    var deep = k.tag ? find(k, test) : null
    if (deep) return deep
  }
  return null
}

function textOf(node) {
  if (node.text !== undefined) return node.text
  if (node.tag === "br") return "\n"
  return (node.kids || []).map(textOf).join("")
}

// Notion's colors ("highlight-red", "block-color-blue_background").
var NOTION_COLORS = ["gray", "brown", "orange", "yellow", "teal", "green", "blue", "purple", "pink", "red"]
var NOTION_CLASS = {}

function notionColor(node, prefix) {
  var cls = node.attrs && node.attrs["class"] || ""
  if (cls.indexOf(prefix) < 0) return ""
  var re = NOTION_CLASS[prefix] || (NOTION_CLASS[prefix] = new RegExp("(?:^|\\s)" + prefix + "(" + NOTION_COLORS.join("|") + ")(_background)?(?:\\s|$)"))
  var m = re.exec(cls)
  if (!m) return ""
  var name = m[1] === "teal" ? "green" : m[1]
  return name + (m[2] || "")
}

// Room for a block's text and its formatting, as much as is still read
// from the file.
function room(ctx) {
  return { left: Math.min(MAX_TEXT, MAX_FILE_TEXT - ctx.read.text), marks: MAX_MARKS }
}

// Inline HTML (a node's children) -> the inside of a block (no more of its
// text than `space` has room for).
function inlineOf(nodes, ctx, space) {
  var r = space || room(ctx)
  var out = ""
  nodes.forEach(function(n) {
    // White space in HTML is one space, as a browser shows it.
    if (n.text !== undefined) {
      if (r.left <= 0) return
      var t = cut(n.text.replace(/[ \t\r\n\f]+/g, " "), r.left)
      r.left -= t.length
      ctx.read.text += t.length
      out += Html.escapeText(t)
      return
    }
    var tag = n.tag
    if (SKIP[tag]) return
    if (tag === "br") { out += "<br />"; return }
    if (tag === "img") { if (n.attrs.alt) out += Html.escapeText(n.attrs.alt); return }
    if (tag === "input") return
    var inner = inlineOf(n.kids || [], ctx, r)
    var style = n.attrs.style || ""
    var color = notionColor(n, "highlight-")
    if (color) {
      var c = notionHex(color)
      if (c) style += (/_background$/.test(color) ? ";background-color:" : ";color:") + c
    }
    var link = tag === "a" && n.attrs.href
    var open = { b: "font-weight:700", strong: "font-weight:700", i: "font-style:italic", em: "font-style:italic", u: "text-decoration: underline",
      ins: "text-decoration: underline", s: "text-decoration: line-through", del: "text-decoration: line-through", strike: "text-decoration: line-through",
      mark: "background-color:" + HIGHLIGHT, code: "font-family:" + MONO, kbd: "font-family:" + MONO, sup: "vertical-align:super", sub: "vertical-align:sub" }[tag]
    if (open) style = open + ";" + style
    // (Past as much formatting as is read, the words alone.)
    if ((!link && !style) || r.marks <= 0 || ctx.read.marks >= MAX_FILE_MARKS) { out += inner; return }
    r.marks--
    ctx.read.marks++
    if (link) out += "<a href=\"" + Html.escapeAttr(ctx.link(n.attrs.href)) + "\">" + inner + "</a>"
    else out += "<span style=\"" + Html.escapeAttr(style) + "\">" + inner + "</span>"
  })
  return out
}

// A block's html without white space (or "&nbsp;"s) at its start, nor white
// space and line breaks (and "&nbsp;"s, when `nbsp`) at its end.
function trimHtml(html, nbsp) {
  var s = html.replace(/^(\s|&nbsp;)+/, "")
  var e = s.length
  for (;;) {
    var last = e >= 6 ? s.slice(e - 6, e) : ""
    if (last === "<br />" || (nbsp && last === "&nbsp;")) e -= 6
    else if (e > 0 && /\s/.test(s.charAt(e - 1))) e--
    else break
  }
  return s.slice(0, e)
}

// A table cell's text: its paragraphs (and lines) a line each.
function cellOf(cell, ctx, space) {
  var r = space || room(ctx)
  var parts = []
  var run = []
  function flush() {
    if (run.length) parts.push(inlineOf(run, ctx, r))
    run = []
  }
  ;(cell.kids || []).forEach(function(k) {
    if (isInline(k)) { run.push(k); return }
    flush()
    parts.push(cellOf(k, ctx, r))
  })
  flush()
  var html = parts.map(function(p) { return trimHtml(p, true) }).filter(function(p) { return p !== "" }).join("<br />")
  return Html.sanitize(html, true)
}

// A Notion color's light-page hex (as Docs.js has them).
function notionHex(value) {
  var table = {
    gray: ["#787774", "#f1f1ef"], brown: ["#9f6b53", "#f4eeee"], orange: ["#d9730d", "#fbecdd"], yellow: ["#cb912f", "#fbf3db"],
    green: ["#448361", "#edf3ec"], blue: ["#337ea9", "#e7f3f8"], purple: ["#9065b0", "#f4f0f7"], pink: ["#c14c8a", "#f9eef3"], red: ["#d44c47", "#fdebec"]
  }
  var bg = /_background$/.test(value)
  var t = table[value.replace(/_background$/, "")]
  return t ? t[bg ? 1 : 0] : ""
}

// HTML -> { title, icon, blocks }.
function fromHtml(html, ctx, options) {
  var o = options || {}
  var c = context(ctx)
  var blocks = []
  var out = { title: "", icon: "", blocks: blocks }
  try {
    var root = tree(html)
    var title = ""
    var titleNode = find(root, function(n) { return n.tag === "h1" && hasClass(n, "page-title") })
    if (titleNode) title = textOf(titleNode).trim()
    if (!title) { var t = find(root, function(n) { return n.tag === "title" }); if (t) title = textOf(t).trim() }
    out.title = title
    var iconNode = find(root, function(n) { return hasClass(n, "page-header-icon") })
    if (iconNode) {
      var iconText = textOf(iconNode).trim()
      if (iconText && !/[A-Za-z0-9]/.test(iconText) && iconText.length <= 16) out.icon = iconText
    }
    var body = find(root, function(n) { return n.tag === "body" }) || root
    readHtml(body.kids, 0, blocks, c, { skipTitle: titleNode })
    if (blocks.length > MAX_BLOCKS) blocks.length = MAX_BLOCKS
    // A first heading that says the title again goes.
    if (title && blocks.length && /^h[123]$/.test(blocks[0].type) && Html.plainText(blocks[0].html).trim() === title) blocks.shift()
    if (o.titleFromHeading && !title && blocks.length && blocks[0].type === "h1") out.title = Html.plainText(blocks.shift().html).trim()
  } catch (e) {
    // (Whatever went wrong, what was read before it.)
  }
  return out
}

function isInline(n) {
  return n.text !== undefined || (!BLOCK[n.tag] && !SKIP[n.tag])
}

// A new block read from HTML, counted.
function put(ctx, out, b) {
  ctx.read.blocks++
  out.push(b)
  return b
}

function readHtml(nodes, depth, out, ctx, opts) {
  var run = []
  function flush() {
    if (!run.length) return
    var inner = Html.sanitize(inlineOf(run, ctx), true)
    if (Html.plainText(inner).trim() !== "") put(ctx, out, { type: "p", html: trimHtml(inner, false), indent: depth })
    run = []
  }
  for (var i = 0; i < nodes.length && !full(ctx.read); i++) {
    var n = nodes[i]
    if (isInline(n)) {
      if (n.text !== undefined && !run.length && /^\s*$/.test(n.text)) continue
      run.push(n)
      continue
    }
    flush()
    readHtmlBlock(n, depth, out, ctx, opts)
  }
  flush()
}

// An item's own checkbox (not one in a list inside it): an <input
// type="checkbox">, or Notion's <div class="checkbox">.
function checkboxOf(li, todo) {
  function test(k) {
    return (k.tag === "input" && (k.attrs.type || "").toLowerCase() === "checkbox") || (todo && k.tag && hasClass(k, "checkbox"))
  }
  for (var i = 0; i < li.kids.length; i++) {
    var k = li.kids[i]
    if (!k.tag) continue
    if (test(k)) return k
    if (k.tag === "ul" || k.tag === "ol") continue
    var inner = find(k, function(x) { return test(x) })
    if (inner && !find(k, function(x) { return x.tag === "ul" || x.tag === "ol" })) return inner
  }
  return null
}

function blockColor(node) {
  return notionColor(node, "block-color-")
}

function readHtmlBlock(n, depth, out, ctx, opts) {
  var tag = n.tag
  if (SKIP[tag] || n === opts.skipTitle) return
  if (hasClass(n, "page-header-icon") || hasClass(n, "properties") || (tag === "header" && find(n, function(k) { return k === opts.skipTitle }))) {
    if (tag === "header") readHtml(n.kids.filter(function(k) { return k !== opts.skipTitle && !(k.tag && (hasClass(k, "page-header-icon") || hasClass(k, "page-cover-image"))) }), depth, out, ctx, opts)
    return
  }
  var color = blockColor(n)
  function add(b) { if (color) b.color = color; return put(ctx, out, b) }
  function inner() { return Html.sanitize(inlineOf(n.kids, ctx), true) }
  if (/^h[1-6]$/.test(tag)) { add({ type: tag === "h1" ? "h1" : tag === "h2" ? "h2" : "h3", html: inner(), indent: depth }); return }
  if (tag === "hr") { add({ type: "divider", indent: depth }); return }
  if (tag === "img") {
    var src = ctx.image(n.attrs.src || "")
    if (src) add({ type: "image", src: src, width: 1, align: "center", indent: depth })
    return
  }
  if (tag === "pre") {
    var codeNode = find(n, function(k) { return k.tag === "code" }) || n
    var lang = /(?:^|\s)language-([^\s]+)/.exec(codeNode.attrs && codeNode.attrs["class"] || "")
    var code = taken(ctx.read, textOf(codeNode).replace(/\n$/, ""))
    var map = mindMap(lang ? lang[1] : "", code)
    if (map) add({ type: "mindmap", outline: map, indent: depth })
    else add({ type: "code", lang: langName(lang ? lang[1].replace(/_/g, " ") : ""), html: Html.fromPlainText(code), indent: depth })
    return
  }
  if (tag === "blockquote") {
    var parts = []
    readHtml(n.kids, depth + 1, parts, ctx, opts)
    var head = parts.length && parts[0].type === "p" && parts[0].indent === depth + 1 ? parts.shift() : { html: "" }
    add({ type: "quote", html: head.html, indent: depth })
    parts.forEach(function(b) { out.push(b) })
    return
  }
  // Notion's callout: an icon, then the text and what's inside it.
  if (tag === "figure" && hasClass(n, "callout")) {
    var iconBox = find(n, function(k) { return hasClass(k, "icon") })
    var iconText = iconBox ? textOf(iconBox).trim() : ""
    var content = n.kids.filter(function(k) { return k.tag === "div" && !find(k, function(x) { return x === iconBox }) && k !== iconBox })
    var parts2 = []
    readHtml(content.length ? content[content.length - 1].kids : n.kids, depth + 1, parts2, ctx, opts)
    var first = parts2.length && parts2[0].type === "p" && parts2[0].indent === depth + 1 ? parts2.shift() : { html: "" }
    add({ type: "callout", icon: iconText && !/[A-Za-z0-9]/.test(iconText) ? iconText : "\u{1f4a1}", html: first.html, indent: depth, color: color || "gray_background" })
    parts2.forEach(function(b) { out.push(b) })
    return
  }
  // Notion's link to a page, and table of contents.
  if (tag === "figure" && hasClass(n, "link-to-page")) {
    var a = find(n, function(k) { return k.tag === "a" })
    var id = a ? /^(?:uber-notebook|omanote):\/\/page\/(.+)$/.exec(ctx.link(a.attrs.href || "")) : null
    if (id) add({ type: "link", target: id[1], indent: depth })
    else readHtml(n.kids, depth, out, ctx, opts)
    return
  }
  if (tag === "nav" && hasClass(n, "table_of_contents")) { add({ type: "toc", indent: depth }); return }
  // Columns (Notion's): side by side, at the top of the page.
  if (hasClass(n, "column-list") && depth === 0) {
    var cols = n.kids.filter(function(k) { return k.tag && hasClass(k, "column") })
    if (cols.length >= 2) {
      put(ctx, out, { type: "columns", indent: 0 })
      cols.forEach(function(col) {
        var w = /width:\s*calc\(\(100% - \(var\(--column-spacing\) \* \d+\)\) \* ([0-9.]+)\)/.exec(col.attrs.style || "") || /width:\s*([0-9.]+)%/.exec(col.attrs.style || "")
        var share = w ? Number(w[1]) : 0
        put(ctx, out, { type: "column", indent: 1, width: share > 1 ? share / 100 : share })
        var before = out.length
        readHtml(col.kids, 2, out, ctx, opts)
        if (out.length === before) put(ctx, out, { type: "p", html: "", indent: 2 })
      })
      return
    }
  }
  // A toggle: <details><summary>...</summary>...</details>.
  if (tag === "details") {
    var summary = find(n, function(k) { return k.tag === "summary" })
    add({ type: "toggle", html: summary ? Html.sanitize(inlineOf(summary.kids, ctx), true) : "", indent: depth, collapsed: !("open" in n.attrs) })
    readHtml(n.kids.filter(function(k) { return k !== summary }), depth + 1, out, ctx, opts)
    return
  }
  if (tag === "ul" || tag === "ol") {
    var toggles = hasClass(n, "toggle")
    var todo = hasClass(n, "to-do-list")
    n.kids.forEach(function(li) {
      if (full(ctx.read)) return
      if (li.tag !== "li") { if (li.tag) readHtmlBlock(li, depth, out, ctx, opts); return }
      var itemColor = blockColor(li)
      // Notion writes toggles as a list of <details>.
      var det = toggles ? find(li, function(k) { return k.tag === "details" }) : null
      if (det) { readHtmlBlock(det, depth, out, ctx, opts); return }
      var box = checkboxOf(li, todo)
      var checked = !!box && ("checked" in box.attrs || hasClass(box, "checkbox-on"))
      var inlineKids = []
      var rest = []
      li.kids.forEach(function(k) {
        if (k === box) return
        if (isInline(k) && !rest.length) inlineKids.push(k)
        else rest.push(k)
      })
      // An item's text in a paragraph of its own (as LibreOffice and Word write it).
      var hasText = inlineKids.some(function(k) { return textOf(k).trim() !== "" })
      if (!hasText && rest.length && rest[0].tag === "p") inlineKids = rest.shift().kids
      var b = { type: box ? "check" : tag === "ol" ? "number" : "bullet", html: trimHtml(Html.sanitize(inlineOf(inlineKids, ctx), true), false), indent: depth }
      if (box) b.checked = checked
      if (itemColor) b.color = itemColor
      put(ctx, out, b)
      readHtml(rest, depth + 1, out, ctx, opts)
    })
    return
  }
  if (tag === "table") {
    // Its rows (not a table's inside a cell); the first a header row if
    // its cells are <th>s. As many rows and columns as a table has.
    var rows = []
    var header = false
    ;(function walk(node) {
      (node.kids || []).forEach(function(k) {
        if (rows.length >= Table.MAX_ROWS) return
        if (k.tag === "tr") {
          var cells = k.kids.filter(function(cell) { return cell.tag === "td" || cell.tag === "th" })
          if (rows.length === 0) header = cells.length > 0 && cells.every(function(cell) { return cell.tag === "th" })
          rows.push(cells.slice(0, Table.MAX_COLS).map(function(cell) { return cellOf(cell, ctx) }))
        } else if (k.tag && k.tag !== "table") walk(k)
      })
    })(n)
    if (rows.length) add({ type: "table", table: { rows: rows, header: header }, indent: depth })
    return
  }
  // A paragraph that's only pictures (as Notion writes them): the pictures.
  if (tag === "p" && n.kids.length && n.kids.every(function(k) { return k.tag === "img" || (k.tag === "a" && k.kids.length === 1 && k.kids[0].tag === "img") || (k.text !== undefined && /^\s*$/.test(k.text)) })) {
    n.kids.forEach(function(k) {
      var img = k.tag === "img" ? k : k.tag === "a" ? k.kids[0] : null
      if (!img) return
      var local = ctx.image(img.attrs.src || "")
      if (local) add({ type: "image", src: local, width: 1, align: "center", indent: depth })
    })
    return
  }
  if (tag === "p" || tag === "dt" || tag === "dd" || tag === "figcaption" || tag === "summary") {
    var html = trimHtml(inner(), false)
    if (Html.plainText(html).trim() !== "") add({ type: "p", html: html, indent: depth })
    return
  }
  // A container (div, section...): what's in it, at the same depth, in its color.
  var before2 = out.length
  readHtml(n.kids, depth, out, ctx, opts)
  if (color) for (var i = before2; i < out.length; i++) if (out[i].indent === depth && !out[i].color) out[i].color = color
}

// ---- Evernote --------------------------------------------------------------------------------

// An .enex file (Evernote's export) -> its notes: [{ title, html, created }].
function enexNotes(xml) {
  var out = []
  try {
    var src = String(xml || "")
    var at = 0
    while (out.length < MAX_NOTES) {
      var start = src.indexOf("<note>", at)
      var end = start >= 0 ? src.indexOf("</note>", start + 6) : -1
      if (end < 0) break
      out.push(enexNote(src.slice(start + 6, end)))
      at = end + 7
    }
  } catch (e) {
    // (Whatever went wrong, the notes read before it.)
  }
  return out
}

// One <note>'s inside -> { title, html, created }.
function enexNote(note) {
  var a = note.indexOf("<title>")
  var b = a >= 0 ? note.indexOf("</title>", a + 7) : -1
  var content = enexContent(note)
  var created = /<created>(\d{8}T\d{6}Z)<\/created>/.exec(note)
  var html = ""
  if (content !== null) {
    html = swapTags(content, /<\/?en-note/g, false, "")
    html = html.replace(/<en-todo\s+checked="true"\s*\/>/g, "<input type=\"checkbox\" checked>")
    html = swapTags(html, /<en-todo/g, true, "<input type=\"checkbox\">")
    html = swapTags(html, /<en-media/g, true, "")
  }
  return {
    title: b >= 0 ? Html.decodeEntities(note.slice(a + 7, b)).trim() : "",
    html: html,
    created: created ? created[1].replace(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/, "$1-$2-$3T$4:$5:$6Z") : ""
  }
}

// A note's content: what's in its <content><![CDATA[…]]></content>, or
// null. As /<content>\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*<\/content>/ finds it.
function enexContent(note) {
  var open = /<content>\s*<!\[CDATA\[/g
  var m = open.exec(note)
  if (!m) return null
  var from = m.index + m[0].length
  var close = /\]\]>\s*<\/content>/g
  close.lastIndex = from
  var c = close.exec(note)
  return c ? note.slice(from, c.index) : null
}

// `text` with each piece that `start` (a /g pattern) begins and the next ">"
// ends (that "/>" ends, when `slash`) as `by`: as /start[^>]*>/g (or
// /start[^>]*\/>/g) replaces them, in time in step with the text.
function swapTags(text, start, slash, by) {
  var out = ""
  var last = 0
  var gt = -1
  var m
  start.lastIndex = 0
  while ((m = start.exec(text)) !== null) {
    var from = m.index + m[0].length
    if (gt < from) gt = text.indexOf(">", from)
    if (gt < 0) break
    if (slash && (gt - 1 < from || text.charAt(gt - 1) !== "/")) continue
    out += text.slice(last, m.index) + by
    last = gt + 1
    start.lastIndex = gt + 1
  }
  return out + text.slice(last)
}

// ---- a notebook's page ------------------------------------------------------------------------

// A page of one of your notebooks (Library.js) as a page in Pages, nothing
// lost: its blocks as they are (text and its formatting, headings, lists,
// to-dos, sticky notes, code, dividers, habits, month calendars), its
// pictures where ctx.image puts them, a time slot as text that starts with
// its time, and what's drawn on it as a sketch at its end (Pages draws in
// sketches, not over the writing). { title, icon, blocks }.
function fromNotebookPage(page, ctx) {
  var out = []
  try {
    return readNotebookPage(page, ctx, out)
  } catch (e) {
    // (Whatever went wrong, what was read before it.)
    if (out.length === 0) out.push({ type: "p", html: "", indent: 0 })
    return { title: "", icon: "", blocks: out }
  }
}

function readNotebookPage(page, ctx, out) {
  var c = context(ctx)
  var p = page && typeof page === "object" ? page : {}
  ;(Array.isArray(p.blocks) ? p.blocks : []).forEach(function(b) {
    if (!b || typeof b !== "object" || !Blocks.isKind(b.type)) return
    // (Pages' own: a notebook never has them, so they'd point nowhere.)
    if (["page", "link", "columns", "column"].indexOf(b.type) >= 0) return
    var block = {}
    for (var k in b) if (k !== "uid") block[k] = b[k]
    block.indent = Math.max(0, Math.floor(Number(b.indent) || 0))
    if (b.type === "time") {
      var label = String(b.label || "").trim()
      block = { type: "p", html: (label ? "<span style=\" font-weight:700;\">" + Html.escapeText(label) + "</span> " : "") + (typeof b.html === "string" ? b.html : ""), indent: block.indent }
      if (b.color) block.color = b.color
    }
    // A sticky note in its color (Pages' callouts have a color, not a tone).
    if (b.type === "callout" && !b.color && Blocks.isColor(b.tone)) block.color = b.tone + "_background"
    if (b.type === "image") {
      block.src = c.image(b.src)
      if (!block.src) return
    }
    out.push(block)
  })
  notebookInk(p.ink).forEach(function(sketch) { out.push({ type: "sketch", sketch: sketch, indent: 0 }) })
  if (out.length === 0) out.push({ type: "p", html: "", indent: 0 })
  return { title: Library.pageTitle({ title: p.title || "", template: p.template || "", blocks: Array.isArray(p.blocks) ? p.blocks : [] }, 80), icon: "", blocks: out }
}

// The widest a notebook's sheet is (NotebookView.qml): a drawing on a
// narrower one keeps its size next to the page's width.
var NOTEBOOK_WIDTH = 860
// The page's ink, as a notebook keeps it (FormatBar.qml).
var NOTEBOOK_INK = "#1f2430"

// A notebook's pen or highlighter color as a sketch has it: the page's ink
// (""), the Pages color it is ("blue", so it follows a dark theme as it
// did on dark paper), or the color itself.
function notebookColor(stroke) {
  var color = String(stroke.color || "").toLowerCase()
  if (color === NOTEBOOK_INK) return ""
  var list = stroke.tool === "marker" ? Papers.HIGHLIGHTS : Papers.INKS
  for (var i = 0; i < list.length; i++) if (list[i].light === color) return list[i].id
  return color
}

// A notebook page's drawing (strokes in its pixels, over the writing) as
// sketches: the same size next to the page's width, from its top stroke
// down. One sketch, unless there's more than one can hold.
function notebookInk(ink) {
  var list = (Array.isArray(ink) ? ink : []).filter(function(s) { return s && Array.isArray(s.points) && s.points.length >= 2 })
  var minX = 0
  var maxX = 0
  var minY = Infinity
  var maxY = -Infinity
  list.forEach(function(s) {
    for (var j = 0; j + 1 < s.points.length; j += 2) {
      var x = Number(s.points[j])
      var y = Number(s.points[j + 1])
      if (!isFinite(x) || !isFinite(y)) continue
      minX = Math.min(minX, x)
      maxX = Math.max(maxX, x)
      minY = Math.min(minY, y)
      maxY = Math.max(maxY, y)
    }
  })
  if (!isFinite(minY)) return []
  var pad = 20
  var span = Math.max(1, maxY - minY)
  var scale = Math.min(Sketch.WIDTH / Math.max(NOTEBOOK_WIDTH, maxX - minX + pad), (Sketch.MAX_HEIGHT - 2 * pad) / span)
  var height = Math.max(Sketch.MIN_HEIGHT, Math.ceil(span * scale + 2 * pad))
  // Each stroke in the sketch's units; a long one in parts (a sketch's
  // strokes are at most MAX_POINTS numbers long), drawn the same.
  var strokes = []
  list.forEach(function(s) {
    var points = []
    for (var j = 0; j + 1 < s.points.length; j += 2) {
      var x = Number(s.points[j])
      var y = Number(s.points[j + 1])
      if (isFinite(x) && isFinite(y)) points.push(Math.round((x - minX) * scale * 10) / 10, Math.round(((y - minY) * scale + pad) * 10) / 10)
    }
    var width = (typeof s.width === "number" && isFinite(s.width) ? s.width : 2) * scale
    var part = Sketch.MAX_POINTS - 2
    for (var at = 0; at < points.length; at += part) {
      var piece = points.slice(Math.max(0, at - 2), at + part)
      if (piece.length >= 2) strokes.push({ tool: s.tool === "marker" ? "marker" : "pen", color: notebookColor(s), width: width, points: piece })
    }
  })
  // As many sketches as it takes (a sketch holds MAX_STROKES strokes,
  // MAX_TOTAL numbers in all), each the drawing's whole height.
  var out = []
  var current = null
  var total = 0
  strokes.forEach(function(s) {
    if (!current || current.strokes.length >= Sketch.MAX_STROKES || total + s.points.length > Sketch.MAX_TOTAL) {
      current = { height: height, background: "plain", strokes: [] }
      out.push(current)
      total = 0
    }
    current.strokes.push(s)
    total += s.points.length
  })
  return out.map(function(sk) { return Sketch.clean(sk) }).filter(function(sk) { return sk && sk.strokes.length > 0 })
}

// ---- file names -------------------------------------------------------------------------------

// Notion puts a page's id at the end of its file's name: "Plans 6f1c2b9e0d3a4f6e9b1c2e8a7d5f4c3b.md".
// That id as a UUID, or "".
function notionId(name) {
  var m = /[ _-]([0-9a-f]{32})(?:\.[a-z0-9]+)?$/i.exec(String(name || ""))
  if (!m) return ""
  var h = m[1].toLowerCase()
  return h.slice(0, 8) + "-" + h.slice(8, 12) + "-" + h.slice(12, 16) + "-" + h.slice(16, 20) + "-" + h.slice(20)
}

// A page's title from its file's name: without the folders, the extension
// or Notion's id; "%20" and such decoded.
function titleFromName(path) {
  var name = String(path || "").split("/").pop()
  try { name = decodeURIComponent(name) } catch (e) {}
  return name.replace(/\.[A-Za-z0-9]{1,9}$/, "").replace(/[ _-][0-9a-f]{32}$/i, "").replace(/[_]+/g, " ").trim()
}

// What kind of file it is, by its name: "markdown", "html", "text", "enex",
// "office" (read through LibreOffice or pandoc), "zip", or "" (not notes).
function kindOf(path) {
  var ext = (/\.([A-Za-z0-9]{1,9})$/.exec(String(path || "")) || ["", ""])[1].toLowerCase()
  if (["md", "markdown", "mdown", "mkd", "mkdn", "mdwn", "mdtxt", "mdtext", "text"].indexOf(ext) >= 0) return "markdown"
  if (["html", "htm", "xhtml"].indexOf(ext) >= 0) return "html"
  if (["txt", "log", "csv"].indexOf(ext) >= 0) return ext === "csv" ? "" : "text"
  if (ext === "enex") return "enex"
  if (["docx", "doc", "odt", "rtf", "epub", "org", "rst", "tex", "latex", "textile", "wiki", "mediawiki", "ipynb", "fodt", "pages", "wpd"].indexOf(ext) >= 0) return "office"
  if (ext === "zip") return "zip"
  return ""
}

// A path relative to a file's folder, made absolute ("" if it leaves the
// folder it's imported from, or is a web address).
function resolvePath(fromFile, rel, root) {
  var r = String(rel || "")
  if (!r || /^[a-z][a-z0-9+.-]*:/i.test(r) || r.charAt(0) === "#") return ""
  r = r.split("#")[0].split("?")[0]
  try { r = decodeURIComponent(r) } catch (e) {}
  var base = r.charAt(0) === "/" ? [] : String(fromFile || "").split("/").slice(0, -1)
  r.split("/").forEach(function(part) {
    if (part === "" || part === ".") return
    if (part === "..") base.pop()
    else base.push(part)
  })
  var abs = "/" + base.filter(function(p) { return p !== "" }).join("/")
  if (root && abs.indexOf(root.replace(/\/$/, "") + "/") !== 0) return ""
  return abs
}
