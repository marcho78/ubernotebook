// Docs.js - how Pages look and what you can put on them: type sizes and
// spacing for each kind of block, the colors blocks and text can have (as
// Notion has them, for light and dark pages), the commands in the "/" menu,
// the emoji a page can have as its icon, and the covers.
//
// Colors a person picks for text are stored as the light-page color and
// shown as its dark twin on a dark page (as Papers.js does for inks).
//
// Shared by the pages view (app/Doc*.qml) and tests/workspace.test.cjs, so
// keep it plain JavaScript with no QML or Node APIs.
.pragma library

// ---- type ------------------------------------------------------------------------

// For each kind of block: its text size (px, at the normal text size), line
// height (times the size), and the space above and below it.
var STYLES = {
  p:       { size: 16, lh: 1.5, above: 2, below: 2 },
  h1:      { size: 30, lh: 1.3, above: 26, below: 4, weight: 700 },
  h2:      { size: 24, lh: 1.3, above: 18, below: 3, weight: 700 },
  h3:      { size: 20, lh: 1.3, above: 12, below: 2, weight: 600 },
  bullet:  { size: 16, lh: 1.5, above: 1, below: 1 },
  number:  { size: 16, lh: 1.5, above: 1, below: 1 },
  check:   { size: 16, lh: 1.5, above: 1, below: 1 },
  toggle:  { size: 16, lh: 1.5, above: 1, below: 1 },
  quote:   { size: 18, lh: 1.5, above: 4, below: 4 },
  callout: { size: 16, lh: 1.5, above: 4, below: 4 },
  code:    { size: 14, lh: 1.55, above: 4, below: 4, mono: true },
  page:    { size: 16, lh: 1.5, above: 1, below: 1 },
  link:    { size: 16, lh: 1.5, above: 1, below: 1 },
  toc:     { size: 14, lh: 1.6, above: 4, below: 4 },
  divider: { size: 16, lh: 1.0, above: 6, below: 6 },
  image:   { size: 16, lh: 1.5, above: 6, below: 6 },
  mindmap: { size: 15, lh: 1.4, above: 10, below: 10 },
  table:   { size: 15, lh: 1.45, above: 8, below: 8 },
  habit:   { size: 16, lh: 1.5, above: 3, below: 3 },
  calendar: { size: 15, lh: 1.5, above: 8, below: 8 }
}

var FONTS = [
  { id: "sans", label: "Default", families: ["Adwaita Sans", "Inter", "Noto Sans"] },
  { id: "serif", label: "Serif", families: ["Lora", "Noto Serif"] },
  { id: "mono", label: "Mono", families: ["iA Writer Mono S", "JetBrainsMono Nerd Font", "Noto Sans Mono"] }
]

// { size, weight, mono, lineHeight, above, below } for a kind of block, in
// small text (14 px) or not (16 px).
function typeStyle(type, small) {
  var s = STYLES[type] || STYLES.p
  var scale = small ? 0.875 : 1
  var size = Math.round(s.size * scale)
  return {
    size: size,
    weight: s.weight || 400,
    mono: s.mono === true,
    lineHeight: Math.round(size * s.lh),
    above: Math.round(s.above * scale),
    below: Math.round(s.below * scale)
  }
}

function font(id) {
  for (var i = 0; i < FONTS.length; i++) if (FONTS[i].id === id) return FONTS[i]
  return FONTS[0]
}

// ---- colors ------------------------------------------------------------------------

