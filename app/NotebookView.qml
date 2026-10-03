import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../Papers.js" as Papers
import "../Covers.js" as Covers
import "../Blocks.js" as Blocks
import "../Library.js" as Library
import "../Markdown.js" as Markdown
import "../Templates.js" as Templates

// An open notebook on the desk: its back cover, the stack of pages, the page
// you're on with the binding down its left edge and index tabs on its right,
// the bar above it (back to the shelf, pages, find, a new page from a
// template) and the formatting bar below it. Pages turn over the binding; the
// cover swings open when the notebook is opened and shut when it's put back
// on the shelf. A planner's next page is its next day, week or month.
Item {
  id: view

  property var theme: null
  property var store: null
  property var settings: ({})
  property bool reduceMotion: false

  // The open notebook, with every page in it: { id, title, cover, binding,
  // paper, pen, pages: [...] }.
  property var nb: null
  property int pageIndex: 0
  property int revision: 0
  property real zoom: 1

  // Back to the shelf, please (the app shuts the cover and puts it away).
  signal closed()
  signal editRequested()
  signal soundRequested(string name)
  signal toast(string text)
  signal pictureFileRequested(string afterUid)

  readonly property alias editor: sheet.editor
  readonly property alias pageSheet: sheet
  // The notebook's pages change in place; `revision` counts every change, so
  // what's worked out from them looks again.
  readonly property var page: { var r = revision; return nb && nb.pages && nb.pages.length > pageIndex ? nb.pages[pageIndex] : null }
  readonly property int pageCount: { var r = revision; return nb && nb.pages ? nb.pages.length : 0 }
  readonly property var themeColors: ({ background: String(theme.background), foreground: String(theme.foreground), accent: String(theme.accent) })
  readonly property var look: { var r = revision; return Papers.resolve(page && page.paper ? page.paper : (nb ? nb.paper : null), themeColors) }
  readonly property var coverLook: { var r = revision; return Covers.resolve(nb ? nb.cover : null, String(theme.accent)) }
  // The back of a sheet: the same paper, its lines showing through faintly.
  readonly property var backLook: {
    var b = {}
    for (var k in look) b[k] = look[k]
    b.lineAlpha = (look.lineAlpha || 0.4) * 0.3
    b.marginAlpha = (look.marginAlpha || 0.6) * 0.3
    b.headRule = false
    b.paper = look.back
    return b
  }
  readonly property string binding: { var r = revision; return nb ? nb.binding : "spiral" }
  readonly property string pen: { var r = revision; return nb ? nb.pen : "sans" }
  readonly property string penFamily: theme.penFamily(Papers.pen(pen).families)
  readonly property bool busy: turning || openAnim.running || shutAnim.running

  // ---- sizes ------------------------------------------------------------------------

  readonly property real topBarH: 54
  readonly property real bottomBarH: 76
  readonly property real coverPad: 13
  readonly property real spineOut: binding === "spiral" ? 16 : 0
  readonly property real tabsOut: tabs.count > 0 ? 30 : 0
  readonly property real availW: (width - 56 - spineOut - tabsOut) / zoom
  readonly property real availH: (height - topBarH - bottomBarH - 18) / zoom
  // A page is taller than it is wide, like a notebook's, and never so wide
  // that lines get hard to read.
  readonly property real sheetH: Math.max(360, availH - coverPad * 2)
  readonly property real sheetW: Math.max(420, Math.min(860, availW - coverPad * 2, sheetH * 0.8))
  readonly property real leftGutter: binding === "spiral" ? 30 : 20

  // ---- pages ------------------------------------------------------------------------

  property bool pageDirty: false

  // Drawing on the page, and with what.
  property bool drawing: false
  property string inkTool: "pen"
  property string inkColor: "#1e4fa3"
  property real inkWidth: 2.2

  // Opens a notebook (already read from disk, with its pages) at a page.
  function show(notebook, index) {
    commit()
    nb = notebook
    var at = typeof index === "number" ? index : -1
    if (at < 0 && notebook.lastPage) {
      for (var i = 0; i < notebook.pages.length; i++) if (notebook.pages[i].id === notebook.lastPage) at = i
    }
    // Where you left off, else the first page.
    loadPage(Math.max(0, Math.min(notebook.pages.length - 1, at < 0 ? 0 : at)))
  }

  function loadPage(index) {
    pageIndex = index
    if (drawing && sheet.ink.strokes !== undefined) sheet.ink.redoStack = []
    var p = page
    if (!p) return
    sheet.editor.load(p.blocks)
    sheet.ink.load(p.ink || [])
    sheet.setTitle(p.title || "")
    sheet.scrollToTop()
    pageDirty = false
    findBar.refresh()
    if (nb.lastPage !== p.id) {
      nb.lastPage = p.id
      store.touchNotebook(nb.id, { lastPage: p.id })
    }
    revision++
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

  // Writes the page you're on, if it changed.
  function commit() {
    saveTimer.stop()
    if (!pageDirty || !page || !nb) return
    pageDirty = false
    var p = page
    p.blocks = sheet.editor.serialize()
    p.ink = sheet.ink.strokes
    p.title = Library.cleanTitle(sheet.titleField.text)
    p.modified = new Date().toISOString()
    p.text = Blocks.plainText(p.blocks)
    store.savePage(nb.id, p)
    revision++
  }

  // A page just made from a template: the cursor goes to its first line.
  property string freshPage: ""

  function focusWriting() {
    if (!page) return
    var fresh = freshPage === page.id
    freshPage = ""
    if (Blocks.isBlank(page.blocks) && !sheet.titleField.text) sheet.titleField.forceActiveFocus()
    else if (fresh && page.template && !sheet.titleField.text) sheet.titleField.forceActiveFocus()
    else if (fresh) sheet.editor.focusFirstEmpty()
    else if (sheet.editor.focusUid && sheet.editor.items[sheet.editor.focusUid]) sheet.editor.focusBlock(sheet.editor.focusUid, -1)
    else sheet.editor.focusEnd()
  }

  function summaries() {
    var r = revision
    if (!nb) return []
    return nb.pages.map(function(p) { return Library.summary(p) })
  }

  // ---- turning pages -------------------------------------------------------------------

  property bool turning: false
  property var pendingTurn: null
  property int waitFrames: 0

  function next() {
    if (!nb || busy) return
    // What was just typed counts: a page isn't blank because it isn't saved yet.
    commit()
    if (pageIndex < pageCount - 1) turnTo(pageIndex + 1)
    else if (!(page && Blocks.isBlank(page.blocks) && !page.title)) newPage(pageIndex + 1)
  }

  function previous() {
    if (!nb || busy || pageIndex <= 0) return
    turnTo(pageIndex - 1)
  }

  // Turns to a page: forwards, the page you're on turns over the binding and
  // shows the next one under it; backwards, the earlier page turns back over
  // it. Both start from a picture of the page you're on.
  function turnTo(index) {
    if (!nb || index === pageIndex || index < 0 || index >= pageCount || busy) return
    commit()
    var forward = index > pageIndex
    if (reduceMotion) {
      fade.target = index
      fade.restart()
      return
    }
    soundRequested("page")
    snap.sourceItem = sheet
    snap.scheduleUpdate()
    pendingTurn = { index: index, forward: forward }
    waitFrames = 2
    turning = true
  }

  Connections {
    target: view.Window.window
    enabled: view.pendingTurn !== null
    function onFrameSwapped() {
      if (!view.pendingTurn) return
      view.waitFrames -= 1
      if (view.waitFrames > 0) return
      var t = view.pendingTurn
      view.pendingTurn = null
      view.loadPage(t.index)
      if (t.forward) {
        turnLeaf.visible = true
        turnAnim.from = 0
        turnAnim.to = -180
        turnAnim.target = turnLeaf
        turnAnim.restart()
      } else {
        underLeaf.visible = true
        liveLeaf.angle = -180
        turnAnim.from = -180
        turnAnim.to = 0
        turnAnim.target = liveLeaf
        turnAnim.restart()
      }
    }
  }

  NumberAnimation {
    id: turnAnim
    property: "angle"
    duration: 620
    easing.type: Easing.InOutCubic
    onFinished: {
      turnLeaf.visible = false
      turnLeaf.angle = 0
      underLeaf.visible = false
      liveLeaf.angle = 0
      snap.sourceItem = null
      view.turning = false
      view.focusWriting()
    }
  }

  // Without the motion: a quick fade.
  SequentialAnimation {
    id: fade
    property int target: 0
    NumberAnimation { target: liveLeaf; property: "opacity"; to: 0; duration: 90 }
    ScriptAction { script: view.loadPage(fade.target) }
    NumberAnimation { target: liveLeaf; property: "opacity"; to: 1; duration: 120 }
    ScriptAction { script: view.focusWriting() }
  }

  // A new page at an index: `kind` of page (a template's id), or the kind
  // this notebook makes.
  function newPage(at, kind) {
    if (!nb) return
    commit()
    var index = typeof at === "number" ? at : pageIndex + 1
    var p = store.createPage(nb.id, index, pageOptions(typeof kind === "string" ? kind : nb.template, index))
    if (!p) return
    nb.pages.splice(index, 0, p)
    freshPage = p.id
    revision++
    if (index === pageIndex) { loadPage(index); focusWriting() }
    else turnTo(index)
  }

  // ---- templates -------------------------------------------------------------------------

  // Dates in titles and headings, in your language.
  function formatDay(d, pattern) { return Qt.formatDate(Templates.parse(d), pattern) }

  // A page of a template for a date.
  function templatePage(kind, day) {
    return Templates.build(kind, day, formatDay)
  }

  // What a new page at `index` starts as: a page of `kind`, dated after the
  // last page of that kind before it (a planner's next day, week or month).
  function pageOptions(kind, index) {
    if (!kind || kind === "blank" || !Templates.isTemplate(kind)) return {}
    var last = ""
    for (var i = Math.min(index, pageCount) - 1; i >= 0 && !last; i--) {
      if (nb.pages[i].template === kind && nb.pages[i].day) last = nb.pages[i].day
    }
    return templatePage(kind, Templates.nextDay(kind, last, Templates.iso(new Date())))
  }

  // Nothing written, drawn or titled on it yet.
  function isEmptyPage(p) {
    var r = revision
    return !!p && !p.title && !(p.ink && p.ink.length) && Blocks.isBlank(p.blocks)
  }

  // A page from a template: on the page you're on while it's still blank,
  // else a new one after it.
  function addTemplatePage(kind) {
    if (!nb || !page || busy) return
    commit()
    if (!isEmptyPage(page)) {
      newPage(pageIndex + 1, kind)
      return
    }
    var o = pageOptions(kind, pageIndex)
    page.template = o.template || ""
    page.day = o.day || ""
    page.title = o.title || ""
    page.blocks = Blocks.cleanList(o.blocks || [])
    page.text = Blocks.plainText(page.blocks)
    page.modified = new Date().toISOString()
    store.savePage(nb.id, page)
    loadPage(pageIndex)
    freshPage = page.id
    focusWriting()
  }

  function openTemplates() {
    if (nb) templatePop.openAt(plusButton)
  }

  // The date written at the top of a page: the day it's for (a planner's),
  // else the day it was started; none while its title is that date.
  function dateLabel(p) {
    if (!p) return ""
    if (!p.day) return Qt.formatDate(new Date(p.created), "ddd d MMM yyyy")
    var t = Templates.byId(p.template)
    if (t.dateTitle && p.title === Templates.titleFor(p.template, p.day, formatDay)) return ""
    var d = Templates.parse(p.day)
    if (t.date === "week") return Qt.formatDate(d, "d MMM") + " \u2013 " + Qt.formatDate(Templates.parse(Templates.addDays(p.day, 6)), "d MMM yyyy")
    if (t.date === "month") return Qt.formatDate(d, "MMMM yyyy")
    return Qt.formatDate(d, "ddd d MMM yyyy")
  }

  // The faint title of a page with none: what its template calls it, or its first line.
  function titleHint(p) {
    if (!p) return "Untitled"
    if (p.template) return Templates.titleHint(p.template)
    return Blocks.firstLine(p.blocks || [], 40) || "Untitled"
  }

  function deletePage(index) {
    if (!nb || index < 0 || index >= pageCount) return
    commit()
    var p = nb.pages[index]
    if (pageCount === 1) {
      // The last page is never torn out: it's wiped clean.
      p.blocks = Blocks.cleanList([])
      p.title = ""
      p.tab = null
      p.template = ""
      p.day = ""
      p.text = ""
      p.modified = new Date().toISOString()
      store.savePage(nb.id, p)
      loadPage(0)
      return
    }
    store.deletePage(nb.id, p.id)
    nb.pages.splice(index, 1)
    revision++
    loadPage(Math.min(index, nb.pages.length - 1))
    toast("Page moved to the trash")
  }

  function movePage(from, to) {
    if (!nb || from === to || from < 0 || to < 0 || from >= pageCount || to >= pageCount) return
    commit()
    var p = nb.pages.splice(from, 1)[0]
    nb.pages.splice(to, 0, p)
    store.orderPages(nb.id, nb.pages.map(function(x) { return x.id }))
    if (pageIndex === from) pageIndex = to
    else if (from < pageIndex && to >= pageIndex) pageIndex -= 1
    else if (from > pageIndex && to <= pageIndex) pageIndex += 1
    revision++
  }

  function setPaper(choice, wholeNotebook) {
    if (!nb || !page) return
    commit()
    if (wholeNotebook) {
      nb.paper = choice
      nb.pages.forEach(function(p) {
        if (p.paper) { p.paper = null; if (p !== page) store.savePage(nb.id, p) }
      })
      store.touchNotebook(nb.id, { paper: choice })
      page.paper = null
    } else {
      page.paper = choice
    }
    pageDirty = true
    commit()
    loadPage(pageIndex)
  }

  function setTab(tab) {
    if (!page) return
    page.tab = tab
    pageDirty = true
    commit()
    revision++
  }

  // The paper picker, from the ⋯ menu at the top ("top") or the bar below.
  function openPaperPicker(from) {
    if (from === "top") paperPop.openAt(moreButton)
    else formatBar.openPaper()
  }

  function findText(query) {
    findBar.openWith(query)
  }

  // After the notebook itself changed (its cover, paper or pen).
  function refreshNotebook() {
    var n = nb
    nb = null
    nb = n
    loadPage(pageIndex)
  }

  // Out come the pens (the writing waits), or back to writing.
  function sheetInk() { return sheet.ink }

  function setDrawing(on) {
    drawing = on
    if (on) view.forceActiveFocus()
    else focusWriting()
  }

  function copyMarkdown() {
    commit()
    if (!page) return
    store.copyText(Markdown.fromPage(page, ""))
    toast("Copied the page as Markdown")
  }

  function insertDate() {
    var item = sheet.editor.items[sheet.editor.focusUid]
    if (!item || !item.edit) return
    var text = Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
    sheet.editor.beginOp()
    item.edit.remove(item.edit.selectionStart, item.edit.selectionEnd)
    var at = item.edit.cursorPosition
    item.edit.insert(at, text.replace(/&/g, "&amp;").replace(/</g, "&lt;"))
    sheet.editor.syncBlock(item.uid)
    sheet.editor.endOp()
    item.edit.forceActiveFocus()
    item.edit.cursorPosition = at + text.length
  }

  // ---- the cover --------------------------------------------------------------------------

  // 0: shut on the pages; -168: open, out of the way to the left.
  property real coverAngle: -168
  property bool closing: false
  // The bars fade in while the notebook opens (set by the app).
  property real chromeOpacity: 1

  signal coverShut()

  // Swings the cover open (the notebook was just put down on the desk).
  function openCover() {
    shutAnim.stop()
    closing = false
    if (reduceMotion) {
      coverAngle = -168
      focusWriting()
      return
    }
    coverAngle = 0
    openAnim.restart()
    soundRequested("open")
  }

  // Swings it shut, then coverShut(): the app puts the notebook back.
  function shutCover() {
    commit()
    if (reduceMotion) { coverShut(); return }
    openAnim.stop()
    closing = true
    shutAnim.restart()
    soundRequested("close")
  }

  // Where the notebook lies, in another item's coordinates.
  function bookRect(target) {
    return book.mapToItem(target, 0, 0, book.width, book.height)
  }

  SequentialAnimation {
    id: openAnim
    PauseAnimation { duration: 60 }
    NumberAnimation { target: view; property: "coverAngle"; to: -168; duration: 860; easing.type: Easing.InOutCubic }
    ScriptAction { script: view.focusWriting() }
  }

  SequentialAnimation {
    id: shutAnim
    NumberAnimation { target: view; property: "coverAngle"; to: 0; duration: 600; easing.type: Easing.InOutCubic }
    ScriptAction { script: { view.closing = false; view.coverShut() } }
  }

  // ---- the notebook ---------------------------------------------------------------------------

  Item {
    id: stage
    anchors.fill: parent
    anchors.topMargin: view.topBarH
    anchors.bottomMargin: view.bottomBarH

    Item {
      id: book
      width: view.sheetW + view.coverPad * 2
      height: view.sheetH + view.coverPad * 2
      x: (stage.width - width) / 2 + (view.spineOut - view.tabsOut) / 2
      y: (stage.height - height) / 2
      scale: view.zoom
      transformOrigin: Item.Center

      // The back cover, with the desk's shadow under it.
      Cover {
        id: backCover
        anchors.fill: parent
        look: view.coverLook
        title: ""
        bare: true
        binding: view.binding
        layer.enabled: true
        layer.effect: MultiEffect {
          shadowEnabled: true
          shadowColor: view.theme.shadow
          shadowBlur: 1.0
          shadowVerticalOffset: 14
          shadowHorizontalOffset: 3
          shadowScale: 1.01
          autoPaddingEnabled: true
        }
      }

      // The pages under this one, their edges showing at the right and bottom.
      Repeater {
        model: Math.min(4, Math.max(1, view.pageCount - view.pageIndex))
        delegate: Rectangle {
          required property int index
          readonly property int depth: Math.min(4, Math.max(1, view.pageCount - view.pageIndex)) - index
          x: view.coverPad + depth * 1.6
          y: view.coverPad + depth * 1.4
          width: view.sheetW
          height: view.sheetH
          radius: 2
          color: Papers.mix(view.look.paper, view.look.dark ? "#000000" : "#8a7a5a", 0.07 + depth * 0.03)
          border.width: 1
          border.color: Qt.rgba(0, 0, 0, 0.08)
        }
      }

      Item {
        id: pageArea
        x: view.coverPad
        y: view.coverPad
        width: view.sheetW
        height: view.sheetH

        // A picture of the page you're on, taken just before a page turns. It
        // stays behind the page (a source only draws while it's shown), lies
        // under an earlier page turning back over it, and is what turns away
        // when you go forward.
        ShaderEffectSource {
          id: snap
          anchors.fill: parent
          live: false
          hideSource: false
        }
        Item { id: underLeaf; visible: false }

        // The page you're on (and, turning back, the page coming over).
        Item {
          id: liveLeaf
          property real angle: 0
          anchors.fill: parent
          transform: Rotation {
            origin.x: 0
            origin.y: liveLeaf.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: liveLeaf.angle
            distanceToPlane: 3000
          }

          PageSheet {
            id: sheet
            anchors.fill: parent
            look: view.look
            pen: view.pen
            spacing: view.look.spacing
            family: view.penFamily
            monoFamily: view.theme.monoFont
            uiFamily: view.theme.uiFont
            accent: view.theme.accent
            strikeDone: view.settings.strikeDone !== false
            scrollSpeed: view.settings.scrollSpeed || "normal"
            leftGutter: view.leftGutter
            // The page changes in place (a template on a blank page): `revision` says so.
            dateText: { var r = view.revision; return view.dateLabel(view.page) }
            pageNumber: view.pageIndex + 1
            placeholder: { var r = view.revision; return view.titleHint(view.page) }
            assetUrl: function(src) { return view.store.assetUrl(view.nb ? view.nb.id : "", src) }
            drawing: view.drawing
            ink.tool: view.inkTool
            ink.color: view.inkColor
            ink.penWidth: view.inkWidth
            ink.onChanged: view.markDirty()
            onTitleEdited: function(text) { view.markDirty() }
            onPicturesDropped: function(urls) { view.dropPictures(urls) }
            editor.onChanged: view.markDirty()
            editor.onLinkOpened: function(url) { view.store.openUrl(url) }
            editor.onPictureOpened: function(src) { view.store.openUrl(view.store.assetUrl(view.nb.id, src)) }
            editor.onPastePicture: function(afterUid) { view.pastePicture(afterUid) }
            editor.onLinkRequested: linkPop.openAt(formatBar)
          }

          // The back of the page, as it passes the binding.
          Paper {
            anchors.fill: parent
            visible: liveLeaf.angle < -90
            look: view.backLook
            originY: sheet.bodyTop
            marginLine: view.sheetW - sheet.marginLine
            gridOrigin: sheet.textLeft
          }
          // Light falling on it as it turns.
          Rectangle {
            anchors.fill: parent
            visible: liveLeaf.angle !== 0
            opacity: Math.abs(Math.sin(liveLeaf.angle * Math.PI / 180)) * 0.5
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
              GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.1) }
              GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.1) }
            }
          }
        }

        // The page you were on, turning over the binding.
        Item {
          id: turnLeaf
          property real angle: 0
          anchors.fill: parent
          visible: false
          transform: Rotation {
            origin.x: 0
            origin.y: turnLeaf.height / 2
            axis { x: 0; y: 1; z: 0 }
            angle: turnLeaf.angle
            distanceToPlane: 3000
          }
          ShaderEffect {
            anchors.fill: parent
            visible: turnLeaf.angle > -90
            property variant source: snap
          }
          Paper {
            anchors.fill: parent
            visible: turnLeaf.angle <= -90
            look: view.backLook
            originY: sheet.bodyTop
            marginLine: view.sheetW - sheet.marginLine
            gridOrigin: sheet.textLeft
          }
          Rectangle {
            anchors.fill: parent
            opacity: Math.abs(Math.sin(turnLeaf.angle * Math.PI / 180)) * 0.55
            gradient: Gradient {
              orientation: Gradient.Horizontal
              GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.55) }
              GradientStop { position: 0.6; color: Qt.rgba(0, 0, 0, 0.12) }
              GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.12) }
            }
          }
        }

        // The shadow a turning page casts on the one under it.
        Rectangle {
          visible: view.turning
          readonly property real a: turnLeaf.visible ? turnLeaf.angle : liveLeaf.angle
          readonly property real reach: Math.max(0, Math.cos(a * Math.PI / 180)) * pageArea.width
          x: reach
          width: Math.min(120, pageArea.width * 0.2) * Math.abs(Math.sin(a * Math.PI / 180))
          height: parent.height
          opacity: Math.abs(Math.sin(a * Math.PI / 180))
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.28) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0) }
          }
        }

        // The corner of the page, turning up when the pointer comes near.
        Item {
          id: corner
          width: 70
          height: 70
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          visible: !view.turning && !view.closing
          property real fold: cornerHover.hovered ? 30 : 0
          Behavior on fold { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

          HoverHandler { id: cornerHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: view.next() }

          Shape {
            anchors.fill: parent
            visible: corner.fold > 0.5
            preferredRendererType: Shape.CurveRenderer
            // The page underneath, where the corner lifted off.
            ShapePath {
              strokeWidth: 0
              strokeColor: "transparent"
              fillColor: Papers.mix(view.look.paper, "#000000", view.look.dark ? 0.25 : 0.1)
              startX: corner.width - corner.fold; startY: corner.height
              PathLine { x: corner.width; y: corner.height - corner.fold }
              PathLine { x: corner.width; y: corner.height }
              PathLine { x: corner.width - corner.fold; y: corner.height }
            }
            // The corner, folded back.
            ShapePath {
              strokeWidth: 1
              strokeColor: Qt.rgba(0, 0, 0, 0.12)
              fillGradient: LinearGradient {
                x1: corner.width - corner.fold; y1: corner.height - corner.fold
                x2: corner.width - corner.fold * 0.5; y2: corner.height - corner.fold * 0.5
                GradientStop { position: 0; color: view.look.back }
                GradientStop { position: 1; color: Papers.mix(view.look.back, "#000000", 0.14) }
              }
              startX: corner.width - corner.fold; startY: corner.height
              PathLine { x: corner.width; y: corner.height - corner.fold }
              PathLine { x: corner.width - corner.fold; y: corner.height - corner.fold }
              PathLine { x: corner.width - corner.fold; y: corner.height }
            }
          }
        }
      }

      Spine {
        id: spine
        // A spiral wraps around the cover too; a fold lies under it.
        z: view.binding === "spiral" ? 3 : 0
        x: view.coverPad - 16
        y: view.coverPad
        width: 60
        height: view.sheetH
        edge: 16
        binding: view.binding
        dark: view.look.dark === true
      }

      // Index tabs on the pages that have one.
      Repeater {
        id: tabs
        model: {
          var r = view.revision
          var out = []
          if (view.nb) view.nb.pages.forEach(function(p, i) { if (p.tab) out.push({ index: i, color: p.tab.color, label: p.tab.label || "" }) })
          return out
        }
        delegate: Item {
          required property var modelData
          required property int index
          readonly property real slot: Math.min(78, (view.sheetH - 40) / Math.max(1, tabs.count))
          x: book.width - 6
          y: view.coverPad + 26 + index * slot
          width: 34
          height: slot - 8
          z: -1
          Rectangle {
            anchors.fill: parent
            radius: 6
            color: modelData.color
            opacity: modelData.index === view.pageIndex ? 1 : 0.82
            border.width: 1
            border.color: Qt.darker(modelData.color, 1.2)
            Text {
              textFormat: Text.PlainText
              anchors.centerIn: parent
              anchors.horizontalCenterOffset: 3
              rotation: 90
              width: parent.height - 10
              horizontalAlignment: Text.AlignHCenter
              text: modelData.label
              elide: Text.ElideRight
              font.family: view.theme.printFont
              font.pixelSize: 13
              color: Papers.readable(String(modelData.color), "#1b1c1f", "#f6f3ec")
            }
          }
          HoverHandler { cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: view.turnTo(modelData.index) }
        }
      }

      // The front cover, swinging open (and shut).
      Item {
        id: frontCover
        z: 2
        anchors.fill: parent
        visible: view.coverAngle > -167.5
        transform: Rotation {
          origin.x: 0
          origin.y: frontCover.height / 2
          axis { x: 0; y: 1; z: 0 }
          angle: view.coverAngle
          distanceToPlane: 2600
        }
        Cover {
          anchors.fill: parent
          visible: view.coverAngle > -90
          look: view.coverLook
          title: view.nb ? view.nb.title : ""
          binding: view.binding
          fonts: view.theme.coverFonts
          pages: view.pageCount
        }
        Cover {
          anchors.fill: parent
          visible: view.coverAngle <= -90
          look: view.coverLook
          inside: true
          binding: view.binding
        }
        Rectangle {
          anchors.fill: parent
          radius: 8
          opacity: Math.abs(Math.sin(view.coverAngle * Math.PI / 180)) * 0.45
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: Qt.rgba(0, 0, 0, 0.5) }
            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.05) }
          }
        }
      }
    }
  }

  // ---- the bar above -------------------------------------------------------------------------

  Item {
    id: topBar
    anchors.left: parent.left
    anchors.right: parent.right
    height: view.topBarH
    opacity: view.chromeOpacity

    Row {
      anchors.left: parent.left
      anchors.leftMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6
      IconButton {
        theme: view.theme
        icon: view.theme.icons.shelf
        label: "Notebooks"
        tip: "Back to the shelf  Ctrl+W"
        onClicked: view.closed()
      }
      Rectangle { width: 1; height: 22; color: view.theme.line; anchors.verticalCenter: parent.verticalCenter }
      IconButton {
        theme: view.theme
        label: view.nb ? view.nb.title : ""
        tip: "Cover, paper and pen"
        onClicked: view.editRequested()
      }
    }

    Row {
      anchors.centerIn: parent
      spacing: 4
      IconButton {
        theme: view.theme; icon: view.theme.icons.left; tip: "Previous page  Ctrl+PgUp"
        active: view.pageIndex > 0
        onClicked: view.previous()
      }
      IconButton {
        id: pageButton
        theme: view.theme
        label: "Page " + (view.pageIndex + 1) + " of " + view.pageCount
        tip: "All pages  Ctrl+G"
        onClicked: pagesPop.open()
        PagesPop {
          id: pagesPop
          theme: view.theme
          view: view
          x: (pageButton.width - width) / 2
          y: pageButton.height + 8
        }
      }
      IconButton {
        theme: view.theme; icon: view.theme.icons.right; tip: view.pageIndex < view.pageCount - 1 ? "Next page  Ctrl+PgDown" : "New page  Ctrl+PgDown"
        onClicked: view.next()
      }
    }

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 14
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      IconButton { theme: view.theme; icon: view.theme.icons.search; tip: "Find on this page  Ctrl+F"; checked: findBar.shown; onClicked: findBar.toggle() }
      IconButton {
        id: plusButton
        theme: view.theme; icon: view.theme.icons.plus; tip: "New page, from a template  Ctrl+T"
        checked: templatePop.opened
        onClicked: view.openTemplates()
      }
      IconButton {
        id: moreButton
        theme: view.theme; icon: view.theme.icons.more; tip: "More"
        onClicked: moreMenu.open()
        Pop {
          id: moreMenu
          theme: view.theme
          focus: false
          x: moreButton.width - width
          y: moreButton.height + 8
          contentItem: Column {
            spacing: 2
            MenuRow { theme: view.theme; icon: view.theme.icons.paper; text: "Paper\u2026"; onClicked: { moreMenu.close(); paperPop.openAt(moreButton) } }
            MenuRow { theme: view.theme; icon: view.theme.icons.tag; text: view.page && view.page.tab ? "Change tab\u2026" : "Add a tab\u2026"; onClicked: { moreMenu.close(); tabPop.open() } }
            MenuRow { theme: view.theme; icon: view.theme.icons.copy; text: "Copy page as Markdown"; onClicked: { moreMenu.close(); view.copyMarkdown() } }
            MenuRow { theme: view.theme; icon: view.theme.icons.export; text: "Export notebook\u2026"; onClicked: { moreMenu.close(); view.commit(); view.store.exportNotebook(view.nb.id) } }
            MenuRow { theme: view.theme; icon: view.theme.icons.cog; text: "Cover, paper and pen\u2026"; onClicked: { moreMenu.close(); view.editRequested() } }
            Rectangle { width: parent.width; height: 1; color: view.theme.line }
            MenuRow { theme: view.theme; icon: view.theme.icons.trash; text: view.pageCount > 1 ? "Tear out this page" : "Clear this page"; danger: true; onClicked: { moreMenu.close(); view.deletePage(view.pageIndex) } }
          }
        }
      }
    }
  }

  // Find on this page.
  FindBar {
    id: findBar
    theme: view.theme
    editor: sheet.editor
    anchors.horizontalCenter: parent.horizontalCenter
    y: view.topBarH + 6
    z: 5
    onDone: view.focusWriting()
  }

  // ---- the bar below -----------------------------------------------------------------------

  FormatBar {
    id: formatBar
    theme: view.theme
    editor: sheet.editor
    dark: view.look.dark === true
    pen: view.pen
    spacing: view.look.spacing
    width: parent.width - 40
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 14
    opacity: view.chromeOpacity
    drawing: view.drawing
    inkTool: view.inkTool
    inkColor: view.inkColor
    inkWidth: view.inkWidth
    ink: sheet.ink
    onDrawingRequested: function(on) { view.setDrawing(on) }
    onInkToolPicked: function(tool) { view.inkTool = tool }
    onInkColorPicked: function(color) { view.inkColor = color; if (view.inkTool === "eraser") view.inkTool = "pen" }
    onInkWidthPicked: function(width) { view.inkWidth = width }
    onPaperRequested: function(anchor) { paperPop.openAt(anchor) }
    onLinkRequested: function(anchor) { linkPop.openAt(anchor) }
    onPictureRequested: view.pictureFileRequested(sheet.editor.focusUid)
    onDateRequested: view.insertDate()
  }

  PaperPop {
    id: paperPop
    theme: view.theme
    view: view
  }

  TemplatePop {
    id: templatePop
    theme: view.theme
    view: view
  }

  LinkPop {
    id: linkPop
    theme: view.theme
    editor: sheet.editor
  }

  TabPop {
    id: tabPop
    theme: view.theme
    view: view
    parent: moreButton
    x: moreButton.width - width
    y: moreButton.height + 8
  }

  // ---- pictures -------------------------------------------------------------------------------

  function dropPictures(urls) {
    var after = sheet.editor.focusUid
    for (var i = 0; i < urls.length && i < 12; i++) {
      var path = decodeURIComponent(String(urls[i]).replace(/^file:\/\//, ""))
      if (!Library.isImagePath(path)) continue
      store.importPicture(nb.id, path, function(src) {
        if (src) sheet.editor.insertPicture(after, src, 0)
      })
    }
  }

  function addPicture(path, afterUid) {
    if (!nb || !Library.isImagePath(path)) return
    store.importPicture(nb.id, path, function(src) {
      if (src) sheet.editor.insertPicture(afterUid || sheet.editor.focusUid, src, 0)
    })
  }

  function pastePicture(afterUid) {
    if (!nb) return
    store.pastePicture(nb.id, function(src) {
      if (src) sheet.editor.insertPicture(afterUid, src, 0)
    })
  }

  // ---- keys that belong to the notebook -----------------------------------------------------

  Keys.onPressed: function(e) { if (view.handleKey(e)) e.accepted = true }

  function handleKey(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    if (drawing) {
      if (ctrl && !alt && e.key === Qt.Key_Z) { if (shift) sheet.ink.redo(); else sheet.ink.undo(); return true }
      if (ctrl && !alt && e.key === Qt.Key_Y) { sheet.ink.redo(); return true }
      if (e.key === Qt.Key_Escape) { setDrawing(false); return true }
      if (!ctrl && !alt && e.key === Qt.Key_P) { inkTool = "pen"; return true }
      if (!ctrl && !alt && e.key === Qt.Key_M) { inkTool = "marker"; return true }
      if (!ctrl && !alt && e.key === Qt.Key_E) { inkTool = "eraser"; return true }
    }
    if (ctrl && shift && !alt && e.key === Qt.Key_D) { setDrawing(!drawing); return true }
    if (ctrl && !alt && e.key === Qt.Key_PageDown) { view.next(); return true }
    if (ctrl && !alt && e.key === Qt.Key_PageUp) { view.previous(); return true }
    if (alt && !ctrl && e.key === Qt.Key_Right) { view.next(); return true }
    if (alt && !ctrl && e.key === Qt.Key_Left) { view.previous(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_N) { view.newPage(view.pageIndex + 1); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_T) { view.openTemplates(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_F) { findBar.open(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_G) { pagesPop.open(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_W) { view.closed(); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_K) { linkPop.openAt(formatBar); return true }
    if (ctrl && !shift && !alt && e.key === Qt.Key_Semicolon) { view.insertDate(); return true }
    return false
  }
}
