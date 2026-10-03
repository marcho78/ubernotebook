// Dates.js - dates written into Pages with "@": what's typed after the "@"
// ("tomorrow 9am", "fri", "in 2 hours", "oct 3", "2026-10-05") read as a
// date (and a time, if it has one), the suggestions the "@" menu offers, how
// a date is written on the page, and the links that carry it:
//
//   omanote://date/2026-10-05          a date
//   omanote://date/2026-10-05T09:30    a date and time
//   omanote://remind/2026-10-05T09:30  a reminder then (a notification comes)
//
// Shared by the editor (app/Editor.qml), the workspace and tests/dates.test.cjs,
// so keep it plain JavaScript with no QML or Node APIs.
.pragma library

var DAYS = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
var MONTHS = ["january", "february", "march", "april", "may", "june", "july", "august", "september", "october", "november", "december"]
var SHORT_DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
var SHORT_MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
// When a reminder with no time of its own comes: 9 in the morning.
var MORNING = 9

function pad(n) { return (n < 10 ? "0" : "") + n }

function startOfDay(d) { return new Date(d.getFullYear(), d.getMonth(), d.getDate()) }

function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n, d.getHours(), d.getMinutes()) }

// A day's name (or the start of it: "wed", "thurs") -> 0..6, or -1.
function dayIndex(word) {
  var w = String(word || "").toLowerCase()
  if (w.length < 2) return -1
  for (var i = 0; i < DAYS.length; i++) if (DAYS[i].indexOf(w) === 0) return i
  return -1
}

function monthIndex(word) {
  var w = String(word || "").toLowerCase().replace(/\.$/, "")
  if (w.length < 3) return -1
  for (var i = 0; i < MONTHS.length; i++) if (MONTHS[i].indexOf(w) === 0) return i
  return -1
}

// A time of day: "9", "9am", "9:30", "9.30pm", "21:00", "noon", "midnight"
// -> minutes after midnight, or -1.
function parseTime(text) {
  var t = String(text || "").toLowerCase().replace(/\s+/g, "")
  if (t === "noon") return 12 * 60
  if (t === "midnight") return 0
  var m = /^(\d{1,2})(?:[:.](\d{2}))?(am|pm|a|p)?$/.exec(t)
  if (!m) return -1
  var h = Number(m[1])
  var min = m[2] ? Number(m[2]) : 0
  if (min > 59) return -1
  if (m[3]) {
    if (h < 1 || h > 12) return -1
    if (m[3].charAt(0) === "p" && h < 12) h += 12
    if (m[3].charAt(0) === "a" && h === 12) h = 0
  } else if (h > 23) {
    return -1
  }
  return h * 60 + min
}

// What's typed after "@", read as { at: Date, time: bool }, or null.
// `now` is when it's read.
function parse(text, now) {
  var n = now || new Date()
  var words = String(text || "").toLowerCase().replace(/,/g, " ").trim().split(/\s+/).filter(function(w) { return w.length > 0 })
  if (words.length === 0) return null
  var day = null
  var minutes = -1
  var i = 0
  function rest() { return words.slice(i).join(" ") }

  // "in 3 days", "in 2 weeks", "in 2 hours", "in 30 min"
  if (words[0] === "in" && words.length >= 3 && /^\d{1,3}$/.test(words[1])) {
    var k = Number(words[1])
    var unit = words[2]
    if (/^(min|mins|minute|minutes)$/.test(unit)) return { at: new Date(n.getTime() + k * 60000), time: true }
    if (/^(h|hr|hrs|hour|hours)$/.test(unit)) return { at: new Date(n.getTime() + k * 3600000), time: true }
    if (/^(day|days)$/.test(unit)) day = addDays(startOfDay(n), k)
    else if (/^(week|weeks)$/.test(unit)) day = addDays(startOfDay(n), 7 * k)
    else if (/^(month|months)$/.test(unit)) day = new Date(n.getFullYear(), n.getMonth() + k, n.getDate())
    else return null
    i = 3
  } else if (words[0] === "today" || words[0] === "tod") { day = startOfDay(n); i = 1 }
  else if (words[0] === "tonight") { day = startOfDay(n); minutes = 20 * 60; i = 1 }
  else if (words[0] === "tomorrow" || words[0] === "tmr" || words[0] === "tom") { day = addDays(startOfDay(n), 1); i = 1 }
  else if (words[0] === "yesterday") { day = addDays(startOfDay(n), -1); i = 1 }
  else if (words[0] === "next" && words[1] === "week") { day = addDays(startOfDay(n), 7 - (n.getDay() + 6) % 7); i = 2 }
  else if (words[0] === "next" && words[1] === "month") { day = new Date(n.getFullYear(), n.getMonth() + 1, 1); i = 2 }
  else if ((words[0] === "next" || words[0] === "this") && dayIndex(words[1]) >= 0) {
    var target = dayIndex(words[1])
    var ahead = (target - n.getDay() + 7) % 7
    if (words[0] === "next" && ahead === 0) ahead = 7
    day = addDays(startOfDay(n), ahead)
    i = 2
  } else if (dayIndex(words[0]) >= 0 && monthIndex(words[0]) < 0) {
    var d0 = dayIndex(words[0])
    var diff = (d0 - n.getDay() + 7) % 7
    day = addDays(startOfDay(n), diff === 0 ? 7 : diff)
    i = 1
  } else if (/^\d{4}-\d{2}-\d{2}(t\d{2}:\d{2})?$/.test(words[0])) {
    var iso = fromIso(words[0].replace("t", "T"))
    if (!iso) return null
    if (iso.time) return iso
    day = iso.at
    i = 1
  } else {
    // "oct 3", "3 oct", "october 3 2027", "3 october"
    var mo = -1
    var dd = -1
    var yy = -1
    if (monthIndex(words[0]) >= 0 && /^\d{1,2}(st|nd|rd|th)?$/.test(words[1] || "")) { mo = monthIndex(words[0]); dd = parseInt(words[1], 10); i = 2 }
    else if (/^\d{1,2}(st|nd|rd|th)?$/.test(words[0]) && monthIndex(words[1] || "") >= 0) { dd = parseInt(words[0], 10); mo = monthIndex(words[1]); i = 2 }
    if (mo < 0) {
      // Just a time: today at it (or tomorrow, if that's gone by).
      var only = parseTime(rest())
      if (only < 0) return null
      var at = new Date(n.getFullYear(), n.getMonth(), n.getDate(), Math.floor(only / 60), only % 60)
      if (at < n) at = addDays(at, 1)
      return { at: at, time: true, onlyTime: true }
    }
    if (/^\d{4}$/.test(words[i] || "")) { yy = Number(words[i]); i++ }
    var year = yy > 0 ? yy : n.getFullYear()
    day = new Date(year, mo, dd)
    if (day.getMonth() !== mo) return null
    // A date without a year that's gone by this year is next year's.
    if (yy < 0 && day < startOfDay(n)) day = new Date(year + 1, mo, dd)
  }
  // Then, maybe, a time: "9am", "at 9:30".
  if (words[i] === "at") i++
  if (i < words.length) {
    var tm = parseTime(rest())
    if (tm < 0) return null
    minutes = tm
  }
  if (minutes >= 0) return { at: new Date(day.getFullYear(), day.getMonth(), day.getDate(), Math.floor(minutes / 60), minutes % 60), time: true }
  return { at: day, time: false }
}

