import QtQuick
import QtQuick.Dialogs
import Quickshell
import qs.Commons
import "app"

// The notebook window, and the quick-note card. The Omarchy shell summons
// this (`omarchy-shell shell toggle marcho78.omanote`, the shortcut, the bar
// icon) and keeps it loaded, so the notebook opens instantly and stays where
// you left it; what's in the window is made the first time it opens.
Item {
  id: root

  // ---- plugin lifecycle ---------------------------------------------------

  property var shell: null
  property var service: null
  property var manifest: null

  readonly property string pluginId: "marcho78.omanote"
  readonly property bool opened: window.visible
  property bool closingFromHost: false
  property var pendingPayload: ({})

  // The shell hands the service over when this loads, if the service is
  // there by then; otherwise it's looked up until it is.
  function resolveService() {
    if (!service && shell && typeof shell.serviceFor === "function") service = shell.serviceFor(pluginId)
    return !!service
  }

  onServiceChanged: if (service) service.attachUi(root)
  onShellChanged: resolveService()
  Component.onCompleted: if (!resolveService()) serviceLookup.start()
  // Going away (the shell stopping, Omanote turned off): the page you're on
  // is written first, and the write finishes before anything else goes.
  Component.onDestruction: {
    if (!service) return
    if (service.store) service.store.stopping = true
    saveNow()
    service.detachUi(root)
  }

  Timer {
    id: serviceLookup
    interval: 250
    repeat: true
    property int tries: 0
    onTriggered: {
      tries++
      if (root.resolveService() || tries > 80) stop()
    }
  }

  // Summoned: show the window and go where the payload says (a search, the
  // settings, the shelf), else back where you were.
  function open(payloadJson) {
    resolveService()
    var payload = {}
    try { payload = JSON.parse(String(payloadJson || "{}")) || {} } catch (e) { payload = {} }
    pendingPayload = payload
    content.active = true
    window.visible = true
    Qt.callLater(root.arrive)
  }

  function arrive() {
    var app = content.item
    if (!app) return
    var p = pendingPayload
    pendingPayload = ({})
    app.forceActiveFocus()
    if (typeof p.page === "string" && p.page) {
      app.showSpace("pages")
      app.docView.open(p.page)
    } else if (p.pages) {
      app.showSpace("pages")
      app.docView.activate()
    } else if (typeof p.search === "string" && p.search) {
      app.showSpace("notebooks")
      if (app.mode === "notebook") app.closeNotebook()
      app.shelfView.query = p.search
      app.shelfView.focusSearch()
    } else if (p.settings) {
      app.openSettings()
    } else if (p.shelf) {
      app.showSpace("notebooks")
      if (app.mode === "notebook") app.closeNotebook()
    } else {
      app.resume()
    }
  }

  // Host-initiated close (`shell hide`): the host already knows.
  function close() {
    closingFromHost = true
    saveNow()
    window.visible = false
    closingFromHost = false
  }

  // User-initiated close (Esc on the shelf): tell the shell, so toggle agrees.
  function requestClose() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else window.visible = false
  }

  // For commands (Api.qml): the Pages view changes the page it has open
  // itself, and trashes pages the way its menu does.
  function appendToOpenPage(id, blocks) { return content.item ? content.item.docView.appendFromCommand(id, blocks) : false }
  function addPageBlock(parentId, childId) { return content.item ? content.item.docView.pageAddedInto(parentId, childId) : false }
  function replaceInOpenPage(id, change) { return content.item ? content.item.docView.replaceFromCommand(id, change) : false }
  function insertInOpenPage(id, change) { return content.item ? content.item.docView.insertFromCommand(id, change) : false }
  function trashPage(id) {
    if (!content.item) return false
    content.item.docView.trashPage(id)
    return true
  }

  // Writes the page you're on now (the window closing, the shell stopping).
  function saveNow() {
    if (!content.item) return
    content.item.notebookView.commit()
    content.item.docView.commit()
  }

  // ---- the notebook window ----------------------------------------------------

  Fonts { id: fonts }

  FloatingWindow {
    id: window
    title: "Omanote"
    visible: false
    color: Color.background
    implicitWidth: root.service ? root.service.settings.width : 1320
    implicitHeight: root.service ? root.service.settings.height : 900
    minimumSize: Qt.size(720, 560)

    onVisibleChanged: {
      if (!visible) {
        root.saveNow()
        if (!root.closingFromHost && root.shell && typeof root.shell.hide === "function") root.shell.hide(root.pluginId)
      }
    }

    Loader {
      id: content
      anchors.fill: parent
      active: false
      focus: true
      sourceComponent: App {
        focus: true
        store: root.service ? root.service.store : null
        workspace: root.service ? root.service.workspace : null
        service: root.service
        loadFonts: false
        fontsLoaded: fonts.loaded
        background: Color.background
        foreground: Color.foreground
        accent: Color.accent
        urgent: Color.urgent
        onHideRequested: root.requestClose()
      }
    }
  }

  // A page added from outside (a quick note) shows up in the open notebook.
  Connections {
    target: root.service ? root.service.store : null
    function onPageAdded(notebookId, page) {
      var app = content.item
      if (!app || !app.notebookView.nb || app.notebookView.nb.id !== notebookId) return
      app.notebookView.nb.pages.push(page)
      app.notebookView.revision++
    }
  }

  // ---- the quick note ------------------------------------------------------------

  function openQuick() {
    quickWindow.visible = true
    Qt.callLater(function() { quickNote.start() })
  }

  Theme {
    id: quickTheme
    background: Color.background
    foreground: Color.foreground
    accent: Color.accent
    urgent: Color.urgent
    fontsVersion: fonts.loaded
  }

  FloatingWindow {
    id: quickWindow
    title: "Omanote Quick Note"
    visible: false
    color: "transparent"
    implicitWidth: 520
    implicitHeight: 440

    QuickNote {
      id: quickNote
      anchors.fill: parent
      theme: quickTheme
      onKept: function(text) {
        quickWindow.visible = false
        if (root.service) root.service.quick(text)
      }
      onThrownAway: quickWindow.visible = false
    }
  }

  // ---- pictures from files ---------------------------------------------------------

  property var pictureDone: null

  function pickPicture(done) {
    pictureDone = done
    picker.open()
  }

  // Notes to import into Pages: files, or a folder (a Notion or Obsidian export).
  property var importDone: null

  function pickImport(folder, done) {
    importDone = done
    if (folder) importFolder.open()
    else importFiles.open()
  }

  function importPicked(paths) {
    var done = root.importDone
    root.importDone = null
    if (done) done(paths)
  }

  FileDialog {
    id: importFiles
    title: "Import notes"
    fileMode: FileDialog.OpenFiles
    nameFilters: ["Notes (*.md *.markdown *.txt *.html *.htm *.enex *.zip *.docx *.doc *.odt *.rtf *.epub *.org *.rst)", "All files (*)"]
    currentFolder: "file://" + Quickshell.env("HOME") + "/Documents"
    onAccepted: root.importPicked(selectedFiles.map(function(f) { return decodeURIComponent(String(f).replace(/^file:\/\//, "")) }))
    onRejected: root.importPicked([])
  }

  FolderDialog {
    id: importFolder
    title: "Import a folder of notes"
    currentFolder: "file://" + Quickshell.env("HOME") + "/Documents"
    onAccepted: root.importPicked([decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""))])
    onRejected: root.importPicked([])
  }

  FileDialog {
    id: picker
    title: "Choose a picture"
    nameFilters: ["Pictures (*.png *.jpg *.jpeg *.gif *.webp *.bmp *.svg)"]
    currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
    onAccepted: {
      var done = root.pictureDone
      root.pictureDone = null
      if (done) done(decodeURIComponent(String(selectedFile).replace(/^file:\/\//, "")))
    }
    onRejected: {
      var done = root.pictureDone
      root.pictureDone = null
      if (done) done("")
    }
  }
}
