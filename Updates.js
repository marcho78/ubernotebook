// Updates.js - whether there's a newer Uber Notebook, and what's in it: the
// project's releases on GitHub (the manifest's homepage), compared with the
// version running, and each newer one's notes; the notes of the version
// running come from CHANGELOG.md, which comes with it.
//
// Shared by Updates.qml and tests/updates.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library

// "1.2.3", "v1.2", "1.2.3-beta.1": { nums: [1, 2, 3], pre: ["beta", 1] }, or null.
function parse(v) {
  var m = /^v?(\d{1,6})(?:\.(\d{1,6}))?(?:\.(\d{1,6}))?(?:-([0-9A-Za-z.-]+))?(?:\+[0-9A-Za-z.-]+)?$/.exec(String(v === undefined || v === null ? "" : v).trim())
  if (!m) return null
  return {
    nums: [Number(m[1]), Number(m[2] || 0), Number(m[3] || 0)],
    pre: m[4] ? m[4].split(".").map(function(p) { return /^\d+$/.test(p) ? Number(p) : p }) : []
  }
}

// -1, 0 or 1, as semantic versions compare (a version that can't be read
// is older than any that can).
function compare(a, b) {
  var x = parse(a), y = parse(b)
  if (!x || !y) return x ? 1 : y ? -1 : 0
  for (var i = 0; i < 3; i++) if (x.nums[i] !== y.nums[i]) return x.nums[i] < y.nums[i] ? -1 : 1
  if (!x.pre.length || !y.pre.length) return x.pre.length === y.pre.length ? 0 : x.pre.length ? -1 : 1
  for (var k = 0; k < Math.max(x.pre.length, y.pre.length); k++) {
    if (k >= x.pre.length) return -1
    if (k >= y.pre.length) return 1
    var p = x.pre[k], q = y.pre[k]
    if (p === q) continue
    if (typeof p === "number" && typeof q === "number") return p < q ? -1 : 1
    if (typeof p === "number") return -1
    if (typeof q === "number") return 1
    return p < q ? -1 : 1
  }
  return 0
}

// "https://github.com/owner/repo" (or .git, or a trailing slash): "owner/repo"; else "".
function repoOf(homepage) {
  var m = /^https:\/\/github\.com\/([A-Za-z0-9_.-]{1,100})\/([A-Za-z0-9_.-]{1,100}?)(?:\.git)?\/?$/.exec(String(homepage || "").trim())
  return m ? m[1] + "/" + m[2] : ""
}

// The address of a repository's releases, on GitHub's API.
function releasesUrl(repo) { return "https://api.github.com/repos/" + repo + "/releases?per_page=30" }

// Release notes as Uber Notebook shows them: Markdown, with no pictures or HTML
// (nothing in them fetched from anywhere), not too long.
function cleanNotes(md) {
  var t = String(md || "").replace(/\r\n?/g, "\n")
  t = t.replace(/!\[[^\]]*\]\([^)]*\)/g, "")
  t = t.replace(/<!--[\s\S]*?-->/g, "")
  t = t.replace(/<\/?[A-Za-z][^>]*>/g, "")
  t = t.replace(/\n{3,}/g, "\n\n").trim()
  return t.length > 20000 ? t.slice(0, 20000) + "\n\n…" : t
}

// curl's answer (the body, then the HTTP status on a line of its own):
// { code, body }.
function response(output) {
  var text = String(output || "")
  var cut = text.lastIndexOf("\n")
  var code = Number(text.slice(cut + 1).trim())
  return { code: isFinite(code) ? code : 0, body: cut >= 0 ? text.slice(0, cut) : "" }
}

// GitHub's releases (its JSON), the published ones that aren't
// pre-releases, newest first: [{ version, tag, name, notes, url, date }].
function releases(json) {
  var list = null
  try { list = JSON.parse(String(json || "")) } catch (e) { return null }
  if (!Array.isArray(list)) return null
  return list.filter(function(r) {
    return r && typeof r === "object" && !r.draft && !r.prerelease && parse(r.tag_name) !== null
  }).map(function(r) {
    var v = String(r.tag_name).trim().replace(/^v/, "")
    var url = typeof r.html_url === "string" && /^https:\/\/github\.com\//.test(r.html_url) ? r.html_url : ""
    return {
      version: v,
      tag: String(r.tag_name),
      name: typeof r.name === "string" ? r.name.replace(/[\u0000-\u001f]+/g, " ").trim().slice(0, 120) : "",
      notes: cleanNotes(r.body),
      url: url,
      date: typeof r.published_at === "string" ? r.published_at : ""
    }
  }).sort(function(a, b) { return compare(b.version, a.version) })
}

// The ones newer than `current`, newest first.
function newer(list, current) {
  return (list || []).filter(function(r) { return compare(r.version, current) > 0 })
}

// What's new, as Markdown: one release's notes, or several, each under
// its own heading.
function combined(list) {
  var l = list || []
  if (l.length === 1) return l[0].notes || "No notes for this release."
  return l.map(function(r) {
    var title = r.name && r.name !== r.tag && r.name !== r.version ? r.name : "Version " + r.version
    var when = r.date && !isNaN(Date.parse(r.date)) ? " (" + r.date.slice(0, 10) + ")" : ""
    return "### " + title + when + "\n\n" + (r.notes || "No notes for this release.")
  }).join("\n\n")
}

// A version's part of CHANGELOG.md ("## 1.0.0 - ..." up to the next "## "),
// its heading taken off: { title, notes }, or null.
function fromChangelog(text, version) {
  var lines = String(text || "").replace(/\r\n?/g, "\n").split("\n")
  var start = -1
  var title = ""
  for (var i = 0; i < lines.length; i++) {
    var m = /^##\s+\[?v?([0-9][0-9A-Za-z.+-]*)\]?(.*)$/.exec(lines[i])
    if (!m) continue
    if (start >= 0) { lines = lines.slice(start, i); start = 0; break }
    if (compare(m[1], version) === 0 && parse(m[1])) { start = i + 1; title = (m[1] + m[2]).replace(/\s+-\s+/, " — ").trim() }
  }
  if (start < 0) return null
  if (start > 0) lines = lines.slice(start)
  return { title: title, notes: cleanNotes(lines.join("\n")) }
}
