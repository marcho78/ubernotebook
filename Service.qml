import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import "Defaults.js" as Defaults
import "Settings.js" as Settings
import "Scope.js" as Scope
import "Agent.js" as Agent
import "QuickQueue.js" as QuickQueue
import "Dates.js" as Dates

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
  // The skill, for any AI that can run commands on this computer: its text
  // (omarchy-shell uber-notebook skill), onto the clipboard, saved where you
  // say, or its folder shown (Settings → AI).
  function skillText() { return storeItem.readNow(skillPath, 1024 * 1024) || "" }
  function copySkill() {
    var t = skillText()
    if (t) storeItem.copyText(t)
    return t !== ""
  }
  function saveSkillCopy(done) {
    pickSavePath("uber-notebook-skill.md", function(to) {
      if (!to) { done("", ""); return }
      storeItem.copyFileTo(skillPath, to, function(ok, why) { done(ok ? to : "", ok ? "" : why || "it couldn't be saved there") })
    }, "document")
  }
  function showSkill() { Quickshell.execDetached(["/usr/bin/uwsm-app", "--", "/usr/bin/xdg-open", skillDir]) }

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
  // Times on the clock you chose (reminders' notifications too).
  readonly property bool twelveHour: settings.clock !== "24"
  onTwelveHourChanged: Dates.setTwelveHour(twelveHour)

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
  // The window closed: what couldn't be saved tried again, and if it still
  // can't be, said where you'll see it (it goes on trying).
  function windowClosed() {
    storeItem.retryUnsaved(function(left) {
      if (left > 0) storeItem.notify("Not saved yet", (left === 1 ? "A change" : left + " changes") + " to your notes couldn't be saved (is the disk full?). Uber Notebook keeps trying.", "", "")
    })
  }

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
    // Another notes folder (a profile, `set folder`): what's open is saved
    // first, where it was.
    if (changes && Object.prototype.hasOwnProperty.call(changes, "folder") && changes.folder !== settings.folder) {
      saveOpen()
      // (Quick notes still waiting for this one's Pages: into its Quick notes
      // notebook now, while it's open.)
      if (quickWaiting.length) flushQuick(true)
      // (What couldn't be saved, tried again where it was.)
      storeItem.retryUnsaved(null)
    }
    var next = Settings.clone(user)
    for (var key in changes) if (defaults && Object.prototype.hasOwnProperty.call(defaults, key)) next[key] = changes[key]
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
    // (The demo's folder is made in it, and it too if it isn't there yet.)
    dataFolder: Settings.resolveFolder(profilesItem.dataFolder, root.home, true)
    // (A new profile's folder is made if it isn't there; one opened before
    // isn't made again.)
    newProfile: profilesItem.current !== null && profilesItem.current.fresh === true
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
    storeItem.exec(storeItem.privateMkdir([mirrorPath]), function(ok) {
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
    // (The open profile's, always: an Inbox made is set as the setting,
    // never over this binding.)
    inbox: root.settings.inbox || ""
    noProfile: profilesItem.firstRun
    profiles: profilesItem
    settings: root.settings
    updates: updatesItem
    backups: backupsItem
    agentScope: root.agentScope
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
    // (Only the entry as it was written: one changed or put there since is left.)
    if (launcherEntry && launcherText) Quickshell.execDetached(stopRunner().concat(["remove-owned", desktopFile, launcherText]))
    if (agentSkill) storeItem.unlinkSkill(skillDir, stopRunner())
    // Writes from here on finish before the shell goes on stopping.
    storeItem.stopping = true
    if (ui && typeof ui.saveNow === "function") ui.saveNow()
    workspaceItem.flush()
    storeItem.flush()
    if (hyprIntegration)
      Quickshell.execDetached(["/usr/bin/hyprctl", "eval",
        hyprText ? Settings.hyprRegistrationText(hyprText, { remove: true }) : Settings.hyprRegistration(pluginDir + "/hypr/uber-notebook.lua", { remove: true })])
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
  // The open profile and its notes folder, as QuickQueue.js reads them.
  function quickState() {
    return { profile: profilesItem.current ? profilesItem.current.id : "", folder: storeItem.folder, home: storeItem.home,
      rootPath: storeItem.rootPath, switching: storeItem.switching, ready: storeItem.ready, blockedFolder: storeItem.blockedFolder }
  }
  // Why a quick note can't be kept now ("" when it can): the profile's
  // notes folder can't be used (a drive that can't keep files private, or
  // that's gone), or there's no profile known yet (the shell just started).
  // The note's window stays open with it, its words in it. (One being
  // opened, a switch a moment ago, is kept for it: QuickQueue.js.)
  function quickRefusal() {
    var s = quickState()
    if (QuickQueue.blocked(s)) return "Not saved: this profile's notes folder can't be used. Pick another folder (Settings, Profiles)"
    if (!s.profile) return "Not saved yet: your notes are still opening. Try again in a moment"
    return ""
  }
  // true once it's kept (written, or waiting for the profile it's made in);
  // false, and said, when it can't be: the note's window then stays open,
  // its words in it.
  function quick(text) { return keepQuick(text).ok }
  // The same, with what was said: { ok, said, waiting } (the quick command
  // answers with it).
  function keepQuick(text) {
    var value = String(text || "").trim()
    // (No profile yet: the window, to make one; a note isn't kept.)
    if (profilesItem.firstRun) { show({}); return { ok: value === "", said: (value ? "Not saved: " : "") + "Uber Notebook has no profile yet. Make one in its window" } }
    if (!value) {
      if (ui && typeof ui.openQuick === "function") ui.openQuick()
      return { ok: true, said: "" }
    }
    var s = quickState()
    var now = QuickQueue.now(s)
    if (now === "refuse") return quickSaid(false, quickRefusal())
    // (Its notes still opening, or Pages still loading when it goes there:
    // kept for that profile, written once they're open.)
    if (now === "wait" || (settings.quickTo !== "notebook" && !workspaceItem.loaded)) {
      quickWaiting = QuickQueue.add(quickWaiting, value, s.profile)
      quickTimer.restart()
      return { ok: true, waiting: true, said: "Kept: it's saved as soon as this profile's notes are open" }
    }
    return settings.quickTo === "notebook" ? quickToNotebook(value) : quickToPages(value)
  }
  // { ok, said }, said in the OSD (`quiet`: one that can't be kept yet, not).
  function quickSaid(ok, message, quiet) {
    if (ok) osd("\u{f082e}", message)
    else if (!quiet) osd("\u{f0028}", message)
    return { ok: ok, said: message }
  }

  // (`quiet`: one waiting, tried again: not said when it can't be yet.)
  function quickToNotebook(value, quiet) {
    if (storeItem.quickNote(value)) return quickSaid(true, "Saved to Quick notes")
    return quickSaid(false, quickRefusal() || "Not saved: Uber Notebook's notes aren't open yet", quiet)
  }

  // Into the Pages Inbox, once Pages has loaded (a note made before then
  // waits for it, with the profile it was made in; if Pages can't load, it
  // goes to that profile's Quick notes notebook, so it's never lost, and
  // never into another profile: QuickQueue.js).
  property var quickWaiting: []

  function quickToPages(value, quiet) {
    if (!workspaceItem.loaded) return quickSaid(false, quickRefusal() || "Not saved yet: Pages is still loading", quiet)
    var r = null
    try { r = JSON.parse(apiItem.quickPage(value)) } catch (e) { r = null }
    if (r && r.ok) { osd("\u{f0836}", "Saved to your Pages Inbox"); return { ok: true, said: "Saved to your Pages Inbox" } }
    if (storeItem.quickNote(value)) return quickSaid(true, "Saved to Quick notes (Pages: " + (r ? r.error : "couldn't save it") + ")")
    return quickSaid(false, quickRefusal() || "Not saved: Pages: " + (r ? r.error : "couldn't save it"), quiet)
  }

  // Those made in the profile open now, written, once its notes folder is
  // the one open and read (where Settings says; `notebook`: Pages can't be
  // waited for, a while gone by or the profile being left: its Quick notes
  // notebook). Any of another, kept till it's open again. One that can't be
  // written yet (its profile still loading) stays waiting, under its
  // profile, and is tried again: a note kept is never let go of before it's
  // written.
  function flushQuick(notebook) {
    quickTimer.stop()
    var id = QuickQueue.openProfile(quickState())
    var toPages = !notebook && settings.quickTo !== "notebook"
    if (id && (!toPages || workspaceItem.loaded))
      quickWaiting = QuickQueue.flush(quickWaiting, id, function(v) { return (toPages ? root.quickToPages(v, true) : root.quickToNotebook(v, true)).ok })
    var mine = profilesItem.current ? profilesItem.current.id : ""
    if (mine && QuickQueue.take(quickWaiting, mine).mine.length) quickTimer.restart()
  }

  Connections {
    target: workspaceItem
    function onLoadedChanged() { if (workspaceItem.loaded && root.quickWaiting.length) root.flushQuick(false) }
  }

  Connections {
    target: storeItem
    // (Its notes folder open and read: those waiting for it written, once
    // what Store does first is done: a new demo's first notebook.)
    function onReadyChanged() { if (storeItem.ready && root.quickWaiting.length) Qt.callLater(root.flushQuick, false) }
    // (Its folder can't be used after all: those waiting for it given back
    // to you, in the quick-note card with why, not kept where a restart
    // would lose them; with no window, they wait on, said.)
    function onBlockedFolderChanged() { Qt.callLater(root.giveBackQuick) }
  }
  function giveBackQuick() {
    var s = quickState()
    if (!QuickQueue.blocked(s)) return
    var t = QuickQueue.take(quickWaiting, s.profile)
    if (!t.mine.length) return
    if (ui && typeof ui.holdQuick === "function") {
      quickWaiting = t.rest
      ui.holdQuick(t.mine.join("\n\n"), quickRefusal())
    } else osd("\u{f0028}", "A quick note is waiting: this profile's notes folder can't be used. Pick another folder (Settings, Profiles)")
  }

  Timer {
    id: quickTimer
    interval: 10000
    onTriggered: root.flushQuick(true)
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
  function pickSavePath(name, done, kind) {
    if (ui && typeof ui.pickSavePath === "function") ui.pickSavePath(name, done, kind || "")
    else done("")
  }

  function osd(icon, message) {
    Quickshell.execDetached(["/usr/bin/omarchy-shell", "-q", "osd", "show",
      JSON.stringify({ icon: icon, message: String(message).slice(0, 120), duration: 1400 })])
  }

  // ---- in the app launcher ----------------------------------------------------------------------
  //
  // An entry in ~/.local/share/applications, so Uber Notebook is in the Omarchy
  // launcher (and any other) with its icon, like an app. It's made when
  // Uber Notebook starts and taken out when it stops, so turning Uber Notebook off (or
  // removing it) leaves nothing behind. Only ever its own: it's made only where
  // there's nothing of that name, and taken out only if it's exactly what was
  // made (the archive helper's create-owned and remove-owned).

  readonly property string desktopFile: home + "/.local/share/applications/marcho78-uber-notebook.desktop"
  // What was made (or found there, the same), to take out when it stops.
  property string launcherText: ""

  Timer {
    id: launcherTimer
    // After a reloaded predecessor has taken its entry out.
    interval: 1200
    onTriggered: {
      var entry = Settings.desktopEntry(root.pluginDir)
      if (!entry) return
      storeItem.exec(["/usr/bin/mkdir", "-p", "--", root.home + "/.local/share/applications"], function(ok) {
        if (!ok) return
        storeItem.helper(["create-owned", root.desktopFile, entry], function(made, out) {
          var r = String(out || "").trim()
          if (made && (r === "made" || r === "same")) { root.launcherText = entry; return }
          // (One Uber Notebook left from another place, the same but for its
          // icon's, which is gone: taken out, if it's still that, and made
          // again. One you changed is left.)
          var there = storeItem.readNow(root.desktopFile, 8192) || ""
          var icon = /^Icon=(\/[^\n]*)$/m.exec(there)
          if (r !== "taken" || !icon || there.replace(/^Icon=.*$/m, "") !== entry.replace(/^Icon=.*$/m, "")) return
          storeItem.exec(["/usr/bin/test", "-e", icon[1]], function(iconThere) {
            if (iconThere) return
            storeItem.helper(["remove-owned", root.desktopFile, there], function() {
              storeItem.helper(["create-owned", root.desktopFile, entry], function(made2, out2) {
                if (made2 && String(out2 || "").trim() === "made") root.launcherText = entry
              }, { timeoutMs: 5000, maxBytes: 4096 })
            }, { timeoutMs: 5000, maxBytes: 4096 })
          }, { okCodes: [0, 1], timeoutMs: 3000 })
        }, { timeoutMs: 5000, maxBytes: 4096 })
      })
    }
  }

  // ---- IPC --------------------------------------------------------------------------------------

  // While an agent works in Uber Notebook's panel (DocView), what it may do
  // through the commands below: Scope.js. null the rest of the time.
  property var agentScope: null
  // (`agent`: its name, `id`: which it is, claude, grok or codex: Permissions.js.)
  // (`pictures`: Grok's image tool saves what it makes in its own session for
  // this conversation; a picture from there may go on a page too.)
  function beginAgentScope(agent, dir, id, grants, talk) {
    var grokHome = /^\//.test(String(Quickshell.env("GROK_HOME") || "")) ? String(Quickshell.env("GROK_HOME")) : storeItem.home + "/.grok"
    var pictures = String(id || "") === "grok" ? [Agent.grokPictures(grokHome, String(dir || ""))].filter(function(p) { return p !== "" }) : []
    agentScope = { agent: String(agent || "An agent"), id: String(id || ""), dir: String(dir || ""), pictures: pictures, frozen: false, grants: grants && typeof grants === "object" ? grants : {}, talk: String(talk || "") }
  }
  function endAgentScope() { agentScope = null }
  // A command, from you (`forAgent` false: uber-notebook, a script's or a
  // terminal's agent's too: as always) or from the panel's agent
  // (uber-notebook-agent: as Scope.js says while it works, none otherwise),
  // the Api told which while it runs.
  // (A file from outside its folders, and nothing else in the way: you're
  // asked in the panel, and it's done when you say yes: Api.askForFiles.)
  function scoped(forAgent, command, args, run) {
    var why = Scope.forCaller(forAgent, agentScope, command, args)
    if (why) {
      var outside = forAgent ? Scope.outsideFiles(agentScope, command, args) : null
      if (outside && outside.length && Scope.check(Scope.withApproved(agentScope, outside), command, args) === "") {
        return apiItem.askForFiles(agentScope, outside, run)
      }
      return JSON.stringify({ ok: false, error: why })
    }
    apiItem.caller = forAgent ? agentScope : null
    try { return run() } finally { apiItem.caller = null }
  }

  // The commands, under two names: uber-notebook (yours, a script's, a
  // terminal's agent's: as always) and uber-notebook-agent (the panel's
  // agent's: Scope.js), each made from this one handler.
  Instantiator {
    model: [{ name: "uber-notebook", agent: false }, { name: "uber-notebook-agent", agent: true }]
    // (Which one it is kept beside the handler, not on it: what's on an
    // IpcHandler goes out over IPC, and these can't.)
    delegate: QtObject {
      id: commands
      required property var modelData
      readonly property bool agent: modelData.agent
      readonly property IpcHandler handler: IpcHandler {
        target: commands.modelData.name

        function toggle(): void { root.toggle({}) }
        function show(): void { if (!root.windowOpen) root.show({}) }
        function hide(): void { root.hide() }
        // uber-notebook quick            opens the quick-note card
        // uber-notebook quick "Buy milk"  saves it straight away
        // ({ ok, note }, waiting: true if its profile's notes are still
        // opening; or { ok: false, error }: not kept, said why.)
        function quick(text: string): string {
          if (commands.agent) return JSON.stringify({ ok: false, error: "not for the panel's agent: quick notes are yours" })
          var r = root.keepQuick(String(text || "").slice(0, 20000))
          if (!r.ok) return JSON.stringify({ ok: false, error: r.said || "not saved" })
          return JSON.stringify(r.waiting ? { ok: true, waiting: true, note: r.said } : { ok: true, note: r.said || "the quick-note card is open" })
        }
        function search(text: string): void { root.show({ search: String(text || "").slice(0, 200) }) }
        function shelf(): void { root.show({ shelf: true }) }
        // uber-notebook pages: straight to Pages.
        function pages(): void { root.show({ pages: true }) }
        // The calendar, on a day ("" is today).
        function calendar(day: string): void { root.show({ calendar: /^\d{4}-\d{2}-\d{2}$/.test(String(day || "")) ? String(day) : "today" }) }
        // uber-notebook importNotes ~/notes: files or a folder (a Notion or Obsidian export) into Pages.
        // (Right after a profile switch, its notes still opening: not
        // imported, said; never into the profile before.)
        function importNotes(path: string): string {
          if (commands.agent) return JSON.stringify({ ok: false, error: "not for the panel's agent: importing is yours" })
          var p = String(path || "")
          if (p.indexOf("~/") === 0) p = root.home + p.slice(1)
          var said = ""
          workspaceItem.importPaths([p], "", function(r) {
            said = r.unready ? "Not imported: your notes are still opening. Try again in a moment"
              : r.stopped ? "Not imported: another profile was opened"
              : r.pages ? "Imported " + r.pages + (r.pages === 1 ? " page" : " pages") + " into Pages" : "Nothing to import there"
            root.osd("\u{f0e27}", said)
          })
          // (Done or refused at once, said; else on its way: the OSD says how it went.)
          if (said) return JSON.stringify(said.indexOf("Imported") === 0 ? { ok: true, note: said } : { ok: false, error: said })
          return JSON.stringify({ ok: true, note: "importing: the OSD says how it went" })
        }
        // uber-notebook open <page id>: a page in Pages (a reminder's notification does this).
        function open(id: string): void { if (/^[0-9a-f-]{36}$/.test(String(id || ""))) root.show({ page: String(id) }) }
        function settings(): void { root.show({ settings: true }) }
        // omarchy-shell uber-notebook set paper grid   (values are checked like the settings panel's)
        function set(key: string, value: string): string {
          if (commands.agent) return "not for the panel's agent: Uber Notebook's settings are yours"
          if (!root.defaults || !Object.prototype.hasOwnProperty.call(root.defaults, key)) return "unknown setting"
          var parsed = value
          if (value === "true" || value === "false") parsed = value === "true"
          else if (/^-?\d{1,6}$/.test(value)) parsed = Number(value)
          root.setSetting(key, parsed)
          return JSON.stringify(root.settings[key])
        }
        function reset(): void { if (!commands.agent) root.resetSettings() }
        // omarchy-shell uber-notebook mirror: the Markdown copy made up to date now, and how it is.
        function mirror(): string {
          if (commands.agent) return JSON.stringify({ ok: false, error: "not for the panel's agent: the Markdown copy is yours to make" })
          if (!mirrorItem.on) return JSON.stringify({ ok: false, error: "the Markdown copy is off: omarchy-shell uber-notebook set mirror true" })
          mirrorItem.sync()
          return JSON.stringify({ ok: !mirrorItem.problem, folder: root.mirrorPath, status: mirrorItem.status, files: mirrorItem.files })
        }

        // For AI agents and scripts: pages in and out, answered in JSON
        // (omarchy-shell uber-notebook help lists them; Api.qml does them).
        function help(): string { return root.scoped(commands.agent, "help", [], function() { return apiItem.help() }) }
        function list(): string { return root.scoped(commands.agent, "list", [], function() { return apiItem.list() }) }
        function find(words: string): string { return root.scoped(commands.agent, "find", [words], function() { return apiItem.find(words) }) }
        function read(id: string): string { return root.scoped(commands.agent, "read", [id], function() { return apiItem.read(id) }) }
        function add(title: string, file: string): string { return root.scoped(commands.agent, "add", [title, file], function() { return apiItem.add(title, file) }) }
        function addTo(page: string, title: string, file: string): string { return root.scoped(commands.agent, "addTo", [page, title, file], function() { return apiItem.addTo(page, title, file) }) }
        function append(id: string, file: string): string { return root.scoped(commands.agent, "append", [id, file], function() { return apiItem.append(id, file) }) }
        function blocks(id: string): string { return root.scoped(commands.agent, "blocks", [id], function() { return apiItem.blocks(id) }) }
        function tags(): string { return root.scoped(commands.agent, "tags", [], function() { return apiItem.tags() }) }
        function library(kind: string, words: string): string { return root.scoped(commands.agent, "library", [kind, words], function() { return apiItem.library(kind, words) }) }
        function contacts(words: string): string { return root.scoped(commands.agent, "contacts", [words], function() { return apiItem.contacts(words) }) }
        function contact(which: string): string { return root.scoped(commands.agent, "contact", [which], function() { return apiItem.contact(which) }) }
        function addContact(name: string, phone: string, email: string): string { return root.scoped(commands.agent, "addContact", [name, phone, email], function() { return apiItem.addContact(name, phone, email) }) }
        function importContacts(file: string): string { return root.scoped(commands.agent, "importContacts", [file], function() { return apiItem.importContacts(file) }) }
        function tagged(tag: string): string { return root.scoped(commands.agent, "tagged", [tag], function() { return apiItem.tagged(tag) }) }
        function tagColor(tag: string, color: string): string { return root.scoped(commands.agent, "tagColor", [tag, color], function() { return apiItem.tagColor(tag, color) }) }
        function projects(): string { return root.scoped(commands.agent, "projects", [], function() { return apiItem.projects() }) }
        function templates(): string { return root.scoped(commands.agent, "templates", [], function() { return apiItem.templates() }) }
        function events(from: string, to: string): string { return root.scoped(commands.agent, "events", [from, to], function() { return apiItem.events(from, to) }) }
        function addEvent(what: string, repeat: string): string { return root.scoped(commands.agent, "addEvent", [what, repeat], function() { return apiItem.addEvent(what, repeat) }) }
        function removeEvent(id: string): string { return root.scoped(commands.agent, "removeEvent", [id], function() { return apiItem.removeEvent(id) }) }
        function fromTemplate(template: string, title: string, parent: string): string { return root.scoped(commands.agent, "fromTemplate", [template, title, parent], function() { return apiItem.fromTemplate(template, title, parent) }) }
        function project(id: string, status: string, due: string): string { return root.scoped(commands.agent, "project", [id, status, due], function() { return apiItem.project(id, status, due) }) }
        function archive(id: string): string { return root.scoped(commands.agent, "archive", [id], function() { return apiItem.archive(id, true) }) }
        function unarchive(id: string): string { return root.scoped(commands.agent, "unarchive", [id], function() { return apiItem.archive(id, false) }) }
        function replace(page: string, block: string, file: string): string { return root.scoped(commands.agent, "replace", [page, block, file], function() { return apiItem.replace(page, block, file) }) }
        function insertAfter(page: string, block: string, file: string): string { return root.scoped(commands.agent, "insertAfter", [page, block, file], function() { return apiItem.insertAfter(page, block, file) }) }
        function trash(id: string): string { return root.scoped(commands.agent, "trash", [id], function() { return apiItem.trash(id) }) }
        function rename(id: string, title: string): string { return root.scoped(commands.agent, "rename", [id, title], function() { return apiItem.rename(id, title) }) }
        function move(id: string, parent: string, position: string): string { return root.scoped(commands.agent, "move", [id, parent, position], function() { return apiItem.move(id, parent, position) }) }
        function icon(id: string, emoji: string): string { return root.scoped(commands.agent, "icon", [id, emoji], function() { return apiItem.icon(id, emoji) }) }
        function cover(id: string, cover: string): string { return root.scoped(commands.agent, "cover", [id, cover], function() { return apiItem.cover(id, cover) }) }
        function lock(id: string, on: string): string { return root.scoped(commands.agent, "lock", [id, on], function() { return apiItem.lock(id, on) }) }
        function favorite(id: string, on: string): string { return root.scoped(commands.agent, "favorite", [id, on], function() { return apiItem.favorite(id, on) }) }
        function trashed(): string { return root.scoped(commands.agent, "trashed", [], function() { return apiItem.trashed() }) }
        function restore(id: string): string { return root.scoped(commands.agent, "restore", [id], function() { return apiItem.restore(id) }) }
        function duplicate(id: string): string { return root.scoped(commands.agent, "duplicate", [id], function() { return apiItem.duplicate(id) }) }
        function makeTemplate(id: string): string { return root.scoped(commands.agent, "makeTemplate", [id], function() { return apiItem.makeTemplate(id) }) }
        function history(id: string): string { return root.scoped(commands.agent, "history", [id], function() { return apiItem.history(id) }) }
        function version(id: string, name: string): string { return root.scoped(commands.agent, "version", [id, name], function() { return apiItem.version(id, name) }) }
        function restoreVersion(id: string, name: string): string { return root.scoped(commands.agent, "restoreVersion", [id, name], function() { return apiItem.restoreVersion(id, name) }) }
        function check(page: string, block: string, on: string): string { return root.scoped(commands.agent, "check", [page, block, on], function() { return apiItem.check(page, block, on) }) }
        function color(page: string, block: string, color: string): string { return root.scoped(commands.agent, "color", [page, block, color], function() { return apiItem.color(page, block, color) }) }
        function removeBlock(page: string, block: string): string { return root.scoped(commands.agent, "removeBlock", [page, block], function() { return apiItem.removeBlock(page, block) }) }
        function board(page: string, block: string, action: string, a: string, b: string): string { return root.scoped(commands.agent, "board", [page, block, action, a, b], function() { return apiItem.board(page, block, action, a, b) }) }
        function attach(page: string, file: string): string { return root.scoped(commands.agent, "attach", [page, file], function() { return apiItem.attach(page, file) }) }
        function bookmark(page: string, url: string): string { return root.scoped(commands.agent, "bookmark", [page, url], function() { return apiItem.bookmark(page, url) }) }
        function editEvent(id: string, field: string, value: string): string { return root.scoped(commands.agent, "editEvent", [id, field, value], function() { return apiItem.editEvent(id, field, value) }) }
        function editContact(which: string, field: string, value: string): string { return root.scoped(commands.agent, "editContact", [which, field, value], function() { return apiItem.editContact(which, field, value) }) }
        function removeContact(id: string): string { return root.scoped(commands.agent, "removeContact", [id], function() { return apiItem.removeContact(id) }) }
        function importCalendar(file: string): string { return root.scoped(commands.agent, "importCalendar", [file], function() { return apiItem.importCalendar(file) }) }
        function picture(page: string, block: string, width: string, align: string): string { return root.scoped(commands.agent, "picture", [page, block, width, align], function() { return apiItem.picture(page, block, width, align) }) }
        function addGallery(page: string, pictures: string, columns: string): string { return root.scoped(commands.agent, "addGallery", [page, pictures, columns], function() { return apiItem.addGallery(page, pictures, columns) }) }
        function gallery(page: string, block: string, action: string, a: string, b: string): string { return root.scoped(commands.agent, "gallery", [page, block, action, a, b], function() { return apiItem.gallery(page, block, action, a, b) }) }
        function setLink(page: string, block: string, link: string): string { return root.scoped(commands.agent, "setLink", [page, block, link], function() { return apiItem.setLink(page, block, link) }) }
        function describeTemplate(template: string, text: string): string { return root.scoped(commands.agent, "describeTemplate", [template, text], function() { return apiItem.describeTemplate(template, text) }) }
        function addTemplate(title: string, file: string, description: string): string { return root.scoped(commands.agent, "addTemplate", [title, file, description], function() { return apiItem.addTemplate(title, file, description) }) }
        function preferences(): string { return root.scoped(commands.agent, "preferences", [], function() { return apiItem.preferences() }) }
        function renameTag(tag: string, to: string): string { return root.scoped(commands.agent, "renameTag", [tag, to], function() { return apiItem.renameTag(tag, to) }) }
        function removeTag(tag: string): string { return root.scoped(commands.agent, "removeTag", [tag], function() { return apiItem.removeTag(tag) }) }
        function notebooks(): string { return root.scoped(commands.agent, "notebooks", [], function() { return apiItem.notebooks() }) }
        function notebook(id: string): string { return root.scoped(commands.agent, "notebook", [id], function() { return apiItem.notebook(id) }) }
        function readNotebook(id: string, page: string): string { return root.scoped(commands.agent, "readNotebook", [id, page], function() { return apiItem.readNotebook(id, page) }) }
        function addToNotebook(id: string, file: string): string { return root.scoped(commands.agent, "addToNotebook", [id, file], function() { return apiItem.addToNotebook(id, file) }) }
        // omarchy-shell uber-notebook profiles: [{ id, name, folder, open, demo }].
        function profiles(): string { return root.scoped(commands.agent, "profiles", [], function() { return apiItem.profileList() }) }
        // omarchy-shell uber-notebook profile Business: another profile open (its name or id).
        function profile(which: string): string { return root.scoped(commands.agent, "profile", [which], function() { return apiItem.openProfile(which) }) }
        function addProfile(name: string, folder: string, open: string): string { return root.scoped(commands.agent, "addProfile", [name, folder, open], function() { return apiItem.addProfile(name, folder, open) }) }
        function renameProfile(which: string, name: string): string { return root.scoped(commands.agent, "renameProfile", [which, name], function() { return apiItem.renameProfile(which, name) }) }
        function profileFolder(which: string, folder: string): string { return root.scoped(commands.agent, "profileFolder", [which, folder], function() { return apiItem.profileFolder(which, folder) }) }
        function removeProfile(which: string): string { return root.scoped(commands.agent, "removeProfile", [which], function() { return apiItem.removeProfile(which) }) }
        function demo(): string { return root.scoped(commands.agent, "demo", [], function() { return apiItem.demo(false) }) }
        function restartDemo(): string { return root.scoped(commands.agent, "restartDemo", [], function() { return apiItem.demo(true) }) }
        function backup(which: string): string { return root.scoped(commands.agent, "backup", [which], function() { return apiItem.backup(which) }) }
        function backups(): string { return root.scoped(commands.agent, "backups", [], function() { return apiItem.backupList() }) }
        function restoreBackup(file: string, open: string): string { return root.scoped(commands.agent, "restoreBackup", [file, open], function() { return apiItem.restoreBackup(file, open) }) }
        function appVersion(): string { return root.scoped(commands.agent, "appVersion", [], function() { return apiItem.appVersion() }) }
        // omarchy-shell uber-notebook skill: Uber Notebook's skill, for any AI.
        function skill(): string { return root.scoped(commands.agent, "skill", [], function() { return root.skillText() || JSON.stringify({ ok: false, error: "the skill couldn't be read" }) }) }
        function checkUpdate(): string { return root.scoped(commands.agent, "checkUpdate", [], function() { return apiItem.checkUpdate() }) }
        function releaseNotes(): string { return root.scoped(commands.agent, "releaseNotes", [], function() { return apiItem.releaseNotes() }) }
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
    }
  }

  // What it takes itself out with as it stops (its launcher entry, its
  // skill's links, its Hyprland shortcuts), read now, while its folder is
  // here: `omarchy plugin remove` moves the folder away as soon as it's
  // unloaded, before what's started as it stops has read anything there.
  property string helperText: ""
  property string hyprText: ""
  function stopRunner() {
    return helperText ? ["/usr/bin/python3", "-I", "-S", "-c", helperText] : ["/usr/bin/python3", "-I", "-S", storeItem.filesHelper]
  }

  Component.onCompleted: {
    Dates.setTwelveHour(twelveHour)
    try { ownManifest = JSON.parse(storeItem.readNow(pluginDir + "/manifest.json", 64 * 1024) || "null") } catch (e) { ownManifest = null }
    helperText = storeItem.readNow(storeItem.filesHelper, 512 * 1024) || ""
    hyprText = storeItem.readNow(pluginDir + "/hypr/uber-notebook.lua", 256 * 1024) || ""
    scheduleRegister()
    if (launcherEntry) launcherTimer.start()
    if (agentSkill) storeItem.linkSkill(skillDir)
    backupsTimer.start()
  }

  // The backups there, once the profiles are in.
  Timer { id: backupsTimer; interval: 2500; onTriggered: backupsItem.refresh() }
}
