// Contacts.js - the people in Pages (the sidebar's People): kept on this
// computer in Pages/contacts.json, no account, imported from the contacts
// other apps export (vCard .vcf: iPhone, Android, Google, iCloud, Outlook;
// Google's and Outlook's CSV) and written back as vCard:
//
//   { version: 1, contacts: [{ id: "c3k9x2", name: "Sam Rivera", company: "Acme",
//       title: "Designer", phones: [{ label: "mobile", value: "+1 555 123 4567" }],
//       emails: [{ label: "work", value: "sam@acme.com" }], birthday: "1990-04-12",
//       address: "1 Main St, Springfield", website: "https://sam.dev",
//       notes: "Met at the launch", created, modified }] }
//
// A page names a person with a link to omanote://contact/<id> ("@Sam
// Rivera"), or a contact block shows their card. It cleans what's read,
// finds people by what's typed, reads vCard and CSV (an import matches
// people already there by email or phone, and fills them in), and writes
// vCard. Shared with tests/contacts.test.cjs, so keep it plain JavaScript
// with no QML or Node APIs.
.pragma library

var MAX = 20000
var MAX_LIST = 20
var LABELS = ["mobile", "home", "work", "main", "other"]

function line(value, max) {
  return String(typeof value === "string" || typeof value === "number" ? value : "").replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, max || 200)
}
function text(value, max) {
  return String(typeof value === "string" ? value : "").replace(/\r\n?/g, "\n").replace(/[\u0000-\u0009\u000b-\u001f\u007f]+/g, " ").trim().slice(0, max || 4000)
}

var counter = 0
function newId() { counter++; return "c" + Date.now().toString(36) + counter.toString(36) + Math.random().toString(36).slice(2, 5) }
function isId(id) { return typeof id === "string" && /^[A-Za-z0-9_-]{1,40}$/.test(id) }

