// Templates.js - pages that come laid out: planners for a day, a week or a
// month, a habit tracker, a journal, and pages for to-dos, meetings,
// lectures, a project, reading, a recipe or packing. Each is made of ordinary
// blocks, so everything on it can be written in, moved, formatted and found.
//
// Planner pages know their date (a page's `day`), and a notebook of them
// goes on day by day, week by week or month by month: its next page is the
// one after its last (or today's, when that's later).
//
// `fmt(isoDate, pattern)` formats dates for titles and headings (the app
// passes Qt.formatDate, so day and month names are in your language).
//
// Shared by the notebook (app/*.qml), the library and tests/templates.test.cjs,
// so keep it plain JavaScript with no QML or Node APIs.
.pragma library

// date: what a page of it is dated by: "day", "week" (its Monday) or
// "month" (its 1st), each one after the last; "today" (the day it's made);
// "" (not dated). every: what a notebook of them gets as each new page.
// titleHint: the faint title of a page that has none yet. dateTitle: its
// title is its date (so the date isn't written again beside it). paper: the
// pattern it looks best on, suggested when a notebook is made of it.
var TEMPLATES = [
  { id: "blank", label: "Blank page", hint: "Just the paper", icon: "page", date: "", every: "New pages are blank" },
  { id: "daily", label: "Daily planner", hint: "Priorities, the day hour by hour, to-dos", icon: "calendar", date: "day", dateTitle: true, paper: "dots", every: "Each new page plans the next day" },
  { id: "weekly", label: "Weekly planner", hint: "A focus, the seven days, habits", icon: "calendarWeek", date: "week", dateTitle: true, every: "Each new page plans the next week" },
  { id: "monthly", label: "Monthly planner", hint: "The month at a glance, goals, day by day", icon: "calendarMonth", date: "month", dateTitle: true, paper: "dots", every: "Each new page plans the next month" },
  { id: "journal", label: "Journal", hint: "Grateful for, a highlight, what you learned", icon: "journal", date: "today", dateTitle: true, every: "Each new page is today's entry" },
  { id: "habits", label: "Habit tracker", hint: "Habits to tick off, day by day", icon: "habits", date: "week", paper: "grid", every: "Each new page tracks the next week" },
  { id: "todo", label: "To-do list", hint: "Today, this week, someday", icon: "checks", date: "", titleHint: "To do", every: "Each new page is a fresh list" },
  { id: "meeting", label: "Meeting notes", hint: "Who, agenda, notes, decisions, actions", icon: "people", date: "today", titleHint: "What's the meeting?", every: "Each new page is set for a meeting" },
  { id: "lecture", label: "Lecture notes", hint: "Questions, notes, a summary", icon: "school", date: "today", titleHint: "Which lecture?", every: "Each new page is set for a lecture" },
  { id: "project", label: "Project plan", hint: "Goal, milestones, tasks, risks", icon: "project", date: "", titleHint: "Project name" },
  { id: "reading", label: "Reading log", hint: "Reading now, up next, favorite lines", icon: "book", date: "" },
  { id: "recipe", label: "Recipe", hint: "Ingredients, method, notes", icon: "recipe", date: "", titleHint: "Recipe name" },
  { id: "packing", label: "Packing list", hint: "Documents, clothes, toiletries, tech", icon: "bag", date: "", titleHint: "Where to?" }
]

// What a notebook can make every new page (the rest are one-off pages).
var PAGE_KINDS = ["blank", "daily", "weekly", "monthly", "journal", "habits", "todo", "meeting", "lecture"]

function byId(id) {
  for (var i = 0; i < TEMPLATES.length; i++) if (TEMPLATES[i].id === id) return TEMPLATES[i]
  return TEMPLATES[0]
}

function isTemplate(id) {
  for (var i = 0; i < TEMPLATES.length; i++) if (TEMPLATES[i].id === id) return true
  return false
}

function isPageKind(id) {
  return PAGE_KINDS.indexOf(id) >= 0
}

