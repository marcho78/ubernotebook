import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Settings.js" as Settings
import "../../Backups.js" as Backups

// Settings in sections (each its own; the list at the left), the sidebar's
// foot (who makes Uber Notebook, on X; a newer version, a click from its notes),
// the update check (up to date, a newer one, none yet, GitHub out of reach;
// updating, or the command to copy), and backups: made (this profile, all
// of them; the backup folder left out), listed, automatic ones (the oldest
// cleared out, never yours), put back as new profiles (from the list, a
// file, the first run), and refused when a file isn't one. And the same
// for agents.
Item {
  id: root
  width: 1320
  height: 900

  FakeStore { id: store }
  FakeService { id: service; store: files; user: ({ sounds: false }); profiles: profiles; updates: updates; backups: backups }
  FakeFiles { id: files; rootPath: profiles.current !== null ? Settings.resolveFolder(service.settings.folder, "/tmp", true) : "" }
  UberNotebook.Profiles { id: profiles; service: service; files: files; dataFolder: "/tmp/uber-notebook-data" }
  UberNotebook.Workspace {
    id: ws
    files: files
    starter: "templates"
  }
  UberNotebook.Updates {
    id: updates
    files: files
    current: "1.0.0"
    homepage: "https://github.com/marcho78/omanote"
    pluginDir: "/tmp/uber-notebook-plugin"
    pluginId: "marcho78.uber-notebook"
    automatic: false
  }
  UberNotebook.Backups { id: backups; service: service; files: files; profiles: profiles; version: "1.0.0" }
  UberNotebook.Api { id: api; workspace: ws; files: files; profiles: profiles; noProfile: profiles.firstRun; updates: updates; backups: backups }

  App {
    id: app
    anchors.fill: parent
    store: store
    workspace: ws
    service: service
    background: "#eeeae2"
    foreground: "#2b2a28"
    accent: "#c05a36"
  }

  readonly property string releases: "https://api.github.com/repos/marcho78/omanote/releases?per_page=30"

  TestCase {
    name: "Settings"
    when: windowShown

    function find(item, test) {
      if (!item) return null
      if (item.visible && test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function findAll(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) findAll(item.children[i], test, out)
      return out
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function all(item, name) { return findAll(item, function(it) { return it.objectName === name }, []) }
    function win() { return root.Window.window.contentItem }
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function panel() { return named(win(), "settingsFlick") }
    // (Scrolled to it, in the settings, if it's further down.)
    function reach(item) {
      var f = panel()
      if (f && item) {
        var y = item.mapToItem(f.contentItem, 0, 0).y
        if (y + item.height > f.contentY + f.height || y < f.contentY) f.contentY = Math.max(0, Math.min(f.contentHeight - f.height, y - 40))
        wait(80)
      }
      return item
    }
    function section(id) {
      click(named(win(), "settingsSection_" + id))
      tryCompare(named(win(), "settingsTitle"), "text", id.charAt(0).toUpperCase() + id.slice(1), 1000)
    }

    // Two profiles, with notes; Pages open.
    function fresh() {
      files.reset()
      files.disk["/tmp/Notes/Personal/library.json"] = "{\"notebooks\":[]}"
      files.disk["/tmp/Notes/Personal/Pages/one.json"] = "{\"page\":1}"
      files.disk["/tmp/Notes/Work/Pages/w.json"] = "{\"work\":1}"
      service.user = ({ sounds: false, profile: "p-1", folder: "~/Notes/Personal", inbox: "inbox-1",
        profiles: [{ id: "p-1", name: "Personal", folder: "~/Notes/Personal", saved: {} }, { id: "p-2", name: "Work", folder: "~/Notes/Work", saved: { lastPage: "w" } }] })
      profiles.settled = true
      backups.list = []
      backups.note = ""
      backups.working = ""
      updates.status = "idle"
      updates.newer = []
      updates.installing = ""
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      app.showSpace("pages")
      app.docView.activate()
      // (What Pages focuses as it opens, given it first.)
      wait(250)
    }
    function closeAll() {
      if (app.settingsPopup.opened) keyClick(Qt.Key_Escape)
      tryVerify(function() { return !app.settingsPopup.opened }, 1000, "Esc closes it")
      app.releaseNotesPopup.close()
      wait(100)
    }

    function test_1_in_sections() {
      fresh()
      app.openSettings("general")
      tryVerify(function() { return panel() !== null }, 1000)
      verify(named(win(), "scrollSpeed_faster") !== null, "General: scrolling")
      compare(named(win(), "appearanceSwatch_colorPage"), null, "not another section's")
      click(named(win(), "scrollSpeed_faster"))
      compare(service.settings.scrollSpeed, "faster")
      section("appearance")
      verify(named(win(), "appearanceSwatch_colorPage") !== null)
      compare(named(win(), "scrollSpeed_faster"), null)
      section("writing")
      section("audio")
      verify(named(win(), "micPicker") !== null)
      section("profiles")
      compare(all(win(), "settingsProfile").length, 2)
      section("backups")
      verify(named(win(), "backupNow") !== null)
      section("about")
      verify(named(win(), "updateCheck") !== null)
      // On X, from About.
      click(named(win(), "aboutX"))
      verify(files.opened.indexOf("https://x.com/devsec_ai") >= 0)
      closeAll()
      // Opened again: where it was.
      app.openSettings("")
      tryCompare(named(win(), "settingsTitle"), "text", "About", 1000)
      closeAll()
    }

    function test_2_the_foot_of_the_sidebar() {
      fresh()
      var foot = named(win(), "sidebarFooter")
      verify(foot !== null)
      compare(named(foot, "footerUpdate"), null, "no newer version: nothing said")
      files.opened = []
      click(named(foot, "footerX"))
      compare(files.opened[0], "https://x.com/devsec_ai")
      // And the shelf's corner.
      app.showSpace("notebooks")
      wait(100)
      verify(named(win(), "shelfFooter") !== null)
      app.showSpace("pages")
    }

    function test_3_a_newer_version() {
      fresh()
      files.http[root.releases] = { code: 200, body: JSON.stringify([
        { tag_name: "v1.1.0", name: "Spring", body: "Better **search**.\n\n![shot](https://x.example/a.png)", html_url: "https://github.com/marcho78/omanote/releases/tag/v1.1.0", published_at: "2026-11-01T10:00:00Z" },
        { tag_name: "v1.0.0", body: "First" }
      ]) }
      updates.check()
      tryCompare(updates, "status", "available", 1000)
      compare(updates.latest.version, "1.1.0")
      // The sidebar says so; a click: what's new.
      var line = null
      tryVerify(function() { line = named(win(), "footerUpdate"); return line !== null }, 1000)
      click(line)
      var notes = app.releaseNotesPopup
      tryVerify(function() { return notes.opened }, 1000)
      compare(named(notes.contentItem, "releaseNotesTitle").text, "What's new in 1.1.0")
      var md = named(notes.contentItem, "releaseNotesText").text
      verify(md.indexOf("Better **search**.") >= 0, md)
      verify(md.indexOf("x.example") < 0, "no pictures fetched")
      // Not from git: the command, to copy.
      compare(named(notes.contentItem, "releaseNotesUpdate"), null)
      click(named(notes.contentItem, "releaseNotesCopy"))
      compare(files.copied, "omarchy plugin update marcho78.uber-notebook")
      click(named(notes.contentItem, "releaseNotesGitHub"))
      verify(files.opened.indexOf("https://github.com/marcho78/omanote/releases/tag/v1.1.0") >= 0)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !notes.opened }, 1000, "Esc closes it")
      // From git: Update now.
      updates.managed = true
      app.showReleaseNotes()
      tryVerify(function() { return notes.opened }, 1000)
      click(named(notes.contentItem, "releaseNotesUpdate"))
      tryCompare(files, "installed", ["marcho78.uber-notebook"], 1000)
      keyClick(Qt.Key_Escape)
      updates.managed = false
      // Settings: About has a dot, and says it.
      app.openSettings("about")
      tryVerify(function() { return panel() !== null }, 1000)
      var status = named(win(), "updateStatus")
      verify(status.note.indexOf("Version 1.1.0 is available") === 0, status.note)
      verify(named(win(), "settingsSection_about").children.some(function(c) { return c.visible && c.width === 7 }), "a dot by About")
      verify(named(win(), "updateNotes") !== null)
      closeAll()
    }

    function test_4_up_to_date_none_yet_out_of_reach() {
      fresh()
      files.http[root.releases] = { code: 200, body: JSON.stringify([{ tag_name: "v1.0.0", body: "First" }]) }
      updates.check()
      tryCompare(updates, "status", "current", 1000)
      verify(!updates.available)
      compare(named(win(), "footerUpdate"), null)
      // Up to date: the notes of the version running, from CHANGELOG.md.
      files.disk["/tmp/uber-notebook-plugin/CHANGELOG.md"] = "# Changelog\n\n## 1.0.0 - Unreleased\n\nThe first version.\n"
      compare(updates.notes().markdown, "The first version.")
      compare(updates.notes().title, "What's in 1.0.0")
      files.http[root.releases] = { code: 404, body: "{\"message\":\"Not Found\"}" }
      updates.check()
      tryCompare(updates, "status", "none", 1000)
      files.http = ({})
      updates.check()
      tryCompare(updates, "status", "failed", 1000)
      verify(/Couldn't reach GitHub/.test(updates.problem), updates.problem)
      files.http[root.releases] = { code: 403, body: "{}" }
      updates.check()
      tryCompare(updates, "status", "failed", 1000)
      verify(/later/.test(updates.problem))
      // Off in Settings: the toggle.
      app.openSettings("about")
      tryVerify(function() { return panel() !== null }, 1000)
      click(named(win(), "updateAuto"))
      compare(service.settings.checkUpdates, false)
      closeAll()
    }

    function test_5_backups_made_and_listed() {
      fresh()
      app.openSettings("backups")
      tryVerify(function() { return panel() !== null }, 1000)
      click(reach(named(win(), "backupNow")))
      tryVerify(function() { return backups.list.length === 1 }, 2000, "made, and listed")
      var b = backups.list[0]
      verify(/^Uber Notebook Personal \d{4}-\d{2}-\d{2} \d{4}\.tar\.gz$/.test(b.name), b.name)
      compare(b.path, "/tmp/Documents/Uber Notebook Backups/" + b.name, "in the backup folder")
      var held = JSON.parse(String(files.disk[b.path]).slice(9))
      compare(held.manifest.profiles.map(function(p) { return p.name }), ["Personal"])
      compare(held.manifest.profiles[0].saved.inbox, "inbox-1", "with its Inbox")
      compare(held.files.p1["Pages/one.json"], "{\"page\":1}")
      verify(service.savedOpen > 0, "what's open written first")
      tryVerify(function() { return all(win(), "backupRow").length === 1 }, 1000)
      // All of them.
      click(reach(named(win(), "backupAll")))
      tryVerify(function() { return backups.list.length === 2 }, 2000)
      var both = JSON.parse(String(files.disk[backups.list.filter(function(x) { return /All profiles/.test(x.name) })[0].path]).slice(9))
      compare(both.manifest.profiles.map(function(p) { return p.name }), ["Personal", "Work"])
      compare(both.files.p2["Pages/w.json"], "{\"work\":1}")
      // The backup folder inside a profile's: left out.
      service.setSetting("backupFolder", "~/Notes/Personal/Backups")
      files.disk["/tmp/Notes/Personal/Backups/old.tar.gz"] = "an old one"
      var r = null
      backups.backUp("", false, function(x) { r = x })
      tryVerify(function() { return r !== null && r.ok }, 2000)
      held = JSON.parse(String(files.disk[r.path]).slice(9))
      verify(held.files.p1["Pages/one.json"] !== undefined)
      verify(Object.keys(held.files.p1).every(function(k) { return k.indexOf("Backups") !== 0 }), JSON.stringify(Object.keys(held.files.p1)))
      service.setSetting("backupFolder", "")
      // Nothing written in a profile yet: nothing to back up.
      service.setSettings({ profiles: profiles.shown.concat([{ id: "p-3", name: "Empty", folder: "~/Notes/Empty", saved: {} }]) })
      r = null
      backups.backUp("Empty", false, function(x) { r = x })
      tryVerify(function() { return r !== null }, 1000)
      verify(!r.ok && /nothing to back up/.test(r.error), r.error)
      closeAll()
    }

    function test_6_automatic_ones() {
      fresh()
      // Five automatic ones, a day apart, and one of yours, oldest of all.
      var dir = "/tmp/Documents/Uber Notebook Backups/"
      var day = 24 * 3600
      var t0 = Date.now() / 1000 - 10 * day
      files.disk[dir + "Uber Notebook Mine 2026-01-01 0900.tar.gz"] = "mine"
      files.mtimes[dir + "Uber Notebook Mine 2026-01-01 0900.tar.gz"] = t0 - day
      for (var i = 0; i < 5; i++) {
        var n = dir + "Uber Notebook 2026-09-0" + (i + 1) + " 0900 (automatic).tar.gz"
        files.disk[n] = "auto " + i
        files.mtimes[n] = t0 + i * day
      }
      backups.automaticNow()
      wait(300)
      compare(Object.keys(files.disk).filter(function(p) { return /\(automatic\)/.test(p) }).length, 5, "off: none made")
      service.setSettings({ backupEvery: "daily", backupKeep: 3 })
      backups.automaticNow()
      tryVerify(function() { return backups.list.filter(function(b) { return b.automatic }).length === 3 }, 2000, "made one, cleared the oldest out")
      verify(files.disk[dir + "Uber Notebook Mine 2026-01-01 0900.tar.gz"] !== undefined, "yours: never")
      verify(files.trashed.indexOf(dir + "Uber Notebook 2026-09-01 0900 (automatic).tar.gz") >= 0, "to the trash")
      var newest = backups.list.filter(function(b) { return b.automatic })[0]
      compare(JSON.parse(String(files.disk[newest.path]).slice(9)).manifest.profiles.length, 2, "every profile")
      // Not due again for a day.
      var count = backups.list.length
      backups.automaticNow()
      wait(300)
      compare(backups.list.length, count)
    }

    function test_7_put_back() {
      fresh()
      var made = null
      backups.backUp("all", false, function(x) { made = x })
      tryVerify(function() { return made !== null && made.ok }, 2000)
      app.openSettings("backups")
      tryVerify(function() { return panel() !== null }, 1000)
      tryVerify(function() { return all(win(), "backupRestore").length === 1 }, 1000)
      click(reach(all(win(), "backupRestore")[0]))
      var ask = null
      tryVerify(function() { ask = named(win(), "restoreAsk"); return ask !== null && ask.note.indexOf("Puts back") === 0 }, 1000)
      verify(ask.note.indexOf("“Personal”, “Work”") >= 0, ask.note)
      click(reach(named(win(), "restoreYes")))
      tryVerify(function() { return profiles.list.length === 4 }, 2000, "two new profiles")
      var names = profiles.list.map(function(p) { return p.name })
      compare(names.slice(2), ["Personal (restored)", "Work (restored)"], "their names taken: (restored)")
      var back = profiles.list[2]
      compare(back.folder, "~/Documents/Uber Notebook Personal (restored)")
      compare(back.saved.inbox, "inbox-1", "with its Inbox")
      compare(files.disk["/tmp/Documents/Uber Notebook Personal (restored)/Pages/one.json"], "{\"page\":1}")
      compare(files.disk["/tmp/Notes/Personal/Pages/one.json"], "{\"page\":1}", "what was there, as it was")
      compare(profiles.current.name, "Personal", "still the one that was open")
      // Again: new folders beside those.
      var again = null
      backups.restore(made.path, false, function(x) { again = x })
      tryVerify(function() { return again !== null && again.ok }, 2000)
      compare(again.restored[0].name, "Personal (restored 2)")
      compare(again.restored[0].folder, "~/Documents/Uber Notebook Personal (restored) 2")
      // Open one.
      var open = null
      tryVerify(function() { open = named(win(), "restoredOpen"); return open !== null }, 1000)
      click(reach(open))
      tryCompare(profiles.current, "name", "Personal (restored)", 1000)
      // A file that isn't a backup: said, nothing made.
      files.disk["/tmp/x.tar.gz"] = "something else"
      service.nextFile = "/tmp/x.tar.gz"
      app.openSettings("backups")
      tryVerify(function() { return panel() !== null }, 1000)
      click(reach(named(win(), "restoreFromFile")))
      compare(service.pickedKind, "backup")
      compare(service.pickedFrom, "/tmp/Documents/Uber Notebook Backups", "it opens in the backup folder")
      tryVerify(function() { ask = named(win(), "restoreAsk"); return ask !== null && ask.note.indexOf("isn't a backup") >= 0 }, 1000)
      compare(named(win(), "restoreYes"), null)
      compare(profiles.list.length, 6)
      closeAll()
    }

    function test_8_the_first_run_puts_one_back() {
      fresh()
      var made = null
      backups.backUp("", false, function(x) { made = x })
      tryVerify(function() { return made !== null && made.ok }, 2000)
      // A new computer: no profiles yet.
      service.user = ({ sounds: false })
      tryVerify(function() { return named(win(), "firstRun") !== null }, 1000)
      service.nextFile = made.path
      click(named(win(), "firstRunRestore"))
      tryVerify(function() { return !profiles.firstRun }, 2000, "put back, and open")
      compare(profiles.current.name, "Personal")
      compare(service.settings.folder, "~/Documents/Uber Notebook Personal (restored)")
      compare(service.settings.inbox, "inbox-1")
      tryVerify(function() { return named(win(), "firstRun") === null }, 1000)
    }

    // Settings → AI: your agent (Omarchy's default), and the model and
    // effort for each that works here.
    function test_10_ai() {
      fresh()
      files.agentList = [{ name: "claude", label: "Claude" }, { name: "codex", label: "Codex" }, { name: "gemini", label: "Gemini" }, { name: "grok", label: "Grok" }]
      files.agent = "gemini"
      files.disk["/tmp/.codex/models_cache.json"] = '{"models":[{"slug":"gpt-6-astra","display_name":"GPT-6-Astra","visibility":"list","priority":2,"default_reasoning_level":"medium","supported_reasoning_levels":[{"effort":"low"},{"effort":"medium"},{"effort":"high"},{"effort":"xhigh"},{"effort":"max"}]},{"slug":"gpt-5.5","display_name":"GPT-5.5","visibility":"list","priority":13,"default_reasoning_level":"medium","supported_reasoning_levels":[{"effort":"low"},{"effort":"medium"},{"effort":"high"},{"effort":"xhigh"}]}]}'
      files.disk["/tmp/.grok/models_cache.json"] = '{"models":{"grok-4.7":{"info":{"id":"grok-4.7","name":"Grok 4.7","description":"Latest","hidden":false,"reasoning_effort":"high","reasoning_efforts":[{"id":"xhigh","value":"xhigh"},{"id":"high","value":"high"},{"id":"medium","value":"medium"},{"id":"low","value":"low"}]}},"grok-4.5":{"info":{"id":"grok-4.5","name":"Grok 4.5","hidden":false,"reasoning_effort":"high","reasoning_efforts":[{"id":"high","value":"high"},{"id":"medium","value":"medium"},{"id":"low","value":"low"}]}}}}'
      app.openSettings("ai")
      tryVerify(function() { return panel() !== null && named(win(), "aiAgent_codex") !== null }, 1000)
      click(named(win(), "aiAgent_codex"))
      compare(files.agent, "codex", "Omarchy's default, from here")
      // A model and effort for each that works here; not for Gemini.
      verify(named(win(), "aiChoice_claude") !== null)
      verify(named(win(), "aiChoice_grok") !== null)
      compare(named(win(), "aiChoice_gemini"), null, "it opens in a terminal")
      click(reach(named(win(), "aiChoice_codexModel")))
      var pick = null
      // (Its menu all the way open before a click on it.)
      tryVerify(function() { pick = named(win(), "aiChoice_codexModel_gpt-5.5"); return pick !== null && named(win(), "aiChoice_codexModel").parent.menuOpened }, 1000)
      mouseClick(pick)
      compare(service.settings.codexModel, "gpt-5.5")
      click(reach(named(win(), "aiChoice_codexEffort")))
      tryVerify(function() { pick = named(win(), "aiChoice_codexEffort_high"); return pick !== null && named(win(), "aiChoice_codexModel").parent.menuOpened }, 1000)
      compare(named(win(), "aiChoice_codexEffort_max"), null, "GPT-5.5 doesn't take max")
      mouseClick(pick)
      compare(service.settings.codexEffort, "high")
      tryVerify(function() { return named(win(), "aiChoice_codex").note === "GPT-5.5 \u00b7 High" }, 1000, "the model it works with (no description of its own)")
      verify(named(win(), "aiChoice_claude").note === "As Claude Code is set up", named(win(), "aiChoice_claude").note)
      closeAll()
      service.setSettings({ codexModel: "", codexEffort: "" })
    }

    function test_11_what_the_sidebar_shows() {
      fresh()
      // From the sidebar: a right-click, Choose what's in the sidebar.
      mouseClick(named(win(), "libraryTile"), 20, 20, Qt.RightButton)
      var choose = null
      tryVerify(function() { choose = named(win(), "sidebarChoose"); return choose !== null }, 1000, "its menu")
      wait(150)
      mouseClick(choose)
      tryVerify(function() { return app.settingsPopup.opened }, 1000)
      tryCompare(named(win(), "settingsTitle"), "text", "Appearance", 1000)
      var group = named(win(), "sidebarChoices")
      var f = panel()
      verify(group !== null)
      tryVerify(function() { var y = group.mapToItem(f.contentItem, 0, 0).y; return y >= f.contentY && y < f.contentY + f.height }, 1000, "in view")
      // Left out, and back.
      var tags = reach(named(win(), "sidebarItem_tags"))
      verify(tags.checked, "shown to begin with")
      compare(named(win(), "sidebarShowAll"), null, "nothing to show again")
      click(tags)
      compare(service.settings.sidebarHidden, ["tags"])
      verify(!named(win(), "sidebarItem_tags").checked)
      click(reach(named(win(), "sidebarItem_trash")))
      compare(service.settings.sidebarHidden, ["tags", "trash"])
      tryVerify(function() { return app.docView.visible && named(app.docView, "trashButton") === null }, 1000, "out of the sidebar")
      click(reach(named(win(), "sidebarItem_tags")))
      compare(service.settings.sidebarHidden, ["trash"])
      click(reach(named(win(), "sidebarShowAll")))
      compare(service.settings.sidebarHidden, [])
      closeAll()
    }

    function test_9_for_agents() {
      fresh()
      var r = JSON.parse(api.backup(""))
      verify(r.ok, JSON.stringify(r))
      compare(r.profiles, ["Personal"])
      tryVerify(function() { return backups.list.length === 1 }, 2000)
      var listed = JSON.parse(api.backupList())
      compare(listed.backups.length, 1)
      verify(/^Uber Notebook Personal/.test(listed.backups[0].name))
      compare(listed.folder, "~/Documents/Uber Notebook Backups")
      compare(JSON.parse(api.backup("Nobody")).ok, false)
      compare(JSON.parse(api.restoreBackup("relative.tar.gz", "")).ok, false, "a full path")
      verify(JSON.parse(api.restoreBackup(listed.backups[0].file, "")).ok)
      tryVerify(function() { return profiles.list.length === 3 }, 2000)
      compare(profiles.current.name, "Personal", "not opened unless asked")
      // Updates.
      files.http[root.releases] = { code: 200, body: JSON.stringify([{ tag_name: "v1.2.0", body: "Faster.", html_url: "https://github.com/marcho78/omanote/releases/tag/v1.2.0" }]) }
      verify(JSON.parse(api.checkUpdate()).ok)
      tryCompare(updates, "status", "available", 1000)
      var v = JSON.parse(api.appVersion())
      compare(v.version, "1.0.0")
      compare(v.latest, "1.2.0")
      compare(v.updateAvailable, true)
      compare(v.canUpdateItself, false)
      verify(api.releaseNotes().indexOf("Faster.") >= 0)
      compare(JSON.parse(api.installUpdate()).ok, false, "not from git: it says how")
      updates.managed = true
      verify(JSON.parse(api.installUpdate()).ok)
      tryCompare(files, "installed", ["marcho78.uber-notebook"], 1000)
      updates.managed = false
      verify(JSON.parse(api.help()).commands.some(function(c) { return c.use.indexOf("restoreBackup") === 0 }))
    }

    // Many agents (a dozen installed): their chips wrap, and their line grows
    // to hold them, nothing over the line above or the words below.
    function test_12_many_agents_fit() {
      fresh()
      files.agentList = ["claude", "codex", "copilot", "crush", "cursor-agent", "gemini", "grok", "hermes", "muse", "omp", "opencode", "pi"].map(function(n) { return { name: n, label: n.charAt(0).toUpperCase() + n.slice(1) } })
      files.agent = "claude"
      app.openSettings("ai")
      var first = null, last = null
      tryVerify(function() { first = named(win(), "aiAgent_claude"); last = named(win(), "aiAgent_pi"); return panel() !== null && first !== null && last !== null }, 1000)
      wait(100)
      var flow = first.parent
      var line = flow.parent.parent
      verify(last.mapToItem(flow, 0, 0).y > first.mapToItem(flow, 0, 0).y, "wrapped to more rows")
      var top = first.mapToItem(line, 0, 0).y
      var bottom = last.mapToItem(line, 0, last.height).y
      verify(top >= 4, "inside its line at the top: " + top)
      verify(bottom <= line.height - 4, "inside its line at the bottom: " + bottom + " of " + line.height)
      // The words under the card start below the chips.
      var below = find(win(), function(it) { return typeof it.text === "string" && it.text.indexOf("Claude Code, Grok and Codex work right here") === 0 })
      verify(below !== null)
      verify(below.mapToItem(null, 0, 0).y > last.mapToItem(null, 0, last.height).y, "the note under them, not over them")
      closeAll()
    }
  }
}
