// Calendar.js - the calendar in Pages: your own events, kept in
// Pages/calendar.json, on no one's server. An event is a title, when (a
// day, or a start and an end), maybe a repeat, a color, an alert before it,
// a place, a few words, and the page of notes for it:
//
//   { id: "<uuid>", title: "Standup", allDay: false,
//     start: "2026-10-05T09:30", end: "2026-10-05T09:45",
//     repeat: { freq: "weekdays", every: 1, until: "" }, skip: ["2026-10-12"],
//     color: "blue", alert: 10, place: "", detail: "", page: "" }
//
// Times are the computer's own (no time zones). An all-day event's end is
// its last day. A repeat is daily, on weekdays, weekly, monthly or yearly,
// every `every` of those, until a day (or for good); `skip` are the days
// it doesn't happen.
//
// It cleans what's read, works out what happens between two moments (the
// repeats too), lays out a day's events side by side, reads "Lunch with Sam
// fri 12:30", finds the alerts to come, and writes the calendar as iCalendar
// (.ics). Shared with tests/calendar.test.cjs, so keep it plain JavaScript
// with no QML or Node APIs.
.pragma library
.import "Dates.js" as Dates
.import "Mindmap.js" as Mindmap

var VERSION = 1
var REPEATS = ["daily", "weekdays", "weekly", "monthly", "yearly"]
// Minutes before (-1: none).
var ALERTS = [-1, 0, 5, 10, 15, 30, 60, 120, 1440]
var MAX_EVENTS = 20000
var MAX_SKIPS = 500
var DAY = 86400000

function pad(n) { return (n < 10 ? "0" : "") + n }

function cleanLine(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max)
}

function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

function newId(random) {
  var r = typeof random === "function" ? random : Math.random
  var h = "0123456789abcdef"
  var s = ""
  for (var i = 0; i < 36; i++) {
    if (i === 8 || i === 13 || i === 18 || i === 23) s += "-"
    else if (i === 14) s += "4"
    else if (i === 19) s += h.charAt(8 + Math.floor(r() * 4))
    else s += h.charAt(Math.floor(r() * 16))
  }
  return s
}

// "2026-10-05" (a day) -> Date at its start, or null.
function day(text) {
  var d = Dates.fromIso(text)
  return d && !d.time ? d.at : null
}

function dayIso(d) { return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate()) }
function timeIso(d) { return dayIso(d) + "T" + pad(d.getHours()) + ":" + pad(d.getMinutes()) }
function startOfDay(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()) }
function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, d.getHours(), d.getMinutes()) }

function make() { return { version: VERSION, events: [] } }

// An event as it may be kept, or null.
function cleanEvent(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var allDay = raw.allDay === true
  var s = Dates.fromIso(raw.start)
  if (!s) return null
  var out = { id: UUID.test(raw.id) ? raw.id : newId(), title: cleanLine(raw.title, 200), allDay: allDay }
  if (allDay) {
    var sd = startOfDay(s.at)
    var e = Dates.fromIso(raw.end)
    var ed = e ? startOfDay(e.at) : sd
    if (ed < sd) ed = sd
    if ((ed - sd) / DAY > 366) ed = addDays(sd, 366)
    out.start = dayIso(sd)
    out.end = dayIso(ed)
  } else {
    var st = s.time ? s.at : new Date(s.at.getFullYear(), s.at.getMonth(), s.at.getDate(), 9, 0)
    var en = Dates.fromIso(raw.end)
    var et = en && en.time ? en.at : new Date(st.getTime() + 3600000)
    if (et <= st) et = new Date(st.getTime() + 3600000)
    if (et - st > 31 * DAY) et = new Date(st.getTime() + 31 * DAY)
    out.start = timeIso(st)
    out.end = timeIso(et)
  }
  var r = raw.repeat
  if (r && typeof r === "object" && REPEATS.indexOf(r.freq) >= 0) {
    var every = Math.round(Number(r.every) || 1)
    out.repeat = { freq: r.freq, every: Math.max(1, Math.min(99, every)), until: day(r.until) ? r.until : "" }
  } else out.repeat = null
  var seen = {}
  out.skip = (Array.isArray(raw.skip) ? raw.skip : []).filter(function(d) {
    if (!day(d) || seen[d]) return false
    seen[d] = true
    return true
  }).sort().slice(-MAX_SKIPS)
  out.color = cleanColor(raw.color)
  var a = Number(raw.alert)
  out.alert = ALERTS.indexOf(a) >= 0 ? a : -1
  out.place = cleanLine(raw.place, 200)
  out.detail = typeof raw.detail === "string" ? raw.detail.replace(/\r\n?/g, "\n").slice(0, 4000) : ""
  out.page = UUID.test(raw.page) ? raw.page : ""
  return out
}

