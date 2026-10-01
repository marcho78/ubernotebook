// Import.js - other people's notes as Pages: Markdown (Notion's, Obsidian's,
// GitHub's, anyone's), HTML (Notion's export too), plain text and Evernote's
// .enex, read into blocks with as little lost as possible: headings, bold,
// italics, strikethrough, highlights, code, links, nested lists, to-dos and
// whether they're ticked, quotes, callouts, code blocks and their language,
// dividers, pictures, toggles, columns (from Notion's HTML), colors, tables
// (as their text, until Pages has tables), links between the pages imported.
//
// Every reader gives { title, icon, blocks }: blocks as the editor has them
// (in order, each with its depth), their text sanitized as any page's is.
// `ctx` says what can't be known here: ctx.link(href) -> the href to use
// (a link to another imported page becomes omanote://page/<id>);
// ctx.image(src) -> "assets/<name>" for a picture that was copied in, or "";
// ctx.wiki(name) -> the id of the imported page called that, or "".
//
// Shared by the store (Workspace.qml), the editor (pasting Markdown) and
// tests/import.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html
.import "Blocks.js" as Blocks

var MONO = "'iA Writer Mono S'"
var HIGHLIGHT = "#fbf3db"

function context(ctx) {
  var c = ctx || {}
  return {
    link: typeof c.link === "function" ? c.link : function(h) { return h },
    image: typeof c.image === "function" ? c.image : function(s) { return "" },
    wiki: typeof c.wiki === "function" ? c.wiki : function(n) { return "" }
  }
}

// ---- inline Markdown ----------------------------------------------------------------------

var PUNCT = "!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~"

function styleWith(base, extra) {
  var s = {}
  for (var k in base) s[k] = base[k]
  for (var j in extra) {
    if (j === "text-decoration" && s[j]) s[j] = s[j] + " " + extra[j]
    else s[j] = extra[j]
  }
  return s
}

