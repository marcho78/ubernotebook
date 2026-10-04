// Diagram.js - diagrams in Pages: a code block in Mermaid, drawn. It reads
// Mermaid's flowcharts (`graph` / `flowchart`), which is how decision
// trees, network diagrams and system diagrams are written (and what AI
// agents, Notion, Obsidian and GitHub write), and lays them out for
// app/DiagramView.qml to draw: boxes in rows (or columns), the lines between
// them kept apart, groups (subgraphs) around what's in them.
//
//   flowchart LR
//     user([User]) --> web[fa:fa-server Web]
//     subgraph Cloud
//       web -->|SQL| db[(Database)]
//     end
//
// Shared with tests/diagram.test.cjs, so keep it plain JavaScript with no
// QML or Node APIs.
.pragma library
.import "Colors.js" as Colors

// The code block language that's drawn as a diagram.
var LANG = "Mermaid"
var MAX_NODES = 200
var MAX_EDGES = 400
var MAX_TEXT = 20000
// It's read and laid out as it's typed, in the shell, so whatever's written
// is done at once: at most so many groups, so deep in each other; a line
// at most so many ranks long (---> is 2); so many ranks down the page; so
// many points for the long lines to go through, all told; so many classes
// given (class, :::), all told; so many characters of a line's words
// (drawn on every line they're on: A & B -->|words| C & D).
var MAX_GROUPS = 100
var MAX_DEPTH = 16
var MAX_LENGTH = 5
var MAX_RANKS = 400
var MAX_BENDS = 2000
var MAX_CLASSES = 2000
var MAX_LINE_WORDS = 200

function isLang(lang) { return String(lang || "").trim().toLowerCase() === "mermaid" }

// A map from what's written (an id, a class) to what it is, empty to start
// with: "constructor" or "__proto__" is a name like any other.
function dict() { return Object.create(null) }

// ---- reading Mermaid -----------------------------------------------------------------------

// A node's shape from its brackets: [[ ]] subroutine, [( )] cylinder,
// (( )) circle, ([ ]) stadium, {{ }} hexagon, [/ /] and [\ \]
// parallelograms, [/ \] and [\ /] trapezoids, > ] flag, ( ) rounded,
// { } decision, [ ] box.
var SHAPES = [
  { open: "(((", close: ")))", shape: "circle" },
  { open: "([", close: "])", shape: "stadium" },
  { open: "[[", close: "]]", shape: "subroutine" },
  { open: "[(", close: ")]", shape: "cylinder" },
  { open: "((", close: "))", shape: "circle" },
  { open: "{{", close: "}}", shape: "hexagon" },
  { open: "[/", close: "/]", shape: "lean-right" },
  { open: "[\\", close: "\\]", shape: "lean-left" },
  { open: "[/", close: "\\]", shape: "trapezoid" },
  { open: "[\\", close: "/]", shape: "trapezoid-alt" },
  { open: "(", close: ")", shape: "rounded" },
  { open: "[", close: "]", shape: "box" },
  { open: "{", close: "}", shape: "diamond" },
  { open: ">", close: "]", shape: "flag" }
]

// The shapes `@{ shape: … }` names (Mermaid 11), as the ones above.
var SHAPE_NAMES = {
  rect: "box", rectangle: "box", proc: "box", process: "box", rounded: "rounded", event: "rounded",
  stadium: "stadium", pill: "stadium", terminal: "stadium", "fr-rect": "subroutine", subroutine: "subroutine", subproc: "subroutine",
  cyl: "cylinder", cylinder: "cylinder", database: "cylinder", db: "cylinder", circle: "circle", circ: "circle", "dbl-circ": "circle",
  diam: "diamond", diamond: "diamond", decision: "diamond", question: "diamond", hex: "hexagon", hexagon: "hexagon", prepare: "hexagon",
  "lean-r": "lean-right", "lean-right": "lean-right", "in-out": "lean-right", "lean-l": "lean-left", "lean-left": "lean-left", "out-in": "lean-left",
  "trap-b": "trapezoid", trapezoid: "trapezoid", priority: "trapezoid", "trap-t": "trapezoid-alt", "inv-trapezoid": "trapezoid-alt", manual: "trapezoid-alt",
  flag: "flag", "odd": "flag", doc: "box", document: "box", cloud: "rounded"
}

// Icons a node can have (`fa:fa-server Web`, or `@{ icon: "server" }`):
// Font Awesome's names as Mermaid writes them, and the icon font's own,
// to the names app/DiagramView.qml draws.
var ICONS = {
  server: "server", servers: "server", "server-network": "serverNetwork", database: "database", db: "database",
  cloud: "cloud", laptop: "laptop", desktop: "desktop", computer: "desktop", "mobile": "phone", "mobile-alt": "phone",
  "mobile-screen": "phone", phone: "phone", cellphone: "phone", user: "user", person: "user", users: "users", "user-group": "users",
  globe: "web", web: "web", internet: "web", "network-wired": "lan", lan: "lan", switch: "lan", sitemap: "lan", "ethernet": "lan",
  wifi: "wifi", "access-point": "wifi", router: "router", "router-network": "router", firewall: "firewall", "wall-fire": "firewall",
  "fire": "firewall", "shield": "shield", "shield-alt": "shield", "shield-halved": "shield", lock: "lock", key: "key",
  hdd: "disk", disk: "disk", harddisk: "disk", "hard-drive": "disk", nas: "nas", storage: "nas", print: "printer", printer: "printer",
  docker: "docker", container: "docker", kubernetes: "kubernetes", k8s: "kubernetes", envelope: "mail", mail: "mail", email: "mail",
  code: "code", api: "api", gear: "gear", cog: "gear", cogs: "gear", queue: "queue", inbox: "queue", "layer-group": "queue",
  file: "file", "file-alt": "file", folder: "folder", bolt: "bolt", "chart-line": "chart", chart: "chart", search: "search",
  "credit-card": "card", "shopping-cart": "cart", cart: "cart", clock: "clock", bell: "bell", home: "home", house: "home",
  building: "building", "check": "check", times: "cross", "xmark": "cross", question: "question", "circle-question": "question"
}

function iconOf(name) {
  var n = String(name || "").trim().toLowerCase().replace(/^fa[srb]?:/, "").replace(/^fa-/, "").replace(/^mdi:/, "")
  return Object.prototype.hasOwnProperty.call(ICONS, n) ? ICONS[n] : ""
}

// A label as written: quotes off, <br> as a new line, entities and
// Mermaid's #quot; read; an icon at its start ("fa:fa-server Web") taken
// out of it. { text, icon }.
function labelOf(raw) {
  var t = String(raw || "").trim()
  if (t.length >= 2 && t.charAt(0) === "\"" && t.charAt(t.length - 1) === "\"") t = t.slice(1, -1)
  if (t.length >= 2 && t.charAt(0) === "`" && t.charAt(t.length - 1) === "`") t = t.slice(1, -1)
  t = t.replace(/<br\s*\/?>/gi, "\n").replace(/#quot;/g, "\"").replace(/#(\d+);/g, function(m, n) { return String.fromCharCode(Number(n)) })
    .replace(/&amp;/g, "&").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"")
  var icon = ""
  var m = /^\s*(fa[srb]?:fa-[a-z0-9-]+|fa[srb]?:[a-z0-9-]+|mdi:[a-z0-9-]+)\s*/i.exec(t)
  if (m) {
    icon = iconOf(m[1])
    t = t.slice(m[0].length)
  }
  // Markdown's ** and * in a label: the words alone.
  t = t.replace(/\*\*([^*]+)\*\*/g, "$1").replace(/\*([^*]+)\*/g, "$1")
  return { text: t.split("\n").map(function(l) { return l.trim() }).join("\n").trim(), icon: icon }
}

