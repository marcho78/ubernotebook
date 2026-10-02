// Meeting.js - meetings in Pages, recorded by voxtype's meeting mode. A
// meeting block keeps the voxtype meeting it is (its id: voxtype keeps the
// recording's transcript, and the block fetches it when the meeting ends),
// what voxtype wrote out, and the names you gave its speakers:
//
//   { id: "<voxtype's meeting id>", title: "Weekly sync",
//     startedAt: "2026-10-02T09:30:00Z", duration: 1830,
//     segments: [{ start: 1200, end: 5400, speaker: "You", text: "Morning..." }],
//     names: { "Remote": "Sam" }, open: true, color: "", background: "" }
//
// No id: it hasn't started. An id and no segments: it's being recorded (or
// it ended with nothing said). voxtype attributes speech to "You" (the
// microphone) and "Remote" (what the computer plays: the other side of a
// call), or SPEAKER_00, SPEAKER_01... with its speaker model.
//
// It reads what voxtype prints (its JSON export, its list of meetings, its
// meeting_state file), puts a meeting's words in turns, and writes them as
// text and Markdown. Shared with tests/meeting.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library
.import "Mindmap.js" as Mindmap
.import "Audio.js" as Audio

var MAX_SEGMENTS = 20000
var MAX_TEXT = 4000
var MAX_TITLE = 200
var MAX_NAMES = 40
var ID = /^[0-9a-fA-F-]{8,64}$/

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function cleanLine(value, max) {
  return String(typeof value === "string" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max)
}

function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

function cleanId(value) {
  var s = String(value || "").trim()
  return ID.test(s) ? s.toLowerCase() : ""
}

function make() {
  return { id: "", title: "", startedAt: "", duration: 0, segments: [], names: {}, open: true, color: "", background: "" }
}

// A meeting block's data as it may be used (null if it isn't an object).
function clean(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var out = make()
  out.id = cleanId(raw.id)
  out.title = cleanLine(raw.title, MAX_TITLE)
  var t = Date.parse(raw.startedAt)
  out.startedAt = typeof raw.startedAt === "string" && !isNaN(t) ? new Date(t).toISOString() : ""
  var d = Number(raw.duration)
  out.duration = isFinite(d) ? Math.round(clamp(d, 0, 48 * 3600)) : 0
  if (Array.isArray(raw.segments)) {
    raw.segments.slice(0, MAX_SEGMENTS).forEach(function(s) {
      if (!s || typeof s !== "object") return
      var text = cleanLine(s.text, MAX_TEXT)
      if (!text) return
      var start = Math.round(clamp(Number(s.start) || 0, 0, 48 * 3600000))
      var end = Math.round(clamp(Number(s.end) || start, start, 48 * 3600000))
      out.segments.push({ start: start, end: end, speaker: cleanLine(s.speaker, 60) || "You", text: text })
    })
  }
  if (raw.names && typeof raw.names === "object" && !Array.isArray(raw.names)) {
    Object.keys(raw.names).slice(0, MAX_NAMES).forEach(function(k) {
      var key = cleanLine(k, 60)
      var name = cleanLine(raw.names[k], 60)
      if (key && name && name !== key) out.names[key] = name
    })
  }
  out.open = raw.open !== false
  out.color = cleanColor(raw.color)
  out.background = cleanColor(raw.background)
  return out
}

// A block's data filled from voxtype's JSON export (keeping its names and
// colors), or null when it isn't one.
function fromExport(json, into) {
  var e = null
  try { e = typeof json === "string" ? JSON.parse(json) : json } catch (x) { return null }
  if (!e || typeof e !== "object" || !e.metadata || !e.transcript) return null
  var base = clean(into || {}) || make()
  var m = e.metadata
  var segs = Array.isArray(e.transcript.segments) ? e.transcript.segments : []
  base.id = cleanId(m.id) || base.id
  base.title = cleanLine(m.title, MAX_TITLE) || base.title
  base.startedAt = m.startedAt || base.startedAt
  var secs = Number(m.durationSecs)
  base.duration = isFinite(secs) && secs > 0 ? secs : Math.round((Number(e.transcript.durationMs) || 0) / 1000)
  base.segments = segs.map(function(s) {
    return { start: s.startMs, end: s.endMs, speaker: s.speaker || (s.source === "loopback" ? "Remote" : "You"), text: s.text }
  })
  return clean(base)
}

