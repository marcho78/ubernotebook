import QtQuick
import QtTest
import "../.." as Omanote
import "../../app"
import "../../Settings.js" as Settings
import "../../Workspace.js" as Workspace

// Profiles: the first run (your first profile, its folder; or the demo),
// nothing made until then; a second one from the dropdown, each keeping its
// own settings; the demo with its examples (a profile of your own starts
// with the templates); Settings (renamed, taken off the list, asked first);
// notes from before profiles a profile of their own.
Item {
  id: root
  width: 1320
  height: 900

  FakeStore { id: store }
  FakeService { id: service; store: store; user: ({ sounds: false }); profiles: profiles }
  // (The files follow the open profile's folder, as Store.qml does: none
  // before there's a profile.)
  FakeFiles { id: files; rootPath: profiles.current !== null ? Settings.resolveFolder(service.settings.folder, "/tmp", true) : "" }
  Omanote.Profiles { id: profiles; service: service; files: files; dataFolder: "/tmp/omanote-data" }
  Omanote.Workspace {
    id: ws
    files: files
    starter: profiles.current !== null && profiles.current.demo ? "examples" : "templates"
  }

  Omanote.Api { id: api; workspace: ws; files: files; profiles: profiles; noProfile: profiles.firstRun }

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
    name: "Profiles"
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
    function win() { return root.Window.window.contentItem }
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function type(text) { for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i)) }
    function clear(field) { field.text = ""; field.edited("") }

    // A first run: no profiles, nothing on disk.
    function fresh(user, disk) {
      files.reset()
      for (var k in (disk || {})) files.disk[k] = disk[k]
      service.user = user || ({ sounds: false })
      profiles.settled = false
      ws.welcomed = false
      ws.written = ({})
      app.docView.page = null
      app.showSpace("pages")
      profiles.settle()
      tryVerify(function() { return profiles.settled }, 2000)
      wait(50)
    }
    function pagesOpen() {
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      app.docView.activate()
      wait(50)
    }
    function titles() { return Object.keys(ws.index.pages).map(function(id) { return ws.index.pages[id].title }) }

    function test_1_the_first_run() {
      fresh()
      verify(profiles.firstRun)
      var first = named(win(), "firstRun")
      verify(first !== null, "it asks")
      compare(named(first, "profileName").text, "Personal")
      compare(named(first, "profileFolder").text, "~/Documents/Omanote", "the usual place, for the first")
      compare(Object.keys(files.disk).length, 0, "nothing made anywhere yet")
      // Its own folder, picked.
      service.nextFolder = "/tmp/Notes/Mine"
      click(named(first, "profileChoose"))
      compare(named(first, "profileFolder").text, "~/Notes/Mine", "under home: ~")
      clear(named(first, "profileName"))
      click(named(first, "profileCreate"))
      compare(named(first, "profileError").text, "Give it a name")
      mouseClick(named(first, "profileName"))
      tryVerify(function() { return named(first, "profileName").input.activeFocus }, 1000)
      type("Home")
      click(named(first, "profileCreate"))
      tryVerify(function() { return !profiles.firstRun && named(win(), "firstRun") === null }, 1000)
      compare(profiles.current.name, "Home")
      compare(service.settings.folder, "~/Notes/Mine")
      compare(files.rootPath, "/tmp/Notes/Mine")
      // A profile of your own starts with the templates, no examples.
      pagesOpen()
      verify(Workspace.templates(ws.index).length >= 5, "the templates")
      compare(titles().indexOf("Welcome to Omanote"), -1, "no examples")
      compare(ws.contacts.contacts.length, 0, "nobody in People")
      compare(named(win(), "profileSwitchName").text, "Home", "the switch says which")
    }

    function test_2_another_one_and_switching() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Omanote", true) === "")
      service.setSetting("inbox", "aaaa-inbox")
      service.setSetting("lastPage", "aaaa-page")
      // From the dropdown: New profile.
      click(named(win(), "profileSwitch"))
      var item = null
      tryVerify(function() { item = named(win(), "profileNew"); return item !== null }, 1000)
      click(item)
      var name = null
      tryVerify(function() { name = find(win(), function(it) { return it.objectName === "profileName" && it.visible }); return name !== null && name.input.activeFocus }, 1000)
      type("Business")
      compare(named(win(), "profileFolder").text, "~/Documents/Omanote Business", "suggested from its name")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return profiles.current && profiles.current.name === "Business" }, 1000)
      verify(service.savedOpen > 0, "what was open, written first")
      compare(service.settings.folder, "~/Documents/Omanote Business")
      compare(service.settings.inbox, "", "its own Inbox, not Personal's")
      compare(service.settings.lastPage, "")
      service.setSetting("inbox", "bbbb-inbox")
      // Back to Personal from the dropdown: its own, as it was.
      click(named(win(), "profileSwitch"))
      var choice = null
      tryVerify(function() { choice = find(win(), function(it) { return it.objectName === "profileChoice" && it.text === "Personal" }); return choice !== null }, 1000)
      click(choice)
      tryVerify(function() { return profiles.current.name === "Personal" }, 1000)
      compare(service.settings.inbox, "aaaa-inbox")
      compare(service.settings.lastPage, "aaaa-page")
      compare(service.settings.folder, "~/Documents/Omanote")
      var business = profiles.list.filter(function(p) { return p.name === "Business" })[0]
      compare(business.saved.inbox, "bbbb-inbox", "Business keeps its")
      // A name or a folder that's taken.
      compare(profiles.add("business", "~/Elsewhere", false), "There's a profile called that already")
      compare(profiles.add("Other", "~/Documents/Omanote/Other", false), "“Personal” keeps its notes there")
    }

    function test_3_the_demo() {
      fresh()
      // From the first run.
      click(named(named(win(), "firstRun"), "firstRunDemo"))
      tryVerify(function() { return profiles.current && profiles.current.demo }, 1000)
      compare(service.settings.folder, "/tmp/omanote-data/demo")
      pagesOpen()
      tryVerify(function() { return titles().indexOf("Welcome to Omanote") >= 0 }, 2000, "the examples")
      compare(app.docView.page.title, "Welcome to Omanote")
      // A profile of your own, then back to the demo from the dropdown (no new one).
      verify(profiles.add("Mine", "~/Mine", true) === "")
      compare(profiles.list.length, 2)
      click(named(win(), "profileSwitch"))
      var demo = null
      tryVerify(function() { demo = find(win(), function(it) { return it.objectName === "profileChoice" && it.text === "Demo" }); return demo !== null }, 1000)
      compare(named(win(), "profileDemo"), null, "Explore the demo: only while there's none")
      click(demo)
      tryVerify(function() { return profiles.current.demo }, 1000)
      compare(profiles.list.length, 2)
      // Started over: a new folder, the examples again.
      profiles.restartDemo()
      verify(/^\/tmp\/omanote-data\/demo-[a-z0-9]+$/.test(service.settings.folder), service.settings.folder)
      compare(profiles.list.filter(function(p) { return p.demo }).length, 1)
    }

    function test_4_settings() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Omanote", true) === "")
      verify(profiles.add("Side", "~/Side", false) === "")
      app.openSettings()
      var rows = []
      tryVerify(function() { rows = findAll(win(), function(it) { return it.objectName === "settingsProfile" }, []); return rows.length === 2 }, 1000)
      var side = rows.filter(function(r) { return r.modelData.name === "Side" })[0]
      var mine = rows.filter(function(r) { return r.modelData.name === "Personal" })[0]
      compare(named(mine, "settingsProfileRemove"), null, "the open one can't be taken off")
      compare(named(side, "settingsProfileFolder").text, "~/Side")
      // Renamed in place; a name that's taken, said.
      var nameField = named(side, "settingsProfileName")
      mouseClick(nameField)
      nameField.text = "Personal"
      nameField.accepted()
      compare(side.error, "There's a profile called that already")
      compare(nameField.text, "Side", "put back")
      nameField.text = "Studio"
      nameField.accepted()
      tryVerify(function() { return profiles.list.some(function(p) { return p.name === "Studio" }) }, 1000)
      // Taken off the list, asked first.
      rows = findAll(win(), function(it) { return it.objectName === "settingsProfile" }, [])
      side = rows.filter(function(r) { return r.modelData.name === "Studio" })[0]
      click(named(side, "settingsProfileRemove"))
      var yes = null
      tryVerify(function() { yes = named(side, "settingsProfileYes"); return yes !== null }, 1000)
      compare(profiles.list.length, 2, "not yet")
      click(yes)
      tryVerify(function() { return profiles.list.length === 1 }, 1000)
      // A new one from Settings.
      click(named(win(), "settingsNewProfile"))
      var name = null
      tryVerify(function() { name = find(win(), function(it) { return it.objectName === "profileName" && it.visible }); return name !== null }, 1000)
      tryVerify(function() { return name.input.activeFocus }, 1000, "ready to type in")
      type("Work")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return profiles.current.name === "Work" }, 1000)
    }

    // Agents: profiles listed, made (the first, before there's one), renamed,
    // given another folder, opened, taken off the list; the demo.
    function test_4b_agents() {
      fresh()
      function j(t) { return JSON.parse(t) }
      verify(j(api.add("Notes", "/tmp/in/x.md")).error.indexOf("no profile yet") >= 0, "nothing to work on yet")
      var w = j(api.addProfile("Work", "", "true"))
      verify(w.ok, JSON.stringify(w))
      compare(w.folder, "~/Documents/Omanote", "the first: the usual place")
      compare(profiles.current.name, "Work")
      var c = j(api.addProfile("Client", "", "false"))
      compare(c.folder, "~/Documents/Omanote Client", "beside it, named for it")
      compare(profiles.current.name, "Work", "not opened")
      compare(j(api.addProfile("work", "", "false")).error, "There's a profile called that already")
      var list = j(api.profileList())
      compare(list.map(function(p) { return p.name + (p.open ? "*" : "") }).join(","), "Work*,Client")
      compare(j(api.renameProfile("client", "Acme")).name, "Acme")
      compare(j(api.profileFolder("Acme", "~/Clients/Acme")).folder, "~/Clients/Acme")
      compare(j(api.profileFolder("Acme", "~/Documents/Omanote/Acme")).error, "“Work” keeps its notes there")
      compare(j(api.removeProfile("Work")).error, "Open another profile first")
      compare(j(api.openProfile("Acme")).profile, "Acme")
      compare(service.settings.folder, "~/Clients/Acme")
      var gone = j(api.removeProfile("Work"))
      verify(gone.ok && gone.note.indexOf("~/Documents/Omanote") >= 0, JSON.stringify(gone))
      compare(j(api.openProfile("nope")).ok, false)
      // The demo.
      compare(j(api.demo(false)).profile, "Demo")
      verify(profiles.current.demo)
      compare(j(api.profileFolder("Demo", "~/x")).error, "the demo keeps its own folder")
      var before = service.settings.folder
      verify(j(api.demo(true)).ok)
      verify(service.settings.folder !== before && /demo-/.test(service.settings.folder))
      verify(j(api.help()).commands.some(function(x) { return x.use.indexOf("addProfile") === 0 }))
    }

    function test_5_notes_from_before_profiles() {
      // Notes in the usual place: they're "Personal", open.
      fresh({ sounds: false }, { "/tmp/Documents/Omanote/library.json": "{}" })
      compare(profiles.list.length, 1)
      compare(profiles.current.name, "Personal")
      compare(service.settings.folder, "~/Documents/Omanote")
      verify(!profiles.firstRun)
      // A folder set in Settings, and notes in the usual place too: both, the set one open.
      fresh({ sounds: false, folder: "~/Documents/Omanote-Demo", inbox: "keep-inbox" }, { "/tmp/Documents/Omanote/Pages/index.json": "{}" })
      compare(profiles.list.map(function(p) { return p.name }).join(","), "Omanote-Demo,Personal")
      compare(profiles.current.name, "Omanote-Demo")
      compare(service.settings.inbox, "keep-inbox", "its settings, as they were")
      // Its Inbox in the usual place's notes: Personal's, not the open one's.
      fresh({ sounds: false, folder: "~/Documents/Omanote-Demo", inbox: "real-inbox", lastPage: "demo-page" }, {
        "/tmp/Documents/Omanote/library.json": "{}", "/tmp/Documents/Omanote/Pages/real-inbox.json": "{}",
        "/tmp/Documents/Omanote-Demo/Pages/demo-page.json": "{}" })
      compare(profiles.current.name, "Omanote-Demo")
      compare(service.settings.inbox, "", "not the demo's")
      compare(service.settings.lastPage, "demo-page", "the demo's page, its")
      compare(profiles.list.filter(function(p) { return p.name === "Personal" })[0].saved.inbox, "real-inbox")
      profiles.use("Personal")
      compare(service.settings.inbox, "real-inbox", "Personal's, back when it's open")
      compare(service.settings.folder, "~/Documents/Omanote")
      // Nothing anywhere: the first run.
      fresh()
      verify(profiles.firstRun)
      // Profiles there already: the first, if the one open's gone.
      fresh({ sounds: false, profiles: [{ id: "p-x", name: "X", folder: "~/X" }], profile: "p-gone" })
      compare(profiles.current.name, "X")
    }
  }
}
