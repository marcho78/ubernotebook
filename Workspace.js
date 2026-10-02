// Workspace.js - Pages: the other way to write in Omanote, as a workspace of
// pages made of blocks, the way Notion does it.
//
// Everything is a block: an atomic record with an id (a UUID v4), a type, its
// properties (its text, a color, whether it's ticked...), `content` (the ids
// of the blocks inside it, in order) and `parent` (the id of the block or page
// it's in). A page is a block too, and a page inside a page is a `page` block
// in its parent's content whose id is the inner page's own id.
//
//   Pages/
//     index.json          the tree of pages, for the sidebar: titles, icons,
//                         parents, children in order, what's in the trash
//     <page id>.json      one page: its title, icon, cover and look, and
//                         every block on it, as a tree (content + blocks)
//     assets/<name>       pictures and covers on its pages
//
// The editor works on a page's blocks as a list in reading order, each with
// its depth (flatten/unflatten turn one into the other); a block's children
// are the deeper blocks right after it.
//
// Everything read from these files is checked here before anything uses it.
// Shared by the store (Workspace.qml), the pages view (app/Doc*.qml) and
// tests/workspace.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Blocks.js" as Blocks
.import "Html.js" as Html
.import "Dates.js" as Dates
.import "Mindmap.js" as Mindmap
.import "Table.js" as Table
.import "Tags.js" as Tags
.import "Audio.js" as Audio

var VERSION = 1
var MAX_DEPTH = 12
var MAX_BLOCKS = 5000
var MAX_PAGES = 20000
var MAX_TITLE = 200

// ---- ids ---------------------------------------------------------------------------

// A random (version 4) UUID: 122 random bits, "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".
function uuid4(random) {
  var r = typeof random === "function" ? random : Math.random
  var bytes = []
  for (var i = 0; i < 16; i++) bytes.push(Math.floor(r() * 256) & 255)
  bytes[6] = (bytes[6] & 0x0f) | 0x40
  bytes[8] = (bytes[8] & 0x3f) | 0x80
  var hex = bytes.map(function(b) { return (b < 16 ? "0" : "") + b.toString(16) }).join("")
  return hex.slice(0, 8) + "-" + hex.slice(8, 12) + "-" + hex.slice(12, 16) + "-" + hex.slice(16, 20) + "-" + hex.slice(20)
}

// Any UUID, as Omanote writes them (lowercase). Pages and blocks made
// elsewhere keep theirs.
var UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/

function isUuid(value) {
  return typeof value === "string" && UUID.test(value)
}

// ---- blocks ---------------------------------------------------------------------------

// The kinds of block a page can have.
var KINDS = ["p", "h1", "h2", "h3", "bullet", "number", "check", "toggle", "quote", "callout", "code", "divider", "image", "page", "link", "toc", "columns", "column", "habit", "calendar", "mindmap", "table", "sketch", "audio"]

function isKind(type) {
  return KINDS.indexOf(type) >= 0
}

// Can a block have blocks inside it? Text, lists, to-dos, toggles, quotes and
// callouts can; a heading only when it's a toggle heading.
function canNest(type, block) {
  if (type === "h1" || type === "h2" || type === "h3") return !!block && block.toggle === true
  return ["p", "bullet", "number", "check", "toggle", "quote", "callout", "columns", "column"].indexOf(type) >= 0
}

// Blocks that only arrange others (columns), and never show themselves.
function isStructure(type) {
  return type === "columns" || type === "column"
}

// ---- columns -------------------------------------------------------------------------------

// Columns that make sense, in a page's list of blocks (each { uid, type,
// indent }): a columns block is at the top of the page and holds only column
// blocks, two or more, each with something in it. An empty column goes; a
// columns block with fewer than two columns left (or anywhere else, or
// holding something that isn't a column) goes, and what was in its columns
// takes its place; a column outside columns goes, and what was in it comes
// out. Returns { remove: [uids], indent: { uid: depth } }, or null when
// everything's as it should be.
function fixColumns(list) {
  var remove = []
  var indent = {}
  var n = list.length
  function end(i) {
    var j = i
    while (j + 1 < n && list[j + 1].indent > list[i].indent) j++
    return j
  }
  function shift(from, to, by) {
    for (var k = from; k <= to; k++) indent[list[k].uid] = Math.max(0, (indent[list[k].uid] !== undefined ? indent[list[k].uid] : list[k].indent) + by)
  }
  var i = 0
  while (i < n) {
    var b = list[i]
    if (b.type === "columns") {
      var last = end(i)
      var columns = []
      var odd = b.indent !== 0
      for (var j = i + 1; j <= last; j = end(j) + 1) {
        if (list[j].type !== "column" || list[j].indent !== b.indent + 1) odd = true
        else columns.push({ at: j, end: end(j) })
      }
      var full = columns.filter(function(c) { return c.end > c.at })
      if (odd || full.length < 2) {
        // It goes; what was in its columns takes its place.
        remove.push(b.uid)
        for (var k = i + 1; k <= last; k++) {
          if (list[k].type === "column" && list[k].indent === b.indent + 1) remove.push(list[k].uid)
          else shift(k, k, -2)
        }
      } else {
        columns.forEach(function(c) { if (c.end === c.at) remove.push(list[c.at].uid) })
      }
      i = last + 1
      continue
    }
    if (b.type === "column") {
      // A column that isn't in columns: it goes, and what was in it comes out.
      var e = end(i)
      remove.push(b.uid)
      shift(i + 1, e, -1)
      i = e + 1
      continue
    }
    i++
  }
  return remove.length || Object.keys(indent).length ? { remove: remove, indent: indent } : null
}

// The list with those changes made (a new list; the blocks are the same).
function applyFix(list, fix) {
  if (!fix) return list
  var gone = {}
  fix.remove.forEach(function(uid) { gone[uid] = true })
  return list.filter(function(b) { return !gone[b.uid] }).map(function(b) {
    if (fix.indent[b.uid] === undefined) return b
    var c = {}
    for (var k in b) c[k] = b[k]
    c.indent = fix.indent[b.uid]
    return c
  })
}

// Does it fold its children away (a toggle, or a toggle heading)?
function folds(block) {
  return !!block && (block.type === "toggle" || block.toggle === true)
}

// One block from a page file, as it may be used, or null.
function cleanBlock(raw, id) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw) || !isUuid(id)) return null
  if (!isKind(raw.type)) return null
  var props = {}
  for (var key in raw) if (key !== "content" && key !== "parent" && key !== "id") props[key] = raw[key]
  props.uid = id
  var b = Blocks.clean(props, { nest: true })
  if (!b) return null
  if (b.type === "image" && !b.src) return null
  if (b.type === "link" && !isUuid(b.target)) return null
  delete b.indent
  delete b.uid
  b.id = id
  return b
}

// ---- pages ------------------------------------------------------------------------------

var WIDTHS = ["normal", "full"]
var SIZES = ["normal", "small"]
var FONTS = ["sans", "serif", "mono"]
var COVERS = 12

function cleanTitle(value) {
  if (typeof value !== "string") return ""
  return value.replace(/[\u0000-\u001f\u007f\u2028\u2029]+/g, " ").replace(/\s+/g, " ").trim().slice(0, MAX_TITLE)
}

