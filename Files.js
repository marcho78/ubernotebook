// Files.js - files on a page in Pages: any file (a PDF shown page by page),
// and videos. The file is copied into Pages/assets (named so a page can't
// point outside it), and the block keeps what it was called:
//
//   { src: "assets/file-20261002-103012-k3f-report.pdf", name: "Q3 report.pdf",
//     size: 182344, kind: "pdf", open: true, height: 560, color: "", background: "" }
//
// Shared with tests/files.test.cjs, so keep it plain JavaScript with no QML
// or Node APIs.
.pragma library
.import "Mindmap.js" as Mindmap

var KINDS = {
  pdf: ["pdf"],
  video: ["mp4", "m4v", "mov", "webm", "mkv", "avi", "ogv"],
  audio: ["mp3", "ogg", "opus", "wav", "flac", "m4a", "aac"],
  image: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "svg"],
  doc: ["doc", "docx", "odt", "rtf", "md", "txt", "pages"],
  sheet: ["xls", "xlsx", "ods", "csv", "tsv", "numbers"],
  slides: ["ppt", "pptx", "odp", "key"],
  archive: ["zip", "tar", "gz", "tgz", "bz2", "xz", "7z", "rar", "zst"],
  code: ["js", "ts", "py", "rs", "go", "c", "h", "cpp", "java", "rb", "sh", "json", "yaml", "yml", "toml", "html", "css", "qml", "lua"]
}
var MAX_HEIGHT = 2000

function cleanColor(value) {
  if (value === "" || value === undefined || value === null) return ""
  return Mindmap.cleanColor(value)
}

function cleanSrc(src) {
  var s = typeof src === "string" ? src : ""
  return /^assets\/[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/.test(s) && s.indexOf("..") < 0 ? s : ""
}

function extOf(name) {
  var m = /\.([A-Za-z0-9]{1,8})$/.exec(String(name || ""))
  return m ? m[1].toLowerCase() : ""
}

// What a file is, by its name: pdf, video, audio, image, doc, sheet,
// slides, archive, code or other.
function kindOf(name) {
  var e = extOf(name)
  for (var k in KINDS) if (KINDS[k].indexOf(e) >= 0) return k
  return "other"
}

function make() { return { src: "", name: "", size: 0, kind: "other", open: true, height: 560, poster: "", color: "", background: "" } }

function clean(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var out = make()
  out.src = cleanSrc(raw.src)
  out.name = String(typeof raw.name === "string" ? raw.name : "").replace(/[\u0000-\u001f\u007f\/\\]+/g, " ").trim().slice(0, 200)
  var n = Number(raw.size)
  out.size = isFinite(n) && n > 0 ? Math.round(n) : 0
  out.kind = KINDS[raw.kind] ? raw.kind : kindOf(out.name || out.src)
  out.open = raw.open !== false
  var h = Number(raw.height)
  out.height = isFinite(h) && h >= 160 ? Math.round(Math.min(MAX_HEIGHT, h)) : 560
  // A video's still (a frame from it, made when it was added).
  out.poster = cleanSrc(raw.poster)
  out.color = cleanColor(raw.color)
  out.background = cleanColor(raw.background)
  return out
}

// "182 KB", "3.4 MB".
function sizeLabel(bytes) {
  var b = Number(bytes) || 0
  if (b < 1024) return b + " B"
  if (b < 1024 * 1024) return Math.round(b / 1024) + " KB"
  if (b < 1024 * 1024 * 1024) return (Math.round(b / 1024 / 1024 * 10) / 10) + " MB"
  return (Math.round(b / 1024 / 1024 / 1024 * 10) / 10) + " GB"
}

// A copy's name in assets: "file-20261002-103012-k3f-q3-report.pdf".
function assetName(original, now, salt) {
  var d = now || new Date()
  function two(n) { return (n < 10 ? "0" : "") + n }
  var tail = String(salt || Math.random().toString(36).slice(2, 5)).replace(/[^a-z0-9]/g, "").slice(0, 6) || "a"
  var ext = extOf(original)
  var base = String(original || "file").replace(/\.[A-Za-z0-9]{1,8}$/, "").toLowerCase().replace(/[^a-z0-9._-]+/g, "-").replace(/^[-._]+|[-._]+$/g, "").slice(0, 60) || "file"
  return "file-" + d.getFullYear() + two(d.getMonth() + 1) + two(d.getDate()) + "-" + two(d.getHours()) + two(d.getMinutes()) + two(d.getSeconds()) + "-" + tail + "-" + base + (ext ? "." + ext : "")
}

// As Markdown: a link to it (a video's too).
function toMarkdown(f, prefix) {
  if (!f || !f.src) return "*(A file, not added yet)*"
  var icon = f.kind === "video" ? "\u{1f3ac}" : "\u{1f4ce}"
  return "[" + icon + " " + (f.name || "File").replace(/[\[\]]/g, "") + "](" + (prefix || "") + f.src + ")" + (f.size ? " (" + sizeLabel(f.size) + ")" : "")
}