// An email as it's kept (lower case, checked), or "".
function cleanEmail(value) {
  var s = line(value, 200).replace(/^mailto:/i, "")
  return /^[^\s@<>()",;:]+@[^\s@<>()",;:]+\.[A-Za-z]{2,}$/.test(s) ? s.toLowerCase() : ""
}
// A phone number as written (digits, spaces, + ( ) - . / x, "ext"), or "".
function cleanPhone(value) {
  var s = line(value, 60).replace(/^tel:/i, "")
  var digits = s.replace(/\D/g, "")
  return digits.length >= 3 && /^[+0-9 ().\/#*-]+((x|ext\.?|extension)\s*[0-9]+)?$/i.test(s) ? s : ""
}
// Its digits, to match one number written two ways (the last 9 or more).
function phoneKey(value) {
  var d = String(value || "").replace(/(x|ext\.?|extension)\s*[0-9]+$/i, "").replace(/\D/g, "")
  return d.length > 9 ? d.slice(-9) : d
}
// "mobile", "home", "work", "main", or what it was called ("other" for nothing).
function cleanLabel(value) {
  var s = line(value, 80).toLowerCase().replace(/internet|pref|voice|x-|\d+|=|\*/g, " ").replace(/[^a-z ,]/g, " ")
  if (/cell|mobile|iphone/.test(s)) return "mobile"
  if (/home/.test(s)) return "home"
  if (/work|business|office/.test(s)) return "work"
  if (/main/.test(s)) return "main"
  var first = s.split(/[ ,]+/).filter(function(w) { return w })[0] || ""
  return first.slice(0, 20) || "other"
}
// A birthday: "1990-04-12", or "--04-12" with no year, or "".
function cleanBirthday(value) {
  var s = line(value, 20)
  var m = /^(\d{4}|--)-?(\d{2})-?(\d{2})$/.exec(s)
  if (!m) return ""
  var mo = Number(m[2])
  var d = Number(m[3])
  if (mo < 1 || mo > 12 || d < 1 || d > 31) return ""
  return (m[1] === "--" ? "-" : m[1]) + "-" + m[2] + "-" + m[3]
}
function cleanWebsite(value) {
  var s = line(value, 500)
  if (/^www\./i.test(s)) s = "https://" + s
  return /^https?:\/\/[^\s]+\.[^\s]+$/i.test(s) ? s : ""
}
function cleanList(list, clean) {
  var out = []
  var seen = {}
  ;(Array.isArray(list) ? list : []).forEach(function(r) {
    if (out.length >= MAX_LIST) return
    var raw = r && typeof r === "object" ? r.value : r
    var v = clean(raw)
    var key = clean === cleanPhone ? phoneKey(v) : v
    if (!v || seen[key]) return
    seen[key] = true
    out.push({ label: cleanLabel(r && typeof r === "object" ? r.label : ""), value: v })
  })
  return out
}
function cleanDate(value) {
  return typeof value === "string" && !isNaN(new Date(value).getTime()) ? value : new Date(0).toISOString()
}

// One person, cleaned (null: no name, email or phone to know them by).
function cleanContact(raw) {
  if (!raw || typeof raw !== "object") return null
  var c = {
    id: isId(raw.id) ? raw.id : newId(),
    name: line(raw.name, 120),
    company: line(raw.company, 120),
    title: line(raw.title, 120),
    phones: cleanList(raw.phones, cleanPhone),
    emails: cleanList(raw.emails, cleanEmail),
    birthday: cleanBirthday(raw.birthday),
    address: line(raw.address, 300),
    website: cleanWebsite(raw.website),
    notes: text(raw.notes, 4000),
    created: cleanDate(raw.created),
    modified: cleanDate(raw.modified)
  }
  if (!c.name && !c.emails.length && !c.phones.length && !c.company) return null
  return c
}

function make() { return { version: 1, contacts: [] } }

function clean(raw) {
  var out = make()
  if (!raw || typeof raw !== "object" || !Array.isArray(raw.contacts)) return out
  var seen = {}
  raw.contacts.slice(0, MAX).forEach(function(r) {
    var c = cleanContact(r)
    if (!c || seen[c.id]) return
    seen[c.id] = true
    out.contacts.push(c)
  })
  return out
}

function copy(book) { return JSON.parse(JSON.stringify(book)) }

// What a person's called on a page: their name, else their email or number.
function nameOf(c) {
  if (!c) return "Someone"
  return c.name || (c.emails.length ? c.emails[0].value : c.phones.length ? c.phones[0].value : c.company) || "Someone"
}
// "SR" for Sam Rivera.
function initials(c) {
  var n = nameOf(c).replace(/@.*$/, "").replace(/[^A-Za-z0-9\u00c0-\uffff ]/g, " ").trim().split(/\s+/)
  if (!n[0]) return "?"
  return ((n[0].charAt(0) || "") + (n.length > 1 ? n[n.length - 1].charAt(0) : "")).toUpperCase()
}
// A person's color (one of Pages', from their name), for their initials.
var TINTS = ["blue", "green", "orange", "purple", "pink", "red", "yellow", "brown"]
function tintOf(c) {
  var s = nameOf(c)
  var h = 0
  for (var i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) % 9973
  return TINTS[h % TINTS.length]
}
// What's under a name: "Designer at Acme", or their first number or email.
function subtitle(c) {
  if (!c) return ""
  if (c.title && c.company) return c.title + " at " + c.company
  return c.company || c.title || (c.name && c.phones.length ? c.phones[0].value : c.name && c.emails.length ? c.emails[0].value : "")
}

function byId(book, id) {
  var list = book && book.contacts ? book.contacts : []
  for (var i = 0; i < list.length; i++) if (list[i].id === id) return list[i]
  return null
}
function byEmail(book, email) {
  var e = cleanEmail(email)
  if (!e) return null
  var list = book && book.contacts ? book.contacts : []
  for (var i = 0; i < list.length; i++) if (list[i].emails.some(function(x) { return x.value === e })) return list[i]
  return null
}

// People by name, A to Z.
function sorted(book) {
  return (book && book.contacts ? book.contacts : []).slice().sort(function(a, b) {
    var x = nameOf(a).toLowerCase()
    var y = nameOf(b).toLowerCase()
    return x < y ? -1 : x > y ? 1 : 0
  })
}

// Those with all the words typed (in their name, company, title, emails,
// numbers or notes), those whose name starts with them first.
function find(book, query, max) {
  var words = String(query || "").toLowerCase().split(/\s+/).filter(function(w) { return w })
  var list = sorted(book)
  if (!words.length) return list.slice(0, max || list.length)
  var digits = String(query || "").replace(/\D/g, "")
  var hits = []
  list.forEach(function(c) {
    var hay = [c.name, c.company, c.title, c.address, c.notes].concat(c.emails.map(function(e) { return e.value })).concat(c.phones.map(function(p) { return p.value })).join(" ").toLowerCase()
    var byDigits = digits.length >= 3 && c.phones.some(function(p) { return p.value.replace(/\D/g, "").indexOf(digits) >= 0 })
    if (!byDigits && !words.every(function(w) { return hay.indexOf(w) >= 0 })) return
    var name = nameOf(c).toLowerCase()
    var rank = name.indexOf(words[0]) === 0 ? 0 : name.split(/\s+/).some(function(p) { return p.indexOf(words[0]) === 0 }) ? 1 : 2
    hits.push({ c: c, rank: rank })
  })
  hits.sort(function(a, b) { return a.rank - b.rank })
  return hits.map(function(h) { return h.c }).slice(0, max || hits.length)
}

// ---- changing it ---------------------------------------------------------------------------

// The book with a person put in (or put back in their place), a copy.
function withContact(book, c, now) {
  var n = copy(book)
  var stamp = (now || new Date()).toISOString()
  var raw = JSON.parse(JSON.stringify(c))
  raw.modified = stamp
  var i = -1
  for (var k = 0; k < n.contacts.length; k++) if (n.contacts[k].id === raw.id) i = k
  if (i < 0) raw.created = raw.created && raw.created !== new Date(0).toISOString() ? raw.created : stamp
  var clean = cleanContact(raw)
  if (!clean) return n
  if (i >= 0) n.contacts[i] = clean
  else n.contacts.push(clean)
  return n
}
function without(book, id) {
  var n = copy(book)
  n.contacts = n.contacts.filter(function(c) { return c.id !== id })
  return n
}

// People read from a file put in the book: someone there already (the same
// email or number, else the same name) is filled in, not added twice.
// Returns { book, added, updated }.
function merge(book, people, now) {
  var n = copy(book)
  var added = 0
  var updated = 0
  var stamp = (now || new Date()).toISOString()
  people.forEach(function(p) {
    var c = cleanContact(p)
    if (!c) return
    var keys = c.emails.map(function(e) { return "e:" + e.value }).concat(c.phones.map(function(x) { return "p:" + phoneKey(x.value) }))
    var hit = null
    n.contacts.forEach(function(o) {
      if (hit) return
      var mine = o.emails.map(function(e) { return "e:" + e.value }).concat(o.phones.map(function(x) { return "p:" + phoneKey(x.value) }))
      if (keys.some(function(k) { return mine.indexOf(k) >= 0 })) hit = o
    })
    if (!hit && c.name) hit = n.contacts.filter(function(o) { return o.name && o.name.toLowerCase() === c.name.toLowerCase() && !o.emails.length && !o.phones.length })[0] || null
    if (hit) {
      var before = JSON.stringify(hit)
      ;["name", "company", "title", "birthday", "address", "website"].forEach(function(f) { if (!hit[f] && c[f]) hit[f] = c[f] })
      if (c.notes && hit.notes.indexOf(c.notes) < 0) hit.notes = hit.notes ? hit.notes + "\n" + c.notes : c.notes
      hit.phones = cleanList(hit.phones.concat(c.phones), cleanPhone)
      hit.emails = cleanList(hit.emails.concat(c.emails), cleanEmail)
      if (JSON.stringify(hit) !== before) { hit.modified = stamp; updated++ }
      return
    }
    if (n.contacts.length >= MAX) return
    c.id = newId()
    c.created = stamp
    c.modified = stamp
    n.contacts.push(c)
    added++
  })
  return { book: n, added: added, updated: updated }
}

// ---- vCard ---------------------------------------------------------------------------------

// A structured value's parts ("Rivera;Sam;;;"), a "\\;" kept in its part.
function splitV(s) {
  var out = [""]
  var str = String(s)
  for (var i = 0; i < str.length; i++) {
    var ch = str.charAt(i)
    if (ch === "\\" && i + 1 < str.length) { out[out.length - 1] += ch + str.charAt(i + 1); i++ }
    else if (ch === ";") out.push("")
    else out[out.length - 1] += ch
  }
  return out
}
function unescapeV(s) {
  return String(s).replace(/\\n/gi, "\n").replace(/\\([,;:\\])/g, "$1")
}
function escapeV(s) {
  return String(s).replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/([,;])/g, "\\$1")
}
// "=C3=A9" (vCard 2.1's quoted-printable) as text.
function quotedPrintable(s) {
  var bytes = []
  var str = String(s).replace(/=\r?\n/g, "")
  for (var i = 0; i < str.length; i++) {
    if (str.charAt(i) === "=" && /^[0-9A-Fa-f]{2}$/.test(str.substr(i + 1, 2))) { bytes.push(parseInt(str.substr(i + 1, 2), 16)); i += 2 }
    else bytes.push(str.charCodeAt(i) & 0xff)
  }
  var out = ""
  for (var k = 0; k < bytes.length; k++) {
    var b = bytes[k]
    if (b < 0x80) out += String.fromCharCode(b)
    else if (b >= 0xc0 && b < 0xe0 && k + 1 < bytes.length) { out += String.fromCharCode(((b & 0x1f) << 6) | (bytes[++k] & 0x3f)) }
    else if (b >= 0xe0 && b < 0xf0 && k + 2 < bytes.length) { out += String.fromCharCode(((b & 0x0f) << 12) | ((bytes[++k] & 0x3f) << 6) | (bytes[++k] & 0x3f)) }
    else if (b >= 0xf0 && k + 3 < bytes.length) { var cp = ((b & 0x07) << 18) | ((bytes[++k] & 0x3f) << 12) | ((bytes[++k] & 0x3f) << 6) | (bytes[++k] & 0x3f); out += String.fromCodePoint(cp) }
  }
  return out
}