// calendar.json as it may be used.
function clean(raw) {
  var out = make()
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.events)) return out
  var seen = {}
  raw.events.slice(0, MAX_EVENTS).forEach(function(e) {
    var c = cleanEvent(e)
    if (!c) return
    if (seen[c.id]) c.id = newId()
    seen[c.id] = true
    out.events.push(c)
  })
  return out
}

function copy(cal) { return JSON.parse(JSON.stringify(cal)) }

function byId(cal, id) {
  for (var i = 0; i < cal.events.length; i++) if (cal.events[i].id === id) return cal.events[i]
  return null
}

// ---- what happens when ----------------------------------------------------------------------

function startOf(ev) { return Dates.fromIso(ev.start).at }
// When it ends: a timed one's end, an all-day one's last day's end.
function endOf(ev) { return ev.allDay ? addDays(Dates.fromIso(ev.end).at, 1) : Dates.fromIso(ev.end).at }

// The days a repeating event happens on, from its first, the first of them
// not before `from` (a Date) and up to `to`: each a Date, its start's day.
function repeatDays(ev, from, to) {
  var first = startOfDay(startOf(ev))
  var r = ev.repeat
  var out = []
  if (!r) {
    if (first >= startOfDay(from) && first < to) out.push(first)
    return out
  }
  var until = r.until ? addDays(day(r.until), 1) : null
  var end = until && until < to ? until : to
  var n = r.every
  var lo = startOfDay(from)
  var guard = 0
  function push(d) { if (d >= lo && d < end && d >= first) out.push(d) }
  if (r.freq === "daily") {
    var k = Math.max(0, Math.floor((lo - first) / DAY / n) - 1)
    for (var d = addDays(first, k * n); d < end && guard++ < 5000; d = addDays(d, n)) push(d)
  } else if (r.freq === "weekly" || r.freq === "weekdays") {
    var step = r.freq === "weekly" ? 7 * n : 1
    var w = Math.max(0, Math.floor((lo - first) / DAY / step) - 1)
    for (var d2 = addDays(first, w * step); d2 < end && guard++ < 5000; d2 = addDays(d2, step)) {
      if (r.freq === "weekdays") {
        // Monday to Friday, every `n` weeks counted from the first.
        var wd = d2.getDay()
        var weeks = Math.floor((startOfWeek(d2) - startOfWeek(first)) / (7 * DAY) + 0.5)
        if (wd === 0 || wd === 6 || weeks % n !== 0) continue
      }
      push(d2)
    }
  } else if (r.freq === "monthly") {
    var months = Math.max(0, (lo.getFullYear() - first.getFullYear()) * 12 + lo.getMonth() - first.getMonth() - 1)
    months -= months % n
    for (var m = months; guard++ < 2000; m += n) {
      var dm = new Date(first.getFullYear(), first.getMonth() + m, first.getDate())
      // (A month without the day, the 31st, is skipped.)
      if (dm.getDate() !== first.getDate()) { if (new Date(first.getFullYear(), first.getMonth() + m, 1) >= end) break; continue }
      if (dm >= end) break
      push(dm)
    }
  } else if (r.freq === "yearly") {
    var years = Math.max(0, lo.getFullYear() - first.getFullYear() - 1)
    years -= years % n
    for (var y = years; guard++ < 500; y += n) {
      var dy = new Date(first.getFullYear() + y, first.getMonth(), first.getDate())
      if (dy.getMonth() !== first.getMonth()) { if (new Date(first.getFullYear() + y, first.getMonth(), 1) >= end) break; continue }
      if (dy >= end) break
      push(dy)
    }
  }
  return out
}