// What follows a node's id at `i` in `s`: its brackets and label, or an
// `@{ … }`. { shape, label, icon, end } or null. `closes` (optional, one
// for each line): where each closing bracket was looked for and found, so
// a line of brackets that never close is looked through once.
function readShape(s, i, closes) {
  if (s.charAt(i) === "@" && s.charAt(i + 1) === "{") {
    var close = s.indexOf("}", i + 2)
    if (close < 0) return null
    var body = s.slice(i + 2, close)
    var props = dict()
    // (A name from where a word starts: not tried again from each letter of a long one.)
    var re = /\b([a-zA-Z]+)\s*:\s*("([^"]*)"|[^,]+)/g
    var m
    while ((m = re.exec(body)) !== null) props[m[1].toLowerCase()] = (m[3] !== undefined ? m[3] : m[2]).trim()
    var named = String(props.shape || "").toLowerCase()
    var shape = Object.prototype.hasOwnProperty.call(SHAPE_NAMES, named) ? SHAPE_NAMES[named] : "box"
    var lab = labelOf(props.label || "")
    return { shape: shape, label: lab.text, icon: props.icon ? iconOf(props.icon) : lab.icon, end: close + 1, given: !!props.label }
  }
  // (Every shape starts with one of these.)
  var c = s.charAt(i)
  if (c !== "(" && c !== "[" && c !== "{" && c !== ">") return null
  for (var k = 0; k < SHAPES.length; k++) {
    var sh = SHAPES[k]
    if (s.substr(i, sh.open.length) !== sh.open) continue
    var from = i + sh.open.length
    var end = -1
    // A quoted label can hold the closing brackets.
    if (s.charAt(from) === "\"") {
      var q = s.indexOf("\"", from + 1)
      if (q >= 0 && s.substr(q + 1, sh.close.length) === sh.close) end = q + 1
    }
    if (end < 0) end = findClose(s, sh.close, from, closes)
    if (end < 0) continue
    var inner = s.slice(from, end)
    // (A shorter bracket matched first would leave a part of a longer one.)
    if (sh.open === "(" && inner.charAt(0) === "(") continue
    if (sh.open === "[" && /^[\[(/\\]/.test(inner)) continue
    if (sh.open === "{" && inner.charAt(0) === "{") continue
    var l = labelOf(inner)
    return { shape: sh.shape, label: l.text, icon: l.icon, end: end + sh.close.length, given: true }
  }
  return null
}

// Where `close` is in `s` from `from` on (-1: nowhere): s.indexOf, what
// it found kept in `closes` for the next look further on the same line.
function findClose(s, close, from, closes) {
  if (!closes) return s.indexOf(close, from)
  var known = closes[close]
  if (known && known.from <= from && (known.at < 0 || known.at >= from)) return known.at
  var at = s.indexOf(close, from)
  closes[close] = { from: from, at: at }
  return at
}

// A link at `i`: --> --- -.-> -.- ==> === --o --x <--> ~~~, longer ones
// (---> and ---- are a rank longer, up to MAX_LENGTH ranks), with text:
// -- text --> or -->|text|. { style, arrowStart, arrowEnd, label, length,
// end } or null.
function readLink(s, i) {
  // (Each read where it is in the line, not from a copy of the rest of it:
  // a long line of links is read through once.)
  // -- text --> / == text ==> / -. text .-> (the text can't start like a link).
  var re = /(<?)(--|==|-\.)\s*([^|>\n\-=.\s](?:[^|>\n]*?[^\s|>\-=.])?)\s*(--+|==+|\.-+)([>ox]?)/y
  re.lastIndex = i
  var m = re.exec(s)
  if (m) {
    var dashes = m[4].replace(/\./g, "").length + 1
    return { style: m[2] === "==" ? "thick" : m[2] === "-." ? "dotted" : "solid", arrowStart: m[1] === "<" ? "arrow" : "",
      arrowEnd: ends(m[5]), label: lineWords(labelOf(m[3]).text), length: Math.min(MAX_LENGTH, Math.max(1, dashes - (m[5] ? 1 : 2))), end: i + m[0].length }
  }
  re = /(<|o|x)?(-{2,}|={2,}|-\.+-|~{3,})([>ox]?)/y
  re.lastIndex = i
  m = re.exec(s)
  if (!m) return null
  var body = m[2]
  var count = body.replace(/\./g, "").length
  var out = { style: body.charAt(0) === "=" ? "thick" : body.charAt(0) === "~" ? "invisible" : body.indexOf(".") >= 0 ? "dotted" : "solid",
    arrowStart: m[1] === "<" ? "arrow" : m[1] === "o" ? "circle" : m[1] === "x" ? "cross" : "", arrowEnd: ends(m[3]),
    label: "", length: Math.min(MAX_LENGTH, Math.max(1, count - (m[3] ? 1 : 2))), end: i + m[0].length }
  // -->|text|
  re = /\s*\|([^|]*)\|/y
  re.lastIndex = out.end
  var lm = re.exec(s)
  if (lm) {
    out.label = lineWords(labelOf(lm[1]).text)
    out.end += lm[0].length
  }
  return out
}

function ends(c) { return c === ">" ? "arrow" : c === "o" ? "circle" : c === "x" ? "cross" : "" }

// A line's words, at most MAX_LINE_WORDS characters (cut, with an ellipsis).
function lineWords(text) {
  if (text.length <= MAX_LINE_WORDS) return text
  var cut = text.slice(0, MAX_LINE_WORDS - 1)
  // (Not half of a character written as two.)
  var last = cut.charCodeAt(cut.length - 1)
  if (last >= 0xd800 && last <= 0xdbff) cut = cut.slice(0, -1)
  return cut.trim() + "\u2026"
}

// Mermaid -> { kind: "flowchart", direction, nodes: [{ id, label, shape,
// icon, group, paint? }], edges: [{ from, to, label, style, arrowStart,
// arrowEnd, length, paint? }], groups: [{ id, label, parent, direction,
// paint? }], errors: [{ line, text }] }, or { kind, unsupported: true } for
// the diagrams it doesn't draw. `paint`: its colors, from `classDef`,
// `class` (or `:::`), `style` and `linkStyle` (see readStyle).
function parse(text) {
  var src = String(text || "").slice(0, MAX_TEXT).replace(/\r/g, "")
  var lines = src.split("\n")
  var out = { kind: "flowchart", direction: "TD", nodes: [], edges: [], groups: [], errors: [] }
  var byId = dict()
  var groupStack = []
  // Each group by its id, and how deep it is (0: in no other).
  var groupOf = dict()
  var started = false
  // Colors: classes by name, the classes given each id (in order), each
  // id's own style, the lines' styles ("default" or by number).
  var classDefs = dict()
  var classesOf = dict()
  var classesGiven = 0
  var styleOf = dict()
  var linkStyles = []
  // The shapes' closing marks already looked for on the line being read
  // (readShape: each looked for once a line).
  var closes = dict()
  function giveClass(id, name) {
    if (classesGiven >= MAX_CLASSES) return
    classesGiven++
    ;(classesOf[id] = classesOf[id] || []).push(name)
  }
  // A `classDef`, `class`, `style` or `linkStyle` line: false when it
  // isn't understood.
  function styleLine(kind, rest) {
    var m
    if (kind === "classDef") {
      m = /^([\w-]+(?:\s*,\s*[\w-]+)*)\s+(.+)$/.exec(rest)
      if (!m) return false
      var def = readStyle(m[2])
      m[1].split(",").forEach(function(name) { name = name.trim(); classDefs[name] = mergeStyle(classDefs[name] || {}, def) })
      return true
    }
    if (kind === "class") {
      var written = classLine(rest)
      if (!written) return false
      var names = written.names.split(",")
      written.ids.split(",").forEach(function(id) {
        id = id.trim()
        for (var k = 0; id && k < names.length && classesGiven < MAX_CLASSES; k++) giveClass(id, names[k].trim())
      })
      return true
    }
    if (kind === "style") {
      m = /^([A-Za-z0-9_\u00c0-\uffff][\w.\u00c0-\uffff-]*)\s+(.+)$/.exec(rest)
      if (!m) return false
      styleOf[m[1]] = mergeStyle(styleOf[m[1]] || {}, readStyle(m[2]))
      return true
    }
    // linkStyle 0,2 stroke:#f00 / linkStyle default stroke-width:2px
    // (an `interpolate` name before the style is how the line curves: left
    // as it's drawn here).
    m = /^(default|\d+(?:\s*,\s*\d+)*)\s+(?:interpolate\s+\w+\s*)?(.*)$/.exec(rest)
    if (!m) return false
    linkStyles.push({ which: m[1] === "default" ? "default" : m[1].split(",").map(function(n) { return Number(n.trim()) }), style: readStyle(m[2]) })
    return true
  }
  function node(id, def) {
    var n = byId[id]
    if (!n) {
      if (out.nodes.length >= MAX_NODES) return null
      n = { id: id, label: id, shape: "box", icon: "", group: groupStack.length ? groupStack[groupStack.length - 1] : "" }
      byId[id] = n
      out.nodes.push(n)
    }
    if (def) {
      n.shape = def.shape
      if (def.given) n.label = def.label
      if (def.icon) n.icon = def.icon
    }
    return n
  }
  // Ids and their shapes, `&` between them: "A & B[Two]". [ids] and where it ends.
  function readNodes(s, i) {
    var ids = []
    // (Each read where it is in the line, as readLink's are.)
    var idAt = /[A-Za-z0-9_\u00c0-\uffff](?:[\w.\u00c0-\uffff]|-(?![-.]))*/y
    var classAt = /:::([\w-]+)/y
    while (true) {
      while (s.charAt(i) === " " || s.charAt(i) === "\t") i++
      // (A link right after an id: "A-->B" reads "A" then "-->", the id
      // ending before a "--" or "-.".)
      idAt.lastIndex = i
      var m = idAt.exec(s)
      if (!m) break
      var id = m[0]
      i += id.length
      var def = readShape(s, i, closes)
      if (def) i = def.end
      var n = node(id, def)
      if (n) ids.push(n.id)
      while (s.charAt(i) === " " || s.charAt(i) === "\t") i++
      // ":::class" after it: its colors.
      classAt.lastIndex = i
      var cls = classAt.exec(s)
      if (cls) {
        if (n) giveClass(n.id, cls[1])
        i += cls[0].length
      }
      while (s.charAt(i) === " " || s.charAt(i) === "\t") i++
      if (s.charAt(i) === "&") { i++; continue }
      break
    }
    return { ids: ids, end: i }
  }
  // A name for a group written without one: "group" and how many there
  // are, or the next no other group has.
  function newGroupId() {
    var n = out.groups.length
    while (groupOf["group" + n]) n++
    return "group" + n
  }
  for (var ln = 0; ln < lines.length; ln++) {
    var parts = splitStatements(lines[ln])
    for (var p = 0; p < parts.length; p++) {
      var line = parts[p].trim()
      if (!line || line.indexOf("%%") === 0) continue
      if (!started) {
        var head = /^(graph|flowchart)(?:\s+(TB|TD|BT|RL|LR))?\s*$/i.exec(line)
        if (head) {
          started = true
          out.direction = head[2] ? head[2].toUpperCase().replace("TB", "TD") : "TD"
          continue
        }
        var other = /^([A-Za-z0-9-]+)\s*$|^([A-Za-z0-9-]+)\s/.exec(line)
        var kind = other ? (other[1] || other[2]) : ""
        if (OTHER_KINDS.test(kind)) return { kind: kind, unsupported: true, nodes: [], edges: [], groups: [], errors: [] }
        started = true
      }
      var sg = /^subgraph\s+(.*)$/i.exec(line)
      if (sg) {
        var rest = sg[1].trim()
        var gid = rest
        var glabel = rest
        var gm = /^([\w.-]+)\s*\[(.*)\]\s*$/.exec(rest)
        if (gm) { gid = gm[1]; glabel = labelOf(gm[2]).text }
        else if (/^".*"$/.test(rest)) { glabel = labelOf(rest).text; gid = newGroupId() }
        else glabel = labelOf(rest).text
        if (!gid) gid = newGroupId()
        var parent = groupStack.length ? groupStack[groupStack.length - 1] : ""
        // One begun before (even this one, inside itself): the same group,
        // what's in it this time in it too.
        if (groupOf[gid]) { groupStack.push(gid); continue }
        // One too many, or too deep: said, and what's in it is in the
        // group it's in.
        var depth = parent ? groupOf[parent].depth + 1 : 0
        if (out.groups.length >= MAX_GROUPS || depth >= MAX_DEPTH) {
          out.errors.push({ line: ln + 1, text: line })
          groupStack.push(parent)
          continue
        }
        var group = { id: gid, label: glabel, parent: parent, direction: "" }
        groupOf[gid] = { group: group, depth: depth }
        out.groups.push(group)
        groupStack.push(gid)
        continue
      }
      if (/^end$/i.test(line)) { groupStack.pop(); continue }
      var dir = /^direction\s+(TB|TD|BT|RL|LR)$/i.exec(line)
      if (dir) {
        var within = groupStack.length ? groupStack[groupStack.length - 1] : ""
        if (within) groupOf[within].group.direction = dir[1].toUpperCase().replace("TB", "TD")
        else if (!groupStack.length) out.direction = dir[1].toUpperCase().replace("TB", "TD")
        continue
      }
      var styled = /^(classDef|class|style|linkStyle)\s+(.*)$/.exec(line)
      if (styled) {
        if (!styleLine(styled[1], styled[2].trim())) out.errors.push({ line: ln + 1, text: line })
        continue
      }
      if (/^(classDef|class|style|linkStyle|click|accTitle|accDescr|title)\b/.test(line)) continue
      // Nodes and links between them: A --> B -->|x| C & D.
      closes = dict()
      var first = readNodes(line, 0)
      if (!first.ids.length) { out.errors.push({ line: ln + 1, text: line }); continue }
      var i = first.end
      var from = first.ids
      var ok = true
      while (i < line.length) {
        while (line.charAt(i) === " " || line.charAt(i) === "\t") i++
        if (i >= line.length) break
        var link = readLink(line, i)
        if (!link) { ok = false; break }
        i = link.end
        var next = readNodes(line, i)
        if (!next.ids.length) { ok = false; break }
        i = next.end
        // Every pair (A & B --> C & D), till there are as many lines as there can be.
        for (var fa = 0; fa < from.length && out.edges.length < MAX_EDGES; fa++) {
          for (var tb = 0; tb < next.ids.length && out.edges.length < MAX_EDGES; tb++) {
            out.edges.push({ from: from[fa], to: next.ids[tb], label: link.label, style: link.style, arrowStart: link.arrowStart, arrowEnd: link.arrowEnd, length: link.length })
          }
        }
        from = next.ids
      }
      if (!ok) out.errors.push({ line: ln + 1, text: line })
    }
  }
  // Groups named as nodes (a link to a subgraph): the group, not a box.
  out.nodes = out.nodes.filter(function(n) { return !groupOf[n.id] || out.edges.some(function(e) { return e.from === n.id || e.to === n.id }) })

  // Colors, as Mermaid ranks them: `classDef default` (boxes), then the
  // classes given (in order), then the id's own `style`; a line's,
  // `linkStyle default`, then its number's.
  function paintOf(id, withDefault) {
    var p = withDefault && classDefs["default"] ? mergeStyle({}, classDefs["default"]) : {}
    ;(classesOf[id] || []).forEach(function(name) { if (classDefs[name]) p = mergeStyle(p, classDefs[name]) })
    if (styleOf[id]) p = mergeStyle(p, styleOf[id])
    return Object.keys(p).length ? p : null
  }
  out.nodes.forEach(function(n) { var p = paintOf(n.id, true); if (p) n.paint = p })
  out.groups.forEach(function(g) { var p = paintOf(g.id, false); if (p) g.paint = p })
  if (linkStyles.length) {
    // (Each line's styles gathered once, in order, from the lines that name it.)
    var all = {}
    var byNumber = []
    linkStyles.forEach(function(ls) {
      if (ls.which === "default") { all = mergeStyle(all, ls.style); return }
      var named = dict()
      ls.which.forEach(function(k) {
        if (k < out.edges.length && !named[k]) { named[k] = true; byNumber[k] = mergeStyle(byNumber[k], ls.style) }
      })
    })
    out.edges.forEach(function(e, k) {
      var p = mergeStyle(all, byNumber[k])
      if (Object.keys(p).length) e.paint = p
    })
  }
  return out
}

// A `class` line's ids and classes: "a,b warm" -> { ids: "a,b", names:
// "warm" }, or null. The classes are the names at its end with commas
// between them (and spaces round those), after a space; as many as there
// are (found from the end, so it's quick however long the line is).
function classLine(rest) {
  var s = String(rest)
  var starts = []
  var i = s.length
  while (i > 0 && /\s/.test(s.charAt(i - 1))) i--
  while (i > 0) {
    var end = i
    while (i > 0 && /[\w-]/.test(s.charAt(i - 1))) i--
    if (i === end) break
    starts.push(i)
    var j = i
    while (j > 0 && /\s/.test(s.charAt(j - 1))) j--
    if (j === 0 || s.charAt(j - 1) !== ",") break
    j--
    while (j > 0 && /\s/.test(s.charAt(j - 1))) j--
    i = j
  }
  // The first of those names with a space before it, and an id before that.
  for (var k = starts.length - 1; k >= 0; k--) {
    var at = starts[k]
    var before = at
    while (before > 0 && /\s/.test(s.charAt(before - 1))) before--
    if (before === at || before === 0) continue
    var ids = s.slice(0, before)
    if (/[\n\r\u2028\u2029]/.test(ids)) return null
    return { ids: ids, names: s.slice(at).trim() }
  }
  return null
}

// Mermaid's other diagrams (not drawn here).
var OTHER_KINDS = /^(sequenceDiagram|classDiagram(-v2)?|stateDiagram(-v2)?|erDiagram|journey|gantt|pie|quadrantChart|requirementDiagram|gitGraph|C4Context|C4Container|C4Component|C4Dynamic|C4Deployment|mindmap|timeline|zenuml|sankey(-beta)?|xychart(-beta)?|block(-beta)?|packet(-beta)?|kanban|architecture(-beta)?|radar(-beta)?|treemap(-beta)?)$/i

// A line's statements: ";" between them (not inside a label's brackets or quotes).
function splitStatements(line) {
  var out = []
  var depth = 0
  var quoted = false
  var cur = ""
  for (var i = 0; i < line.length; i++) {
    var c = line.charAt(i)
    if (c === "\"") quoted = !quoted
    if (!quoted) {
      if (c === "[" || c === "(" || c === "{") depth++
      else if (c === "]" || c === ")" || c === "}") depth = Math.max(0, depth - 1)
      else if (c === ";" && depth === 0) { out.push(cur); cur = ""; continue }
    }
    cur += c
  }
  out.push(cur)
  return out
}

// What the drawing says it can't do, or what in it it doesn't understand.
function problem(g) {
  if (!g) return ""
  if (g.unsupported) return "Uber Notebook draws Mermaid's flowcharts (graph or flowchart); this is a \u201c" + g.kind + "\u201d diagram, kept as it's written."
  if (g.errors && g.errors.length) return "Line " + g.errors[0].line + " isn't understood: " + g.errors[0].text.slice(0, 80)
  if (!g.nodes.length) return "Nothing to draw yet."
  return ""
}

// ---- colors ----------------------------------------------------------------------------------

// CSS's named colors (Mermaid's styles are CSS's), as hex.
var NAMED = (function() {
  var words = (
  "aliceblue f0f8ff antiquewhite faebd7 aqua 00ffff aquamarine 7fffd4 azure f0ffff beige f5f5dc " +
  "bisque ffe4c4 black 000000 blanchedalmond ffebcd blue 0000ff blueviolet 8a2be2 brown a52a2a " +
  "burlywood deb887 cadetblue 5f9ea0 chartreuse 7fff00 chocolate d2691e coral ff7f50 " +
  "cornflowerblue 6495ed cornsilk fff8dc crimson dc143c cyan 00ffff darkblue 00008b " +
  "darkcyan 008b8b darkgoldenrod b8860b darkgray a9a9a9 darkgreen 006400 darkgrey a9a9a9 " +
  "darkkhaki bdb76b darkmagenta 8b008b darkolivegreen 556b2f darkorange ff8c00 darkorchid 9932cc " +
  "darkred 8b0000 darksalmon e9967a darkseagreen 8fbc8f darkslateblue 483d8b darkslategray 2f4f4f " +
  "darkslategrey 2f4f4f darkturquoise 00ced1 darkviolet 9400d3 deeppink ff1493 deepskyblue 00bfff " +
  "dimgray 696969 dimgrey 696969 dodgerblue 1e90ff firebrick b22222 floralwhite fffaf0 " +
  "forestgreen 228b22 fuchsia ff00ff gainsboro dcdcdc ghostwhite f8f8ff gold ffd700 " +
  "goldenrod daa520 gray 808080 green 008000 greenyellow adff2f grey 808080 honeydew f0fff0 " +
  "hotpink ff69b4 indianred cd5c5c indigo 4b0082 ivory fffff0 khaki f0e68c lavender e6e6fa " +
  "lavenderblush fff0f5 lawngreen 7cfc00 lemonchiffon fffacd lightblue add8e6 lightcoral f08080 " +
  "lightcyan e0ffff lightgoldenrodyellow fafad2 lightgray d3d3d3 lightgreen 90ee90 " +
  "lightgrey d3d3d3 lightpink ffb6c1 lightsalmon ffa07a lightseagreen 20b2aa lightskyblue 87cefa " +
  "lightslategray 778899 lightslategrey 778899 lightsteelblue b0c4de lightyellow ffffe0 " +
  "lime 00ff00 limegreen 32cd32 linen faf0e6 magenta ff00ff maroon 800000 mediumaquamarine 66cdaa " +
  "mediumblue 0000cd mediumorchid ba55d3 mediumpurple 9370db mediumseagreen 3cb371 " +
  "mediumslateblue 7b68ee mediumspringgreen 00fa9a mediumturquoise 48d1cc mediumvioletred c71585 " +
  "midnightblue 191970 mintcream f5fffa mistyrose ffe4e1 moccasin ffe4b5 navajowhite ffdead " +
  "navy 000080 oldlace fdf5e6 olive 808000 olivedrab 6b8e23 orange ffa500 orangered ff4500 " +
  "orchid da70d6 palegoldenrod eee8aa palegreen 98fb98 paleturquoise afeeee palevioletred db7093 " +
  "papayawhip ffefd5 peachpuff ffdab9 peru cd853f pink ffc0cb plum dda0dd powderblue b0e0e6 " +
  "purple 800080 rebeccapurple 663399 red ff0000 rosybrown bc8f8f royalblue 4169e1 " +
  "saddlebrown 8b4513 salmon fa8072 sandybrown f4a460 seagreen 2e8b57 seashell fff5ee " +
  "sienna a0522d silver c0c0c0 skyblue 87ceeb slateblue 6a5acd slategray 708090 slategrey 708090 " +
  "snow fffafa springgreen 00ff7f steelblue 4682b4 tan d2b48c teal 008080 thistle d8bfd8 " +
  "tomato ff6347 turquoise 40e0d0 violet ee82ee wheat f5deb3 white ffffff whitesmoke f5f5f5 " +
  "yellow ffff00 yellowgreen 9acd32").split(" ")
  var out = {}
  for (var i = 0; i + 1 < words.length; i += 2) out[words[i]] = "#" + words[i + 1]
  return out
})()

// A CSS color -> Qt's "#rrggbb" ("#aarrggbb" when it's see-through), or ""
// when it isn't one: #rgb, #rgba, #rrggbb, #rrggbbaa, rgb() and rgba(),
// hsl() and hsla() (commas or spaces between, "/ alpha"), a name, none or
// transparent.
function cssColor(value) {
  var v = String(value || "").trim().toLowerCase()
  if (!v) return ""
  if (v === "none" || v === "transparent") return "#00000000"
  var m = /^#([0-9a-f]{3,4}|[0-9a-f]{6}|[0-9a-f]{8})$/.exec(v)
  if (m) {
    var h = m[1].length <= 4 ? m[1].replace(/./g, "$&$&") : m[1]
    return withAlpha("#" + h.slice(0, 6), h.length === 8 ? parseInt(h.slice(6), 16) / 255 : 1)
  }
  m = /^(rgba?|hsla?)\(\s*([^)]*)\)$/.exec(v)
  if (m) {
    var parts = m[2].split(/\s*[,\/]\s*|\s+/).filter(function(x) { return x !== "" })
    if (parts.length < 3 || parts.length > 4) return ""
    var a = parts.length === 4 ? cssNumber(parts[3], 1) : 1
    if (isNaN(a)) return ""
    a = Math.max(0, Math.min(1, a))
    if (m[1].charAt(0) === "r") {
      var r = cssNumber(parts[0], 255), g = cssNumber(parts[1], 255), b = cssNumber(parts[2], 255)
      if (isNaN(r) || isNaN(g) || isNaN(b)) return ""
      return withAlpha(Colors.toHex(r, g, b), a)
    }
    var hue = parseFloat(parts[0]), sat = cssNumber(parts[1], 1), light = cssNumber(parts[2], 1)
    if (isNaN(hue) || isNaN(sat) || isNaN(light)) return ""
    return withAlpha(hslHex(hue, sat > 1 ? sat / 100 : sat, light > 1 ? light / 100 : light), a)
  }
  return Object.prototype.hasOwnProperty.call(NAMED, v) ? NAMED[v] : ""
}