// A page's icon: an emoji (a few characters at most, nothing that isn't one).
function cleanIcon(value) {
  if (typeof value !== "string" || value.length === 0 || value.length > 16) return ""
  if (/[\u0000-\u0020\u007f<>&"'\\\/]|[A-Za-z0-9]/.test(value)) return ""
  return value
}

// A cover: "gradient:<n>" (one of Omanote's), or a picture in assets.
function cleanCover(value) {
  var v = typeof value === "string" ? value : ""
  var m = /^gradient:(\d{1,2})$/.exec(v)
  if (m) return Number(m[1]) < COVERS ? v : ""
  return Blocks.cleanAsset(v)
}

function cleanFormat(raw) {
  var f = raw && typeof raw === "object" ? raw : {}
  return {
    width: WIDTHS.indexOf(f.width) >= 0 ? f.width : "normal",
    size: SIZES.indexOf(f.size) >= 0 ? f.size : "normal",
    font: FONTS.indexOf(f.font) >= 0 ? f.font : "sans",
    // Locked: it reads, but can't be changed until it's unlocked.
    locked: f.locked === true
  }
}

function cleanDate(value, fallback) {
  if (typeof value !== "string" || value.length > 40) return fallback
  var t = Date.parse(value)
  return isFinite(t) ? new Date(t).toISOString() : fallback
}

// A page's tree of blocks from its file: every block reachable from the
// page's content once, each where its parent says, no deeper than MAX_DEPTH.
// The children of a block that can't have any (or too deep) come out after
// it instead of being lost.
function cleanTree(rawContent, rawBlocks, pageId) {
  var blocks = {}
  var seen = {}
  var count = 0
  var source = rawBlocks && typeof rawBlocks === "object" && !Array.isArray(rawBlocks) ? rawBlocks : {}
  function walk(ids, parentId, depth) {
    var out = []
    if (!Array.isArray(ids)) return out
    for (var i = 0; i < ids.length && count < MAX_BLOCKS; i++) {
      var id = ids[i]
      if (!isUuid(id) || seen[id] || id === pageId) continue
      var raw = Object.prototype.hasOwnProperty.call(source, id) ? source[id] : null
      var b = cleanBlock(raw, id)
      if (!b) continue
      seen[id] = true
      count++
      b.parent = parentId
      blocks[id] = b
      out.push(id)
      var inner = raw.content
      if (b.type === "page") continue
      if (canNest(b.type, b) && depth < MAX_DEPTH) {
        var kids = walk(inner, id, depth + 1)
        if (kids.length) b.content = kids
      } else {
        out = out.concat(walk(inner, parentId, depth))
      }
    }
    return out
  }
  var content = walk(rawContent, pageId, 0)
  // Columns that make sense (see fixColumns), whatever the file says.
  var list = flatten({ content: content, blocks: blocks })
  var fix = fixColumns(list)
  if (fix) return unflatten(applyFix(list, fix), pageId)
  return { content: content, blocks: blocks }
}

// A page file as it may be used, or null. `id` is its file's name.
function cleanPage(raw, id) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw) || !isUuid(id)) return null
  var created = cleanDate(raw.created, new Date(0).toISOString())
  var tree = cleanTree(raw.content, raw.blocks, id)
  var page = {
    version: VERSION,
    id: id,
    type: "page",
    parent: isUuid(raw.parent) && raw.parent !== id ? raw.parent : "",
    title: cleanTitle(raw.title),
    icon: cleanIcon(raw.icon),
    cover: cleanCover(raw.cover),
    format: cleanFormat(raw.format),
    created: created,
    modified: cleanDate(raw.modified, created),
    content: tree.content,
    blocks: tree.blocks
  }
  // A project: its status and when it's due.
  var project = cleanProject(raw.project)
  if (project) page.project = project
  page.text = pageText(page)
  return page
}

// A new page: { parent, title, icon, blocks } (blocks as the editor has them:
// in order, each with its depth).
function newPage(options, date, random) {
  var o = options || {}
  var now = (date || new Date()).toISOString()
  var id = isUuid(o.id) ? o.id : uuid4(random)
  var list = (o.blocks || []).map(function(b) {
    var c = {}
    for (var k in b) c[k] = b[k]
    if (!isUuid(c.uid)) c.uid = uuid4(random)
    return c
  })
  var tree = unflatten(list, id)
  var page = cleanPage({
    parent: o.parent, title: o.title, icon: o.icon, cover: o.cover, format: o.format, project: o.project,
    created: now, modified: now, content: tree.content, blocks: tree.blocks
  }, id)
  return page
}

// ---- a page's blocks as a list, and back --------------------------------------------------

// The page's blocks in reading order, each with its depth (`indent`) and its
// id as `uid`: what the editor works on.
function flatten(page) {
  var out = []
  var blocks = page && page.blocks ? page.blocks : {}
  function walk(ids, depth) {
    (ids || []).forEach(function(id) {
      var b = blocks[id]
      if (!b) return
      var copy = {}
      for (var k in b) if (k !== "content" && k !== "parent" && k !== "id") copy[k] = b[k]
      copy.uid = id
      copy.indent = depth
      out.push(copy)
      if (b.content) walk(b.content, depth + 1)
    })
  }
  walk(page ? page.content : [], 0)
  return out
}

// The editor's list (in order, each with its depth) as a page's tree: each
// block goes inside the nearest block above it that's shallower and can
// hold it.
function unflatten(list, pageId) {
  var blocks = {}
  var content = []
  var items = []
  var seen = {}
  ;(list || []).forEach(function(item) {
    if (!item || !isUuid(item.uid) || seen[item.uid]) return
    seen[item.uid] = true
    var b = {}
    for (var k in item) if (k !== "uid" && k !== "indent" && k !== "content" && k !== "parent") b[k] = item[k]
    b.id = item.uid
    items.push({ indent: Math.max(0, Math.floor(Number(item.indent) || 0)), type: b.type, toggle: b.toggle, block: b })
  })
  // Once the depths make sense, the blocks above one that are still open
  // (the stack) are its parent and the parent's parents, one per depth.
  normalizeDepths(items)
  var stack = []
  items.forEach(function(it) {
    while (stack.length && stack[stack.length - 1].indent >= it.indent) stack.pop()
    var parent = stack.length ? stack[stack.length - 1].block : null
    var b = it.block
    if (parent) {
      parent.content = (parent.content || []).concat([b.id])
      b.parent = parent.id
    } else {
      content.push(b.id)
      b.parent = pageId
    }
    blocks[b.id] = b
    stack.push(it)
  })
  return { content: content, blocks: blocks }
}

// Depths that make sense: a block is at most one deeper than the block above
// it, and only if that block can hold others. Changes the list in place.
function normalizeDepths(list) {
  for (var i = 0; i < list.length; i++) {
    var max = i === 0 ? 0 : list[i - 1].indent + (canNest(list[i - 1].type, list[i - 1]) ? 1 : 0)
    if (!(list[i].indent >= 0)) list[i].indent = 0
    if (list[i].indent > max) list[i].indent = max
  }
  return list
}

// The index of the last block inside the block at i (i itself if it has none).
function subtreeEnd(list, i) {
  var j = i
  while (j + 1 < list.length && list[j + 1].indent > list[i].indent) j++
  return j
}

