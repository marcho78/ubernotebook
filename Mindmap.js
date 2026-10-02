// Mindmap.js - mind maps in Pages: a topic in the middle and ideas branching
// out of it. A mind map block keeps its map as `outline`, one idea a line,
// each indented two spaces under the one it branches from, the first line the
// topic in the middle:
//
//   Launch plan
//     Marketing
//       Blog post
//     Engineering
//
// That's also how it comes and goes as Markdown, in a ```mindmap block (and
// how Mermaid writes a mind map, which is read too). An idea's colors come
// after it, in braces: "Marketing {red}" (its text), "Marketing {red
// background}", or both, "Marketing {red, yellow background}": a color
// Pages has, or one of your own, "Marketing {#ff8800}". A main idea's color
// is its branch's too. `folds` holds which
// ideas are folded (their branches hidden): their places in the outline,
// counting from 0 for the topic, "2,5".
//
// It reads and writes outlines, changes maps, and lays a map out for
// app/MindMap.qml to draw. Shared with tests/mindmap.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library

var MAX_NODES = 300
var MAX_TEXT = 160
var MAX_DEPTH = 8

// The colors an idea can have (as in Blocks.js and Docs.js), or any hex
// color ("#ff8800").
var COLORS = ["gray", "brown", "orange", "yellow", "green", "blue", "purple", "pink", "red"]

// A color as an idea keeps it: a name of COLORS, "#rrggbb", or "".
function cleanColor(value) {
  var v = String(value || "").trim().toLowerCase()
  if (COLORS.indexOf(v) >= 0) return v
  var m = /^#([0-9a-f]{3}|[0-9a-f]{6})$/.exec(v)
  if (!m) return ""
  var h = m[1]
  return "#" + (h.length === 3 ? h.charAt(0) + h.charAt(0) + h.charAt(1) + h.charAt(1) + h.charAt(2) + h.charAt(2) : h)
}

// ---- reading and writing ---------------------------------------------------------------