// The people in a .vcf file (one card or many; vCard 2.1, 3.0, 4.0).
function fromVcard(source) {
  // Lines folded onto the next (a space or a tab at its start) put back.
  var lines = String(source || "").replace(/\r\n?/g, "\n").replace(/\n[ \t]/g, "").split("\n")
  // (Quoted-printable lines ending in "=" go on to the next.)
  var joined = []
  lines.forEach(function(l) {
    var last = joined.length ? joined[joined.length - 1] : null
    if (last !== null && /QUOTED-PRINTABLE/i.test(last.split(":")[0]) && /=$/.test(last)) joined[joined.length - 1] = last.slice(0, -1) + l
    else joined.push(l)
  })
  var out = []
  var cur = null
  joined.forEach(function(l) {
    if (/^BEGIN:VCARD$/i.test(l.trim())) { cur = { name: "", first: "", last: "", phones: [], emails: [], notes: "" }; return }
    if (/^END:VCARD$/i.test(l.trim())) {
      if (cur) {
        if (!cur.name) cur.name = (cur.first + " " + cur.last).trim()
        delete cur.first
        delete cur.last
        var c = cleanContact(cur)
        if (c) out.push(c)
      }
      cur = null
      return
    }
    if (!cur || out.length >= MAX) return
    var colon = l.indexOf(":")
    if (colon < 0) return
    var head = l.slice(0, colon)
    var value = l.slice(colon + 1)
    var parts = head.split(";")
    var key = parts[0].replace(/^item\d+\./i, "").toUpperCase()
    var params = parts.slice(1).join(";")
    if (/ENCODING=QUOTED-PRINTABLE|;QUOTED-PRINTABLE/i.test(";" + params)) value = quotedPrintable(value)
    var types = (params.match(/TYPE=([^;]+)/ig) || []).map(function(t) { return t.slice(5) }).join(",") + "," + parts.slice(1).filter(function(p) { return p.indexOf("=") < 0 }).join(",")
    if (key === "FN") cur.name = unescapeV(value)
    else if (key === "N") {
      var n = splitV(value).map(unescapeV)
      cur.last = (n[0] || "").trim()
      cur.first = [n[2] || "", n[1] || ""].join(" ").replace(/\s+/g, " ").trim()
    }
    else if (key === "TEL") cur.phones.push({ label: types, value: unescapeV(value) })
    else if (key === "EMAIL") cur.emails.push({ label: types, value: unescapeV(value) })
    else if (key === "ORG") cur.company = unescapeV(splitV(value)[0])
    else if (key === "TITLE") cur.title = unescapeV(value)
    else if (key === "BDAY") cur.birthday = value.replace(/T.*$/, "")
    else if (key === "ADR" && !cur.address) cur.address = splitV(value).map(unescapeV).map(function(x) { return x.trim() }).filter(function(x) { return x }).join(", ")
    else if (key === "URL" && !cur.website) cur.website = unescapeV(value)
    else if (key === "NOTE") cur.notes = unescapeV(value)
  })
  return out
}