// The depths a block can take when it's put before list[index] (the block
// moved is already out of the list): no deeper than one inside the block
// above it (if that can hold blocks), and no shallower than the block below,
// so that no other block gets a new parent.
function depthRange(list, index) {
  var above = index > 0 ? list[index - 1] : null
  var below = index < list.length ? list[index] : null
  var max = above ? above.indent + (canNest(above.type, above) ? 1 : 0) : 0
  var min = below ? Math.min(below.indent, max) : 0
  return { min: min, max: max }
}

// ---- what's on a page -------------------------------------------------------------------

// The pages inside a page, in the order their blocks are on it.
// The sketches on a page: [{ id (the block's), sketch }].
function sketchesOf(page) {
  return flatten(page).filter(function(b) { return b.type === "sketch" && b.sketch }).map(function(b) { return { id: b.uid, sketch: b.sketch } })
}

function childPages(page) {
  return flatten(page).filter(function(b) { return b.type === "page" }).map(function(b) { return b.uid })
}

// Every page it links to: link blocks, and pages linked from its text
// ("[["), each once.
function linkedPages(page) {
  var out = []
  flatten(page).forEach(function(b) {
    if (b.type === "link" && isUuid(b.target) && out.indexOf(b.target) < 0) out.push(b.target)
    if (!Blocks.isText(b.type) || !b.html) return
    Html.links(b.html).forEach(function(l) {
      var id = Html.pageOf(l.href)
      if (id && id !== page.id && out.indexOf(id) < 0) out.push(id)
    })
  })
  return out
}

// The reminders on it ("@" with "Remind me"): [{ block, at, text }], `at`
// when the notification comes, `text` what the block says.
function pageReminders(page) {
  var out = []
  flatten(page).forEach(function(b) {
    if (!Blocks.isText(b.type) || !b.html || b.html.indexOf("omanote://remind/") < 0) return
    var text = Html.plainText(b.html).replace(/\s+/g, " ").trim().slice(0, 200)
    Html.links(b.html).forEach(function(l) {
      var d = Dates.fromHref(l.href)
      if (!d || !d.remind) return
      out.push({ block: b.uid, at: Dates.iso(Dates.remindAt(d.at, d.time), true), text: text })
    })
  })
  return out.slice(0, 200)
}

function pageText(page) {
  var lines = [page.title || ""]
  flatten(page).forEach(function(b) {
    if (Blocks.isText(b.type)) lines.push(Html.plainText(b.html || ""))
    else if (b.type === "mindmap") Mindmap.toList(b.outline).forEach(function(it) { lines.push(it.text) })
    else if (b.type === "table") lines.push(Table.text(b.table))
    // What was said in an audio note.
    else if (b.type === "audio" && b.audio && b.audio.transcript) lines.push(b.audio.transcript)
  })
  return lines.join("\n").trim()
}

// ---- changing a page that isn't open ---------------------------------------------------------

// A block taken off a page, with everything inside it. Returns whether it was on it.
function removeBlock(page, id) {
  var b = page.blocks[id]
  if (!b) return false
  var list = b.parent && page.blocks[b.parent] ? page.blocks[b.parent].content : page.content
  var at = list ? list.indexOf(id) : -1
  if (at >= 0) list.splice(at, 1)
  if (b.parent && page.blocks[b.parent] && page.blocks[b.parent].content && page.blocks[b.parent].content.length === 0) delete page.blocks[b.parent].content
  function drop(bid) {
    var x = page.blocks[bid]
    if (!x) return
    ;(x.content || []).forEach(drop)
    delete page.blocks[bid]
  }
  drop(id)
  return true
}

// A page inside it, as a page block at its end (unless it's on it already).
function appendPageBlock(page, childId) {
  if (!isUuid(childId) || page.blocks[childId]) return false
  page.blocks[childId] = { id: childId, type: "page", parent: page.id }
  page.content.push(childId)
  return true
}

// A page inside it, as a page block in front of the page block `before`
// (or right after `after`), in the same place on the page as that one; else
// at its end. (The order of a page's pages is the order of their blocks.)
function placePageBlock(page, childId, before, after) {
  if (!isUuid(childId)) return false
  if (page.blocks[childId]) removeBlock(page, childId)
  var ref = before && page.blocks[before] && before !== childId ? before : after && page.blocks[after] && after !== childId ? after : ""
  if (!ref) return appendPageBlock(page, childId)
  var rb = page.blocks[ref]
  var inBlock = rb.parent && page.blocks[rb.parent]
  var list = inBlock ? page.blocks[rb.parent].content : page.content
  var at = list.indexOf(ref) + (ref === before ? 0 : 1)
  page.blocks[childId] = { id: childId, type: "page", parent: inBlock ? rb.parent : page.id }
  list.splice(at, 0, childId)
  return true
}

// ---- the tree of pages -------------------------------------------------------------------

function emptyIndex() {
  return { version: VERSION, top: [], pages: {}, fired: {}, favorites: [], tagColors: {} }
}

function entry(raw) {
  var e = raw && typeof raw === "object" ? raw : {}
  var created = cleanDate(e.created, new Date(0).toISOString())
  return {
    title: cleanTitle(e.title),
    icon: cleanIcon(e.icon),
    parent: isUuid(e.parent) ? e.parent : "",
    children: [],
    trashed: e.trashed === true,
    created: created,
    modified: cleanDate(e.modified, created),
    // What it links to, its reminders and its tags (null: not worked out yet).
    links: Array.isArray(e.links) ? e.links.filter(isUuid).slice(0, 2000) : null,
    tags: Array.isArray(e.tags) ? cleanTagCounts(e.tags) : null,
    // A project (its status and due date), and the to-dos on the page.
    project: cleanProject(e.project),
    checks: e.checks && typeof e.checks === "object" ? cleanChecks(e.checks) : null,
    // Put away in the archive (with the pages in it).
    archived: e.archived === true,
    reminders: Array.isArray(e.reminders) ? e.reminders.filter(function(r) {
      return r && isUuid(r.block) && Dates.fromIso(r.at) !== null && typeof r.text === "string"
    }).map(function(r) { return { block: r.block, at: r.at, text: r.text.slice(0, 200) } }).slice(0, 200) : null,
    rawChildren: Array.isArray(e.children) ? e.children : []
  }
}

