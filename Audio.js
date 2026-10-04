// Audio.js - audio notes and dictation in Pages. An audio block keeps its
// recording in Pages/assets (an Opus file), how long it is, its waveform (a
// level a bar, 0 to 100) and what was said in it, written out by voxtype;
// and its colors: the player's (its button, the part played) and its
// background, each one of Pages' colors or one of your own ("#ff8800"):
//
//   { src: "assets/audio-20261002-105312-k3f.ogg", duration: 42.5,
//     peaks: [12, 40, 88...], transcript: "Call the plumber...",
//     open: true, color: "blue", background: "" }
//
// A block with no recording yet (src "") offers to record one.
//
// It reads the levels ffmpeg prints while it records, makes a waveform of
// them, cleans what voxtype prints into the words said, and says how long
// a recording is. Shared with tests/audio.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library
.import "Mindmap.js" as Mindmap

var MAX_DURATION = 6 * 3600
var MAX_PEAKS = 400
var MAX_TRANSCRIPT = 200000
// How long a recording may go on (seconds): dictation, an audio note, a
// test of the microphone (Settings).
var LIMITS = { dictation: 600, audio: 3 * 3600, test: 8 }
// Levels a second, as ffmpeg measures them while it records.
var RATE = 10
// The quietest level (dBFS) that shows, and the loudest.
var FLOOR = -55
var CEIL = -5

function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, v)) }

function cleanSrc(src) {
  var s = typeof src === "string" ? src : ""
  return /^assets\/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(s) && s.indexOf("..") < 0 ? s : ""
}

function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

function make() {
  return { src: "", duration: 0, peaks: [], transcript: "", open: true, color: "", background: "" }
}

// An audio block's data as it may be used (null if it isn't an object).
function clean(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var out = make()
  out.src = cleanSrc(raw.src)
  var d = Number(raw.duration)
  out.duration = isFinite(d) ? Math.round(clamp(d, 0, MAX_DURATION) * 10) / 10 : 0
  if (Array.isArray(raw.peaks)) {
    out.peaks = raw.peaks.slice(0, MAX_PEAKS).map(function(p) {
      var n = Number(p)
      return isFinite(n) ? Math.round(clamp(n, 0, 100)) : 0
    })
  }
  out.transcript = typeof raw.transcript === "string" ? raw.transcript.replace(/\r\n?/g, "\n").slice(0, MAX_TRANSCRIPT) : ""
  out.open = raw.open !== false
  out.color = cleanColor(raw.color)
  out.background = cleanColor(raw.background)
  return out
}

// A level ffmpeg measured (dBFS) as 0 to 1.
function levelOf(db) {
  var n = Number(db)
  if (!isFinite(n)) return 0
  return clamp((n - FLOOR) / (CEIL - FLOOR), 0, 1)
}

// The level on one line ffmpeg prints ("lavfi.astats.Overall.RMS_level=-23.4"),
// or -1 when it isn't one.
function levelIn(line) {
  var m = /lavfi\.astats\.Overall\.RMS_level=(-?inf|-?[0-9.]+)/.exec(String(line || ""))
  if (!m) return -1
  return /inf/.test(m[1]) ? 0 : levelOf(m[1])
}

// Every level in what ffmpeg printed.
function levelsIn(text) {
  var out = []
  String(text || "").split("\n").forEach(function(line) {
    var v = levelIn(line)
    if (v >= 0) out.push(v)
  })
  return out
}

// A waveform of `n` bars (0 to 100) from levels (0 to 1): each bar the
// loudest of its share, so a short word still shows.
function peaks(levels, n) {
  var list = Array.isArray(levels) ? levels : []
  var count = Math.max(1, Math.min(MAX_PEAKS, Math.round(n || 120)))
  if (list.length === 0) return []
  if (list.length <= count) return list.map(function(v) { return Math.round(clamp(v, 0, 1) * 100) })
  var out = []
  for (var i = 0; i < count; i++) {
    var a = Math.floor(i * list.length / count)
    var b = Math.max(a + 1, Math.floor((i + 1) * list.length / count))
    var top = 0
    for (var k = a; k < b; k++) top = Math.max(top, list[k])
    out.push(Math.round(clamp(top, 0, 1) * 100))
  }
  return out
}

// A waveform as `count` bars, to fit the room there is: stretched or squeezed
// (each bar the loudest of its share).
function fit(list, count) {
  var src = Array.isArray(list) ? list : []
  var n = Math.max(1, Math.floor(count))
  if (src.length === 0) return []
  var out = []
  for (var i = 0; i < n; i++) {
    var a = Math.floor(i * src.length / n)
    var b = Math.max(a + 1, Math.floor((i + 1) * src.length / n))
    var top = 0
    for (var k = a; k < b && k < src.length; k++) top = Math.max(top, src[k])
    out.push(top)
  }
  return out
}