function vcardOf(c) {
  var out = ["BEGIN:VCARD", "VERSION:3.0", "FN:" + escapeV(nameOf(c))]
  var words = (c.name || "").split(/\s+/)
  out.push("N:" + escapeV(words.length > 1 ? words[words.length - 1] : (c.name || "")) + ";" + escapeV(words.length > 1 ? words.slice(0, -1).join(" ") : "") + ";;;")
  if (c.company) out.push("ORG:" + escapeV(c.company))
  if (c.title) out.push("TITLE:" + escapeV(c.title))
  c.phones.forEach(function(p) { out.push("TEL;TYPE=" + (p.label === "mobile" ? "CELL" : p.label.toUpperCase().replace(/[^A-Z]/g, "") || "VOICE") + ":" + p.value) })
  c.emails.forEach(function(e) { out.push("EMAIL;TYPE=" + (e.label.toUpperCase().replace(/[^A-Z]/g, "") || "INTERNET") + ":" + e.value) })
  if (c.birthday) out.push("BDAY:" + c.birthday)
  if (c.address) out.push("ADR:;;" + escapeV(c.address) + ";;;;")
  if (c.website) out.push("URL:" + c.website)
  if (c.notes) out.push("NOTE:" + escapeV(c.notes))
  out.push("END:VCARD")
  // (Lines no longer than 75 characters, folded onto the next.)
  return out.map(function(l) {
    var f = []
    while (l.length > 75) { f.push(l.slice(0, 75)); l = " " + l.slice(75) }
    f.push(l)
    return f.join("\r\n")
  }).join("\r\n")
}