// index.json as it may be used: every page once, under a parent that exists
// (else at the top), children in order, no page inside itself.
function cleanIndex(raw) {
  var r = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {}
  var src = r.pages && typeof r.pages === "object" && !Array.isArray(r.pages) ? r.pages : {}
  var pages = {}
  var n = 0
  for (var id in src) {
    if (!isUuid(id) || n >= MAX_PAGES) continue
    pages[id] = entry(src[id])
    n++
  }
  var placed = {}
  var top = []
  function place(ids, parent, chain) {
    var out = []
    ;(ids || []).forEach(function(id) {
      if (!pages[id] || placed[id] || chain[id]) return
      if (pages[id].parent !== parent) return
      placed[id] = true
      out.push(id)
      var inner = {}
      for (var c in chain) inner[c] = true
      inner[id] = true
      pages[id].children = place(pages[id].rawChildren, id, inner)
    })
    return out
  }
  top = place(Array.isArray(r.top) ? r.top : [], "", {})
  // Pages the tree didn't reach go under their parent once it's placed, or
  // at the top when they have none (or the oldest of a loop of pages that
  // say they're inside each other goes to the top).
  function settle(id, parent) {
    placed[id] = true
    pages[id].parent = parent
    if (parent) pages[parent].children.push(id)
    else top.push(id)
    var chain = {}
    chain[id] = true
    pages[id].children = pages[id].children.concat(place(pages[id].rawChildren, id, chain))
  }
  var rest = Object.keys(pages).filter(function(id) { return !placed[id] }).sort(function(a, b) {
    return pages[a].created < pages[b].created ? -1 : pages[a].created > pages[b].created ? 1 : 0
  })
  while (rest.length) {
    var waiting = []
    var moved = false
    rest.forEach(function(id) {
      if (placed[id]) return
      var p = pages[id].parent
      if (!p || !pages[p]) { settle(id, ""); moved = true }
      else if (placed[p]) { settle(id, p); moved = true }
      else waiting.push(id)
    })
    if (!moved && waiting.length) settle(waiting.shift(), "")
    rest = waiting.filter(function(id) { return !placed[id] })
  }
  for (var k in pages) delete pages[k].rawChildren
  // The pages in Favorites, in order.
  var favorites = []
  ;(Array.isArray(r.favorites) ? r.favorites : []).forEach(function(id) { if (pages[id] && favorites.indexOf(id) < 0 && favorites.length < 200) favorites.push(id) })
  // Reminders that have come already (so they don't again).
  var fired = {}
  var src2 = r.fired && typeof r.fired === "object" && !Array.isArray(r.fired) ? r.fired : {}
  Object.keys(src2).slice(0, 5000).forEach(function(key) { if (/^[0-9a-f-]{36}\|[0-9a-f-]{36}\|[0-9T:-]{16}$/.test(key)) fired[key] = true })
  // Tags' colors: { name: "blue" | "#ff8800" | "blue_background"... }.
  var tagColors = {}
  var src3 = r.tagColors && typeof r.tagColors === "object" && !Array.isArray(r.tagColors) ? r.tagColors : {}
  Object.keys(src3).slice(0, 2000).forEach(function(name) {
    var c = cleanTagColor(src3[name])
    if (Tags.clean(name) === name && c) tagColors[name] = c
  })
  return { version: VERSION, top: top, pages: pages, fired: fired, favorites: favorites, tagColors: tagColors }
}

// Is page `id` inside page `of` (at any depth), by the parents recorded?
function isInside(pages, id, of) {
  var seen = {}
  var p = pages[id] ? pages[id].parent : ""
  while (p && !seen[p]) {
    if (p === of) return true
    seen[p] = true
    p = pages[p] ? pages[p].parent : ""
  }
  return false
}

// A page and every page inside it.
function withDescendants(index, id) {
  var out = []
  function walk(pid) {
    if (!index.pages[pid] || out.indexOf(pid) >= 0) return
    out.push(pid)
    index.pages[pid].children.forEach(walk)
  }
  walk(id)
  return out
}

// Is it in the trash (or inside a page that is)?
function inTrash(index, id) {
  var seen = {}
  var p = id
  while (p && index.pages[p] && !seen[p]) {
    if (index.pages[p].trashed) return true
    seen[p] = true
    p = index.pages[p].parent
  }
  return false
}

// What's in the trash: the pages thrown away (not the pages inside them),
// most recent first.
function trashed(index) {
  return Object.keys(index.pages).filter(function(id) {
    var e = index.pages[id]
    return e.trashed && !(e.parent && inTrash(index, e.parent))
  }).sort(function(a, b) { return index.pages[a].modified < index.pages[b].modified ? 1 : -1 })
}

// The sidebar's rows: the pages not in the trash, as the tree shows them,
// with the children of the pages in `open` shown.
function rows(index, open) {
  var out = []
  function walk(ids, depth) {
    ids.forEach(function(id) {
      var e = index.pages[id]
      // (The trash's and the archive's aren't in the tree.)
      if (!e || e.trashed || e.archived) return
      var kids = e.children.filter(function(c) { return index.pages[c] && !index.pages[c].trashed && !index.pages[c].archived })
      out.push({ id: id, depth: depth, title: e.title, icon: e.icon, hasChildren: kids.length > 0, open: !!(open && open[id]) })
      if (open && open[id]) walk(kids, depth + 1)
    })
  }
  walk(index.top, 0)
  return out
}

// The sidebar's two trees: { projects, pages }. Every project is at the top
// of Projects (a project inside a page or another project too), what's on
// now first (as projectList), with the pages in it under it; Pages has the
// rest. So a page is in one of them, once. A project's row has isProject,
// status, due, progress and overdue.
function sidebarRows(index, open, now) {
  function shown(id) { var e = index.pages[id]; return !!e && !e.trashed && !e.archived }
  function kidsOf(e) { return e.children.filter(function(c) { return shown(c) && !index.pages[c].project }) }
  function walk(ids, depth, out) {
    ids.forEach(function(id) {
      var e = index.pages[id]
      if (!shown(id) || e.project) return
      var kids = kidsOf(e)
      out.push({ id: id, depth: depth, title: e.title, icon: e.icon, hasChildren: kids.length > 0, open: !!(open && open[id]) })
      if (open && open[id]) walk(kids, depth + 1, out)
    })
  }
  var pages = []
  walk(index.top, 0, pages)
  var projects = []
  projectList(index, now).forEach(function(p) {
    var e = index.pages[p.id]
    var kids = kidsOf(e)
    projects.push({ id: p.id, depth: 0, title: e.title, icon: e.icon, hasChildren: kids.length > 0, open: !!(open && open[p.id]),
      isProject: true, status: p.status, due: p.due, progress: p.progress, overdue: p.overdue })
    if (open && open[p.id]) walk(kids, 1, projects)
  })
  return { projects: projects, pages: pages }
}

// The pages above a page, from the top: [{ id, title, icon }].
function path(index, id) {
  var out = []
  var seen = {}
  var p = id
  while (p && index.pages[p] && !seen[p]) {
    seen[p] = true
    out.unshift({ id: p, title: index.pages[p].title, icon: index.pages[p].icon })
    p = index.pages[p].parent
  }
  return out
}

// Puts a page in the tree: under `parent` ("" for the top) at `at` (or the end).
// Where a page dragged in the sidebar goes, dropped "before", "after" or
// "inside" the page `target` (or "end": at the end of the top of Pages):
// { parent, at (its place among the parent's pages), before, after (the
// pages beside it there) }, or null when it can't go there (into itself, or
// into a page inside it).
function dropPlace(index, id, target, where) {
  if (!index.pages[id]) return null
  if (where === "end") {
    var top = index.top.filter(function(x) { return x !== id })
    return { parent: "", at: top.length, before: "", after: top[top.length - 1] || "" }
  }
  if (!index.pages[target] || id === target || isInside(index.pages, target, id)) return null
  if (where === "inside") {
    var kids = index.pages[target].children.filter(function(x) { return x !== id })
    return { parent: target, at: kids.length, before: "", after: kids[kids.length - 1] || "" }
  }
  var parent = index.pages[target].parent
  var list = (parent && index.pages[parent] ? index.pages[parent].children : index.top).filter(function(x) { return x !== id })
  var i = list.indexOf(target)
  var at = where === "before" ? i : i + 1
  return { parent: parent, at: at, before: list[at] || "", after: at > 0 ? list[at - 1] : "" }
}

