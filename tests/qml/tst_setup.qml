import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Settings.js" as Settings

// The skill and reminder details, off till you turn them on: the panel that
// asks, once by itself (a profile open); the strip over Pages while one's
// off, in every profile, till it's turned on or off by you or dismissed;
// Turn on (the one that's off, or the panel for both); nothing on the page
// under it. And a message's own button (Turn on, for a reminder's details).
Item {
  id: root
  width: 1320
  height: 900

  FakeStore { id: store }
  FakeService { id: service; store: files; user: ({ sounds: false }); profiles: profiles; asked: ({}) }
  FakeFiles { id: files; rootPath: profiles.current !== null ? Settings.resolveFolder(service.settings.folder, "/tmp", true) : "" }
  UberNotebook.Profiles { id: profiles; service: service; files: files; dataFolder: "/tmp/uber-notebook-data" }
  UberNotebook.Workspace {
    id: ws
    files: files
    starter: "templates"
  }

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

  TestCase {
    name: "Setup"
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
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function strip() { return app.setupBar }
    function stripText() { var t = named(win(), "setupStripText"); return t ? t.text : "" }

    // Two profiles; Pages open. `user`: settings over those.
    function fresh(user) {
      if (app.setupPopup.opened) app.setupPopup.close()
      tryVerify(function() { return !app.setupPopup.visible }, 1000)
      ws.flushIndex()
      files.reset()
      files.disk["/tmp/Notes/Personal/library.json"] = "{\"notebooks\":[]}"
      files.disk["/tmp/Notes/Personal/Pages/one.json"] = "{\"page\":1}"
      files.disk["/tmp/Notes/Work/Pages/w.json"] = "{\"work\":1}"
      var u = { sounds: false, profile: "p-1", folder: "~/Notes/Personal", inbox: "inbox-1",
        profiles: [{ id: "p-1", name: "Personal", folder: "~/Notes/Personal", saved: {} }, { id: "p-2", name: "Work", folder: "~/Notes/Work", saved: {} }] }
      for (var k in user || {}) u[k] = user[k]
      service.user = u
      profiles.settled = true
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      app.showSpace("pages")
      app.docView.activate()
      wait(250)
    }

    // No profile yet (the first run): no panel, no strip; the first one
    // made, the panel.
    function test_0_after_the_first_profile() {
      if (app.setupPopup.opened) app.setupPopup.close()
      files.reset()
      service.user = ({ sounds: false })
      profiles.settled = false
      app.showSpace("pages")
      profiles.settle()
      tryVerify(function() { return profiles.settled && profiles.firstRun }, 2000)
      wait(900)
      verify(!app.setupPopup.opened, "not over the first run")
      verify(!strip().visible)
      verify(profiles.add("Home", "~/Documents/Uber Notebook", true) === "")
      tryVerify(function() { return !profiles.firstRun }, 1000)
      tryVerify(function() { return app.setupPopup.opened }, 2000, "the first profile made: the panel")
      app.setupPopup.close()
      tryVerify(function() { return !app.setupPopup.visible }, 1000)
      compare(service.settings.setupShown, true)
    }

    // The first start: the panel, once by itself, both off; what's turned on
    // there is on; closed, it's been shown and doesn't open again.
    function test_1_the_panel_once_by_itself() {
      fresh({ setupShown: false })
      tryVerify(function() { return app.setupPopup.opened }, 2000, "opens by itself")
      compare(named(win(), "setupTitle").text, "Choose what to turn on")
      var skill = named(win(), "setupSkill")
      var reminders = named(win(), "setupReminders")
      compare(skill.checked, false, "off")
      compare(reminders.checked, false, "off")
      click(skill)
      tryVerify(function() { return service.settings.agentSkill === true }, 1000)
      compare(skill.checked, true)
      compare(service.settings.reminderWords, false, "only what was turned on")
      click(named(win(), "setupDone"))
      tryVerify(function() { return !app.setupPopup.visible }, 1000, "Done closes it")
      compare(service.settings.setupShown, true, "shown")
      // The strip: only what's still off.
      tryVerify(function() { return strip().visible }, 1000)
      compare(stripText(), "See reminder details in notifications.")
      // Another profile: it doesn't open again.
      verify(profiles.use("p-2") === "")
      tryVerify(function() { return profiles.current.id === "p-2" }, 1000)
      wait(900)
      verify(!app.setupPopup.opened, "not again")
      verify(strip().visible, "the strip, in every profile")
      compare(stripText(), "See reminder details in notifications.")
    }

    // Shown already: not opened. Esc closes it, and that counts as shown.
    function test_2_shown_already_and_esc() {
      fresh({ setupShown: true })
      wait(900)
      verify(!app.setupPopup.opened, "shown before: not by itself")
      fresh({ setupShown: false })
      tryVerify(function() { return app.setupPopup.opened }, 2000)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return !app.setupPopup.visible }, 1000, "Esc")
      compare(service.settings.setupShown, true)
      compare(service.settings.agentSkill, false, "nothing turned on")
      compare(service.settings.reminderWords, false)
    }

    // Both off: the strip says both; Turn on opens the panel. One off: Turn
    // on turns that one on, and the strip goes.
    function test_3_turn_on() {
      fresh({ setupShown: true })
      tryVerify(function() { return strip().visible }, 1000)
      compare(stripText(), "Use the Uber Notebook skill in Claude Code and Codex, and see reminder details in notifications.")
      // (Pages starts under it: nothing of the page is under the strip.)
      compare(app.docView.anchors.topMargin, strip().height)
      var before = ws.index ? JSON.stringify(ws.index) : ""
      click(named(win(), "setupStripTurnOn"))
      tryVerify(function() { return app.setupPopup.opened }, 1000, "both: the panel")
      compare(service.settings.agentSkill, false, "nothing turned on by itself")
      compare(service.settings.reminderWords, false)
      click(named(win(), "setupReminders"))
      tryVerify(function() { return service.settings.reminderWords === true }, 1000)
      click(named(win(), "setupDone"))
      tryVerify(function() { return !app.setupPopup.visible }, 1000)
      compare(stripText(), "Use the Uber Notebook skill in Claude Code and Codex.")
      click(named(win(), "setupStripTurnOn"))
      tryVerify(function() { return service.settings.agentSkill === true }, 1000, "one: turned on")
      verify(!app.setupPopup.opened, "no panel for one")
      tryVerify(function() { return !strip().visible }, 1000, "both on: gone")
      compare(app.docView.anchors.topMargin, 0)
      compare(ws.index ? JSON.stringify(ws.index) : "", before, "nothing on the page changed")
      // Turned off by you, in Settings: not asked about again.
      service.setSetting("agentSkill", false)
      service.setSetting("reminderWords", false)
      wait(100)
      verify(!strip().visible, "off by you: the strip doesn't come back")
    }

    // Dismiss: gone, in every profile, while both stay off.
    function test_4_dismiss() {
      fresh({ setupShown: true })
      tryVerify(function() { return strip().visible }, 1000)
      click(named(win(), "setupStripDismiss"))
      tryVerify(function() { return !strip().visible }, 1000)
      compare(service.settings.agentSkill, false, "nothing turned on")
      compare(service.settings.reminderWords, false)
      compare(JSON.stringify(service.settings.setupSettled), JSON.stringify(["skill", "reminders"]))
      verify(profiles.use("p-2") === "")
      tryVerify(function() { return profiles.current.id === "p-2" }, 1000)
      wait(200)
      verify(!strip().visible, "not in another profile either")
    }

    // Only over Pages; none with no profile open.
    function test_5_only_over_pages() {
      fresh({ setupShown: true })
      tryVerify(function() { return strip().visible }, 1000)
      app.showSpace("notebooks")
      tryVerify(function() { return !strip().visible }, 1000, "not over the notebooks")
      app.showSpace("pages")
      tryVerify(function() { return strip().visible }, 1000)
      profiles.openStart()
      tryVerify(function() { return !strip().visible }, 1000, "not over the start screen")
      profiles.closeStart()
      tryVerify(function() { return strip().visible }, 1000)
    }

    // A message with a button of its own: its label, and what it does.
    function test_6_a_message_with_a_button() {
      fresh({ setupShown: true })
      var done = 0
      app.toastWithAction("Reminder set for Fri 9 Oct, 9:53 am. Show its details in the notification?", "Turn on", function() { done++ })
      var b = null
      tryVerify(function() { b = named(win(), "toastUndo"); return b !== null }, 1000)
      compare(b.children[0].text, "Turn on")
      click(b)
      compare(done, 1, "done")
      // Undo's own, as before.
      app.toastWithUndo("Deleted", function() {})
      tryVerify(function() { b = named(win(), "toastUndo"); return b !== null }, 1000)
      compare(b.children[0].text, "Undo")
    }
  }
}