// A line (or lines) of Markdown text -> runs { text, style, href }, { br }.
function inlineRuns(text, ctx, refs) {
  var src = String(text || "")
  var atoms = []
  var i = 0
  function push(a) { atoms.push(a) }
  function textAtom(t) {
    if (t === "") return
    var last = atoms[atoms.length - 1]
    if (last && last.t === "text") last.v += t
    else push({ t: "text", v: t })
  }
  while (i < src.length) {
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
      var fence = new Array(n + 1).join("`")
      var close = src.indexOf(fence, i + n)
      while (close >= 0 && src.charAt(close + n) === "`") close = src.indexOf(fence, close + n + 1)
      if (close >= 0) {
        var code = src.slice(i + n, close).replace(/\n/g, " ")
        if (/^ .* $/.test(code) && /[^ ]/.test(code)) code = code.slice(1, -1)
        push({ t: "code", v: code })
        i = close + n
        continue
      }
      textAtom(fence); i += n; continue
    }
    // A hard line break (two spaces before it) or a soft one.
    if (ch === "\n") {
      var before = atoms[atoms.length - 1]
      if (before && before.t === "text" && / {2,}$/.test(before.v)) { before.v = before.v.replace(/ +$/, ""); push({ t: "br" }) }
      else textAtom(" ")
      i++
      continue
    }
    // <https://...> and <mailto:...>
    if (ch === "<") {
      var auto = /^<((?:https?|mailto|file):[^\s<>]+)>/i.exec(src.slice(i))
      if (auto) { push({ t: "link", href: auto[1], runs: [{ text: auto[1], style: {}, href: "" }] }); i += auto[0].length; continue }
      var tag = /^<(\/?)([a-zA-Z][a-zA-Z0-9]*)((?:\s+[^<>]*?)?)\s*(\/?)>/.exec(src.slice(i))
      if (tag) { push({ t: "tag", close: tag[1] === "/", name: tag[2].toLowerCase(), attrs: tag[3] || "" }); i += tag[0].length; continue }
    }
    // [[Page]], [[Page|shown as]] (Obsidian, and others).
    if (ch === "[" && src.charAt(i + 1) === "[") {
      var wend = src.indexOf("]]", i + 2)
      if (wend > i + 2 && src.slice(i + 2, wend).indexOf("\n") < 0) {
        var inner = src.slice(i + 2, wend)
        var bar = inner.indexOf("|")
        var target = (bar >= 0 ? inner.slice(0, bar) : inner).replace(/#.*$/, "").trim()
        var shown = (bar >= 0 ? inner.slice(bar + 1) : inner).trim()
        var id = ctx.wiki(target)
        if (id) push({ t: "link", href: "omanote://page/" + id, runs: [{ text: shown, style: {}, href: "" }] })
        else textAtom(shown)
        i = wend + 2
        continue
      }
    }
    // Pictures and links: ![alt](src "title"), [text](href "title"), [text][ref], [ref].
    if (ch === "[" || (ch === "!" && src.charAt(i + 1) === "[")) {
      var isImage = ch === "!"
      var open = isImage ? i + 1 : i
      var link = parseLink(src, open, refs)
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
          push({ t: "link", href: hrefOut, runs: inlineRuns(link.text, ctx, refs) })
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
      var bare = /^(?:https?:\/\/|www\.)[^\s<]*[^\s<.,:;"')\]]/i.exec(src.slice(i))
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

// [text](href "title") at `open` (the "["): { text, href, end }, or null.
function parseLink(src, open, refs) {
  var depth = 0
  var j = open
  for (; j < src.length; j++) {
    var c = src.charAt(j)
    if (c === "\\") { j++; continue }
    if (c === "`") { var k = src.indexOf("`", j + 1); if (k > j) j = k; continue }
    if (c === "[") depth++
    else if (c === "]") { depth--; if (depth === 0) break }
  }
  if (j >= src.length) return null
  var text = src.slice(open + 1, j)
  var after = src.slice(j + 1)
  var inl = /^\(\s*(<[^>]*>|[^\s()]*(?:\([^\s()]*\)[^\s()]*)*)(?:\s+("[^"]*"|'[^']*'|\([^)]*\)))?\s*\)/.exec(after)
  if (inl) {
    var href = inl[1].replace(/^<|>$/g, "")
    return { text: text, href: decodeHref(href), end: j + 1 + inl[0].length }
  }
  var ref = /^\[([^\]]*)\]/.exec(after)
  var key = (ref && ref[1] ? ref[1] : text).toLowerCase().replace(/\s+/g, " ").trim()
  if (refs && refs[key]) return { text: text, href: refs[key], end: j + 1 + (ref ? ref[0].length : 0) }
  return null
}

function decodeHref(href) {
  return String(href).replace(/\\([!-\/:-@\[-`{-~])/g, "$1")
}

// Matches delimiters (* ** _ __ ~~ ==) into styles, then gives the runs.
function resolve(atoms) {
  var spans = []
  var stack = []
  for (var i = 0; i < atoms.length; i++) {
    var a = atoms[i]
    if (a.t !== "delim") continue
    // A closer takes the nearest opener of its kind, as much of it as it can.
    var matched = a.close
    while (matched && a.n > 0) {
      matched = false
      for (var s = stack.length - 1; s >= 0; s--) {
        var o = atoms[stack[s]]
        if (o.ch !== a.ch || o.n === 0) continue
        // "Rule of three": *a**b* isn't a match of * with **.
        if ((o.close || a.open) && (o.orig + a.orig) % 3 === 0 && !(o.orig % 3 === 0 && a.orig % 3 === 0) && o.ch !== "~" && o.ch !== "=") continue
        var use = a.ch === "~" || a.ch === "=" ? 2 : (o.n >= 2 && a.n >= 2 ? 2 : 1)
        var style = a.ch === "~" ? { "text-decoration": "line-through" }
          : a.ch === "=" ? { "background-color": HIGHLIGHT }
          : use === 2 ? { "font-weight": "700" } : { "font-style": "italic" }
        spans.push({ from: stack[s], to: i, style: style })
        o.n -= use
        a.n -= use
        // Openers after it can't close any more.
        stack.length = o.n > 0 ? s + 1 : s
        matched = true
        break
      }
    }
    if (a.n > 0 && a.open) stack.push(i)
  }
  // Styles from html tags: <b>, <i>, <u>, <s>, <mark>, <code>, <sup>, <sub>, <span style>.
  var runs = []
  var tags = []
  function tagStyle() {
    var st = {}
    tags.forEach(function(t) { st = styleWith(st, t.style) })
    return st
  }
  function styleAt(idx) {
    var st = tagStyle()
    spans.forEach(function(sp) { if (idx > sp.from && idx < sp.to) st = styleWith(st, sp.style) })
    return st
  }
  for (var k = 0; k < atoms.length; k++) {
    var at = atoms[k]
    if (at.t === "text") runs.push({ text: at.v, style: styleAt(k), href: "" })
    else if (at.t === "br") runs.push({ br: true })
    else if (at.t === "code") runs.push({ text: at.v, style: styleWith(styleAt(k), { "font-family": MONO }), href: "" })
    else if (at.t === "delim" && at.n > 0) runs.push({ text: new Array(at.n + 1).join(at.ch), style: styleAt(k), href: "" })
    else if (at.t === "link") {
      var outer = styleAt(k)
      at.runs.forEach(function(r) {
        if (r.br) { runs.push(r); return }
        runs.push({ text: r.text, style: styleWith(outer, r.style), href: at.href })
      })
    } else if (at.t === "tag") {
      var name = at.name
      if (name === "br") { runs.push({ br: true }); continue }
      var tagStyles = { b: { "font-weight": "700" }, strong: { "font-weight": "700" }, i: { "font-style": "italic" }, em: { "font-style": "italic" },
        u: { "text-decoration": "underline" }, ins: { "text-decoration": "underline" }, s: { "text-decoration": "line-through" }, del: { "text-decoration": "line-through" },
        strike: { "text-decoration": "line-through" }, mark: { "background-color": HIGHLIGHT }, code: { "font-family": MONO }, kbd: { "font-family": MONO },
        sup: { "vertical-align": "super" }, sub: { "vertical-align": "sub" } }
      if (at.close) {
        for (var q = tags.length - 1; q >= 0; q--) if (tags[q].name === name) { tags.splice(q, 1); break }
      } else if (tagStyles[name]) {
        tags.push({ name: name, style: tagStyles[name] })
      } else if (name === "span" || name === "font") {
        var css = /style\s*=\s*"([^"]*)"/i.exec(at.attrs)
        var st2 = {}
        if (css) css[1].split(";").forEach(function(decl) {
          var p = decl.split(":")
          if (p.length < 2) return
          var key = p[0].trim().toLowerCase()
          var val = p.slice(1).join(":").trim()
          if (key === "color" || key === "background-color") st2[key] = val
        })
        var color = /color\s*=\s*"([^"]*)"/i.exec(at.attrs)
        if (name === "font" && color) st2.color = color[1]
        tags.push({ name: name, style: st2 })
      }
    }
  }
  return runs
}

function inlineHtml(text, ctx, refs) {
  return Html.sanitize(Html.serialize(inlineRuns(text, context(ctx), refs || {})), true)
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

function isBlank(line) { return /^\s*$/.test(line) }

function leading(line) {
  var n = 0
  for (var i = 0; i < line.length; i++) {
    if (line.charAt(i) === " ") n++
    else break
  }
  return n
}

function listMarker(line) {
  var m = /^( {0,3})([-*+]|\d{1,9}[.)])( +|$)(.*)$/.exec(line)
  if (!m) return null
  if (m[3] === "" && m[4] === "") return { indent: m[1].length, ordered: /\d/.test(m[2]), start: m[1].length + m[2].length + 1, rest: "", marker: m[2] }
  var pad = m[3].length > 4 ? 1 : m[3].length
  return { indent: m[1].length, ordered: /\d/.test(m[2]), start: m[1].length + m[2].length + pad, rest: m[3].length > 4 ? m[3].slice(1) + m[4] : m[4], marker: m[2] }
}

function fenceStart(line) {
  var m = /^( {0,3})(`{3,}|~{3,})\s*([^`\s]*)[^`]*$/.exec(line)
  return m ? { indent: m[1].length, fence: m[2], lang: m[3] } : null
}

function fenceEnd(line, f) {
  return new RegExp("^ {0,3}" + f.fence.charAt(0) + "{" + f.fence.length + ",}\\s*$").test(line)
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

function heading(line) {
  var m = /^ {0,3}(#{1,6})(?:[ \t]+(.*?))?(?:[ \t]+#+)?[ \t]*$/.exec(line)
  return m ? { level: m[1].length, text: m[2] || "" } : null
}

function tableRow(line) {
  var t = line.trim()
  if (t.indexOf("|") < 0) return null
  if (t.charAt(0) === "|") t = t.slice(1)
  if (t.charAt(t.length - 1) === "|" && t.charAt(t.length - 2) !== "\\") t = t.slice(0, -1)
  var cells = []
  var cell = ""
  for (var i = 0; i < t.length; i++) {
    var c = t.charAt(i)
    if (c === "\\" && t.charAt(i + 1) === "|") { cell += "|"; i++; continue }
    if (c === "|") { cells.push(cell.trim()); cell = ""; continue }
    cell += c
  }
  cells.push(cell.trim())
  return cells
}

function isTableRule(line) {
  return /^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$/.test(line) && line.indexOf("-") >= 0
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

// Lines of Markdown -> blocks (flat, with depths from 0).
function readBlocks(lines, ctx, refs) {
  var out = []
  var i = 0
  function emit(b) { out.push(b) }
  function para(text) {
    var html = inlineHtml(text, ctx, refs)
    return { type: "p", html: html, indent: 0 }
  }
  function startsBlock(line) {
    return heading(line) || fenceStart(line) || isRule(line) || /^ {0,3}>/.test(line) || listMarker(line) || /^ {0,3}<(details|aside)\b/i.test(line)
  }
  while (i < lines.length) {
    var line = lines[i]
    if (isBlank(line)) { i++; continue }

    // Code: ``` or ~~~, with its language.
    var f = fenceStart(line)
    if (f) {
      var code = []
      i++
      while (i < lines.length && !fenceEnd(lines[i], f)) {
        code.push(lines[i].slice(Math.min(f.indent, leading(lines[i]))))
        i++
      }
      i++
      emit({ type: "code", html: Html.fromPlainText(code.join("\n")), lang: langName(f.lang), indent: 0 })
      continue
    }

    var h = heading(line)
    if (h) {
      emit({ type: h.level === 1 ? "h1" : h.level === 2 ? "h2" : "h3", html: inlineHtml(h.text, ctx, refs), indent: 0 })
      i++
      continue
    }

    if (isRule(line)) { emit({ type: "divider", indent: 0 }); i++; continue }

    // A quote (or a callout: "> [!NOTE]"), and what's inside it.
    if (/^ {0,3}>/.test(line)) {
      var q = []
      while (i < lines.length && (/^ {0,3}>/.test(lines[i]) || (!isBlank(lines[i]) && q.length && !isBlank(q[q.length - 1]) && !startsBlock(lines[i])))) {
        q.push(lines[i].replace(/^ {0,3}> ?/, ""))
        i++
      }
      var callout = /^\s*\[!(\w+)\][+-]?\s*(.*)$/.exec(q[0] || "")
      var inner = readBlocks(callout ? [callout[2]].concat(q.slice(1)) : q, ctx, refs)
      var head = inner.length && inner[0].type === "p" && inner[0].indent === 0 ? inner.shift() : { html: "" }
      var kind = callout ? CALLOUTS[callout[1].toLowerCase()] || CALLOUTS.note : null
      emit(kind ? { type: "callout", icon: kind.icon, color: kind.color, html: head.html, indent: 0 } : { type: "quote", html: head.html, indent: 0 })
      inner.forEach(function(b) { b.indent += 1; emit(b) })
      continue
    }

    // Toggles and callouts written as HTML (GitHub's <details>, Notion's <aside>).
    var det = /^ {0,3}<(details|aside)\b[^>]*>(.*)$/i.exec(line)
    if (det) {
      var tagName = det[1].toLowerCase()
      var body = [det[2]]
      i++
      var closeRe = new RegExp("</" + tagName + ">", "i")
      if (!closeRe.test(det[2])) {
        while (i < lines.length && !closeRe.test(lines[i])) { body.push(lines[i]); i++ }
        if (i < lines.length) { body.push(lines[i]); i++ }
      }
      var all = body.join("\n").replace(closeRe, "")
      if (tagName === "details") {
        var sum = /<summary[^>]*>([\s\S]*?)<\/summary>/i.exec(all)
        var rest = all.replace(/<summary[^>]*>[\s\S]*?<\/summary>/i, "")
        emit({ type: "toggle", html: inlineHtml(sum ? sum[1].trim() : "", ctx, refs), indent: 0 })
        readBlocks(rest.split("\n"), ctx, refs).forEach(function(b) { b.indent += 1; emit(b) })
      } else {
        var parts = all.trim().split("\n")
        // Notion starts an <aside> with the callout's emoji.
        var em = /^\s*(\S{1,16})\s+(.*)$/.exec(parts[0] || "")
        var iconWord = em && !/[A-Za-z0-9<>&*_`#\[\]]/.test(em[1]) ? em[1] : ""
        var inside = readBlocks(iconWord ? [em[2]].concat(parts.slice(1)) : parts, ctx, refs)
        var first = inside.length && inside[0].type === "p" && inside[0].indent === 0 ? inside.shift() : { html: "" }
        emit({ type: "callout", icon: iconWord || "\u{1f4a1}", color: "gray_background", html: first.html, indent: 0 })
        inside.forEach(function(b) { b.indent += 1; emit(b) })
      }
      continue
    }

    // Lists: bullets, numbers, to-dos, and everything inside each item.
    var lm = listMarker(line)
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
      var task = /^\[([ xX])\][ \t]+(.*)$/.exec(item[0]) || /^\[([ xX])\]$/.exec(item[0])
      if (task) item[0] = task[2] || ""
      var parts2 = readBlocks(item, ctx, refs)
      var first2 = parts2.length && parts2[0].type === "p" && parts2[0].indent === 0 ? parts2.shift() : { html: "" }
      var type = task ? "check" : lm.ordered ? "number" : "bullet"
      var b0 = { type: type, html: first2.html, indent: 0 }
      if (task) b0.checked = task[1] !== " "
      emit(b0)
      parts2.forEach(function(b) { b.indent += 1; emit(b) })
      continue
    }

    // A table: as its text, lined up, in a code block (Pages has no tables yet).
    if (i + 1 < lines.length && tableRow(line) && isTableRule(lines[i + 1])) {
      var rows = [tableRow(line)]
      i += 2
      while (i < lines.length && !isBlank(lines[i]) && lines[i].indexOf("|") >= 0) { rows.push(tableRow(lines[i])); i++ }
      emit({ type: "code", lang: "Table", html: tableText(rows).map(Html.escapeText).map(function(l) { return l.replace(/  /g, " &nbsp;") }).join("<br />"), indent: 0 })
      continue
    }

    // Code indented by four spaces.
    if (leading(line) >= 4) {
      var ind = []
      while (i < lines.length && (leading(lines[i]) >= 4 || isBlank(lines[i]))) { ind.push(lines[i].slice(4)); i++ }
      while (ind.length && isBlank(ind[ind.length - 1])) ind.pop()
      emit({ type: "code", html: ind.map(function(l) { return Html.escapeText(l).replace(/  /g, " &nbsp;") }).join("<br />"), indent: 0 })
      continue
    }

    // A picture on a line of its own.
    var pic = /^\s*!\[([^\]]*)\]\(\s*<?([^\s>)]+)>?(?:\s+"[^"]*")?\s*\)\s*$/.exec(line) || /^\s*<img\b[^>]*\bsrc\s*=\s*"([^"]+)"[^>]*>\s*$/i.exec(line)
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
    var text = [line]
    i++
    while (i < lines.length && !isBlank(lines[i]) && !startsBlock(lines[i]) && !(/^ {0,3}(=+|-+)\s*$/.test(lines[i]))) {
      if (i + 1 < lines.length && tableRow(lines[i]) && isTableRule(lines[i + 1])) break
      text.push(lines[i])
      i++
    }
    if (i < lines.length && /^ {0,3}(=+|-+)\s*$/.test(lines[i])) {
      emit({ type: /=/.test(lines[i]) ? "h1" : "h2", html: inlineHtml(text.join(" ").trim(), ctx, refs), indent: 0 })
      i++
      continue
    }
    emit(para(text.map(function(t) { return t.replace(/^\s+/, "") }).join("\n")))
  }
  return out
}

// A table's rows as lines of text, the columns lined up.
function tableText(rows) {
  var widths = []
  rows.forEach(function(r) { r.forEach(function(c, k) { widths[k] = Math.max(widths[k] || 0, c.length) }) })
  var lines = rows.map(function(r) { return r.map(function(c, k) { return c + new Array(Math.max(0, (widths[k] || 0) - c.length) + 1).join(" ") }).join("  \u2502  ").replace(/\s+$/, "") })
  if (lines.length > 1) lines.splice(1, 0, widths.map(function(w) { return new Array(w + 1).join("\u2500") }).join("\u2500\u2500\u253c\u2500\u2500"))
  return lines
}

var LANGS = { js: "JavaScript", javascript: "JavaScript", ts: "TypeScript", typescript: "TypeScript", py: "Python", python: "Python", sh: "Bash", bash: "Bash",
  shell: "Bash", zsh: "Bash", console: "Bash", c: "C", cpp: "C++", "c++": "C++", cs: "C#", csharp: "C#", css: "CSS", go: "Go", golang: "Go", html: "HTML",
  java: "Java", json: "JSON", kotlin: "Kotlin", kt: "Kotlin", lua: "Lua", make: "Makefile", makefile: "Makefile", md: "Markdown", markdown: "Markdown",
  nix: "Nix", php: "PHP", qml: "QML", rb: "Ruby", ruby: "Ruby", rs: "Rust", rust: "Rust", sql: "SQL", swift: "Swift", toml: "TOML", yaml: "YAML", yml: "YAML",
  zig: "Zig", dockerfile: "Dockerfile", docker: "Dockerfile", xml: "XML", svg: "XML", diff: "Diff", patch: "Diff", ini: "INI",
  scss: "SCSS", jsx: "JavaScript", tsx: "TypeScript", text: "", plaintext: "", "plain text": "" }

// A code block's language as Pages names it (kept as written if it's not
// one it knows, so nothing's lost).
function langName(lang) {
  var l = String(lang || "").trim()
  if (!l) return ""
  var k = l.toLowerCase()
  if (Object.prototype.hasOwnProperty.call(LANGS, k)) return LANGS[k]
  return /^[A-Za-z0-9+#._ -]{1,24}$/.test(l) ? l : ""
}

// Markdown -> { title, icon, blocks }. The title comes from front matter
// ("title: ..."), or a first "# Title" when options.titleFromHeading.
function fromMarkdown(text, ctx, options) {
  var o = options || {}
  var c = context(ctx)
  var lines = expandTabs(String(text || "").replace(/^\ufeff/, "").replace(/\r\n?/g, "\n").split("\n"))
  var title = ""
  var icon = ""
  // Front matter (--- at the top, key: value lines, ---).
  if (lines[0] === "---") {
    var end = lines.indexOf("---", 1)
    if (end > 0 && end < 80) {
      lines.slice(1, end).forEach(function(l) {
        var m = /^(title|name|icon)\s*:\s*["']?(.*?)["']?\s*$/i.exec(l)
        if (m && m[1].toLowerCase() === "icon") icon = m[2]
        else if (m && !title) title = m[2]
      })
      lines = lines.slice(end + 1)
    }
  }
  var r = collectRefs(lines)
  var blocks = readBlocks(r.lines, c, r.refs)
  if (o.titleFromHeading && !title) {
    var firstText = -1
    for (var k = 0; k < blocks.length; k++) { if (blocks[k].type !== "divider") { firstText = k; break } }
    if (firstText >= 0 && blocks[firstText].type === "h1" && blocks[firstText].indent === 0) {
      title = Html.plainText(blocks[firstText].html).trim()
      blocks.splice(firstText, 1)
    }
  }
  // A page Notion exported starts with its title, then maybe its icon.
  return { title: title.trim(), icon: icon, blocks: blocks }
}

// Does pasted text look like Markdown (so it becomes blocks)?
function looksLikeMarkdown(text) {
  var t = String(text || "")
  if (t.indexOf("\n") < 0 && !/(\*\*|__|`|\[[^\]]+\]\()/.test(t)) return false
  return /^(#{1,6} |\s*[-*+] |\s*\d+[.)] |\s*[-*+] \[[ xX]\] |> |```|~~~|---\s*$|\|.*\|)/m.test(t) || /(\*\*[^*\n]+\*\*|`[^`\n]+`|\[[^\]\n]+\]\([^)\n]+\))/.test(t)
}

// ---- plain text -------------------------------------------------------------------------------

// Plain text: a paragraph a line (a blank line keeps its place).
function fromText(text) {
  var lines = String(text || "").replace(/^\ufeff/, "").replace(/\r\n?/g, "\n").split("\n")
  while (lines.length && isBlank(lines[lines.length - 1])) lines.pop()
  var blocks = []
  var blank = false
  lines.forEach(function(l) {
    if (isBlank(l)) {
      if (!blank && blocks.length) blocks.push({ type: "p", html: "", indent: 0 })
      blank = true
      return
    }
    blank = false
    blocks.push({ type: "p", html: Html.escapeText(l.replace(/\t/g, "    ")).replace(/  /g, " &nbsp;"), indent: 0 })
  })
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

// HTML -> a tree of { tag, attrs, kids } and { text } (forgiving, as browsers are).
function tree(html) {
  var root = { tag: "#root", attrs: {}, kids: [] }
  var stack = [root]
  var re = /<!--[\s\S]*?-->|<!\[CDATA\[([\s\S]*?)\]\]>|<!doctype[^>]*>|<\/\s*([a-zA-Z][a-zA-Z0-9-]*)\s*>|<([a-zA-Z][a-zA-Z0-9-]*)((?:\s+[^\s>\/=]+(?:\s*=\s*(?:"[^"]*"|'[^']*'|[^\s>]+))?)*)\s*(\/?)>|([^<]+)|</gi
  var m
  var src = String(html || "")
  while ((m = re.exec(src)) !== null) {
    var top = stack[stack.length - 1]
    if (m[1] !== undefined) { top.kids.push({ text: m[1] }); continue }
    if (m[2]) {
      var name = m[2].toLowerCase()
      for (var s = stack.length - 1; s > 0; s--) {
        if (stack[s].tag === name) { stack.length = s; break }
      }
      continue
    }
    if (m[3]) {
      var tag = m[3].toLowerCase()
      // An open <p> or <li> ends where the next one starts.
      if ((tag === "p" || tag === "li" || tag === "dt" || tag === "dd") && top.tag === tag) { stack.pop(); top = stack[stack.length - 1] }
      var node = { tag: tag, attrs: attrsOf(m[4]), kids: [] }
      top.kids.push(node)
      if (!VOID[tag] && !m[5]) stack.push(node)
      continue
    }
    if (m[6] !== undefined) top.kids.push({ text: Html.decodeEntities(m[6]) })
    else top.kids.push({ text: "<" })
  }
  return root
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

function notionColor(node, prefix) {
  var cls = node.attrs && node.attrs["class"] || ""
  var m = new RegExp("(?:^|\\s)" + prefix + "(" + NOTION_COLORS.join("|") + ")(_background)?(?:\\s|$)").exec(cls)
  if (!m) return ""
  var name = m[1] === "teal" ? "green" : m[1]
  return name + (m[2] || "")
}

// Inline HTML (a node's children) -> the inside of a block.
function inlineOf(nodes, ctx) {
  var out = ""
  nodes.forEach(function(n) {
    // White space in HTML is one space, as a browser shows it.
    if (n.text !== undefined) { out += Html.escapeText(n.text.replace(/[ \t\r\n\f]+/g, " ")); return }
    var tag = n.tag
    if (SKIP[tag]) return
    if (tag === "br") { out += "<br />"; return }
    if (tag === "img") { if (n.attrs.alt) out += Html.escapeText(n.attrs.alt); return }
    if (tag === "input") return
    var inner = inlineOf(n.kids || [], ctx)
    var style = n.attrs.style || ""
    var color = notionColor(n, "highlight-")
    if (color) {
      var c = notionHex(color)
      if (c) style += (/_background$/.test(color) ? ";background-color:" : ";color:") + c
    }
    if (tag === "a" && n.attrs.href) {
      var href = ctx.link(n.attrs.href)
      out += "<a href=\"" + Html.escapeAttr(href) + "\">" + inner + "</a>"
      return
    }
    var open = { b: "font-weight:700", strong: "font-weight:700", i: "font-style:italic", em: "font-style:italic", u: "text-decoration: underline",
      ins: "text-decoration: underline", s: "text-decoration: line-through", del: "text-decoration: line-through", strike: "text-decoration: line-through",
      mark: "background-color:" + HIGHLIGHT, code: "font-family:" + MONO, kbd: "font-family:" + MONO, sup: "vertical-align:super", sub: "vertical-align:sub" }[tag]
    if (open) style = open + ";" + style
    out += style ? "<span style=\"" + Html.escapeAttr(style) + "\">" + inner + "</span>" : inner
  })
  return out
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
  var root = tree(html)
  var title = ""
  var icon = ""
  var titleNode = find(root, function(n) { return n.tag === "h1" && hasClass(n, "page-title") })
  if (titleNode) title = textOf(titleNode).trim()
  if (!title) { var t = find(root, function(n) { return n.tag === "title" }); if (t) title = textOf(t).trim() }
  var iconNode = find(root, function(n) { return hasClass(n, "page-header-icon") })
  if (iconNode) {
    var iconText = textOf(iconNode).trim()
    if (iconText && !/[A-Za-z0-9]/.test(iconText) && iconText.length <= 16) icon = iconText
  }
  var body = find(root, function(n) { return n.tag === "body" }) || root
  var blocks = []
  readHtml(body.kids, 0, blocks, c, { skipTitle: titleNode })
  // A first heading that says the title again goes.
  if (title && blocks.length && /^h[123]$/.test(blocks[0].type) && Html.plainText(blocks[0].html).trim() === title) blocks.shift()
  if (o.titleFromHeading && !title && blocks.length && blocks[0].type === "h1") title = Html.plainText(blocks.shift().html).trim()
  return { title: title, icon: icon, blocks: blocks }
}

function isInline(n) {
  return n.text !== undefined || (!BLOCK[n.tag] && !SKIP[n.tag])
}

function readHtml(nodes, depth, out, ctx, opts) {
  var run = []
  function flush() {
    if (!run.length) return
    var inner = Html.sanitize(inlineOf(run, ctx), true)
    if (Html.plainText(inner).trim() !== "") out.push({ type: "p", html: inner.replace(/^(\s|&nbsp;)+|(\s|<br \/>)+$/g, ""), indent: depth })
    run = []
  }
  nodes.forEach(function(n) {
    if (isInline(n)) {
      if (n.text !== undefined && !run.length && /^\s*$/.test(n.text)) return
      run.push(n)
      return
    }
    flush()
    readHtmlBlock(n, depth, out, ctx, opts)
  })
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
  function add(b) { if (color) b.color = color; out.push(b); return b }
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
    var lines = textOf(codeNode).replace(/\n$/, "").split("\n")
    add({ type: "code", lang: langName(lang ? lang[1].replace(/_/g, " ") : ""), html: Html.fromPlainText(lines.join("\n")), indent: depth })
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
    var id = a ? /^omanote:\/\/page\/(.+)$/.exec(ctx.link(a.attrs.href || "")) : null
    if (id) add({ type: "link", target: id[1], indent: depth })
    else readHtml(n.kids, depth, out, ctx, opts)
    return
  }
  if (tag === "nav" && hasClass(n, "table_of_contents")) { add({ type: "toc", indent: depth }); return }
  // Columns (Notion's): side by side, at the top of the page.
  if (hasClass(n, "column-list") && depth === 0) {
    var cols = n.kids.filter(function(k) { return k.tag && hasClass(k, "column") })
    if (cols.length >= 2) {
      out.push({ type: "columns", indent: 0 })
      cols.forEach(function(col) {
        var w = /width:\s*calc\(\(100% - \(var\(--column-spacing\) \* \d+\)\) \* ([0-9.]+)\)/.exec(col.attrs.style || "") || /width:\s*([0-9.]+)%/.exec(col.attrs.style || "")
        var share = w ? Number(w[1]) : 0
        out.push({ type: "column", indent: 1, width: share > 1 ? share / 100 : share })
        var before = out.length
        readHtml(col.kids, 2, out, ctx, opts)
        if (out.length === before) out.push({ type: "p", html: "", indent: 2 })
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
      var b = { type: box ? "check" : tag === "ol" ? "number" : "bullet", html: Html.sanitize(inlineOf(inlineKids, ctx), true).replace(/^(\s|&nbsp;)+|(\s|<br \/>)+$/g, ""), indent: depth }
      if (box) b.checked = checked
      if (itemColor) b.color = itemColor
      out.push(b)
      readHtml(rest, depth + 1, out, ctx, opts)
    })
    return
  }
  if (tag === "table") {
    var rows = []
    ;(function walk(node) {
      (node.kids || []).forEach(function(k) {
        if (k.tag === "tr") rows.push(k.kids.filter(function(cell) { return cell.tag === "td" || cell.tag === "th" }).map(function(cell) { return textOf(cell).replace(/\s+/g, " ").trim() }))
        else if (k.tag) walk(k)
      })
    })(n)
    if (rows.length) add({ type: "code", lang: "Table", html: tableText(rows).map(Html.escapeText).map(function(l) { return l.replace(/  /g, " &nbsp;") }).join("<br />"), indent: depth })
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
    var html = inner().replace(/^(\s|&nbsp;)+|(\s|<br \/>)+$/g, "")
    if (Html.plainText(html).trim() !== "") add({ type: "p", html: html, indent: depth })
    return
  }
  // A container (div, section...): what's in it, at the same depth, in its color.
  var before = out.length
  readHtml(n.kids, depth, out, ctx, opts)
  if (color) for (var i = before; i < out.length; i++) if (out[i].indent === depth && !out[i].color) out[i].color = color
}

// ---- Evernote --------------------------------------------------------------------------------

// An .enex file (Evernote's export) -> its notes: [{ title, html, created }].
function enexNotes(xml) {
  var out = []
  var re = /<note>([\s\S]*?)<\/note>/g
  var m
  while ((m = re.exec(String(xml || ""))) !== null) {
    var note = m[1]
    var t = /<title>([\s\S]*?)<\/title>/.exec(note)
    var content = /<content>\s*<!\[CDATA\[([\s\S]*?)\]\]>\s*<\/content>/.exec(note)
    var created = /<created>(\d{8}T\d{6}Z)<\/created>/.exec(note)
    out.push({
      title: t ? Html.decodeEntities(t[1]).trim() : "",
      html: content ? content[1].replace(/<\/?en-note[^>]*>/g, "").replace(/<en-todo\s+checked="true"\s*\/>/g, "<input type=\"checkbox\" checked>").replace(/<en-todo[^>]*\/>/g, "<input type=\"checkbox\">").replace(/<en-media[^>]*\/>/g, "") : "",
      created: created ? created[1].replace(/^(\d{4})(\d{2})(\d{2})T(\d{2})(\d{2})(\d{2})Z$/, "$1-$2-$3T$4:$5:$6Z") : ""
    })
  }
  return out
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