// Where a page is now, to put it back there: { parent, at, before, after }.
function placeOf(index, id) {
  var e = index.pages[id]
  if (!e) return null
  var list = (e.parent && index.pages[e.parent] ? index.pages[e.parent].children : index.top).filter(function(x) { return x !== id })
  var all = e.parent && index.pages[e.parent] ? index.pages[e.parent].children : index.top
  var at = all.indexOf(id)
  return { parent: e.parent, at: at, before: list[at] || "", after: at > 0 ? list[at - 1] : "" }
}

function attach(index, id, parent, at) {
  detach(index, id)
  var list = parent && index.pages[parent] ? index.pages[parent].children : index.top
  var i = typeof at === "number" && at >= 0 && at <= list.length ? at : list.length
  list.splice(i, 0, id)
  index.pages[id].parent = parent && index.pages[parent] ? parent : ""
}

function detach(index, id) {
  var e = index.pages[id]
  if (!e) return
  var list = e.parent && index.pages[e.parent] ? index.pages[e.parent].children : index.top
  var i = list.indexOf(id)
  if (i >= 0) list.splice(i, 1)
}

// A page's children in the index, set to the order of its page blocks (a
// page file is what's true about what's on it). Pages that were its children
// but aren't on it any more stay where they are only if they're elsewhere.
function syncChildren(index, id, ids) {
  var e = index.pages[id]
  if (!e) return false
  var wanted = ids.filter(function(c) { return index.pages[c] && c !== id && !isInsideOrSelf(index, id, c) })
  var before = e.children.join()
  wanted.forEach(function(c) {
    if (index.pages[c].parent !== id) detach(index, c)
    index.pages[c].parent = id
  })
  e.children = wanted.concat(e.children.filter(function(c) { return wanted.indexOf(c) < 0 && index.pages[c] && index.pages[c].trashed }))
  return e.children.join() !== before
}

function isInsideOrSelf(index, id, of) {
  return id === of || isInside(index.pages, id, of)
}

// The pages that link to a page (not the ones in the trash), by name.
function backlinks(index, id) {
  var out = []
  for (var pid in index.pages) {
    var e = index.pages[pid]
    if (pid !== id && e.links && e.links.indexOf(id) >= 0 && !inTrash(index, pid)) out.push(pid)
  }
  return out.sort(function(a, b) { return (index.pages[a].title || "").localeCompare(index.pages[b].title || "") })
}

// ---- reminders ---------------------------------------------------------------------------

function reminderKey(page, r) { return page + "|" + r.block + "|" + r.at }

// Reminders still to come (or come while Omanote wasn't running), soonest
// first: [{ key, page, block, at (a Date), text }].
function pendingReminders(index) {
  var out = []
  for (var pid in index.pages) {
    var e = index.pages[pid]
    if (!e.reminders || inTrash(index, pid)) continue
    e.reminders.forEach(function(r) {
      var key = reminderKey(pid, r)
      if (index.fired && index.fired[key]) return
      var d = Dates.fromIso(r.at)
      if (d) out.push({ key: key, page: pid, block: r.block, at: d.at, text: r.text })
    })
  }
  return out.sort(function(a, b) { return a.at - b.at })
}

// ---- finding pages ----------------------------------------------------------------------

function terms(query) {
  return String(query || "").toLowerCase().split(/\s+/).filter(function(t) { return t.length > 0 }).slice(0, 8)
}

// Pages whose titles have every word of the query, best first.
function findTitles(index, query, limit) {
  var list = terms(query)
  if (list.length === 0) return []
  var out = []
  for (var id in index.pages) {
    if (inTrash(index, id)) continue
    var t = (index.pages[id].title || "Untitled").toLowerCase()
    var score = 0
    for (var i = 0; i < list.length; i++) {
      var at = t.indexOf(list[i])
      if (at < 0) { score = 0; break }
      score += at === 0 ? 3 : 2
    }
    if (score > 0) out.push({ id: id, score: score, modified: index.pages[id].modified })
  }
  out.sort(function(a, b) { return b.score - a.score || (a.modified < b.modified ? 1 : -1) })
  return out.slice(0, limit || 20).map(function(r) { return r.id })
}

// How well a page matches every word of a query (0: not at all); its title counts most.
function score(title, text, query) {
  var list = terms(query)
  if (list.length === 0) return 0
  var t = String(title || "").toLowerCase()
  var body = String(text || "").toLowerCase()
  var total = 0
  for (var i = 0; i < list.length; i++) {
    var inTitle = t.indexOf(list[i]) >= 0
    var inBody = body.indexOf(list[i]) >= 0
    if (!inTitle && !inBody) return 0
    total += (inTitle ? 3 : 0) + (inBody ? 1 : 0)
  }
  return total
}

// The words around the first match: { before, match, after }.
function snippet(text, query, radius) {
  var list = terms(query)
  var body = String(text || "").replace(/\s+/g, " ").trim()
  var lower = body.toLowerCase()
  var r = radius || 40
  var at = -1
  var term = ""
  list.forEach(function(t) {
    var found = lower.indexOf(t)
    if (found >= 0 && (at < 0 || found < at)) { at = found; term = t }
  })
  if (at < 0) return { before: body.slice(0, r * 2), match: "", after: "" }
  var start = Math.max(0, at - r)
  var end = Math.min(body.length, at + term.length + r)
  return {
    before: (start > 0 ? "\u2026" : "") + body.slice(start, at),
    match: body.slice(at, at + term.length),
    after: body.slice(at + term.length, end) + (end < body.length ? "\u2026" : "")
  }
}

// ---- files --------------------------------------------------------------------------------

function pagesDir(root) { return root + "/Pages" }
// Earlier versions of a page: a file each, named for when it was kept.
function historyDir(root, id) { return root + "/Pages/history/" + id }
function pageFile(root, id) { return root + "/Pages/" + id + ".json" }
function indexFile(root) { return root + "/Pages/index.json" }
function assetsDir(root) { return root + "/Pages/assets" }

function stringify(value) {
  return JSON.stringify(value, null, 1) + "\n"
}

// A page as its file has it: each block its id, type and parent first, then
// what it says, then the blocks inside it.
function pageJson(page) {
  var blocks = {}
  for (var id in page.blocks) {
    var b = page.blocks[id]
    var out = { id: b.id, type: b.type, parent: b.parent }
    for (var k in b) if (k !== "id" && k !== "type" && k !== "parent" && k !== "content") out[k] = b[k]
    if (b.content && b.content.length) out.content = b.content
    blocks[id] = out
  }
  return stringify({
    version: VERSION, id: page.id, type: "page", parent: page.parent || "",
    title: page.title || "", icon: page.icon || "", cover: page.cover || "", format: page.format, project: page.project || undefined,
    created: page.created, modified: page.modified,
    content: page.content, blocks: blocks, text: page.text || ""
  })
}