// Everyone as one .vcf file.
function toVcard(book) {
  return sorted(book).map(vcardOf).join("\r\n") + "\r\n"
}

// ---- CSV (Google's and Outlook's) ------------------------------------------------------------

function csvRows(source) {
  var rows = []
  var row = []
  var cell = ""
  var quoted = false
  var s = String(source || "").replace(/^\ufeff/, "")
  for (var i = 0; i < s.length; i++) {
    var ch = s.charAt(i)
    if (quoted) {
      if (ch === "\"" && s.charAt(i + 1) === "\"") { cell += "\""; i++ }
      else if (ch === "\"") quoted = false
      else cell += ch
    } else if (ch === "\"") quoted = true
    else if (ch === ",") { row.push(cell); cell = "" }
    else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && s.charAt(i + 1) === "\n") i++
      row.push(cell); cell = ""
      rows.push(row); row = []
    } else cell += ch
  }
  if (cell !== "" || row.length) { row.push(cell); rows.push(row) }
  return rows.filter(function(r) { return r.some(function(x) { return x.trim() }) })
}

// The people in a CSV file: its first row names the columns (Google:
// "Name", "E-mail 1 - Value", "Phone 1 - Type"...; Outlook: "First Name",
// "E-mail Address", "Mobile Phone"...; or plain "Name", "Email", "Phone").
function fromCsv(source) {
  var rows = csvRows(source)
  if (rows.length < 2) return []
  var head = rows[0].map(function(h) { return h.trim().toLowerCase() })
  function col(test) { for (var i = 0; i < head.length; i++) if (test(head[i])) return i; return -1 }
  var cName = col(function(h) { return h === "name" || h === "full name" || h === "display name" })
  var cFirst = col(function(h) { return h === "first name" || h === "given name" })
  var cMiddle = col(function(h) { return h === "middle name" || h === "additional name" })
  var cLast = col(function(h) { return h === "last name" || h === "family name" })
  var cCompany = col(function(h) { return h === "company" || h === "organization 1 - name" || h === "organization name" || h === "organization" })
  var cTitle = col(function(h) { return h === "job title" || (h === "title" && cFirst < 0) || h === "organization 1 - title" || h === "organization title" })
  var cBirthday = col(function(h) { return h === "birthday" })
  var cNotes = col(function(h) { return h === "notes" })
  var cWeb = col(function(h) { return h === "web page" || h === "website 1 - value" || h === "website" })
  var cAddr = col(function(h) { return h === "address 1 - formatted" || h === "home address" || h === "business address" || h === "address" })
  var phoneCols = []
  var emailCols = []
  head.forEach(function(h, i) {
    // (Google: "Phone 1 - Type", lately "Phone 1 - Label".)
    function labelCol(what, n) { var t = head.indexOf(what + " " + n + " - type"); return t >= 0 ? t : head.indexOf(what + " " + n + " - label") }
    var g = /^phone (\d+) - value$/.exec(h)
    if (g) { phoneCols.push({ value: i, label: labelCol("phone", g[1]) }); return }
    g = /^e-mail (\d+) - value$/.exec(h)
    if (g) { emailCols.push({ value: i, label: labelCol("e-mail", g[1]) }); return }
    if (/(^|\s)(phone|fax)$/.test(h) && !/fax/.test(h)) phoneCols.push({ value: i, fixed: h.replace(/\s*phone$/, "") || "main" })
    else if (/^(e-?mail( address)?|e-?mail \d+ address|e-mail \d address)$/.test(h)) emailCols.push({ value: i, fixed: "" })
  })
  var out = []
  rows.slice(1).forEach(function(r) {
    if (out.length >= MAX) return
    function at(i) { return i >= 0 && i < r.length ? r[i].trim() : "" }
    var name = at(cName) || [at(cFirst), at(cMiddle), at(cLast)].filter(function(x) { return x }).join(" ")
    var c = cleanContact({
      name: name, company: at(cCompany), title: at(cTitle), birthday: at(cBirthday), notes: at(cNotes), website: at(cWeb), address: at(cAddr),
      // (Google puts "a ::: b" for two numbers in one cell.)
      phones: [].concat.apply([], phoneCols.map(function(p) { return at(p.value).split(/\s*:::\s*/).map(function(v) { return { label: p.fixed !== undefined ? p.fixed : at(p.label), value: v } }) })),
      emails: [].concat.apply([], emailCols.map(function(e) { return at(e.value).split(/\s*:::\s*/).map(function(v) { return { label: e.fixed !== undefined ? e.fixed : at(e.label), value: v } }) }))
    })
    if (c) out.push(c)
  })
  return out
}

