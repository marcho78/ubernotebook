import QtQuick
import "../Html.js" as Html
import "../Blocks.js" as Blocks
import "../Papers.js" as Papers
import "../Docs.js" as Docs
import "../Workspace.js" as Workspace
import "../Mindmap.js" as Mindmap
import "../Table.js" as Table
import "../Sketch.js" as Sketch
import "../Audio.js" as Audio
import "../Meeting.js" as Meeting
import "../Calendar.js" as Calendar
import "../Tags.js" as Tags
import "../Dates.js" as Dates
import "../Emoji.js" as Emoji
import "../Highlight.js" as Highlight
import "../Import.js" as Import

// A page's writing: its blocks, one after another, and everything you can do
// to them. Each text block is its own rich-text editor (Block.qml in a
// notebook, DocBlock.qml in Pages); this decides what keys do across them
// (Enter splits a block, Backspace at its start joins it to the one above,
// the arrows move between them), formats text, pastes, picks whole blocks,
// and keeps the page's undo history.
//
// In Pages (layout "doc") it works the way Notion does: any block can hold
// others (they're the deeper blocks right after it, and go wherever it goes),
// toggles fold what's inside them away, blocks and words have colors, "/"
// offers every kind of block, Markdown typed inline (**bold**) formats, and a
// handle beside each block drags it, and what's inside it, somewhere else.
//
// Undo works on snapshots of the page: one after every pause in typing, and
// one before every change that isn't typing (formatting, a new block, a
// checkbox), so each undo step is something you'd recognize.
FocusScope {
  id: root

  // ---- how the page looks (set by the page) -------------------------------------------

  property real pitch: 30
  property string pen: "sans"
  property string spacing: "regular"
  property string family: "Adwaita Sans"
  property string monoFamily: "iA Writer Mono S"
  // Small print on the page: a habit's days, a calendar's weekdays.
  property string uiFamily: "Adwaita Sans"
  property color ink: "#1f2430"
  property color muted: "#6b7280"
  property color accent: "#2456b3"
  property color linkColor: "#2456b3"
  property color selectionColor: "#b9d3f5"
  property bool dark: false
  // The page's own color, behind everything (Pages: a mind map's circles).
  property color paper: dark ? "#1a1b26" : "#ffffff"
  property bool strikeDone: true
  property bool readOnly: false
  property real contentWidth: width
  // The app's look (Theme.qml), for what a page draws of the app's own: a
  // sketch's tools.
  property var theme: null
  // Drawing in Pages: the pen last picked, for every sketch (a color of
  // Pages', one of your own, or "" for the page's ink).
  property string sketchTool: "pen"
  property string sketchColor: ""
  property string sketchMarker: "yellow"
  property real sketchNib: Sketch.NIBS[1]
  // "assets/x.png" -> a URL the page can show. Set by the page.
  property var assetUrl: function(src) { return "" }

  // "paper" (a notebook: every line on a rule) or "doc" (a page in Pages).
  property string layout: "paper"
  readonly property bool doc: layout === "doc"
  // Pages: the page's text is small (14 px instead of 16).
  property bool smallText: false
  // Pages: what a page block shows, function(id) -> { title, icon } (or
  // null); pagesRevision changes when a page's title or icon does.
  property var pageInfo: function(id) { return null }
  property int pagesRevision: 0
  // Pages: pages for "[[", function(query) -> [{ id, title, icon, path }];
  // and a new page with a name, function(title) -> its id ("" if it wasn't made).
  property var findPages: function(query) { return [] }
  // Pages: tags for "#", function(query) -> [{ name, label, pages }]; and
  // how a tag is drawn, function(href) -> { color, background } (or null).
  property var findTags: function(query) { return [] }
  property var tagStyle: function(href) { return null }
  property var makePage: function(title) { return "" }
  // People (the "@" menu offers them): those with what's typed, [{ id,
  // name, sub, initials, tint }]; a new one with a name, its id; the link
  // for an email that's someone's ("" if it's no one's).
  property var findPeople: function(query) { return [] }
  property var makePerson: null
  property var personOfEmail: function(email) { return "" }
  // Pages: how far in a block's children start, and a list marker's room.
  readonly property real docGutter: smallText ? 24 : 27

  readonly property real gutter: Math.round(pitch * 1.05)
  // Room for a time slot's time ("07:00") or a day ("Wed 30") before its text.
  readonly property real timeGutter: Math.round(pitch * 2.2)
  readonly property real indentStep: Math.round(pitch * 1.1)
  readonly property real boxPad: Math.round(pitch * 0.45)
  readonly property real quotePad: Math.round(pitch * 0.62)

  // ---- what it tells the page ------------------------------------------------------------

  signal changed()
  // Up from the first line, or Shift+Tab at the top: back to the title.
  signal leaveTop()
  // Where the cursor is, in the editor's coordinates, to keep it in view.
  signal cursorAt(real y, real height)
  signal linkOpened(string url)
  signal pictureOpened(string src)
  // A picture on the clipboard, to go after this block.
  signal pastePicture(string afterUid)
  // Ctrl+K: put a link here (Qt would delete to the end of the line).
  signal linkRequested()
  // Blocks are drawn again (the paper, pen or colors changed).
  signal restyle()
  // Pages: a page (or a link to one) clicked; "/" asked for a page inside
  // this one, a link to a page, or a picture, in (or after) block `uid`; a
  // callout's icon, a block's handle or a code block's language clicked; a
  // code block copied.
  signal pageOpened(string id)
  signal subpageRequested(string uid)
  signal pageLinkRequested(string uid)
  // A link to a page: to another page (the picker's).
  signal pageRelinkRequested(string uid)
  signal imageRequested(string uid)
  signal iconRequested(string uid)
  signal blockMenuRequested(string uid)
  signal languageRequested(string uid)
  // A mind map's colors for the idea you're writing on, asked for (Pages).
  signal mindMapColorsRequested(string uid, var anchor)
  // A table's row or column handle clicked: its menu ("row" or "col", which one).
  signal tableMenuRequested(string uid, string kind, int index, var anchor)
  // A table's cells to color (TableBlock.colorScope says which).
  signal tableColorsRequested(string uid, var anchor)
  // A sketch's pen color to pick, beside `anchor`.
  signal sketchColorsRequested(string uid, var anchor)
  // An audio note to record into (a new one), or its colors to pick.
  signal audioRequested(string uid)
  signal audioColorsRequested(string uid, var anchor)
  // Dictation (Ctrl+Shift+D): what you say, written where you are.
  signal dictateRequested()
  // A new audio note where you are, recording (Ctrl+Shift+R).
  signal recordRequested()
  // One of your templates, put in after the block you're in ("/template").
  signal templateRequested(string uid)
  // A tag clicked: every block with it.
  signal tagOpened(string name)
  // A person named on the page, clicked (beside where: an item, a point in it).
  signal contactOpened(string id, var anchor, real x, real y)
  // "/agent" typed on a block: ask your agent (Pages).
  signal agentRequested(string uid)
  signal textCopied(string text)

  implicitHeight: doc ? docHeight : column.height

  // ---- the blocks ----------------------------------------------------------------------

  ListModel { id: blocksModel }
  property alias model: blocksModel

  // uid -> the block's text as stored (light-paper colors). The editor of a
  // block holds the newer text while you type; syncBlock() brings it back.
  property var htmls: ({})
  // uid -> its Block.qml, while it exists.
  property var items: ({})
  property var numbers: ({})
  property string focusUid: ""
  property var selectedMap: ({})
  property var selectedList: []
  property string selectionAnchor: ""
  property var formatState: ({ type: "p", inline: ({}), blocks: 0 })
  property var findMatches: ({})
  property string findCurrentUid: ""
  property int findCurrentIndex: -1

  readonly property var toDark: doc ? Docs.darkMap() : Papers.darkMap()
  readonly property var toLight: doc ? Docs.lightMap() : Papers.lightMap()

  onDarkChanged: restyle()
  onLinkColorChanged: restyle()
  onPenChanged: restyle()
  onSpacingChanged: restyle()

  function display(inner) {
    var out = dark ? Html.mapColors(inner, toDark) : inner
    // Links to pages say what the pages are called now.
    if (doc && /(?:uber-notebook|omanote):\/\/page\//.test(out)) out = Html.refreshPageLinks(out, function(id) {
      var info = root.pageInfo(id)
      return info ? root.pageLinkText(info) : ""
    })
    return out
  }

  // What a link to a page says: its icon and name.
  function pageLinkText(info) {
    return (info && info.icon ? info.icon + " " : "") + (info && info.title ? info.title : "Untitled")
  }
  function canonical(inner) { return dark ? Html.mapColors(inner, toLight) : inner }

  function row(b) {
    return {
      uid: b.uid, type: b.type, indent: b.indent || 0, checked: b.checked === true,
      align: b.align || "left", tone: b.tone || "", dstyle: b.style || "", src: b.src || "",
      imgWidth: b.type === "column" ? (b.width || 0) : (b.width || 0.6), ratio: b.ratio || 0,
      label: b.label || "", days: b.days || "", month: b.month || "", marks: b.marks || "", hint: b.hint || "",
      color: b.color || "", toggle: b.toggle === true, collapsed: b.collapsed === true, lang: b.lang || "",
      target: b.target || "", icon: b.icon || "", outline: b.outline || "", folds: b.folds || "",
      table: b.type === "table" && b.table ? JSON.stringify(b.table) : "",
      sketch: b.type === "sketch" && b.sketch ? JSON.stringify(b.sketch) : "",
      audio: b.type === "audio" && b.audio ? JSON.stringify(b.audio) : "",
      meeting: b.type === "meeting" && b.meeting ? JSON.stringify(b.meeting) : "",
      calref: (b.type === "agenda" || b.type === "event") && b.calendar ? JSON.stringify(b.calendar) : "",
      extra: Blocks.hasData(b.type) && b.data ? JSON.stringify(b.data) : ""
    }
  }

  // What a block is: the model's row as a block object.
  function rowBlock(r) {
    return { uid: r.uid, type: r.type, indent: r.indent, checked: r.checked, align: r.align, tone: r.tone, style: r.dstyle, src: r.src, width: r.imgWidth, ratio: r.ratio,
      label: r.label, days: r.days, month: r.month, marks: r.marks, hint: r.hint,
      color: r.color, toggle: r.toggle, collapsed: r.collapsed, lang: r.lang, target: r.target, icon: r.icon,
      outline: r.outline, folds: r.folds, table: r.type === "table" && r.table ? JSON.parse(r.table) : undefined,
      sketch: r.type === "sketch" && r.sketch ? JSON.parse(r.sketch) : undefined,
      audio: r.type === "audio" && r.audio ? JSON.parse(r.audio) : undefined,
      meeting: r.type === "meeting" && r.meeting ? JSON.parse(r.meeting) : undefined,
      calendar: (r.type === "agenda" || r.type === "event") && r.calref ? JSON.parse(r.calref) : undefined,
      data: Blocks.hasData(r.type) && r.extra ? JSON.parse(r.extra) : undefined }
  }

  readonly property var cleanOptions: doc ? ({ nest: true }) : null

  function blockAt(i) {
    var r = blocksModel.get(i)
    var b = rowBlock(r)
    if (Blocks.isText(r.type)) b.html = htmls[r.uid] || ""
    return Blocks.clean(b, cleanOptions)
  }

  function indexOf(uid) {
    for (var i = 0; i < blocksModel.count; i++) if (blocksModel.get(i).uid === uid) return i
    return -1
  }

  function uidAt(i) { return i >= 0 && i < blocksModel.count ? blocksModel.get(i).uid : "" }
  function typeOf(uid) { var i = indexOf(uid); return i >= 0 ? blocksModel.get(i).type : "" }

  function takenUids() {
    var taken = {}
    for (var i = 0; i < blocksModel.count; i++) taken[blocksModel.get(i).uid] = true
    return taken
  }

  function register(item) { items[item.uid] = item }
  function unregister(item) { if (items[item.uid] === item) delete items[item.uid] }

  // The block's newer text from its editor, if it has any.
  function syncBlock(uid) {
    var item = items[uid]
    if (item && item.dirty && item.type === "table") { syncTable(item); return }
    if (!item || !item.dirty || !item.isText) return
    htmls[uid] = storedOf(item)
    item.dirty = false
    // Bigger (or no longer big) text changes how many rules its lines take.
    if (!item.loading) item.measure(htmls[uid])
  }

  function syncAll() {
    for (var uid in items) syncBlock(uid)
  }

  function innerOf(edit, a, b) {
    return canonical(Html.extractInner(edit.getFormattedText(a, b)))
  }

  function setHtml(uid, inner) {
    htmls[uid] = doc && typeOf(uid) === "code" ? codeText(inner || "") : inner || ""
    if (items[uid]) items[uid].reload()
  }

  // What a block's editor holds, as it's stored. In Pages, code is plain
  // text: the colors it's shown in (its language's) aren't kept.
  function storedOf(item) {
    var inner = canonical(Html.extractInner(item.edit.getFormattedText(0, item.edit.length)))
    return doc && (item.type === "code" || item.shownCode === true) ? codeText(inner) : inner
  }

  function codeText(inner) { return Html.fromPlainText(Html.plainText(inner)) }

  // What a block's editor shows: its text, and code in its language's colors.
  function displayOf(uid, type, lang) {
    var inner = htmls[uid] || ""
    if (doc && type === "code" && Highlight.knows(lang)) return Highlight.html(Html.plainText(inner), lang, dark)
    return display(inner)
  }

  // A block that became code, or stopped being code: its text as it was
  // shown, then as it is now.
  function retyped(item) {
    if (!restoring) syncBlock(item.uid)
    if (doc && item.type === "code") htmls[item.uid] = codeText(htmls[item.uid] || "")
    item.reload()
  }

  // Code is colored again a moment after you stop typing in it (what's
  // typed takes the color before it till then).
  property string codeUid: ""
  Timer {
    id: codeTimer
    interval: 300
    onTriggered: root.recolor(root.codeUid)
  }

  function recolor(uid) {
    var item = items[uid]
    if (!item || !item.isText || item.type !== "code") return
    var e = item.edit
    if (e.inputMethodComposing) { codeTimer.restart(); return }
    var a = e.selectionStart
    var b = e.selectionEnd
    var backwards = e.cursorPosition === a && a !== b
    syncBlock(uid)
    item.reload()
    if (a !== b && e.activeFocus) {
      if (backwards) e.select(b, a)
      else e.select(a, b)
    }
  }

  // ---- loading and saving ----------------------------------------------------------------

  function load(blocks) {
    burstTimer.stop()
    burstOpen = false
    inOp = false
    restoring = false
    pending = null
    clearBlockSelection()
    clearFind()
    closeSlash()
    closeMention()
    var list = Blocks.cleanList(blocks, cleanOptions)
    if (doc) {
      list = Workspace.applyFix(list, Workspace.fixColumns(list))
      Workspace.normalizeDepths(list)
      // A block from elsewhere (a notebook, the clipboard) gets a UUID here.
      var taken = {}
      list.forEach(function(b) { if (!Workspace.isUuid(b.uid) || taken[b.uid]) b.uid = root.newId(taken); taken[b.uid] = true })
    }
    var map = {}
    for (var i = 0; i < list.length; i++) map[list[i].uid] = doc && list[i].type === "code" ? codeText(list[i].html || "") : list[i].html || ""
    htmls = map
    blocksModel.clear()
    for (var j = 0; j < list.length; j++) blocksModel.append(row(list[j]))
    refreshNumbers()
    undoStack = []
    redoStack = []
    focusUid = ""
    stable = snapshot()
    updateFormat()
  }

  // The page's blocks as they are now, to save.
  function serialize() {
    syncAll()
    var out = []
    for (var i = 0; i < blocksModel.count; i++) {
      var b = blockAt(i)
      if (b) out.push(b)
    }
    return out
  }

  function refreshNumbers() {
    var list = []
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      list.push({ uid: r.uid, type: r.type, indent: r.indent })
    }
    numbers = Blocks.numbering(list, doc)
    if (doc) {
      docLayout = computeLayout()
      positionBlocks()
    }
    structure++
  }

  // Counts every change to what the blocks are (not to their text).
  property int structure: 0

  // ---- Pages: blocks inside blocks ------------------------------------------------------

  // uid -> where a block is on a page in Pages: { x (where it starts),
  // hidden (inside a folded toggle), kids (it has blocks inside it), lists
  // (how many bulleted or numbered items it's inside), boxes
  // (the callouts, colored blocks and quotes it's in, itself included,
  // outermost first: { uid, x, color, bar, last (the last block showing in
  // it) }) }.
  property var docLayout: ({})

  function newId(taken) {
    for (var i = 0; i < 20; i++) {
      var id = Workspace.uuid4()
      if (!taken || !taken[id]) return id
    }
    return Workspace.uuid4()
  }

  // How far in the blocks inside a block start: past a list's marker, a
  // callout's icon, a quote's bar.
  function childOffset(r) {
    if (r.type === "callout") return docGutter + 20
    if (r.type === "quote") return 18
    return docGutter
  }

  // The background a block (and what's inside it) has, or "".
  function boxColor(r) {
    var c = Docs.blockColors(r.color, dark).background
    if (r.type === "callout") return c || Docs.calloutBackground(dark)
    return c
  }

  // The room between two columns (the handles of the next column's blocks sit in it).
  readonly property real columnGap: 46

  function computeLayout() {
    var n = blocksModel.count
    var out = {}
    var stack = []
    var page = { left: 0, w: contentWidth }
    for (var i = 0; i < n; i++) {
      var r = blocksModel.get(i)
      while (stack.length && stack[stack.length - 1].indent >= r.indent) stack.pop()
      var parent = stack.length ? stack[stack.length - 1] : null
      var flow = parent ? parent.flow : page
      var x = parent ? parent.childX : 0
      var next = i + 1 < n ? blocksModel.get(i + 1) : null
      if (r.type === "column" && parent && parent.columnFlows && parent.columnFlows[r.uid]) flow = parent.columnFlows[r.uid]
      var info = { left: flow.left, w: flow.w, x: x, hidden: stack.some(function(a) { return a.folded }), kids: !!next && next.indent > r.indent, boxes: [],
        lists: stack.filter(function(a) { return a.list }).length }
      stack.forEach(function(a) { if (a.box) info.boxes.push(a.box) })
      var color = boxColor(r)
      var me = { indent: r.indent, flow: flow, childX: x + childOffset(r), folded: Workspace.folds(rowBlock(r)) && r.collapsed, box: null, list: r.type === "bullet" || r.type === "number" }
      if (color || r.type === "quote") {
        me.box = { uid: r.uid, x: x, color: color, bar: r.type === "quote", callout: r.type === "callout", last: r.uid }
        info.boxes.push(me.box)
      }
      if (r.type === "columns") {
        // Its columns side by side, each its share of the width.
        var cols = []
        for (var j = i + 1; j < n && blocksModel.get(j).indent > r.indent; j++) {
          var c = blocksModel.get(j)
          if (c.type === "column" && c.indent === r.indent + 1) cols.push(c)
        }
        var shares = cols.map(function(c) { return c.imgWidth > 0 ? c.imgWidth : 1 / Math.max(1, cols.length) })
        var total = shares.reduce(function(a, b) { return a + b }, 0) || 1
        var usable = flow.w - columnGap * Math.max(0, cols.length - 1)
        var left = flow.left
        me.columnFlows = {}
        cols.forEach(function(c, k) {
          var w = usable * shares[k] / total
          me.columnFlows[c.uid] = { left: left, w: w }
          left += w + columnGap
        })
        me.childX = 0
      }
      if (r.type === "column") me.childX = 0
      if (!info.hidden) info.boxes.forEach(function(b) { b.last = r.uid })
      out[r.uid] = info
      stack.push(me)
    }
    return out
  }

  // Pages: every block's place, from the top, the blocks in columns side by
  // side. Heights come from the blocks, so this runs again whenever one
  // changes height (a line wraps, a picture loads).
  property real docHeight: 0
  // The gaps between columns: { columns, left, right (the columns' uids), top, height }.
  property var columnGaps: []

  function schedulePosition() {
    if (doc) Qt.callLater(positionBlocks)
  }

  function positionBlocks() {
    if (!doc) return
    var n = blocksModel.count
    var y = 0
    var gaps = []
    var i = 0
    while (i < n) {
      var r = blocksModel.get(i)
      var item = items[r.uid]
      if (r.type === "columns") {
        var last = subtreeEnd(i)
        var top = y + 4
        var bottom = top
        var cols = []
        if (item) item.y = top
        for (var j = i + 1; j <= last; j = subtreeEnd(j) + 1) {
          var cy = top
          for (var k = j; k <= subtreeEnd(j); k++) {
            var it = items[uidAt(k)]
            if (!it) continue
            it.y = cy
            cy += it.height
          }
          bottom = Math.max(bottom, cy)
          cols.push(uidAt(j))
        }
        for (var g = 0; g + 1 < cols.length; g++) gaps.push({ columns: r.uid, left: cols[g], right: cols[g + 1], top: top, height: bottom - top })
        y = bottom + 4
        i = last + 1
      } else {
        if (item) {
          item.y = y
          y += item.height
        }
        i++
      }
    }
    docHeight = y
    columnGaps = gaps
  }

  onContentWidthChanged: if (doc) refreshNumbers()

  // Columns that make sense after a change (Workspace.fixColumns): no empty
  // column, no columns with one column left.
  function normalizeColumns() {
    var list = []
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      list.push({ uid: r.uid, type: r.type, indent: r.indent })
    }
    var fix = Workspace.fixColumns(list)
    if (!fix) return
    for (var uid in fix.indent) {
      var k = indexOf(uid)
      if (k >= 0) blocksModel.setProperty(k, "indent", fix.indent[uid])
    }
    fix.remove.forEach(function(gone) {
      var at = indexOf(gone)
      if (at >= 0) removeAt(at)
    })
  }

  // The block a block is inside (-1: the page).
  function parentIndex(index) {
    var d = blocksModel.get(index).indent
    for (var j = index - 1; j >= 0; j--) if (blocksModel.get(j).indent < d) return j
    return -1
  }

  function inColumn(index) {
    var p = index >= 0 ? parentIndex(index) : -1
    return p >= 0 && blocksModel.get(p).type === "column"
  }

  // "/2 columns": empty columns after the block (or in place of an empty one).
  function insertColumns(uid, count) {
    var i = indexOf(uid)
    if (i < 0) return
    var top = i
    while (top > 0 && blocksModel.get(top).indent > 0) top--
    var r = blocksModel.get(i)
    beginOp()
    var at
    var empty = r.indent === 0 && Blocks.isText(r.type) && subtreeEnd(i) === i && Html.plainText(htmls[r.uid] || "") === "" && !(items[r.uid] && items[r.uid].edit.length > 0)
    if (empty) {
      at = i
      removeAt(i)
    } else {
      at = subtreeEnd(top) + 1
    }
    insertBlock(at, { type: "columns", indent: 0 }, "")
    var first = ""
    for (var c = 0; c < count; c++) {
      insertBlock(at + 1 + c * 2, { type: "column", indent: 1 }, "")
      var p = insertBlock(at + 2 + c * 2, { type: "p", indent: 2 }, "")
      if (!first) first = p
    }
    if (at + 1 + count * 2 >= blocksModel.count) insertBlock(blocksModel.count, { type: "p", indent: 0 }, "")
    endOp()
    focusBlock(first, 0)
  }

  // Dragging the gap between two columns: every column in them gets its
  // share as a fraction first; then the two either side of the gap trade.
  function beginColumnResize(columnsUid) {
    var i = indexOf(columnsUid)
    if (i < 0) return null
    beginOp()
    var list = []
    for (var j = i + 1; j <= subtreeEnd(i); j = subtreeEnd(j) + 1) list.push(j)
    var shares = list.map(function(j) { var w = blocksModel.get(j).imgWidth; return w > 0 ? w : 1 / list.length })
    var total = shares.reduce(function(a, b) { return a + b }, 0) || 1
    var start = {}
    list.forEach(function(j, k) {
      blocksModel.setProperty(j, "imgWidth", shares[k] / total)
      start[uidAt(j)] = shares[k] / total
    })
    var info = docLayout[columnsUid] || { w: contentWidth }
    start.usable = Math.max(1, info.w - columnGap * Math.max(0, list.length - 1))
    return start
  }

  function resizeColumns(start, leftUid, rightUid, dx) {
    var a = start[leftUid]
    var b = start[rightUid]
    if (a === undefined || b === undefined) return
    var min = 0.08
    var next = Math.max(min, Math.min(a + b - min, a + dx / start.usable))
    blocksModel.setProperty(indexOf(leftUid), "imgWidth", next)
    blocksModel.setProperty(indexOf(rightUid), "imgWidth", a + b - next)
    refreshNumbers()
  }

  function endColumnResize() {
    endOp()
  }

  function isHidden(uid) {
    return doc && !!docLayout[uid] && docLayout[uid].hidden === true
  }

  // Depths that make sense after a change (Workspace.normalizeDepths).
  function normalizeModel() {
    var prev = null
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      var max = prev ? prev.indent + (Workspace.canNest(prev.type, prev) ? 1 : 0) : 0
      var depth = Math.min(r.indent, max)
      if (depth !== r.indent) blocksModel.setProperty(i, "indent", depth)
      prev = { indent: depth, type: r.type, toggle: r.toggle }
    }
  }

  // The last block inside the block at index (itself if it has none).
  function subtreeEnd(index) {
    var n = blocksModel.count
    if (index < 0 || index >= n) return index
    var d = blocksModel.get(index).indent
    var j = index
    while (j + 1 < n && blocksModel.get(j + 1).indent > d) j++
    return j
  }

  // The block before it at its depth, inside the same block (-1: none).
  function previousSibling(index) {
    var d = blocksModel.get(index).indent
    for (var j = index - 1; j >= 0; j--) {
      var e = blocksModel.get(j).indent
      if (e === d) return j
      if (e < d) return -1
    }
    return -1
  }

  // Blocks picked, each with what's inside it, as [first, last] index ranges.
  function subtreeRanges(uids) {
    var indices = uids.map(indexOf).filter(function(i) { return i >= 0 }).sort(function(a, b) { return a - b })
    var out = []
    indices.forEach(function(i) {
      if (out.length && i <= out[out.length - 1][1]) return
      out.push([i, doc ? subtreeEnd(i) : i])
    })
    return out
  }

  // A toggle folded or unfolded. Not something to undo; it's saved with the page.
  function setCollapsed(uid, collapsed) {
    var i = indexOf(uid)
    if (i < 0) return
    closeBurst()
    blocksModel.setProperty(i, "collapsed", collapsed)
    refreshNumbers()
    stable = snapshot()
    changed()
    // The cursor doesn't stay inside what folded away.
    if (collapsed && focusUid && isHidden(focusUid)) focusBlock(uid, -1)
  }

  function toggleFold(uid) {
    var i = indexOf(uid)
    if (i >= 0) setCollapsed(uid, !blocksModel.get(i).collapsed)
  }

  // Blocks' text or background color ("" for none).
  function setBlockColor(uids, color) {
    var keepFocus = focusInfo()
    beginOp()
    uids.forEach(function(u) {
      var i = indexOf(u)
      if (i >= 0) blocksModel.setProperty(i, "color", color)
    })
    endOp()
    restoreFocus(keepFocus)
  }

  function setProp(uid, key, value) {
    var i = indexOf(uid)
    if (i < 0) return
    beginOp()
    blocksModel.setProperty(i, key, value)
    endOp()
  }

  // Blocks made another kind (in Pages, a toggle heading if `toggle`), as one step.
  function turnInto(uids, type, toggle) {
    var list = uids.filter(function(u) { return Blocks.isText(typeOf(u)) })
    if (list.length === 0) return
    var keepFocus = focusInfo()
    beginOp()
    list.forEach(function(u) {
      syncBlock(u)
      convert(u, type, false)
      var i = indexOf(u)
      blocksModel.setProperty(i, "toggle", toggle === true && (type === "h1" || type === "h2" || type === "h3"))
      if (type === "callout" && !blocksModel.get(i).icon) blocksModel.setProperty(i, "icon", "\u{1f4a1}")
    })
    endOp()
    restoreFocus(keepFocus)
  }

  // Where the selected words are, in the editor's coordinates.
  function selectionRect() {
    var item = items[focusUid]
    if (!item || !item.isText) return Qt.rect(0, 0, 0, 0)
    var e = item.edit
    var a = e.positionToRectangle(e.selectionStart)
    var b = e.positionToRectangle(e.selectionEnd)
    var oneLine = a.y === b.y
    var left = oneLine ? Math.min(a.x, b.x) : 0
    var right = oneLine ? Math.max(a.x, b.x) : e.width
    return Qt.rect(item.x + e.x + left, item.y + e.y + Math.min(a.y, b.y), right - left, Math.max(a.y + a.height, b.y + b.height) - Math.min(a.y, b.y))
  }

  // + beside a block: a new block after it (and what's inside it), with the
  // "/" menu open in it; an empty text block takes the menu itself.
  function addBelow(uid) {
    var i = indexOf(uid)
    if (i < 0 || readOnly) return
    var r = blocksModel.get(i)
    var target = uid
    var empty = Blocks.isText(r.type) && Html.plainText(htmls[r.uid] || "") === "" && !(items[r.uid] && items[r.uid].edit.length > 0)
    if (!empty) {
      beginOp()
      target = insertBlock(subtreeEnd(i) + 1, { type: "p", indent: r.indent }, "")
      endOp()
    }
    focusBlock(target, 0)
    var item = items[target]
    if (item) item.edit.insert(0, "/")
  }

  // The first block inside a toggle (or any block that can hold one).
  function addChild(uid) {
    var i = indexOf(uid)
    if (i < 0 || readOnly) return
    var r = blocksModel.get(i)
    if (r.collapsed) blocksModel.setProperty(i, "collapsed", false)
    beginOp()
    var child = insertBlock(i + 1, { type: "p", indent: r.indent + 1 }, "")
    endOp()
    focusBlock(child, 0)
  }

  // A block and everything inside it, taken out for another block in its
  // place (a page, when it's turned into one), as one step.
  function replaceSubtree(uid, props) {
    var i = indexOf(uid)
    if (i < 0) return ""
    var end = subtreeEnd(i)
    var depth = blocksModel.get(i).indent
    beginOp()
    for (var k = end; k >= i; k--) removeAt(k)
    var p = {}
    for (var key in props) p[key] = props[key]
    p.indent = depth
    var made = insertBlock(i, p, "")
    if (indexOf(made) === blocksModel.count - 1) insertBlock(blocksModel.count, { type: "p", indent: 0 }, "")
    endOp()
    return made
  }

  // ---- Pages: mind maps ---------------------------------------------------------------

  // A mind map's ideas (an outline, Mindmap.js) and which are folded, as one step.
  function setMindMap(uid, outline, folds) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "mindmap") return
    var clean = Mindmap.clean(outline)
    if (!clean) return
    var f = Mindmap.cleanFolds(folds, Mindmap.count(clean))
    if (clean === blocksModel.get(i).outline && f === blocksModel.get(i).folds) return
    beginOp()
    blocksModel.setProperty(i, "outline", clean)
    blocksModel.setProperty(i, "folds", f)
    endOp()
  }

  // ---- Pages: sketches -------------------------------------------------------------------

  // A sketch changed (a stroke drawn or erased, its height, its background), as one step.
  function setSketch(uid, sketch) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "sketch") return
    var clean = Sketch.clean(sketch)
    if (!clean) return
    var json = JSON.stringify(clean)
    if (json === blocksModel.get(i).sketch) return
    beginOp()
    blocksModel.setProperty(i, "sketch", json)
    endOp()
  }

  // ---- Pages: audio notes ----------------------------------------------------------------

  // The audio note playing (one at a time).
  property string playingUid: ""
  // The microphone (Recorder.qml), and the audio notes being worked on:
  // { uid: "transcribe" (written out) or "louder" (made louder) }.
  property var recorder: null
  property var audioWork: ({})
  // An audio note's button: "record", "stop", "cancel", "transcribe", "louder".
  signal audioAction(string uid, string what)

  // An audio note changed (recorded, written out, its colors), as one step.
  function setAudio(uid, audio) {
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "audio") return false
    var clean = Audio.clean(audio)
    if (!clean) return false
    var json = JSON.stringify(clean)
    if (json === blocksModel.get(i).audio) return true
    beginOp()
    blocksModel.setProperty(i, "audio", json)
    endOp()
    return true
  }

  // Words said (dictation), written where you are: at the cursor in the
  // block you're in (a space before them when they need one), or on a new
  // line at the end of the page.
  function dictated(text) {
    if (readOnly) return false
    var words = String(text || "").replace(/\s+/g, " ").trim()
    if (!words) return false
    var item = items[focusUid]
    if (item && item.isText && item.edit) {
      var e = item.edit
      var before = e.getText(Math.max(0, e.selectionStart - 1), e.selectionStart)
      insertText(focusUid, Audio.joinAfter(before, words))
      return true
    }
    // (An empty line at the end takes them.)
    var last = blocksModel.count - 1
    if (last >= 0 && Blocks.isText(blocksModel.get(last).type) && Html.plainText(htmls[uidAt(last)] || "") === "" && items[uidAt(last)]) {
      var lastUid = uidAt(last)
      focusBlock(lastUid, 0)
      insertText(lastUid, words)
      return true
    }
    beginOp()
    var made = insertBlock(blocksModel.count, { type: "p", indent: 0 }, Html.escapeText(words))
    endOp()
    focusBlock(made, -1)
    return true
  }

  // ---- Pages: meetings -------------------------------------------------------------------

  // voxtype's meeting mode (Meetings.qml).
  property var meetings: null
  // The meetings being written out or brought in: { uid: true }.
  property var meetingWork: ({})
  // A meeting's button: "start", "stop", "pause", "resume", "enable", "import",
  // "fetch", "summarize"; "name" with { speaker, name }.
  signal meetingAction(string uid, string what, var arg)
  signal meetingColorsRequested(string uid, var anchor)
  // A new meeting, from "/meeting": it starts.
  signal meetingRequested(string uid)

  // A meeting changed (started, written out, a speaker named, its colors), as one step.
  function setMeeting(uid, meeting) {
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "meeting") return false
    var clean = Meeting.clean(meeting)
    if (!clean) return false
    var json = JSON.stringify(clean)
    if (json === blocksModel.get(i).meeting) return true
    beginOp()
    blocksModel.setProperty(i, "meeting", json)
    endOp()
    return true
  }

  function meetingOf(uid) {
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "meeting") return null
    try { return Meeting.clean(JSON.parse(blocksModel.get(i).meeting)) } catch (e) { return Meeting.make() }
  }

  // The meeting block on the page that's voxtype's meeting `id` ("" if none).
  function meetingBlock(id) {
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      if (r.type !== "meeting" || !r.meeting) continue
      try { if (JSON.parse(r.meeting).id === id) return r.uid } catch (e) {}
    }
    return ""
  }

  // ---- Pages: buttons, files, videos, bookmarks, boards, synced blocks ------------------------

  // The ones being worked on ({ uid: true }: a bookmark's page being read).
  property var dataWork: ({})
  // What one of them asks for: "new" (just made: pick its file, its link, set it up),
  // "colors" (`arg` the anchor), and their own ("press", "open", "fetch", "edit"...).
  signal dataAction(string uid, string what, var arg)

  // A block's `data` changed, as one step.
  function setData(uid, data) {
    var i = indexOf(uid)
    if (i < 0 || !Blocks.hasData(blocksModel.get(i).type)) return false
    var json = JSON.stringify(Blocks.cleanData(blocksModel.get(i).type, data))
    if (json === blocksModel.get(i).extra) return true
    beginOp()
    blocksModel.setProperty(i, "extra", json)
    endOp()
    return true
  }

  function dataOf(uid) {
    var i = indexOf(uid)
    if (i < 0 || !Blocks.hasData(blocksModel.get(i).type)) return null
    try { return Blocks.cleanData(blocksModel.get(i).type, JSON.parse(blocksModel.get(i).extra || "{}")) } catch (e) { return Blocks.cleanData(blocksModel.get(i).type, {}) }
  }

  // ---- Pages: the calendar's blocks ---------------------------------------------------------

  // The workspace's calendar (for an agenda or an event block).
  property var calendarSource: null
  // An agenda's or an event block's buttons: "add" (an event that day),
  // "open" (an event, `arg` { id, day, anchor }), "colors" (its, `arg` the anchor).
  signal calendarAction(string uid, string what, var arg)
  // "/event": a new event, typed, and its block where the "/" was.
  signal eventRequested(string uid)

  // An agenda's or an event block's data changed (the day it shows, its colors), as one step.
  function setCalRef(uid, ref) {
    var i = indexOf(uid)
    if (i < 0 || (blocksModel.get(i).type !== "agenda" && blocksModel.get(i).type !== "event")) return false
    var json = JSON.stringify(Calendar.cleanRef(ref))
    if (json === blocksModel.get(i).calref) return true
    beginOp()
    blocksModel.setProperty(i, "calref", json)
    endOp()
    return true
  }

  // An audio note's data as the page has it now (or null).
  function audioOf(uid) {
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "audio") return null
    try { return Audio.clean(JSON.parse(blocksModel.get(i).audio)) } catch (e) { return Audio.make() }
  }

  // Drawing on a sketch: it's where you are on the page.
  function sketchFocused(uid) {
    closeSlash()
    closeMention()
    if (focusUid !== uid && items[focusUid] && items[focusUid].isText) items[focusUid].edit.deselect()
    focusUid = uid
    if (selectedList.length > 0 && !dragSelecting) clearBlockSelection()
  }

  // Done writing in a block's own field (a board's card or column name):
  // the keyboard back to the page (undo and the rest), no text under it.
  function parkFocus() {
    if (selectedList.length > 0 && !dragSelecting) clearBlockSelection()
    keyCatcher.forceActiveFocus()
  }

  // ---- Pages: tables ---------------------------------------------------------------------

  // A table's cells as they're being written, into the page.
  function syncTable(item) {
    var i = indexOf(item.uid)
    item.dirty = false
    var json = item.tableJson()
    if (i >= 0 && json && blocksModel.get(i).table !== json) blocksModel.setProperty(i, "table", json)
  }

  // Writing in a table's cell: like typing in a block, a burst of it is one
  // step to undo.
  function tableTyped(item) {
    if (restoring || inOp || readOnly) return
    if (!burstOpen) {
      pushUndo(stable)
      redoStack = []
      burstOpen = true
    }
    burstTimer.restart()
    changed()
  }

  // A table changed another way (a row or a column in, out or moved, a
  // width, the header row, formatting), as one step.
  function setTable(uid, table) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "table") return
    var clean = Table.clean(table)
    if (!clean) return
    closeBurst()
    var json = JSON.stringify(clean)
    if (json === blocksModel.get(i).table) return
    beginOp()
    blocksModel.setProperty(i, "table", json)
    endOp()
  }

  // The cursor's in a table's cell.
  function tableFocused(uid) {
    closeSlash()
    closeMention()
    if (focusUid !== uid && items[focusUid] && items[focusUid].isText) items[focusUid].edit.deselect()
    focusUid = uid
    if (selectedList.length > 0 && !dragSelecting) clearBlockSelection()
  }

  // Up or down out of a table, `x` across the page: into the block above or
  // below (or the table past it).
  function leaveTable(uid, dir, x) {
    var target = cursorNeighbor(indexOf(uid), dir)
    if (target < 0) {
      if (dir < 0) leaveTop()
      return
    }
    var dest = items[uidAt(target)]
    if (!dest) return
    if (dest.type === "table") { dest.enter(dir, x - dest.x); return }
    var y = dir < 0 ? dest.edit.contentHeight - dest.lineHeight * 0.5 : dest.lineHeight * 0.5
    focusBlock(dest.uid, dest.edit.positionAt(Math.max(0, x - dest.x - dest.edit.x), Math.max(0, y)))
  }

  // The next block the cursor can go to: text, or a table.
  function cursorNeighbor(index, dir) {
    for (var i = index + dir; i >= 0 && i < blocksModel.count; i += dir) {
      var r = blocksModel.get(i)
      if ((Blocks.isText(r.type) || r.type === "table") && !isHidden(r.uid)) return i
    }
    return -1
  }

  // A table as HTML (copied, for other apps).
  function tableHtml(t) {
    if (!t) return ""
    return "<table border=\"1\" cellspacing=\"0\" cellpadding=\"4\">" + t.rows.map(function(r, i) {
      var tag = t.header && i === 0 ? "th" : "td"
      return "<tr>" + r.map(function(c, k) {
        var tint = Table.colorOf(t, i, k)
        function hex(id, back) { var e = Docs.colorEntry(id); return e ? (back ? e.background[0] : e.text[0]) : id }
        var style = (tint.color ? "color:" + hex(tint.color, false) + ";" : "") + (tint.background ? "background-color:" + hex(tint.background, true) + ";" : "")
        return "<" + tag + (style ? " style=\"" + style + "\"" : "") + ">" + c + "</" + tag + ">"
      }).join("") + "</tr>"
    }).join("") + "</table>"
  }

  // A branch folded or unfolded: like a toggle, saved but not a step to undo.
  function setMindMapFolds(uid, folds) {
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "mindmap") return
    closeBurst()
    blocksModel.setProperty(i, "folds", Mindmap.cleanFolds(folds, Mindmap.count(blocksModel.get(i).outline)))
    stable = snapshot()
    changed()
  }

  // Starts writing on a mind map's topic.
  function editMindMap(uid) {
    var item = items[uid]
    if (item && typeof item.startMindMap === "function") item.startMindMap()
  }

  // Blocks (and what's inside them) as a mind map in their place, as one
  // step: one block is the topic and what's inside it the ideas; several are
  // the ideas of a topic called "Mind map". Not when a page is among them
  // (it would go with them). The mind map's uid, or "".
  function toMindMap(uids) {
    if (readOnly) return ""
    var ranges = subtreeRanges(uids)
    if (ranges.length === 0) return ""
    syncAll()
    var rows = []
    ranges.forEach(function(r) {
      for (var k = r[0]; k <= r[1]; k++) {
        var row = blocksModel.get(k)
        rows.push({ uid: row.uid, type: row.type, indent: row.indent, outline: row.outline, color: row.color, table: row.table })
      }
    })
    // (Pages and drawings aren't ideas: they'd be lost.)
    if (rows.some(function(b) { return b.type === "page" || b.type === "sketch" || b.type === "audio" || b.type === "meeting" || b.type === "agenda" || b.type === "event" || Blocks.hasData(b.type) })) return ""
    function words(b) { return Blocks.isText(b.type) ? Html.plainText(htmls[b.uid] || "").replace(/\s+/g, " ").trim() : "" }
    // A table's rows are ideas: their cells' words.
    function tableIdeas(b, depth) {
      var t = b.table ? JSON.parse(b.table) : null
      if (!t) return []
      return t.rows.map(function(r) { return r.map(function(c) { return Html.plainText(c).replace(/\s+/g, " ").trim() }).filter(function(x) { return x !== "" }).join(" \u00b7 ") })
        .filter(function(x) { return x !== "" }).map(function(x) { return { text: x, depth: depth, color: "", background: "" } })
    }
    // A block's color is its idea's: its text's, or its background's.
    function idea(b, depth) {
      var c = String(b.color || "")
      var bg = /_background$/.test(c)
      return { text: words(b), depth: depth, color: bg ? "" : c, background: bg ? c.replace(/_background$/, "") : "" }
    }
    var base = Math.min.apply(null, rows.map(function(b) { return b.indent }))
    var single = ranges.length === 1
    var items = []
    rows.forEach(function(b, n) {
      if (single && n === 0) return
      var depth = b.indent - base + (single ? 0 : 1)
      if (b.type === "mindmap") Mindmap.toList(b.outline).forEach(function(it) { it.depth += depth; items.push(it) })
      else if (b.type === "table") tableIdeas(b, depth).forEach(function(it) { items.push(it) })
      else if (words(b)) items.push(idea(b, depth))
    })
    var outline = Mindmap.fromList(single ? idea(rows[0], 0) : "Mind map", items)
    var at = ranges[0][0]
    var depthAt = blocksModel.get(at).indent
    beginOp()
    for (var j = ranges.length - 1; j >= 0; j--) for (var k = ranges[j][1]; k >= ranges[j][0]; k--) removeAt(k)
    var made = insertBlock(at, { type: "mindmap", outline: outline, indent: depthAt }, "")
    if (indexOf(made) === blocksModel.count - 1) insertBlock(blocksModel.count, { type: "p", indent: 0 }, "")
    endOp()
    clearBlockSelection()
    return made
  }

  // A mind map as a bulleted list: its topic, and its ideas inside it.
  function mindMapToList(uid) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "mindmap") return
    replaceWithBlocks(uid, Mindmap.toList(blocksModel.get(i).outline).map(function(it) {
      return { type: "bullet", html: Html.escapeText(it.text), indent: it.depth,
        color: it.background ? it.background + "_background" : it.color }
    }))
    clearBlockSelection()
  }

  // Blocks a command sends in place of a block and the blocks inside it, as
  // deep as it was, as one step. The cursor stays where it is, or, if it was
  // in what went, goes to the end of what came.
  function replaceWithBlocks(uid, list) {
    var i = indexOf(uid)
    if (i < 0 || !list || list.length === 0) return
    var end = subtreeEnd(i)
    var depth = blocksModel.get(i).indent
    var hadCursor = false
    for (var k = i; k <= end; k++) if (uidAt(k) === focusUid) hadCursor = true
    beginOp()
    for (var j = end; j >= i; j--) removeAt(j)
    var last = ""
    list.forEach(function(b, n) {
      var props = {}
      for (var key in b) props[key] = b[key]
      props.indent = (b.indent || 0) + depth
      last = insertBlock(i + n, props, Blocks.isText(b.type) ? b.html || "" : "")
    })
    endOp()
    if (hadCursor && last) focusBlock(last, -1)
  }

  // Blocks a command sends, put after a block and the blocks inside it, as
  // deep as it is, as one step; the cursor stays where it is.
  function insertAfterBlock(uid, list) {
    var i = indexOf(uid)
    if (i < 0 || !list || list.length === 0) return
    var depth = blocksModel.get(i).indent
    insertBlocksAt(subtreeEnd(i) + 1, list.map(function(b) {
      var c = {}
      for (var key in b) c[key] = b[key]
      c.indent = (b.indent || 0) + depth
      return c
    }), true)
  }

  // Every block replaced by `list` as it is (their ids kept: an earlier
  // version of the page put back), as one step.
  function resetBlocks(list) {
    if (readOnly || !list) return
    var clean = Blocks.cleanList(list, cleanOptions)
    if (doc) {
      clean = Workspace.applyFix(clean, Workspace.fixColumns(clean))
      Workspace.normalizeDepths(clean)
    }
    clearBlockSelection()
    closeSlash()
    closeMention()
    beginOp()
    for (var k = blocksModel.count - 1; k >= 0; k--) removeAt(k)
    clean.forEach(function(b, n) {
      htmls[b.uid] = doc && b.type === "code" ? codeText(b.html || "") : b.html || ""
      blocksModel.insert(n, row(b))
    })
    endOp()
  }

  // Every block replaced by `list` (a template on a blank page), as one
  // step; the cursor goes to the first empty line to write on.
  function replaceAll(list) {
    if (!list || list.length === 0) return
    beginOp()
    for (var k = blocksModel.count - 1; k >= 0; k--) removeAt(k)
    list.forEach(function(b, n) {
      var props = {}
      for (var key in b) props[key] = b[key]
      insertBlock(n, props, Blocks.isText(b.type) ? b.html || "" : "")
    })
    endOp()
    var first = ""
    for (var i = 0; i < blocksModel.count && !first; i++) {
      var r = blocksModel.get(i)
      if (Blocks.isText(r.type) && Html.plainText(htmls[r.uid] || "") === "" && r.type !== "h1" && r.type !== "h2" && r.type !== "h3") first = r.uid
    }
    if (first) focusBlock(first, 0)
  }

  // A block put in place of an empty text block, or else after the block
  // (and what's inside it): a page, a link to one, a picture. Returns its uid.
  function placeBlock(uid, props) {
    var index = indexOf(uid)
    if (index < 0) index = blocksModel.count - 1
    var r = index >= 0 ? blocksModel.get(index) : null
    beginOp()
    var at
    var p = {}
    for (var k in props) p[k] = props[k]
    if (r && Blocks.isText(r.type) && Html.plainText(htmls[r.uid] || "") === "" && !(items[r.uid] && items[r.uid].edit.length > 0)) {
      at = index
      p.indent = r.indent
      removeAt(index)
    } else {
      at = r ? subtreeEnd(index) + 1 : 0
      p.indent = r ? r.indent : 0
    }
    var made = insertBlock(at, p, "")
    if (indexOf(made) === blocksModel.count - 1) insertBlock(blocksModel.count, { type: "p", indent: 0 }, "")
    endOp()
    var after = textNeighbor(indexOf(made), 1)
    if (after >= 0) focusBlock(uidAt(after), 0)
    return made
  }

  // Every heading on the page, for a table of contents: [{ uid, level, text }].
  function headings() {
    var r0 = structure
    syncAll()
    var out = []
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      if (r.type === "h1" || r.type === "h2" || r.type === "h3")
        out.push({ uid: r.uid, level: Number(r.type.charAt(1)), text: Html.plainText(htmls[r.uid] || "").replace(/\s+/g, " ").trim() })
    }
    return out
  }

  // Shows a block (unfolding what it's in) with the cursor at its end.
  function reveal(uid) {
    var i = indexOf(uid)
    if (i < 0) return
    var d = blocksModel.get(i).indent
    for (var j = i - 1; j >= 0 && d > 0; j--) {
      var r = blocksModel.get(j)
      if (r.indent < d) {
        if (r.collapsed) blocksModel.setProperty(j, "collapsed", false)
        d = r.indent
      }
    }
    refreshNumbers()
    stable = snapshot()
    changed()
    focusBlock(uid, -1)
    var item = items[uid]
    if (item) cursorAt(item.y, item.height)
  }

  // ---- Pages: dragging blocks -----------------------------------------------------------

  // The block being dragged by its handle, and where it would go: { index
  // (in the list without it and what's inside it), depth, x, y }.
  property string dragUid: ""
  property var dropTarget: null

  function dragStart(uid) {
    if (readOnly) return
    closeSlash()
    clearBlockSelection()
    dragUid = uid
    dropTarget = null
  }

  // The pointer at (x, y) in the editor: up the right side of a block (the
  // two go into columns), or else the gap between blocks it's nearest, in the
  // column (or the page) it's over, and how deep, from how far right it is.
  function dragMove(x, y) {
    var from = indexOf(dragUid)
    if (from < 0) return
    var end = subtreeEnd(from)
    cursorAt(y - 60, 120)
    var side = sideDrop(x, y, from, end)
    if (side) { dropTarget = side; return }

    // The column under the pointer, or the page.
    var col = columnAt(x, y, from, end)
    var start = col >= 0 ? col + 1 : 0
    var stop = col >= 0 ? subtreeEnd(col) : blocksModel.count - 1
    var base = col >= 0 ? blocksModel.get(col).indent + 1 : 0
    var flow = col >= 0 ? docLayout[uidAt(col)] : { left: 0, w: contentWidth }
    // What's in it (in the page, a columns block and what's in it count as one).
    var units = []
    for (var i = start; i <= stop; i++) {
      if (i >= from && i <= end) { i = end; continue }
      var r = blocksModel.get(i)
      if (col < 0 && r.type === "columns") {
        var last = subtreeEnd(i)
        var box = unitBox(i, last)
        units.push({ index: i, r: r, top: box.top, bottom: box.bottom, nest: false })
        i = last
        continue
      }
      var item = items[r.uid]
      if (!item || isHidden(r.uid) || Workspace.isStructure(r.type)) continue
      units.push({ index: i, r: r, top: item.y, bottom: item.y + item.height,
        nest: Workspace.canNest(r.type, rowBlock(r)) && !(Workspace.folds(rowBlock(r)) && r.collapsed) })
    }
    var k = 0
    while (k < units.length && y >= (units[k].top + units[k].bottom) / 2) k++
    var above = k > 0 ? units[k - 1] : null
    var below = k < units.length ? units[k] : null
    var full = below ? below.index : stop + 1
    var target = full > end ? full - (end - from + 1) : full
    // Inside the block above it (if it can hold blocks and isn't folded), or
    // beside it or the blocks it's in, but not shallower than the block below.
    var max = above ? above.r.indent + (above.nest ? 1 : 0) : base
    var min = below ? Math.min(below.r.indent, max) : base
    min = Math.max(min, base)
    max = Math.max(max, min)
    var best = min
    var bestX = 0
    var bestDist = 1e9
    for (var d = min; d <= max; d++) {
      var dx = above ? depthX(above, d) : 0
      var dist = Math.abs(x + 20 - flow.left - dx)
      if (dist < bestDist) { bestDist = dist; best = d; bestX = dx }
    }
    var lineY = below ? below.top : above ? above.bottom : (col >= 0 ? (items[uidAt(col)] ? items[uidAt(col)].y : 0) : 0)
    dropTarget = { index: target, depth: best, x: flow.left + bestX, y: lineY, w: flow.w - bestX }
  }

  // The top and bottom of blocks [i, last] showing.
  function unitBox(i, last) {
    var top = 1e9
    var bottom = -1e9
    for (var j = i; j <= last; j++) {
      var it = items[uidAt(j)]
      if (!it || it.height <= 0) continue
      top = Math.min(top, it.y)
      bottom = Math.max(bottom, it.y + it.height)
    }
    return top > bottom ? { top: 0, bottom: 0 } : { top: top, bottom: bottom }
  }

  // The column (its index) under the point, or -1.
  function columnAt(x, y, from, end) {
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      if (r.type !== "columns") continue
      var last = subtreeEnd(i)
      var box = unitBox(i, last)
      if (y < box.top - 6 || y > box.bottom + 10) { i = last; continue }
      for (var j = i + 1; j <= last; j = subtreeEnd(j) + 1) {
        var f = docLayout[uidAt(j)]
        if (f && x >= f.left - columnGap / 2 && x < f.left + f.w + columnGap / 2) return j
      }
      i = last
    }
    return -1
  }

  // Up the right side of a block at the top of the page or of a column: the
  // block dragged goes into a column beside it.
  function sideDrop(x, y, from, end) {
    var dragged = blocksModel.get(from)
    if (Workspace.isStructure(dragged.type)) return null
    for (var i = 0; i < blocksModel.count; i++) {
      if (i >= from && i <= end) continue
      var r = blocksModel.get(i)
      var item = items[r.uid]
      if (!item || item.height <= 0 || isHidden(r.uid) || Workspace.isStructure(r.type)) continue
      if (!(r.indent === 0 || inColumn(i))) continue
      if (y < item.y + 4 || y > item.y + item.height - 4) continue
      var f = docLayout[r.uid]
      var reach = Math.min(60, f.w * 0.15)
      if (x < f.left + f.w - reach || x > f.left + f.w + 16) continue
      // Six columns at most.
      if (inColumn(i)) {
        var list = parentIndex(parentIndex(i))
        var count = 0
        for (var j = list + 1; j <= subtreeEnd(list); j = subtreeEnd(j) + 1) count++
        if (count >= 6) return null
      }
      return { side: r.uid, vertical: true, x: f.left + f.w + 4, y: item.y, h: item.height }
    }
    return null
  }

  // Where a block at `depth` starts, right below `above`.
  function depthX(above, depth) {
    if (!above) return 0
    var info = docLayout[above.r.uid] || { x: 0 }
    if (depth > above.r.indent) return info.x + childOffset(above.r)
    // Up through the blocks `above` is in to the one at that depth.
    var i = indexOf(above.r.uid)
    var d = above.r.indent
    var x = info.x
    for (var j = i - 1; j >= 0 && d > depth; j--) {
      var r = blocksModel.get(j)
      if (r.indent < d) {
        d = r.indent
        x = (docLayout[r.uid] || { x: 0 }).x
      }
    }
    return x
  }

  function dragEnd(drop) {
    var uid = dragUid
    var t = dropTarget
    dragUid = ""
    dropTarget = null
    if (!drop || !t || !uid) return
    if (t.side) moveBeside(uid, t.side)
    else moveSubtree(uid, t.index, t.depth)
  }

  // A block (and what's inside it) put in a column to the right of another:
  // a new column next to the other's, if it's in one; else the two of them
  // in columns of their own.
  function moveBeside(uid, targetUid) {
    var from = indexOf(uid)
    if (from < 0 || indexOf(targetUid) < 0 || uid === targetUid) return
    var keepFocus = focusInfo()
    syncAll()
    beginOp()
    var end = subtreeEnd(from)
    var moved = []
    for (var i = from; i <= end; i++) {
      var b = blockAt(i)
      if (b) moved.push(b)
    }
    var base = moved.length ? moved[0].indent : 0
    for (var j = end; j >= from; j--) removeAt(j)
    var t = indexOf(targetUid)
    var at
    var depth
    if (inColumn(t)) {
      var column = parentIndex(t)
      at = subtreeEnd(column) + 1
      depth = blocksModel.get(column).indent
      // Every column gets an equal share again.
      var list = parentIndex(column)
      for (var c = list + 1; c <= subtreeEnd(list); c = subtreeEnd(c) + 1) blocksModel.setProperty(c, "imgWidth", 0)
    } else {
      // (Its depth before it moves in: the model's rows are live.)
      var level = blocksModel.get(t).indent
      var tEnd = subtreeEnd(t)
      for (var k = t; k <= tEnd; k++) blocksModel.setProperty(k, "indent", blocksModel.get(k).indent + 2)
      insertBlock(t, { type: "columns", indent: level }, "")
      insertBlock(t + 1, { type: "column", indent: level + 1 }, "")
      at = tEnd + 3
      depth = level + 1
    }
    insertBlock(at, { type: "column", indent: depth }, "")
    moved.forEach(function(b, n) {
      var props = {}
      for (var key in b) props[key] = b[key]
      props.id = b.uid
      props.indent = depth + 1 + (b.indent - base)
      root.insertBlock(at + 1 + n, props, b.html || "")
    })
    endOp()
    restoreFocus(keepFocus)
  }

  // A block, and what's inside it, moved to `to` (its index in the list
  // without them) at `depth`.
  function moveSubtree(uid, to, depth) {
    var from = indexOf(uid)
    if (from < 0) return
    var end = subtreeEnd(from)
    var n = end - from + 1
    var delta = depth - blocksModel.get(from).indent
    if (to === from && delta === 0) return
    var keepFocus = focusInfo()
    beginOp()
    for (var i = from; i <= end; i++) blocksModel.setProperty(i, "indent", Math.min(Blocks.MAX_DEPTH, blocksModel.get(i).indent + delta))
    if (to !== from) blocksModel.move(from, Math.max(0, Math.min(blocksModel.count - n, to)), n)
    endOp()
    restoreFocus(keepFocus)
  }

  // ---- undo --------------------------------------------------------------------------------

  property var undoStack: []
  property var redoStack: []
  property var stable: null
  property bool burstOpen: false
  property bool inOp: false
  property bool restoring: false
  readonly property bool canUndo: undoStack.length > 0 || burstOpen
  readonly property bool canRedo: redoStack.length > 0

  Timer {
    id: burstTimer
    interval: 900
    onTriggered: root.closeBurst()
  }

  function snapshot() {
    syncAll()
    var list = []
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      var b = rowBlock(r)
      b.html = htmls[r.uid] || ""
      list.push(b)
    }
    return { blocks: list, focus: focusInfo() }
  }

  function focusInfo() {
    var item = items[focusUid]
    // Drawing on a sketch: it goes on.
    if (item && item.type === "sketch" && item.sketchView && item.sketchView.drawing) return { uid: focusUid, pos: 0, anchor: -1, drawing: true }
    // In a table: the cell.
    if (item && item.type === "table" && item.tableView && item.tableView.writing) {
      var t = item.tableView
      var cell = t.cellAt(t.curRow, t.curCol)
      return { uid: focusUid, pos: 0, anchor: -1, cell: { r: t.curRow, c: t.curCol, pos: cell ? cell.edit.cursorPosition : -1 } }
    }
    if (!item || !item.isText) return { uid: focusUid, pos: 0, anchor: -1 }
    var e = item.edit
    var hasSel = e.selectionStart !== e.selectionEnd
    return { uid: focusUid, pos: e.cursorPosition, anchor: hasSel ? (e.cursorPosition === e.selectionEnd ? e.selectionStart : e.selectionEnd) : -1 }
  }

  function pushUndo(snap) {
    if (!snap) return
    var stack = undoStack.slice()
    stack.push(snap)
    if (stack.length > 200) stack.shift()
    undoStack = stack
  }

  function closeBurst() {
    burstTimer.stop()
    if (!burstOpen) return
    burstOpen = false
    stable = snapshot()
  }

  // Before and after every change that isn't typing.
  function beginOp() {
    closeBurst()
    pushUndo(stable || snapshot())
    redoStack = []
    inOp = true
  }

  function endOp() {
    inOp = false
    if (doc) {
      normalizeColumns()
      normalizeModel()
    }
    refreshNumbers()
    stable = snapshot()
    changed()
    scheduleFormat()
  }

  function restore(snap) {
    pending = null
    restoring = true
    var same = snap.blocks.length === blocksModel.count
    for (var k = 0; same && k < snap.blocks.length; k++) {
      if (blocksModel.get(k).uid !== snap.blocks[k].uid) same = false
    }
    if (same) {
      for (var i = 0; i < snap.blocks.length; i++) {
        var b = snap.blocks[i]
        var r = row(b)
        var cur = blocksModel.get(i)
        for (var key in r) if (cur[key] !== r[key]) blocksModel.setProperty(i, key, r[key])
        if ((htmls[b.uid] || "") !== (b.html || "")) setHtml(b.uid, b.html || "")
      }
    } else {
      clearBlockSelection()
      var map = {}
      snap.blocks.forEach(function(b) { map[b.uid] = b.html || "" })
      htmls = map
      blocksModel.clear()
      snap.blocks.forEach(function(b) { blocksModel.append(row(b)) })
    }
    restoring = false
    refreshNumbers()
    var f = snap.focus
    if (f && f.cell && items[f.uid] && items[f.uid].tableView) items[f.uid].tableView.focusCell(f.cell.r, f.cell.c, f.cell.pos)
    else if (f && f.drawing && items[f.uid] && items[f.uid].sketchView) items[f.uid].sketchView.startDrawing()
    else if (f && f.uid && items[f.uid]) focusBlock(f.uid, f.pos, f.anchor)
    else if (blocksModel.count > 0) focusBlock(uidAt(0), 0)
  }

  function undo() {
    closeBurst()
    if (undoStack.length === 0) return
    var stack = undoStack.slice()
    var snap = stack.pop()
    undoStack = stack
    var redo = redoStack.slice()
    redo.push(snapshot())
    redoStack = redo
    restore(snap)
    stable = snapshot()
    changed()
    scheduleFormat()
  }

  function redo() {
    closeBurst()
    if (redoStack.length === 0) return
    var stack = redoStack.slice()
    var snap = stack.pop()
    redoStack = stack
    pushUndo(snapshot())
    restore(snap)
    stable = snapshot()
    changed()
    scheduleFormat()
  }

  // ---- what blocks report --------------------------------------------------------------

  // Typing in a block.
  function edited(item) {
    if (restoring || inOp) return
    if (!burstOpen) {
      // Qt also reports changes that change nothing (after formatting, a
      // late notice of what the formatting did): those start no undo step.
      var now = storedOf(item)
      if (now === (htmls[item.uid] || "")) {
        item.dirty = false
        return
      }
      pushUndo(stable)
      redoStack = []
      burstOpen = true
    }
    burstTimer.restart()
    applyPending(item)
    changed()
    scheduleFormat()
    if (doc && item.type === "code" && Highlight.knows(item.lang)) {
      codeUid = item.uid
      codeTimer.restart()
    }
    if (!item.edit.inputMethodComposing) Qt.callLater(function() {
      root.markdownShortcut(item)
      if (root.doc) {
        root.checkSlash(item)
        root.checkMention(item)
        root.inlineMarkdown(item)
        root.autoEmail(item)
      }
    })
  }

  // "- ", "1. ", "[] ", "# " and friends typed at the start of a block make it
  // that kind. Read from the text rather than the Space key, because with an
  // input method (fcitx, ibus) typing arrives as text, not as key presses.
  function markdownShortcut(item) {
    if (!item || !item.edit || !item.isText || item.edit.inputMethodComposing) return
    var edit = item.edit
    var pos = edit.cursorPosition
    if (pos < 2 || pos > 6 || edit.selectionStart !== edit.selectionEnd) return
    var typed = edit.getText(0, pos)
    if (typed.charAt(typed.length - 1) !== " ") return
    var type = typeOf(item.uid)
    if (type === "code") return
    var shortcut = Blocks.shortcut(typed.slice(0, -1), doc)
    if (!shortcut) return
    if (!(type === "p" || (Blocks.isList(type) && Blocks.isList(shortcut.type) && shortcut.type !== type))) return
    closeSlash()
    closeBurst()
    beginOp()
    edit.remove(0, pos)
    syncBlock(item.uid)
    convert(item.uid, shortcut.type, shortcut.checked === true)
    if (shortcut.label) blocksModel.setProperty(indexOf(item.uid), "label", shortcut.label)
    endOp()
    focusBlock(item.uid, 0)
  }

  // ---- Pages: "/" --------------------------------------------------------------------

  // The "/" menu while it's open: { uid, at (where the "/" is), query (what's
  // typed after it) }; the view shows it with slashItems, slashIndex picked.
  property var slash: null
  property var slashItems: []
  property int slashIndex: 0

  // A "/" typed at the start of a block or after a space opens the menu;
  // what's typed after it looks for a kind of block.
  function checkSlash(item) {
    if (!doc || !item || !item.edit || !item.isText || item.edit.inputMethodComposing) return
    var e = item.edit
    var pos = e.cursorPosition
    if (slash && slash.uid === item.uid) {
      var text = e.getText(0, e.length)
      var query = text.slice(slash.at + 1, pos)
      if (pos <= slash.at || text.charAt(slash.at) !== "/" || query.length > 30 || /\s\s|^\s/.test(query)) { closeSlash(); return }
      slashItems = Docs.findCommands(query)
      slashIndex = 0
      // Typing on past what nothing matches: it was just a slash.
      if (slashItems.length === 0 && /\s$/.test(query)) { closeSlash(); return }
      slash = { uid: item.uid, at: slash.at, query: query }
      return
    }
    if (pos < 1 || e.selectionStart !== e.selectionEnd || typeOf(item.uid) === "code") return
    var before = e.getText(Math.max(0, pos - 2), pos)
    if (before.charAt(before.length - 1) !== "/") return
    if (before.length === 2 && !/\s/.test(before.charAt(0))) return
    slashItems = Docs.findCommands("")
    slashIndex = 0
    slash = { uid: item.uid, at: pos - 1, query: "" }
  }

  function closeSlash() {
    if (slash === null) return
    slash = null
    slashItems = []
  }

  // Where the "/" is, in the editor's coordinates (the menu opens under it).
  function slashRect() {
    var item = slash ? items[slash.uid] : null
    if (!item) return Qt.rect(0, 0, 0, 0)
    var r = item.edit.positionToRectangle(slash.at)
    return Qt.rect(item.x + item.edit.x + r.x, item.y + item.edit.y + r.y, r.width, r.height)
  }

  // Takes what's picked in the menu: the block becomes that kind (or a new
  // one of it comes after it), gets a color, or something else happens.
  function applySlash(command) {
    var s = slash
    closeSlash()
    var item = s ? items[s.uid] : null
    if (!item || !command) return
    var e = item.edit
    var end = Math.min(e.length, s.at + 1 + s.query.length)
    closeBurst()
    beginOp()
    item.loading = true
    e.remove(s.at, end)
    item.loading = false
    item.dirty = true
    syncBlock(s.uid)
    var index = indexOf(s.uid)
    var r = blocksModel.get(index)
    var empty = Html.plainText(htmls[s.uid] || "") === ""
    if (command.color !== undefined) {
      blocksModel.setProperty(index, "color", command.color)
      endOp()
      focusBlock(s.uid, s.at)
      return
    }
    if (command.action) {
      endOp()
      focusBlock(s.uid, s.at)
      if (command.action === "date") insertText(s.uid, Qt.formatDate(new Date(), "d MMMM yyyy"))
      else if (command.action === "page") subpageRequested(s.uid)
      else if (command.action === "link") pageLinkRequested(s.uid)
      else if (command.action === "image") imageRequested(s.uid)
      else if (command.action === "columns") insertColumns(s.uid, command.count || 2)
      else if (command.action === "agent") agentRequested(s.uid)
      else if (command.action === "dictate") dictateRequested()
      else if (command.action === "template") templateRequested(s.uid)
      else if (command.action === "event") eventRequested(s.uid)
      else if (command.action === "synced") dataAction(s.uid, "syncedPick", null)
      return
    }
    var props = command.props || {}
    if (Blocks.isText(command.type) && empty) {
      convert(s.uid, command.type, false)
      for (var key in props) blocksModel.setProperty(index, key, props[key])
      endOp()
      focusBlock(s.uid, 0)
      return
    }
    var p = { type: command.type, indent: r.indent }
    for (var k in props) p[k] = props[k]
    var at = empty && !Blocks.isText(command.type) ? index : subtreeEnd(index) + 1
    if (empty && !Blocks.isText(command.type)) removeAt(index)
    var made = insertBlock(at, p, "")
    if (!Blocks.isText(command.type) && indexOf(made) === blocksModel.count - 1) insertBlock(blocksModel.count, { type: "p", indent: 0 }, "")
    endOp()
    // A new mind map: you write its topic first.
    if (command.type === "mindmap") { Qt.callLater(function() { root.editMindMap(made) }); return }
    // A file, a video, a bookmark, a button: picked, typed, set up.
    if (Blocks.hasData(command.type)) { Qt.callLater(function() { root.dataAction(made, "new", null) }); return }
    // A new meeting: it starts.
    if (command.type === "meeting") { Qt.callLater(function() { root.meetingRequested(made) }); return }
    // A new audio note: it records.
    if (command.type === "audio") { Qt.callLater(function() { root.audioRequested(made) }); return }
    // A new sketch: you draw on it.
    if (command.type === "sketch") { Qt.callLater(function() { if (root.items[made] && root.items[made].sketchView) root.items[made].sketchView.startDrawing() }); return }
    // A new table: you write in its first cell.
    if (command.type === "table") { Qt.callLater(function() { if (root.items[made]) root.items[made].enter(1, 0) }); return }
    if (Blocks.isText(command.type)) focusBlock(made, 0)
    else {
      var after = textNeighbor(indexOf(made), 1)
      if (after >= 0) focusBlock(uidAt(after), 0)
    }
  }

  // ---- Pages: "@", "[[" and ":" -----------------------------------------------------------

  // The "@" menu (a date or a reminder), the "[[" menu (a page) or the ":"
  // menu (an emoji by name) while it's open: { kind: "date" | "page" |
  // "emoji", uid, at (where the "@", "[[" or ":" is), query (what's typed
  // after it) }; the view shows it with mentionItems.
  property var mention: null
  property var mentionItems: []
  property int mentionIndex: 0

  function triggerOf(kind) { return kind === "page" ? "[[" : kind === "emoji" ? ":" : kind === "tag" ? "#" : "@" }
  // What a tag's name is made of, and a name followed by what ends it.
  readonly property var tagChars: new RegExp("^" + Tags.CHARS + "*$")
  readonly property var tagEnded: new RegExp("^(" + Tags.CHARS + "+)([\\s.,;:!?)\\]}\"'\u2019\u201d])$")

  // What the menu offers: dates and reminders; or pages, and a new page
  // with the name typed.
  function mentionList(kind, query) {
    if (kind === "emoji") return Emoji.find(query, 8).map(function(e) { return { kind: "emoji", label: ":" + e.code + ":", emoji: e.emoji } })
    if (kind === "tag") {
      var found = findTags(query).map(function(t) { return { kind: "tag", name: t.name, label: t.label, hint: t.pages + (t.pages === 1 ? " page" : " pages") } })
      var typed = Tags.clean(query)
      if (typed && !found.some(function(t) { return t.name === typed })) found.push({ kind: "tagnew", name: typed, label: "New tag " + Tags.label(query), tag: Tags.label(query) })
      return found
    }
    if (kind === "date") {
      // People with what's typed, then dates; a new person with a name typed.
      var who = query.trim()
      var people = who && typeof findPeople === "function" ? findPeople(who).slice(0, 5).map(function(p) {
        return { kind: "person", id: p.id, label: p.name, hint: p.sub, initials: p.initials, tint: p.tint }
      }) : []
      var dates = Dates.suggestions(query, new Date()).map(function(d) {
        return { kind: "date", label: d.label, hint: d.hint, at: d.at, time: d.time, remind: d.remind }
      })
      var add = who.length >= 2 && typeof makePerson === "function" && /^[A-Za-z\u00c0-\uffff][A-Za-z\u00c0-\uffff' .-]{0,60}$/.test(who)
        && !people.some(function(p) { return p.label.toLowerCase() === who.toLowerCase() })
        ? [{ kind: "personnew", label: "New contact \u201c" + who + "\u201d", name: who, hint: "Add them to People" }] : []
      return people.concat(dates).concat(add)
    }
    var list = findPages(query).map(function(p) { return { kind: "page", id: p.id, label: p.title || "Untitled", icon: p.icon || "", hint: p.path || "" } })
    var name = query.trim()
    if (name) list.push({ kind: "create", label: "New page \u201c" + name + "\u201d", title: name, hint: "A page with this name, at the top of Pages" })
    return list
  }

  // "[[" typed opens the page menu; "@" at the start of a block or after a
  // space opens the date menu (so an email address doesn't); ":" and two
  // letters of an emoji's name there, the emoji menu (not "10:30" or ":)").
  // ":rocket:" typed in full is the emoji.
  function checkMention(item) {
    if (!doc || !item || !item.edit || !item.isText || item.edit.inputMethodComposing || slash) return
    var e = item.edit
    var pos = e.cursorPosition
    if (mention && mention.uid === item.uid) {
      var text = e.getText(0, e.length)
      var trigger = triggerOf(mention.kind)
      var query = text.slice(mention.at + trigger.length, pos)
      // Written past it (two spaces, a new line, "]]", on and on): it closes.
      if (pos < mention.at + trigger.length || text.slice(mention.at, mention.at + trigger.length) !== trigger
          || query.length > 40 || /\s\s|^\s|[\u2028\n]/.test(query) || (mention.kind === "page" && query.indexOf("]]") >= 0)) { closeMention(); return }
      // A tag's name, then a space or a stop: it's a tag.
      if (mention.kind === "tag") {
        var ended = tagEnded.exec(query)
        if (ended && Tags.clean(ended[1])) {
          // (What ended it is put back after the tag.)
          mention = { kind: "tag", uid: item.uid, at: mention.at, query: query }
          applyMention({ kind: "tagnew", name: Tags.clean(ended[1]), tag: Tags.label(ended[1]), keep: ended[2] })
          return
        }
        if (!tagChars.test(query)) { closeMention(); return }
      }
      if (mention.kind === "emoji") {
        var name = query.replace(/:$/, "")
        if (!Emoji.isQuery(name)) { closeMention(); return }
        if (query !== name) {
          var hit = Emoji.exact(name)
          if (hit) {
            mention = { kind: "emoji", uid: item.uid, at: mention.at, query: query }
            applyMention({ kind: "emoji", emoji: hit })
          } else closeMention()
          return
        }
      }
      var list = mentionList(mention.kind, query)
      if (mention.kind === "emoji" && list.length === 0) { closeMention(); return }
      mentionItems = list
      mentionIndex = 0
      mention = { kind: mention.kind, uid: item.uid, at: mention.at, query: query }
      return
    }
    if (pos < 1 || e.selectionStart !== e.selectionEnd || typeOf(item.uid) === "code") return
    var before = e.getText(Math.max(0, pos - 2), pos)
    var kind = ""
    var at = -1
    var query = ""
    if (before === "[[") { kind = "page"; at = pos - 2 }
    else if (before.charAt(before.length - 1) === "#" && (before.length === 1 || /[\s(\[{"'\u201c\u2018]/.test(before.charAt(0)))) { kind = "tag"; at = pos - 1 }
    else if (before.charAt(before.length - 1) === "@" && (before.length === 1 || /\s/.test(before.charAt(0)))) { kind = "date"; at = pos - 1 }
    else {
      var named = /:([A-Za-z0-9_+-]{2,40})$/.exec(e.getText(Math.max(0, pos - 42), pos))
      var from = named ? pos - named[0].length : -1
      if (named && (from === 0 || /[\s([{"'\u201c\u2018]/.test(e.getText(from - 1, from)))) { kind = "emoji"; at = from; query = named[1] }
    }
    if (!kind) return
    var list = mentionList(kind, query)
    if (kind === "emoji" && list.length === 0) return
    mentionItems = list
    mentionIndex = 0
    mention = { kind: kind, uid: item.uid, at: at, query: query }
  }

  function closeMention() {
    if (mention === null) return
    mention = null
    mentionItems = []
  }

  // Where the "@" or "[[" is, in the editor's coordinates.
  function mentionRect() {
    var item = mention ? items[mention.uid] : null
    if (!item) return Qt.rect(0, 0, 0, 0)
    var r = item.edit.positionToRectangle(mention.at)
    return Qt.rect(item.x + item.edit.x + r.x, item.y + item.edit.y + r.y, r.width, r.height)
  }

  // Takes what's picked: a date (or a reminder then), a page, or a new page,
  // as a link in place of what was typed.
  function applyMention(entry) {
    var m = mention
    closeMention()
    var item = m ? items[m.uid] : null
    if (!item || !entry) return
    var e = item.edit
    var end = Math.min(e.length, m.at + triggerOf(m.kind).length + m.query.length)
    if (entry.kind === "emoji") {
      closeBurst()
      beginOp()
      replaceRange(item, m.at, end, Html.escapeText(entry.emoji))
      endOp()
      focusBlock(item.uid, m.at + entry.emoji.length)
      return
    }
    // A tag: its link, then what ended it (a space, a stop), or a space.
    if (entry.kind === "tag" || entry.kind === "tagnew") {
      var label = entry.kind === "tag" ? entry.label : entry.tag
      var tag = Tags.html(label)
      if (!tag) return
      var after = entry.keep !== undefined ? entry.keep : " "
      closeBurst()
      beginOp()
      replaceRange(item, m.at, end, tag + Html.escapeText(after))
      endOp()
      focusBlock(item.uid, m.at + label.length + after.length)
      return
    }
    var href = ""
    var text = ""
    if (entry.kind === "date") {
      var d = Dates.fromIso(entry.at)
      if (!d) return
      href = Dates.href(d.at, d.time, entry.remind)
      text = (entry.remind ? "\u23f0 " : "@") + Dates.label(d.at, d.time, new Date())
    } else if (entry.kind === "person" || entry.kind === "personnew") {
      // A person: "@Sam Rivera", a link to them (a new one's made first).
      var pid = entry.kind === "personnew" ? (typeof makePerson === "function" ? makePerson(entry.name) : "") : entry.id
      if (!pid) return
      href = "uber-notebook://contact/" + pid
      text = "@" + (entry.kind === "personnew" ? entry.name : entry.label)
    } else {
      var id = entry.kind === "create" ? makePage(entry.title) : entry.id
      if (!id) return
      href = "uber-notebook://page/" + id
      text = pageLinkText(pageInfo(id) || { title: entry.title || entry.label, icon: entry.icon || "" })
    }
    closeBurst()
    beginOp()
    // A space after it, plain, so what's typed next isn't part of the link.
    replaceRange(item, m.at, end, "<a href=\"" + Html.escapeAttr(href) + "\">" + Html.escapeText(text) + "</a> ")
    endOp()
    focusBlock(item.uid, m.at + text.length + 1)
  }

  // Plain text typed in at the cursor of a block, as one step.
  function insertText(uid, text) {
    var item = items[uid]
    if (!item || !item.edit) return
    var e = item.edit
    beginOp()
    e.remove(e.selectionStart, e.selectionEnd)
    var at = e.cursorPosition
    e.insert(at, spaced(Html.escapeText(text)))
    syncBlock(uid)
    endOp()
    focusBlock(uid, at + text.length)
  }

  // **bold**, *italic*, `code` and ~~struck~~ typed in Pages are formatted
  // as the closing mark goes in; what's typed after them isn't.
  function inlineMarkdown(item) {
    if (!doc || !item || !item.edit || !item.isText || item.edit.inputMethodComposing || slash) return
    var e = item.edit
    if (e.selectionStart !== e.selectionEnd || typeOf(item.uid) === "code") return
    var pos = e.cursorPosition
    var before = e.getText(Math.max(0, pos - 200), pos)
    var rules = [
      { re: /\*\*([^*\s](?:[^*\u2028]*[^*\s])?)\*\*$/, mark: 2, kind: "bold" },
      { re: /~~([^~\s](?:[^~\u2028]*[^~\s])?)~~$/, mark: 2, kind: "strike" },
      { re: /`([^`\u2028]+)`$/, mark: 1, kind: "code" },
      { re: /(?:^|[^*])\*([^*\s](?:[^*\u2028]*[^*\s])?)\*$/, mark: 1, kind: "italic" }
    ]
    for (var i = 0; i < rules.length; i++) {
      var m = rules[i].re.exec(before)
      if (!m) continue
      var text = m[1]
      var mark = rules[i].mark
      var start = pos - text.length - mark * 2
      closeBurst()
      beginOp()
      item.loading = true
      e.remove(pos - mark, pos)
      e.remove(start, start + mark)
      item.loading = false
      item.dirty = true
      var inner = innerOf(e, start, start + text.length)
      replaceRange(item, start, start + text.length, transformed(inner, rules[i].kind))
      endOp()
      focusBlock(item.uid, start + text.length)
      // What's typed next isn't bold (or code...) too.
      pending = { uid: item.uid, pos: start + text.length, changes: [{ kind: "off", value: rules[i].kind }] }
      scheduleFormat()
      return
    }
  }

  // An email typed, then a space or a stop after it (or Enter: `ending`): a
  // link (mailto:, or to the person it's theirs, then their card on a click).
  function autoEmail(item, ending) {
    if (!doc || !item || !item.edit || !item.isText || item.edit.inputMethodComposing || slash || mention) return
    var e = item.edit
    if (e.selectionStart !== e.selectionEnd || typeOf(item.uid) === "code") return
    var pos = e.cursorPosition
    var before = e.getText(Math.max(0, pos - 120), pos)
    var m = (ending ? /(^|[\s(\[{<"'\u201c])([^\s@<>()\[\]{}"',;:]+@[^\s@<>()\[\]{}"',;:]+?)([.,;:!?)\]}>"'\u201d]*)$/
      : /(^|[\s(\[{<"'\u201c])([^\s@<>()\[\]{}"',;:]+@[^\s@<>()\[\]{}"',;:]+?)([.,;:!?)\]}>"'\u201d]*[\s\u2028])$/).exec(before)
    if (!m || m[2].indexOf(".") < 0) return
    var start = pos - m[3].length - m[2].length
    var end = start + m[2].length
    var inner = innerOf(e, start, end)
    if (Html.links(inner).length > 0) return
    var linked = Html.linkEmails(inner, personOfEmail)
    if (linked === inner) return
    closeBurst()
    beginOp()
    replaceRange(item, start, end, linked)
    endOp()
    focusBlock(item.uid, pos)
  }

  function focusChangedIn(item, focused) {
    if (focused) {
      if (slash && slash.uid !== item.uid) closeSlash()
      if (mention && mention.uid !== item.uid) closeMention()
      if (focusUid !== item.uid && items[focusUid] && items[focusUid].edit) items[focusUid].edit.deselect()
      focusUid = item.uid
      if (selectedList.length > 0 && !dragSelecting) clearBlockSelection()
      scheduleFormat()
      cursorMovedIn(item)
    }
  }

  function cursorMovedIn(item) {
    var r = item.edit.cursorRectangle
    cursorAt(item.y + item.edit.y + r.y, r.height)
    if (slash && (slash.uid !== item.uid || item.edit.cursorPosition <= slash.at)) closeSlash()
    if (mention && (mention.uid !== item.uid || item.edit.cursorPosition <= mention.at)) closeMention()
    if (pending) Qt.callLater(dropStalePending)
    scheduleFormat()
  }

  // Formatting waiting for typing is dropped when the cursor moves away
  // without typing (typing applies it first, see applyPending).
  function dropStalePending() {
    var p = pending
    if (!p) return
    var item = items[p.uid]
    if (!item || !item.edit.activeFocus || item.edit.cursorPosition !== p.pos) pending = null
    scheduleFormat()
  }

  function selectionChangedIn(item) {
    scheduleFormat()
  }

  function openLink(url, anchor, x, y) {
    var page = Html.pageOf(url)
    if (page) { pageOpened(page); return }
    var person = Html.contactOf(url)
    if (person) { contactOpened(person, anchor || null, x || 0, y || 0); return }
    var tag = Tags.of(url)
    if (tag) { tagOpened(tag); return }
    var clean = Html.cleanUrl(url)
    if (clean) linkOpened(clean)
  }

  function openPicture(src) {
    if (src) pictureOpened(src)
  }

  // ---- moving around ---------------------------------------------------------------------

  function focusBlock(uid, pos, anchor) {
    var item = items[uid]
    if (!item) return
    if (!item.isText) {
      selectBlocks(uid, uid)
      return
    }
    if (selectedList.length > 0) clearBlockSelection()
    item.edit.forceActiveFocus()
    var len = item.edit.length
    var p = pos === undefined || pos < 0 ? len : Math.min(len, pos)
    if (anchor !== undefined && anchor >= 0 && anchor !== p) {
      item.edit.cursorPosition = Math.min(len, anchor)
      item.edit.moveCursorSelection(p, TextEdit.SelectCharacters)
    } else {
      item.edit.cursorPosition = p
    }
  }

  function focusStart() {
    for (var i = 0; i < blocksModel.count; i++) {
      if (Blocks.isText(blocksModel.get(i).type)) { focusBlock(uidAt(i), 0); return }
    }
  }

  function focusEnd() {
    for (var i = blocksModel.count - 1; i >= 0; i--) {
      if (Blocks.isText(blocksModel.get(i).type)) { focusBlock(uidAt(i), -1); return }
    }
  }

  // The first empty line to write on, past the headings (on a new page from
  // a template, its first priority or its first line of notes), else the end.
  function focusFirstEmpty() {
    syncAll()
    for (var i = 0; i < blocksModel.count; i++) {
      var r = blocksModel.get(i)
      if (!Blocks.isText(r.type) || r.type === "h1" || r.type === "h2" || r.type === "h3") continue
      if (Html.plainText(htmls[r.uid] || "") === "") { focusBlock(r.uid, 0); return }
    }
    focusEnd()
  }

  // A click on empty paper under the last block: write there.
  function clickBelow() {
    if (readOnly) return
    var last = blocksModel.count - 1
    if (last >= 0 && Blocks.isText(blocksModel.get(last).type)) { focusBlock(uidAt(last), -1); return }
    beginOp()
    var uid = insertBlock(blocksModel.count, { type: "p" }, "")
    endOp()
    focusBlock(uid, 0)
  }

  // The nearest text block before (dir -1) or after (dir 1) index.
  function textNeighbor(index, dir) {
    for (var i = index + dir; i >= 0 && i < blocksModel.count; i += dir) {
      var r = blocksModel.get(i)
      if (Blocks.isText(r.type) && !isHidden(r.uid)) return i
    }
    return -1
  }

  function lineOf(item) {
    return Math.floor((item.edit.cursorRectangle.y + item.edit.cursorRectangle.height / 2) / item.lineHeight)
  }

  // Up or down into the next block, keeping the cursor's place across.
  function moveVertical(item, dir) {
    var index = indexOf(item.uid)
    var target = doc ? cursorNeighbor(index, dir) : textNeighbor(index, dir)
    if (target < 0) {
      if (dir < 0) leaveTop()
      else item.edit.cursorPosition = item.edit.length
      return
    }
    var dest = items[uidAt(target)]
    if (!dest) return
    if (dest.type === "table") {
      dest.enter(dir, item.x + item.edit.x + item.edit.cursorRectangle.x - dest.x)
      return
    }
    var x = item.x + item.edit.x + item.edit.cursorRectangle.x - dest.x - dest.edit.x
    var y = dir < 0 ? dest.edit.contentHeight - dest.lineHeight * 0.5 : dest.lineHeight * 0.5
    focusBlock(dest.uid, dest.edit.positionAt(Math.max(0, x), Math.max(0, y)))
  }

  // ---- keys --------------------------------------------------------------------------------

  function onKey(item, e) {
    var edit = item.edit
    if (!edit || edit.inputMethodComposing) return
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    var hasSel = edit.selectionStart !== edit.selectionEnd
    var pos = edit.cursorPosition
    var key = e.key

    // A locked page: moving around, copying and folding, nothing that changes it.
    if (readOnly) {
      var moving = [Qt.Key_Up, Qt.Key_Down, Qt.Key_Left, Qt.Key_Right, Qt.Key_Home, Qt.Key_End, Qt.Key_PageUp, Qt.Key_PageDown, Qt.Key_Escape].indexOf(key) >= 0
      var copying = ctrl && !alt && (key === Qt.Key_C || key === Qt.Key_A || key === Qt.Key_F)
      var folding = ctrl && (key === Qt.Key_Return || key === Qt.Key_Enter) && doc && Workspace.folds(rowBlock(blocksModel.get(indexOf(item.uid))))
      if (folding) { e.accepted = true; toggleFold(item.uid); return }
      if (!moving && !copying) { e.accepted = true; return }
    }

    // The "@" and "[[" menus, like "/", take the arrows, Enter and Esc.
    if (mention && mention.uid === item.uid && !ctrl && !alt) {
      if (key === Qt.Key_Down || key === Qt.Key_Up) {
        e.accepted = true
        if (mentionItems.length) mentionIndex = (mentionIndex + (key === Qt.Key_Down ? 1 : -1) + mentionItems.length) % mentionItems.length
        return
      }
      if ((key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Tab) && mentionItems.length) {
        e.accepted = true
        applyMention(mentionItems[mentionIndex])
        return
      }
      if (key === Qt.Key_Escape) { e.accepted = true; closeMention(); return }
    }

    // The "/" menu takes the arrows, Enter and Esc while it's open.
    if (slash && slash.uid === item.uid && !ctrl && !alt) {
      if (key === Qt.Key_Down || key === Qt.Key_Up) {
        e.accepted = true
        if (slashItems.length) slashIndex = (slashIndex + (key === Qt.Key_Down ? 1 : -1) + slashItems.length) % slashItems.length
        return
      }
      if ((key === Qt.Key_Return || key === Qt.Key_Enter || key === Qt.Key_Tab) && slashItems.length) {
        e.accepted = true
        applySlash(slashItems[slashIndex])
        return
      }
      if (key === Qt.Key_Escape) { e.accepted = true; closeSlash(); return }
    }

    // Undo, redo, paste and the formatting shortcuts, whatever else happens.
    if (ctrl && !alt && key === Qt.Key_Z) { e.accepted = true; if (shift) redo(); else undo(); return }
    if (ctrl && !alt && key === Qt.Key_Y) { e.accepted = true; redo(); return }
    if ((ctrl && !alt && !shift && key === Qt.Key_V) || (shift && key === Qt.Key_Insert)) { e.accepted = true; paste(item, false); return }
    if (ctrl && shift && !alt && key === Qt.Key_V) { e.accepted = true; paste(item, true); return }
    if (ctrl && !alt && (key === Qt.Key_C || key === Qt.Key_X) && hasSel) {
      lastCopied = Html.plainText(innerOf(edit, edit.selectionStart, edit.selectionEnd))
      copiedBlocks = null
      return
    }
    if (ctrl && !shift && !alt && key === Qt.Key_B) { e.accepted = true; formatInline("bold"); return }
    if (ctrl && !shift && !alt && key === Qt.Key_I) { e.accepted = true; formatInline("italic"); return }
    if (ctrl && !shift && !alt && key === Qt.Key_U) { e.accepted = true; formatInline("underline"); return }
    if (ctrl && shift && !alt && key === Qt.Key_X) { e.accepted = true; formatInline("strike"); return }
    if (ctrl && shift && !alt && key === Qt.Key_H) { e.accepted = true; formatInline("highlight", Papers.HIGHLIGHTS[0].light); return }
    if (doc && ctrl && shift && !alt && key === Qt.Key_D) { e.accepted = true; dictateRequested(); return }
    if (doc && ctrl && shift && !alt && key === Qt.Key_R) { e.accepted = true; recordRequested(); return }
    if (ctrl && !shift && !alt && key === Qt.Key_E) { e.accepted = true; formatInline("code"); return }
    if (ctrl && !shift && !alt && key === Qt.Key_K) { e.accepted = true; linkRequested(); return }
    if (ctrl && shift && !alt && (key === Qt.Key_Greater || key === Qt.Key_Period)) { e.accepted = true; stepSize(1); return }
    if (ctrl && shift && !alt && (key === Qt.Key_Less || key === Qt.Key_Comma)) { e.accepted = true; stepSize(-1); return }
    if (ctrl && !shift && !alt && key === Qt.Key_Backslash) { e.accepted = true; formatInline("clear"); return }
    if (ctrl && alt && !shift && key >= Qt.Key_0 && key <= Qt.Key_3) {
      e.accepted = true
      setType([item.uid], ["p", "h1", "h2", "h3"][key - Qt.Key_0])
      return
    }
    // Pages: Ctrl+Alt+4 to-do, 5 bulleted, 6 numbered, 7 toggle, 8 code (as in Notion).
    if (doc && ctrl && alt && !shift && key >= Qt.Key_4 && key <= Qt.Key_8) {
      e.accepted = true
      setType([item.uid], ["check", "bullet", "number", "toggle", "code"][key - Qt.Key_4])
      return
    }
    if (ctrl && shift && (key === Qt.Key_7 || key === Qt.Key_Ampersand)) { e.accepted = true; toggleType([item.uid], "number"); return }
    if (ctrl && shift && (key === Qt.Key_8 || key === Qt.Key_Asterisk)) { e.accepted = true; toggleType([item.uid], "bullet"); return }
    if (ctrl && shift && (key === Qt.Key_9 || key === Qt.Key_ParenLeft)) { e.accepted = true; toggleType([item.uid], "check"); return }
    if (alt && shift && (key === Qt.Key_Up || key === Qt.Key_Down)) { e.accepted = true; moveBlocks([item.uid], key === Qt.Key_Up ? -1 : 1); return }
    if (ctrl && !alt && !shift && key === Qt.Key_D) { e.accepted = true; duplicateBlocks([item.uid]); return }

    if (ctrl && !alt && !shift && key === Qt.Key_A) {
      // The second Ctrl+A picks every block.
      if ((edit.selectionStart === 0 && edit.selectionEnd === edit.length) || edit.length === 0) {
        e.accepted = true
        selectBlocks(uidAt(0), uidAt(blocksModel.count - 1))
      }
      return
    }
    if (ctrl && !alt && (key === Qt.Key_Home || key === Qt.Key_End)) {
      if (shift) return
      e.accepted = true
      if (key === Qt.Key_Home) focusStart(); else focusEnd()
      return
    }

    if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      if (ctrl && !alt) {
        e.accepted = true
        if (typeOf(item.uid) === "check") toggleCheck(item.uid)
        else if (typeOf(item.uid) === "habit") toggleDay(item.uid, (new Date().getDay() + 6) % 7)
        else if (doc && Workspace.folds(rowBlock(blocksModel.get(indexOf(item.uid))))) toggleFold(item.uid)
        return
      }
      if (shift || alt) return
      e.accepted = true
      // (An email just typed at the end: a link first.)
      autoEmail(item, true)
      enter(item)
      return
    }

    if (key === Qt.Key_Backspace && !hasSel && pos === 0 && !ctrl && !alt) {
      e.accepted = true
      backspaceAtStart(item)
      return
    }
    if (key === Qt.Key_Delete && !hasSel && pos === edit.length && !ctrl && !alt) {
      e.accepted = true
      deleteAtEnd(item)
      return
    }

    if ((key === Qt.Key_Up || key === Qt.Key_Down) && !ctrl && !alt) {
      var dir = key === Qt.Key_Up ? -1 : 1
      var line = lineOf(item)
      var edge = dir < 0 ? line <= 0 : line >= edit.lineCount - 1
      if (!edge) return
      e.accepted = true
      if (shift) {
        var from = indexOf(item.uid)
        var to = Math.max(0, Math.min(blocksModel.count - 1, from + dir))
        selectBlocks(item.uid, uidAt(to))
      } else {
        moveVertical(item, dir)
      }
      return
    }
    if (key === Qt.Key_Left && !shift && !ctrl && !alt && !hasSel && pos === 0) {
      var prev = textNeighbor(indexOf(item.uid), -1)
      if (prev >= 0) { e.accepted = true; focusBlock(uidAt(prev), -1) }
      return
    }
    if (key === Qt.Key_Right && !shift && !ctrl && !alt && !hasSel && pos === edit.length) {
      var next = textNeighbor(indexOf(item.uid), 1)
      if (next >= 0) { e.accepted = true; focusBlock(uidAt(next), 0) }
      return
    }

    if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
      e.accepted = true
      var type = typeOf(item.uid)
      var back = key === Qt.Key_Backtab || shift
      if (type === "code" && !back) {
        edit.remove(edit.selectionStart, edit.selectionEnd)
        edit.insert(edit.cursorPosition, "&nbsp;&nbsp;")
      } else if (doc || Blocks.canIndent(type)) {
        indentBlocks([item.uid], back ? -1 : 1)
      }
      return
    }

    if (key === Qt.Key_Escape) {
      if (hasSel) { e.accepted = true; edit.deselect(); return }
      if (!ctrl && !alt && !shift) {
        e.accepted = true
        selectBlocks(item.uid, item.uid)
      }
      return
    }
  }

  // ---- enter, backspace, delete --------------------------------------------------------------

  function enter(item) {
    var edit = item.edit
    var uid = item.uid
    var index = indexOf(uid)
    var r = blocksModel.get(index)
    var type = r.type
    // In a schedule, Enter at the end of a slot goes on to the next one.
    if (type === "time" && edit.selectionStart === edit.selectionEnd && edit.cursorPosition === edit.length) {
      var following = index + 1 < blocksModel.count ? blocksModel.get(index + 1) : null
      if (following && following.type === "time") {
        focusBlock(following.uid, -1)
        return
      }
    }
    beginOp()
    if (edit.selectionStart !== edit.selectionEnd) edit.remove(edit.selectionStart, edit.selectionEnd)
    var pos = edit.cursorPosition
    var len = edit.length
    var text = edit.getText(0, len)

    // After the last slot, the next one: an hour on (or as far on as the
    // slots before it); an empty last slot ends the schedule, as an empty
    // list item ends a list. Within a slot's text, Enter is a new line of it.
    if (type === "time") {
      if (pos < len) {
        edit.insert(pos, "<br />")
        syncBlock(uid)
        endOp()
        focusBlock(uid, pos + 1)
        return
      }
      if (len === 0) {
        convert(uid, "p", false)
        endOp()
        focusBlock(uid, 0)
        return
      }
      var before = index > 0 && blocksModel.get(index - 1).type === "time" ? blocksModel.get(index - 1).label : ""
      var label = Blocks.nextLabel(r.label, before)
      var slot = insertBlock(index + 1, label ? { type: "time", label: label } : { type: "p" }, "")
      endOp()
      focusBlock(slot, 0)
      return
    }

    // Code: Enter is a new line; Enter on an empty last line leaves the block.
    // (A line break reads back as U+2028 from rich text.)
    if (type === "code") {
      var last = len > 0 ? text.charCodeAt(len - 1) : 0
      if (pos === len && (last === 0x2028 || last === 10)) {
        edit.remove(len - 1, len)
        syncBlock(uid)
        var after = insertBlock(index + 1, { type: "p" }, "")
        endOp()
        focusBlock(after, 0)
      } else {
        edit.insert(pos, "<br />")
        syncBlock(uid)
        endOp()
        focusBlock(uid, pos + 1)
      }
      return
    }

    // An empty list item, quote, note, habit or toggle: the list ends here.
    if (len === 0 && (Blocks.isList(type) || type === "quote" || (type === "callout" && !doc) || type === "habit" || type === "toggle")) {
      if (r.indent > 0 && Blocks.isList(type) && !(doc && inColumn(index))) {
        var last = doc ? subtreeEnd(index) : index
        for (var k = index; k <= last; k++) blocksModel.setProperty(k, "indent", blocksModel.get(k).indent - 1)
      }
      else convert(uid, "p", false)
      endOp()
      focusBlock(uid, 0)
      return
    }

    // "---" and Enter: a divider.
    if (type === "p" && Blocks.isDividerText(text)) {
      setHtml(uid, "")
      blocksModel.setProperty(index, "type", "divider")
      blocksModel.setProperty(index, "dstyle", "line")
      var below = insertBlock(index + 1, { type: "p", indent: doc ? r.indent : 0 }, "")
      endOp()
      focusBlock(below, 0)
      return
    }
    if (type === "p" && text === "```") {
      setHtml(uid, "")
      convert(uid, "code", false)
      endOp()
      focusBlock(uid, 0)
      return
    }

    // At the very start of a block with text: a new empty block above.
    if (pos === 0 && len > 0) {
      var aboveType = Blocks.isList(type) ? type : "p"
      insertBlock(index, { type: aboveType, indent: doc || Blocks.isList(type) ? r.indent : 0 }, "")
      endOp()
      focusBlock(uid, 0)
      return
    }

    // In Pages, Enter at the end of an open toggle, a callout, or a block
    // with blocks inside it starts a block inside it; after a folded toggle,
    // one after everything folded in it.
    if (doc && pos === len) {
      var folding = Workspace.folds(rowBlock(r))
      var hasKids = index + 1 < blocksModel.count && blocksModel.get(index + 1).indent > r.indent
      if ((folding && !r.collapsed) || type === "callout" || (hasKids && !folding)) {
        var childType = folding || type === "callout" ? "p" : Blocks.kindAfterEnter(type, true)
        var child = insertBlock(index + 1, { type: childType, indent: r.indent + 1 }, "")
        endOp()
        focusBlock(child, 0)
        return
      }
      if (folding && r.collapsed) {
        var sibling = insertBlock(subtreeEnd(index) + 1, { type: Blocks.kindAfterEnter(type, true), indent: r.indent }, "")
        endOp()
        focusBlock(sibling, 0)
        return
      }
    }

    var head = innerOf(edit, 0, pos)
    var tail = pos < len ? innerOf(edit, pos, len) : ""
    // A quote in Pages ends with Enter, as in Notion (Shift+Enter: a new line in it).
    var nextType = doc && type === "quote" && pos === len ? "p" : Blocks.kindAfterEnter(type, pos === len)
    setHtml(uid, head)
    var props = { type: nextType }
    if (doc) props.indent = r.indent
    else if (Blocks.isList(nextType) || nextType === "p") props.indent = Blocks.canIndent(nextType) ? r.indent : 0
    if (nextType === "callout") props.tone = r.tone || "yellow"
    if (nextType === type && r.align !== "left") props.align = r.align
    var created = insertBlock(index + 1, props, tail)
    endOp()
    focusBlock(created, 0)
  }

  function backspaceAtStart(item) {
    var uid = item.uid
    var index = indexOf(uid)
    var r = blocksModel.get(index)
    var action = Blocks.backspaceAction({ type: r.type, indent: r.indent })
    if (action === "convert") {
      beginOp()
      convert(uid, "p", false)
      endOp()
      focusBlock(uid, 0)
      return
    }
    if (action === "outdent" && doc && inColumn(index)) action = "merge"
    if (action === "outdent" && doc) {
      indentDoc([uid], -1)
      focusBlock(uid, 0)
      return
    }
    if (action === "outdent") {
      beginOp()
      blocksModel.setProperty(index, "indent", r.indent - 1)
      endOp()
      focusBlock(uid, 0)
      return
    }
    if (index === 0) return
    // The block showing above it (in Pages, not one folded away).
    var above = index - 1
    while (above > 0 && isHidden(uidAt(above))) above--
    var prev = blocksModel.get(above)
    // The first block in a column: nothing above it to join.
    if (Workspace.isStructure(prev.type)) return
    if (!Blocks.isText(prev.type)) {
      // A picture or divider above: pick it first, so it's never lost by accident.
      selectBlocks(prev.uid, prev.uid)
      return
    }
    beginOp()
    syncBlock(uid)
    syncBlock(prev.uid)
    var prevItem = items[prev.uid]
    var joinAt = prevItem ? prevItem.edit.length : Html.plainText(htmls[prev.uid] || "").length
    var joined = (htmls[prev.uid] || "") + (htmls[uid] || "")
    removeAt(index)
    setHtml(prev.uid, joined)
    endOp()
    focusBlock(prev.uid, joinAt)
  }

  function deleteAtEnd(item) {
    var uid = item.uid
    var index = indexOf(uid)
    if (index >= blocksModel.count - 1) return
    var next = blocksModel.get(index + 1)
    // The end of a column: the next column isn't something to delete.
    if (Workspace.isStructure(next.type)) return
    // A table, a mind map or a sketch below: pick it first, so it's never lost by accident.
    if (doc && (next.type === "table" || next.type === "mindmap" || next.type === "sketch" || next.type === "audio" || next.type === "meeting" || next.type === "board" || next.type === "synced")) {
      selectBlocks(next.uid, next.uid)
      return
    }
    beginOp()
    if (!Blocks.isText(next.type)) {
      removeAt(index + 1)
      endOp()
      focusBlock(uid, -1)
      return
    }
    syncBlock(uid)
    syncBlock(next.uid)
    var at = item.edit.length
    var joined = (htmls[uid] || "") + (htmls[next.uid] || "")
    removeAt(index + 1)
    setHtml(uid, joined)
    endOp()
    focusBlock(uid, at)
  }

  // ---- changing blocks ----------------------------------------------------------------

  function insertBlock(index, props, inner) {
    var taken = takenUids()
    var b = Blocks.make(props.type, props, taken, cleanOptions)
    if (doc) {
      // Blocks get UUIDs; a page block keeps its page's (props.id).
      var fixed = Workspace.isUuid(props.id) && !taken[props.id]
      // A copy of a page block would be a second way into the same page, so
      // it's a link to it.
      if (b.type === "page" && !fixed) b = Blocks.make("link", { target: props.uid, indent: b.indent }, taken, cleanOptions)
      b.uid = fixed ? props.id : newId(taken)
    }
    htmls[b.uid] = inner || ""
    blocksModel.insert(Math.max(0, Math.min(blocksModel.count, index)), row(b))
    return b.uid
  }

  function removeAt(index) {
    var uid = uidAt(index)
    if (!uid) return
    blocksModel.remove(index)
    delete htmls[uid]
    if (selectedMap[uid]) clearBlockSelection()
  }

  // Makes a block another kind, keeping its text.
  function convert(uid, type, checked) {
    var index = indexOf(uid)
    if (index < 0) return
    var r = blocksModel.get(index)
    if (!Blocks.isText(type) || !Blocks.isText(r.type)) return
    blocksModel.setProperty(index, "type", type)
    if (!Blocks.canIndent(type)) blocksModel.setProperty(index, "indent", 0)
    blocksModel.setProperty(index, "checked", type === "check" && checked === true)
    if (type === "callout" && !r.tone) blocksModel.setProperty(index, "tone", "yellow")
    if (type === "habit" && !/^[01]{7}$/.test(r.days)) blocksModel.setProperty(index, "days", Blocks.NO_DAYS)
  }

  // The formatting bar's and the shortcuts' way to change blocks' kind.
  function setType(uids, type) {
    var list = uids.filter(function(u) { return Blocks.isText(typeOf(u)) })
    if (list.length === 0) return
    var keepFocus = focusInfo()
    beginOp()
    list.forEach(function(u) { syncBlock(u); convert(u, type, false) })
    endOp()
    restoreFocus(keepFocus)
  }

  // A list kind on, or back to text when all of them already are.
  function toggleType(uids, type) {
    var all = uids.length > 0 && uids.every(function(u) { return typeOf(u) === type })
    setType(uids, all ? "p" : type)
  }

  function setAlign(uids, align) {
    var keepFocus = focusInfo()
    beginOp()
    uids.forEach(function(u) {
      var i = indexOf(u)
      if (i >= 0 && Blocks.isText(blocksModel.get(i).type)) blocksModel.setProperty(i, "align", align)
    })
    endOp()
    restoreFocus(keepFocus)
  }

  function setTone(uids, tone) {
    var keepFocus = focusInfo()
    beginOp()
    uids.forEach(function(u) {
      var i = indexOf(u)
      if (i >= 0) {
        if (blocksModel.get(i).type !== "callout") { syncBlock(u); convert(u, "callout", false) }
        blocksModel.setProperty(i, "tone", tone)
      }
    })
    endOp()
    restoreFocus(keepFocus)
  }

  function indentBlocks(uids, delta) {
    if (doc) { indentDoc(uids, delta); return }
    var keepFocus = focusInfo()
    var changedAny = false
    uids.forEach(function(u) {
      var i = indexOf(u)
      if (i < 0) return
      var r = blocksModel.get(i)
      if (!Blocks.canIndent(r.type)) return
      var next = Math.max(0, Math.min(Blocks.MAX_INDENT, r.indent + delta))
      if (next === r.indent) return
      if (!changedAny) { beginOp(); changedAny = true }
      blocksModel.setProperty(i, "indent", next)
    })
    if (changedAny) endOp()
    restoreFocus(keepFocus)
  }

  // In Pages, a block goes inside the block before it (with everything inside
  // it), if that one can hold blocks; out again, the blocks after it inside
  // the same block go inside it (as in Notion).
  function indentDoc(uids, delta) {
    var keepFocus = focusInfo()
    var changedAny = false
    subtreeRanges(uids).forEach(function(range) {
      var i = range[0]
      var r = blocksModel.get(i)
      if (delta > 0) {
        var prev = previousSibling(i)
        if (prev < 0 || Workspace.isStructure(blocksModel.get(prev).type) || !Workspace.canNest(blocksModel.get(prev).type, rowBlock(blocksModel.get(prev)))) return
        if (Workspace.folds(rowBlock(blocksModel.get(prev))) && blocksModel.get(prev).collapsed) blocksModel.setProperty(prev, "collapsed", false)
      } else if (r.indent === 0 || inColumn(i)) {
        // Not out of a column (nothing but columns goes in columns).
        return
      }
      if (!changedAny) { beginOp(); changedAny = true }
      for (var k = range[0]; k <= range[1]; k++) blocksModel.setProperty(k, "indent", Math.max(0, Math.min(Blocks.MAX_DEPTH, blocksModel.get(k).indent + delta)))
    })
    if (changedAny) endOp()
    restoreFocus(keepFocus)
  }

  function toggleCheck(uid) {
    if (readOnly) return
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "check") return
    var keepFocus = focusInfo()
    beginOp()
    blocksModel.setProperty(i, "checked", !blocksModel.get(i).checked)
    endOp()
    restoreFocus(keepFocus)
  }

  // A time slot's time (or, in a monthly planner, its day).
  function setLabel(uid, text) {
    var i = indexOf(uid)
    if (i < 0 || blocksModel.get(i).type !== "time") return
    var clean = Blocks.cleanLine(text, 12)
    if (clean === blocksModel.get(i).label) return
    beginOp()
    blocksModel.setProperty(i, "label", clean)
    endOp()
  }

  // A habit ticked off for a day of the week (0 is Monday), or not.
  function toggleDay(uid, day) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "habit") return
    var keepFocus = focusInfo()
    beginOp()
    blocksModel.setProperty(i, "days", Blocks.toggleDay(blocksModel.get(i).days, day))
    endOp()
    restoreFocus(keepFocus)
  }

  // A day circled on a calendar, or rubbed out.
  function toggleMark(uid, day) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "calendar") return
    var keepFocus = focusInfo()
    beginOp()
    blocksModel.setProperty(i, "marks", Blocks.toggleMark(blocksModel.get(i).marks, day))
    endOp()
    restoreFocus(keepFocus)
  }

  // A calendar turned to an earlier or later month (0: this month). The days
  // circled were that month's, so they go.
  function shiftMonth(uid, delta) {
    var i = indexOf(uid)
    if (i < 0 || readOnly || blocksModel.get(i).type !== "calendar") return
    var month = delta === 0 ? Blocks.thisMonth() : Blocks.shiftMonth(blocksModel.get(i).month, delta)
    if (month === blocksModel.get(i).month) return
    beginOp()
    blocksModel.setProperty(i, "month", month)
    blocksModel.setProperty(i, "marks", "")
    endOp()
  }

  function moveBlocks(uids, delta) {
    if (doc) { moveDoc(uids, delta); return }
    var indices = uids.map(indexOf).filter(function(i) { return i >= 0 }).sort(function(a, b) { return a - b })
    if (indices.length === 0) return
    var from = indices[0]
    var to = indices[indices.length - 1]
    var range = Blocks.moveRange(blocksModel.count, from, to, delta)
    if (!range) return
    var keepFocus = focusInfo()
    beginOp()
    if (delta < 0) blocksModel.move(from - 1, to, 1)
    else blocksModel.move(to + 1, from, 1)
    endOp()
    if (selectedList.length > 0) selectBlocks(uidAt(range.from), uidAt(range.to))
    else restoreFocus(keepFocus)
  }

  // In Pages, blocks move past the block before (or after) them at their
  // depth, with everything inside them.
  function moveDoc(uids, delta) {
    var ranges = subtreeRanges(uids)
    if (ranges.length === 0) return
    var from = ranges[0][0]
    var end = ranges[ranges.length - 1][1]
    var n = end - from + 1
    var d = blocksModel.get(from).indent
    var to
    if (delta < 0) {
      var prev = previousSibling(from)
      if (prev < 0) return
      to = prev
    } else {
      var next = end + 1
      if (next >= blocksModel.count || blocksModel.get(next).indent !== d) return
      to = from + (subtreeEnd(next) - next + 1)
    }
    var keepFocus = focusInfo()
    var picked = selectedList.length > 0
    beginOp()
    blocksModel.move(from, to, n)
    endOp()
    if (picked) selectBlocks(uidAt(to), uidAt(to + n - 1))
    else restoreFocus(keepFocus)
  }

  function duplicateBlocks(uids) {
    if (doc) {
      // Each with what's inside it, after the last.
      var ranges = subtreeRanges(uids)
      if (ranges.length === 0) return
      syncAll()
      beginOp()
      var copies = []
      ranges.forEach(function(range) { for (var k = range[0]; k <= range[1]; k++) copies.push(blockAt(k)) })
      var at0 = ranges[ranges.length - 1][1] + 1
      var head = ""
      var tail = ""
      copies.forEach(function(b, n) {
        tail = insertBlock(at0 + n, b, b.html || "")
        if (!head) head = tail
      })
      endOp()
      if (selectedList.length > 0) selectBlocks(head, head)
      else focusBlock(head, -1)
      return
    }
    var indices = uids.map(indexOf).filter(function(i) { return i >= 0 }).sort(function(a, b) { return a - b })
    if (indices.length === 0) return
    syncAll()
    beginOp()
    var at = indices[indices.length - 1] + 1
    var first = ""
    indices.forEach(function(i, n) {
      var b = blockAt(i)
      var copyUid = insertBlock(at + n, b, b.html || "")
      if (!first) first = copyUid
    })
    endOp()
    if (selectedList.length > 0) selectBlocks(first, uidAt(at + indices.length - 1))
    else focusBlock(first, -1)
  }

  function removeBlocks(uids) {
    var indices = uids.map(indexOf).filter(function(i) { return i >= 0 }).sort(function(a, b) { return b - a })
    if (doc) {
      // With everything inside them.
      var all = []
      subtreeRanges(uids).forEach(function(range) { for (var k = range[0]; k <= range[1]; k++) all.push(k) })
      indices = all.sort(function(a, b) { return b - a })
    }
    if (indices.length === 0) return
    beginOp()
    var landing = indices[indices.length - 1]
    clearBlockSelection()
    indices.forEach(function(i) { removeAt(i) })
    if (blocksModel.count === 0) insertBlock(0, { type: "p" }, "")
    endOp()
    var target = Math.min(landing, blocksModel.count - 1)
    var text = textNeighbor(target + 1, -1)
    if (text < 0) text = textNeighbor(target - 1, 1)
    if (text >= 0) focusBlock(uidAt(text), landing <= text ? 0 : -1)
  }

  // Blocks (with everything inside them) put in place of others, as one
  // step: `list` (block objects) where the first of `uids` was.
  function swapBlocks(uids, list) {
    var all = []
    subtreeRanges(uids).forEach(function(range) { for (var k = range[0]; k <= range[1]; k++) all.push(k) })
    if (all.length === 0) return
    var at = Math.min.apply(null, all)
    beginOp()
    clearBlockSelection()
    all.sort(function(a, b) { return b - a }).forEach(function(i) { removeAt(i) })
    list.forEach(function(b, n) {
      var props = {}
      for (var k in b) props[k] = b[k]
      insertBlock(at + n, props, Blocks.isText(b.type) ? b.html || "" : "")
    })
    if (blocksModel.count === 0) insertBlock(0, { type: "p" }, "")
    endOp()
  }

  function restoreFocus(info) {
    if (selectedList.length > 0) { keyCatcher.forceActiveFocus(); return }
    if (info && info.uid && items[info.uid] && items[info.uid].isText) focusBlock(info.uid, info.pos, info.anchor)
  }

  // Inserting from the formatting bar: a divider, a code block, a sticky note…
  function insertKind(type, props) {
    var index = focusUid ? indexOf(focusUid) : blocksModel.count - 1
    if (selectedList.length > 0) index = indexOf(selectedList[selectedList.length - 1])
    var cur = index >= 0 ? blocksModel.get(index) : null
    beginOp()
    var uid
    // An empty paragraph just becomes the new kind.
    if (cur && cur.type === "p" && Blocks.isText(type) && !(htmls[cur.uid] || "") && !(items[cur.uid] && items[cur.uid].edit.length > 0)) {
      convert(cur.uid, type, false)
      for (var key in props || {}) if (key === "tone" || key === "label" || key === "days") blocksModel.setProperty(index, key, props[key])
      uid = cur.uid
    } else {
      var p = { type: type }
      for (var k in props || {}) p[k] = props[k]
      uid = insertBlock(index + 1, p, "")
    }
    if (!Blocks.isText(type) && indexOf(uid) === blocksModel.count - 1) insertBlock(blocksModel.count, { type: "p" }, "")
    endOp()
    if (Blocks.isText(type)) focusBlock(uid, 0)
    else {
      var after = textNeighbor(indexOf(uid), 1)
      if (after >= 0) focusBlock(uidAt(after), 0)
    }
    return uid
  }

  function insertPicture(afterUid, src, ratio) {
    var index = afterUid ? indexOf(afterUid) : blocksModel.count - 1
    beginOp()
    var uid = insertBlock(index + 1, { type: "image", src: src, width: 0.6, ratio: ratio > 0 ? ratio : 0, align: "center" }, "")
    if (indexOf(uid) === blocksModel.count - 1) insertBlock(blocksModel.count, { type: "p" }, "")
    endOp()
    var after = textNeighbor(indexOf(uid), 1)
    if (after >= 0) focusBlock(uidAt(after), 0)
  }

  function setRatio(uid, ratio) {
    var i = indexOf(uid)
    if (i < 0 || !(ratio > 0)) return
    // Not an edit of its own: part of whatever put the picture there.
    blocksModel.setProperty(i, "ratio", ratio)
    stable = snapshot()
    changed()
  }

  function beginResize(uid) { beginOp() }
  function resizeImage(uid, width) {
    var i = indexOf(uid)
    if (i >= 0) blocksModel.setProperty(i, "imgWidth", width)
  }
  function endResize(uid) { endOp() }

  function setImageAlign(uid, align) {
    var i = indexOf(uid)
    if (i < 0) return
    beginOp()
    blocksModel.setProperty(i, "align", align)
    endOp()
  }

  function setDivider(uid, style) {
    var i = indexOf(uid)
    if (i < 0) return
    beginOp()
    blocksModel.setProperty(i, "dstyle", style)
    endOp()
  }

  // ---- formatting text ------------------------------------------------------------------

  // Formatting chosen with nothing selected applies to what you type next.
  property var pending: null

  function transformed(inner, kind, value) {
    if (kind === "bold" || kind === "italic" || kind === "underline" || kind === "strike") return Html.toggle(inner, kind)
    if (kind === "code") return Html.toggle(inner, "code", monoFamily)
    if (kind === "color") return Html.setColor(inner, value)
    if (kind === "highlight") {
      // Highlighting what's already highlighted in that color takes it off.
      var s = Html.summarize(inner)
      return Html.setHighlight(inner, s.highlight === Html.normalColor(value) ? "" : value)
    }
    if (kind === "family") return Html.setFamily(inner, value)
    if (kind === "size") return Html.setSize(inner, value)
    if (kind === "link") return Html.setLink(inner, value)
    if (kind === "clear") return Html.clearFormatting(inner)
    // One kind of formatting off, whatever the text has now.
    if (kind === "off") {
      if (value === "bold") return Html.setStyle(inner, "font-weight", "")
      if (value === "italic") return Html.setStyle(inner, "font-style", "")
      if (value === "code") return Html.setFamily(inner, "")
      if (value === "strike") return Html.mapRuns(inner, function(run) { Html.setDecoration(run.style, "line-through", false); return run })
    }
    return inner
  }

  function formatInline(kind, value) {
    // Code in Pages is plain text, in its language's colors.
    if (doc && selectedList.length === 0 && typeOf(focusUid) === "code") return
    if (selectedList.length > 0) {
      var list = selectedList.filter(function(u) { return Blocks.isText(typeOf(u)) && !(root.doc && typeOf(u) === "code") })
      if (list.length === 0) return
      syncAll()
      // Toggles go one way for all of them: on unless every block already has it.
      var all = list.map(function(u) { return htmls[u] || "" }).join("<br />")
      beginOp()
      var on = kind === "bold" || kind === "italic" || kind === "underline" || kind === "strike" || kind === "code" ? Html.wouldApply(all, kind) : true
      list.forEach(function(u) {
        var inner = htmls[u] || ""
        var next = transformed(inner, kind, value)
        if ((kind === "bold" || kind === "italic" || kind === "underline" || kind === "strike" || kind === "code") && Html.wouldApply(inner, kind) !== on)
          next = inner
        setHtml(u, next)
      })
      endOp()
      keyCatcher.forceActiveFocus()
      return
    }
    var item = items[focusUid]
    if (!item || !item.isText) return
    var edit = item.edit
    var s = edit.selectionStart
    var e = edit.selectionEnd
    if (s === e) {
      if (kind === "clear") { pending = null; scheduleFormat(); return }
      // Nothing selected: the next thing typed gets it.
      var base = pending && pending.uid === item.uid && pending.pos === s ? pending.changes : []
      pending = { uid: item.uid, pos: s, changes: base.concat([{ kind: kind, value: value }]) }
      scheduleFormat()
      edit.forceActiveFocus()
      return
    }
    beginOp()
    var inner2 = innerOf(edit, s, e)
    var out = transformed(inner2, kind, value)
    replaceRange(item, s, e, out)
    // Still selected, in the undo step too, so undoing gives it back selected.
    edit.forceActiveFocus()
    edit.select(s, e)
    endOp()
  }

  // Rich text going into a block keeps its spaces (Qt's HTML reader would
  // drop a space at either end of it, or a lone one).
  function spaced(html) {
    return "<span style=\"white-space: pre-wrap;\">" + html + "</span>"
  }

  // Puts rich text in place of [s, e) in a block, as one change.
  function replaceRange(item, s, e, inner) {
    var edit = item.edit
    item.loading = true
    edit.remove(s, e)
    if (inner) edit.insert(s, spaced(Html.decorateLinks(display(inner), linkColor, tagStyle)))
    item.loading = false
    item.dirty = true
    syncBlock(item.uid)
  }

  // Whatever was typed since Ctrl+B (or the like) with nothing selected.
  function applyPending(item) {
    var p = pending
    if (!p || p.uid !== item.uid) return
    var edit = item.edit
    var end = edit.cursorPosition
    if (end <= p.pos || edit.inputMethodComposing) return
    pending = null
    var inner = innerOf(edit, p.pos, end)
    p.changes.forEach(function(c) { inner = transformed(inner, c.kind, c.value) })
    replaceRange(item, p.pos, end, inner)
    edit.cursorPosition = end
  }

  // Text sizes to pick from (px), with the block's own among them.
  function sizeChoices(normal) {
    var list = [11, 12, 14, 16, 18, 20, 24, 28, 32, 40, 48, 64]
    if (list.indexOf(normal) < 0) {
      list.push(normal)
      list.sort(function(a, b) { return a - b })
    }
    return list
  }

  // The size of the block's own text where the cursor is.
  function normalSize() {
    var t = formatState.type && Blocks.isText(formatState.type) ? formatState.type : "p"
    return Papers.typeStyle(t, pen, spacing).size
  }

  // One size bigger (dir 1) or smaller (-1) than what's selected, or what's
  // at the cursor. Back at the block's own size, it has no size of its own.
  function stepSize(dir) {
    updateFormat()
    var normal = normalSize()
    var size = formatState.inline && formatState.inline.size ? Number(formatState.inline.size) : normal
    var list = sizeChoices(normal)
    var next = size
    if (dir > 0) {
      for (var i = 0; i < list.length; i++) if (list[i] > size) { next = list[i]; break }
    } else {
      for (var j = list.length - 1; j >= 0; j--) if (list[j] < size) { next = list[j]; break }
    }
    if (next !== size) formatInline("size", next === normal ? 0 : next)
  }

  // A link on the selection, or on the word at the cursor.
  function setLink(url) {
    var item = items[focusUid]
    if (!item || !item.isText) return
    var clean = url ? Html.cleanUrl(url) : ""
    if (url && !clean) return
    var edit = item.edit
    if (edit.selectionStart === edit.selectionEnd) edit.selectWord()
    if (edit.selectionStart === edit.selectionEnd) {
      // An empty spot: write the address itself as the link.
      if (!clean) return
      beginOp()
      var at = edit.cursorPosition
      replaceRange(item, at, at, Html.setLink(Html.escapeText(clean), clean))
      endOp()
      edit.forceActiveFocus()
      edit.cursorPosition = at + clean.length
      return
    }
    formatInline("link", clean)
  }

  function currentLink() {
    var item = items[focusUid]
    if (!item || !item.isText) return ""
    var e = item.edit
    var a = e.selectionStart
    var b = e.selectionEnd
    if (a === b) { a = Math.max(0, a - 1); b = Math.min(e.length, b + 1) }
    var s = Html.summarize(innerOf(e, a, b))
    return s.link || ""
  }

  function selectedText() {
    var item = items[focusUid]
    if (!item || !item.isText) return ""
    return item.edit.selectedText
  }

  // ---- what the formatting bar shows ------------------------------------------------------

  Timer {
    id: formatTimer
    interval: 30
    onTriggered: root.updateFormat()
  }

  function scheduleFormat() { formatTimer.restart() }

  function updateFormat() {
    var st = { type: "", indent: 0, align: "left", checked: false, tone: "", inline: {}, hasSelection: false, blocks: selectedList.length, uid: focusUid, canUndo: canUndo, canRedo: canRedo }
    if (selectedList.length > 0) {
      var types = {}
      var inner = []
      selectedList.forEach(function(u) {
        var i = indexOf(u)
        if (i < 0) return
        types[blocksModel.get(i).type] = true
        if (Blocks.isText(blocksModel.get(i).type)) inner.push(htmls[u] || "")
      })
      var keys = Object.keys(types)
      st.type = keys.length === 1 ? keys[0] : ""
      st.inline = Html.summarize(inner.join("<br />"))
      st.hasSelection = true
      if (keys.length === 1) {
        var first = blocksModel.get(indexOf(selectedList[0]))
        st.align = first.align
        st.tone = first.tone
        st.indent = first.indent
      }
    } else {
      var index = indexOf(focusUid)
      if (index >= 0) {
        var r = blocksModel.get(index)
        st.type = r.type
        st.indent = r.indent
        st.align = r.align
        st.checked = r.checked
        st.tone = r.tone
        st.color = r.color
        st.toggle = r.toggle
        var item = items[focusUid]
        if (item && item.isText) {
          var e = item.edit
          var a = e.selectionStart
          var b = e.selectionEnd
          st.hasSelection = a !== b
          st.inline = Html.summarize(a !== b ? innerOf(e, a, b) : innerOf(e, Math.max(0, a - 1), a))
          if (pending && pending.uid === item.uid) {
            pending.changes.forEach(function(c) {
              if (c.kind === "bold" || c.kind === "italic" || c.kind === "underline" || c.kind === "strike" || c.kind === "code")
                st.inline[c.kind] = st.inline[c.kind] === "all" ? "none" : "all"
              else if (c.kind === "color") st.inline.color = c.value
              else if (c.kind === "highlight") st.inline.highlight = c.value
              else if (c.kind === "size") st.inline.size = c.value ? String(c.value) : ""
              else if (c.kind === "off") st.inline[c.value] = "none"
            })
          }
        }
      }
    }
    formatState = st
  }

  // ---- picking whole blocks -------------------------------------------------------------

  property bool dragSelecting: false

  function selectBlocks(fromUid, toUid) {
    var a = indexOf(fromUid)
    var b = indexOf(toUid)
    if (a < 0 || b < 0) return
    closeBurst()
    pending = null
    var lo = Math.min(a, b)
    var hi = Math.max(a, b)
    // In Pages, a block picked is picked with everything inside it.
    if (doc) for (var k = lo; k <= hi; k++) hi = Math.max(hi, subtreeEnd(k))
    var map = {}
    var list = []
    for (var i = lo; i <= hi; i++) { map[uidAt(i)] = true; list.push(uidAt(i)) }
    selectionAnchor = fromUid
    selectedMap = map
    selectedList = list
    if (items[focusUid] && items[focusUid].edit) items[focusUid].edit.deselect()
    keyCatcher.forceActiveFocus()
    var top = items[uidAt(lo)]
    if (top) cursorAt(top.y, top.height)
    scheduleFormat()
  }

  function clearBlockSelection() {
    if (selectedList.length === 0) return
    selectedMap = ({})
    selectedList = []
    selectionAnchor = ""
    scheduleFormat()
  }

  // Keys while whole blocks are picked.
  Item {
    id: keyCatcher
    Keys.onPressed: function(e) { root.blockKey(e) }
  }

  function blockKey(e) {
    if (selectedList.length === 0) { e.accepted = false; return }
    // A locked page: only moving around and copying.
    if (readOnly && !((e.modifiers & Qt.ControlModifier) && (e.key === Qt.Key_C || e.key === Qt.Key_A))
        && [Qt.Key_Up, Qt.Key_Down, Qt.Key_Escape, Qt.Key_Return, Qt.Key_Enter].indexOf(e.key) < 0) { e.accepted = true; return }
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    var key = e.key
    var lo = indexOf(selectedList[0])
    var hi = indexOf(selectedList[selectedList.length - 1])
    var anchor = indexOf(selectionAnchor)
    var list = selectedList.slice()
    e.accepted = true
    if (ctrl && !alt && key === Qt.Key_Z) { if (shift) redo(); else undo(); return }
    if (ctrl && !alt && key === Qt.Key_Y) { redo(); return }
    if (ctrl && !alt && key === Qt.Key_A) { selectBlocks(uidAt(0), uidAt(blocksModel.count - 1)); return }
    if (ctrl && !alt && (key === Qt.Key_C || key === Qt.Key_X)) { copyBlocks(list, key === Qt.Key_X); return }
    if ((ctrl && !alt && key === Qt.Key_V) || (shift && key === Qt.Key_Insert)) { pasteAfter(selectedList[selectedList.length - 1], shift); return }
    if (ctrl && !shift && !alt && key === Qt.Key_B) { formatInline("bold"); return }
    if (ctrl && !shift && !alt && key === Qt.Key_I) { formatInline("italic"); return }
    if (ctrl && !shift && !alt && key === Qt.Key_U) { formatInline("underline"); return }
    if (ctrl && shift && !alt && key === Qt.Key_X) { formatInline("strike"); return }
    if (ctrl && shift && !alt && key === Qt.Key_H) { formatInline("highlight", Papers.HIGHLIGHTS[0].light); return }
    if (ctrl && !shift && !alt && key === Qt.Key_Backslash) { formatInline("clear"); return }
    if (ctrl && shift && !alt && (key === Qt.Key_Greater || key === Qt.Key_Period)) { stepSize(1); return }
    if (ctrl && shift && !alt && (key === Qt.Key_Less || key === Qt.Key_Comma)) { stepSize(-1); return }
    if (ctrl && !shift && !alt && key === Qt.Key_D) { duplicateBlocks(list); return }
    if (ctrl && alt && !shift && key >= Qt.Key_0 && key <= Qt.Key_3) { setType(list, ["p", "h1", "h2", "h3"][key - Qt.Key_0]); return }
    if (ctrl && shift && (key === Qt.Key_7 || key === Qt.Key_Ampersand)) { toggleType(list, "number"); return }
    if (ctrl && shift && (key === Qt.Key_8 || key === Qt.Key_Asterisk)) { toggleType(list, "bullet"); return }
    if (ctrl && shift && (key === Qt.Key_9 || key === Qt.Key_ParenLeft)) { toggleType(list, "check"); return }
    if (alt && shift && (key === Qt.Key_Up || key === Qt.Key_Down)) { moveBlocks(list, key === Qt.Key_Up ? -1 : 1); return }
    if (key === Qt.Key_Tab) { indentBlocks(list, 1); return }
    if (key === Qt.Key_Backtab) { indentBlocks(list, -1); return }
    if (key === Qt.Key_Backspace || key === Qt.Key_Delete) { removeBlocks(list); return }
    if (key === Qt.Key_Escape) {
      var back = list[0]
      clearBlockSelection()
      if (items[back] && items[back].isText) focusBlock(back, -1)
      else {
        var near = textNeighbor(indexOf(back), 1)
        if (near < 0) near = textNeighbor(indexOf(back), -1)
        if (near >= 0) focusBlock(uidAt(near), 0)
      }
      return
    }
    if (key === Qt.Key_Return || key === Qt.Key_Enter) {
      var first = list[0]
      if (items[first] && items[first].isText) { clearBlockSelection(); focusBlock(first, -1) }
      else if (typeOf(first) === "image") openPicture(items[first] ? items[first].src : "")
      return
    }
    if (key === Qt.Key_Up || key === Qt.Key_Down) {
      var dir = key === Qt.Key_Up ? -1 : 1
      if (shift) {
        // Grow or shrink from the end away from where it started.
        var moving = anchor === lo ? hi : lo
        var next = Math.max(0, Math.min(blocksModel.count - 1, moving + dir))
        selectBlocks(uidAt(anchor), uidAt(next))
      } else {
        var target = Math.max(0, Math.min(blocksModel.count - 1, (dir < 0 ? lo : hi) + dir))
        selectBlocks(uidAt(target), uidAt(target))
      }
      return
    }
    e.accepted = false
  }

  // ---- dragging across blocks picks them -------------------------------------------------

  // The block at a point (in Pages, in the column the point's in).
  function blockAtPoint(x, y) {
    var near = ""
    for (var i = 0; i < blocksModel.count; i++) {
      var item = items[uidAt(i)]
      if (!item || item.height <= 0) continue
      var across = !doc || (x >= item.x && x < item.x + item.width)
      if (y >= item.y && y < item.y + item.height) {
        if (across) return uidAt(i)
        if (!near) near = uidAt(i)
      }
    }
    if (near) return near
    return y < 0 ? uidAt(0) : uidAt(blocksModel.count - 1)
  }

  property string dragFrom: ""

  function dragMoved(pressX, pressY, x, y) {
    var from = blockAtPoint(pressX, pressY)
    var to = blockAtPoint(x, y)
    if (!from || !to) return
    if (!dragSelecting) {
      if (from === to) return
      dragSelecting = true
      dragFrom = from
      var item = items[from]
      if (item && item.edit) {
        item.edit.selectByMouse = false
        item.edit.deselect()
      }
    }
    selectBlocks(dragFrom, to)
  }

  // After the release has reached the text it started in (which takes the
  // keyboard back as it lets go), the picked blocks keep it.
  function dragEnded() {
    if (!dragSelecting) return
    Qt.callLater(function() {
      var item = root.items[root.dragFrom]
      if (item && item.edit) item.edit.selectByMouse = true
      root.dragFrom = ""
      keyCatcher.forceActiveFocus()
      root.dragSelecting = false
    })
  }

  // ---- the clipboard -------------------------------------------------------------------------

  // What Uber Notebook itself last copied, so pasting it back keeps everything.
  property string lastCopied: ""
  property var copiedBlocks: null

  TextEdit {
    id: clipArea
    visible: false
    textFormat: TextEdit.RichText
  }
  TextSelection {
    id: clipSelection
    document: clipArea.textDocument
  }

  function blocksAsHtml(list) {
    var out = ""
    var open = ""
    function close() { if (open) out += "</" + open + ">"; open = "" }
    list.forEach(function(b) {
      var inner = b.html || ""
      var listTag = b.type === "bullet" || b.type === "check" ? "ul" : b.type === "number" ? "ol" : ""
      if (listTag !== open) { close(); if (listTag) { out += "<" + listTag + ">"; open = listTag } }
      if (b.type === "bullet" || b.type === "number") out += "<li>" + inner + "</li>"
      else if (b.type === "check") out += "<li class=\"" + (b.checked ? "checked" : "unchecked") + "\">" + inner + "</li>"
      else if (b.type === "h1" || b.type === "h2" || b.type === "h3") out += "<" + b.type + ">" + inner + "</" + b.type + ">"
      else if (b.type === "quote") out += "<blockquote>" + inner + "</blockquote>"
      else if (b.type === "code") out += "<pre>" + inner + "</pre>"
      else if (b.type === "divider") out += "<hr />"
      else if (b.type === "time") out += "<p>" + (b.label ? Html.escapeText(b.label) + " " : "") + inner + "</p>"
      else if (b.type === "table") out += tableHtml(b.table)
      else if (b.type === "bookmark") out += b.data && b.data.url ? "<p><a href=\"" + Html.escapeAttr(b.data.url) + "\">" + Html.escapeText(b.data.title || b.data.url) + "</a></p>" : ""
      else if (b.type === "board") out += b.data ? b.data.columns.map(function(c) { return "<p><b>" + Html.escapeText(c.name) + "</b></p><ul>" + c.cards.map(function(k) { return "<li>" + Html.escapeText(k.text) + "</li>" }).join("") + "</ul>" }).join("") : ""
      else if (b.type === "meeting") out += b.meeting && b.meeting.segments && b.meeting.segments.length ? "<p>" + Html.escapeText(Meeting.text(b.meeting)).replace(/\n/g, "<br />") + "</p>" : ""
      else if (b.type === "audio") out += b.audio && b.audio.transcript ? "<p>" + Html.escapeText(b.audio.transcript).replace(/\n/g, "<br />") + "</p>" : ""
      else if (b.type === "image" || b.type === "calendar" || b.type === "columns" || b.type === "column" || b.type === "sketch") out += ""
      else out += "<p>" + inner + "</p>"
    })
    close()
    return "<html><body>" + out + "</body></html>"
  }

  function copyBlocks(uids, cut) {
    syncAll()
    var list = uids.map(indexOf).filter(function(i) { return i >= 0 }).sort(function(a, b) { return a - b }).map(blockAt)
    if (list.length === 0) return
    clipArea.text = blocksAsHtml(list)
    clipArea.selectAll()
    clipArea.copy()
    clipSelection.selectionStart = 0
    clipSelection.selectionEnd = clipArea.length
    lastCopied = normalizeClip(clipSelection.text)
    copiedBlocks = JSON.parse(JSON.stringify(list))
    if (cut) removeBlocks(uids)
  }

  function normalizeClip(text) {
    return String(text || "").replace(/[\u2028\u2029\n\r\ufffc]+/g, "\n").replace(/[ \t\u00a0]+/g, " ").trim()
  }

  // What's on the clipboard, as plain text ("\n" between lines).
  function clipboardText() {
    clipArea.text = ""
    clipArea.paste()
    clipSelection.selectionStart = 0
    clipSelection.selectionEnd = clipArea.length
    return String(clipSelection.text || "").replace(/[\u2028\u2029]/g, "\n")
  }

  // Blocks put in at an index (their depths kept, from 0), as one step; the
  // cursor goes to the last of them unless `keepFocus`.
  function insertBlocksAt(index, list, keepFocus) {
    if (!list || list.length === 0) return
    var at = Math.max(0, Math.min(blocksModel.count, index))
    beginOp()
    var last = ""
    list.forEach(function(b, n) {
      var props = {}
      for (var k in b) props[k] = b[k]
      last = insertBlock(at + n, props, Blocks.isText(b.type) ? b.html || "" : "")
    })
    endOp()
    if (!keepFocus) focusBlock(last, -1)
  }

  // What's on the clipboard, as blocks: [{ type, html, checked }].
  function clipboardBlocks(keepLook) {
    clipArea.text = ""
    clipArea.paste()
    var n = clipArea.length
    if (n === 0) return []
    clipSelection.selectionStart = 0
    clipSelection.selectionEnd = n
    var raw = clipSelection.text
    if (copiedBlocks && normalizeClip(raw) === lastCopied) {
      return copiedBlocks.map(function(b) { var c = JSON.parse(JSON.stringify(b)); delete c.uid; return c })
    }
    var keep = keepLook === true || (lastCopied !== "" && normalizeClip(raw) === lastCopied)
    // In Pages, a table (from a spreadsheet, a web page) is a table.
    if (doc) {
      var whole = clipArea.getFormattedText(0, n)
      if (/<table[\s>]/i.test(whole)) {
        var read = Import.fromHtml(whole, null, {}).blocks
        if (read.some(function(b) { return b.type === "table" })) return read
      }
    }
    var out = []
    var start = 0
    for (var i = 0; i <= raw.length; i++) {
      if (i < raw.length && raw.charCodeAt(i) !== 0x2029) continue
      var full = clipArea.getFormattedText(start, i)
      var inner = Html.sanitize(Html.extractInner(full), keep)
      var b = { type: "p", html: inner }
      var head = full.slice(0, full.indexOf("<!--StartFragment-->") >= 0 ? full.indexOf("<!--StartFragment-->") : full.length)
      if (/<li class="checked"/.test(head)) { b.type = "check"; b.checked = true }
      else if (/<li class="unchecked"/.test(head)) b.type = "check"
      else if (/<ol[\s>]/.test(head)) b.type = "number"
      else if (/<ul[\s>]/.test(head)) b.type = "bullet"
      else if (/<h1[\s>]/.test(head)) b.type = "h1"
      else if (/<h2[\s>]/.test(head)) b.type = "h2"
      else if (/<h[3-6][\s>]/.test(head)) b.type = "h3"
      else if (/<pre[\s>]/.test(head)) b.type = "code"
      out.push(b)
      start = i + 1
    }
    // Trailing empty paragraph from the copy.
    if (out.length > 1 && out[out.length - 1].html === "" && out[out.length - 1].type === "p") out.pop()
    // In Pages, Markdown pasted as plain text becomes blocks, and cells
    // from a spreadsheet (a row a line, tabs between) a table.
    if (doc && out.every(function(b) { return b.type === "p" })) {
      var text = raw.replace(/[\u2028\u2029]/g, "\n")
      var cells = Table.fromTSV(text)
      if (cells) return [{ type: "table", table: { rows: cells, header: true }, indent: 0 }]
      if (Import.looksLikeMarkdown(text)) {
        var md = Import.fromMarkdown(text, null, {}).blocks
        if (md.length) return md
      }
    }
    return out
  }

  function paste(item, plainOnly) {
    var edit = item.edit
    var list = clipboardBlocks(false)
    if (list.length === 0) {
      pastePicture(item.uid)
      return
    }
    if (plainOnly) list = list.map(function(b) { return { type: b.type === "code" ? "code" : "p", html: Html.fromPlainText(Html.plainText(b.html || "")) } })
    // In Pages, emails pasted in text are links.
    if (doc) list = list.map(function(b) {
      if (!Blocks.isText(b.type) || b.type === "code" || !b.html) return b
      var o = {}
      for (var k in b) o[k] = b[k]
      o.html = Html.linkEmails(b.html, root.personOfEmail)
      return o
    })
    var uid = item.uid
    var index = indexOf(uid)
    var cur = blocksModel.get(index)
    // Into code in Pages: the text as it is, every line of it, in the block.
    if (doc && cur.type === "code") {
      var text = clipboardText().replace(/\r\n?/g, "\n")
      beginOp()
      item.loading = true
      edit.remove(edit.selectionStart, edit.selectionEnd)
      item.loading = false
      var at = edit.cursorPosition
      replaceRange(item, at, at, Html.fromPlainText(text))
      endOp()
      focusBlock(uid, at + text.length)
      recolor(uid)
      return
    }
    beginOp()
    if (edit.selectionStart !== edit.selectionEnd) {
      item.loading = true
      edit.remove(edit.selectionStart, edit.selectionEnd)
      item.loading = false
      item.dirty = true
    }
    var pos = edit.cursorPosition
    // One line of text goes in where the cursor is.
    if (list.length === 1 && Blocks.isText(list[0].type) && (list[0].type === "p" || list[0].type === cur.type)) {
      var inner = list[0].html || ""
      replaceRange(item, pos, pos, inner)
      endOp()
      focusBlock(uid, pos + Html.plainText(inner).length)
      return
    }
    // More: the block splits around it.
    var head = innerOf(edit, 0, pos)
    var tail = pos < edit.length ? innerOf(edit, pos, edit.length) : ""
    var headEmpty = Html.plainText(head).length === 0
    var at = index
    var lastUid = uid
    var lastLen = 0
    // In Pages what's pasted keeps its shape, as deep as where it goes.
    var base = Math.min.apply(null, list.map(function(b) { return b.indent || 0 }))
    list.forEach(function(b, n) {
      var inner = b.html || ""
      if (n === 0 && Blocks.isText(b.type) && !headEmpty) {
        setHtml(uid, head + inner)
        lastUid = uid
        lastLen = Html.plainText(head + inner).length
        return
      }
      if (n === 0 && headEmpty) {
        // The block was empty up to the cursor: it becomes the first pasted block.
        if (Blocks.isText(b.type)) {
          convert(uid, b.type, b.checked === true)
          setHtml(uid, inner)
          lastUid = uid
          lastLen = Html.plainText(inner).length
          return
        }
      }
      at += 1
      var props = {}
      for (var k in b) props[k] = b[k]
      if (root.doc) props.indent = cur.indent + Math.max(0, (b.indent || 0) - base)
      lastUid = insertBlock(at, props, Blocks.isText(b.type) ? inner : "")
      lastLen = Html.plainText(inner).length
    })
    if (tail) {
      var lastIndex = indexOf(lastUid)
      if (Blocks.isText(blocksModel.get(lastIndex).type)) setHtml(lastUid, (htmls[lastUid] || "") + tail)
      else lastUid = insertBlock(lastIndex + 1, { type: "p" }, tail)
    }
    endOp()
    focusBlock(lastUid, lastLen)
  }

  // Pasting with blocks picked: after them.
  function pasteAfter(uid, plainOnly) {
    var list = clipboardBlocks(false)
    if (list.length === 0) { pastePicture(uid); return }
    var index = indexOf(uid)
    var depth = index >= 0 ? blocksModel.get(index).indent : 0
    if (doc) index = subtreeEnd(index)
    var base = Math.min.apply(null, list.map(function(b) { return b.indent || 0 }))
    beginOp()
    var last = ""
    list.forEach(function(b, n) {
      var props = {}
      for (var k in b) props[k] = b[k]
      if (plainOnly) props = { type: "p" }
      if (root.doc) props.indent = depth + Math.max(0, (b.indent || 0) - base)
      last = insertBlock(index + 1 + n, props, Blocks.isText(props.type) ? (plainOnly ? Html.fromPlainText(Html.plainText(b.html || "")) : b.html || "") : "")
    })
    endOp()
    selectBlocks(uidAt(index + 1), last)
  }

  // ---- find in page ---------------------------------------------------------------------

  property var findList: []

  function find(query) {
    syncAll()
    var q = String(query || "").toLowerCase()
    var matches = {}
    var list = []
    if (q) {
      for (var i = 0; i < blocksModel.count; i++) {
        var uid = uidAt(i)
        var item = items[uid]
        if (!item || !item.isText || isHidden(uid)) continue
        var text = item.edit.getText(0, item.edit.length).toLowerCase()
        var at = text.indexOf(q)
        var found = []
        while (at >= 0 && found.length < 200) {
          found.push([at, at + q.length])
          list.push({ uid: uid, index: found.length - 1, start: at, end: at + q.length })
          at = text.indexOf(q, at + q.length)
        }
        if (found.length) matches[uid] = found
      }
    }
    findMatches = matches
    findList = list
    return list.length
  }

  function clearFind() {
    findMatches = ({})
    findList = []
    findCurrentUid = ""
    findCurrentIndex = -1
  }

  // Shows the n-th match, selected, and returns it.
  function showMatch(n) {
    if (findList.length === 0) return -1
    var i = ((n % findList.length) + findList.length) % findList.length
    var m = findList[i]
    findCurrentUid = m.uid
    findCurrentIndex = m.index
    var item = items[m.uid]
    if (item) {
      var r = item.edit.positionToRectangle(m.start)
      cursorAt(item.y + item.edit.y + r.y, r.height)
    }
    return i
  }

  // Selects the current match in its block, to type over it.
  function takeMatch() {
    var item = items[findCurrentUid]
    if (!item || findCurrentIndex < 0) return
    var m = (findMatches[findCurrentUid] || [])[findCurrentIndex]
    if (!m) return
    focusBlock(findCurrentUid, m[1], m[0])
  }

  // ---- the page itself ---------------------------------------------------------------------

  // A notebook's blocks, one under another.
  Column {
    id: column
    visible: !root.doc
    width: root.contentWidth

    Repeater {
      model: root.doc ? null : blocksModel
      delegate: Block { editor: root }
    }
  }

  // Pages' blocks, each put in its place by positionBlocks (in columns, side by side).
  Item {
    id: docArea
    visible: root.doc
    width: root.contentWidth
    height: root.docHeight

    Repeater {
      model: root.doc ? blocksModel : null
      delegate: DocBlock { editor: root }
    }

    // Between two columns: drag to share the width between them otherwise.
    Repeater {
      model: root.readOnly ? [] : root.columnGaps
      delegate: Item {
        id: gap
        required property var modelData
        readonly property var column: root.docLayout[modelData.left] || ({ left: 0, w: 0 })
        x: column.left + column.w + root.columnGap / 2 - 6
        y: modelData.top
        width: 12
        height: modelData.height
        z: 15
        property var start: null
        Rectangle {
          anchors.horizontalCenter: parent.horizontalCenter
          width: 3
          height: parent.height
          radius: 1.5
          color: Qt.alpha(root.accent, 0.6)
          visible: gapHover.hovered || gapDrag.active
        }
        HoverHandler { id: gapHover; cursorShape: Qt.SplitHCursor }
        DragHandler {
          id: gapDrag
          target: null
          cursorShape: Qt.SplitHCursor
          onActiveChanged: {
            if (active) gap.start = root.beginColumnResize(gap.modelData.columns)
            else root.endColumnResize()
          }
          onTranslationChanged: if (active && gap.start) root.resizeColumns(gap.start, gap.modelData.left, gap.modelData.right, translation.x)
        }
      }
    }
  }

  // Where a block being dragged would go: a line between blocks, or up the
  // side of one (to put them in columns).
  Rectangle {
    readonly property var t: root.dropTarget
    visible: t !== null
    z: 20
    x: t ? t.x : 0
    y: t ? (t.vertical ? t.y : t.y - 2) : 0
    width: t ? (t.vertical ? 3 : t.w) : 0
    height: t && t.vertical ? t.h : 3
    radius: 1.5
    color: Qt.alpha(root.accent, 0.8)
  }

  // Watches drags that start in one block and move to another. It lies over
  // the blocks, so it sees each press first; taking none, it passes it on to
  // the text under it.
  Item {
    anchors.fill: root.doc ? docArea : column
    PointHandler {
      id: dragWatch
      target: null
      acceptedButtons: Qt.LeftButton
      acceptedModifiers: Qt.NoModifier
      onActiveChanged: if (!active) root.dragEnded()
      onPointChanged: {
        if (!active || root.readOnly) return
        var dy = point.position.y - point.pressPosition.y
        if (!root.dragSelecting && Math.abs(dy) < 6) return
        root.dragMoved(point.pressPosition.x, point.pressPosition.y, point.position.x, point.position.y)
      }
    }
  }
}