function indexJson(index) {
  var pages = {}
  for (var id in index.pages) {
    var e = index.pages[id]
    var out = { title: e.title, icon: e.icon, parent: e.parent, children: e.children, trashed: e.trashed, created: e.created, modified: e.modified }
    if (e.links) out.links = e.links
    if (e.reminders) out.reminders = e.reminders
    if (e.tags) out.tags = e.tags
    if (e.project) out.project = e.project
    if (e.checks) out.checks = e.checks
    if (e.archived) out.archived = true
    pages[id] = out
  }
  return stringify({ version: VERSION, top: index.top, pages: pages, fired: index.fired || {}, favorites: index.favorites || [], tagColors: index.tagColors || {} })
}

// Favorites that are there, and not in the trash or the archive.
function favorites(index) {
  return (index.favorites || []).filter(function(id) { return index.pages[id] && !inTrash(index, id) && !inArchive(index, id) })
}

// A page (with the pages in it) copied: every block and page a new id, the
// page blocks pointing to the copies, and "Title (copy)". pages: the page and
// the pages in it, read; returns the copies, the first the top one.
function duplicate(pages, topId, date, random) {
  var ids = {}
  pages.forEach(function(p) { ids[p.id] = uuid4(random) })
  var now = (date || new Date()).toISOString()
  return pages.map(function(p) {
    var list = flatten(p).map(function(b) {
      var c = {}
      for (var k in b) c[k] = b[k]
      c.uid = b.type === "page" && ids[b.uid] ? ids[b.uid] : uuid4(random)
      return c
    })
    var copy = newPage({ id: ids[p.id], parent: p.id === topId ? p.parent : ids[p.parent] || p.parent,
      title: p.id === topId ? (p.title || "Untitled") + " (copy)" : p.title, icon: p.icon, cover: p.cover, format: p.format, project: p.project, blocks: list }, date, random)
    copy.created = now
    copy.modified = now
    return copy
  }).sort(function(a, b) { return a.id === ids[topId] ? -1 : b.id === ids[topId] ? 1 : 0 })
}

// ---- for agents and scripts ------------------------------------------------------------------

// A page as a command tells of it: { id, title, icon, path (the pages it's
// in, " / " between), parent, modified }; null for none.
function describe(index, id) {
  var e = index.pages[id]
  if (!e) return null
  return {
    id: id, title: e.title || "Untitled", icon: e.icon || "",
    path: path(index, id).slice(0, -1).map(function(p) { return p.title || "Untitled" }).join(" / "),
    parent: e.parent || "", modified: e.modified || ""
  }
}

// Every page that isn't in the trash, in the sidebar's order.
function allPages(index) {
  var open = {}
  for (var id in index.pages) open[id] = true
  return rows(index, open).map(function(r) { return describe(index, r.id) })
}

// The page called `name` (in any case; the last changed, if more are), or "".
function pageNamed(index, name) {
  var n = String(name || "").trim().toLowerCase()
  if (!n) return ""
  var best = ""
  for (var id in index.pages) {
    var e = index.pages[id]
    if (inTrash(index, id) || String(e.title || "").trim().toLowerCase() !== n) continue
    if (!best || String(e.modified || "") > String(index.pages[best].modified || "")) best = id
  }
  return best
}

// Blocks (as the editor has them, depths from 0) put into a page's list of
// blocks at `at`, `depth` deeper, in place of the `remove` blocks there; a
// block keeps its uid if it has a free one (a page's block, whose uid is the
// page's id). Changes the page, and returns how many went in.
function putBlocks(page, at, remove, list, depth, random) {
  var flat = flatten(page)
  var start = Math.max(0, Math.min(flat.length, at))
  var gone = flat.slice(start, start + Math.max(0, remove || 0))
  var taken = {}
  flat.forEach(function(b) { taken[b.uid] = true })
  gone.forEach(function(b) { delete taken[b.uid] })
  var added = (list || []).map(function(b) {
    var c = {}
    for (var k in b) c[k] = b[k]
    if (!isUuid(c.uid) || taken[c.uid]) c.uid = uuid4(random)
    taken[c.uid] = true
    c.indent = Math.max(0, Math.floor(Number(b.indent) || 0)) + Math.max(0, depth || 0)
    return c
  })
  var tree = unflatten(flat.slice(0, start).concat(added, flat.slice(start + gone.length)), page.id)
  var clean = cleanPage({ parent: page.parent, title: page.title, icon: page.icon, cover: page.cover, format: page.format, project: page.project,
    created: page.created, modified: page.modified, content: tree.content, blocks: tree.blocks }, page.id)
  page.content = clean.content
  page.blocks = clean.blocks
  return added.length
}

// Blocks put at the end of a page, before the empty line it ends with.
function appendBlocks(page, list, random) {
  var flat = flatten(page)
  var at = flat.length
  var last = flat[flat.length - 1]
  if (last && last.indent === 0 && last.type === "p" && Html.plainText(last.html || "") === "") at--
  return putBlocks(page, at, 0, list, 0, random)
}

// Where a block is on a page: { at (its place in the list of blocks), end
// (its last block inside), depth, block }, or null.
function locate(page, uid) {
  var flat = flatten(page)
  for (var i = 0; i < flat.length; i++) {
    if (flat[i].uid === uid) return { at: i, end: subtreeEnd(flat, i), depth: flat[i].indent, block: flat[i], list: flat }
  }
  return null
}

// A page's blocks as a command tells of them: { id, type, depth, text (its
// Markdown) } and what else a kind has; a page's block (or a link to one)
// has the page's title, from titleOf(id).
function blockList(page, md, titleOf) {
  return flatten(page).map(function(b) {
    var out = { id: b.uid, type: b.type, depth: b.indent }
    // Code as it's written; other text as Markdown.
    if (b.type === "code") out.text = Html.plainText(b.html || "")
    else if (Blocks.isText(b.type)) out.text = md(b.html || "")
    if (b.type === "check") out.checked = b.checked === true
    if (b.type === "code" && b.lang) out.lang = b.lang
    if ((b.type === "toggle" || b.toggle) && b.collapsed) out.folded = true
    if (b.type === "habit") out.days = b.days
    if (b.type === "calendar") out.month = b.month
    if (b.type === "mindmap") out.text = b.outline
    if (b.type === "table") out.text = Table.toMarkdown(b.table, md)
    if (b.type === "sketch") { out.text = "(a drawing)"; out.strokes = b.sketch ? b.sketch.strokes.length : 0 }
    if (b.type === "audio") {
      var au = b.audio || Audio.make()
      out.text = au.transcript || (au.src ? "(an audio note, " + Audio.clock(au.duration) + ", not written out)" : "(an audio note, not recorded yet)")
      if (au.src) { out.src = au.src; out.duration = au.duration }
    }
    if (b.type === "link") out.target = b.target
    if ((b.type === "page" || b.type === "link") && typeof titleOf === "function") out.title = titleOf(b.type === "page" ? b.uid : b.target)
    if (b.type === "image") out.src = b.src
    return out
  })
}

// ---- page history ---------------------------------------------------------------------------

var HISTORY_KEEP = 100

