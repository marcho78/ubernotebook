// Starter.js - what a new Uber Notebook's Pages starts with: example pages that
// show what it can do (a project with its board, meeting notes with the
// meeting in them, a trip with its flight's email, a mind map, a reading
// list, a recipe...), the people and events they name, and templates of
// your own to start from.
//
// The pages are Markdown files in starter/ (dev/starter puts them in
// StarterContent.js), read the way an agent's Markdown is (Import.js), with
// a few lines for what Markdown has no way to say, each starting "::":
//
//   ::columns 60 40  ...  ::next  ...  ::end     blocks side by side
//   ::pages                         the pages in this one not placed yet
//   ::file name | Its name.pdf      a file from starter/assets (a PDF shows its pages)
//   ::image name                    a picture from starter/assets
//   ::email name.eml                a saved email
//   ::meeting name.json             a meeting and who said what
//   ::sketch name.json              a drawing
//   ::bookmark url | title | a line about it | site
//   ::button words | template | page or insert
//   ::habit 1101100 | name          a habit, its days from Monday
//   ::toc, ::calendar               a table of contents, a month's calendar
//
// And for the day they're made: {{date:+2}} is a date on the page (two days
// on), {{day:+2}} that day as 2026-10-04, {{label:+2}} as "Sun 4 Oct";
// {{date:tue}} is the next Tuesday (today, on a Tuesday). {{person:sam}} is
// someone from starter/people.json, {{event:sync}} an event's id from
// starter/calendar.json, {{folder}} where the notes are. In an email (and
// what's attached to it): {{mail:-6}}, a Date: header that day, and
// {{compact:+9}}, a calendar file's 20261011. A template's own
// {{date}} and the like are left for when it's used.
//
// A page's front matter: title, icon, parent (another page's file name),
// order, favorite, cover, status and due (a project), template, and a
// template's description (what it's for, shown in Templates).
.pragma library
.import "StarterContent.js" as Content
.import "Import.js" as Import
.import "Workspace.js" as Workspace
.import "Calendar.js" as Calendar
.import "Contacts.js" as Contacts
.import "Dates.js" as Dates
.import "Email.js" as Email
.import "Meeting.js" as Meeting
.import "Bookmark.js" as Bookmark
.import "Files.js" as Files
.import "Html.js" as Html

// What the example files are called in Pages/assets.
var PREFIX = "example-"

var WEEKDAYS = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"]

// A day from `now`: "+2", "-1", "0", or a weekday ("tue": the next one).
function dayAt(now, spec) {
  var base = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  var s = String(spec || "0").trim().toLowerCase()
  var w = WEEKDAYS.indexOf(s.slice(0, 3))
  if (w >= 0 && /^[a-z]+$/.test(s)) return new Date(base.getFullYear(), base.getMonth(), base.getDate() + (w - base.getDay() + 7) % 7)
  var n = Number(s.replace(/^\+/, ""))
  return new Date(base.getFullYear(), base.getMonth(), base.getDate() + (isFinite(n) ? Math.round(n) : 0))
}

function fill(text, now, b) {
  return String(text || "").replace(/\{\{(date|day|label|person|event|mail|compact):([^}]+)\}\}|\{\{folder\}\}/g, function(all, kind, arg) {
    if (!kind) return b.folder
    var key = arg.trim()
    if (kind === "person") {
      var p = b.people[key]
      return p ? "[@" + p.name + "](uber-notebook://contact/" + p.id + ")" : key
    }
    if (kind === "event") return b.events[key] ? b.events[key].id : ""
    var d = dayAt(now, key)
    if (kind === "day") return Calendar.dayIso(d)
    if (kind === "label") return Dates.label(d, false, now)
    if (kind === "compact") return Calendar.dayIso(d).replace(/-/g, "")
    if (kind === "mail") return mailDate(new Date(d.getFullYear(), d.getMonth(), d.getDate(), 9, 12))
    return "[@" + Dates.label(d, false, now) + "](uber-notebook://date/" + Calendar.dayIso(d) + ")"
  })
}