// Text and background colors, [light page, dark page].
var COLORS = [
  { id: "gray", label: "Gray", text: ["#787774", "#9b9b9b"], background: ["#f1f1ef", "#2f2f2f"] },
  { id: "brown", label: "Brown", text: ["#9f6b53", "#ba856f"], background: ["#f4eeee", "#4a3228"] },
  { id: "orange", label: "Orange", text: ["#d9730d", "#c77d48"], background: ["#fbecdd", "#5c3b23"] },
  { id: "yellow", label: "Yellow", text: ["#cb912f", "#ca9849"], background: ["#fbf3db", "#564328"] },
  { id: "green", label: "Green", text: ["#448361", "#529e72"], background: ["#edf3ec", "#243d30"] },
  { id: "blue", label: "Blue", text: ["#337ea9", "#5e87c9"], background: ["#e7f3f8", "#143a4e"] },
  { id: "purple", label: "Purple", text: ["#9065b0", "#9d68d3"], background: ["#f4f0f7", "#3c2d49"] },
  { id: "pink", label: "Pink", text: ["#c14c8a", "#d15796"], background: ["#f9eef3", "#4e2c3c"] },
  { id: "red", label: "Red", text: ["#d44c47", "#df5452"], background: ["#fdebec", "#522e2a"] }
]

function colorEntry(name) {
  for (var i = 0; i < COLORS.length; i++) if (COLORS[i].id === name) return COLORS[i]
  return null
}

// A block's color ("blue", "blue_background"), resolved for a light or dark
// page: { text, background } ("" where it has none).
function blockColors(value, dark) {
  var v = String(value || "")
  var bg = /_background$/.test(v)
  var c = colorEntry(v.replace(/_background$/, ""))
  if (!c) return { text: "", background: "" }
  return bg ? { text: "", background: c.background[dark ? 1 : 0] } : { text: c.text[dark ? 1 : 0], background: "" }
}

// The background a callout has when it has no color of its own.
function calloutBackground(dark) {
  return dark ? "#2a2a2a" : "#f1f1ef"
}

// light -> dark, for text colors and backgrounds put on words.
function darkMap() {
  var map = {}
  COLORS.forEach(function(c) {
    map[c.text[0]] = c.text[1]
    map[c.background[0]] = c.background[1]
  })
  return map
}

function lightMap() {
  var map = {}
  COLORS.forEach(function(c) {
    map[c.text[1]] = c.text[0]
    map[c.background[1]] = c.background[0]
  })
  return map
}

// ---- the "/" menu -------------------------------------------------------------------

