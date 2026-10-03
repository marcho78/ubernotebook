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
    } else if (typeof p.calendar === "string" && p.calendar) {
      app.showSpace("pages")
      app.docView.openCalendar(p.calendar === "today" ? "" : p.calendar)
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
  function setProjectOfOpenPage(id, next) { return content.item ? content.item.docView.setProjectOfOpenPage(id, next) : false }
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

    // The file pickers: Qt's own, drawn in this window (declared in it, so
    // it's theirs). The desktop's (GTK's) would run inside the Omarchy shell,
    // and its folder watching can bring the whole shell down.
    FileDialog {
      id: importFiles
      title: "Import notes"
      options: FileDialog.DontUseNativeDialog
      fileMode: FileDialog.OpenFiles
      nameFilters: ["Notes (*.md *.markdown *.txt *.html *.htm *.enex *.zip *.docx *.doc *.odt *.rtf *.epub *.org *.rst)", "All files (*)"]
      currentFolder: "file://" + Quickshell.env("HOME") + "/Documents"
      onAccepted: root.importPicked(selectedFiles.map(function(f) { return decodeURIComponent(String(f).replace(/^file:\/\//, "")) }))
      onRejected: root.importPicked([])
    }

    FolderDialog {
      id: importFolder
      title: "Import a folder of notes"
      options: FolderDialog.DontUseNativeDialog
      currentFolder: "file://" + Quickshell.env("HOME") + "/Documents"
      onAccepted: root.importPicked([decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, ""))])
      onRejected: root.importPicked([])
    }

    FolderDialog {
      id: folderPicker
      options: FolderDialog.DontUseNativeDialog
      currentFolder: "file://" + Quickshell.env("HOME") + "/Documents"
      onAccepted: root.folderPicked(decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, "")))
      onRejected: root.folderPicked("")
    }

    FolderDialog {
      id: exportPicker
      title: "Export to"
      options: FolderDialog.DontUseNativeDialog
      currentFolder: "file://" + Quickshell.env("HOME") + "/Documents"
      onAccepted: root.exportPicked(decodeURIComponent(String(selectedFolder).replace(/^file:\/\//, "")))
      onRejected: root.exportPicked("")
    }

    FileDialog {
      id: filePicker
      options: FileDialog.DontUseNativeDialog
      currentFolder: "file://" + Quickshell.env("HOME")
      onAccepted: {
        var done = root.fileDone
        root.fileDone = null
        if (done) done(decodeURIComponent(String(selectedFile).replace(/^file:\/\//, "")))
      }
      onRejected: {
        var done = root.fileDone
        root.fileDone = null
        if (done) done("")
      }
    }

    FileDialog {
      id: picturesPicker
      title: "Choose pictures"
      options: FileDialog.DontUseNativeDialog
      fileMode: FileDialog.OpenFiles
      nameFilters: ["Pictures (*.png *.jpg *.jpeg *.gif *.webp *.bmp *.svg)"]
      currentFolder: "file://" + Quickshell.env("HOME") + "/Pictures"
      onAccepted: root.picturesPicked(selectedFiles.map(function(f) { return decodeURIComponent(String(f).replace(/^file:\/\//, "")) }))
      onRejected: root.picturesPicked([])
    }

    FileDialog {
      id: picker
      title: "Choose a picture"
      options: FileDialog.DontUseNativeDialog
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
    baseBackground: Color.background
    baseForeground: Color.foreground
    pageColor: root.service && root.service.settings ? (root.service.settings.colorPage || "") : ""
    textColor: root.service && root.service.settings ? (root.service.settings.colorText || "") : ""
    cardColor: root.service && root.service.settings ? (root.service.settings.colorCards || "") : ""
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
      destination: root.service ? (root.service.settings.quickTo || "notebook") : "notebook"
      recorder: root.service ? root.service.recorder : null
      onDestinationPicked: function(to) { if (root.service) root.service.setSetting("quickTo", to) }
      onKept: function(text) {
        quickWindow.visible = false
        if (root.service) root.service.quick(text)
      }
      onThrownAway: quickWindow.visible = false
    }
  }

  // ---- pictures from files ---------------------------------------------------------

  property var pictureDone: null

  // A file to put on a page (any, a PDF, a video).
  property var fileDone: null
  // (`from`: the folder it opens in; else your home.)
  function pickFile(kind, done, from) {
    fileDone = done
    filePicker.nameFilters = kind === "calendar" ? ["Calendars (*.ics *.ical *.ifb *.vcs)", "Any file (*)"] : kind === "pdf" ? ["PDF (*.pdf)"] : kind === "video" ? ["Videos (*.mp4 *.m4v *.mov *.webm *.mkv *.avi *.ogv)"] : kind === "contacts" ? ["Contacts (*.vcf *.vcard *.csv)"] : kind === "email" ? ["Emails (*.eml)", "Any file (*)"] : kind === "backup" ? ["Backups (*.tar.gz)", "Any file (*)"] : ["Any file (*)"]
    filePicker.title = kind === "calendar" ? "Choose a calendar file (.ics)" : kind === "pdf" ? "Choose a PDF" : kind === "video" ? "Choose a video" : kind === "contacts" ? "Choose contacts to import (.vcf or .csv)" : kind === "email" ? "Choose an email (.eml)" : kind === "backup" ? "Choose a backup (.tar.gz)" : "Choose a file"
    filePicker.currentFolder = "file://" + (from || Quickshell.env("HOME"))
    filePicker.open()
  }

  function pickPicture(done) {
    pictureDone = done
    picker.open()
  }
  // Pictures, several at once (a gallery's): done([paths]).
  property var picturesDone: null
  function pickPictures(done) {
    picturesDone = done
    picturesPicker.open()
  }
  function picturesPicked(paths) {
    var done = root.picturesDone
    root.picturesDone = null
    if (done) done(paths)
  }

  // A folder for something (a profile's notes): done(path), or done("").
  property var folderDone: null
  function pickFolder(title, done) {
    folderDone = done
    folderPicker.title = title || "Choose a folder"
    folderPicker.open()
  }
  function folderPicked(path) {
    var done = root.folderDone
    root.folderDone = null
    if (done) done(path)
  }

  // Where an export goes, when Settings says to ask.
  property var exportDone: null

  function pickExportFolder(done) {
    exportDone = done
    exportPicker.open()
  }

  function exportPicked(path) {
    var done = root.exportDone
    root.exportDone = null
    if (done) done(path)
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

}