function startOfWeek(d) { var s = startOfDay(d); return addDays(s, -((s.getDay() + 6) % 7)) }

// What happens from `from` up to `to` (Dates): [{ key, id, title, start,
// end (Dates), allDay, color, place, page, repeats, day ("2026-10-05", the
// day it starts), event }], by when.
function occurrences(cal, from, to) {
  var out = []
  var events = cal && cal.events ? cal.events : []
  events.forEach(function(ev) {
    var s = startOf(ev)
    var length = endOf(ev) - s
    var offset = s - startOfDay(s)
    // (An event that started before `from` and goes on into it counts.)
    var look = new Date(from.getTime() - length)
    repeatDays(ev, look, to).forEach(function(d) {
      var key = dayIso(d)
      if (ev.skip.indexOf(key) >= 0) return
      var start = new Date(d.getTime() + offset)
      // (Days that are 23 or 25 hours long: the start at its own time of day.)
      if (!ev.allDay) start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), s.getHours(), s.getMinutes())
      var end = ev.allDay ? addDays(d, Math.round(length / DAY)) : new Date(start.getTime() + length)
      if (end <= from || start >= to) return
      out.push({ key: ev.id + "|" + key, id: ev.id, title: ev.title, start: start, end: end, allDay: ev.allDay, color: ev.color,
        place: ev.place, page: ev.page, repeats: !!ev.repeat, day: key, event: ev })
    })
  })
  return out.sort(function(a, b) {
    if (a.allDay !== b.allDay && dayIso(a.start) === dayIso(b.start)) return a.allDay ? -1 : 1
    return a.start - b.start || b.end - a.end || (a.title < b.title ? -1 : 1)
  })
}

// What's on a day (a Date): all-day ones first, then by time.
function onDay(list, d) {
  var lo = startOfDay(d)
  var hi = addDays(lo, 1)
  return list.filter(function(o) { return o.start < hi && o.end > lo })
}

// A day's timed events side by side where they overlap: each with its
// column and how many columns its group has, [{ occ, col, cols }].
function columns(list) {
  var timed = list.filter(function(o) { return !o.allDay }).slice().sort(function(a, b) { return a.start - b.start || b.end - a.end })
  var out = []
  var group = []
  var groupEnd = 0
  function close() {
    var cols = 0
    group.forEach(function(g) { cols = Math.max(cols, g.col + 1) })
    group.forEach(function(g) { g.cols = cols; out.push(g) })
    group = []
  }
  timed.forEach(function(o) {
    if (group.length && o.start >= groupEnd) close()
    var used = {}
    group.forEach(function(g) { if (g.occ.end > o.start) used[g.col] = true })
    var col = 0
    while (used[col]) col++
    group.push({ occ: o, col: col, cols: 1 })
    groupEnd = Math.max(groupEnd, o.end.getTime())
  })
  if (group.length) close()
  return out
}

// ---- reading what's typed -------------------------------------------------------------------