function cleanText(text) {
  return String(text || "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, MAX_TEXT)
}

function node(text, color, background) {
  return { text: cleanText(text), color: color || "", background: background || "", children: [], folded: false }
}

// "Marketing {red, blue background}" -> { text: "Marketing", color: "red",
// background: "blue" }. Braces that aren't colors stay part of the text.
function splitColors(line) {
  var t = String(line)
  var m = /^(.*?)\s*\{([^{}]*)\}\s*$/.exec(t)
  if (!m || !m[1].trim()) return { text: t, color: "", background: "" }
  var out = { text: m[1], color: "", background: "" }
  var parts = m[2].split(",").map(function(p) { return p.trim().toLowerCase() }).filter(function(p) { return p })
  if (parts.length === 0 || parts.length > 2) return { text: t, color: "", background: "" }
  for (var i = 0; i < parts.length; i++) {
    var c = /^([a-z]+|#[0-9a-f]+)(?:[ _]+(background|bg))?$/.exec(parts[i])
    var color = c ? cleanColor(c[1]) : ""
    if (!color) return { text: t, color: "", background: "" }
    if (c[2]) out.background = color
    else out.color = color
  }
  return out
}

// An idea's colors, as they're written after it: " {red, blue background}".
function colorMark(n) {
  var parts = []
  var color = cleanColor(n.color)
  var background = cleanColor(n.background)
  if (color) parts.push(color)
  if (background) parts.push(background + " background")
  return parts.length ? " {" + parts.join(", ") + "}" : ""
}

// What's written on a line: without a list's marker ("- ", "1. "), and,
// from Mermaid, without its shapes ("root((Topic))", "a[Idea]") and styles.
function lineText(raw, mermaid) {
  var t = String(raw).trim().replace(/^([-*+\u2022]|\d{1,3}[.)])\s+/, "")
  var colors = splitColors(t)
  t = colors.text
  if (mermaid) {
    t = t.replace(/:::[\w\s-]*$/, "").trim()
    // Each shape's brackets, the longer ones first.
    var shapes = [["((", "))"], ["))", "(("], ["{{", "}}"], ["(", ")"], [")", "("], ["[", "]"]]
    var id = /^[^\s()\[\]{}]*/.exec(t)[0]
    var rest = t.slice(id.length)
    for (var s = 0; s < shapes.length; s++) {
      var open = shapes[s][0]
      var close = shapes[s][1]
      if (rest.length > open.length + close.length && rest.indexOf(open) === 0 && rest.slice(-close.length) === close) {
        t = rest.slice(open.length, rest.length - close.length)
        break
      }
    }
    t = t.replace(/^["'`]+|["'`]+$/g, "").replace(/\*\*/g, "")
  }
  return { text: cleanText(t), color: colors.color, background: colors.background }
}

// An outline (or a Mermaid mind map) as a tree: { text, children, folded },
// the topic at the top; null when there's nothing in it. A second line as far
// left as the first is an idea of the topic too.
function parse(text) {
  var lines = String(text || "").replace(/\r/g, "").replace(/\t/g, "    ").split("\n")
  var mermaid = false
  var first = 0
  while (first < lines.length && !lines[first].trim()) first++
  if (first < lines.length && lines[first].trim().toLowerCase() === "mindmap") { mermaid = true; first++ }
  var root = null
  var stack = []
  var count = 0
  for (var i = first; i < lines.length && count < MAX_NODES; i++) {
    var raw = lines[i]
    if (!raw.trim()) continue
    if (mermaid && (/^\s*%%/.test(raw) || /^\s*::icon\(/.test(raw))) continue
    var read = lineText(raw, mermaid)
    if (!read.text) continue
    var width = /^ */.exec(raw)[0].length
    var n = node(read.text, read.color, read.background)
    count++
    if (!root) { root = n; continue }
    while (stack.length && stack[stack.length - 1].width >= width) stack.pop()
    // No deeper than MAX_DEPTH: deeper lines go in at that depth.
    if (stack.length > MAX_DEPTH - 1) stack.length = MAX_DEPTH - 1
    var parent = stack.length ? stack[stack.length - 1].node : root
    parent.children.push(n)
    stack.push({ width: width, node: n })
  }
  return root
}

// Every idea, the topic first, each before its own ideas: fn(node, depth, parent).
function walk(root, fn) {
  function go(n, depth, parent) {
    fn(n, depth, parent)
    n.children.forEach(function(c) { go(c, depth + 1, n) })
  }
  if (root) go(root, 0, null)
}

function serialize(root) {
  var out = []
  walk(root, function(n, depth) { if (n.text) out.push(new Array(depth + 1).join("  ") + n.text + colorMark(n)) })
  return out.join("\n")
}

// An outline as it's kept: "" when there's nothing in it.
function clean(text) {
  var root = parse(text)
  return root ? serialize(root) : ""
}

function count(outline) {
  var n = 0
  walk(parse(outline), function() { n++ })
  return n
}

// ---- folds -------------------------------------------------------------------------------

function cleanFolds(folds, total) {
  var seen = {}
  return String(folds || "").split(",").map(Number)
    .filter(function(i) { return i >= 1 && i < (total || 0) && Math.floor(i) === i && !seen[i] && (seen[i] = true) })
    .sort(function(a, b) { return a - b }).join(",")
}

function applyFolds(root, folds) {
  var set = {}
  String(folds || "").split(",").forEach(function(i) { if (i !== "") set[Number(i)] = true })
  var i = 0
  walk(root, function(n) { n.folded = !!set[i] && n.children.length > 0; i++ })
  return root
}

function foldsOf(root) {
  var out = []
  var i = 0
  walk(root, function(n) { if (n.folded && n.children.length) out.push(i); i++ })
  return out.join(",")
}

// ---- changing a map ------------------------------------------------------------------------

function copy(root) {
  function c(n) { return { text: n.text, color: n.color || "", background: n.background || "", folded: n.folded, children: n.children.map(c) } }
  return c(root)
}

function parentOf(root, target) {
  var found = null
  walk(root, function(n, depth, parent) { if (n === target) found = parent })
  return found
}

function descendants(n) {
  var total = 0
  n.children.forEach(function(c) { total += 1 + descendants(c) })
  return total
}

// Ideas left with no words (and nothing branching from them) go.
function prune(n) {
  n.children = n.children.filter(function(c) { prune(c); return c.text || c.children.length })
  return n
}

// ---- from and to lists ---------------------------------------------------------------------

// A topic and its ideas, [{ text, depth, color, background }] with depth 1
// for the ideas of the topic (`topic` the same, or just its text), as an
// outline.
function fromList(topic, items) {
  var top = typeof topic === "object" && topic ? topic : { text: topic }
  var lines = [(cleanText(top.text) || "Mind map") + colorMark(top)]
  var last = 0
  ;(items || []).forEach(function(it) {
    var text = cleanText(it.text)
    if (!text) return
    var depth = Math.max(1, Math.min(last + 1, MAX_DEPTH, Math.floor(Number(it.depth) || 1)))
    lines.push(new Array(depth + 1).join("  ") + text + colorMark(it))
    last = depth
  })
  return clean(lines.join("\n"))
}

// An outline as [{ text, depth, color, background }], the topic at depth 0.
function toList(outline) {
  var out = []
  walk(parse(outline), function(n, depth) { out.push({ text: n.text, depth: depth, color: n.color, background: n.background }) })
  return out
}

// ---- laying it out ---------------------------------------------------------------------------

// Words in lines no wider than max: [{ text, w }] (a word wider than that is
// broken up).
function wrap(text, max, advance) {
  var lines = []
  var line = ""
  function put(s) { lines.push({ text: s, w: advance(s) }) }
  String(text).split(" ").forEach(function(word) {
    while (advance(word) > max && word.length > 1) {
      var cut = word.length - 1
      while (cut > 1 && advance(word.slice(0, cut)) > max) cut--
      if (line) { put(line); line = "" }
      put(word.slice(0, cut))
      word = word.slice(cut)
    }
    var next = line ? line + " " + word : word
    if (line && advance(next) > max) { put(line); line = word }
    else line = next
  })
  if (line || lines.length === 0) put(line)
  return lines
}

// Where every idea goes. `m` measures: advance(text, depth) and
// lineHeight(depth) in pixels, maxWidth(depth), pad(depth) { x, y },
// minWidth, gapX(depth) and gapY(depth) (from an idea to its ideas, and
// between ideas), and `available` (the width there is). Both ways are tried,
// ideas on both sides of the topic and on its right only, and the one that
// needs shrinking least is used.
// Returns { nodes: [{ node, index, depth, branch, side, x, y, w, h, lines,
// anchorY, hidden }], edges: [{ from, to }] (into nodes), width, height,
// scale }.
function layout(root, m) {
  if (!root) return { nodes: [], edges: [], width: 0, height: 0, scale: 1 }
  var boxes = []
  var index = 0
  walk(root, function(n, depth) {
    var max = m.maxWidth(depth)
    var pad = m.pad(depth)
    var lines = wrap(n.text || " ", max, function(s) { return m.advance(s, depth) })
    var w = Math.max(m.minWidth || 0, Math.ceil(Math.max.apply(null, lines.map(function(l) { return l.w }))) + 2 * pad.x)
    var h = lines.length * m.lineHeight(depth) + 2 * pad.y
    n.$box = { index: index++, depth: depth, w: w, h: h, lines: lines.map(function(l) { return l.text }) }
  })
  function height(n) {
    var kids = n.folded ? [] : n.children
    var sum = 0
    kids.forEach(function(c, i) { sum += height(c) + (i ? m.gapY(c.$box.depth) : 0) })
    n.$box.tall = Math.max(n.$box.h, sum)
    return n.$box.tall
  }
  height(root)

  function arrange(sides) {
    var out = []
    var edges = []
    function place(n, x, cy, side, branch) {
      var b = n.$box
      var entry = { node: n, index: b.index, depth: b.depth, branch: branch, side: side, w: b.w, h: b.h, lines: b.lines,
        x: side < 0 ? x - b.w : x, y: cy - b.h / 2 }
      entry.anchorY = b.depth >= 2 ? entry.y + entry.h : cy
      out.push(entry)
      var at = out.length - 1
      if (n.folded) return at
      var kids = n.children
      var sum = 0
      kids.forEach(function(c, i) { sum += c.$box.tall + (i ? m.gapY(c.$box.depth) : 0) })
      var y = cy - sum / 2
      var gap = m.gapX(b.depth)
      kids.forEach(function(c) {
        var kx = side < 0 ? entry.x - gap : entry.x + entry.w + gap
        var k = place(c, kx, y + c.$box.tall / 2, side, branch)
        edges.push({ from: at, to: k })
        y += c.$box.tall + m.gapY(c.$box.depth)
      })
      return at
    }
    var rb = root.$box
    out.push({ node: root, index: rb.index, depth: 0, branch: -1, side: 0, w: rb.w, h: rb.h, lines: rb.lines, x: -rb.w / 2, y: -rb.h / 2, anchorY: 0 })
    var kids = root.folded ? [] : root.children
    var groups = { right: [], left: [] }
    if (sides === 2 && kids.length > 1) {
      var total = 0
      kids.forEach(function(c) { total += c.$box.tall })
      var acc = 0
      kids.forEach(function(c, i) {
        if (i === 0 || acc + c.$box.tall / 2 <= total / 2) { groups.right.push(c); acc += c.$box.tall }
        else groups.left.push(c)
      })
    } else {
      groups.right = kids.slice()
    }
    ;[["right", 1], ["left", -1]].forEach(function(g) {
      var list = groups[g[0]]
      var side = g[1]
      var sum = 0
      list.forEach(function(c, i) { sum += c.$box.tall + (i ? m.gapY(1) : 0) })
      var y = -sum / 2
      list.forEach(function(c) {
        var x = side > 0 ? rb.w / 2 + m.gapX(0) : -rb.w / 2 - m.gapX(0)
        var k = place(c, x, y + c.$box.tall / 2, side, kids.indexOf(c))
        edges.push({ from: 0, to: k })
        y += c.$box.tall + m.gapY(1)
      })
    })
    var minX = Infinity, minY = Infinity, maxX = -Infinity, maxY = -Infinity
    out.forEach(function(e) {
      minX = Math.min(minX, e.x); minY = Math.min(minY, e.y)
      maxX = Math.max(maxX, e.x + e.w); maxY = Math.max(maxY, e.y + e.h)
    })
    var pad = m.margin || 0
    out.forEach(function(e) { e.x += pad - minX; e.y += pad - minY; e.anchorY += pad - minY })
    var width = maxX - minX + 2 * pad
    return { nodes: out, edges: edges, width: width, height: maxY - minY + 2 * pad, scale: Math.min(1, (m.available || width) / width) }
  }
  var both = arrange(2)
  var result = both
  if (both.scale < 1) {
    var right = arrange(1)
    if (right.scale > both.scale + 0.02) result = right
  }
  walk(root, function(n) { delete n.$box })
  return result
}
