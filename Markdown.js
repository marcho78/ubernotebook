// Markdown.js - a page as Markdown, for exporting and copying.
//
// Headings, lists, checklists, quotes, code, dividers and pictures become
// their Markdown; bold, italics, strikethrough, code and links too. Time
// slots are a list with the times in bold, habits a table of the week, a
// calendar a table of the month (with marked days in bold), and tables
// Markdown's tables.
// Highlights are ==marked== (as Obsidian and Typora write them), underlines
// <u>underlined</u>, and sticky notes GitHub's "> [!NOTE]" callouts. Ink
// colors and fonts have no Markdown and are left out.
//
// Shared by the notebook (app/*.qml) and tests/markdown.test.cjs, so keep it
// plain JavaScript with no QML or Node APIs.
.pragma library
.import "Html.js" as Html
.import "Blocks.js" as Blocks
.import "Workspace.js" as Workspace
.import "Table.js" as Table
.import "Sketch.js" as Sketch
.import "Audio.js" as Audio
.import "Meeting.js" as Meeting

// Characters that would otherwise be read as Markdown.
function escapeText(text) {
  return String(text).replace(/([\\`*_\[\]<>~=|])/g, "\\$1")
}

function flags(run) {
  var s = run.style || {}
  return {
    bold: Html.isBold(s),
    italic: Html.isItalic(s),
    strike: Html.hasDecoration(s, "line-through"),
    underline: Html.hasDecoration(s, "underline"),
    code: Html.isCode(s),
    mark: !!s["background-color"]
  }
}

function sameFlags(a, b) {
  return a.bold === b.bold && a.italic === b.italic && a.strike === b.strike && a.underline === b.underline && a.code === b.code && a.mark === b.mark
}

// One block's text as Markdown. Neighbouring runs with the same Markdown are
// joined first, and spaces are kept outside the markers (Markdown doesn't see
// "** bold**" as bold).
function inline(inner) {
  var runs = Html.parse(inner)
  var groups = []
  runs.forEach(function(run) {
    if (run.br) { groups.push({ br: true }); return }
    if (run.img) return
    var f = flags(run)
    var last = groups[groups.length - 1]
    if (last && !last.br && last.href === (run.href || "") && sameFlags(last.flags, f)) last.text += run.text
    else groups.push({ text: run.text, flags: f, href: run.href || "" })
  })
  var out = ""
  groups.forEach(function(g) {
    if (g.br) { out += "\\\n"; return }
    var m = /^(\s*)([\s\S]*?)(\s*)$/.exec(g.text.replace(/\u00a0/g, " "))
    var lead = m[1]
    var core = m[2]
    var trail = m[3]
    if (!core) { out += g.text.replace(/\u00a0/g, " "); return }
    var f = g.flags
    var body
    // A tag is its words, "#idea", as Obsidian and others read them.
    if (Html.isTag(g.href)) { out += lead + core + trail; return }
    if (f.code) {
      var fence = core.indexOf("`") >= 0 ? "``" : "`"
      body = fence + (core.charAt(0) === "`" ? " " : "") + core + (core.charAt(core.length - 1) === "`" ? " " : "") + fence
    } else {
      body = escapeText(core)
    }
    if (f.underline) body = "<u>" + body + "</u>"
    if (f.mark) body = "==" + body + "=="
    if (f.strike) body = "~~" + body + "~~"
    if (f.italic) body = "*" + body + "*"
    if (f.bold) body = "**" + body + "**"
    if (g.href) body = "[" + body + "](" + g.href.replace(/[()\s]/g, function(c) { return encodeURIComponent(c) }) + ")"
    out += lead + body + trail
  })
  return out
}

function plainLines(inner) {
  return Html.plainText(inner).split("\n")
}

var WEEKDAYS = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
var MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]

function tableRow(cells) {
  return "| " + cells.join(" | ") + " |"
}

// Habits, one after another, as one table: a row each, a column a day.
function habitTable(list) {
  var rows = [tableRow(["Habit"].concat(WEEKDAYS)), tableRow(["---"].concat(WEEKDAYS.map(function() { return ":-:" })))]
  list.forEach(function(b) {
    var name = inline(b.html || "").replace(/\\\n/g, " ") || " "
    var days = String(b.days || "").split("").map(function(d) { return d === "1" ? "\u2713" : " " })
    rows.push(tableRow([name].concat(days)))
  })
  return rows.join("\n")
}

// A month, Monday first, its marked days in bold.
function calendarTable(b) {
  var layout = Blocks.monthLayout(b.month)
  var name = MONTHS[Number(String(b.month).slice(5, 7)) - 1] + " " + String(b.month).slice(0, 4)
  var rows = ["**" + name + "**", "", tableRow(WEEKDAYS), tableRow(WEEKDAYS.map(function() { return ":-:" }))]
  for (var w = 0; w < layout.weeks; w++) {
    var cells = []
    for (var c = 0; c < 7; c++) {
      var day = w * 7 + c - layout.offset + 1
      cells.push(day < 1 || day > layout.days ? " " : Blocks.hasMark(b.marks || "", day) ? "**" + day + "**" : String(day))
    }
    rows.push(tableRow(cells))
  }
  return rows.join("\n")
}

// A page's blocks as Markdown. `assetPrefix` is put before pictures' paths.
function fromBlocks(blocks, assetPrefix) {
  var numbers = Blocks.numbering(blocks)
  var out = []
  var prevList = false
  var prefix = assetPrefix || ""
  // Where each depth's text starts, so nested items line up under their parent.
  var indents = [0]
  for (var i = 0; i < blocks.length; i++) {
    var b = blocks[i]
    // Time slots read as a list: no blank lines between them.
    var isList = Blocks.isList(b.type) || b.type === "time"
    var depth = b.indent || 0
    var lead = ""
    if (isList || (b.type === "p" && depth > 0)) {
      indents.length = Math.min(indents.length, depth + 1)
      while (indents.length <= depth) indents.push(indents[indents.length - 1] + 2)
      lead = new Array(indents[depth] + 1).join(" ")
    } else {
      indents = [0]
    }
    var text = Blocks.isText(b.type) ? inline(b.html || "") : ""
    // Markdown only numbers 1, 2, 3; nested a./i. items are numbered by the reader.
    var number = /^\d+\.$/.test(numbers[b.uid] || "") ? numbers[b.uid] : "1."
    var line
    if (b.type === "h1") line = "# " + text
    else if (b.type === "h2") line = "## " + text
    else if (b.type === "h3") line = "### " + text
    else if (b.type === "bullet") line = lead + "- " + text
    else if (b.type === "number") line = lead + number + " " + text
    else if (b.type === "check") line = lead + (b.checked ? "- [x] " : "- [ ] ") + text
    else if (b.type === "quote") line = text.split("\n").map(function(l) { return "> " + l }).join("\n")
    else if (b.type === "callout") line = "> [!NOTE]\n" + text.split("\n").map(function(l) { return "> " + l }).join("\n")
    else if (b.type === "code") line = "```\n" + plainLines(b.html || "").join("\n") + "\n```"
    else if (b.type === "divider") line = "---"
    else if (b.type === "image") line = b.src ? "![](" + prefix + b.src + ")" : ""
    else if (b.type === "time") line = "- " + (b.label ? "**" + escapeText(b.label) + "**" + (text ? " " : "") : "") + text
    else if (b.type === "calendar") line = calendarTable(b)
    else if (b.type === "habit") {
      var run = [b]
      while (i + 1 < blocks.length && blocks[i + 1].type === "habit") run.push(blocks[++i])
      line = habitTable(run)
    }
    else line = lead + text
    if (isList) indents[depth + 1] = indents[depth] + (b.type === "number" ? number.length + 1 : 2)
    if (out.length > 0) out.push(isList && prevList ? "\n" : "\n\n")
    out.push(line)
    prevList = isList
  }
  return out.join("").replace(/\n{3,}/g, "\n\n").trim() + "\n"
}

// A whole page: its title as a heading, then its blocks.
function fromPage(page, assetPrefix) {
  var body = fromBlocks(page.blocks || [], assetPrefix)
  var title = String(page.title || "").trim()
  return (title ? "# " + escapeText(title) + "\n\n" : "") + body
}

// A name for the exported file: "2026-09-30 Meeting notes.md".
function fileName(page, index) {
  var date = String(page.created || "").slice(0, 10)
  var title = String(page.title || Blocks.firstLine(page.blocks || [], 60) || "Page " + (index + 1))
  title = title.replace(/[\/\\:*?"<>|\u0000-\u001f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, 80) || "Page"
  return (date ? date + " " : "") + title + ".md"
}

// ---- Pages ------------------------------------------------------------------------------

// A page in Pages as Markdown: its title, then its blocks, the blocks inside
// a list item or toggle indented under it, inside a quote or callout quoted
// with it. Toggles are list items (as Notion exports them); callouts quotes
// with their icon; pages on it and links links to their files; columns one
// after the other.
// `lookup(id)` -> { title, icon, file } for pages it has or points to.
// `options.sketchFile(blockId)` -> where a sketch's SVG is (written beside
// the Markdown), or "" (it's said to be there); `options.assetPrefix` is put
// before pictures' paths ("assets/...").
function fromDocPage(page, lookup, options) {
  var info = typeof lookup === "function" ? lookup : function() { return null }
  var opts = options || {}
  var blocks = page.blocks || {}

  function indent(text, prefix) {
    return text.split("\n").map(function(l) { return l ? prefix + l : l }).join("\n")
  }
  function quoted(text) {
    return text.split("\n").map(function(l) { return l ? "> " + l : ">" }).join("\n")
  }
  function pageLink(id, arrow) {
    var p = info(id)
    if (!p) return ""
    var label = (p.icon ? p.icon + " " : "") + escapeText(p.title || "Untitled") + (arrow ? " \u2197" : "")
    return p.file ? "[" + label + "](" + p.file + ")" : "**" + label + "**"
  }

  // A run of sibling blocks: list items one under another, the rest apart;
  // habits one after another, a table of the week.
  function list(ids) {
    var out = ""
    var prevList = false
    var n = 0
    ids.forEach(function(id, k) {
      var b = blocks[id]
      if (!b) return
      var prev = k > 0 ? blocks[ids[k - 1]] : null
      if (b.type === "habit" && prev && prev.type === "habit") return
      var isList = b.type === "bullet" || b.type === "number" || b.type === "check" || b.type === "toggle"
      n = b.type === "number" ? n + 1 : 0
      var text = b.type === "habit" ? habitTable(habitRun(ids, k)) : one(b, n)
      if (text === "") return
      if (out) out += isList && prevList ? "\n" : "\n\n"
      out += text
      prevList = isList
    })
    return out
  }

  function one(b, n) {
    var text = Blocks.isText(b.type) ? inline(b.html || "") : ""
    var kids = b.content ? list(b.content) : ""
    // Markdown has no columns: one after the other.
    if (b.type === "columns" || b.type === "column") return kids
    var line
    if (b.type === "h1" || b.type === "h2" || b.type === "h3") line = new Array(Number(b.type.charAt(1)) + 1).join("#") + " " + text
    else if (b.type === "bullet" || b.type === "toggle") line = "- " + text
    else if (b.type === "number") line = n + ". " + text
    else if (b.type === "check") line = (b.checked ? "- [x] " : "- [ ] ") + text
    else if (b.type === "quote") return quoted(text + (kids ? "\n\n" + kids : ""))
    else if (b.type === "callout") return quoted((b.icon ? b.icon + " " : "") + text + (kids ? "\n\n" + kids : ""))
    else if (b.type === "code") line = "```" + (b.lang ? b.lang.toLowerCase().replace(/\s+/g, "") : "") + "\n" + plainLines(b.html || "").join("\n") + "\n```"
    else if (b.type === "divider") line = "---"
    else if (b.type === "image") line = b.src ? "![](" + (opts.assetPrefix || "") + b.src + ")" : ""
    else if (b.type === "page") line = pageLink(b.id, false)
    else if (b.type === "link") line = pageLink(b.target, true)
    else if (b.type === "toc") line = ""
    else if (b.type === "mindmap") line = "```mindmap\n" + (b.outline || "") + "\n```"
    else if (b.type === "table") line = Table.toMarkdown(b.table, inline)
    else if (b.type === "sketch") {
      var file = typeof opts.sketchFile === "function" ? opts.sketchFile(b.id) : ""
      line = file ? "![Sketch](" + file + ")" : "*(A sketch, drawn in Omanote)*"
    }
    else if (b.type === "audio") {
      // A link to the recording, and what was said in it, quoted.
      var au = b.audio || {}
      var head = au.src ? "[\u{1f399}\u{fe0f} Audio note, " + Audio.clock(au.duration) + "](" + (opts.assetPrefix || "") + au.src + ")" : "*(An audio note, not recorded)*"
      line = au.transcript ? head + "\n\n" + quoted(au.transcript) : head
    }
    else if (b.type === "meeting") line = Meeting.toMarkdown(b.meeting)
    else if (b.type === "calendar") line = calendarTable(b)
    else line = text
    if (!kids) return line
    var listy = b.type === "bullet" || b.type === "toggle" || b.type === "check" || b.type === "number"
    return (line ? line + (listy ? "\n" : "\n\n") : "") + indent(kids, b.type === "number" ? "   " : "  ")
  }

  function habitRun(ids, k) {
    var run = []
    for (var j = k; j < ids.length && blocks[ids[j]] && blocks[ids[j]].type === "habit"; j++) run.push(blocks[ids[j]])
    return run
  }

  var title = String(page.title || "").trim()
  var head = title || page.icon ? "# " + (page.icon ? page.icon + " " : "") + escapeText(title || "Untitled") + "\n\n" : ""
  // A project's status and due date as front matter (Obsidian reads it as properties).
  var front = page.project ? "---\nstatus: " + page.project.status + (page.project.due ? "\ndue: " + page.project.due : "") + "\n---\n\n" : ""
  return front + (head + list(page.content || [])).replace(/\n{3,}/g, "\n\n").trim() + "\n"
}