// "50%" (of `whole`) or "0.5".
function cssNumber(text, whole) {
  var n = parseFloat(text)
  if (isNaN(n)) return NaN
  return /%$/.test(text) ? n / 100 * whole : n
}

function hslHex(h, s, l) {
  var hh = ((h % 360) + 360) % 360
  var ss = Math.max(0, Math.min(1, s))
  var ll = Math.max(0, Math.min(1, l))
  var c = (1 - Math.abs(2 * ll - 1)) * ss
  var x = c * (1 - Math.abs((hh / 60) % 2 - 1))
  var m = ll - c / 2
  var p = hh < 60 ? [c, x, 0] : hh < 120 ? [x, c, 0] : hh < 180 ? [0, c, x] : hh < 240 ? [0, x, c] : hh < 300 ? [x, 0, c] : [c, 0, x]
  return Colors.toHex((p[0] + m) * 255, (p[1] + m) * 255, (p[2] + m) * 255)
}

// Qt's "#aarrggbb": how see-through (1: not at all), the color without it,
// and "#rrggbb" with `a`.
function alphaOf(c) { return /^#[0-9a-f]{8}$/i.test(c) ? parseInt(c.slice(1, 3), 16) / 255 : 1 }
function opaque(c) { return /^#[0-9a-f]{8}$/i.test(c) ? "#" + c.slice(3) : c }
function withAlpha(hex, a) {
  if (a >= 1) return hex
  return "#" + ("0" + Math.round(Math.max(0, a) * 255).toString(16)).slice(-2) + hex.slice(1)
}
// A see-through color as it shows on `paper`.
function over(c, paper) {
  var a = alphaOf(c)
  if (a >= 1) return opaque(c)
  var x = Colors.rgb(opaque(c))
  var y = Colors.rgb(paper)
  if (!x || !y) return paper
  return Colors.toHex(x.r * a + y.r * (1 - a), x.g * a + y.g * (1 - a), x.b * a + y.b * (1 - a))
}

// A style, as `classDef`, `style` and `linkStyle` write it
// ("fill:#f9f,stroke:#333,stroke-width:4px,color:#fff") -> what it says of
// what's drawn here: { fill, stroke, color (the words'), width (px), dash
// ([px, px, ...]; [] for none), bold, italic }. The rest (a font's size,
// rounded corners) is left out.
function readStyle(text) {
  var t = String(text || "")
  var parts = []
  var depth = 0
  var cur = ""
  for (var i = 0; i < t.length; i++) {
    var ch = t.charAt(i)
    if (ch === "(") depth++
    else if (ch === ")") depth = Math.max(0, depth - 1)
    if (ch === "," && depth === 0) { parts.push(cur); cur = ""; continue }
    cur += ch
  }
  parts.push(cur)
  var props = dict()
  var last = ""
  parts.forEach(function(part) {
    var at = part.indexOf(":")
    // ("stroke-dasharray: 5, 5": what follows a comma, without a name, is
    // the one before's.)
    if (at < 0) { if (last && part.trim()) props[last] += "," + part; return }
    last = part.slice(0, at).trim().toLowerCase()
    props[last] = part.slice(at + 1)
  })
  var out = {}
  Object.keys(props).forEach(function(k) {
    var v = props[k].replace(/!important/i, "")
    // ("red;" or "red ; ": the semicolons at its end off.)
    var stop = v.length
    while (stop > 0 && /\s/.test(v.charAt(stop - 1))) stop--
    var from = stop
    while (from > 0 && v.charAt(from - 1) === ";") from--
    if (from < stop) v = v.slice(0, from)
    v = v.trim()
    var c = ""
    if (k === "fill") { c = cssColor(v); if (c) out.fill = c }
    else if (k === "stroke") { c = cssColor(v); if (c) out.stroke = c }
    else if (k === "color") { c = cssColor(v); if (c) out.color = c }
    else if (k === "stroke-width") { var w = parseFloat(v); if (!isNaN(w)) out.width = Math.max(0, Math.min(12, w)) }
    else if (k === "stroke-dasharray") {
      var d = v.toLowerCase() === "none" ? [] : v.split(/[\s,]+/).map(parseFloat).filter(function(x) { return !isNaN(x) && x >= 0 })
      if (d.every(function(x) { return x === 0 })) d = []
      if (d.length % 2) d = d.concat(d)
      out.dash = d.slice(0, 8).map(function(x) { return Math.min(60, x) })
    }
    else if (k === "font-weight") { var fw = v.toLowerCase(); out.bold = fw === "bold" || fw === "bolder" || parseFloat(fw) >= 600 }
    else if (k === "font-style") { var fs = v.toLowerCase(); out.italic = fs === "italic" || fs === "oblique" }
  })
  return out
}

// `b` over `a` (what `b` says wins).
function mergeStyle(a, b) {
  var out = {}
  Object.keys(a || {}).forEach(function(k) { out[k] = a[k] })
  Object.keys(b || {}).forEach(function(k) { out[k] = b[k] })
  return out
}

// How a box, a group or a line (`line`) with `paint` is drawn on the page
// (its `ink` and `paper`, "#rrggbb"): { fill, stroke, text, width, dash,
// bold, italic }, "" (width -1, dash null) where it's the page's own. A
// line, and an outline round nothing filled, shows on the page whatever
// its color (lighter on a dark page, darker on a light one, as a mind
// map's do). Words read on what's behind them: their own color, made a
// little darker or lighter if it has to be; with none, the page's ink, or
// what reads better on a box's own color. A line's words are on the page.
function look(paint, ink, paper, line) {
  var p = paint || {}
  var fill = !line && p.fill ? p.fill : ""
  var out = { fill: fill, stroke: "", text: "", width: p.width !== undefined ? p.width : -1, dash: p.dash || null, bold: !!p.bold, italic: !!p.italic }
  if (p.stroke) out.stroke = (line || !fill) && alphaOf(p.stroke) > 0 ? withAlpha(Colors.visibleOn(opaque(p.stroke), paper), alphaOf(p.stroke)) : p.stroke
  var back = fill ? over(fill, paper) : paper
  if (p.color && alphaOf(p.color) > 0) out.text = Colors.visibleOn(over(p.color, back), back, 3)
  else if (fill) out.text = Colors.readableOn(back, ink)
  return out
}

// ---- laying it out -------------------------------------------------------------------------

// Where everything goes. `measure(text, bold)` -> its width in px (one line);
// `opts`: { lineHeight, icon (px), maxText (px a label wraps at) }.
// { w, h, nodes: { id: { x, y, w, h, lines, shape, icon, paint? } }, edges:
// [{ from, to, points: [{ x, y }], label, labelAt, style, arrowStart,
// arrowEnd, paint? }], groups: [{ id, label, x, y, w, h, depth, paint? }] },
// in px, top left at 0, 0.
function layout(g, measure, opts) {
  var o = opts || {}
  var lineH = o.lineHeight || 18
  var iconH = o.icon || 22
  var maxText = o.maxText || 180
  var measureText = typeof measure === "function" ? measure : function(t) { return String(t).length * 7.5 }
  var vertical = g.direction === "TD" || g.direction === "BT"
  var GAP_X = 36
  var GAP_RANK = 56
  var PAD = 24
  // (No more than parse gives, each id once, whatever it's given.)
  var seen = dict()
  var nodes = (g.nodes || []).filter(function(n) { if (!n || seen[n.id]) return false; seen[n.id] = true; return true }).slice(0, MAX_NODES)
  var groups = groupTree(g)
  if (!nodes.length) return { nodes: dict(), edges: [], groups: [], w: 0, h: 0 }

  // Each node's size, its label wrapped.
  var sizes = dict()
  nodes.forEach(function(n) {
    // (Bold words measured bold.)
    var bold = !!(n.paint && n.paint.bold)
    var measureIt = bold ? function(t) { return measureText(t, true) } : measureText
    // (A question's words in a narrower column, so its diamond is less flat.)
    var lines = wrap(n.label, measureIt, n.shape === "diamond" ? Math.min(maxText, 120) : maxText)
    var tw = 0
    lines.forEach(function(l) { tw = Math.max(tw, measureIt(l)) })
    var w = tw + 28
    var textH = lines.length * lineH + (n.icon ? iconH + 4 : 0)
    var h = textH + 16
    // A diamond round its words: they fit when their width over its width
    // and their height over its height come to no more than 1 (twice their
    // size each way does, with a little room); a circle: their diagonal.
    if (n.shape === "diamond") { w = (tw + 8) * 2 + 8; h = (textH + 4) * 2 + 6 }
    else if (n.shape === "circle") { var d = Math.sqrt((tw + 16) * (tw + 16) + (textH + 8) * (textH + 8)) + 4; w = d; h = d }
    else if (n.shape === "hexagon") w += 24
    else if (n.shape === "lean-right" || n.shape === "lean-left" || n.shape === "trapezoid" || n.shape === "trapezoid-alt") w += 24
    else if (n.shape === "cylinder") h += 14
    else if (n.shape === "stadium") w += h * 0.5
    else if (n.shape === "flag") w += 14
    w = Math.max(w, n.icon ? 72 : 48)
    h = Math.max(h, 36)
    sizes[n.id] = { w: Math.round(w), h: Math.round(h), lines: lines }
  })
  // Laid out down the page (as TD), then turned for LR, BT, RL: a node's
  // breadth across a rank, its depth along the way.
  function breadth(id) { return vertical ? sizes[id].w : sizes[id].h }
  function depthOf(id) { return vertical ? sizes[id].h : sizes[id].w }

  var ids = nodes.map(function(n) { return n.id })
  var index = dict()
  ids.forEach(function(id, i) { index[id] = i })
  var edges = (g.edges || []).filter(function(e) { return e && index[e.from] !== undefined && index[e.to] !== undefined }).slice(0, MAX_EDGES)
  // Lines with words on them: each line goes a rank further, its words in
  // the rank between (as big as they are), so words never sit on each other
  // or on a box; the ranks half as far apart.
  var labelled = edges.some(function(e) { return e.label })
  var SPAN = labelled ? 2 : 1
  if (labelled) GAP_RANK = 24

  // Ranks: the longest way to each node from where the arrows start (an
  // arrow that goes back round a loop counts the other way), a longer line
  // (--->) as many ranks as it says; if that's more ranks than there can
  // be, each long line a rank shorter, till they fit.
  var back = backEdges(ids, edges)
  var rank = null
  for (var longest = MAX_LENGTH; longest >= 1; longest--) {
    rank = ranksWith(longest)
    var deepest = 0
    ids.forEach(function(id) { deepest = Math.max(deepest, rank[id]) })
    if (deepest < MAX_RANKS) break
  }
  function ranksWith(longest) {
    var dag = edges.map(function(e, k) {
      var length = Math.min(longest, Math.max(1, e.length || 1))
      return back[k] ? { from: e.to, to: e.from, length: length } : { from: e.from, to: e.to, length: length }
    }).filter(function(e) { return e.from !== e.to })
    var at = dict()
    var ins = dict()
    var outs = dict()
    ids.forEach(function(id) { at[id] = 0; ins[id] = 0; outs[id] = [] })
    dag.forEach(function(e) { ins[e.to]++; outs[e.from].push(e) })
    // (Each node once all that lead to it have their ranks: with the arrows
    // that go back turned round, nothing leads back to itself.)
    var waiting = dict()
    var ready = []
    ids.forEach(function(id) { waiting[id] = ins[id]; if (!ins[id]) ready.push(id) })
    for (var q = 0; q < ready.length; q++) {
      outs[ready[q]].forEach(function(e) {
        at[e.to] = Math.max(at[e.to], at[e.from] + e.length * SPAN)
        if (--waiting[e.to] === 0) ready.push(e.to)
      })
    }
    // A node only arrows leave: as late as it can be (just before the first
    // it points to), so its lines are short.
    ids.forEach(function(id) {
      if (ins[id] === 0 && outs[id].length) {
        var best = Infinity
        outs[id].forEach(function(e) { best = Math.min(best, at[e.to] - e.length * SPAN) })
        if (best > at[id] && best < Infinity) at[id] = best
      }
    })
    return at
  }

  // Long lines go through a point on each rank between (a "dummy"), as
  // many as there can be all told, the shortest lines' first: past that, a
  // line goes straight.
  var layers = []
  function addTo(r, item) {
    while (layers.length <= r) layers.push([])
    layers[r].push(item)
  }
  var groupOfNode = dict()
  nodes.forEach(function(n) { var t = n.group ? groups.byId[n.group] : null; groupOfNode[n.id] = t ? t.path : "" })
  ids.forEach(function(id) { addTo(rank[id], { id: id, real: true, group: groupOfNode[id] }) })
  var chains = []
  var routed = []
  var bends = 0
  edges.map(function(e, k) { return { k: k, between: e.from === e.to ? 0 : Math.max(0, Math.abs(rank[e.from] - rank[e.to]) - 1) } })
    .sort(function(a, b) { return a.between - b.between || a.k - b.k })
    .forEach(function(s) { if (bends + s.between <= MAX_BENDS) { bends += s.between; routed[s.k] = true } })
  // (Words on many lines measured once.)
  var wordsOf = dict()
  function wordsSize(text) {
    if (wordsOf[text]) return wordsOf[text]
    var wl = wrap(text, measureText, 150)
    var ww = 0
    wl.forEach(function(l) { ww = Math.max(ww, measureText(l)) })
    return (wordsOf[text] = { w: Math.round(ww + 14), h: Math.round(wl.length * (lineH - 2) + 6), lines: wl })
  }
  edges.forEach(function(e, k) {
    var a = e.from
    var b = e.to
    if (a === b) { chains.push({ edge: e, path: [a, b], self: true }); return }
    var ra = rank[a]
    var rb = rank[b]
    var lo = Math.min(ra, rb)
    var hi = Math.max(ra, rb)
    var path = [ra <= rb ? a : b]
    if (routed[k]) {
      var group = commonGroup(groupOfNode[a], groupOfNode[b])
      for (var r = lo + 1; r < hi; r++) {
        var dummyId = "\u0000" + k + ":" + r
        var words = e.label && r === Math.floor((lo + hi) / 2)
        addTo(r, { id: dummyId, real: false, label: words, group: group })
        if (words) {
          var size = wordsSize(e.label)
          sizes[dummyId] = { w: size.w, h: size.h, lines: size.lines }
        } else sizes[dummyId] = { w: 8, h: 8, lines: [] }
        path.push(dummyId)
      }
    }
    path.push(ra <= rb ? b : a)
    chains.push({ edge: e, path: ra <= rb ? path : path.slice().reverse(), flipped: ra > rb, labelOn: e.label && path.length > 2 ? path[Math.floor(path.length / 2)] : "" })
  })
  // (A rank only a straight line went through: gone.)
  layers = layers.filter(function(l) { return l.length })
  var rankOf = dict()
  layers.forEach(function(l, r) { l.forEach(function(item) { rankOf[item.id] = r }) })

  // The order across each rank: by where the nodes they're joined to are
  // (several sweeps down and up), each group kept together.
  var neighbors = dict()
  function link(a, b) {
    (neighbors[a] = neighbors[a] || { up: [], down: [] })
    ;(neighbors[b] = neighbors[b] || { up: [], down: [] })
    neighbors[a].down.push(b)
    neighbors[b].up.push(a)
  }
  chains.forEach(function(c) {
    if (c.self) return
    for (var i = 0; i + 1 < c.path.length; i++) {
      var p = c.path[i]
      var q = c.path[i + 1]
      if (rankOf[p] < rankOf[q]) link(p, q)
      else link(q, p)
    }
  })
  // (Each one's neighbors, and the outermost group it's in, kept on it.)
  var order = dict()
  layers.forEach(function(layer) {
    layer.forEach(function(item, i) {
      var nb = neighbors[item.id]
      item.up = nb ? nb.up : []
      item.down = nb ? nb.down : []
      item.top = (item.group || "").split("/")[0]
      order[item.id] = i
    })
  })
  function sweep(down) {
    var from = down ? 1 : layers.length - 2
    var to = down ? layers.length : -1
    for (var r = from; r !== to; r += down ? 1 : -1) {
      var layer = layers[r]
      for (var i = 0; i < layer.length; i++) {
        var item = layer[i]
        var nb = down ? item.up : item.down
        var sum = 0
        for (var j = 0; j < nb.length; j++) sum += order[nb[j]]
        item.key = nb.length ? sum / nb.length : order[item.id]
      }
      groupSort(layer)
      for (var k = 0; k < layer.length; k++) order[layer[k].id] = k
    }
  }
  // (Each group's members side by side, where the group's average is: each
  // group's worked out once, before they're sorted.)
  function groupSort(layer) {
    var sum = dict()
    var count = dict()
    var i
    for (i = 0; i < layer.length; i++) {
      var top = layer[i].top
      if (!top) continue
      sum[top] = (sum[top] || 0) + layer[i].key
      count[top] = (count[top] || 0) + 1
    }
    for (i = 0; i < layer.length; i++) layer[i].groupKey = layer[i].top ? sum[layer[i].top] / count[layer[i].top] + 0.0001 : layer[i].key
    layer.sort(function(a, b) {
      if (a.groupKey !== b.groupKey) return a.groupKey - b.groupKey
      return a.key - b.key
    })
  }
  var best = null
  var bestCross = Infinity
  for (var it = 0; it < 8; it++) {
    sweep(it % 2 === 0)
    var c = crossings(layers, order)
    if (c < bestCross) {
      bestCross = c
      best = layers.map(function(l) { return l.map(function(x) { return x.id }) })
    }
    if (c === 0) break
  }
  if (best) {
    var itemOf = dict()
    layers.forEach(function(l) { l.forEach(function(x) { itemOf[x.id] = x }) })
    layers = best.map(function(l) { return l.map(function(id) { return itemOf[id] }) })
    layers.forEach(function(l) { l.forEach(function(x, i) { order[x.id] = i }) })
  }

  // Across: side by side in order, then lined up with what it's joined to:
  // passes down (each under what leads to it, so a chain is straight) and up
  // (each over what it leads to, so a parent is in the middle of its
  // children), ending with one up; never closer to the next than the gap.
  var across = dict()
  layers.forEach(function(layer) {
    var x = 0
    layer.forEach(function(item, i) {
      var w = breadth(item.id)
      if (i > 0) x += gapBetween(layer[i - 1], item)
      across[item.id] = x + w / 2
      x += w
    })
  })
  function gapBetween(a, b) {
    var base = a.real && b.real ? GAP_X : a.real || b.real ? GAP_X * 0.6 : 14
    return a.group === b.group ? base : base + 18
  }
  // (Half of each one's breadth, and the gap before it, the same every pass.)
  layers.forEach(function(layer) {
    layer.forEach(function(item, i) {
      item.half = breadth(item.id) / 2
      item.gap = i > 0 ? gapBetween(layer[i - 1], item) : 0
    })
  })
  for (var round = 0; round < 12; round++) {
    var down = round % 2 === 0
    for (var r2 = 0; r2 < layers.length; r2++) {
      var layer2 = layers[down ? r2 : layers.length - 1 - r2]
      var want = []
      for (var i2 = 0; i2 < layer2.length; i2++) {
        var nb2 = down ? layer2[i2].up : layer2[i2].down
        var sum2 = 0
        for (var j2 = 0; j2 < nb2.length; j2++) sum2 += across[nb2[j2]]
        want.push(nb2.length ? sum2 / nb2.length : across[layer2[i2].id])
      }
      place(layer2, want)
    }
  }
  function place(layer, want) {
    // Left to right, then right to left, as near what each wants as it can.
    var pos = want.slice()
    for (var i = 1; i < layer.length; i++) {
      var min = pos[i - 1] + layer[i - 1].half + layer[i].gap + layer[i].half
      if (pos[i] < min) pos[i] = min
    }
    for (var j = layer.length - 2; j >= 0; j--) {
      var max = pos[j + 1] - layer[j + 1].half - layer[j + 1].gap - layer[j].half
      if (pos[j] > max) pos[j] = max
    }
    for (var k = 0; k < layer.length; k++) across[layer[k].id] = pos[k]
    for (var k2 = 1; k2 < layer.length; k2++) {
      var min2 = across[layer[k2 - 1].id] + layer[k2 - 1].half + layer[k2].gap + layer[k2].half
      if (across[layer[k2].id] < min2) across[layer[k2].id] = min2
    }
  }

  // Along: rank after rank, each as deep as its deepest node.
  var along = dict()
  var at = 0
  var rankDepth = []
  layers.forEach(function(layer, r) {
    var deep = 8
    layer.forEach(function(item) { if (item.real || item.label) deep = Math.max(deep, depthOf(item.id)) })
    rankDepth[r] = deep
    layer.forEach(function(item) { along[item.id] = at + deep / 2 })
    at += deep + GAP_RANK
  })

  // Everything moved so the leftmost and topmost are at the padding; then
  // turned for the direction.
  var minA = Infinity
  ids.forEach(function(id) { minA = Math.min(minA, across[id] - breadth(id) / 2) })
  layers.forEach(function(l) { l.forEach(function(x) { if (!x.real) minA = Math.min(minA, across[x.id] - breadth(x.id) / 2) }) })
  var groupRoom = groups.deepest * 16
  function point(id) {
    var a = across[id] - minA + PAD + groupRoom
    var b = along[id] + PAD + groupRoom + (groups.list.length ? 14 : 0)
    return vertical ? { x: a, y: b } : { x: b, y: a }
  }
  var out = { nodes: dict(), edges: [], groups: [], w: 0, h: 0 }
  nodes.forEach(function(n) {
    var c = point(n.id)
    var s = sizes[n.id]
    out.nodes[n.id] = { x: c.x - s.w / 2, y: c.y - s.h / 2, w: s.w, h: s.h, lines: s.lines, shape: n.shape, icon: n.icon, label: n.label }
    if (n.paint) out.nodes[n.id].paint = n.paint
  })
  // Flipped: BT and RL.
  var maxX = 0
  var maxY = 0
  Object.keys(out.nodes).forEach(function(id) {
    var b = out.nodes[id]
    maxX = Math.max(maxX, b.x + b.w)
    maxY = Math.max(maxY, b.y + b.h)
  })

  // The lines: from the side of one box to the side of the other, through
  // their points between.
  chains.forEach(function(c) {
    var e = c.edge
    var pts
    if (c.self) {
      var b = out.nodes[e.from]
      pts = [{ x: b.x + b.w, y: b.y + b.h * 0.35 }, { x: b.x + b.w + 22, y: b.y + b.h * 0.2 }, { x: b.x + b.w + 22, y: b.y + b.h * 0.8 }, { x: b.x + b.w, y: b.y + b.h * 0.65 }]
    } else {
      pts = c.path.map(function(id) {
        if (out.nodes[id]) { var bb = out.nodes[id]; return { x: bb.x + bb.w / 2, y: bb.y + bb.h / 2 } }
        return point(id)
      })
      // (A chain's path runs from where the line starts to where it ends,
      // up the page too: its arrowhead at its end.)
      pts[0] = edgePoint(out.nodes[c.path[0]], pts[1])
      pts[pts.length - 1] = edgePoint(out.nodes[c.path[c.path.length - 1]], pts[pts.length - 2])
    }
    var labelAt = null
    var labelLines = []
    if (e.label) {
      if (c.labelOn) { labelAt = point(c.labelOn); labelLines = sizes[c.labelOn].lines }
      else { labelAt = midpoint(pts); labelLines = [e.label] }
    }
    out.edges.push({ from: e.from, to: e.to, points: pts, label: e.label, labelLines: labelLines, labelAt: labelAt, style: e.style, arrowStart: e.arrowStart, arrowEnd: e.arrowEnd })
    if (e.paint) out.edges[out.edges.length - 1].paint = e.paint
    pts.forEach(function(p) { maxX = Math.max(maxX, p.x); maxY = Math.max(maxY, p.y) })
  })

  // Groups: round what's in them (and the groups in them), the innermost
  // first, each then taken in by the group it's in.
  var reach = dict()
  function takeIn(gid, x0, y0, x1, y1) {
    var r = reach[gid] || (reach[gid] = { x0: Infinity, y0: Infinity, x1: -Infinity, y1: -Infinity })
    r.x0 = Math.min(r.x0, x0); r.y0 = Math.min(r.y0, y0); r.x1 = Math.max(r.x1, x1); r.y1 = Math.max(r.y1, y1)
  }
  nodes.forEach(function(n) {
    if (!n.group || !groups.byId[n.group]) return
    var b = out.nodes[n.id]
    takeIn(n.group, b.x, b.y, b.x + b.w, b.y + b.h)
  })
  var boxes = dict()
  groups.list.slice().sort(function(a, b) { return b.depth - a.depth }).forEach(function(t) {
    var r = reach[t.id]
    if (!r) return
    var pad = 14
    var box = { x: r.x0 - pad, y: r.y0 - pad - 18, w: r.x1 - r.x0 + pad * 2, h: r.y1 - r.y0 + pad * 2 + 18 }
    // As wide as its name, at least (wider round the middle of what's in it).
    var nameW = t.group.label ? measureText(t.group.label) * 0.92 + 24 : 0
    if (nameW > box.w) { box.x -= (nameW - box.w) / 2; box.w = nameW }
    boxes[t.id] = box
    if (t.up) takeIn(t.up, box.x, box.y, box.x + box.w, box.y + box.h)
  })
  groups.list.forEach(function(t) {
    var b = boxes[t.id]
    if (!b) return
    out.groups.push({ id: t.id, label: t.group.label, x: b.x, y: b.y, w: b.w, h: b.h, depth: t.depth })
    if (t.group.paint) out.groups[out.groups.length - 1].paint = t.group.paint
    maxX = Math.max(maxX, b.x + b.w)
    maxY = Math.max(maxY, b.y + b.h)
  })
  // (Outer groups first, so inner ones are drawn over them.)
  out.groups.sort(function(a, b) { return a.depth - b.depth })

  if (g.direction === "BT" || g.direction === "RL") {
    var flipY = g.direction === "BT"
    var W = maxX + PAD
    var H = maxY + PAD
    Object.keys(out.nodes).forEach(function(id) {
      var b = out.nodes[id]
      if (flipY) b.y = H - b.y - b.h
      else b.x = W - b.x - b.w
    })
    out.edges.forEach(function(e) {
      e.points = e.points.map(function(p) { return flipY ? { x: p.x, y: H - p.y } : { x: W - p.x, y: p.y } })
      if (e.labelAt) e.labelAt = flipY ? { x: e.labelAt.x, y: H - e.labelAt.y } : { x: W - e.labelAt.x, y: e.labelAt.y }
    })
    out.groups.forEach(function(b) {
      if (flipY) b.y = H - b.y - b.h
      else b.x = W - b.x - b.w
    })
  }
  out.w = Math.ceil(maxX + PAD)
  out.h = Math.ceil(maxY + PAD)
  return out
}

// A label in lines no wider than `max` (px), its words kept whole.
function wrap(text, measure, max) {
  var out = []
  String(text || "").split("\n").forEach(function(para) {
    var words = para.split(/\s+/).filter(function(w) { return w })
    var line = ""
    words.forEach(function(w) {
      var next = line ? line + " " + w : w
      if (line && measure(next) > max) { out.push(line); line = w }
      else line = next
    })
    out.push(line)
  })
  return out.length ? out : [""]
}

// The arrows that go back round a loop (found walking from each start).
function backEdges(ids, edges) {
  var state = dict()
  var back = {}
  var out = dict()
  // (Where an arrow from another comes in.)
  var into = dict()
  edges.forEach(function(e, k) {
    (out[e.from] = out[e.from] || []).push(k)
    if (e.from !== e.to) into[e.to] = true
  })
  function visit(id) {
    state[id] = 1
    ;(out[id] || []).forEach(function(k) {
      var to = edges[k].to
      if (state[to] === 1) back[k] = true
      else if (!state[to]) visit(to)
    })
    state[id] = 2
  }
  var starts = ids.filter(function(id) { return !into[id] })
  starts.concat(ids).forEach(function(id) { if (!state[id]) visit(id) })
  return back
}

// How many lines cross between ranks, each rank in its order (`order` of
// each is where it is in its rank): two cross when one starts left of the
// other and ends right of it. Going along a rank left to right, each line
// crosses those from further left that end further right: counted as it
// goes, in a Fenwick tree of where they end (quick, however many lines).
function crossings(layers, order) {
  var total = 0
  for (var r = 0; r + 1 < layers.length; r++) {
    var layer = layers[r]
    var last = -1
    var i, j, x
    for (i = 0; i < layer.length; i++) for (j = 0; j < layer[i].down.length; j++) last = Math.max(last, order[layer[i].down[j]])
    if (last < 0) continue
    var tree = []
    for (x = 0; x <= last + 1; x++) tree.push(0)
    var counted = 0
    for (i = 0; i < layer.length; i++) {
      var ends = layer[i].down
      // (Those from the same one don't cross: all of them counted first.)
      for (j = 0; j < ends.length; j++) {
        var notRight = 0
        for (x = order[ends[j]] + 1; x > 0; x -= x & -x) notRight += tree[x]
        total += counted - notRight
      }
      for (j = 0; j < ends.length; j++) {
        for (x = order[ends[j]] + 1; x < tree.length; x += x & -x) tree[x]++
        counted++
      }
    }
  }
  return total
}

// The groups, each id once (its first), at most MAX_GROUPS: { list, byId,
// deepest }, each { id, group, up, path, depth }: `up` the group it's in
// ("" for none), `path` the groups it's in and itself, outermost first
// ("a/b"), `depth` how many it's in; `deepest`, how many deep the deepest
// goes. What a group's in is followed out MAX_DEPTH at most, and stops at
// one already passed: a group written inside itself isn't in itself.
function groupTree(g) {
  var byId = dict()
  var list = []
  ;(g.groups || []).forEach(function(gr) {
    if (!gr || !gr.id || byId[gr.id] || list.length >= MAX_GROUPS) return
    byId[gr.id] = { id: gr.id, group: gr }
    list.push(byId[gr.id])
  })
  var deepest = 0
  list.forEach(function(t) {
    var path = []
    var passed = dict()
    var cur = t.id
    while (cur && byId[cur] && !passed[cur] && path.length < MAX_DEPTH) {
      passed[cur] = true
      path.unshift(cur)
      cur = byId[cur].group.parent || ""
    }
    t.path = path.join("/")
    t.depth = path.length - 1
    t.up = path.length > 1 ? path[path.length - 2] : ""
    deepest = Math.max(deepest, path.length)
  })
  return { list: list, byId: byId, deepest: deepest }
}

function commonGroup(a, b) {
  var pa = a ? a.split("/") : []
  var pb = b ? b.split("/") : []
  var out = []
  for (var i = 0; i < Math.min(pa.length, pb.length) && pa[i] === pb[i]; i++) out.push(pa[i])
  return out.join("/")
}

// Where a line from a box's middle toward `to` leaves the box.
function edgePoint(box, to) {
  var cx = box.x + box.w / 2
  var cy = box.y + box.h / 2
  var dx = to.x - cx
  var dy = to.y - cy
  if (dx === 0 && dy === 0) return { x: cx, y: cy }
  var hw = box.w / 2
  var hh = box.h / 2
  var t
  if (box.shape === "diamond") t = 1 / (Math.abs(dx) / hw + Math.abs(dy) / hh)
  else if (box.shape === "circle") t = Math.min(hw, hh) / Math.sqrt(dx * dx + dy * dy)
  else t = Math.min(hw / Math.max(1e-6, Math.abs(dx)), hh / Math.max(1e-6, Math.abs(dy)))
  return { x: cx + dx * t, y: cy + dy * t }
}

function midpoint(pts) {
  var total = 0
  for (var i = 1; i < pts.length; i++) total += Math.hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
  var half = total / 2
  for (var j = 1; j < pts.length; j++) {
    var seg = Math.hypot(pts[j].x - pts[j - 1].x, pts[j].y - pts[j - 1].y)
    if (half <= seg && seg > 0) {
      var t = half / seg
      return { x: pts[j - 1].x + (pts[j].x - pts[j - 1].x) * t, y: pts[j - 1].y + (pts[j].y - pts[j - 1].y) * t }
    }
    half -= seg
  }
  return pts[0] || { x: 0, y: 0 }
}

// ---- drawing it -------------------------------------------------------------------------------

// Each icon's glyph in the icon font (Material Design, as Nerd Fonts has it).
var GLYPHS = {
  server: "\u{f048b}", serverNetwork: "\u{f048d}", database: "\u{f01bc}", cloud: "\u{f015f}", laptop: "\u{f0322}",
  desktop: "\u{f0aab}", phone: "\u{f011c}", user: "\u{f0004}", users: "\u{f0849}", web: "\u{f059f}", lan: "\u{f0317}",
  wifi: "\u{f05a9}", router: "\u{f1087}", firewall: "\u{f1a11}", shield: "\u{f0498}", lock: "\u{f033e}", key: "\u{f0306}",
  disk: "\u{f02ca}", nas: "\u{f08f3}", printer: "\u{f042a}", docker: "\u{f0868}", kubernetes: "\u{f10fe}", mail: "\u{f01ee}",
  code: "\u{f0169}", api: "\u{f109b}", gear: "\u{f0493}", queue: "\u{f0328}", file: "\u{f0214}", folder: "\u{f024b}",
  bolt: "\u{f140b}", chart: "\u{f0128}", search: "\u{f0349}", card: "\u{f0fef}", cart: "\u{f0110}", clock: "\u{f0150}",
  bell: "\u{f009a}", home: "\u{f02dc}", building: "\u{f0991}", check: "\u{f012c}", cross: "\u{f0156}", question: "\u{f02d7}"
}

function glyph(icon) { return Object.prototype.hasOwnProperty.call(GLYPHS, icon) ? GLYPHS[icon] : "" }

function num(v) { return Math.round(v * 10) / 10 }

// A node's outline, w by h, as an SVG path (for a Shape's PathSvg).
function shapePath(shape, w, h) {
  var W = num(w), H = num(h)
  function rounded(r) {
    r = num(Math.min(r, w / 2, h / 2))
    var a = " A " + r + " " + r + " 0 0 1 "
    return "M " + r + " 0 H " + num(w - r) + a + W + " " + r + " V " + num(h - r) + a + num(w - r) + " " + H
      + " H " + r + a + "0 " + num(h - r) + " V " + r + a + r + " 0 Z"
  }
  var s = 12
  switch (shape) {
  case "rounded": return rounded(10)
  case "stadium": return rounded(h / 2)
  case "subroutine": return rounded(3)
  case "cylinder":
    var ry = 7
    return "M 0 " + ry + " A " + num(w / 2) + " " + ry + " 0 0 1 " + W + " " + ry + " V " + num(h - ry) + " A " + num(w / 2) + " " + ry + " 0 0 1 0 " + num(h - ry) + " Z"
  case "circle": return "M 0 " + num(h / 2) + " A " + num(w / 2) + " " + num(h / 2) + " 0 1 1 " + W + " " + num(h / 2) + " A " + num(w / 2) + " " + num(h / 2) + " 0 1 1 0 " + num(h / 2) + " Z"
  case "diamond": return "M " + num(w / 2) + " 0 L " + W + " " + num(h / 2) + " L " + num(w / 2) + " " + H + " L 0 " + num(h / 2) + " Z"
  case "hexagon": return "M " + s + " 0 L " + num(w - s) + " 0 L " + W + " " + num(h / 2) + " L " + num(w - s) + " " + H + " L " + s + " " + H + " L 0 " + num(h / 2) + " Z"
  case "lean-right": return "M " + s + " 0 L " + W + " 0 L " + num(w - s) + " " + H + " L 0 " + H + " Z"
  case "lean-left": return "M 0 0 L " + num(w - s) + " 0 L " + W + " " + H + " L " + s + " " + H + " Z"
  case "trapezoid": return "M " + s + " 0 L " + num(w - s) + " 0 L " + W + " " + H + " L 0 " + H + " Z"
  case "trapezoid-alt": return "M 0 0 L " + W + " 0 L " + num(w - s) + " " + H + " L " + s + " " + H + " Z"
  case "flag": return "M 0 0 L " + W + " 0 L " + W + " " + H + " L 0 " + H + " L " + s + " " + num(h / 2) + " Z"
  // (A group, round what's in it.)
  case "group": return rounded(8)
  default: return rounded(4)
  }
}

// The lines inside a shape, drawn over its color (not filled): a
// subroutine's sides, the near edge of a cylinder's top. "" for none.
function shapeLines(shape, w, h) {
  var W = num(w), H = num(h)
  if (shape === "subroutine") return "M 8 0 V " + H + " M " + num(w - 8) + " 0 V " + H
  if (shape === "cylinder") return "M 0 7 A " + num(w / 2) + " 7 0 0 0 " + W + " 7"
  return ""
}

// A line through its points, its corners rounded off; stopped short of an
// arrowhead (`cutEnd`, `cutStart` px) so the head isn't drawn over.
function edgePath(points, cutStart, cutEnd) {
  var p = points.map(function(q) { return { x: q.x, y: q.y } })
  if (p.length < 2) return ""
  function cut(a, b, by) {
    var d = Math.hypot(b.x - a.x, b.y - a.y)
    if (!by || d <= by) return b
    return { x: b.x - (b.x - a.x) * by / d, y: b.y - (b.y - a.y) * by / d }
  }
  p[p.length - 1] = cut(p[p.length - 2], p[p.length - 1], cutEnd)
  p[0] = cut(p[1], p[0], cutStart)
  var out = "M " + num(p[0].x) + " " + num(p[0].y)
  if (p.length === 2) return out + " L " + num(p[1].x) + " " + num(p[1].y)
  for (var i = 1; i < p.length - 1; i++) {
    var mx = (p[i].x + p[i + 1].x) / 2
    var my = (p[i].y + p[i + 1].y) / 2
    if (i === p.length - 2) out += " Q " + num(p[i].x) + " " + num(p[i].y) + " " + num(p[i + 1].x) + " " + num(p[i + 1].y)
    else out += " Q " + num(p[i].x) + " " + num(p[i].y) + " " + num(mx) + " " + num(my)
  }
  return out
}

// An arrowhead (filled), a circle or a cross where a line ends, pointing
// the way its last stretch goes: an SVG path, or "".
function endPath(points, atStart, kind) {
  if (!kind || points.length < 2) return ""
  var tip = atStart ? points[0] : points[points.length - 1]
  var from = atStart ? points[1] : points[points.length - 2]
  var d = Math.hypot(tip.x - from.x, tip.y - from.y) || 1
  var ux = (tip.x - from.x) / d
  var uy = (tip.y - from.y) / d
  var len = 9
  var half = 4
  if (kind === "arrow") {
    var bx = tip.x - ux * len
    var by = tip.y - uy * len
    return "M " + num(tip.x) + " " + num(tip.y) + " L " + num(bx - uy * half) + " " + num(by + ux * half) + " L " + num(bx + uy * half) + " " + num(by - ux * half) + " Z"
  }
  if (kind === "circle") {
    var cx = tip.x - ux * 4.5
    var cy = tip.y - uy * 4.5
    return "M " + num(cx - 4) + " " + num(cy) + " A 4 4 0 1 1 " + num(cx + 4) + " " + num(cy) + " A 4 4 0 1 1 " + num(cx - 4) + " " + num(cy) + " Z"
  }
  if (kind === "cross") {
    var x0 = tip.x - ux * 6
    var y0 = tip.y - uy * 6
    return "M " + num(x0 - 4) + " " + num(y0 - 4) + " L " + num(x0 + 4) + " " + num(y0 + 4) + " M " + num(x0 - 4) + " " + num(y0 + 4) + " L " + num(x0 + 4) + " " + num(y0 - 4)
  }
  return ""
}

// How far short of its end a line stops for what's drawn there.
function cutFor(kind) { return kind === "arrow" ? 8 : kind === "circle" ? 8.5 : 0 }

// ---- what the "/" menu starts with ----------------------------------------------------------

var STARTERS = {
  diagram: "flowchart TD\n  start([Start]) --> idea[Write down the idea]\n  idea --> check{Worth doing?}\n  check -->|Yes| plan[Plan it]\n  check -->|No| park[Park it]\n  plan --> done([Done])",
  decision: "flowchart TD\n  q1{Is the server reachable?}\n  q1 -->|No| a1[Check the network and DNS]\n  q1 -->|Yes| q2{Is the service running?}\n  q2 -->|No| a2[Restart it and read its logs]\n  q2 -->|Yes| q3{Errors in the logs?}\n  q3 -->|Yes| a3[Fix what they say]\n  q3 -->|No| a4([It's working])",
  network: "flowchart LR\n  net((fa:fa-globe Internet)) --- fw[fa:fa-fire Firewall]\n  fw --- rt[fa:fa-router Router]\n  rt --- sw[fa:fa-network-wired Switch]\n  subgraph LAN [Office LAN 192.168.1.0/24]\n    sw --- pc[fa:fa-desktop Desktop]\n    sw --- lap[fa:fa-laptop Laptop]\n    sw --- nas[(fa:fa-hdd NAS)]\n    sw --- ap[fa:fa-wifi Access point]\n  end\n  ap -.- phone[fa:fa-mobile Phone]",
  system: "flowchart LR\n  user([fa:fa-user User]) -->|HTTPS| lb[Load balancer]\n  subgraph App [Application]\n    lb --> api1[fa:fa-server API]\n    lb --> api2[fa:fa-server API]\n  end\n  api1 & api2 -->|SQL| db[(fa:fa-database Postgres)]\n  api1 & api2 -.->|jobs| q[[fa:fa-layer-group Queue]]\n  q --> worker[fa:fa-cogs Worker]\n  worker --> db"
}