// What "/" offers. `type` (and `props`) is the block it makes; `action` is
// something else to do; `keys` are more words it's found by.
var COMMANDS = [
  { id: "agent", group: "Agent", label: "Ask agent", hint: "Your default coding agent does it", icon: "agent", action: "agent", keys: "ai assistant claude codex gemini opencode llm help write" },
  { id: "p", group: "Basic blocks", label: "Text", hint: "Just start writing", icon: "text", type: "p", keys: "paragraph plain" },
  { id: "h1", group: "Basic blocks", label: "Heading 1", hint: "Big section heading", icon: "h1", type: "h1", keys: "title h1 #" },
  { id: "h2", group: "Basic blocks", label: "Heading 2", hint: "Medium section heading", icon: "h2", type: "h2", keys: "subtitle h2 ##" },
  { id: "h3", group: "Basic blocks", label: "Heading 3", hint: "Small section heading", icon: "h3", type: "h3", keys: "h3 ###" },
  { id: "bullet", group: "Basic blocks", label: "Bulleted list", hint: "A simple bulleted list", icon: "bullets", type: "bullet", keys: "ul unordered -" },
  { id: "number", group: "Basic blocks", label: "Numbered list", hint: "A list with numbers", icon: "numbers", type: "number", keys: "ol ordered 1." },
  { id: "check", group: "Basic blocks", label: "To-do list", hint: "Track tasks with a to-do list", icon: "checks", type: "check", keys: "todo task checkbox []" },
  { id: "toggle", group: "Basic blocks", label: "Toggle list", hint: "Hide what's inside, show it with a click", icon: "toggle", type: "toggle", keys: "collapse fold details >" },
  { id: "th1", group: "Basic blocks", label: "Toggle heading 1", hint: "A big heading that folds", icon: "h1", type: "h1", props: { toggle: true }, keys: "collapse fold" },
  { id: "th2", group: "Basic blocks", label: "Toggle heading 2", hint: "A medium heading that folds", icon: "h2", type: "h2", props: { toggle: true }, keys: "collapse fold" },
  { id: "th3", group: "Basic blocks", label: "Toggle heading 3", hint: "A small heading that folds", icon: "h3", type: "h3", props: { toggle: true }, keys: "collapse fold" },
  { id: "quote", group: "Basic blocks", label: "Quote", hint: "Capture a quote", icon: "quote", type: "quote", keys: "blockquote citation \"" },
  { id: "callout", group: "Basic blocks", label: "Callout", hint: "Make writing stand out", icon: "sticky", type: "callout", props: { icon: "\u{1f4a1}" }, keys: "note info tip warning aside" },
  { id: "divider", group: "Basic blocks", label: "Divider", hint: "Visually divide blocks", icon: "divider", type: "divider", keys: "line separator hr rule ---" },
  { id: "code", group: "Basic blocks", label: "Code", hint: "Capture a code snippet", icon: "code", type: "code", keys: "snippet pre ```" },
  { id: "table", group: "Basic blocks", label: "Table", hint: "Rows and columns, with a header row", icon: "table", type: "table", props: { table: { rows: [["", "", ""], ["", "", ""], ["", "", ""]], header: true } }, keys: "table grid rows columns cells spreadsheet" },
  { id: "habit", group: "Planning", label: "Habit", hint: "A habit, with a circle for each day of the week", icon: "habit", type: "habit", keys: "tracker streak routine week days" },
  { id: "calendar", group: "Planning", label: "Calendar", hint: "A month at a glance: click a date to circle it", icon: "calendarMonth", type: "calendar", keys: "month dates planner" },
  { id: "page", group: "Pages", label: "Page", hint: "A page inside this page", icon: "page", action: "page", keys: "subpage sub-page new document" },
  { id: "link", group: "Pages", label: "Link to page", hint: "Point to a page elsewhere", icon: "link", action: "link", keys: "mention reference goto" },
  { id: "image", group: "Media", label: "Image", hint: "A picture from a file", icon: "image", action: "image", keys: "picture photo png jpg" },
  { id: "mindmap", group: "Advanced", label: "Mind map", hint: "Ideas branching out from one topic", icon: "mindmap", type: "mindmap", props: { outline: "Central topic\n  Main idea\n  Main idea\n  Main idea" }, keys: "mindmap brainstorm map tree ideas diagram" },
  { id: "toc", group: "Advanced", label: "Table of contents", hint: "The headings on this page", icon: "toc", type: "toc", keys: "contents outline index" },
  { id: "cols2", group: "Layout", label: "2 columns", hint: "Two columns side by side", icon: "columns", action: "columns", count: 2, keys: "columns side layout split" },
  { id: "cols3", group: "Layout", label: "3 columns", hint: "Three columns side by side", icon: "columns", action: "columns", count: 3, keys: "columns side layout split" },
  { id: "cols4", group: "Layout", label: "4 columns", hint: "Four columns side by side", icon: "columns", action: "columns", count: 4, keys: "columns side layout split" },
  { id: "cols5", group: "Layout", label: "5 columns", hint: "Five columns side by side", icon: "columns", action: "columns", count: 5, keys: "columns side layout split" },
  { id: "date", group: "Inline", label: "Today", hint: "Today's date", icon: "calendar", action: "date", keys: "date now time" }
]

// Colors in the "/" menu: "/red", "/red background".
function colorCommands() {
  var out = [{ id: "color:", group: "Color", label: "Default", hint: "No color", color: "", keys: "color plain" }]
  COLORS.forEach(function(c) {
    out.push({ id: "color:" + c.id, group: "Color", label: c.label, hint: c.label + " text", color: c.id, keys: "color text" })
  })
  COLORS.forEach(function(c) {
    out.push({ id: "color:" + c.id + "_background", group: "Background", label: c.label + " background", hint: "A " + c.label.toLowerCase() + " background", color: c.id + "_background", keys: "background highlight" })
  })
  return out
}

