import QtQuick
import QtQuick.Shapes
import QtMultimedia
import "../Papers.js" as Papers
import "../Covers.js" as Covers
import "../Blocks.js" as Blocks

// Omanote: a desk with your notebooks on it. The shelf shows them cover up;
// pick one and it slides onto the desk and its cover swings open. Or Pages:
// a workspace of pages made of blocks, the way Notion does it (DocView.qml).
//
// Everything on disk goes through `store` (Store.qml in the Omarchy shell,
// or a stand-in for the dev harness) and `workspace` (Workspace.qml), and
// settings through `service`.
FocusScope {
  id: root

  property var store: null
  property var workspace: null
  property var service: null
  readonly property var settings: service && service.settings ? service.settings : ({})

  // The Omarchy theme's colors.
  property color background: "#1a1b26"
  property color foreground: "#c0caf5"
  property color accent: "#7aa2f7"
  property color urgent: "#f7768e"

  readonly property bool reduceMotion: settings.reduceMotion === true
  readonly property alias theme: themeObject
  readonly property alias notebookView: view
  readonly property alias shelfView: shelf
  readonly property alias docView: docs
  property string mode: "shelf"
  // "notebooks" (the shelf and the desk) or "pages".
  property string space: "notebooks"
  Component.onCompleted: space = settings.space === "pages" ? "pages" : "notebooks"

  // Pages, or back to the notebooks.
  function showSpace(next) {
    if (next === space) return
    if (space === "pages") docs.commit()
    else if (mode === "notebook") view.commit()
    space = next
    if (service) service.setSetting("space", next)
    if (next === "pages") docs.activate()
    else root.forceActiveFocus()
  }

  // Esc on the shelf: put Omanote away.
  signal hideRequested()

  Theme {
    id: themeObject
    background: root.background
    foreground: root.foreground
    accent: root.accent
    urgent: root.urgent
  }

  // The fonts Omanote brings with it (the notebook window loads them once
  // for itself and the quick note, and turns this off).
  property bool loadFonts: true
  property int fontsLoaded: 0
  onFontsLoadedChanged: themeObject.fontsVersion++

  Loader {
    active: root.loadFonts
    sourceComponent: Fonts { onLoadedChanged: root.fontsLoaded = loaded }
  }

  // ---- the desk ------------------------------------------------------------------------

  Paper {
    anchors.fill: parent
    look: ({ paper: String(themeObject.desk), shader: 0, grain: themeObject.dark ? 0.9 : 0.6, fiber: 0, pitch: 30, hasMargin: false, headRule: false, line: "#000000", lineAlpha: 0 })
  }

  // Light pooling in the middle of the desk.
  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillGradient: RadialGradient {
        centerX: root.width / 2; centerY: root.height * 0.42
        centerRadius: Math.max(root.width, root.height) * 0.75
        focalX: centerX; focalY: centerY
        GradientStop { position: 0.0; color: Qt.alpha(themeObject.foreground, themeObject.dark ? 0.05 : 0.04) }
        GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, themeObject.dark ? 0.28 : 0.1) }
      }
      startX: 0; startY: 0
      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: 0; y: 0 }
    }
  }

  // ---- the shelf -------------------------------------------------------------------------

  Shelf {
    id: shelf
    anchors.fill: parent
    theme: themeObject
    store: root.store
    visible: opacity > 0 && root.space === "notebooks"
    enabled: root.mode === "shelf"
    onSpaceRequested: function(next) { root.showSpace(next) }
    onOpenRequested: function(notebook, from) { root.openNotebook(notebook, from, "", "") }
    onNewRequested: root.newNotebook()
    onEditRequested: function(notebook) { notebookDialog.defaults = root.settings; notebookDialog.start(notebook) }
    onDeleteRequested: function(notebook) { root.askDelete(notebook) }
    onSettingsRequested: settingsPanel.open()
    onResultOpened: function(notebookId, pageId, query) {
      var meta = null
      root.store.notebooks.forEach(function(n) { if (n.id === notebookId) meta = n })
      if (meta) root.openNotebook(meta, shelf.coverRect(notebookId, root), pageId, query)
    }
  }

  // ---- the open notebook -----------------------------------------------------------------

  NotebookView {
    id: view
    anchors.fill: parent
    theme: themeObject
    store: root.store
    settings: root.settings
    reduceMotion: root.reduceMotion
    zoom: (root.settings.zoom || 100) / 100
    visible: root.space === "notebooks" && (root.mode === "notebook" || flyAnim.running || flyBack.running)
    enabled: root.mode === "notebook" && root.space === "notebooks"
    onClosed: root.closeNotebook()
    onCoverShut: root.flyToShelf()
    onEditRequested: { notebookDialog.defaults = root.settings; notebookDialog.start(view.nb) }
    onSoundRequested: function(name) { root.play(name) }
    onToast: function(text) { root.toast(text) }
    onPictureFileRequested: function(afterUid) { root.pickPicture(afterUid) }
  }

  // ---- Pages ------------------------------------------------------------------------------

  DocView {
    id: docs
    anchors.fill: parent
    theme: themeObject
    workspace: root.workspace
    service: root.service
    visible: root.space === "pages"
    enabled: visible
    focus: visible
    onNotebooksRequested: root.showSpace("notebooks")
    onSettingsRequested: settingsPanel.open()
    onToast: function(text) { root.toast(text) }
    onPictureRequested: function(done) { if (root.service) root.service.pickPicture(done); else done("") }
    onConfirmRequested: function(title, text, action, confirmed) { confirm.ask(title, text, action, confirmed) }
    onImportRequested: function(folder) {
      if (root.service) root.service.pickImport(folder, function(paths) { if (paths.length) docs.importPaths(paths, "") })
    }
  }

  // The cover, flying between the shelf and the desk.
  Cover {
    id: flyer
    visible: false
    closed: true
    fonts: themeObject.coverFonts
  }

  ParallelAnimation {
    id: flyAnim
    NumberAnimation { id: flyX; target: flyer; property: "x"; duration: 380; easing.type: Easing.OutCubic }
    NumberAnimation { id: flyY; target: flyer; property: "y"; duration: 380; easing.type: Easing.OutCubic }
    NumberAnimation { id: flyW; target: flyer; property: "width"; duration: 380; easing.type: Easing.OutCubic }
    NumberAnimation { id: flyH; target: flyer; property: "height"; duration: 380; easing.type: Easing.OutCubic }
    NumberAnimation { target: shelf; property: "opacity"; to: 0; duration: 260 }
    onFinished: {
      view.opacity = 1
      flyer.visible = false
      view.openCover()
      chromeIn.restart()
    }
  }

  NumberAnimation { id: chromeIn; target: view; property: "chromeOpacity"; from: 0; to: 1; duration: 420; easing.type: Easing.OutCubic }

  ParallelAnimation {
    id: flyBack
    NumberAnimation { id: backX; target: flyer; property: "x"; duration: 360; easing.type: Easing.InOutCubic }
    NumberAnimation { id: backY; target: flyer; property: "y"; duration: 360; easing.type: Easing.InOutCubic }
    NumberAnimation { id: backW; target: flyer; property: "width"; duration: 360; easing.type: Easing.InOutCubic }
    NumberAnimation { id: backH; target: flyer; property: "height"; duration: 360; easing.type: Easing.InOutCubic }
    NumberAnimation { target: shelf; property: "opacity"; to: 1; duration: 300 }
    onFinished: {
      flyer.visible = false
      root.forceActiveFocus()
    }
  }

  property bool opening: false

  // Takes a notebook off the shelf, and opens it (at a page, finding text).
  function openNotebook(meta, from, pageId, query) {
    if (opening || !meta) return
    opening = true
    store.openNotebook(meta.id, function(nb) {
      opening = false
      if (!nb) { toast("That notebook couldn't be read"); return }
      var index = -1
      if (pageId) nb.pages.forEach(function(p, i) { if (p.id === pageId) index = i })
      view.show(nb, index)
      if (service) service.setSetting("lastNotebook", nb.id)
      root.mode = "notebook"
      if (query) Qt.callLater(function() { view.findText(query) })
      flyIn(from)
    })
  }

  function flyIn(from) {
    view.coverAngle = 0
    // No flight from a shelf that hasn't been laid out yet.
    if (reduceMotion || !from || from.width <= 0 || (from.x === 0 && from.y === 0)) {
      shelf.opacity = 0
      view.opacity = 1
      view.chromeOpacity = 1
      view.openCover()
      return
    }
    view.chromeOpacity = 0
    view.opacity = 0
    var target = view.bookRect(root)
    flyer.look = view.coverLook
    flyer.title = view.nb.title
    flyer.binding = view.binding
    flyer.pages = view.pageCount
    flyer.x = from.x; flyer.y = from.y; flyer.width = from.width; flyer.height = from.height
    flyX.to = target.x; flyY.to = target.y; flyW.to = target.width; flyH.to = target.height
    flyer.visible = true
    flyAnim.restart()
  }

  function closeNotebook() {
    if (root.mode !== "notebook") return
    view.shutCover()
  }

  // The cover is shut: back it goes to its place on the shelf.
  function flyToShelf() {
    var id = view.nb ? view.nb.id : ""
    var from = view.bookRect(root)
    root.mode = "shelf"
    if (service) service.setSetting("lastNotebook", "")
    var to = shelf.coverRect(id, root)
    if (reduceMotion || to.width <= 0) {
      shelf.opacity = 1
      root.forceActiveFocus()
      return
    }
    flyer.look = view.coverLook
    flyer.title = view.nb ? view.nb.title : ""
    flyer.binding = view.binding
    flyer.x = from.x; flyer.y = from.y; flyer.width = from.width; flyer.height = from.height
    backX.to = to.x; backY.to = to.y; backW.to = to.width; backH.to = to.height
    flyer.visible = true
    flyBack.restart()
  }

  // When the window opens: back where you were.
  function resume() {
    if (root.space === "pages") { docs.activate(); return }
    if (root.mode === "notebook") { view.focusWriting(); return }
    root.forceActiveFocus()
    var last = settings.lastNotebook || ""
    if (!last || !store) return
    store.notebooks.forEach(function(n) {
      if (n.id === last) root.openNotebook(n, shelf.coverRect(n.id, root), "", "")
    })
  }

  // ---- notebooks --------------------------------------------------------------------------

  function openSettings() { settingsPanel.open() }

  function newNotebook() {
    notebookDialog.defaults = root.settings
    notebookDialog.start(null)
  }

  NotebookDialog {
    id: notebookDialog
    theme: themeObject
    parent: root
    onDone: function(choice) {
      if (notebookDialog.target) {
        root.store.updateNotebook(notebookDialog.target.id, choice)
        if (view.nb && view.nb.id === notebookDialog.target.id) {
          view.nb.title = choice.title
          view.nb.cover = choice.cover
          view.nb.binding = choice.binding
          view.nb.paper = choice.paper
          view.nb.pen = choice.pen
          view.nb.template = choice.template
          view.refreshNotebook()
        }
        return
      }
      // The next new notebook starts from this one's choices.
      if (service) {
        service.setSetting("cover", choice.cover.color)
        service.setSetting("material", choice.cover.material)
        service.setSetting("binding", choice.binding)
        service.setSetting("paper", choice.paper.pattern)
        service.setSetting("paperColor", choice.paper.color)
        service.setSetting("spacing", choice.paper.spacing)
        service.setSetting("pen", choice.pen)
      }
      // A notebook of planners (or journal pages...) starts with today's.
      var meta = root.store.createNotebook(choice, choice.template ? [view.templatePage(choice.template, "")] : null)
      if (meta) Qt.callLater(function() { root.openNotebook(meta, shelf.coverRect(meta.id, root), "", "") })
    }
    onDeleteRequested: function(notebook) { root.askDelete(notebook) }
  }

  function askDelete(notebook) {
    confirm.ask("Put \u201c" + notebook.title + "\u201d in the trash?",
      "Its folder moves to the .trash folder inside your notebooks folder, where you can get it back.",
      "Put in the trash",
      function() {
        if (view.nb && view.nb.id === notebook.id && root.mode === "notebook") {
          root.mode = "shelf"
          shelf.opacity = 1
        }
        root.store.deleteNotebook(notebook.id)
        root.toast("\u201c" + notebook.title + "\u201d is in the trash")
      })
  }

  Confirm { id: confirm; theme: themeObject; parent: root }
  SettingsPanel { id: settingsPanel; theme: themeObject; service: root.service; parent: root }

  // A picture from a file, chosen with the desktop's file picker.
  function pickPicture(afterUid) {
    if (!service) return
    service.pickPicture(function(path) { if (path) view.addPicture(path, afterUid) })
  }

  // ---- sounds ------------------------------------------------------------------------------

  SoundEffect { id: pageSound; source: "../sounds/page.wav"; volume: 0.5 }
  SoundEffect { id: openSound; source: "../sounds/open.wav"; volume: 0.55 }
  SoundEffect { id: closeSound; source: "../sounds/close.wav"; volume: 0.55 }

  function play(name) {
    if (settings.sounds === false) return
    if (name === "page") pageSound.play()
    else if (name === "open") openSound.play()
    else if (name === "close") closeSound.play()
  }

  // ---- messages -----------------------------------------------------------------------------

  function toast(text) {
    toastText.text = text
    toastBox.opacity = 1
    toastTimer.restart()
  }

  Rectangle {
    id: toastBox
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 92
    width: toastText.implicitWidth + 36
    height: 38
    radius: 19
    color: themeObject.surfaceHigh
    border.width: 1
    border.color: themeObject.line
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Text {
      textFormat: Text.PlainText
      id: toastText
      anchors.centerIn: parent
      font.family: themeObject.uiFont
      font.pixelSize: 13
      color: themeObject.text
    }
  }
  Timer { id: toastTimer; interval: 2600; onTriggered: toastBox.opacity = 0 }

  Connections {
    target: root.store
    ignoreUnknownSignals: true
    function onFailed(message) { root.toast(message) }
    function onExported(path) { root.toast("Exported to " + path.replace(/^\/home\/[^\/]+/, "~")) }
  }

  // ---- keys -------------------------------------------------------------------------------

  Keys.onPressed: function(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    if (ctrl && !alt && e.key === Qt.Key_Comma) { e.accepted = true; settingsPanel.open(); return }
    if (root.space === "pages") return
    if (ctrl && shift && !alt && e.key === Qt.Key_N) { e.accepted = true; newNotebook(); return }
    if (ctrl && !alt && (e.key === Qt.Key_Equal || e.key === Qt.Key_Plus)) { e.accepted = true; zoomBy(10); return }
    if (ctrl && !alt && e.key === Qt.Key_Minus) { e.accepted = true; zoomBy(-10); return }
    if (ctrl && !alt && !shift && e.key === Qt.Key_0) { e.accepted = true; if (service) service.setSetting("zoom", 100); return }
    if (root.mode === "notebook") return
    if ((ctrl && e.key === Qt.Key_F) || (ctrl && shift && e.key === Qt.Key_F)) { e.accepted = true; shelf.focusSearch(); return }
    if (e.key === Qt.Key_Escape) { e.accepted = true; root.hideRequested(); return }
  }

  function zoomBy(delta) {
    if (!service) return
    var z = Math.max(60, Math.min(200, (settings.zoom || 100) + delta))
    service.setSetting("zoom", z)
  }
}