// What a speaker is called: the name you gave them, or voxtype's
// ("SPEAKER_01" as "Speaker 2").
function speakerName(meeting, speaker) {
  var names = meeting && meeting.names ? meeting.names : {}
  if (names[speaker]) return names[speaker]
  var m = /^SPEAKER_(\d+)$/.exec(speaker || "")
  return m ? "Speaker " + (Number(m[1]) + 1) : speaker || "You"
}

// The speakers, in the order they first spoke.
function speakers(meeting) {
  var out = []
  var list = meeting && meeting.segments ? meeting.segments : []
  list.forEach(function(s) { if (out.indexOf(s.speaker) < 0) out.push(s.speaker) })
  return out
}

// The words in turns: a speaker's segments one after another made one turn,
// [{ speaker, start (ms), text }].
function turns(meeting) {
  var out = []
  var list = meeting && meeting.segments ? meeting.segments : []
  list.forEach(function(s) {
    var last = out[out.length - 1]
    if (last && last.speaker === s.speaker && s.start - last.end < 15000) {
      last.text += " " + s.text
      last.end = s.end
    } else {
      out.push({ speaker: s.speaker, start: s.start, end: s.end, text: s.text })
    }
  })
  return out
}

// The transcript as text: "You (0:12): ..." a turn a line.
function text(meeting) {
  return turns(meeting).map(function(t) { return speakerName(meeting, t.speaker) + " (" + Audio.clock(t.start / 1000) + "): " + t.text }).join("\n")
}

// How many words were said.
function wordCount(meeting) {
  var n = 0
  var list = meeting && meeting.segments ? meeting.segments : []
  list.forEach(function(s) { n += s.text.split(/\s+/).filter(function(w) { return w !== "" }).length })
  return n
}

// The meeting as Markdown: its title and when, then its turns.
function toMarkdown(meeting) {
  var m = meeting || make()
  var head = "**\u{1f465} " + (m.title || "Meeting") + "**" + (m.duration ? " \u00b7 " + Audio.clock(m.duration) : "")
  if (!m.segments.length) return head + (m.id ? "\n\n*(Recorded with voxtype; nothing was written out yet.)*" : "")
  return head + "\n\n" + turns(m).map(function(t) {
    return "**" + speakerName(m, t.speaker) + "** (" + Audio.clock(t.start / 1000) + "): " + t.text
  }).join("\n\n")
}

// voxtype's meeting_state file ("recording\n<id>"): { status, id }.
function parseState(text) {
  var lines = String(text || "").trim().split("\n")
  var status = (lines[0] || "").trim().toLowerCase()
  if (["recording", "paused", "idle"].indexOf(status) < 0) status = "idle"
  return { status: status, id: cleanId(lines[1]) }
}

// `voxtype meeting list`: [{ id, title, date, duration, status }], newest first.
function parseList(text) {
  var out = []
  var cur = null
  String(text || "").split("\n").forEach(function(line) {
    var m = /^\s+(ID|Date|Duration|Status):\s*(.*)$/.exec(line)
    if (m && cur) {
      var key = m[1].toLowerCase()
      cur[key === "id" ? "id" : key] = key === "id" ? cleanId(m[2]) : cleanLine(m[2], 60)
      return
    }
    var t = line.trim()
    if (!t || /^=+$/.test(t) || t === "Recent Meetings" || /^No meetings/.test(t)) return
    if (!/^\s/.test(line)) {
      cur = { id: "", title: cleanLine(t, MAX_TITLE), date: "", duration: "", status: "" }
      out.push(cur)
    }
  })
  return out.filter(function(x) { return x.id !== "" })
}