// The commands matching what's typed after "/", best first (all of them
// for nothing typed; colors only once something is).
function findCommands(query) {
  var q = String(query || "").toLowerCase().trim()
  if (!q) return COMMANDS.slice()
  var out = []
  COMMANDS.concat(colorCommands()).forEach(function(c, i) {
    var label = c.label.toLowerCase()
    var words = (label + " " + (c.keys || "")).toLowerCase()
    var score = label.indexOf(q) === 0 ? 3 : words.split(/\s+/).some(function(w) { return w.indexOf(q) === 0 }) ? 2 : words.indexOf(q) >= 0 ? 1 : 0
    if (score > 0) out.push({ c: c, score: score, i: i })
  })
  out.sort(function(a, b) { return b.score - a.score || a.i - b.i })
  return out.map(function(r) { return r.c })
}

// What a text block can be turned into (the block menu, the toolbar over
// selected words).
var TURN_INTO = [
  { type: "p", label: "Text", icon: "text" },
  { type: "h1", label: "Heading 1", icon: "h1" },
  { type: "h2", label: "Heading 2", icon: "h2" },
  { type: "h3", label: "Heading 3", icon: "h3" },
  { type: "bullet", label: "Bulleted list", icon: "bullets" },
  { type: "number", label: "Numbered list", icon: "numbers" },
  { type: "check", label: "To-do list", icon: "checks" },
  { type: "toggle", label: "Toggle list", icon: "toggle" },
  { type: "h1", toggle: true, label: "Toggle heading 1", icon: "h1" },
  { type: "h2", toggle: true, label: "Toggle heading 2", icon: "h2" },
  { type: "h3", toggle: true, label: "Toggle heading 3", icon: "h3" },
  { type: "quote", label: "Quote", icon: "quote" },
  { type: "callout", label: "Callout", icon: "sticky" },
  { type: "code", label: "Code", icon: "code" },
  { type: "habit", label: "Habit", icon: "habit" }
]

function kindLabel(type, toggle) {
  for (var i = 0; i < TURN_INTO.length; i++) {
    var k = TURN_INTO[i]
    if (k.type === type && !!k.toggle === !!toggle) return k.label
  }
  return type === "page" ? "Page" : type === "link" ? "Link to page" : type === "image" ? "Image" : type === "divider" ? "Divider" : type === "toc" ? "Table of contents" : type === "calendar" ? "Calendar" : type === "mindmap" ? "Mind map" : type === "table" ? "Table" : "Text"
}

// Languages a code block can say it's in.
var LANGUAGES = ["Plain text", "Bash", "C", "C++", "C#", "CSS", "Diff", "Dockerfile", "Go", "HTML", "INI", "Java", "JavaScript", "JSON", "Kotlin", "Lua", "Makefile", "Markdown", "Nix", "PHP", "Python", "QML", "Ruby", "Rust", "SQL", "Swift", "TOML", "TypeScript", "XML", "YAML", "Zig"]

// ---- what an empty block says -------------------------------------------------------

function placeholder(type, focused, toggleHeading) {
  if (type === "h1") return "Heading 1"
  if (type === "h2") return "Heading 2"
  if (type === "h3") return "Heading 3"
  if (type === "toggle") return "Toggle"
  if (!focused) return ""
  if (type === "bullet" || type === "number") return "List"
  if (type === "check") return "To-do"
  if (type === "habit") return "A habit"
  if (type === "quote") return "Empty quote"
  if (type === "callout") return "Type something\u2026"
  if (type === "p") return "Write, or type \u2018/\u2019 for commands"
  return ""
}

// ---- icons and covers -----------------------------------------------------------------