// What's in a file, by its name or what it starts with: people, or [].
function fromFile(name, source) {
  var s = String(source || "")
  if (/\.vcf$|\.vcard$/i.test(name) || /^\s*BEGIN:VCARD/i.test(s)) return fromVcard(s)
  if (/\.csv$/i.test(name)) return fromCsv(s)
  return []
}

// A birthday as it's said on their card: { date: "12 April 1990", next: "in
// 192 days" | "today" | "tomorrow", turns: 37 (0 without a year) }, or null.
var MONTH_NAMES = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
function birthdayInfo(c, now) {
  var b = c ? cleanBirthday(c.birthday) : ""
  if (!b) return null
  var n = now || new Date()
  var year = b.charAt(0) === "-" ? 0 : Number(b.slice(0, 4))
  var mo = Number(b.slice(-5, -3)) - 1
  var d = Number(b.slice(-2))
  var today = new Date(n.getFullYear(), n.getMonth(), n.getDate())
  var next = new Date(n.getFullYear(), mo, d)
  if (next < today) next = new Date(n.getFullYear() + 1, mo, d)
  var days = Math.round((next - today) / 86400000)
  return {
    date: d + " " + MONTH_NAMES[mo] + (year ? " " + year : ""),
    next: days === 0 ? "today" : days === 1 ? "tomorrow" : "in " + days + " days",
    turns: year ? next.getFullYear() - year : 0
  }
}

// What a field is called, for the label menu.
var PHONE_LABELS = ["mobile", "home", "work", "main", "other"]
var EMAIL_LABELS = ["home", "work", "other"]

// ---- on pages ------------------------------------------------------------------------------

// A link to a person, and the person a link goes to ("" for none).
function href(id) { return "omanote://contact/" + id }
function idOf(url) {
  var m = /^omanote:\/\/contact\/([A-Za-z0-9_-]{1,40})$/.exec(String(url || ""))
  return m ? m[1] : ""
}

// A person as Markdown (a contact block): their name, what they do, how to reach them.
function toMarkdown(c, prefix) {
  if (!c) return "*(A contact, not picked yet)*"
  var out = ["**" + nameOf(c) + "**" + (subtitle(c) && (c.title || c.company) ? " \u00b7 " + subtitle(c) : "")]
  c.phones.forEach(function(p) { out.push((prefix || "") + "- \u260e " + p.value + (p.label ? " (" + p.label + ")" : "")) })
  c.emails.forEach(function(e) { out.push((prefix || "") + "- \u2709 [" + e.value + "](mailto:" + e.value + ")") })
  return out.join("\n")
}