// ---- dates, as "yyyy-mm-dd" in local time -----------------------------------------------

function pad(n) { return (n < 10 ? "0" : "") + n }

function iso(date) {
  return date.getFullYear() + "-" + pad(date.getMonth() + 1) + "-" + pad(date.getDate())
}

function parse(text) {
  var p = String(text).split("-")
  return new Date(Number(p[0]), Number(p[1]) - 1, Number(p[2]))
}

function isIsoDate(text) {
  if (typeof text !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(text)) return false
  return iso(parse(text)) === text
}

function addDays(text, n) {
  var d = parse(text)
  return iso(new Date(d.getFullYear(), d.getMonth(), d.getDate() + n))
}

function addMonths(text, n) {
  var d = parse(text)
  return iso(new Date(d.getFullYear(), d.getMonth() + n, 1))
}

// The Monday of the week a date is in.
function mondayOf(text) {
  return addDays(text, -((parse(text).getDay() + 6) % 7))
}

function firstOfMonth(text) {
  return text.slice(0, 8) + "01"
}

// The ISO 8601 week number: weeks start on Monday, and week 1 is the one
// with the year's first Thursday in it.
function isoWeek(text) {
  var thursday = parse(addDays(mondayOf(text), 3))
  var jan1 = new Date(thursday.getFullYear(), 0, 1)
  return 1 + Math.floor(Math.round((thursday - jan1) / 86400000) / 7)
}

// The date a new page of a template gets, when the page before it of the
// same kind was dated lastDay ("" if there's none) and it's `today`: the day,
// week or month after that one, or today's when that's later (days you
// skipped aren't filled in).
function nextDay(id, lastDay, today) {
  var t = byId(id)
  if (!t.date || !isIsoDate(today)) return ""
  if (t.date === "today") return today
  var now = t.date === "day" ? today : t.date === "week" ? mondayOf(today) : firstOfMonth(today)
  if (!isIsoDate(lastDay)) return now
  var after = t.date === "day" ? addDays(lastDay, 1)
    : t.date === "week" ? addDays(mondayOf(lastDay), 7)
    : addMonths(firstOfMonth(lastDay), 1)
  return after > now ? after : now
}

// ---- building a page ------------------------------------------------------------------

