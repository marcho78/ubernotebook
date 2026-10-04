import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Defaults.js" as Defaults
import "Settings.js" as Settings

// Uber Notebook: notebooks that look and feel like paper, and pages made of
// blocks (Pages), on Omarchy.
//
// This service is the part that's always running. It keeps the shortcuts and
// window rules registered with Hyprland (hypr/uber-notebook.lua, run with `hyprctl
// eval`), holds the settings, the notebooks on disk (Store.qml) and Pages
// (Workspace.qml), and answers IPC. Notebook.qml is the window and the
// quick-note card; BarWidget.qml is the icon in the top bar.
//
//   omarchy-shell uber-notebook toggle
//   omarchy-shell uber-notebook quick "Call the dentist"
//   omarchy-shell uber-notebook search "tram 28"
//   omarchy-shell uber-notebook pages
Item {
  id: root

  // ---- host injection ------------------------------------------------------------

  property var shell: null
  property var manifest: null

  // The development harness turns Hyprland registration and the launcher
  // entry off.
  property bool hyprIntegration: true
  property bool launcherEntry: true
  // The uber-notebook skill (skills/uber-notebook), linked into agents' skill folders
  // while Uber Notebook runs, so whichever agent you use knows its commands.
  property bool agentSkill: true
  readonly property string skillDir: pluginDir + "/skills/uber-notebook"
  readonly property string skillPath: skillDir + "/SKILL.md"

  readonly property string pluginId: "marcho78.uber-notebook"
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "").replace(/\/$/, ""))
  readonly property string home: Quickshell.env("HOME")
  // The manifest, as the shell hands it over (or, if it doesn't, as
  // manifest.json says): the version, and the homepage updates are asked of.
  property var ownManifest: null
  readonly property var about: manifest && manifest.version ? manifest : ownManifest
  readonly property string version: about && about.version ? about.version : "1.0.0"

  // ---- settings ----------------------------------------------------------------------
  //
  // Kept inline on Uber Notebook's own shell.json entry (only what differs from
  // Defaults.js): the shell writes the entry (updateEntryInline) and hands
  // plugins a copy of the bar configuration it lives in (barConfig).

  readonly property var defaults: Defaults.DEFAULTS
  readonly property var schema: Defaults.SCHEMA
  property var user: ({})
  readonly property var settings: Settings.merge(defaults, user, schema)

  // While the shell saves an entry it hands plugins a copy of its
  // configuration from just before the save; a copy that still shows the
  // entry as it was must not undo Uber Notebook's own save.
  property bool saving: false
  property string entryBeforeSave: ""

  function loadEntry() {
    if (saving || persistTimer.running) return
    var entry = Settings.entryInBar(shell ? shell.barConfig : null, pluginId)
    if (entryBeforeSave !== "" && JSON.stringify(entry) === entryBeforeSave) return
    entryBeforeSave = ""
    user = entry
    // (The profiles are settled once the shell's configuration is in.)
    if (shell && shell.barConfig && typeof shell.barConfig === "object" && shell.barConfig.layout) settleTimer.restart()
  }
  Timer {
    id: settleTimer
    interval: 400
    onTriggered: profilesItem.settle()
  }

  // ---- profiles ----------------------------------------------------------------------

  // Notes kept apart (Profiles.qml): the open one's folder is the notebooks'
  // and Pages'. None yet (the first run): nothing's made anywhere until
  // there's one.
  Profiles {
    id: profilesItem
    service: root
    files: storeItem
    dataFolder: { var d = Quickshell.env("XDG_DATA_HOME"); return d && d.indexOf("/") === 0 ? d.replace(/\/+$/, "") + "/uber-notebook" : "~/.local/share/uber-notebook" }
  }
  property alias profiles: profilesItem

  // What's open in the window, written (before another profile opens).
  function saveOpen() { if (ui && typeof ui.saveNow === "function") ui.saveNow() }

  // A folder picked in the window: done(path), or done("").
  function pickFolder(title, done) {
    if (ui && typeof ui.pickFolder === "function") ui.pickFolder(title, done)
    else done("")
  }

  onShellChanged: loadEntry()

  Connections {
    target: root.shell
    ignoreUnknownSignals: true
    function onBarConfigChanged() { root.loadEntry() }
  }

  function setSetting(key, value) {
    var changes = {}
    changes[key] = value
    setSettings(changes)
  }
  // Several at once ({ key: value }), as one change.
  function setSettings(changes) {
    var next = Settings.clone(user)
    for (var key in changes) if (defaults && defaults[key] !== undefined) next[key] = changes[key]
    user = Settings.overrides(defaults, Settings.merge(defaults, next, schema))
    persistTimer.restart()
  }

  // Every setting as it started, but the profiles and what's each one's own.
  function resetSettings() {
    var keep = {}
    ;["profiles", "profile", "folder"].concat(Settings.PROFILE_KEYS).forEach(function(k) { if (root.user[k] !== undefined) keep[k] = root.user[k] })
    user = keep
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
    // No profile yet: no folder, nothing made.
    active: profilesItem.current !== null
    // A first notebook with things to try: the demo's; a profile of your own starts empty.
    welcome: profilesItem.current !== null && profilesItem.current.demo === true
    exportFolder: function(done) { root.exportFolder(done) }
  }

  property alias store: storeItem
  readonly property string rootPath: storeItem.rootPath

  // Pages: the workspace of pages made of blocks, in the Pages folder.
  Workspace {
    id: workspaceItem
    files: storeItem
    // A new Pages: the demo's starts with the examples (Starter.js); one of
    // your own, with the templates.
    starter: profilesItem.current !== null && profilesItem.current.demo === true ? "examples" : "templates"
  }

  property alias workspace: workspaceItem

  // The microphone: dictation and audio notes (Recorder.qml).
  Recorder {
    id: recorderItem
    files: storeItem
    input: root.settings.audioInput || ""
    boost: root.settings.audioBoost !== false
  }

  property alias recorder: recorderItem

  // Meetings, recorded by voxtype's meeting mode (Meetings.qml).
  Meetings {
    id: meetingsItem
    files: storeItem
  }

  property alias meetings: meetingsItem

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

  // Whether there's a newer Uber Notebook, and what's in it (Updates.qml).
  Updates {
    id: updatesItem
    files: storeItem
    current: root.version
    homepage: root.about && root.about.homepage ? root.about.homepage : ""
    pluginDir: root.pluginDir
    pluginId: root.pluginId
    automatic: root.settings.checkUpdates !== false
  }

  property alias updates: updatesItem

  // Backups of the profiles, and putting one back (Backups.qml).
  Backups {
    id: backupsItem
    service: root
    files: storeItem
    profiles: profilesItem
    version: root.version
  }

  property alias backups: backupsItem

  // Commands for AI agents and scripts (the IPC below hands them on).
  Api {
    id: apiItem
    workspace: workspaceItem
    files: storeItem
    ui: root.ui
    inbox: root.settings.inbox || ""
    noProfile: profilesItem.firstRun
    profiles: profilesItem
    settings: root.settings
    updates: updatesItem
    backups: backupsItem
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
        Settings.hyprRegistration(root.pluginDir + "/hypr/uber-notebook.lua", Settings.hyprOptions(checked.free, root.settings))])
    }
  }

  Run {
    id: registerRun
    maxBytes: 16 * 1024
    timeoutMs: 4000
    onFinished: function(ok, output) {
      // hypr/uber-notebook.lua raises what didn't register; hyprctl prints it as "error: …".
      var text = String(output || "").trim().replace(/^error:\s*/i, "")
      root.hyprStatus = ok && (text === "" || text === "ok") ? "ok" : (text.slice(0, 600) || "Hyprland didn't answer")
      if (root.hyprStatus !== "ok") console.warn("Uber Notebook: registering with Hyprland:", root.hyprStatus)
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

  // Take the shortcuts and rules back out of Hyprland when Uber Notebook is
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
        Settings.hyprRegistration(pluginDir + "/hypr/uber-notebook.lua", { remove: true })])
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
  // `omarchy-shell shell toggle marcho78.uber-notebook` and the shortcut agree.

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
    // (No profile yet: the window, to make one.)
    if (profilesItem.firstRun) { show({}); return }
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
  // A file to put on a page: "any", "pdf" or "video". done(path), or done("").
  function pickFile(kind, done, from) {
    if (ui && typeof ui.pickFile === "function") ui.pickFile(kind, done, from || "")
    else done("")
  }

  // Pictures (several at once): done([paths]), or done([]).
  function pickPictures(done) {
    if (ui && typeof ui.pickPictures === "function") ui.pickPictures(done)
    else done([])
  }

  function pickPicture(done) {
    if (ui && typeof ui.pickPicture === "function") ui.pickPicture(done)
    else done("")
  }

  // Where a copy of something goes (a picture saved out), named `name` to
  // start with: done(path), or done("").
  function pickSavePath(name, done) {
    if (ui && typeof ui.pickSavePath === "function") ui.pickSavePath(name, done)
    else done("")
  }

  function osd(icon, message) {
    Quickshell.execDetached(["/usr/bin/omarchy-shell", "-q", "osd", "show",
      JSON.stringify({ icon: icon, message: String(message).slice(0, 120), duration: 1400 })])
  }

  // ---- in the app launcher ----------------------------------------------------------------------
  //
  // An entry in ~/.local/share/applications, so Uber Notebook is in the Omarchy
  // launcher (and any other) with its icon, like an app. It's written when
  // Uber Notebook starts and taken out when it stops, so turning Uber Notebook off (or
  // removing it) leaves nothing behind.

  readonly property string desktopFile: home + "/.local/share/applications/marcho78-uber-notebook.desktop"

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
    target: "uber-notebook"

    function toggle(): void { root.toggle({}) }
    function show(): void { if (!root.windowOpen) root.show({}) }
    function hide(): void { root.hide() }
    // uber-notebook quick            opens the quick-note card
    // uber-notebook quick "Buy milk"  saves it straight away
    function quick(text: string): void { root.quick(String(text || "").slice(0, 20000)) }
    function search(text: string): void { root.show({ search: String(text || "").slice(0, 200) }) }
    function shelf(): void { root.show({ shelf: true }) }
    // uber-notebook pages: straight to Pages.
    function pages(): void { root.show({ pages: true }) }
    // The calendar, on a day ("" is today).
    function calendar(day: string): void { root.show({ calendar: /^\d{4}-\d{2}-\d{2}$/.test(String(day || "")) ? String(day) : "today" }) }
    // uber-notebook importNotes ~/notes: files or a folder (a Notion or Obsidian export) into Pages.
    function importNotes(path: string): void {
      var p = String(path || "")
      if (p.indexOf("~/") === 0) p = root.home + p.slice(1)
      workspaceItem.importPaths([p], "", function(r) {
        root.osd("\u{f0e27}", r.pages ? "Imported " + r.pages + (r.pages === 1 ? " page" : " pages") + " into Pages" : "Nothing to import there")
      })
    }
    // uber-notebook open <page id>: a page in Pages (a reminder's notification does this).
    function open(id: string): void { if (/^[0-9a-f-]{36}$/.test(String(id || ""))) root.show({ page: String(id) }) }
    function settings(): void { root.show({ settings: true }) }
    // omarchy-shell uber-notebook set paper grid   (values are checked like the settings panel's)
    function set(key: string, value: string): string {
      if (!root.defaults || root.defaults[key] === undefined) return "unknown setting"
      var parsed = value
      if (value === "true" || value === "false") parsed = value === "true"
      else if (/^-?\d{1,6}$/.test(value)) parsed = Number(value)
      root.setSetting(key, parsed)
      return JSON.stringify(root.settings[key])
    }
    function reset(): void { root.resetSettings() }
    // omarchy-shell uber-notebook mirror: the Markdown copy made up to date now, and how it is.
    function mirror(): string {
      if (!mirrorItem.on) return JSON.stringify({ ok: false, error: "the Markdown copy is off: omarchy-shell uber-notebook set mirror true" })
      mirrorItem.sync()
      return JSON.stringify({ ok: !mirrorItem.problem, folder: root.mirrorPath, status: mirrorItem.status, files: mirrorItem.files })
    }

    // For AI agents and scripts: pages in and out, answered in JSON
    // (omarchy-shell uber-notebook help lists them; Api.qml does them).
    function help(): string { return apiItem.help() }
    function list(): string { return apiItem.list() }
    function find(words: string): string { return apiItem.find(words) }
    function read(id: string): string { return apiItem.read(id) }
    function add(title: string, file: string): string { return apiItem.add(title, file) }
    function addTo(page: string, title: string, file: string): string { return apiItem.addTo(page, title, file) }
    function append(id: string, file: string): string { return apiItem.append(id, file) }
    function blocks(id: string): string { return apiItem.blocks(id) }
    function tags(): string { return apiItem.tags() }
    function library(kind: string, words: string): string { return apiItem.library(kind, words) }
    function contacts(words: string): string { return apiItem.contacts(words) }
    function contact(which: string): string { return apiItem.contact(which) }
    function addContact(name: string, phone: string, email: string): string { return apiItem.addContact(name, phone, email) }
    function importContacts(file: string): string { return apiItem.importContacts(file) }
    function tagged(tag: string): string { return apiItem.tagged(tag) }
    function tagColor(tag: string, color: string): string { return apiItem.tagColor(tag, color) }
    function projects(): string { return apiItem.projects() }
    function templates(): string { return apiItem.templates() }
    function events(from: string, to: string): string { return apiItem.events(from, to) }
    function addEvent(what: string, repeat: string): string { return apiItem.addEvent(what, repeat) }
    function removeEvent(id: string): string { return apiItem.removeEvent(id) }
    function fromTemplate(template: string, title: string, parent: string): string { return apiItem.fromTemplate(template, title, parent) }
    function project(id: string, status: string, due: string): string { return apiItem.project(id, status, due) }
    function archive(id: string): string { return apiItem.archive(id, true) }
    function unarchive(id: string): string { return apiItem.archive(id, false) }
    function replace(page: string, block: string, file: string): string { return apiItem.replace(page, block, file) }
    function insertAfter(page: string, block: string, file: string): string { return apiItem.insertAfter(page, block, file) }
    function trash(id: string): string { return apiItem.trash(id) }
    function rename(id: string, title: string): string { return apiItem.rename(id, title) }
    function move(id: string, parent: string, position: string): string { return apiItem.move(id, parent, position) }
    function icon(id: string, emoji: string): string { return apiItem.icon(id, emoji) }
    function cover(id: string, cover: string): string { return apiItem.cover(id, cover) }
    function lock(id: string, on: string): string { return apiItem.lock(id, on) }
    function favorite(id: string, on: string): string { return apiItem.favorite(id, on) }
    function trashed(): string { return apiItem.trashed() }
    function restore(id: string): string { return apiItem.restore(id) }
    function duplicate(id: string): string { return apiItem.duplicate(id) }
    function makeTemplate(id: string): string { return apiItem.makeTemplate(id) }
    function history(id: string): string { return apiItem.history(id) }
    function version(id: string, name: string): string { return apiItem.version(id, name) }
    function restoreVersion(id: string, name: string): string { return apiItem.restoreVersion(id, name) }
    function check(page: string, block: string, on: string): string { return apiItem.check(page, block, on) }
    function color(page: string, block: string, color: string): string { return apiItem.color(page, block, color) }
    function removeBlock(page: string, block: string): string { return apiItem.removeBlock(page, block) }
    function board(page: string, block: string, action: string, a: string, b: string): string { return apiItem.board(page, block, action, a, b) }
    function attach(page: string, file: string): string { return apiItem.attach(page, file) }
    function bookmark(page: string, url: string): string { return apiItem.bookmark(page, url) }
    function editEvent(id: string, field: string, value: string): string { return apiItem.editEvent(id, field, value) }
    function editContact(which: string, field: string, value: string): string { return apiItem.editContact(which, field, value) }
    function removeContact(id: string): string { return apiItem.removeContact(id) }
    function importCalendar(file: string): string { return apiItem.importCalendar(file) }
    function picture(page: string, block: string, width: string, align: string): string { return apiItem.picture(page, block, width, align) }
    function addGallery(page: string, pictures: string, columns: string): string { return apiItem.addGallery(page, pictures, columns) }
    function gallery(page: string, block: string, action: string, a: string, b: string): string { return apiItem.gallery(page, block, action, a, b) }
    function setLink(page: string, block: string, link: string): string { return apiItem.setLink(page, block, link) }
    function describeTemplate(template: string, text: string): string { return apiItem.describeTemplate(template, text) }
    function addTemplate(title: string, file: string, description: string): string { return apiItem.addTemplate(title, file, description) }
    function preferences(): string { return apiItem.preferences() }
    function renameTag(tag: string, to: string): string { return apiItem.renameTag(tag, to) }
    function removeTag(tag: string): string { return apiItem.removeTag(tag) }
    function notebooks(): string { return apiItem.notebooks() }
    function notebook(id: string): string { return apiItem.notebook(id) }
    function readNotebook(id: string, page: string): string { return apiItem.readNotebook(id, page) }
    function addToNotebook(id: string, file: string): string { return apiItem.addToNotebook(id, file) }
    // omarchy-shell uber-notebook profiles: [{ id, name, folder, open, demo }].
    function profiles(): string { return apiItem.profileList() }
    // omarchy-shell uber-notebook profile Business: another profile open (its name or id).
    function profile(which: string): string { return apiItem.openProfile(which) }
    function addProfile(name: string, folder: string, open: string): string { return apiItem.addProfile(name, folder, open) }
    function renameProfile(which: string, name: string): string { return apiItem.renameProfile(which, name) }
    function profileFolder(which: string, folder: string): string { return apiItem.profileFolder(which, folder) }
    function removeProfile(which: string): string { return apiItem.removeProfile(which) }
    function demo(): string { return apiItem.demo(false) }
    function restartDemo(): string { return apiItem.demo(true) }
    function backup(which: string): string { return apiItem.backup(which) }
    function backups(): string { return apiItem.backupList() }
    function restoreBackup(file: string, open: string): string { return apiItem.restoreBackup(file, open) }
    function appVersion(): string { return apiItem.appVersion() }
    function checkUpdate(): string { return apiItem.checkUpdate() }
    function releaseNotes(): string { return apiItem.releaseNotes() }
    function installUpdate(): string { return apiItem.installUpdate() }
    function status(): string {
      return JSON.stringify({
        open: root.windowOpen,
        hyprland: root.hyprStatus,
        takenShortcuts: root.takenBinds,
        folder: root.rootPath,
        profile: profilesItem.current ? profilesItem.current.name : "",
        version: root.version,
        updateAvailable: updatesItem.available,
        notebooks: storeItem.notebooks.length,
        pages: Object.keys(workspaceItem.index.pages).length,
        ready: storeItem.ready,
        connected: !!root.shell
      })
    }
  }

  Component.onCompleted: {
    try { ownManifest = JSON.parse(storeItem.readNow(pluginDir + "/manifest.json", 64 * 1024) || "null") } catch (e) { ownManifest = null }
    scheduleRegister()
    if (launcherEntry) launcherTimer.start()
    if (agentSkill) storeItem.linkSkill(skillDir)
    backupsTimer.start()
  }

  // The backups there, once the profiles are in.
  Timer { id: backupsTimer; interval: 2500; onTriggered: backupsItem.refresh() }
}