// What voxtype printed, as the words said: not its own lines ("Loading
// audio file", "Processing ..." and log lines), not Whisper's marks for
// silence or music.
function transcriptOf(output) {
  var text = String(output || "").replace(/\u001b\[[0-9;]*m/g, "")
  var lines = text.split("\n").filter(function(line) {
    var t = line.trim()
    if (/^Loading audio file:/.test(t) || /^Audio format:/.test(t) || /^Processing \d+ samples/.test(t)) return false
    if (/^\d{4}-\d\d-\d\dT[0-9:.]+Z?\s+(TRACE|DEBUG|INFO|WARN|ERROR)\b/.test(t)) return false
    if (/^whisper_|^ggml_|^AMX /.test(t)) return false
    return true
  })
  var words = lines.join("\n")
    .replace(/\[(BLANK_AUDIO|blank_audio|Silence|silence|MUSIC|Music|music|Applause|Laughter|NO SPEECH|inaudible)\]/g, "")
    .replace(/\((silence|music|Music|Silence|inaudible|no speech)\)/g, "")
  return words.split("\n").map(function(l) { return l.replace(/[ \t]+/g, " ").trim() }).filter(function(l) { return l !== "" }).join("\n").trim()
}

// How long, as a player says it: "0:07", "12:03", "1:02:03".
function clock(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  var h = Math.floor(s / 3600)
  var m = Math.floor((s % 3600) / 60)
  var r = s % 60
  return (h ? h + ":" + (m < 10 ? "0" : "") : "") + m + ":" + (r < 10 ? "0" : "") + r
}

// A new recording's file name in assets: "audio-20261002-105312-k3f.ogg".
function fileName(now, salt) {
  var d = now || new Date()
  function two(n) { return (n < 10 ? "0" : "") + n }
  var tail = String(salt || Math.random().toString(36).slice(2, 5)).replace(/[^a-z0-9]/g, "").slice(0, 6) || "a"
  return "audio-" + d.getFullYear() + two(d.getMonth() + 1) + two(d.getDate()) + "-" + two(d.getHours()) + two(d.getMinutes()) + two(d.getSeconds()) + "-" + tail + ".ogg"
}

// Words put in where the cursor is: a space before them when what's before
// isn't one (or the start), none after.
function joinAfter(before, words) {
  var w = String(words || "").replace(/\s+/g, " ").trim()
  if (!w) return ""
  var b = String(before || "")
  return b === "" || /[\s(\[{"'\u201c\u2018\/-]$/.test(b) ? w : " " + w
}

// ---- recording -----------------------------------------------------------------------------

// A voice made loud enough (Settings: "Make my voice louder"): the rumble
// under it cut, its level evened out (a quiet laptop microphone up to 30 dB
// louder, the hiss between words left where it was), its peaks kept from
// clipping. It looks a second ahead, so it's put on a recording once it's
// done (ffmpeg drops what it holds when it's stopped).
var BOOST = "highpass=f=80,dynaudnorm=f=150:g=15:p=0.95:m=30,alimiter=limit=0.95"
// The same, quicker to follow you, for the level shown as it records.
var METER_BOOST = "highpass=f=80,dynaudnorm=f=100:g=3:p=0.95:m=30"

// A microphone's name as PipeWire's Pulse server has it, or "" (the default).
function cleanInput(name) {
  var s = String(name || "")
  return /^[A-Za-z0-9][A-Za-z0-9._:@+-]{0,199}$/.test(s) ? s : ""
}

// The microphones in what `pactl -f json list sources` printed: [{ name,
// label }], not the monitors of what's playing.
function sourcesOf(json) {
  var list = []
  try { list = JSON.parse(String(json || "")) } catch (e) { return [] }
  if (!Array.isArray(list)) return []
  return list.filter(function(s) {
    return s && cleanInput(s.name) && !s.monitor_of_sink && !/\.monitor$/.test(s.name)
  }).map(function(s) {
    return { name: s.name, label: String(s.description || s.name).slice(0, 120) }
  })
}

// The ffmpeg command that records from a microphone (`options.input`, or the
// default one: PipeWire's, through its Pulse server), printing its level ten
// times a second: to a 16 kHz WAV for voxtype (dictation), an Opus file (an
// audio note), or nowhere (a test). `options.boost`: the level shown is the
// voice made louder, as it will be.
function recordCommand(kind, file, options) {
  var o = options || {}
  var input = cleanInput(o.input) || "default"
  var limit = String(LIMITS[kind] || LIMITS.audio)
  var graph = "[0:a]aformat=sample_fmts=fltp:channel_layouts=mono,asplit=2[o][m];"
    + "[m]" + (o.boost ? METER_BOOST + "," : "") + "aresample=16000,asetnsamples=n=" + (16000 / RATE) + ":p=0,"
    + "astats=metadata=1:reset=1:measure_perchannel=none:measure_overall=RMS_level,"
    + "ametadata=mode=print:file=/dev/stdout:direct=1,anullsink"
  var out = kind === "dictation" ? ["-map", "[o]", "-ar", "16000", "-c:a", "pcm_s16le", file]
    : kind === "test" ? ["-map", "[o]", "-f", "null", "-"]
    : ["-map", "[o]", "-c:a", "libopus", "-b:a", o.boost ? "64k" : "32k", "-application", "voip", file]
  return ["/usr/bin/ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
    "-f", "pulse", "-i", input, "-t", limit, "-filter_complex", graph].concat(out)
}

// What ffmpeg may read a recording as: a file on this computer (nothing it
// names elsewhere), in one of these formats (not a playlist or a list of
// other files).
var FILE_ONLY = "-protocol_whitelist file -format_whitelist ogg,wav,mp3,flac,matroska,mov,aac,w64,caf,aiff,amr"

// A shell script that makes a recording louder (BOOST) into a new Opus file:
// arguments the recording, the new file, the filter. With "keep" as the
// fourth, the recording stays (a note made louder later, which Undo takes
// back); else it goes once the new file is made, or becomes it if that
// fails. Then it prints the new file's levels (for its waveform).
var LOUDER_SCRIPT = "/usr/bin/ffmpeg -hide_banner -loglevel error -nostdin -y " + FILE_ONLY + " -i \"$1\" -af \"$3\" -c:a libopus -b:a 32k -application voip \"$2\"; s=$?; "
  + "if [ \"$4\" != keep ]; then if [ $s -eq 0 ]; then /usr/bin/rm -f -- \"$1\"; else /usr/bin/mv -f -- \"$1\" \"$2\" || exit 3; fi; elif [ $s -ne 0 ]; then exit 3; fi; "
  + "/usr/bin/ffmpeg -hide_banner -loglevel error -nostdin " + FILE_ONLY + " -i \"$2\" -filter_complex "
  + "\"[0:a]aformat=channel_layouts=mono,aresample=16000,asetnsamples=n=1600:p=0,astats=metadata=1:reset=1:measure_perchannel=none:measure_overall=RMS_level,ametadata=mode=print:file=/dev/stdout\" -f null -; exit 0"

// A shell script that writes out a recording with voxtype: an Opus file
// (or any audio) made a 16 kHz WAV first (through a filter, if one's given),
// the WAV taken away after. Arguments: the file, a WAV to make (or "" when
// the file is one already, as it is), the filter (or "").
var TRANSCRIBE_SCRIPT = "in=\"$1\"; wav=\"$2\"; af=\"${3:-anull}\"; "
  + "if [ -n \"$wav\" ]; then /usr/bin/ffmpeg -hide_banner -loglevel error -nostdin -y " + FILE_ONLY + " -i \"$in\" -af \"$af\" -ar 16000 -ac 1 -c:a pcm_s16le \"$wav\" || exit 3; in=\"$wav\"; fi; "
  + "/usr/bin/voxtype -q transcribe \"$in\" 2>/dev/null; s=$?; [ -n \"$wav\" ] && /usr/bin/rm -f -- \"$wav\"; exit $s"

// What a test of the microphone heard (its levels, as the meter shows them):
// "silent" (nothing, or close to it), "quiet", "good" or "loud" (it may distort).
function verdict(levels) {
  var list = (Array.isArray(levels) ? levels : []).slice().sort(function(a, b) { return a - b })
  if (list.length === 0) return "silent"
  var top = list[Math.min(list.length - 1, Math.floor(list.length * 0.9))]
  return top < 0.12 ? "silent" : top < 0.4 ? "quiet" : top > 0.97 ? "loud" : "good"
}

// A recording that's quiet (its waveform's loudest bar), worth making louder.
function isQuiet(peaks) {
  var list = Array.isArray(peaks) ? peaks : []
  if (list.length === 0) return false
  return Math.max.apply(null, list) < 60
}

// How long transcribing may take (ms): the model loading, then a good deal
// slower than the recording on a slow machine.
function transcribeTimeout(seconds) {
  return Math.round(120000 + Math.max(0, Number(seconds) || 0) * 2000)
}