function esc(text) {
  return String(text).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

function repeat(n, make) {
  var out = []
  for (var i = 0; i < n; i++) out.push(make(i))
  return out
}

function heading(text) { return { type: "h2", html: esc(text) } }
function note() { return { type: "p", html: "" } }
function checks(n) { return repeat(n, function() { return { type: "check", html: "" } }) }
function bullets(n) { return repeat(n, function() { return { type: "bullet", html: "" } }) }
function numbers(n) { return repeat(n, function() { return { type: "number", html: "" } }) }
function items(list) { return list.map(function(text) { return { type: "check", html: esc(text) } }) }
function sticky(tone, hint) { return { type: "callout", tone: tone, html: "", hint: hint } }
function habits(n) { return repeat(n, function() { return { type: "habit", days: "0000000", html: "", hint: "A habit to keep" } }) }

// An hour-by-hour schedule, from..to on the 24-hour clock.
function schedule(from, to) {
  return repeat(to - from + 1, function(i) { return { type: "time", label: pad(from + i) + ":00", html: "" } })
}

// The day a page of a template is for, from any day: a week's Monday, a
// month's 1st; today's when there's none. "" for undated templates.
function dayOf(id, day) {
  var t = byId(id)
  if (!t.date) return ""
  var d = isIsoDate(day) ? day : iso(new Date())
  return t.date === "week" ? mondayOf(d) : t.date === "month" ? firstOfMonth(d) : d
}

// The title a page of a template starts with ("" if it's for you to write).
function titleFor(id, day, fmt) {
  var t = byId(id)
  var f = typeof fmt === "function" ? fmt : function(d, pattern) { return d }
  var d = dayOf(id, day)
  if (t.id === "daily" || t.id === "journal") return f(d, "dddd, d MMMM")
  if (t.id === "weekly") return "Week " + isoWeek(d) + " \u00b7 " + f(d, "d MMM") + " \u2013 " + f(addDays(d, 6), "d MMM")
  if (t.id === "monthly") return f(d, "MMMM yyyy")
  if (t.id === "habits") return "Habits \u00b7 week " + isoWeek(d)
  if (t.id === "reading") return "Reading log"
  return ""
}

// A page of a template, for a date (if it's dated): { template, day, title,
// blocks }. Blocks are plain objects; Blocks.cleanList gives them ids.
function build(id, day, fmt) {
  var t = byId(id)
  var f = typeof fmt === "function" ? fmt : function(d, pattern) { return d }
  var d = dayOf(id, day)
  var page = { template: t.id === "blank" ? "" : t.id, day: d, title: titleFor(id, d, f), blocks: [] }
  var b = []
  if (t.id === "daily") {
    b = [heading("Top priorities")].concat(checks(3),
      [heading("Schedule")], schedule(7, 20),
      [heading("To do")], checks(3),
      [heading("Notes"), note()])
  } else if (t.id === "weekly") {
    b = [sticky("yellow", "This week's focus")]
    for (var i = 0; i < 7; i++) b = b.concat([heading(f(addDays(d, i), "dddd d"))], checks(2))
    b = b.concat([heading("Habits")], habits(4), [heading("Notes"), note()])
  } else if (t.id === "monthly") {
    var days = new Date(Number(d.slice(0, 4)), Number(d.slice(5, 7)), 0).getDate()
    b = [{ type: "calendar", month: d.slice(0, 7), marks: "" },
      heading("Goals")].concat(checks(3),
      [heading("Day by day")],
      repeat(days, function(n) { return { type: "time", label: f(addDays(d, n), "ddd d"), html: "" } }),
      [heading("Notes"), note()])
  } else if (t.id === "journal") {
    b = [heading("I'm grateful for")].concat(numbers(3),
      [heading("What would make today great")], numbers(3),
      [heading("Today's highlight"), note()],
      [heading("What I learned"), note()])
  } else if (t.id === "habits") {
    b = habits(8).concat([heading("Notes"), note()])
  } else if (t.id === "todo") {
    b = [heading("Today")].concat(checks(4), [heading("This week")], checks(4), [heading("Someday")], checks(3))
  } else if (t.id === "meeting") {
    b = [heading("Who")].concat(bullets(2),
      [heading("Agenda")], numbers(3),
      [heading("Notes"), note()],
      [heading("Decisions")], bullets(2),
      [heading("Action items")], checks(3))
  } else if (t.id === "lecture") {
    b = [heading("Questions and keywords")].concat(bullets(3),
      [heading("Notes"), note()],
      [heading("Summary"), sticky("blue", "The lecture in a few lines")])
  } else if (t.id === "project") {
    b = [sticky("purple", "What it's for, and what done looks like"),
      heading("Milestones")].concat(numbers(3),
      [heading("Tasks")], checks(4),
      [heading("Risks")], bullets(2),
      [heading("Notes"), note()])
  } else if (t.id === "reading") {
    b = [heading("Reading now")].concat(bullets(2),
      [heading("Up next")], checks(4),
      [heading("Favorite lines"), { type: "quote", html: "", hint: "A line worth keeping" }])
  } else if (t.id === "recipe") {
    b = [sticky("green", "Serves 4 \u00b7 45 minutes"),
      heading("Ingredients")].concat(bullets(5),
      [heading("Method")], numbers(4),
      [heading("Notes"), note()])
  } else if (t.id === "packing") {
    b = [heading("Documents")].concat(items(["Passport or ID", "Tickets", "Wallet"]),
      [heading("Clothes")], checks(4),
      [heading("Toiletries")], items(["Toothbrush", "Toothpaste"]), checks(1),
      [heading("Tech")], items(["Phone charger", "Headphones"]), checks(1))
  } else {
    b = [note()]
  }
  page.blocks = b
  return page
}

// What a page's template calls it when it has no title of its own.
function titleHint(id) {
  var t = byId(id)
  return t.id === "blank" ? "" : (t.titleHint || t.label)
}

// ---- in Pages -------------------------------------------------------------------------------

// Pages has no paper to fill in, so there each template is laid out as a
// page: sections side by side in columns, callouts, dividers, habits to tick,
// a month's calendar, the date, and on every empty line, faintly, what goes
// on it. Blocks are as the editor has them: { type, html, indent, ... }.

// Each template's icon in Pages (not a calendar that says 17 July).
var ICONS = {
  daily: "\u2600\u{fe0f}", weekly: "\u{1f5d3}\u{fe0f}", monthly: "\u{1f319}", journal: "\u{1f4d3}", habits: "\u{1f501}",
  todo: "\u2705", meeting: "\u{1f465}", lecture: "\u{1f393}", project: "\u{1f680}", reading: "\u{1f4da}",
  recipe: "\u{1f373}", packing: "\u{1f9f3}"
}

// Notion's gray, for a time or a day starting a line.
var FAINT = "#787774"

function blk(type, hint, html) {
  var b = { type: type, html: html || "", indent: 0 }
  if (hint) b.hint = hint
  return b
}
function many(type, hint, n) { return repeat(n, function() { return blk(type, hint) }) }
function head(text) { return blk("h3", "", esc(text)) }
function box(icon, color, hint) {
  var b = blk("callout", hint)
  b.icon = icon
  if (color) b.color = color + "_background"
  return b
}
function rule() { return { type: "divider", style: "line", indent: 0 } }

// Blocks moved in, inside the block before them.
function inside(list, by) {
  return list.map(function(b) {
    var c = {}
    for (var k in b) c[k] = b[k]
    c.indent = (b.indent || 0) + by
    return c
  })
}

// Columns side by side, each a list of blocks; `widths` their shares of the
// page (or an equal share each).
function side(cols, widths) {
  var out = [{ type: "columns", indent: 0 }]
  cols.forEach(function(list, i) {
    var col = { type: "column", indent: 1 }
    if (widths && widths[i]) col.width = widths[i]
    out.push(col)
    out = out.concat(inside(list, 2))
  })
  return out
}

// A toggle with blocks inside it, open or folded.
function fold(text, kids, open) {
  var t = blk("toggle", "", esc(text))
  if (!open) t.collapsed = true
  return [t].concat(inside(kids, 1))
}

// A line that starts with a time or a day, faint and bold, to write after.
function stamp(text) {
  return blk("p", "", "<span style=\"color:" + FAINT + "; font-weight:700;\">" + esc(text) + "</span> ")
}

// A line with the date on it, as a date in Pages ("@Wed 30 Sep").
function dateLine(day, f) {
  return blk("p", "", "<a href=\"uber-notebook://date/" + day + "\">@" + esc(f(day, "ddd d MMM")) + "</a> ")
}

// The month's weeks (Monday to Sunday, cut at its ends), each a folded
// toggle with a line for each day; the one with `today` in it is open (or
// the first, in another month).
function monthWeeks(first, f, today) {
  var month = first.slice(0, 7)
  var out = []
  var at = first
  var opened = false
  var weeks = []
  while (at.slice(0, 7) === month) {
    var days = []
    var end = at
    do {
      days.push(end)
      end = addDays(end, 1)
    } while (end.slice(0, 7) === month && parse(end).getDay() !== 1)
    weeks.push(days)
    at = end
  }
  var current = -1
  weeks.forEach(function(days, i) { if (days.indexOf(today) >= 0) current = i })
  if (current < 0) current = 0
  weeks.forEach(function(days, i) {
    var a = days[0]
    var z = days[days.length - 1]
    var name = "Week " + isoWeek(a) + " \u00b7 " + (a === z ? f(a, "d MMM") : f(a, "d") + " \u2013 " + f(z, "d MMM"))
    out = out.concat(fold(name, days.map(function(day) { return stamp(f(day, "ddd d")) }), i === current))
  })
  return out
}

function pageBlocks(id, d, f, today) {
  if (id === "daily") {
    return [box("\u{1f3af}", "yellow", "The one thing that would make today a good day")].concat(
      side([
        [head("Top priorities"), blk("check", "The most important thing"), blk("check", "Next"), blk("check", "If there's time")],
        [head("To do")].concat(many("check", "Something to do", 3))
      ]),
      [head("Schedule")],
      side([
        repeat(7, function(i) { return stamp(pad(7 + i) + ":00") }),
        repeat(7, function(i) { return stamp(pad(14 + i) + ":00") })
      ]),
      [rule(), head("Notes"), blk("p", "Anything worth remembering")])
  }
  if (id === "weekly") {
    var days = repeat(7, function(i) { return [head(f(addDays(d, i), "ddd d"))].concat(many("check", "To do", 2)) })
    return [box("\u{1f3af}", "yellow", "This week's focus")].concat(
      side(days.slice(0, 4)),
      side(days.slice(4).concat([[head("Next week")].concat(many("check", "Carry over", 2))])),
      [head("Habits")], many("habit", "A habit to keep this week", 4),
      [rule(), head("Notes"), blk("p", "Anything else about the week")])
  }
  if (id === "monthly") {
    return [box("\u{1f3af}", "yellow", "This month's focus")].concat(
      side([
        [{ type: "calendar", month: d.slice(0, 7), marks: "", indent: 0 }],
        [head("Goals")].concat(many("check", "A goal for the month", 3), [head("Dates to remember")], many("bullet", "Type @ and a date", 2))
      ], [0.55, 0.45]),
      [head("Week by week")], monthWeeks(d, f, today),
      [rule(), head("Notes"), blk("p", "Anything else about the month")])
  }
  if (id === "journal") {
    return [blk("quote", "Today in a sentence")].concat(
      side([
        [head("Grateful for")].concat(many("number", "Something, or someone", 3)),
        [head("Today would be great if")].concat(many("number", "One thing", 3))
      ]),
      [head("Highlight of the day"), box("\u2728", "purple", "The best part of today"),
        head("What I learned"), blk("p", "Something new, big or small")])
  }
  if (id === "habits") {
    return [box("\u{1f331}", "green", "What these habits are for"), head(f(d, "d MMM") + " \u2013 " + f(addDays(d, 6), "d MMM"))].concat(
      many("habit", "A habit to keep", 8),
      [rule(), head("Notes"), blk("p", "How the week went")])
  }
  if (id === "todo") {
    return side([
      [head("Today")].concat(many("check", "Something to do", 4)),
      [head("This week")].concat(many("check", "Something to do", 4)),
      [head("Someday")].concat(many("check", "Something, one day", 3))
    ])
  }
  if (id === "meeting") {
    return [dateLine(d, f)].concat(
      side([
        [head("Who")].concat(many("bullet", "Someone there", 2)),
        [head("Agenda")].concat(many("number", "A topic", 3))
      ]),
      [head("Notes")], many("bullet", "What was said", 2),
      side([
        [head("Decisions")].concat(many("bullet", "What was decided", 2)),
        [head("Action items")].concat(many("check", "Who does what, by when", 3))
      ]))
  }
  if (id === "lecture") {
    return [dateLine(d, f)].concat(
      side([
        [head("Questions")].concat(many("bullet", "A question, or a keyword", 3)),
        [head("Notes")].concat(many("bullet", "What was said", 4))
      ], [0.35, 0.65]),
      [rule(), head("Summary"), box("\u{1f4dd}", "blue", "The lecture in a few lines")])
  }
  if (id === "project") {
    return [box("\u{1f3af}", "purple", "What it's for, and what done looks like")].concat(
      side([
        [head("Milestones")].concat(many("number", "A milestone, and when", 3)),
        [head("Risks")].concat(many("bullet", "What could go wrong", 2))
      ]),
      [head("Tasks")], many("check", "A task", 4),
      [rule(), head("Notes"), blk("p", "Links, ideas, anything else")])
  }
  if (id === "reading") {
    return side([
      [head("Reading now")].concat(many("bullet", "A book, and who wrote it", 2)),
      [head("Up next")].concat(many("check", "A book to read", 3))
    ]).concat(
      [head("Finished")], many("bullet", "A book, and what you thought", 2),
      [head("Favorite lines"), blk("quote", "A line worth keeping")])
  }
  if (id === "recipe") {
    return [box("\u{1f37d}\u{fe0f}", "green", "Serves 4 \u00b7 45 minutes")].concat(
      side([
        [head("Ingredients")].concat(many("bullet", "An ingredient", 5)),
        [head("Method")].concat(many("number", "A step", 4))
      ], [0.4, 0.6]),
      [head("Notes"), blk("p", "What to change next time")])
  }
  if (id === "packing") {
    return [box("\u2708\u{fe0f}", "blue", "When, and for how long")].concat(
      side([
        [head("Documents")].concat(items(["Passport or ID", "Tickets", "Wallet"]), [head("Toiletries")], items(["Toothbrush", "Toothpaste"]), [blk("check", "Something else")]),
        [head("Clothes")].concat(many("check", "Something to wear", 4), [head("Tech")], items(["Phone charger", "Headphones"]), [blk("check", "Something else")])
      ]))
  }
  return [blk("p", "")]
}

// ---- your own templates (Pages) -------------------------------------------------------------

// What's written in a template of your own, filled in as it's used:
// {{date}} (in a line, a date in Pages, "@Fri 2 Oct"; in a title, "Fri 2
// Oct"), {{weekday}} ("Friday"), {{time}} ("14:05"), {{month}} ("October
// 2026"), {{year}}, {{week}} ("Week 40"). `html`: it's a block's text.
var FILLS = /\{\{\s*(date|weekday|time|month|year|week)\s*\}\}/gi

function fill(text, html, now, fmt) {
  var s = String(text || "")
  if (s.indexOf("{{") < 0) return s
  var d = now || new Date()
  var day = iso(d)
  var f = typeof fmt === "function" ? fmt : function(x) { return x }
  function out(t) { return html ? esc(t) : t }
  return s.replace(FILLS, function(all, name) {
    var n = name.toLowerCase()
    if (n === "date") return html ? "<a href=\"uber-notebook://date/" + day + "\">@" + esc(f(day, "ddd d MMM")) + "</a>" : f(day, "ddd d MMM")
    if (n === "weekday") return out(f(day, "dddd"))
    if (n === "time") return pad(d.getHours()) + ":" + pad(d.getMinutes())
    if (n === "month") return out(f(day, "MMMM yyyy"))
    if (n === "year") return String(d.getFullYear())
    return "Week " + isoWeek(day)
  })
}

// A page of a template for Pages: { title, hint, icon, blocks }, hint the
// faint title of a page you name ("What's the meeting?"). `day` is today.
function forPages(id, day, fmt) {
  var t = byId(id)
  var f = typeof fmt === "function" ? fmt : function(d, pattern) { return d }
  var today = isIsoDate(day) ? day : iso(new Date())
  var d = dayOf(t.id, today)
  var blocks = pageBlocks(t.id, d || today, f, today).map(function(b) {
    if (b.indent === undefined) b.indent = 0
    if (b.type !== "divider" && b.type !== "calendar" && b.type !== "columns" && b.type !== "column" && b.html === undefined) b.html = ""
    return b
  })
  // Something to click under the last block and write.
  var last = blocks[blocks.length - 1]
  if (last.indent !== 0 || ["divider", "calendar", "columns", "column"].indexOf(last.type) >= 0 || last.hint) blocks.push(blk("p", ""))
  var title = titleFor(t.id, d, f)
  if (!title && t.id === "todo") title = "To do"
  return { title: title, hint: title ? "" : titleHint(t.id), icon: ICONS[t.id] || "", blocks: blocks }
}