// "Lunch with Sam fri 12:30", "Dentist oct 12 3pm for 1 hour", "Standup
// tomorrow 9:30-9:45", "Holiday dec 24": { title, start, end, allDay }, or
// null when there's no day or time in it.
function quick(text, now, onDay) {
  var n = now || new Date()
  var t = String(text || "").replace(/\s+/g, " ").trim()
  if (!t) return null
  var minutes = -1
  // "for 30 min", "for 2 hours".
  var dur = /\s+for\s+(\d{1,3})\s*(m|min|mins|minutes?|h|hr|hrs|hours?)$/i.exec(t)
  if (dur) {
    minutes = Number(dur[1]) * (/^h/i.test(dur[2]) ? 60 : 1)
    t = t.slice(0, dur.index)
  }
  // "12:30-13:30", "9 to 10am": the end.
  var endTime = -1
  var range = /(\d{1,2}(?::\d{2})?\s*(?:am|pm|a|p)?)\s*(?:-|\u2013|to|until)\s*(\d{1,2}(?::\d{2})?\s*(?:am|pm|a|p)?)$/i.exec(t)
  if (range) {
    var a = range[1].trim()
    var b = range[2].trim()
    // "9-10am": the start's in the morning too.
    if (!/[ap]m?$/i.test(a) && /[ap]m?$/i.test(b)) a += b.replace(/^[\d:\s]+/, "")
    endTime = Dates.parseTime(b)
    if (endTime >= 0) t = t.slice(0, range.index) + a
  }
  var words = t.split(" ")
  var found = null
  var cut = -1
  // The longest day and time at the end ("... fri 12:30"), else at the start.
  for (var k = 1; k < words.length && !found; k++) {
    var p = Dates.parse(words.slice(k).join(" "), n)
    // A day name straight after "with" is someone's name; a later time can
    // still be when ("Meeting with Wednesday 1pm").
    if (p && words[k - 1].toLowerCase() !== "with") { found = p; cut = k }
  }
  var title = ""
  if (found) title = words.slice(0, cut).join(" ")
  else {
    for (var j = words.length - 1; j >= 1 && !found; j--) {
      var q = Dates.parse(words.slice(0, j).join(" "), n)
      if (q) { found = q; title = words.slice(j).join(" ") }
    }
  }
  if (!found) return null
  // A time alone, asked for on a day (a day clicked): on that day.
  if (found.onlyTime && onDay) found = { at: new Date(onDay.getFullYear(), onDay.getMonth(), onDay.getDate(), found.at.getHours(), found.at.getMinutes()), time: true }
  title = title.replace(/\s+(at|on|@|by|from)$/i, "").trim()
  if (!found.time) return { title: title, start: dayIso(found.at), end: dayIso(found.at), allDay: true }
  var start = found.at
  var end = new Date(start.getTime() + (minutes > 0 ? minutes : 60) * 60000)
  if (endTime >= 0) {
    end = new Date(start.getFullYear(), start.getMonth(), start.getDate(), Math.floor(endTime / 60), endTime % 60)
    if (end <= start) end = new Date(end.getTime() + DAY)
  }
  return { title: title, start: timeIso(start), end: timeIso(end), allDay: false }
}

// ---- changing it ---------------------------------------------------------------------------

// The calendar with an event put in (or put back in its place), a copy.
function withEvent(cal, ev) {
  var c = copy(cal)
  var clean = cleanEvent(ev)
  if (!clean) return c
  for (var i = 0; i < c.events.length; i++) if (c.events[i].id === clean.id) { c.events[i] = clean; return c }
  c.events.push(clean)
  return c
}

function without(cal, id) {
  var c = copy(cal)
  c.events = c.events.filter(function(e) { return e.id !== id })
  return c
}

// One time a repeating event happens, taken out of the repeat (skipped
// there) and made an event of its own, changed: [the calendar, its id].
function detach(cal, id, dayKey, changes) {
  var ev = byId(cal, id)
  if (!ev) return [copy(cal), ""]
  var c = copy(cal)
  var orig = byId(c, id)
  if (orig.skip.indexOf(dayKey) < 0) orig.skip.push(dayKey)
  orig.skip.sort()
  var occ = occurrences({ events: [ev] }, day(dayKey), addDays(day(dayKey), 1)).filter(function(o) { return o.day === dayKey })[0]
  var one = JSON.parse(JSON.stringify(ev))
  one.id = newId()
  one.repeat = null
  one.skip = []
  if (occ) {
    one.start = ev.allDay ? dayIso(occ.start) : timeIso(occ.start)
    one.end = ev.allDay ? dayIso(addDays(occ.end, -1)) : timeIso(occ.end)
  }
  for (var k in changes || {}) one[k] = changes[k]
  var clean = cleanEvent(one)
  if (clean) c.events.push(clean)
  return [c, clean ? clean.id : ""]
}

