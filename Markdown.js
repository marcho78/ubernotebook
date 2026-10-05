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
.import "Calendar.js" as Calendar
.import "Dates.js" as Dates
.import "Files.js" as Files
.import "Bookmark.js" as Bookmark
.import "Board.js" as Board
.import "Contacts.js" as Contacts
.import "Email.js" as Email
.import "Equations.js" as Equations
.import "Notes.js" as Notes

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
// `notes` (a page's, in order): footnotes as [^1], their words in it;
// without it, as ^[their words].
function inline(inner, notes) {
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
  var lastHref = ""
  groups.forEach(function(g) {
    var seen = lastHref
    lastHref = g.href || ""
    if (g.br) { out += "\\\n"; return }
    // A footnote: [^n] (or ^[its words]).
    if (Notes.isLink(g.href)) {
      if (seen === g.href) return
      var words = Notes.textOf(g.href)
      if (notes) {
        var n = notes.indexOf(words)
        if (n < 0) { notes.push(words); n = notes.length - 1 }
        out += "[^" + (n + 1) + "]"
      } else out += "^[" + words.replace(/\]/g, ")") + "]"
      return
    }
    // An equation in the line: $its LaTeX$ (once, however it's formatted).
    if (Equations.isLink(g.href)) {
      if (seen === g.href) return
      var tex = Equations.texOf(g.href)
      out += tex.indexOf("$") >= 0 || /\\$/.test(tex) ? "$$" + tex + "$$" : "$" + tex + "$"
      return
    }
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
      // Dollars that would be read back as an equation stay dollars.
      if (body.indexOf("$") >= 0 && Equations.inlineSpans(body).length) body = body.replace(/\$/g, "\\$")
    }
    if (f.underline) body = "<u>" + body + "</u>"
    if (f.mark) body = "==" + body + "=="
    if (f.strike) body = "~~" + body + "~~"
    if (f.italic) body = "*" + body + "*"
    if (f.bold) body = "**" + body + "**"
    // (A link written before Uber Notebook was renamed comes out with its new name.)
    if (g.href) body = "[" + body + "](" + g.href.replace(/^omanote:\/\//, "uber-notebook://").replace(/[()\s]/g, function(c) { return encodeURIComponent(c) }) + ")"
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
  // Its footnotes, in order ([^1], [^2]...), written at its end.
  var notes = []

  function indent(text, prefix) {
    return text.split("\n").map(function(l) { return l ? prefix + l : l }).join("\n")
  }
  // A synced block: its blocks, from its page (when there's a way to read it).
  // (Never the page itself, and only so many in a page: 50, 4 million
  // characters of them; the synced page's own synced blocks just say so.
  // `syncedBudget` ({ chars, max }), shared by many pages written at once
  // (the Markdown copy): past it, a synced block says where it is.)
  var syncedCount = 0
  var syncedChars = 0
  var pass = opts.syncedBudget && typeof opts.syncedBudget === "object" ? opts.syncedBudget : null
  var pastPass = "*(A synced block: open the page in Uber Notebook)*"
  function syncedLines(b) {
    var id = b.data ? b.data.page : ""
    if (!id || id === page.id || syncedCount >= 50 || syncedChars >= 4000000) return "*(A synced block)*"
    if (pass && pass.chars >= pass.max) return pastPass
    var p = typeof opts.syncedPage === "function" ? opts.syncedPage(id) : null
    if (!p) return "*(A synced block)*"
    syncedCount++
    var inner = fromDocPage(p, lookup, { assetPrefix: opts.assetPrefix, calendar: opts.calendar }).replace(/^# .*\n\n?/, "")
    syncedChars += inner.length
    if (pass) pass.chars += inner.length
    if (pass && pass.chars > pass.max) return pastPass
    return syncedChars > 4000000 ? "*(A synced block)*" : inner.trim()
  }

  // A contact card: the person as People has them (opts.contactOf), else
  // their name as it was.
  function contactLines(b) {
    var d = b.data || {}
    if (!d.contact) return "*(A contact card)*"
    var c = typeof opts.contactOf === "function" ? opts.contactOf(d.contact) : null
    return c ? Contacts.toMarkdown(c) : "**" + (d.name || "Someone") + "**"
  }

  // A person's ```contact line: their name as People has it, else as the block does.
  function fencedName(d) {
    var c = typeof opts.contactOf === "function" ? opts.contactOf(d.contact) : null
    return (c ? Contacts.nameOf(c) : "") || d.name || d.contact
  }

  // An agenda (the day's events, as the calendar has them) or an event, as lines.
  function calendarLines(b) {
    var cal = opts.calendar
    var ref = b.calendar || {}
    var now = new Date()
    if (b.type === "event") {
      var ev = cal ? Calendar.byId(cal, ref.id) : null
      return ev ? "\u{1f4c5} " + Calendar.line(Calendar.nextOf(ev, now), now) : "*(An event on the calendar)*"
    }
    var d = ref.day ? Dates.fromIso(ref.day).at : new Date(now.getFullYear(), now.getMonth(), now.getDate())
    var head = "**\u{1f4c5} " + Dates.label(d, false, now) + "**"
    if (!cal) return head
    var list = Calendar.occurrences(cal, d, new Date(d.getFullYear(), d.getMonth(), d.getDate() + 1))
    if (!list.length) return head + "\n\n*(Nothing on the calendar)*"
    return head + "\n\n" + list.map(function(o) { return "- " + Calendar.span(o, d) + ": " + (o.title || "Untitled") + (o.place ? " (" + o.place + ")" : "") }).join("\n")
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
    var text = Blocks.isText(b.type) ? inline(b.html || "", notes) : ""
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
    else if (b.type === "code" && Equations.isLang(b.lang)) line = Equations.fence(Html.plainText(b.html || ""))
    else if (b.type === "code") line = "```" + (b.lang ? b.lang.toLowerCase().replace(/\s+/g, "") : "") + "\n" + plainLines(b.html || "").join("\n") + "\n```"
    else if (b.type === "divider") line = "---"
    else if (b.type === "image") line = b.src ? "![](" + (opts.assetPrefix || "") + b.src + ")" : ""
    else if (opts.fences && b.type === "gallery" && b.data) line = "```gallery\ncolumns: " + b.data.columns + (b.data.height ? "\nheight: " + b.data.height : "") + b.data.images.map(function(x) { return "\n![" + (x.caption || "") + "](" + x.src + ")" }).join("") + "\n```"
    else if (b.type === "gallery") line = (b.data && b.data.images ? b.data.images : []).map(function(x) { return "![" + escapeText(x.caption || "") + "](" + (opts.assetPrefix || "") + x.src + ")" }).join("\n")
    else if (b.type === "page") line = pageLink(b.id, false)
    else if (opts.fences && b.type === "link" && b.target) { var lp = info(b.target); line = "```link\n" + b.target + (lp ? "\n" + (lp.title || "Untitled") : "") + "\n```" }
    else if (b.type === "link") line = pageLink(b.target, true)
    else if (b.type === "toc") line = ""
    else if (b.type === "mindmap") line = "```mindmap\n" + (b.outline || "") + "\n```"
    else if (b.type === "table") line = Table.toMarkdown(b.table, inline)
    else if (b.type === "sketch") {
      var file = typeof opts.sketchFile === "function" ? opts.sketchFile(b.id) : ""
      line = file ? "![Sketch](" + file + ")" : "*(A sketch, drawn in Uber Notebook)*"
    }
    else if (b.type === "audio") {
      // A link to the recording, and what was said in it, quoted.
      var au = b.audio || {}
      var head = au.src ? "[\u{1f399}\u{fe0f} Audio note, " + Audio.clock(au.duration) + "](" + (opts.assetPrefix || "") + au.src + ")" : "*(An audio note, not recorded)*"
      line = au.transcript ? head + "\n\n" + quoted(au.transcript) : head
    }
    else if (b.type === "meeting") line = Meeting.toMarkdown(b.meeting)
    // (Agents get Pages' own blocks back as they write them: ```board...)
    else if (opts.fences && b.type === "board") line = "```board\n" + Board.toFence(b.data) + "\n```"
    else if (opts.fences && b.type === "bookmark" && b.data && b.data.url) line = "```bookmark\n" + b.data.url + "\n```"
    else if (opts.fences && b.type === "contact" && b.data && b.data.contact) line = "```contact\n" + fencedName(b.data) + "\n```"
    else if (opts.fences && b.type === "agenda") line = "```agenda\n" + (b.calendar && b.calendar.day ? b.calendar.day : "today") + "\n```"
    else if (opts.fences && b.type === "event" && b.calendar && b.calendar.id) line = "```event\n" + b.calendar.id + "\n```"
    else if (b.type === "agenda" || b.type === "event") line = calendarLines(b)
    else if (b.type === "file" || b.type === "video") line = Files.toMarkdown(b.data, opts.assetPrefix)
    else if (b.type === "bookmark") line = Bookmark.toMarkdown(b.data)
    else if (b.type === "board") line = Board.toMarkdown(b.data)
    else if (b.type === "button") line = ""
    else if (b.type === "synced") line = syncedLines(b)
    else if (b.type === "contact") line = contactLines(b)
    else if (b.type === "email") line = Email.toMarkdown(b.data, opts.assetPrefix)
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
  var body = list(page.content || [])
  var foot = notes.map(function(t, i) { return "[^" + (i + 1) + "]: " + escapeText(t) }).join("\n")
  return front + (head + body + (foot ? "\n\n" + foot : "")).replace(/\n{3,}/g, "\n\n").trim() + "\n"
}