// ---- writing it down ------------------------------------------------------------------

function iso(at, time) {
  var d = at.getFullYear() + "-" + pad(at.getMonth() + 1) + "-" + pad(at.getDate())
  return time ? d + "T" + pad(at.getHours()) + ":" + pad(at.getMinutes()) : d
}

// "2026-10-05" or "2026-10-05T09:30" -> { at, time }, or null.
function fromIso(text) {
  var m = /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}))?$/.exec(String(text || ""))
  if (!m) return null
  var at = new Date(Number(m[1]), Number(m[2]) - 1, Number(m[3]), m[4] ? Number(m[4]) : 0, m[5] ? Number(m[5]) : 0)
  if (at.getMonth() !== Number(m[2]) - 1 || at.getDate() !== Number(m[3])) return null
  if (m[4] && (Number(m[4]) > 23 || Number(m[5]) > 59)) return null
  return { at: at, time: !!m[4] }
}

// How a date is written on the page: "Thu 1 Oct", "Thu 1 Oct 9:30", with
// the year when it isn't this year's.
function label(at, time, now) {
  var n = now || new Date()
  var s = SHORT_DAYS[at.getDay()] + " " + at.getDate() + " " + SHORT_MONTHS[at.getMonth()]
  if (at.getFullYear() !== n.getFullYear()) s += " " + at.getFullYear()
  if (time) s += " " + at.getHours() + ":" + pad(at.getMinutes())
  return s
}

function href(at, time, remind) {
  return "omanote://" + (remind ? "remind" : "date") + "/" + iso(at, time)
}

// "omanote://remind/2026-10-05T09:30" -> { remind, at, time }, or null.
function fromHref(url) {
  var m = /^omanote:\/\/(date|remind)\/([0-9T:-]{10,16})$/.exec(String(url || ""))
  if (!m) return null
  var d = fromIso(m[2])
  if (!d) return null
  return { remind: m[1] === "remind", at: d.at, time: d.time }
}

// When a reminder comes: its time, or 9 in the morning on its day.
function remindAt(at, time) {
  return time ? at : new Date(at.getFullYear(), at.getMonth(), at.getDate(), MORNING, 0)
}

// ---- the "@" menu -----------------------------------------------------------------------

// What "@" offers for what's typed after it: [{ label, hint, at, time, remind }].
function suggestions(text, now) {
  var n = now || new Date()
  var q = String(text || "").trim()
  var out = []
  function add(d, remind) {
    if (!d) return
    out.push({ label: (remind ? "Remind me " : "") + label(d.at, d.time, n), hint: remind ? "A notification then" : (d.time ? "Date and time" : "Date"), at: iso(d.at, d.time), time: d.time, remind: remind })
  }
  if (!q) {
    add({ at: startOfDay(n), time: false }, false)
    add({ at: addDays(startOfDay(n), 1), time: false }, false)
    add(parse("next monday", n), false)
    add(parse("tomorrow 9am", n), true)
    add({ at: new Date(n.getTime() + 3600000), time: true }, true)
    return out
  }
  var d = parse(q, n)
  if (!d) return []
  add(d, false)
  add(d, true)
  return out
}