// A repeating event from a day on taken away (it ends the day before).
function endBefore(cal, id, dayKey) {
  var c = copy(cal)
  var ev = byId(c, id)
  if (!ev || !ev.repeat) return c
  if (dayIso(startOfDay(startOf(ev))) >= dayKey) return without(c, id)
  ev.repeat.until = dayIso(addDays(day(dayKey), -1))
  return c
}

// An event moved: its start to `start` ("2026-10-05" or "...T09:30"), its
// length kept (or its end at `end`).
function moved(ev, start, end) {
  var e = JSON.parse(JSON.stringify(ev))
  var s0 = startOf(ev)
  var to = Dates.fromIso(start)
  if (!to) return e
  if (ev.allDay) {
    // As many days long as it was.
    var days = Math.round((day(ev.end) - day(ev.start)) / DAY)
    e.start = dayIso(to.at)
    e.end = end ? end : dayIso(addDays(startOfDay(to.at), days))
  } else {
    var length = endOf(ev) - s0
    var st = to.time ? to.at : new Date(to.at.getFullYear(), to.at.getMonth(), to.at.getDate(), s0.getHours(), s0.getMinutes())
    e.start = timeIso(st)
    e.end = end ? end : timeIso(new Date(st.getTime() + length))
  }
  return e
}

// ---- alerts --------------------------------------------------------------------------------

// The alerts to come from `from` to `to`: [{ key, at, title, text, page,
// day }]. An all-day event's comes at 9 on its day (or before it).
function alerts(cal, from, to) {
  var out = []
  occurrences(cal, addDays(from, -2), addDays(to, 2)).forEach(function(o) {
    var mins = o.event.alert
    if (mins < 0) return
    var base = o.allDay ? new Date(o.start.getFullYear(), o.start.getMonth(), o.start.getDate(), Dates.MORNING, 0) : o.start
    var at = new Date(base.getTime() - mins * 60000)
    if (at < from || at >= to) return
    var when = o.allDay ? "Today" : (mins === 0 ? "Now" : mins >= 1440 ? "Tomorrow at " + Dates.clockOf(o.start) : "In " + (mins >= 60 ? mins / 60 + (mins === 60 ? " hour" : " hours") : mins + " min"))
    if (o.allDay && mins >= 1440) when = "Tomorrow"
    out.push({ key: "cal|" + o.key + "|" + mins, at: at, title: o.title || "An event", text: when + (o.allDay ? "" : ", " + Dates.clockOf(o.start)) + (o.place ? "  \u00b7  " + o.place : ""),
      page: o.page, day: o.day })
  })
  return out.sort(function(a, b) { return a.at - b.at })
}

// ---- iCalendar ----------------------------------------------------------------------------

function icsText(s) {
  return String(s || "").replace(/\\/g, "\\\\").replace(/;/g, "\\;").replace(/,/g, "\\,").replace(/\n/g, "\\n")
}

function icsDay(text) { return text.replace(/-/g, "") }
function icsTime(text) { return text.replace(/-/g, "").replace(":", "") + "00" }

// Lines folded at 75 characters, as the format has them.
function fold(line) {
  var out = []
  var s = line
  while (s.length > 75) { out.push(s.slice(0, 75)); s = " " + s.slice(75) }
  out.push(s)
  return out.join("\r\n")
}

