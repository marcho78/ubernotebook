import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace
import "../Docs.js" as Docs
import "../Blocks.js" as Blocks
import "../Markdown.js" as Markdown
import "../Import.js" as Import
import "../Html.js" as Html
import "../Templates.js" as Templates
import "../Agent.js" as Agent
import "../Colors.js" as Colors

// Pages: the other way to write in Omanote, the way Notion does it. The
// sidebar has every page as a tree; the page you're on has its cover, icon
// and title, then its blocks (Editor.qml in its "doc" layout), with the "/"
// menu, a toolbar over selected words, and a menu on each block's handle.
// A page is saved a moment after you stop, and when you leave it.
FocusScope {
  id: view

  property var theme: null
  property var workspace: null
  property var service: null
  readonly property var settings: service && service.settings ? service.settings : ({})

  signal notebooksRequested()
  signal settingsRequested()
  signal toast(string text)
  // A picture from the desktop's file picker: done(path) ("" for none).
  signal pictureRequested(var done)
  signal confirmRequested(string title, string text, string action, var confirmed)
  // Notes to import: the desktop's file picker, for files or a folder.
  signal importRequested(bool folder)

  // The open page (Workspace.cleanPage), changed in place; `revision` counts
  // every change, so what's worked out from it looks again.
  property var page: null
  property int revision: 0
  property bool pageDirty: false
  property bool sidebarShown: true
  property var openRows: ({})
  property var history: []
  property int historyAt: -1
  property bool pendingActivate: false
  property bool settingTitle: false
  // Nothing on the page yet: it can start from a template.
  property bool pageBlank: false
  // The faint title of a page from a template you name ("What's the meeting?").
  property string titleHint: ""

  readonly property var index: { var r = workspace ? workspace.revision : 0; return workspace ? workspace.index : Workspace.emptyIndex() }
  readonly property var format: { var r = revision; return page && page.format ? page.format : ({ width: "normal", size: "normal", font: "sans" }) }
  readonly property bool small: format.size === "small"
  // A locked page reads but can't be changed (unlock it in its ⋯ menu).
  readonly property bool locked: format.locked === true
  readonly property bool favorite: { var r = workspace ? workspace.revision : 0; return page && workspace ? workspace.isFavorite(page.id) : false }
  readonly property string family: theme.penFamily(Docs.font(format.font).families)
  readonly property real sidebarW: sidebarShown ? 250 : 0
  readonly property real pageW: format.width === "full" ? Math.max(360, main.width - 2 * 96) : Math.max(320, Math.min(720, main.width - 2 * 84))
  readonly property alias editor: editor
  readonly property alias agentBox: agentPop
  readonly property alias historyPanel: historyPanel
  readonly property var crumbs: { var r = workspace ? workspace.revision : 0; var rr = revision; return page && workspace ? Workspace.path(workspace.index, page.id) : [] }
  readonly property string cover: { var r = revision; return page ? page.cover : "" }
  // The pages that link to this one.
  readonly property var backlinks: { var r = workspace ? workspace.revision : 0; var rr = revision; return page && workspace ? Workspace.backlinks(workspace.index, page.id) : [] }
  readonly property string icon: { var r = revision; return page ? page.icon : "" }
  readonly property real coverH: cover ? 200 : 0

  // ---- opening pages -------------------------------------------------------------------

  // Pages shown: the page you were on last, else the first one.
  function activate() {
    if (page) { focusPage(false); return }
    if (!workspace || !workspace.ready) { pendingActivate = true; return }
    workspace.ensureStarted()
    var ix = workspace.index
    var last = settings.lastPage || ""
    if (last && ix.pages[last] && !Workspace.inTrash(ix, last)) { open(last); return }
    var first = ix.top.filter(function(id) { return ix.pages[id] && !ix.pages[id].trashed })[0]
    if (first) { open(first); return }
    pendingActivate = true
  }

  Connections {
    target: view.workspace
    function onRevisionChanged() {
      if (view.pendingActivate && view.workspace.ready && view.visible) {
        view.pendingActivate = false
        view.activate()
      }
    }
    // A page changed on disk while it was open but unchanged here (a page
    // moved into it from elsewhere): shown as it is now.
    function onPageChanged(id) {
      if (view.page && view.page.id === id && !view.pageDirty) view.workspace.readPage(id, function(p) { if (p && view.page && view.page.id === id) view.show(p) })
    }
  }

  // Opens a page; `then`: "title" puts the cursor in its title.
  function open(id, fromHistory, then) {
    if (!workspace || !id) return
    commit()
    workspace.readPage(id, function(p) {
      if (!p) { view.toast("That page isn't there any more"); return }
      var e = view.workspace.index.pages[id]
      if (e) p.parent = e.parent
      view.show(p)
      if (!fromHistory) {
        view.history = view.history.slice(0, view.historyAt + 1).concat([id]).slice(-100)
        view.historyAt = view.history.length - 1
      }
      view.expandTo(id)
      if (view.service) view.service.setSetting("lastPage", id)
      view.focusPage(then === "title")
    })
  }

  function show(p) {
    page = p
    settingTitle = true
    titleEdit.text = p.title
    settingTitle = false
    editor.load(Workspace.flatten(p))
    pageDirty = false
    titleHint = ""
    updateBlank()
    flick.contentY = 0
    findBar.refresh()
    revision++
  }

  function updateBlank() {
    pageBlank = page !== null && editor.model.count <= 1 && Blocks.isBlank(editor.serialize())
  }

  function pageTitleText() { return titleEdit.text }

  function focusPage(title) {
    if (!page) { view.forceActiveFocus(); return }
    if (title || (!page.title && Blocks.isBlank(editor.serialize()))) {
      titleEdit.forceActiveFocus()
      titleEdit.cursorPosition = titleEdit.length
    } else {
      view.forceActiveFocus()
    }
  }

  function markDirty() {
    pageDirty = true
    saveTimer.restart()
  }

  Timer {
    id: saveTimer
    interval: 700
    onTriggered: view.commit()
  }

  // Writes the open page, if it changed. Pages whose blocks came off it go to
  // the trash (and come back if their block does, with Undo).
  function commit() {
    saveTimer.stop()
    if (!pageDirty || !page || !workspace) return
    pageDirty = false
    var p = page
    var before = Workspace.childPages(p)
    var tree = Workspace.unflatten(editor.serialize(), p.id)
    p.content = tree.content
    p.blocks = tree.blocks
    p.title = Workspace.cleanTitle(titleEdit.text)
    p.modified = new Date().toISOString()
    var after = Workspace.childPages(p)
    before.forEach(function(id) {
      var e = view.workspace.index.pages[id]
      if (after.indexOf(id) < 0 && e && e.parent === p.id && !e.trashed) view.workspace.trashPage(id, true)
    })
    after.forEach(function(id) {
      var e = view.workspace.index.pages[id]
      if (e && e.trashed) view.workspace.restorePage(id, true)
    })
    workspace.savePage(p)
    revision++
  }

  // ---- making, moving and throwing away pages ------------------------------------------

  // A new page, at the top ("") or inside a page (at the end of it).
  function newPage(parentId) {
    if (!workspace) return
    commit()
    var parent = parentId && workspace.index.pages[parentId] ? parentId : ""
    var child = workspace.createPage({ parent: parent })
    if (!child) return
    if (parent) {
      if (page && page.id === parent) {
        editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: child.id })
        markDirty()
        commit()
      } else {
        workspace.editPage(parent, function(p) { return Workspace.appendPageBlock(p, child.id) })
      }
    }
    open(child.id, false, "title")
  }

  // "/page": a page inside this one, where the "/" was; then it opens.
  function subpageIn(uid) {
    if (!page) return
    var child = workspace.createPage({ parent: page.id })
    if (!child) return
    editor.placeBlock(uid, { type: "page", id: child.id })
    markDirty()
    commit()
    open(child.id, false, "title")
  }

  function trashPage(id) {
    if (!id || !workspace || !workspace.index.pages[id]) return
    var e = workspace.index.pages[id]
    var wasOpen = page && Workspace.withDescendants(workspace.index, id).indexOf(page.id) >= 0
    if (page && e.parent === page.id) {
      editor.removeBlocks([id])
      markDirty()
      commit()
    } else {
      commit()
      workspace.trashPage(id, false)
    }
    toast("\u201c" + (e.title || "Untitled") + "\u201d is in the trash")
    if (wasOpen) {
      pageDirty = false
      page = null
      var parent = e.parent && !Workspace.inTrash(workspace.index, e.parent) ? e.parent : ""
      if (parent) open(parent)
      else activate()
    }
  }

  function restorePage(id) {
    var e = workspace.index.pages[id]
    if (!e) return
    var onOpen = page && e.parent === page.id
    workspace.restorePage(id, onOpen)
    if (onOpen) {
      editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: id })
      markDirty()
      commit()
    }
    toast("\u201c" + (e.title || "Untitled") + "\u201d is back")
    if (!page) activate()
  }

  function deletePage(id) {
    var e = workspace.index.pages[id]
    if (!e) return
    confirmRequested("Delete \u201c" + (e.title || "Untitled") + "\u201d from Pages?",
      "It and the pages inside it leave Pages. Their files go to the .trash folder in your notebooks folder, where you can still get them back.",
      "Delete", function() { view.workspace.deleteForever(id) })
  }

  // Moves a page into another page ("" for the top).
  function movePage(id, target) {
    var e = workspace.index.pages[id]
    if (!e || e.parent === target) return
    var from = e.parent
    if (page && from === page.id) editor.removeBlocks([id])
    if (page && target === page.id) editor.placeBlock(editor.uidAt(editor.model.count - 1), { type: "page", id: id })
    if (!workspace.movePage(id, target, -1, page ? page.id : "")) return
    if (page && (from === page.id || target === page.id)) { markDirty(); commit() }
    if (page && page.id === id) { page.parent = target; markDirty(); commit() }
    var where = target ? (workspace.index.pages[target].title || "Untitled") : "the top of Pages"
    toast("Moved to " + where)
  }

  // Blocks moved (with what's inside them) to the end of another page.
  function moveBlocks(uids, target) {
    if (!page || !target || target === page.id) return
    editor.syncAll()
    var list = []
    editor.subtreeRanges(uids).forEach(function(r) { for (var k = r[0]; k <= r[1]; k++) list.push(editor.blockAt(k)) })
    if (list.length === 0) return
    var base = Math.min.apply(null, list.map(function(b) { return b.indent || 0 }))
    list.forEach(function(b) { b.indent = (b.indent || 0) - base })
    var name = workspace.index.pages[target] ? (workspace.index.pages[target].title || "Untitled") : ""
    commit()
    workspace.editPage(target, function(p) {
      var tree = Workspace.unflatten(Workspace.flatten(p).concat(list), p.id)
      p.content = tree.content
      p.blocks = tree.blocks
      return true
    }, function(ok) {
      if (!ok) return
      editor.removeBlocks(uids)
      view.markDirty()
      view.commit()
      view.toast("Moved to \u201c" + name + "\u201d")
    })
  }

  // ---- importing -------------------------------------------------------------------------------

  // Notes from files or folders, as pages (inside `parentId`, or at the top).
  function importPaths(paths, parentId) {
    if (!workspace || !paths || !paths.length) return
    commit()
    toast("Importing\u2026")
    workspace.importPaths(paths, parentId || "", function(r) {
      var note = r.pages ? "Imported " + r.pages + (r.pages === 1 ? " page" : " pages") : "There were no notes to import"
      if (r.skipped && r.skipped.length) note += " (" + r.skipped.length + " not: install pandoc or LibreOffice for Word files)"
      view.toast(note)
      if (r.first) view.open(r.first)
      else if (parentId && view.page && view.page.id === parentId) view.workspace.readPage(parentId, function(p) { if (p) view.show(p) })
    })
  }

  function openImport(anchor) {
    importMenu.parent = anchor
    importMenu.x = 8
    importMenu.y = -importMenu.implicitHeight - 6
    importMenu.open()
  }

  // Pasting several lines into the title: the first is the title, the rest
  // (Markdown or not) the start of the page.
  function pasteIntoTitle() {
    var text = editor.clipboardText()
    if (text.indexOf("\n") < 0) return false
    var lines = text.replace(/\r/g, "").split("\n")
    while (lines.length && !lines[0].trim()) lines.shift()
    var first = (lines.shift() || "").replace(/^\s*#{1,6}\s+/, "").trim()
    var rest = lines.join("\n")
    var read = Import.looksLikeMarkdown(rest) ? Import.fromMarkdown(rest, null, {}) : Import.fromText(rest)
    titleEdit.remove(titleEdit.selectionStart, titleEdit.selectionEnd)
    titleEdit.insert(titleEdit.cursorPosition, Workspace.cleanTitle(first))
    if (read.blocks.length) editor.insertBlocksAt(0, read.blocks)
    return true
  }

  // ---- favorites, copies, turning a block into a page -------------------------------------

  function toggleFavorite(id) {
    if (!workspace || !id) return
    workspace.toggleFavorite(id)
    toast(workspace.isFavorite(id) ? "In Favorites" : "Out of Favorites")
  }

  function duplicatePage(id) {
    if (!workspace || !id) return
    commit()
    var e = workspace.index.pages[id]
    workspace.duplicatePage(id, page ? page.id : "", function(copy) {
      if (!copy) return
      // On the open page: the copy's block right under the original's.
      if (view.page && e && e.parent === view.page.id) {
        var at = view.editor.indexOf(id)
        view.editor.placeBlock(at >= 0 ? id : view.editor.uidAt(view.editor.model.count - 1), { type: "page", id: copy })
        view.markDirty()
        view.commit()
      }
      view.open(copy)
    })
  }

  // A block (and what's inside it) as a page inside this one: its text the
  // page's title, what's inside it the page.
  function turnIntoPage(uid) {
    if (!page || locked) return
    var i = editor.indexOf(uid)
    if (i < 0) return
    editor.syncAll()
    var root = editor.blockAt(i)
    var end = editor.subtreeEnd(i)
    var kids = []
    for (var k = i + 1; k <= end; k++) {
      var b = editor.blockAt(k)
      b.indent -= root.indent + 1
      kids.push(b)
    }
    var title = Workspace.cleanTitle(Html.plainText(root.html || ""))
    var child = workspace.createPage({ parent: page.id, title: title, blocks: kids.length ? kids : undefined })
    if (!child) return
    editor.replaceSubtree(uid, { type: "page", id: child.id })
    markDirty()
    commit()
    toast("\u201c" + (title || "Untitled") + "\u201d is a page now")
  }

  // ---- your agent ---------------------------------------------------------------------------------

  // Ask agent: about the page, the blocks picked, the words selected, or the
  // empty line you're on ("line"). "auto" (Ctrl+J) works out which from
  // where you are. The page is written first, so the agent reads it as it is.
  function openAgent(scope, uids) {
    if (!page) return
    var ctx = { scope: "page", blocks: [], words: "", line: "" }
    var list = uids || []
    if (scope === "blocks" && list.length) {
      ctx = { scope: "blocks", blocks: list.slice(), words: "", line: "" }
    } else if (scope === "line" && list.length) {
      ctx = { scope: "line", blocks: [], words: "", line: list[0] }
    } else if (scope === "words" || scope === "auto") {
      var item = editor.focusUid ? editor.items[editor.focusUid] : null
      var words = item && item.isText ? String(item.edit.selectedText || "").replace(/[\u2028\u2029]/g, "\n") : ""
      if (editor.selectedList.length > 0) ctx = { scope: "blocks", blocks: editor.selectedList.slice(), words: "", line: "" }
      else if (words.trim()) ctx = { scope: "words", blocks: [editor.focusUid], words: words, line: "" }
      else if (scope === "auto" && item && item.isText && !locked && item.edit.length === 0 && Html.plainText(editor.htmls[editor.focusUid] || "") === "")
        ctx = { scope: "line", blocks: [], words: "", line: editor.focusUid }
    }
    commit()
    agentPop.start(ctx)
  }

  // What you asked, handed to your agent with where you are.
  function askAgent(request) {
    if (!page || !workspace) return
    var ctx = agentPop.ask
    commit()
    workspace.files.launchAgent(Agent.prompt({
      request: request, page: { id: page.id, title: Workspace.cleanTitle(titleEdit.text) || page.title },
      scope: ctx.scope, blocks: ctx.blocks, words: ctx.words, line: ctx.line,
      skill: service && service.skillPath ? service.skillPath : ""
    }))
    toast("Asked " + (Agent.name(agentPop.agent) || "your agent") + ": it's working in a terminal, and what it changes shows up here")
  }

  // ---- commands (an agent, a script) -----------------------------------------------------------

  // What a command adds to the page open here goes in at its end (before
  // the empty line it ends with), as one step you can undo, the cursor
  // staying where it is. true, "locked", or false when it's another page.
  function appendFromCommand(id, blocks) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    var at = editor.model.count
    var lastUid = editor.uidAt(at - 1)
    var last = at > 0 ? editor.blockAt(at - 1) : null
    if (last && last.type === "p" && last.indent === 0 && Html.plainText(last.html || "") === ""
        && !(editor.items[lastUid] && editor.items[lastUid].edit.length > 0)) at--
    editor.insertBlocksAt(at, blocks, true)
    markDirty()
    commit()
    return true
  }

  // A command changing a block on the page open here: the block (and what's
  // inside it) replaced, or blocks put in after it, as one step you can
  // undo. true, "locked", or false when it's another page.
  function replaceFromCommand(id, change) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    if (editor.indexOf(change.block) < 0) return false
    editor.replaceWithBlocks(change.block, change.blocks)
    markDirty()
    commit()
    return true
  }

  function insertFromCommand(id, change) {
    if (!page || page.id !== id) return false
    if (locked) return "locked"
    if (editor.indexOf(change.block) < 0) return false
    editor.insertAfterBlock(change.block, change.blocks)
    markDirty()
    commit()
    return true
  }

  // A page a command made inside the page open here: its block goes in
  // there the same way.
  function pageAddedInto(parentId, childId) {
    if (!page || page.id !== parentId) return false
    return appendFromCommand(parentId, [{ type: "page", id: childId, indent: 0 }]) === true
  }

  // ---- templates -----------------------------------------------------------------------------

  readonly property var templates: Templates.TEMPLATES.filter(function(t) { return t.id !== "blank" })

  // A blank page made from a template: its blocks, and its title and icon
  // if it has none yet. Undo takes the blocks back off.
  function applyTemplate(id) {
    if (!page || locked || !pageBlank) return
    var t = Templates.forPages(id, Templates.iso(new Date()), function(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) })
    editor.replaceAll(t.blocks)
    if (!page.icon && t.icon) page.icon = Workspace.cleanIcon(t.icon)
    if (!titleEdit.text.trim() && t.title) titleEdit.text = t.title
    titleHint = t.hint
    markDirty()
    revision++
    if (!titleEdit.text.trim() && t.hint) { titleEdit.forceActiveFocus(); titleEdit.cursorPosition = 0 }
  }

  // ---- the page's look -----------------------------------------------------------------------

  function setFormat(key, value) {
    if (!page) return
    var f = {}
    for (var k in page.format) f[k] = page.format[k]
    f[key] = value
    page.format = Workspace.cleanFormat(f)
    markDirty()
    commit()
  }

  // ---- page history ------------------------------------------------------------------------

  function openHistory() {
    if (!page || !workspace) return
    commit()
    historyPanel.openFor(page.id)
  }

  // An earlier version of the page put back, as a step Undo takes back (the
  // page as it was is kept in its history first, too).
  function restoreVersion(version, label) {
    if (!page || !workspace || locked || !version) return
    commit()
    workspace.keepVersion(page.id, "restore", true)
    var r = Workspace.versionToRestore(version, page, workspace.index)
    editor.resetBlocks(r.blocks)
    if (Workspace.cleanTitle(titleEdit.text) !== r.title) titleEdit.text = r.title
    page.icon = Workspace.cleanIcon(r.icon)
    markDirty()
    commit()
    toast("Restored the version from " + label + "  \u00b7  Ctrl+Z takes it back")
  }

  function setIcon(emoji) {
    if (!page) return
    page.icon = Workspace.cleanIcon(emoji)
    markDirty()
    commit()
  }

  function setCover(cover) {
    if (!page) return
    page.cover = Workspace.cleanCover(cover)
    markDirty()
    commit()
  }

  function copyMarkdown() {
    commit()
    if (!page) return
    workspace.files.copyText(Markdown.fromDocPage(page, function(id) {
      var e = view.workspace.index.pages[id]
      return e ? { title: e.title || "Untitled", icon: e.icon, file: "" } : null
    }))
    toast("Copied the page as Markdown")
  }

  function exportPage() {
    commit()
    if (page) workspace.exportPage(page.id)
  }

  // Pages to link to with "[[": the ones called what's typed, or the most
  // recent; not this one.
  function findPages(query) {
    if (!workspace) return []
    var ix = workspace.index
    var here = page ? page.id : ""
    var ids = String(query || "").trim() ? Workspace.findTitles(ix, query, 9)
      : Object.keys(ix.pages).filter(function(id) { return !Workspace.inTrash(ix, id) })
          .sort(function(a, b) { return ix.pages[a].modified < ix.pages[b].modified ? 1 : -1 }).slice(0, 9)
    return ids.filter(function(id) { return id !== here }).slice(0, 8).map(function(id) {
      return { id: id, title: ix.pages[id].title, icon: ix.pages[id].icon,
        path: Workspace.path(ix, id).slice(0, -1).map(function(p) { return p.title || "Untitled" }).join(" / ") }
    })
  }

  // ---- getting around ------------------------------------------------------------------------

  function back() { if (historyAt > 0) { historyAt--; open(history[historyAt], true) } }
  function forward() { if (historyAt < history.length - 1) { historyAt++; open(history[historyAt], true) } }

  function expandTo(id) {
    var o = {}
    for (var k in openRows) o[k] = openRows[k]
    Workspace.path(workspace.index, id).slice(0, -1).forEach(function(p) { o[p.id] = true })
    openRows = o
  }

  function toggleRow(id) {
    var o = {}
    for (var k in openRows) o[k] = openRows[k]
    o[id] = !o[id]
    openRows = o
  }

  function openFind() { quickFind.start() }
  function openTrash() { trashPop.x = 12; trashPop.y = view.height - trashPop.height - 60; trashPop.open() }
  function openRowMenu(id, anchor) {
    rowMenu.pageId = id
    rowMenu.parent = anchor
    rowMenu.x = anchor.width - 20
    rowMenu.y = anchor.height - 4
    rowMenu.open()
  }

  // Asks where to move a page.
  property string moving: ""
  function movePageAsk(id) {
    if (!id) return
    moving = id
    picker.purpose = "movePage"
    picker.exclude = id
    picker.allowTop = true
    picker.openAt(main, "Move \u201c" + (workspace.index.pages[id].title || "Untitled") + "\u201d to\u2026")
  }

  // Where it's asked from: the block a link or picture goes in or after.
  property string pickFor: ""
  property var movingBlocks: []

  function ensureVisible(y, h) {
    var p = editor.mapToItem(flick.contentItem, 0, y)
    var top = p.y - 90
    var bottom = p.y + h + 90
    var max = Math.max(0, flick.contentHeight - flick.height)
    if (top < flick.contentY) flick.contentY = Math.max(0, Math.round(top))
    else if (bottom > flick.contentY + flick.height) flick.contentY = Math.round(Math.min(max, bottom - flick.height))
  }

  // ---- what's on screen -------------------------------------------------------------------------

  Rectangle {
    anchors.fill: parent
    color: view.theme.background
  }

  DocSidebar {
    id: sidebar
    theme: view.theme
    view: view
    width: 250
    height: parent.height
    x: view.sidebarShown ? 0 : -width
    visible: x > -width
    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
  }

  Item {
    id: main
    x: view.sidebarW
    width: view.width - x
    height: view.height
    Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

    // The bar above: the sidebar, back and forward, where the page is, its menu.
    Item {
      id: topBar
      z: 3
      width: parent.width
      height: 46

      Row {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton {
          visible: !view.sidebarShown
          theme: view.theme; icon: view.theme.icons.sidebar; size: 30; iconSize: 16; tip: "Show the sidebar  Ctrl+\\"
          onClicked: view.sidebarShown = true
        }
        IconButton { theme: view.theme; icon: view.theme.icons.back; size: 30; iconSize: 16; tip: "Back  Alt+\u2190"; active: view.historyAt > 0; onClicked: view.back() }
        IconButton { theme: view.theme; icon: view.theme.icons.forward; size: 30; iconSize: 16; tip: "Forward  Alt+\u2192"; active: view.historyAt < view.history.length - 1; onClicked: view.forward() }
        Item { width: 6; height: 1 }
        Repeater {
          model: view.crumbs
          delegate: Row {
            required property var modelData
            required property int index
            anchors.verticalCenter: parent.verticalCenter
            Text {
              textFormat: Text.PlainText
              visible: index > 0
              anchors.verticalCenter: parent.verticalCenter
              text: "  /  "
              font.family: view.theme.uiFont
              font.pixelSize: 13
              color: view.theme.faint
            }
            Rectangle {
              width: crumb.implicitWidth + 12
              height: 26
              radius: 5
              color: crumbHover.hovered ? view.theme.hover : "transparent"
              Text {
                id: crumb
                textFormat: Text.PlainText
                anchors.centerIn: parent
                width: Math.min(implicitWidth, 200)
                elide: Text.ElideRight
                text: (modelData.icon ? modelData.icon + " " : "") + (modelData.title || "Untitled")
                font.family: view.theme.uiFont
                font.pixelSize: 13
                color: view.theme.text
              }
              HoverHandler { id: crumbHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.open(modelData.id) }
            }
          }
        }
      }

      Row {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          visible: view.page !== null
          rightPadding: 10
          text: { var r = view.revision; return view.page ? "Edited " + Qt.formatDateTime(new Date(view.page.modified), "d MMM, HH:mm") : "" }
          font.family: view.theme.uiFont
          font.pixelSize: 12
          color: view.theme.faint
        }
        IconButton {
          visible: view.locked
          theme: view.theme; icon: view.theme.icons.lock; label: "Locked"; size: 30; iconSize: 14; tint: view.theme.muted
          tip: "Locked: it can't be changed. Click to unlock"
          onClicked: view.setFormat("locked", false)
        }
        IconButton {
          visible: view.page !== null
          theme: view.theme; icon: view.favorite ? view.theme.icons.star : view.theme.icons.starOutline; size: 30; iconSize: 16
          tint: view.favorite ? "#e0a82e" : view.theme.text
          tip: view.favorite ? "In Favorites" : "Add to Favorites"
          onClicked: view.toggleFavorite(view.page.id)
        }
        IconButton {
          visible: view.page !== null
          theme: view.theme; icon: view.theme.icons.agent; size: 30; iconSize: 16
          tip: "Ask your agent  Ctrl+J"
          onClicked: view.openAgent("auto")
        }
        IconButton { theme: view.theme; icon: view.theme.icons.search; size: 30; iconSize: 16; tip: "Find on this page  Ctrl+F"; checked: findBar.shown; onClicked: findBar.toggle() }
        IconButton {
          id: moreButton
          theme: view.theme; icon: view.theme.icons.more; size: 30; iconSize: 16; tip: "Font, width, export, trash"
          active: view.page !== null
          onClicked: pageMenu.open()
          PageMenu {
            id: pageMenu
            theme: view.theme
            view: view
            x: moreButton.width - width
            y: moreButton.height + 6
          }
        }
      }
    }

    // ---- the page -----------------------------------------------------------------------------

    Flickable {
      id: flick
      anchors.top: topBar.bottom
      anchors.bottom: parent.bottom
      width: parent.width
      contentWidth: width
      contentHeight: Math.max(height, header.height + editor.height + 260)
      interactive: false
      clip: true
      visible: view.page !== null
      Behavior on contentY { enabled: !wheel.active; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

      // The cover, across the whole page.
      Item {
        id: coverArea
        width: flick.width
        height: view.coverH
        visible: view.cover !== ""
        readonly property var stops: Docs.coverStops(view.cover)
        Rectangle {
          anchors.fill: parent
          visible: coverArea.stops !== null
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: coverArea.stops ? coverArea.stops[0] : "black" }
            GradientStop { position: coverArea.stops && coverArea.stops.length > 2 ? 0.5 : 1.0; color: coverArea.stops ? coverArea.stops[1] : "black" }
            GradientStop { position: 1.0; color: coverArea.stops ? coverArea.stops[coverArea.stops.length - 1] : "black" }
          }
        }
        Image {
          anchors.fill: parent
          visible: coverArea.stops === null
          source: coverArea.stops === null && view.cover ? view.workspace.assetUrl(view.cover) : ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
        }
        HoverHandler { id: coverHover }
        Row {
          visible: coverHover.hovered
          anchors.right: parent.right
          anchors.rightMargin: 16
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 12
          spacing: 6
          Chip { theme: view.theme; text: "Change cover"; color: view.theme.surfaceHigh; onClicked: coverPop.openAt(this) }
          Chip { theme: view.theme; text: "Remove"; color: view.theme.surfaceHigh; onClicked: view.setCover("") }
        }
      }

      Column {
        id: header
        x: (flick.width - view.pageW) / 2
        y: view.cover ? view.coverH - (view.icon ? 42 : 0) : (view.icon ? 54 : 70)
        width: view.pageW
        spacing: 4

        // The icon, and (on hover) buttons to add one or a cover.
        Text {
          id: iconText
          textFormat: Text.PlainText
          visible: view.icon !== ""
          text: view.icon
          font.family: "Noto Color Emoji"
          font.pixelSize: 64
          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: { emojiPop.target = "page"; emojiPop.removable = true; emojiPop.openAt(iconText) } }
        }
        Item {
          width: parent.width
          height: 30
          HoverHandler { id: headHover }
          Row {
            visible: headHover.hovered || titleEdit.activeFocus && titleEdit.length === 0
            spacing: 4
            IconButton {
              id: addIcon
              visible: view.icon === ""
              theme: view.theme; icon: view.theme.icons.emoji; label: "Add icon"; size: 28; iconSize: 15; tint: view.theme.muted
              onClicked: { emojiPop.target = "page"; emojiPop.removable = false; view.setIcon(Docs.randomEmoji()) }
            }
            IconButton {
              id: addCover
              visible: view.cover === ""
              theme: view.theme; icon: view.theme.icons.cover; label: "Add cover"; size: 28; iconSize: 15; tint: view.theme.muted
              onClicked: view.setCover("gradient:" + Math.floor(Math.random() * Docs.COVERS.length))
            }
          }
        }

        // The title.
        TextEdit {
          id: titleEdit
          width: parent.width
          textFormat: TextEdit.PlainText
          wrapMode: TextEdit.Wrap
          font.family: view.family
          font.pixelSize: view.small ? 34 : 40
          font.weight: Font.Bold
          color: view.theme.text
          selectionColor: Qt.alpha(view.theme.accent, 0.3)
          selectedTextColor: view.theme.text
          selectByMouse: true
          readOnly: view.locked
          onTextChanged: {
            if (view.settingTitle || !view.page) return
            // The sidebar and the path above follow as you type.
            var e = view.workspace.index.pages[view.page.id]
            if (e) { e.title = Workspace.cleanTitle(text); view.workspace.revision++ }
            view.markDirty()
          }
          Keys.onPressed: function(e) {
            if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || (e.key === Qt.Key_Down && titleEdit.cursorPosition === titleEdit.length) || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
              e.accepted = true
              editor.focusStart()
            } else if (((e.modifiers & Qt.ControlModifier) && e.key === Qt.Key_V) || ((e.modifiers & Qt.ShiftModifier) && e.key === Qt.Key_Insert)) {
              if (view.pasteIntoTitle()) e.accepted = true
            }
          }
          Text {
            textFormat: Text.PlainText
            visible: titleEdit.length === 0 && titleEdit.preeditText === ""
            text: view.titleHint || "Untitled"
            font: titleEdit.font
            color: Qt.alpha(view.theme.text, 0.25)
          }
        }
        // The pages that link here.
        Flow {
          visible: view.backlinks.length > 0
          width: parent.width
          spacing: 4
          topPadding: 4
          Text {
            textFormat: Text.PlainText
            height: 26
            verticalAlignment: Text.AlignVCenter
            rightPadding: 4
            text: "\u21a9 Linked from"
            font.family: view.theme.uiFont
            font.pixelSize: 12
            color: view.theme.muted
          }
          Repeater {
            model: view.backlinks
            delegate: Rectangle {
              required property var modelData
              readonly property var e: view.workspace.index.pages[modelData] || ({ title: "", icon: "" })
              width: backName.implicitWidth + 16
              height: 26
              radius: 13
              color: backHover.hovered ? view.theme.hover : Qt.alpha(view.theme.text, 0.04)
              border.width: 1
              border.color: view.theme.line
              Text {
                id: backName
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: (parent.e.icon ? parent.e.icon + " " : "") + (parent.e.title || "Untitled")
                font.family: view.theme.uiFont
                font.pixelSize: 12
                color: view.theme.text
              }
              HoverHandler { id: backHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: view.open(modelData) }
            }
          }
        }
        Item { width: 1; height: 10 }

        Editor {
          id: editor
          layout: "doc"
          width: view.pageW
          contentWidth: width
          focus: true
          family: view.family
          monoFamily: view.theme.monoFont
          uiFamily: view.theme.uiFont
          ink: view.theme.text
          muted: view.theme.muted
          accent: view.theme.accent
          linkColor: view.theme.accent
          selectionColor: Qt.alpha(view.theme.accent, 0.3)
          dark: view.theme.dark
          paper: view.theme.background
          smallText: view.small
          readOnly: view.locked
          strikeDone: view.settings.strikeDone !== false
          assetUrl: function(src) { return view.workspace ? view.workspace.assetUrl(src) : "" }
          pageInfo: function(id) { return view.workspace ? view.workspace.pageMeta(id) : null }
          pagesRevision: view.workspace ? view.workspace.revision : 0
          findPages: function(query) { return view.findPages(query) }
          makePage: function(title) {
            var made = view.workspace ? view.workspace.createPage({ parent: "", title: title }) : null
            return made ? made.id : ""
          }
          onChanged: { view.markDirty(); if (view.pageBlank || editor.model.count <= 1) view.updateBlank() }
          onCursorAt: function(y, h) { view.ensureVisible(y, h) }
          onLeaveTop: { titleEdit.forceActiveFocus(); titleEdit.cursorPosition = titleEdit.length }
          onPageOpened: function(id) { view.open(id) }
          onSubpageRequested: function(uid) { view.subpageIn(uid) }
          onPageLinkRequested: function(uid) {
            view.pickFor = uid
            picker.purpose = "link"
            picker.exclude = ""
            picker.allowTop = false
            picker.openAt(main, "Link to page")
          }
          onImageRequested: function(uid) {
            view.pictureRequested(function(path) {
              if (path) view.workspace.importPicture(path, function(src) { if (src) editor.placeBlock(uid, { type: "image", src: src, width: 1, align: "center" }) })
            })
          }
          onIconRequested: function(uid) {
            if (view.locked) return
            view.pickFor = uid
            emojiPop.target = "callout"
            emojiPop.removable = false
            var item = editor.items[uid]
            if (item) emojiPop.openAt(item)
          }
          onBlockMenuRequested: function(uid) {
            var item = editor.items[uid]
            if (!item) return
            blockMenu.openFor(uid, item)
            blockMenu.x = item.bx - 48
            blockMenu.y = (item.isText ? item.markY : 20) + 16
          }
          onLanguageRequested: function(uid) {
            if (view.locked) return
            view.pickFor = uid
            var item = editor.items[uid]
            if (!item) return
            langPop.current = item.lang || "Plain text"
            langPop.parent = item
            langPop.x = item.bx + 8
            langPop.y = item.textTop - 4
            langPop.open()
          }
          onTextCopied: function(text) { view.workspace.files.copyText(text); view.toast("Copied") }
          onLinkOpened: function(url) { view.workspace.files.openUrl(url) }
          onPictureOpened: function(src) { view.workspace.files.openUrl(view.workspace.assetUrl(src)) }
          onPastePicture: function(afterUid) { view.workspace.pastePicture(function(src) { if (src) editor.insertPicture(afterUid, src, 0) }) }
          onLinkRequested: linkPop.openAt(bubble)
          onMindMapColorsRequested: function(uid, anchor) { view.openIdeaColors(uid, anchor) }
          onTableMenuRequested: function(uid, kind, index, anchor) { tableMenu.openFor(uid, kind, index, anchor, view) }
          onTableColorsRequested: function(uid, anchor) { view.openTableColors(uid, anchor) }
          onAgentRequested: function(uid) {
            var i = editor.indexOf(uid)
            var empty = i >= 0 && Html.plainText(editor.blockAt(i).html || "") === "" && !(editor.items[uid] && editor.items[uid].edit.length > 0)
            view.openAgent(empty ? "line" : "blocks", [uid])
          }
        }

        // On a blank page: templates to start from.
        Column {
          id: templateRow
          visible: view.pageBlank && !view.locked
          width: parent.width
          topPadding: 18
          spacing: 10
          Text {
            textFormat: Text.PlainText
            text: "Start with a template"
            font.family: view.theme.uiFont
            font.pixelSize: 12
            font.weight: Font.DemiBold
            color: view.theme.muted
          }
          Flow {
            width: parent.width
            spacing: 6
            Repeater {
              model: view.templates
              delegate: Chip {
                required property var modelData
                theme: view.theme
                icon: view.theme.icons[modelData.icon] || ""
                text: modelData.label
                onClicked: view.applyTemplate(modelData.id)
              }
            }
          }
        }
      }

      // A click under the last block writes there.
      MouseArea {
        y: header.y + header.height
        width: flick.width
        height: Math.max(0, flick.contentHeight - y)
        cursorShape: Qt.IBeamCursor
        onClicked: editor.clickBelow()
      }

      DropArea {
        anchors.fill: parent
        onEntered: function(drag) { drag.accepted = drag.hasUrls }
        onDropped: function(drop) {
          if (!drop.hasUrls) return
          var after = editor.focusUid
          var notes = []
          for (var i = 0; i < drop.urls.length && i < 100; i++) {
            var path = decodeURIComponent(String(drop.urls[i]).replace(/^file:\/\//, ""))
            // Notes dropped on a page come in as pages inside it; pictures, on it.
            if (Import.kindOf(path) !== "") notes.push(path)
            else if (i < 12) view.workspace.importPicture(path, function(src) { if (src) editor.insertPicture(after, src, 0) })
          }
          if (notes.length && view.page) view.importPaths(notes, view.page.id)
        }
      }
    }

    WheelHandler {
      id: wheel
      target: null
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * 90
        var max = Math.max(0, flick.contentHeight - flick.height)
        flick.contentY = Math.round(Math.max(0, Math.min(max, flick.contentY - dy)))
      }
    }

    // No page open (none yet, or every one in the trash).
    Column {
      visible: view.page === null && view.workspace !== null && view.workspace.ready
      anchors.centerIn: parent
      spacing: 12
      Text {
        textFormat: Text.PlainText
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No page open"
        font.family: view.theme.uiFont
        font.pixelSize: 18
        color: view.theme.muted
      }
      IconButton {
        anchors.horizontalCenter: parent.horizontalCenter
        theme: view.theme; icon: view.theme.icons.newPage; label: "New page"
        onClicked: view.newPage("")
      }
    }

    // Over selected words: the toolbar.
    BubbleBar {
      id: bubble
      z: 6
      theme: view.theme
      editor: editor
      readonly property rect sel: {
        var s = editor.formatState
        var c = flick.contentY
        return editor.selectionRect()
      }
      readonly property point at: { var c = flick.contentY; return editor.mapToItem(main, sel.x, sel.y) }
      visible: editor.formatState.hasSelection === true && editor.selectedList.length === 0 && editor.slash === null && !view.locked
        && editor.formatState.type !== "code"
        && editor.dragUid === "" && editor.activeFocus && sel.width > 0
      x: Math.max(8, Math.min(main.width - width - 8, at.x + sel.width / 2 - width / 2))
      y: at.y - height - 8 < topBar.height ? at.y + sel.height + 8 : at.y - height - 8
      onLinkRequested: function(anchor) { linkPop.openAt(anchor) }
      onAgentRequested: view.openAgent("words")
    }

    FindBar {
      id: findBar
      z: 5
      theme: view.theme
      editor: editor
      anchors.horizontalCenter: parent.horizontalCenter
      y: topBar.height + 4
      onDone: view.forceActiveFocus()
    }
  }

  // ---- popovers -------------------------------------------------------------------------------

  SlashMenu {
    id: slashMenu
    theme: view.theme
    editor: editor
  }

  Connections {
    target: editor
    function onSlashChanged() {
      if (editor.slash === null) { if (slashMenu.opened) slashMenu.close(); return }
      var r = editor.slashRect()
      slashMenu.parent = editor
      slashMenu.x = r.x - 8
      var below = editor.mapToItem(view, 0, r.y + r.height).y + slashMenu.height + 20 < view.height
      slashMenu.y = below ? r.y + r.height + 6 : r.y - slashMenu.height - 6
      if (!slashMenu.opened) slashMenu.open()
    }
  }

  MentionMenu {
    id: mentionMenu
    theme: view.theme
    editor: editor
  }

  Connections {
    target: editor
    function onMentionChanged() {
      if (editor.mention === null) { if (mentionMenu.opened) mentionMenu.close(); return }
      var r = editor.mentionRect()
      mentionMenu.parent = editor
      mentionMenu.x = r.x - 8
      var below = editor.mapToItem(view, 0, r.y + r.height).y + mentionMenu.height + 20 < view.height
      mentionMenu.y = below ? r.y + r.height + 6 : r.y - mentionMenu.height - 6
      if (!mentionMenu.opened) mentionMenu.open()
    }
  }

  BlockMenu {
    id: blockMenu
    theme: view.theme
    editor: editor
    onToPageRequested: function(uid) { view.turnIntoPage(uid) }
    onMindMapRequested: function(uids) {
      if (!editor.toMindMap(uids)) view.toast("A page is among those blocks, and it would go with them: move it out first")
    }
    onAgentRequested: function(uids) { view.openAgent("blocks", uids) }
    onMoveRequested: function(uids) {
      view.movingBlocks = uids
      picker.purpose = "moveBlocks"
      picker.exclude = view.page ? view.page.id : ""
      picker.allowTop = false
      picker.openAt(main, "Move to\u2026")
    }
  }

  AgentPop {
    id: agentPop
    theme: view.theme
    files: view.workspace ? view.workspace.files : null
    parent: view
    onSent: function(request) { view.askAgent(request) }
  }

  // ---- a mind map's colors ----------------------------------------------------------------

  // The colors you picked last (newest first), kept as a setting.
  readonly property var recentColors: Colors.recentList(settings.recentColors || "")
  function rememberColor(hex) {
    if (service) service.setSetting("recentColors", Colors.withRecent(settings.recentColors || "", hex))
  }

  // The map whose idea is being colored.
  property string colorTarget: ""
  property point colorAt: Qt.point(0, 0)
  property bool customOpen: false
  function colorMap() {
    var item = editor.items[colorTarget]
    return item && item.mindMap ? item.mindMap : null
  }

  // The colors for the idea you're on, beside its color button (placed on
  // the page: the map is drawn again under them as colors change).
  function openIdeaColors(uid, anchor) {
    var m = editor.items[uid] ? editor.items[uid].mindMap : null
    if (!m || !m.current) return
    colorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width + 6, 0)
    ideaColors.currentText = m.current.color || ""
    ideaColors.currentBack = m.current.background || ""
    ideaColors.x = colorAt.x
    ideaColors.y = colorAt.y
    ideaColors.open()
  }

  function openCustomColor(kind) {
    var m = colorMap()
    if (!m || !m.current) return
    customOpen = true
    customColor.recent = recentColors
    customColor.x = colorAt.x
    customColor.y = colorAt.y
    customColor.start(kind, kind === "color" ? m.current.color : m.current.background, m.colorInfo())
  }

  // The table whose cells are being colored (its colorScope says which).
  property string tableColorTarget: ""
  property bool tableCustomOpen: false
  function colorTable() {
    var item = editor.items[tableColorTarget]
    return item && item.tableView ? item.tableView : null
  }

  // The colors for a table's cells, beside the button or handle they were
  // asked for from.
  function openTableColors(uid, anchor) {
    var t = editor.items[uid] ? editor.items[uid].tableView : null
    if (!t || !t.colorScope) return
    tableColorTarget = uid
    colorAt = anchor.mapToItem(view, anchor.width + 6, 0)
    var now = t.scopeColors()
    tableColors.currentText = now.color
    tableColors.currentBack = now.background
    tableColors.x = colorAt.x
    tableColors.y = colorAt.y
    tableColors.open()
  }

  function openTableCustom(kind) {
    var t = colorTable()
    if (!t || !t.colorScope) return
    tableCustomOpen = true
    tableCustom.recent = recentColors
    tableCustom.x = colorAt.x
    tableCustom.y = colorAt.y
    var now = t.scopeColors()
    tableCustom.start(kind, kind === "color" ? now.color : now.background, t.colorInfo())
  }

  HistoryPanel {
    id: historyPanel
    theme: view.theme
    workspace: view.workspace
    view: view
    parent: view
    onRestoreRequested: function(page, label) { view.restoreVersion(page, label) }
  }

  // A table's row or column menu (its handle).
  TableMenu {
    id: tableMenu
    theme: view.theme
    editor: editor
  }

  // Colors for a mind map's idea (its color button).
  ColorPop {
    id: ideaColors
    theme: view.theme
    editor: editor
    mode: "idea"
    parent: view
    recent: view.recentColors
    onIdeaPicked: function(kind, color) {
      var m = view.colorMap()
      if (m) m.setIdeaColor(kind, color)
    }
    onCustomRequested: function(kind) { view.openCustomColor(kind) }
    onClosed: {
      if (view.customOpen) return
      var m = view.colorMap()
      if (m) m.colorsClosed(false)
    }
  }

  // Colors for a table's cells (the cell you're in, or a row or a column).
  ColorPop {
    id: tableColors
    objectName: "tableColors"
    theme: view.theme
    editor: editor
    mode: "idea"
    parent: view
    recent: view.recentColors
    onIdeaPicked: function(kind, color) { var t = view.colorTable(); if (t) t.applyColor(kind, color) }
    onCustomRequested: function(kind) { view.openTableCustom(kind) }
    onClosed: {
      if (view.tableCustomOpen) return
      var t = view.colorTable()
      if (t) t.colorsClosed(true)
    }
  }

  // A color of your own for them: shown in the table as you pick, kept with
  // Apply, put back with Cancel.
  ColorPicker {
    id: tableCustom
    objectName: "tableCustom"
    theme: view.theme
    parent: view
    onPreview: function(hex) { var t = view.colorTable(); if (t) t.previewColor(kind, hex) }
    onPicked: function(hex) {
      var t = view.colorTable()
      if (t) t.applyColor(kind, hex)
      view.rememberColor(hex)
    }
    onCanceled: { var t = view.colorTable(); if (t) t.cancelColor() }
    onClosed: {
      view.tableCustomOpen = false
      var t = view.colorTable()
      if (t) t.colorsClosed(true)
    }
  }

  // A color of your own for it: shown on the map as you pick, kept with
  // Apply, put back with Cancel.
  ColorPicker {
    id: customColor
    theme: view.theme
    parent: view
    onPreview: function(hex) { var m = view.colorMap(); if (m) m.previewIdeaColor(kind, hex) }
    onPicked: function(hex) {
      var m = view.colorMap()
      if (m) m.previewIdeaColor(kind, hex)
      view.rememberColor(hex)
    }
    onCanceled: { var m = view.colorMap(); if (m) m.previewIdeaColor(kind, original) }
    onClosed: {
      view.customOpen = false
      var m = view.colorMap()
      if (m) m.colorsClosed(true)
    }
  }

  LinkPop {
    id: linkPop
    theme: view.theme
    editor: editor
  }

  EmojiPop {
    id: emojiPop
    theme: view.theme
    property string target: "page"
    function openAt(anchor) {
      parent = anchor
      x = 0
      y = anchor.height + 6
      open()
    }
    onPicked: function(emoji) {
      if (target === "page") view.setIcon(emoji)
      else editor.setProp(view.pickFor, "icon", emoji)
    }
    onRemoved: if (target === "page") view.setIcon("")
  }

  CoverPop {
    id: coverPop
    theme: view.theme
    function openAt(anchor) {
      parent = anchor
      x = anchor.width - width
      y = -height - 8
      open()
    }
    onPicked: function(cover) { view.setCover(cover) }
    onUploadRequested: view.pictureRequested(function(path) {
      if (path) view.workspace.importPicture(path, function(src) { if (src) view.setCover(src) })
    })
  }

  ChoicePop {
    id: langPop
    theme: view.theme
    choices: Docs.LANGUAGES
    onPicked: function(value) { editor.setProp(view.pickFor, "lang", value === "Plain text" ? "" : value) }
  }

  PagePicker {
    id: picker
    theme: view.theme
    workspace: view.workspace
    property string purpose: "link"
    onPicked: function(id) {
      if (purpose === "link") editor.placeBlock(view.pickFor, { type: "link", target: id })
      else if (purpose === "moveBlocks") view.moveBlocks(view.movingBlocks, id)
      else if (purpose === "movePage") view.movePage(view.moving, id)
    }
  }

  QuickFind {
    id: quickFind
    theme: view.theme
    workspace: view.workspace
    parent: view
    onPageChosen: function(id) { view.open(id) }
  }

  TrashPop {
    id: trashPop
    theme: view.theme
    workspace: view.workspace
    parent: view
    onRestoreRequested: function(id) { view.restorePage(id) }
    onDeleteRequested: function(id) { view.deletePage(id) }
  }

  // Importing: files, or a whole folder (a Notion or Obsidian export).
  Pop {
    id: importMenu
    theme: view.theme
    focus: false
    width: 300
    contentItem: Column {
      spacing: 2
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.page; text: "Files\u2026"; hint: "Markdown, HTML, text, Word\u2026"; onClicked: { importMenu.close(); view.importRequested(false) } }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.folder; text: "A folder\u2026"; hint: "a Notion or Obsidian export"; onClicked: { importMenu.close(); view.importRequested(true) } }
    }
  }

  // A page's menu in the sidebar.
  Pop {
    id: rowMenu
    theme: view.theme
    property string pageId: ""
    focus: false
    width: 230
    contentItem: Column {
      spacing: 2
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.newPage; text: "A page inside it"; onClicked: { rowMenu.close(); view.newPage(rowMenu.pageId) } }
      MenuRow {
        width: parent.width; theme: view.theme
        icon: view.workspace && view.workspace.isFavorite(rowMenu.pageId) ? view.theme.icons.star : view.theme.icons.starOutline
        text: view.workspace && view.workspace.isFavorite(rowMenu.pageId) ? "Out of Favorites" : "Add to Favorites"
        onClicked: { rowMenu.close(); view.toggleFavorite(rowMenu.pageId) }
      }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.duplicate; text: "Duplicate"; onClicked: { rowMenu.close(); view.duplicatePage(rowMenu.pageId) } }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.move; text: "Move to\u2026"; onClicked: { rowMenu.close(); view.movePageAsk(rowMenu.pageId) } }
      Rectangle { width: parent.width; height: 1; color: view.theme.line }
      MenuRow { width: parent.width; theme: view.theme; icon: view.theme.icons.trash; text: "Move to the trash"; danger: true; onClicked: { rowMenu.close(); view.trashPage(rowMenu.pageId) } }
    }
  }

  // ---- keys -------------------------------------------------------------------------------------

  Keys.onPressed: function(e) { if (view.handleKey(e)) e.accepted = true }

  function handleKey(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    if (ctrl && !shift && !alt && e.key === Qt.Key_N) { newPage(""); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_P) { openFind(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_Backslash) { sidebarShown = !sidebarShown; return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_F) { findBar.open(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_J) { openAgent("auto"); return true }
    if (alt && !ctrl && e.key === Qt.Key_Left) { back(); return true }
    if (alt && !ctrl && e.key === Qt.Key_Right) { forward(); return true }
    return false
  }
}