// "Mon, 28 Sep 2026 09:12:00 +0100", as an email's Date: says it.
function mailDate(d) {
  function pad(n) { return (n < 10 ? "0" : "") + n }
  var off = -d.getTimezoneOffset()
  var zone = (off < 0 ? "-" : "+") + pad(Math.floor(Math.abs(off) / 60)) + pad(Math.abs(off) % 60)
  return Dates.SHORT_DAYS[d.getDay()] + ", " + d.getDate() + " " + Dates.SHORT_MONTHS[d.getMonth()] + " " + d.getFullYear() + " "
    + pad(d.getHours()) + ":" + pad(d.getMinutes()) + ":00 " + zone
}

// Front matter: { meta: { key: value }, body }.
function frontMatter(text) {
  var lines = String(text || "").replace(/\r\n?/g, "\n").split("\n")
  var meta = {}
  if (lines[0] !== "---") return { meta: meta, body: lines.join("\n") }
  var end = lines.indexOf("---", 1)
  if (end < 0) return { meta: meta, body: lines.join("\n") }
  lines.slice(1, end).forEach(function(l) {
    var m = /^([A-Za-z]+)\s*:\s*(.*?)\s*$/.exec(l)
    if (m) meta[m[1].toLowerCase()] = m[2].replace(/^["']|["']$/g, "")
  })
  return { meta: meta, body: lines.slice(end + 1).join("\n") }
}

// Blocks moved inside the block before them (by `by` levels).
function inside(list, by) {
  return list.map(function(x) {
    var c = {}
    for (var k in x) c[k] = x[k]
    c.indent = (x.indent || 0) + by
    return c
  })
}

function side(cols, widths) {
  var out = [{ type: "columns", indent: 0 }]
  var total = widths.reduce(function(a, w) { return a + w }, 0)
  cols.forEach(function(list, i) {
    var col = { type: "column", indent: 1 }
    if (widths.length === cols.length && total > 0) col.width = Math.round(widths[i] / total * 100) / 100
    out.push(col)
    out = out.concat(inside(list.length ? list : [{ type: "p", html: "", indent: 0 }], 2))
  })
  return out
}

function json(name) {
  try { return JSON.parse(Content.TEXT["assets/" + name] || "null") } catch (e) { return null }
}

// A file from starter/assets, to copy into Pages/assets (a text one as
// `text`, filled in): its src there.
function asset(b, name, text) {
  var out = PREFIX + name
  if (!b.assets[out]) {
    var t = text !== undefined ? text : Content.TEXT["assets/" + name]
    b.assets[out] = t !== undefined ? { name: out, text: t } : { name: out, file: name }
  }
  return "assets/" + out
}

function sizeOf(name) {
  var t = Content.TEXT["assets/" + name]
  return Content.SIZES[name] || (t !== undefined ? t.length : 0)
}

// A "::" line's blocks.
function directive(cmd, arg, def, now, b) {
  var a = String(arg || "").split("|").map(function(s) { return s.trim() })
  if (cmd === "pages") {
    return def.children.filter(function(k) { return !b.placed[k] }).map(function(k) {
      b.placed[k] = true
      return { type: "page", uid: b.ids[k], indent: 0 }
    })
  }
  if (cmd === "toc") return [{ type: "toc", indent: 0 }]
  if (cmd === "calendar") return [{ type: "calendar", indent: 0, month: Calendar.dayIso(now).slice(0, 7), marks: "" }]
  if (cmd === "image") return [{ type: "image", src: asset(b, a[0]), width: 1, align: "center", indent: 0 }]
  if (cmd === "file") {
    var src = asset(b, a[0])
    return [{ type: Files.kindOf(a[0]) === "video" ? "video" : "file", indent: 0,
      data: { src: src, name: a[1] || a[0], size: sizeOf(a[0]), kind: Files.kindOf(a[1] || a[0]) } }]
  }
  if (cmd === "email") {
    var eml = fill(Content.TEXT["assets/" + a[0]] || "", now, b)
    var m = Email.parse(eml)
    if (!m) return []
    var s = Email.summary(m)
    s.src = asset(b, a[0], eml)
    s.name = a[0]
    s.size = eml.length
    return [{ type: "email", indent: 0, data: s }]
  }
  if (cmd === "meeting") {
    var raw = json(a[0])
    if (!raw) return []
    var day = dayAt(now, raw.day || "0")
    var hm = /^(\d{1,2}):(\d{2})$/.exec(raw.time || "") || [0, 9, 0]
    raw.startedAt = new Date(day.getFullYear(), day.getMonth(), day.getDate(), Number(hm[1]), Number(hm[2])).toISOString()
    raw.id = b.hex(16)
    var meeting = Meeting.clean(raw)
    return meeting ? [{ type: "meeting", indent: 0, meeting: meeting }] : []
  }
  if (cmd === "sketch") {
    var sk = json(a[0])
    return sk ? [{ type: "sketch", indent: 0, sketch: sk }] : []
  }
  if (cmd === "bookmark") {
    var url = Bookmark.cleanUrl(a[0])
    if (!url) return []
    return [{ type: "bookmark", indent: 0, data: { url: url, title: a[1] || "", description: a[2] || "", site: a[3] || Bookmark.domain(url), image: "" } }]
  }
  if (cmd === "button") return [{ type: "button", indent: 0, data: { label: a[0] || "", template: a[1] || "", action: a[2] === "insert" ? "insert" : "page" } }]
  if (cmd === "habit") {
    // Ticked on the days before today (from Monday), never on days to come.
    var today = (now.getDay() + 6) % 7
    var days = (/^[01]{7}$/.test(a[0]) ? a[0] : "0000000").split("").map(function(c, i) { return i < today ? c : "0" }).join("")
    return [{ type: "habit", indent: 0, days: days, html: Html.escapeText(a[1] || "") }]
  }
  return []
}

// A page's Markdown (filled in already) as blocks.
function blocksOf(text, def, now, b) {
  var lines = String(text || "").split("\n")
  var out = []
  var buf = []
  function flush() {
    if (buf.join("").trim()) out = out.concat(Import.fromMarkdown(buf.join("\n"), b.ctx, {}).blocks)
    buf = []
  }
  for (var i = 0; i < lines.length; i++) {
    var m = /^::([a-z]+)\s*(.*)$/.exec(lines[i])
    if (!m) { buf.push(lines[i]); continue }
    flush()
    if (m[1] !== "columns") { out = out.concat(directive(m[1], m[2], def, now, b)); continue }
    var cols = [[]]
    var depth = 0
    var j = i + 1
    for (; j < lines.length; j++) {
      var n = /^::([a-z]+)/.exec(lines[j])
      if (n && n[1] === "columns") depth++
      else if (n && n[1] === "end") { if (depth === 0) break; depth-- }
      else if (n && n[1] === "next" && depth === 0) { cols.push([]); continue }
      cols[cols.length - 1].push(lines[j])
    }
    i = j
    var widths = m[2].trim() ? m[2].trim().split(/\s+/).map(Number).filter(function(w) { return w > 0 }) : []
    out = out.concat(side(cols.map(function(c) { return blocksOf(c.join("\n"), def, now, b) }), widths))
  }
  flush()
  return out
}

function hexer(random) {
  var r = random || Math.random
  return function(n) { var s = ""; for (var i = 0; i < n; i++) s += "0123456789abcdef".charAt(Math.floor(r() * 16)); return s }
}

// Everything, made for `now`: { pages: [{ page, template, description }] (a page before
// the pages in it), favorites: [ids], contacts, events, assets: [{ name,
// text } or { name, file }] }. options: { folder (how to name it), random,
// templatesOnly (just the templates: a profile of your own) }.
function build(now, options) {
  var o = options || {}
  var b = { folder: o.folder || "~/Documents/Uber Notebook", people: {}, events: {}, ids: {}, placed: {}, assets: {}, hex: hexer(o.random) }

  // The people, then the events (which may have notes pages).
  var contacts = []
  var people = []
  if (!o.templatesOnly) try { people = JSON.parse(Content.TEXT["people.json"] || "[]") } catch (e) {}
  people.forEach(function(p) {
    var c = Contacts.cleanContact({ id: "c" + b.hex(12), name: p.name, company: p.company, title: p.title, phones: p.phones, emails: p.emails,
      birthday: p.birthday, address: p.address, website: p.website, notes: p.notes })
    if (!c) return
    b.people[p.key] = { id: c.id, name: Contacts.nameOf(c) }
    contacts.push(c)
  })

  var defs = []
  Object.keys(Content.TEXT).sort().forEach(function(path) {
    var m = /^(pages|templates)\/([a-z0-9-]+)\.md$/.exec(path)
    if (!m) return
    var f = frontMatter(Content.TEXT[path])
    var template = m[1] === "templates" || f.meta.template === "true"
    if (o.templatesOnly && !template) return
    defs.push({ key: m[2], meta: f.meta, body: f.body, template: template, children: [] })
  })
  defs.forEach(function(d) { b.ids[d.key] = Workspace.uuid4(o.random) })
  var byKey = {}
  defs.forEach(function(d) { byKey[d.key] = d })
  function order(x, y) { return (Number(x.meta.order) || 99) - (Number(y.meta.order) || 99) || (x.meta.title || x.key).localeCompare(y.meta.title || y.key) }
  defs.sort(order)
  defs.forEach(function(d) { if (d.meta.parent && byKey[d.meta.parent]) byKey[d.meta.parent].children.push(d.key) })

  var events = []
  var cal = []
  if (!o.templatesOnly) try { cal = JSON.parse(Content.TEXT["calendar.json"] || "[]") } catch (e) {}
  cal.forEach(function(e) {
    var day = dayAt(now, e.on || "0")
    var end = dayAt(now, e.until || e.on || "0")
    var raw = { id: Workspace.uuid4(o.random), title: e.title, allDay: !e.time, place: e.place || "", detail: e.notes || "",
      color: e.color || "", alert: -1, page: e.page && b.ids[e.page] ? b.ids[e.page] : "",
      repeat: e.repeat ? { freq: e.repeat, every: 1, until: "" } : null }
    if (e.time) {
      raw.start = Calendar.dayIso(day) + "T" + e.time
      raw.end = Calendar.dayIso(day) + "T" + (e.end || e.time)
    } else {
      raw.start = Calendar.dayIso(day)
      raw.end = Calendar.dayIso(end)
    }
    var clean = Calendar.cleanEvent(raw)
    if (!clean) return
    b.events[e.key] = clean
    events.push(clean)
  })

  b.ctx = {
    wiki: function(name) {
      var t = String(name || "").trim().toLowerCase()
      var d = defs.filter(function(x) { return !x.template && (x.meta.title || "").toLowerCase() === t })[0]
      return d ? b.ids[d.key] : ""
    },
    contact: function(q) {
      var t = String(q || "").trim().toLowerCase()
      var hit = contacts.filter(function(c) { return c.name.toLowerCase() === t || c.emails.some(function(x) { return x.value === t }) })[0]
      return hit ? hit.id : ""
    },
    event: function(id) { return events.some(function(e) { return e.id === id }) }
  }

  // A page after the page it's in.
  var pages = []
  var done = {}
  function make(d) {
    if (done[d.key]) return
    done[d.key] = true
    var blocks = blocksOf(fill(d.body, now, b), d, now, b)
    d.children.forEach(function(k) {
      if (!b.placed[k]) { b.placed[k] = true; blocks.push({ type: "page", uid: b.ids[k], indent: 0 }) }
    })
    blocks.push({ type: "p", html: "", indent: 0 })
    var project = null
    if (/^(planning|active|paused|done)$/.test(d.meta.status || "")) project = { status: d.meta.status, due: /^\d{4}-\d{2}-\d{2}$/.test(fill(d.meta.due, now, b)) ? fill(d.meta.due, now, b) : "" }
    var page = Workspace.newPage({ id: b.ids[d.key], parent: d.meta.parent && byKey[d.meta.parent] ? b.ids[d.meta.parent] : "",
      title: Workspace.cleanTitle(fill(d.meta.title || "", now, b)), icon: d.meta.icon || "", cover: d.meta.cover || "", project: project, blocks: blocks }, now, o.random)
    pages.push({ page: page, template: d.template, description: d.meta.description || "" })
    d.children.forEach(function(k) { make(byKey[k]) })
  }
  defs.filter(function(d) { return !d.meta.parent || !byKey[d.meta.parent] }).forEach(make)

  return {
    pages: pages,
    favorites: defs.filter(function(d) { return d.meta.favorite === "true" && !d.template }).map(function(d) { return b.ids[d.key] }),
    contacts: contacts,
    events: events,
    assets: Object.keys(b.assets).map(function(k) { return b.assets[k] })
  }
}