// The calendar as an .ics file (times as the computer's own).
function toIcs(cal, now) {
  var stamp = (now || new Date()).toISOString().replace(/[-:]/g, "").replace(/\.\d+Z$/, "Z")
  var lines = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Uber Notebook//Calendar//EN", "CALSCALE:GREGORIAN"]
  var events = cal.events || []
  events.forEach(function(e) {
    lines.push("BEGIN:VEVENT")
    lines.push("UID:" + e.id + "@uber-notebook")
    lines.push("DTSTAMP:" + stamp)
    lines.push("SUMMARY:" + icsText(e.title || "Event"))
    if (e.allDay) {
      lines.push("DTSTART;VALUE=DATE:" + icsDay(e.start))
      lines.push("DTEND;VALUE=DATE:" + icsDay(dayIso(addDays(day(e.end), 1))))
    } else {
      lines.push("DTSTART:" + icsTime(e.start))
      lines.push("DTEND:" + icsTime(e.end))
    }
    if (e.repeat) {
      var freq = e.repeat.freq === "weekdays" ? "WEEKLY;BYDAY=MO,TU,WE,TH,FR" : e.repeat.freq.toUpperCase()
      var rule = "RRULE:FREQ=" + freq + (e.repeat.every > 1 ? ";INTERVAL=" + e.repeat.every : "")
      if (e.repeat.until) rule += ";UNTIL=" + icsDay(e.repeat.until) + (e.allDay ? "" : "T235959")
      lines.push(rule)
      e.skip.forEach(function(d) {
        lines.push(e.allDay ? "EXDATE;VALUE=DATE:" + icsDay(d) : "EXDATE:" + icsDay(d) + "T" + e.start.slice(11).replace(":", "") + "00")
      })
    }
    if (e.place) lines.push("LOCATION:" + icsText(e.place))
    if (e.detail) lines.push("DESCRIPTION:" + icsText(e.detail))
    if (e.alert >= 0) {
      lines.push("BEGIN:VALARM", "ACTION:DISPLAY", "DESCRIPTION:" + icsText(e.title || "Event"), "TRIGGER:-PT" + e.alert + "M", "END:VALARM")
    }
    lines.push("END:VEVENT")
  })
  lines.push("END:VCALENDAR")
  return lines.map(fold).join("\r\n") + "\r\n"
}

// An .ics file's events (a booking's flights, an invitation, another
// calendar's export), as the calendar keeps them, each with a new id:
// titles, all-day or timed (a time in UTC, "...Z", as the computer's own; one
// with a time zone, as written), places, notes, repeats (daily... yearly,
// every few, until; weekdays), days skipped. At most 2000.
function fromIcs(text) {
  var lines = String(text || "").replace(/\r\n?/g, "\n").replace(/\n[ \t]/g, "").split("\n")
  var out = []
  var ev = null
  function unescape(v) { return v.replace(/\\[nN]/g, "\n").replace(/\\([,;\\])/g, "$1") }
  // "20261011", "20261011T072500", "20261011T072500Z": { day: "2026-10-11", time: "07:25" or "" }.
  function when(v) {
    var m = /^(\d{4})(\d{2})(\d{2})(?:T(\d{2})(\d{2})(\d{2})?(Z)?)?$/.exec(String(v || "").trim())
    if (!m) return null
    if (!m[4]) return { day: m[1] + "-" + m[2] + "-" + m[3], time: "" }
    var d = m[7] ? new Date(Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5])) : new Date(+m[1], +m[2] - 1, +m[3], +m[4], +m[5])
    return { day: dayIso(d), time: pad(d.getHours()) + ":" + pad(d.getMinutes()) }
  }
  for (var i = 0; i < lines.length && out.length < 2000; i++) {
    var l = lines[i]
    var c = l.indexOf(":")
    if (c < 0) continue
    var head = l.slice(0, c).split(";")
    var name = head[0].toUpperCase()
    var value = l.slice(c + 1)
    if (name === "BEGIN" && value.trim().toUpperCase() === "VEVENT") { ev = { title: "", start: null, end: null, place: "", detail: "", rule: "", skip: [] }; continue }
    if (!ev) continue
    if (name === "END" && value.trim().toUpperCase() === "VEVENT") {
      if (ev.start) {
        var allDay = ev.start.time === ""
        var raw = { id: newId(), title: ev.title || "Event", allDay: allDay, place: ev.place, detail: ev.detail, alert: -1 }
        if (allDay) {
          raw.start = ev.start.day
          // (The file's end is the day after an all-day event's last.)
          var last = ev.end && ev.end.time === "" ? addDays(day(ev.end.day), -1) : day(ev.start.day)
          raw.end = dayIso(last < day(ev.start.day) ? day(ev.start.day) : last)
        } else {
          raw.start = ev.start.day + "T" + ev.start.time
          raw.end = ev.end && ev.end.time ? ev.end.day + "T" + ev.end.time : raw.start
        }
        var r = /FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)/i.exec(ev.rule)
        if (r) {
          var freq = r[1].toLowerCase()
          if (freq === "weekly" && /BYDAY=MO,TU,WE,TH,FR(;|$)/i.test(ev.rule)) freq = "weekdays"
          var every = /INTERVAL=(\d+)/i.exec(ev.rule)
          var until = when((/UNTIL=([0-9TZ]+)/i.exec(ev.rule) || [])[1])
          raw.repeat = { freq: freq, every: every ? +every[1] : 1, until: until ? until.day : "" }
          raw.skip = ev.skip
        }
        var clean = cleanEvent(raw)
        if (clean) out.push(clean)
      }
      ev = null
      continue
    }
    if (name === "SUMMARY") ev.title = unescape(value).trim()
    else if (name === "LOCATION") ev.place = unescape(value).trim()
    else if (name === "DESCRIPTION") ev.detail = unescape(value).trim()
    else if (name === "DTSTART") ev.start = when(value)
    else if (name === "DTEND") ev.end = when(value)
    else if (name === "RRULE") ev.rule = value
    else if (name === "EXDATE") value.split(",").forEach(function(v) { var w = when(v); if (w) ev.skip.push(w.day) })
  }
  return out
}

