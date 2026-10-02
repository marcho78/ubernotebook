import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Defaults.js" as Defaults
import "Settings.js" as Settings

// Omanote: notebooks that look and feel like paper, and pages made of
// blocks (Pages), on Omarchy.
//
// This service is the part that's always running. It keeps the shortcuts and
// window rules registered with Hyprland (hypr/omanote.lua, run with `hyprctl
// eval`), holds the settings, the notebooks on disk (Store.qml) and Pages
// (Workspace.qml), and answers IPC. Notebook.qml is the window and the
// quick-note card; BarWidget.qml is the icon in the top bar.
//
//   omarchy-shell omanote toggle
//   omarchy-shell omanote quick "Call the dentist"
//   omarchy-shell omanote search "tram 28"
//   omarchy-shell omanote pages
Item {
  id: root

  // ---- host injection ------------------------------------------------------------

  property var shell: null
  property var manifest: null

  // The development harness turns Hyprland registration and the launcher
  // entry off.
  property bool hyprIntegration: true
  property bool launcherEntry: true
  // The omanote skill (skills/omanote), linked into agents' skill folders
  // while Omanote runs, so whichever agent you use knows its commands.
  property bool agentSkill: true
  readonly property string skillDir: pluginDir + "/skills/omanote"
  readonly property string skillPath: skillDir + "/SKILL.md"

  readonly property string pluginId: "marcho78.omanote"
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string home: Quickshell.env("HOME")
  readonly property string version: manifest && manifest.version ? manifest.version : "1.0.0"

  // ---- settings ----------------------------------------------------------------------
  //
  // Kept inline on Omanote's own shell.json entry (only what differs from
  // Defaults.js): the shell writes the entry (updateEntryInline) and hands
  // plugins a copy of the bar configuration it lives in (barConfig).

  readonly property var defaults: Defaults.DEFAULTS
  readonly property var schema: Defaults.SCHEMA
  property var user: ({})
  readonly property var settings: Settings.merge(defaults, user, schema)

  // While the shell saves an entry it hands plugins a copy of its
  // configuration from just before the save; a copy that still shows the
  // entry as it was must not undo Omanote's own save.
  property bool saving: false
  property string entryBeforeSave: ""

  function loadEntry() {
    if (saving || persistTimer.running) return
    var entry = Settings.entryInBar(shell ? shell.barConfig : null, pluginId)
    if (entryBeforeSave !== "" && JSON.stringify(entry) === entryBeforeSave) return
    entryBeforeSave = ""
    user = entry
  }

  onShellChanged: loadEntry()

  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onBarConfigChanged() { root.loadEntry() }
  }

  function setSetting(key, value) {
    if (!defaults || defaults[key] === undefined) return
    var next = Settings.clone(user)
    next[key] = value
    user = Settings.overrides(defaults, Settings.merge(defaults, next, schema))
    persistTimer.restart()
  }

  function resetSettings() {
    user = ({})
    persistTimer.restart()
  }

  Timer {
    id: persistTimer
    interval: 300
    onTriggered: {
      if (!root.shell || typeof root.shell.updateEntryInline !== "function") return
      root.entryBeforeSave = JSON.stringify(Settings.entryInBar(root.shell.barConfig, root.pluginId))
      root.saving = true
      try {
        root.shell.updateEntryInline(root.pluginId, Settings.clone(root.user))
      } finally {
        root.saving = false
      }
    }
  }

  // ---- the notebooks -------------------------------------------------------------------

  Store {
    id: storeItem
    folder: root.settings.folder
    exportFolder: function(done) { root.exportFolder(done) }
  }

  property alias store: storeItem
  readonly property string rootPath: storeItem.rootPath

  // Pages: the workspace of pages made of blocks, in the Pages folder.
  Workspace {
    id: workspaceItem
    files: storeItem
  }

  property alias workspace: workspaceItem

  // The Markdown copy of every page, while Settings has it on (Mirror.qml).
  readonly property string mirrorPath: {
    var f = settings.mirrorFolder || ""
    if (f.indexOf("~/") === 0) return home + f.slice(1)
    if (f) return f
    return storeItem.rootPath ? storeItem.rootPath + "/Markdown" : ""
  }

  Mirror {
    id: mirrorItem
    workspace: workspaceItem
    store: storeItem
    on: root.settings.mirror === true
    folder: root.mirrorPath
    notesRoot: storeItem.rootPath
    home: root.home
  }

  property alias mirror: mirrorItem

  // The copy's folder, in the file manager (once there's a copy).
  function openMirror() {
    if (!mirrorItem.on || mirrorItem.problem || !mirrorPath) return
    storeItem.exec(["/usr/bin/mkdir", "-p", "--", mirrorPath], function(ok) {
      if (ok) Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", root.mirrorPath])
    })
  }

  // Commands for AI agents and scripts (the IPC below hands them on).
  Api {
    id: apiItem
    workspace: workspaceItem
    files: storeItem
    ui: root.ui
    inbox: root.settings.inbox || ""
    onInboxMade: function(id) { root.setSetting("inbox", id) }
  }

  // ---- Hyprland registration ----------------------------------------------------------
  //
  // The shortcuts and window rules are registered at runtime; your Hyprland
  // config is never edited. A config reload clears them, so they're registered
  // again on every `configreloaded` event. A shortcut some other binding
  // already uses is left alone, and the settings say which.

  property string hyprStatus: ""
  property var takenBinds: []
  property bool registering: false
  property bool registerAgain: false
  property int bindReadRetries: 0

  readonly property string registrationKey: JSON.stringify([settings.shortcut, settings.quickShortcut, settings.floating, settings.width, settings.height])
  onRegistrationKeyChanged: scheduleRegister()

  function scheduleRegister() {
    bindReadRetries = 0
    if (hyprIntegration) registerTimer.restart()
  }

  Timer {
    id: registerTimer
    // Long enough for a hot-reloaded predecessor's cleanup to land first.
    interval: 350
    onTriggered: root.register()
  }

  Timer {
    id: bindRetryTimer
    interval: 3000
    onTriggered: root.register()
  }

  function register() {
    if (registering) {
      registerAgain = true
      return
    }
    registering = true
    bindsRun.start(["/usr/bin/hyprctl", "-j", "binds"])
  }

  Run {
    id: bindsRun
    maxBytes: 512 * 1024
    timeoutMs: 4000
    onFinished: function(ok, output) {
      var existing = null
      if (ok) {
        try { existing = JSON.parse(output) } catch (e) { existing = null }
      }
      if (Array.isArray(existing)) root.bindReadRetries = 0
      else if (root.bindReadRetries < 3) {
        root.bindReadRetries++
        bindRetryTimer.restart()
      }
      var checked = Settings.checkBinds(Settings.wantedBinds(root.settings), existing)
      root.takenBinds = checked.taken
      registerRun.start(["/usr/bin/hyprctl", "eval",
        Settings.hyprRegistration(root.pluginDir + "/hypr/omanote.lua", Settings.hyprOptions(checked.free, root.settings))])
    }
  }

  Run {
    id: registerRun
    maxBytes: 16 * 1024
    timeoutMs: 4000
    onFinished: function(ok, output) {
      // hypr/omanote.lua raises what didn't register; hyprctl prints it as "error: …".
      var text = String(output || "").trim().replace(/^error:\s*/i, "")
      root.hyprStatus = ok && (text === "" || text === "ok") ? "ok" : (text.slice(0, 600) || "Hyprland didn't answer")
      if (root.hyprStatus !== "ok") console.warn("Omanote: registering with Hyprland:", root.hyprStatus)
      root.registering = false
      if (root.registerAgain) {
        root.registerAgain = false
        root.register()
      }
    }
  }

  // What the settings say under a shortcut: who has it, or what went wrong.
  function shortcutNote(event) {
    var key = event === "quick" ? settings.quickShortcut : settings.shortcut
    if (!key) return "Off"
    for (var i = 0; i < takenBinds.length; i++) {
      var t = takenBinds[i]
      if (t.event !== event) continue
      if (t.unknown) return "Couldn't read Hyprland's shortcuts to check this one."
      return Settings.shortcutLabel(key) + " is already " + t.usedBy + "; pick another."
    }
    if (hyprStatus && hyprStatus !== "ok") return hyprStatus
    return Settings.shortcutLabel(key)
  }

  // Take the shortcuts and rules back out of Hyprland when Omanote is
  // disabled or reloaded; write everything waiting to be written.
  Component.onDestruction: {
    if (launcherEntry) Quickshell.execDetached(["/usr/bin/rm", "-f", "--", desktopFile])
    if (agentSkill) storeItem.unlinkSkill(skillDir)
    // Writes from here on finish before the shell goes on stopping.
    storeItem.stopping = true
    if (ui && typeof ui.saveNow === "function") ui.saveNow()
    workspaceItem.flush()
    storeItem.flush()
    if (hyprIntegration)
      Quickshell.execDetached(["/usr/bin/hyprctl", "eval",
        Settings.hyprRegistration(pluginDir + "/hypr/omanote.lua", { remove: true })])
  }

  Connections {
    target: Hyprland
    enabled: root.hyprIntegration
    function onRawEvent(event) {
      var name = event.name
      if (name === "custom") {
        var parsed = Settings.parseEvent(event.data)
        if (!parsed) return
        if (parsed.command === "toggle") root.toggle({})
        else if (parsed.command === "quick") root.quick("")
      } else if (name === "configreloaded") {
        root.scheduleRegister()
      }
    }
  }

  // ---- the window ------------------------------------------------------------------------
  //
  // Opening and closing go through the Omarchy shell (summon/hide/toggle), so
  // `omarchy-shell shell toggle marcho78.omanote` and the shortcut agree.

  property var ui: null
  readonly property bool windowOpen: !!ui && ui.opened === true

  function attachUi(item) { ui = item }
  function detachUi(item) { if (ui === item) ui = null }

  function toggle(payload) {
    if (shell && typeof shell.toggle === "function") shell.toggle(pluginId, JSON.stringify(payload || {}))
    else if (ui) ui.opened ? ui.close() : ui.open(JSON.stringify(payload || {}))
  }

  function show(payload) {
    if (shell && typeof shell.summon === "function") shell.summon(pluginId, JSON.stringify(payload || {}))
    else if (ui) ui.open(JSON.stringify(payload || {}))
  }

  function hide() {
    if (shell && typeof shell.hide === "function") shell.hide(pluginId)
    else if (ui) ui.close()
  }

  // A quick note: with text, straight into the Quick notes notebook (or the
  // Pages Inbox, as Settings says); without, the quick-note card opens.
  function quick(text) {
    var value = String(text || "").trim()
    if (value) {
      if (settings.quickTo === "pages") quickToPages(value)
      else quickToNotebook(value)
      return
    }
    if (ui && typeof ui.openQuick === "function") ui.openQuick()
  }

  function quickToNotebook(value) {
    storeItem.quickNote(value)
    osd("\u{f082e}", "Saved to Quick notes")
  }

  // Into the Pages Inbox, once Pages has loaded (a note made before then
  // waits for it; if Pages can't load, it goes to the Quick notes notebook,
  // so it's never lost).
  property var quickWaiting: []

  function quickToPages(value) {
    if (!workspaceItem.ready) {
      quickWaiting = quickWaiting.concat([value])
      quickTimer.restart()
      return
    }
    var r = null
    try { r = JSON.parse(apiItem.quickPage(value)) } catch (e) { r = null }
    if (r && r.ok) osd("\u{f0836}", "Saved to your Pages Inbox")
    else {
      storeItem.quickNote(value)
      osd("\u{f082e}", "Saved to Quick notes (Pages: " + (r ? r.error : "couldn't save it") + ")")
    }
  }

  function flushQuick(toPages) {
    quickTimer.stop()
    var list = quickWaiting
    quickWaiting = []
    list.forEach(function(v) { if (toPages) root.quickToPages(v); else root.quickToNotebook(v) })
  }

  Connections {
    target: workspaceItem
    function onReadyChanged() { if (workspaceItem.ready && root.quickWaiting.length) root.flushQuick(true) }
  }

  Timer {
    id: quickTimer
    interval: 10000
    onTriggered: root.flushQuick(false)
  }

  // The desktop's file picker, for notes to import into Pages (files, or a folder).
  function pickImport(folder, done) {
    if (ui && typeof ui.pickImport === "function") ui.pickImport(folder, done)
    else done([])
  }

  // Where an export goes, as Settings says: a folder you pick (done("") if
  // you don't), or the Exports folder in the notebooks folder.
  function exportFolder(done) {
    if (settings.exportTo === "folder" || !ui || typeof ui.pickExportFolder !== "function") done(storeItem.rootPath + "/Exports")
    else ui.pickExportFolder(done)
  }

  // The desktop's file picker, for a picture (the window shows it).
  function pickPicture(done) {
    if (ui && typeof ui.pickPicture === "function") ui.pickPicture(done)
    else done("")
  }

  function osd(icon, message) {
    Quickshell.execDetached(["/usr/bin/omarchy-shell", "-q", "osd", "show",
      JSON.stringify({ icon: icon, message: String(message).slice(0, 120), duration: 1400 })])
  }

  // ---- in the app launcher ----------------------------------------------------------------------
  //
  // An entry in ~/.local/share/applications, so Omanote is in the Omarchy
  // launcher (and any other) with its icon, like an app. It's written when
  // Omanote starts and taken out when it stops, so turning Omanote off (or
  // removing it) leaves nothing behind.

  readonly property string desktopFile: home + "/.local/share/applications/marcho78-omanote.desktop"

  FileView {
    id: desktopWriter
    atomicWrites: true
    preload: false
    printErrors: false
  }

  Timer {
    id: launcherTimer
    // After a reloaded predecessor has taken its entry out.
    interval: 1200
    onTriggered: {
      var entry = Settings.desktopEntry(root.pluginDir)
      if (!entry) return
      storeItem.exec(["/usr/bin/mkdir", "-p", "--", root.home + "/.local/share/applications"], function(ok) {
        if (!ok) return
        desktopWriter.path = root.desktopFile
        desktopWriter.setText(entry)
      })
    }
  }

  // ---- IPC --------------------------------------------------------------------------------------

  IpcHandler {
    target: "omanote"

    function toggle(): void { root.toggle({}) }
    function show(): void { if (!root.windowOpen) root.show({}) }
    function hide(): void { root.hide() }
    // omanote quick            opens the quick-note card
    // omanote quick "Buy milk"  saves it straight away
    function quick(text: string): void { root.quick(String(text || "").slice(0, 20000)) }
    function search(text: string): void { root.show({ search: String(text || "").slice(0, 200) }) }
    function shelf(): void { root.show({ shelf: true }) }
    // omanote pages: straight to Pages.
    function pages(): void { root.show({ pages: true }) }
    // omanote importNotes ~/notes: files or a folder (a Notion or Obsidian export) into Pages.
    function importNotes(path: string): void {
      var p = String(path || "")
      if (p.indexOf("~/") === 0) p = root.home + p.slice(1)
      workspaceItem.importPaths([p], "", function(r) {
        root.osd("\u{f0e27}", r.pages ? "Imported " + r.pages + (r.pages === 1 ? " page" : " pages") + " into Pages" : "Nothing to import there")
      })
    }
    // omanote open <page id>: a page in Pages (a reminder's notification does this).
    function open(id: string): void { if (/^[0-9a-f-]{36}$/.test(String(id || ""))) root.show({ page: String(id) }) }
    function settings(): void { root.show({ settings: true }) }
    // omarchy-shell omanote set paper grid   (values are checked like the settings panel's)
    function set(key: string, value: string): string {
      if (!root.defaults || root.defaults[key] === undefined) return "unknown setting"
      var parsed = value
      if (value === "true" || value === "false") parsed = value === "true"
      else if (/^-?\d{1,6}$/.test(value)) parsed = Number(value)
      root.setSetting(key, parsed)
      return JSON.stringify(root.settings[key])
    }
    function reset(): void { root.resetSettings() }
    // omarchy-shell omanote mirror: the Markdown copy made up to date now, and how it is.
    function mirror(): string {
      if (!mirrorItem.on) return JSON.stringify({ ok: false, error: "the Markdown copy is off: omarchy-shell omanote set mirror true" })
      mirrorItem.sync()
      return JSON.stringify({ ok: !mirrorItem.problem, folder: root.mirrorPath, status: mirrorItem.status, files: mirrorItem.files })
    }

    // For AI agents and scripts: pages in and out, answered in JSON
    // (omarchy-shell omanote help lists them; Api.qml does them).
    function help(): string { return apiItem.help() }
    function list(): string { return apiItem.list() }
    function find(words: string): string { return apiItem.find(words) }
    function read(id: string): string { return apiItem.read(id) }
    function add(title: string, file: string): string { return apiItem.add(title, file) }
    function addTo(page: string, title: string, file: string): string { return apiItem.addTo(page, title, file) }
    function append(id: string, file: string): string { return apiItem.append(id, file) }
    function blocks(id: string): string { return apiItem.blocks(id) }
    function tags(): string { return apiItem.tags() }
    function tagged(tag: string): string { return apiItem.tagged(tag) }
    function tagColor(tag: string, color: string): string { return apiItem.tagColor(tag, color) }
    function projects(): string { return apiItem.projects() }
    function project(id: string, status: string, due: string): string { return apiItem.project(id, status, due) }
    function archive(id: string): string { return apiItem.archive(id, true) }
    function unarchive(id: string): string { return apiItem.archive(id, false) }
    function replace(page: string, block: string, file: string): string { return apiItem.replace(page, block, file) }
    function insertAfter(page: string, block: string, file: string): string { return apiItem.insertAfter(page, block, file) }
    function trash(id: string): string { return apiItem.trash(id) }
    function status(): string {
      return JSON.stringify({
        open: root.windowOpen,
        hyprland: root.hyprStatus,
        takenShortcuts: root.takenBinds,
        folder: root.rootPath,
        notebooks: storeItem.notebooks.length,
        pages: Object.keys(workspaceItem.index.pages).length,
        ready: storeItem.ready,
        connected: !!root.shell
      })
    }
  }

  Component.onCompleted: {
    scheduleRegister()
    if (launcherEntry) launcherTimer.start()
    if (agentSkill) storeItem.linkSkill(skillDir)
  }
}