// A version's file name, for when it was kept (they sort oldest first), and
// back: "2026-10-02T09-41-05-120Z.json" <-> the date.
function versionName(date) {
  return date.toISOString().replace(/[:.]/g, "-") + ".json"
}
function versionDate(name) {
  var m = /^(\d{4}-\d{2}-\d{2})T(\d{2})-(\d{2})-(\d{2})-(\d{3})Z\.json$/.exec(String(name || ""))
  if (!m) return null
  var d = new Date(m[1] + "T" + m[2] + ":" + m[3] + ":" + m[4] + "." + m[5] + "Z")
  return isNaN(d.getTime()) ? null : d
}

// The versions in a folder's listing, newest first: [{ name, date }].
function versionList(names) {
  return (names || []).map(function(n) { return { name: n, date: versionDate(n) } })
    .filter(function(v) { return v.date !== null })
    .sort(function(a, b) { return b.date.getTime() - a.date.getTime() })
}

// The files past the newest HISTORY_KEEP (to go).
function versionsPast(names, keep) {
  return versionList(names).slice(keep || HISTORY_KEEP).map(function(v) { return v.name })
}

// The versions' labels (newest first, as versionList gives them), with the
// seconds where two are in the same minute.
function versionLabels(list, now) {
  var plain = list.map(function(v) { return versionLabel(v.date, now) })
  return list.map(function(v, i) {
    var same = (i > 0 && plain[i - 1] === plain[i]) || (i + 1 < plain.length && plain[i + 1] === plain[i])
    return same ? versionLabel(v.date, now, true) : plain[i]
  })
}

// Why a version was kept, as the history says it.
var VERSION_WHY = {
  edit: "",
  command: "Before an agent or command changed it",
  restore: "Before an older version was put back",
  tag: "Before a tag was renamed or taken away"
}
function versionWhy(why) { return VERSION_WHY[why] || "" }

// When, as the history says it: "Today 09:41", "Yesterday 18:02",
// "Mon 28 Sep 14:03", "28 Sep 2025 14:03" (and the seconds, `seconds`).
function versionLabel(date, now, seconds) {
  var d = date
  var n = now || new Date()
  function pad(x) { return (x < 10 ? "0" : "") + x }
  var time = pad(d.getHours()) + ":" + pad(d.getMinutes()) + (seconds ? ":" + pad(d.getSeconds()) : "")
  var day = new Date(d.getFullYear(), d.getMonth(), d.getDate())
  var today = new Date(n.getFullYear(), n.getMonth(), n.getDate())
  var diff = Math.round((today.getTime() - day.getTime()) / 86400000)
  var DAYS = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  var MONTHS = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
  if (diff === 0) return "Today " + time
  if (diff === 1) return "Yesterday " + time
  var date = d.getDate() + " " + MONTHS[d.getMonth()]
  if (diff > 1 && diff < 7) return DAYS[d.getDay()] + " " + date + " " + time
  return date + (d.getFullYear() !== n.getFullYear() ? " " + d.getFullYear() : "") + " " + time
}

// An earlier version of a page, made ready to put back over the page as it
// is now: its blocks (a flat list, as the editor has them), title and icon.
// Pages in the page now that the version doesn't have stay, at its end (they
// aren't thrown away); pages it had that are somewhere else now are links
// to them; pages gone for good are left out.
function versionToRestore(version, current, index) {
  var id = current.id
  var pages = (index && index.pages) || {}
  var taken = {}
  var list = []
  flatten(version).forEach(function(b) {
    var c = JSON.parse(JSON.stringify(b))
    delete c.content
    if (c.type === "page") {
      var e = pages[c.uid]
      if (!e) return
      if (e.parent !== id) c = { uid: uuid4(), type: "link", target: c.uid, indent: c.indent }
    }
    taken[c.uid] = true
    list.push(c)
  })
  childPages(current).forEach(function(pid) {
    var e = pages[pid]
    if (!taken[pid] && e && e.parent === id && !e.trashed) {
      list.push({ uid: pid, type: "page", indent: 0 })
      taken[pid] = true
    }
  })
  return { title: version.title || "", icon: version.icon || "", blocks: list }
}

// ---- tags ---------------------------------------------------------------------------------

// A page's tags (Tags.js): [{ name, label (as written), n (blocks with it) }],
// by name. Text blocks' and tables' cells.
function pageTags(page) {
  var by = {}
  function add(inner) {
    Tags.inHtml(inner).forEach(function(t) {
      if (!by[t.name]) by[t.name] = { name: t.name, label: t.label, n: 0 }
      by[t.name].n++
    })
  }
  flatten(page).forEach(function(b) {
    if (Blocks.isText(b.type) && b.type !== "code" && b.html) add(b.html)
    else if (b.type === "table" && b.table) {
      var seen = {}
      b.table.rows.forEach(function(r) { r.forEach(function(c) { Tags.inHtml(c).forEach(function(t) { seen[t.name] = t }) }) })
      for (var k in seen) {
        if (!by[k]) by[k] = { name: k, label: seen[k].label, n: 0 }
        by[k].n++
      }
    }
  })
  return Object.keys(by).sort().map(function(k) { return by[k] }).slice(0, 500)
}

function cleanTagCounts(list) {
  var out = []
  var seen = {}
  list.forEach(function(t) {
    if (!t || typeof t !== "object") return
    var name = Tags.clean(t.name)
    if (!name || name !== t.name || seen[name]) return
    seen[name] = true
    out.push({ name: name, label: Tags.label(t.label) || "#" + name, n: Math.max(1, Math.min(100000, Math.round(Number(t.n) || 1))) })
  })
  return out.slice(0, 500)
}

// A tag's color as kept: one of Pages' ("blue") or one of your own ("#ff8800").
function cleanTagColor(value) {
  return Mindmap.cleanColor(value)
}

// Every tag on a page not in the trash: [{ name, label, pages, blocks }], by name.
function tagList(index) {
  var by = {}
  for (var id in index.pages) {
    var e = index.pages[id]
    if (!e.tags || !e.tags.length || inTrash(index, id)) continue
    e.tags.forEach(function(t) {
      if (!by[t.name]) by[t.name] = { name: t.name, label: t.label, pages: 0, blocks: 0 }
      by[t.name].pages++
      by[t.name].blocks += t.n
    })
  }
  return Object.keys(by).sort().map(function(k) { return by[k] })
}

// A tag's color: its own, else that of the nearest tag it's inside
// (#work/acme takes #work's): { color, from (the tag it's from, "" for none) }.
function tagColorOf(colors, name) {
  var c = colors || {}
  var n = String(name || "")
  while (n) {
    if (c[n]) return { color: c[n], from: n }
    var i = n.lastIndexOf("/")
    n = i > 0 ? n.slice(0, i) : ""
  }
  return { color: "", from: "" }
}