var EMOJI = [
  { label: "Smileys", list: "\u{1f600} \u{1f60a} \u{1f642} \u{1f60e} \u{1f913} \u{1f914} \u{1f929} \u{1f973} \u{1f607} \u{1f970} \u{1f60c} \u{1f634} \u{1f92f} \u{1f624} \u{1f440} \u{1f44b} \u{1f44d} \u{1f64c} \u{1f44f} \u{1f4aa} \u{1f9e0} \u{1f91d}" },
  { label: "Things", list: "\u{1f4c4} \u{1f4dd} \u{1f4d3} \u{1f4d4} \u{1f4d5} \u{1f4d7} \u{1f4d8} \u{1f4d9} \u{1f4da} \u{1f4d6} \u{1f516} \u{1f4cc} \u{1f4ce} \u{1f4c5} \u{1f4c6} \u{1f5d3}\u{fe0f} \u{1f4ca} \u{1f4c8} \u{1f4a1} \u{1f511} \u{1f50d} \u{1f4bb} \u{2328}\u{fe0f} \u{1f4f7} \u{1f3a7} \u{1f4e6} \u{1f381} \u{1f9f0} \u{1f527} \u{1f9ea}" },
  { label: "Nature", list: "\u{1f331} \u{1f33f} \u{1f340} \u{1f335} \u{1f332} \u{1f338} \u{1f33b} \u{1f341} \u{1f30a} \u{1f525} \u{2b50} \u{1f319} \u{2600}\u{fe0f} \u{26a1} \u{1f308} \u{2744}\u{fe0f} \u{1f98a} \u{1f431} \u{1f436} \u{1f989} \u{1f41d} \u{1f98b}" },
  { label: "Food and travel", list: "\u{2615} \u{1f375} \u{1f37d}\u{fe0f} \u{1f34e} \u{1f951} \u{1f35e} \u{1f355} \u{1f370} \u{1f3e0} \u{1f3e2} \u{1f3d6}\u{fe0f} \u{26f0}\u{fe0f} \u{1f5fa}\u{fe0f} \u{2708}\u{fe0f} \u{1f686} \u{1f697} \u{1f6b2} \u{1f680} \u{1f30d} \u{1f9f3}" },
  { label: "Activities", list: "\u{1f3af} \u{1f3c6} \u{1f3a8} \u{1f3b5} \u{1f3ac} \u{1f3ae} \u{1f3b2} \u{26bd} \u{1f3c3} \u{1f9d8} \u{1f4aa} \u{1f393} \u{1f4bc} \u{1f6e0}\u{fe0f} \u{1f9f9} \u{1f6d2}" },
  { label: "Symbols", list: "\u{2705} \u{2611}\u{fe0f} \u{274c} \u{26a0}\u{fe0f} \u{2757} \u{2753} \u{1f4ac} \u{1f4ad} \u{1f4a5} \u{2728} \u{1f4ab} \u{1f3f7}\u{fe0f} \u{1f534} \u{1f7e0} \u{1f7e1} \u{1f7e2} \u{1f535} \u{1f7e3} \u{2764}\u{fe0f} \u{1f499} \u{1f49a} \u{1f49b} \u{1f9e1} \u{1f49c}" }
]

function emojiList() {
  var out = []
  EMOJI.forEach(function(g) { g.list.split(" ").forEach(function(e) { if (e) out.push(e) }) })
  return out
}

// A random one, for "Random" in the icon picker.
function randomEmoji(random) {
  var list = emojiList()
  var r = typeof random === "function" ? random : Math.random
  return list[Math.floor(r() * list.length) % list.length]
}

// The covers: gradients, left to right.
var COVERS = [
  ["#ff9a8b", "#ff6a88", "#ff99ac"],
  ["#a1c4fd", "#c2e9fb"],
  ["#84fab0", "#8fd3f4"],
  ["#fccb90", "#d57eeb"],
  ["#e0c3fc", "#8ec5fc"],
  ["#f6d365", "#fda085"],
  ["#d4fc79", "#96e6a1"],
  ["#2b5876", "#4e4376"],
  ["#0f2027", "#203a43", "#2c5364"],
  ["#ff758c", "#ff7eb3"],
  ["#434343", "#1a1a1a"],
  ["#fdfbfb", "#ebedee"]
]

function coverStops(cover) {
  var m = /^gradient:(\d{1,2})$/.exec(String(cover || ""))
  return m && COVERS[Number(m[1])] ? COVERS[Number(m[1])] : null
}