// Whether the calendar has an event like it already (its title, when it starts).
function hasLike(cal, ev) {
  return (cal && cal.events ? cal.events : []).some(function(e) { return e.title === ev.title && e.start === ev.start })
}

// ---- on a page -----------------------------------------------------------------------------

// What an agenda block (a day's events) or an event block keeps: { day
// ("" today, or "2026-10-05"), id (an event's), color, background }.
function cleanRef(raw) {
  var r = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  return { day: day(r.day) ? r.day : "", id: UUID.test(r.id) ? r.id : "", color: cleanColor(r.color), background: cleanColor(r.background) }
}

// The next time an event happens from `now` on (or its last), or null.
function nextOf(ev, now) {
  if (!ev) return null
  var n = now || new Date()
  var list = occurrences({ events: [ev] }, startOfDay(n), addDays(startOfDay(n), 400))
  if (list.length) return list[0]
  var all = occurrences({ events: [ev] }, startOf(ev), addDays(startOf(ev), 2))
  return all.length ? all[0] : null
}

// An event as a line: "Standup · Mon 5 Oct, 9:30 – 9:45".
function line(o, now) {
  if (!o) return ""
  return (o.title || "Untitled") + " \u00b7 " + Dates.label(o.start, false, now || new Date()) + (o.allDay ? "" : ", " + span(o))
}

// ---- how it's said ---------------------------------------------------------------------------

// A time as it's shown, on the clock you chose ("1:30 pm", "13:30").
function timeLabel(d) { return Dates.clockOf(d) }

// "9:30 - 10:00", "All day", "Until 10:00" (one that began the day before).
function span(o, onDayDate) {
  if (o.allDay) return "All day"
  var lo = onDayDate ? startOfDay(onDayDate) : startOfDay(o.start)
  var hi = addDays(lo, 1)
  var a = o.start < lo ? "" : timeLabel(o.start)
  var b = o.end > hi ? "" : timeLabel(o.end)
  if (!a && !b) return "All day"
  if (!a) return "Until " + b
  if (!b) return "From " + a
  return a + " \u2013 " + b
}

// "Every weekday", "Every 2 weeks, until 1 Dec"...
function repeatLabel(r) {
  if (!r) return "Doesn't repeat"
  var names = { daily: ["day", "days"], weekly: ["week", "weeks"], monthly: ["month", "months"], yearly: ["year", "years"] }
  var s = r.freq === "weekdays" ? (r.every > 1 ? "Weekdays, every " + r.every + " weeks" : "Every weekday")
    : r.every > 1 ? "Every " + r.every + " " + names[r.freq][1] : "Every " + names[r.freq][0]
  if (r.until) { var u = day(r.until); if (u) s += ", until " + u.getDate() + " " + Dates.SHORT_MONTHS[u.getMonth()] }
  return s
}