// Tags in the order the sidebar shows them: by name, or ("color") by color,
// Pages' colors in their order, then colors of your own, then gray, by name
// in each; each with how deep it is under a tag in the list ("work/acme" is
// 1 under "work"). [{ name, label, pages, blocks, depth, color }]
function sortTags(list, colors, by) {
  var names = {}
  list.forEach(function(t) { names[t.name] = true })
  function depth(name) {
    var d = 0
    var n = name
    while (n.lastIndexOf("/") > 0) {
      n = n.slice(0, n.lastIndexOf("/"))
      if (names[n]) d++
    }
    return d
  }
  var out = list.map(function(t) {
    return { name: t.name, label: t.label, pages: t.pages, blocks: t.blocks, depth: by === "color" ? 0 : depth(t.name), color: tagColorOf(colors, t.name).color }
  })
  if (by === "color") {
    out.sort(function(a, b) {
      function rank(c) { var i = Blocks.COLORS.indexOf(c); return c === "" ? 1000 : i >= 0 ? i : 100 }
      var ra = rank(a.color), rb = rank(b.color)
      if (ra !== rb) return ra - rb
      if (ra === 100 && a.color !== b.color) return a.color < b.color ? -1 : 1
      return a.name < b.name ? -1 : a.name > b.name ? 1 : 0
    })
  } else {
    out.sort(function(a, b) { return a.name < b.name ? -1 : a.name > b.name ? 1 : 0 })
  }
  return out
}

// The pages with a tag (not in the trash), the most recently changed first.
function pagesTagged(index, name) {
  return Object.keys(index.pages).filter(function(id) {
    var e = index.pages[id]
    return e.tags && e.tags.some(function(t) { return t.name === name }) && !inTrash(index, id)
  }).sort(function(a, b) { return index.pages[a].modified < index.pages[b].modified ? 1 : -1 })
}

// The blocks on a page with a tag: [{ uid, type, html, checked, indent }] (a
// table's: the cells with it, side by side).
function taggedBlocks(page, name) {
  var out = []
  function has(inner) { return Tags.inHtml(inner).some(function(t) { return t.name === name }) }
  flatten(page).forEach(function(b) {
    if (Blocks.isText(b.type) && b.type !== "code" && b.html && has(b.html)) {
      out.push({ uid: b.uid, type: b.type, html: b.html, checked: b.checked === true, indent: b.indent })
    } else if (b.type === "table" && b.table) {
      var cells = []
      b.table.rows.forEach(function(r) { r.forEach(function(c) { if (has(c)) cells.push(c) }) })
      if (cells.length) out.push({ uid: b.uid, type: "table", html: cells.join(" \u00b7 "), checked: false, indent: b.indent })
    }
  })
  return out
}

// A tag renamed or taken away in a page's blocks (text and tables' cells):
// `change(inner)` -> the new text. Returns how many blocks changed.
function changeTags(page, change) {
  var n = 0
  for (var id in page.blocks) {
    var b = page.blocks[id]
    if (Blocks.isText(b.type) && b.type !== "code" && b.html) {
      var next = change(b.html)
      if (next !== b.html) { b.html = next; n++ }
    } else if (b.type === "table" && b.table) {
      var hit = false
      b.table.rows = b.table.rows.map(function(r) { return r.map(function(c) { var x = change(c); if (x !== c) hit = true; return x }) })
      if (hit) n++
    }
  }
  return n
}

// ---- projects ----------------------------------------------------------------------------

// A page can be a project: { status, due ("2026-10-12" or "") }.
var STATUSES = [
  { id: "planning", label: "Planning", color: "gray" },
  { id: "active", label: "Active", color: "blue" },
  { id: "paused", label: "Paused", color: "yellow" },
  { id: "done", label: "Done", color: "green" }
]

function statusOf(id) {
  for (var i = 0; i < STATUSES.length; i++) if (STATUSES[i].id === id) return STATUSES[i]
  return STATUSES[1]
}

function cleanProject(raw) {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null
  var status = STATUSES.some(function(s) { return s.id === raw.status }) ? raw.status : "active"
  var d = Dates.fromIso(raw.due)
  return { status: status, due: d && !d.time ? raw.due : "" }
}

function cleanChecks(raw) {
  var total = Math.max(0, Math.min(1000000, Math.round(Number(raw.total) || 0)))
  return { done: Math.max(0, Math.min(total, Math.round(Number(raw.done) || 0))), total: total }
}

// The to-dos on a page: { done, total }.
function pageChecks(page) {
  var out = { done: 0, total: 0 }
  flatten(page).forEach(function(b) {
    if (b.type !== "check") return
    out.total++
    if (b.checked) out.done++
  })
  return out
}

// A project's progress: the to-dos on it and on the pages in it (not the
// trash's): { done, total }.
function projectProgress(index, id) {
  var out = { done: 0, total: 0 }
  withDescendants(index, id).forEach(function(pid) {
    var e = index.pages[pid]
    if (!e || !e.checks || (pid !== id && e.trashed)) return
    out.done += e.checks.done
    out.total += e.checks.total
  })
  return out
}

// When a project's due, as the sidebar and its page say it: { label,
// overdue, days } ("Today", "Tomorrow", "Fri", "Fri 12 Oct", "3 days late").
function dueInfo(due, now) {
  var d = Dates.fromIso(due)
  if (!d) return null
  var n = now || new Date()
  var today = new Date(n.getFullYear(), n.getMonth(), n.getDate())
  var days = Math.round((new Date(d.at.getFullYear(), d.at.getMonth(), d.at.getDate()).getTime() - today.getTime()) / 86400000)
  var label = days === 0 ? "Today" : days === 1 ? "Tomorrow" : days === -1 ? "Yesterday"
    : days < -1 ? -days + " days late" : days < 7 ? Dates.label(d.at, false, n).split(" ")[0] : Dates.label(d.at, false, n)
  return { label: label, overdue: days < 0, days: days }
}

// The projects (not in the trash or the archive): [{ id, title, icon,
// status, due, progress, overdue }], what's on now first: active, then
// planning, then paused, then done; each by when it's due (late first, none
// last), then by name.
function projectList(index, now) {
  var out = []
  for (var id in index.pages) {
    var e = index.pages[id]
    if (!e.project || inTrash(index, id) || inArchive(index, id)) continue
    var info = dueInfo(e.project.due, now)
    out.push({ id: id, title: e.title, icon: e.icon, status: e.project.status, due: e.project.due,
      progress: projectProgress(index, id), overdue: !!(info && info.overdue && e.project.status !== "done") })
  }
  var rank = { active: 0, planning: 1, paused: 2, done: 3 }
  out.sort(function(a, b) {
    if (rank[a.status] !== rank[b.status]) return rank[a.status] - rank[b.status]
    if (a.due !== b.due) return !a.due ? 1 : !b.due ? -1 : a.due < b.due ? -1 : 1
    return (a.title || "").toLowerCase() < (b.title || "").toLowerCase() ? -1 : 1
  })
  return out
}

// ---- the archive ---------------------------------------------------------------------------

// Put away (or inside a page that is): out of the tree and the projects,
// still there to search, link to and open.
function inArchive(index, id) {
  var seen = {}
  var p = id
  while (p && index.pages[p] && !seen[p]) {
    if (index.pages[p].archived) return true
    seen[p] = true
    p = index.pages[p].parent
  }
  return false
}

// The pages put away (each with its pages inside it), the last changed first.
function archived(index) {
  return Object.keys(index.pages).filter(function(id) {
    var e = index.pages[id]
    return e.archived && !inTrash(index, id) && !(e.parent && inArchive(index, e.parent))
  }).sort(function(a, b) { return index.pages[a].modified < index.pages[b].modified ? 1 : -1 })
}

