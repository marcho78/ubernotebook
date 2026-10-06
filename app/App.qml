import QtQuick
import QtQuick.Shapes
import QtMultimedia
import "../Papers.js" as Papers
import "../Covers.js" as Covers
import "../Blocks.js" as Blocks

// Uber Notebook: a desk with your notebooks on it. The shelf shows them cover up;
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
  readonly property alias settingsPopup: settingsPanel
  readonly property alias releaseNotesPopup: releaseNotes
  property string mode: "shelf"
  // "pages" or "notebooks" (the shelf and the desk).
  property string space: "pages"
  Component.onCompleted: space = settings.space === "notebooks" ? "notebooks" : "pages"

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

  // Esc on the shelf: put Uber Notebook away.
  signal hideRequested()

  Theme {
    id: themeObject
    baseBackground: root.background
    baseForeground: root.foreground
    accent: root.accent
    urgent: root.urgent
    // Settings → Appearance.
    pageColor: root.settings.colorPage || ""
    textColor: root.settings.colorText || ""
    sidebarColor: root.settings.colorSidebar || ""
    cardColor: root.settings.colorCards || ""
  }

  // The fonts Uber Notebook brings with it (the notebook window loads them once
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
    anchors.topMargin: demoStrip.height
    theme: themeObject
    store: root.store
    service: root.service
    visible: opacity > 0 && root.space === "notebooks"
    enabled: root.mode === "shelf"
    onSpaceRequested: function(next) { root.showSpace(next) }
    onOpenRequested: function(notebook, from) { root.openNotebook(notebook, from, "", "") }
    onNewRequested: root.newNotebook()
    onEditRequested: function(notebook) { notebookDialog.defaults = root.settings; notebookDialog.start(notebook) }
    onDeleteRequested: function(notebook) { root.askDelete(notebook) }
    onMoveRequested: function(notebook) { root.askMove(notebook) }
    onSettingsRequested: settingsPanel.open()
    onAboutRequested: settingsPanel.openAt("about")
    onReleaseNotesRequested: releaseNotes.show()
    onResultOpened: function(notebookId, pageId, query) {
      var meta = null
      root.store.notebooks.forEach(function(n) { if (n.id === notebookId) meta = n })
      if (meta) root.openNotebook(meta, shelf.coverRect(notebookId, root), pageId, query)
    }
  }

  // ---- the demo: the way to your own profile, in sight ----------------------------------
  // While the demo's open: what it is, and the welcome screen a click away
  // (your own profile, or a backup put back). Everything else is under it.
  Rectangle {
    id: demoStrip
    objectName: "demoStrip"
    readonly property bool shown: root.service !== null && root.service.profiles !== undefined && root.service.profiles !== null
      && root.service.profiles.inDemo === true && !root.service.profiles.startShown
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    height: shown ? 40 : 0
    visible: shown
    z: 40
    color: themeObject.sidebar
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: themeObject.line }
    Row {
      anchors.centerIn: parent
      spacing: 14
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "You're exploring the demo."
        font.family: themeObject.uiFont
        font.pixelSize: 13
        color: themeObject.muted
      }
      TextButton {
        objectName: "demoStripStart"
        anchors.verticalCenter: parent.verticalCenter
        theme: themeObject
        text: "Make my own profile"
        onClicked: root.service.profiles.openStart()
      }
    }
  }

  // ---- the open notebook -----------------------------------------------------------------

  NotebookView {
    id: view
    anchors.fill: parent
    anchors.topMargin: demoStrip.height
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
    onPictureSaveRequested: function(path, name) { root.savePictureCopy(path, name) }
  }

  // ---- Pages ------------------------------------------------------------------------------

  DocView {
    id: docs
    anchors.fill: parent
    anchors.topMargin: demoStrip.height
    theme: themeObject
    workspace: root.workspace
    service: root.service
    visible: root.space === "pages"
    enabled: visible
    focus: visible
    onNotebooksRequested: root.showSpace("notebooks")
    onSettingsRequested: settingsPanel.open()
    onAboutRequested: settingsPanel.openAt("about")
    onSidebarChoicesRequested: settingsPanel.openAt("appearance", "sidebarChoices")
    onReleaseNotesRequested: releaseNotes.show()
    onToast: function(text) { root.toast(text) }
    onToastUndo: function(text, undo) { root.toastWithUndo(text, undo) }
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

  // Settings, at a section ("" the one it was at).
  function openSettings(section) { if (section) settingsPanel.openAt(section); else settingsPanel.open() }
  function showReleaseNotes(own) { releaseNotes.show(own === true) }

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

  // A notebook into Pages (Workspace.importNotebook): a page called what it
  // is, with a page inside it for each of its pages. Once they're made, the
  // notebook goes in the trash (where it can be got back), unless a picture
  // of it couldn't be copied: then it stays on the shelf too.
  function askMove(notebook) {
    confirm.ask("Move \u201c" + notebook.title + "\u201d to Pages?",
      "It becomes a page in Pages with a page inside it for each of its pages: their text, pictures and drawings (a drawing becomes a sketch at the end of its page). The notebook then moves to the .trash folder inside your notebooks folder, where you can get it back.",
      "Move to Pages",
      function() { root.moveToPages(notebook) })
  }

  function moveToPages(notebook) {
    if (!root.store || !root.workspace) return
    var name = "\u201c" + notebook.title + "\u201d"
    // (In the profile it was asked in: another opened on the way, it stops,
    // and the notebook stays.)
    var from = root.store.rootPath
    function moved() { return root.store.rootPath !== from }
    root.store.openNotebook(notebook.id, function(nb) {
      if (moved()) { root.toast(name + " wasn't moved: another profile was opened"); return }
      if (!nb) { root.toast(name + " couldn't be read"); return }
      root.workspace.importNotebook(nb, from + "/" + notebook.id, function(r) {
        if (r && r.stopped || moved()) { root.toast(name + " wasn't moved: another profile was opened"); return }
        if (!r) { root.toast(name + " couldn't be moved to Pages"); return }
        if (r.tooLong) { root.toast("\u201c" + r.tooLong + "\u201d in " + name + " is longer than a page in Pages can be: nothing was moved"); return }
        // (Into the trash only once all of it is in Pages, and saved.)
        if (r.missing === 0 && r.failed === 0) root.store.deleteNotebook(notebook.id)
        root.showSpace("pages")
        docs.open(r.id)
        if (r.failed > 0) root.toast(name + " is in Pages, but not all of it could be saved: the notebook stays on the shelf")
        else if (r.missing > 0) root.toast(name + " is in Pages now, but " + (r.missing === 1 ? "a picture" : r.missing + " pictures") + " couldn't be copied: the notebook stays on the shelf")
        else root.toast(name + " is in Pages now")
      })
    })
  }

  // The first time: your first profile, or the demo (nothing made until then).
  FirstRun {
    anchors.fill: parent
    z: 50
    theme: themeObject
    service: root.service
    visible: root.service !== null && root.service.profiles !== undefined && root.service.profiles !== null && (root.service.profiles.firstRun || root.service.profiles.startShown)
  }

  // Another profile (another folder): an open notebook was the one before's,
  // so it's the shelf (what was written is written: the switch saved it).
  Connections {
    target: root.store
    ignoreUnknownSignals: true
    function onRootPathChanged() {
      if (root.mode !== "notebook") return
      view.pageDirty = false
      root.mode = "shelf"
      shelf.opacity = 1
    }
  }

  Confirm { id: confirm; theme: themeObject; parent: root }
  SettingsPanel { id: settingsPanel; theme: themeObject; service: root.service; parent: root; onReleaseNotesRequested: function(own) { releaseNotes.show(own) } }
  ReleaseNotes { id: releaseNotes; theme: themeObject; service: root.service; parent: root }

  // A picture from a file, chosen with the desktop's file picker.
  function pickPicture(afterUid) {
    if (!service) return
    service.pickPicture(function(path) { if (path) view.addPicture(path, afterUid) })
  }

  // A copy of a notebook's picture, saved where you say.
  function savePictureCopy(path, name) {
    if (!service || !path) return
    service.pickSavePath(name, function(to) {
      if (!to) return
      root.store.copyFileTo(path, to, function(ok, why) {
        var home = root.store.home
        root.toast(ok ? "Saved to " + (home && to.indexOf(home + "/") === 0 ? "~" + to.slice(home.length) : to) : "The picture couldn't be saved" + (why ? ": " + why : ""))
      })
    })
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
    toastUndoAction = null
    toastText.text = text
    toastBox.opacity = 1
    toastTimer.interval = 2600
    toastTimer.restart()
  }

  // A message with Undo, a while longer.
  property var toastUndoAction: null
  function toastWithUndo(text, undo) {
    toastText.text = text
    toastUndoAction = undo
    toastBox.opacity = 1
    toastTimer.interval = 6000
    toastTimer.restart()
  }

  Rectangle {
    id: toastBox
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 92
    width: toastText.implicitWidth + 36 + (root.toastUndoAction ? undoButton.width + 8 : 0)
    height: 38
    radius: 19
    color: themeObject.surfaceHigh
    border.width: 1
    border.color: themeObject.line
    opacity: 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    // (A click on it is its own, never the page's under it.)
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }
    Text {
      textFormat: Text.PlainText
      id: toastText
      x: 18
      anchors.verticalCenter: parent.verticalCenter
      font.family: themeObject.uiFont
      font.pixelSize: 13
      color: themeObject.text
    }
    Rectangle {
      id: undoButton
      objectName: "toastUndo"
      visible: root.toastUndoAction !== null
      anchors.right: parent.right
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      width: undoText.implicitWidth + 20
      height: 28
      radius: 14
      color: undoHover.hovered ? themeObject.hover : "transparent"
      Text {
        id: undoText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: "Undo"
        font.family: themeObject.uiFont
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: themeObject.accent
      }
      HoverHandler { id: undoHover; cursorShape: Qt.PointingHandCursor }
      TapHandler {
        gesturePolicy: TapHandler.ReleaseWithinBounds
        onTapped: {
          var f = root.toastUndoAction
          root.toastUndoAction = null
          toastBox.opacity = 0
          if (f) f()
        }
      }
    }
  }
  Timer { id: toastTimer; interval: 2600; onTriggered: toastBox.opacity = 0 }

  Connections {
    target: root.store
    ignoreUnknownSignals: true
    function onFailed(message) { root.toast(message) }
    function onRecovered(count) { root.toast(count === 1 ? "Saved now: the change that couldn't be saved before" : "Saved now: the " + count + " changes that couldn't be saved before") }
    function onExported(path) { root.toast("Exported to " + path.replace(/^\/home\/[^\/]+/, "~")) }
  }
  // (Pages' own: a file it couldn't read, so left as it is; a zip that
  // wouldn't unzip; a picture not copied.)
  Connections {
    target: root.workspace
    ignoreUnknownSignals: true
    function onFailed(message) { if (typeof message === "string" && message) root.toast(message) }
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
