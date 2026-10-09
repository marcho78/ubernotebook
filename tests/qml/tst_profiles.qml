import QtQuick
import QtTest
import "../.." as UberNotebook
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
  UberNotebook.Profiles { id: profiles; service: service; files: files; dataFolder: "/tmp/uber-notebook-data" }
  UberNotebook.Workspace {
    id: ws
    files: files
    starter: profiles.current !== null && profiles.current.demo ? "examples" : "templates"
  }

  // (Its Inbox the open profile's, kept as its setting, as Service.qml has it.)
  UberNotebook.Api {
    id: api; workspace: ws; files: files; profiles: profiles; noProfile: profiles.firstRun
    inbox: service.settings.inbox || ""
    onInboxMade: function(id) { service.setSetting("inbox", id) }
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
      compare(named(first, "profileFolder").text, "~/Documents/Uber Notebook", "the usual place, for the first")
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
      compare(titles().indexOf("Welcome to Uber Notebook"), -1, "no examples")
      compare(ws.contacts.contacts.length, 0, "nobody in People")
      compare(named(win(), "profileSwitchName").text, "Home", "the switch says which")
    }

    function test_2_another_one_and_switching() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
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
      compare(named(win(), "profileFolder").text, "~/Documents/Uber Notebook Business", "suggested from its name")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return profiles.current && profiles.current.name === "Business" }, 1000)
      verify(service.savedOpen > 0, "what was open, written first")
      compare(service.settings.folder, "~/Documents/Uber Notebook Business")
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
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      var business = profiles.list.filter(function(p) { return p.name === "Business" })[0]
      compare(business.saved.inbox, "bbbb-inbox", "Business keeps its")
      // A name or a folder that's taken.
      compare(profiles.add("business", "~/Elsewhere", false), "There's a profile called that already")
      compare(profiles.add("Other", "~/Documents/Uber Notebook/Other", false), "“Personal” keeps its notes there")
    }

    // Each profile its own Inbox: one made in a profile (its first quick
    // note) is kept as its setting, and switching back brings the other's,
    // never another "Inbox" made there.
    function test_2b_each_profile_its_own_inbox() {
      fresh()
      function j(t) { return JSON.parse(t) }
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
      var personal = profiles.current.id
      pagesOpen()
      tryVerify(function() { return ws.loaded }, 2000)
      var a = j(api.quickPage("Milk"))
      verify(a.ok, JSON.stringify(a))
      var inboxP = service.settings.inbox
      verify(Workspace.isUuid(inboxP), inboxP)
      compare(api.inbox, inboxP)
      // A new profile: none yet, its own made there.
      verify(profiles.add("Client", "~/Documents/Uber Notebook Client", true) === "")
      compare(api.inbox, "", "Client's, not Personal's")
      pagesOpen()
      tryVerify(function() { return ws.loaded }, 2000)
      var b = j(api.quickPage("Call"))
      verify(b.ok, JSON.stringify(b))
      var inboxC = service.settings.inbox
      verify(Workspace.isUuid(inboxC) && inboxC !== inboxP, inboxC)
      compare(api.inbox, inboxC)
      // Back to Personal: its Inbox again, the next note (or `add`) in it.
      verify(profiles.use(personal) === "")
      compare(api.inbox, inboxP, "Personal's again")
      pagesOpen()
      tryVerify(function() { return ws.loaded }, 2000)
      var c = j(api.quickPage("Eggs"))
      verify(c.ok, JSON.stringify(c))
      compare(ws.index.pages[c.id].parent, inboxP, "into Personal's Inbox")
      compare(titles().filter(function(t) { return t === "Inbox" }).length, 1, "no other Inbox made")
      compare(service.settings.inbox, inboxP, "its setting as it was")
      // And Client's, as it was.
      verify(profiles.use("Client") === "")
      compare(api.inbox, inboxC)
    }

    function test_3_the_demo() {
      fresh()
      // From the first run.
      click(named(named(win(), "firstRun"), "firstRunDemo"))
      tryVerify(function() { return profiles.current && profiles.current.demo }, 1000)
      compare(service.settings.folder, "/tmp/uber-notebook-data/demo")
      pagesOpen()
      tryVerify(function() { return titles().indexOf("Welcome to Uber Notebook") >= 0 }, 2000, "the examples")
      compare(app.docView.page.title, "Welcome to Uber Notebook")
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
      verify(/^\/tmp\/uber-notebook-data\/demo-[a-z0-9]+$/.test(service.settings.folder), service.settings.folder)
      compare(profiles.list.filter(function(p) { return p.demo }).length, 1)
    }

    // A profile's notes folder that can't be used (a drive that can't keep
    // files private, or one that's gone): said over the notes, nothing under
    // it reached, with the way to pick another folder (Settings, Profiles).
    function test_3c_notes_that_cant_be_kept() {
      fresh()
      click(named(named(win(), "firstRun"), "firstRunDemo"))
      tryVerify(function() { return profiles.inDemo && named(win(), "firstRun") === null }, 2000)
      tryCompare(ws, "ready", true, 3000)
      wait(200)
      // (Where a control is that would make a page, before it's covered.)
      var row = named(win(), "newPageRow") || named(win(), "newPageButton")
      verify(row !== null, "a control that makes a page")
      var at = row.mapToItem(win(), row.width / 2, row.height / 2)
      var pages = Object.keys(ws.index.pages).length
      store.blockedWhy = "private"
      store.blockedFolder = "/run/media/me/STICK/Notes"
      var cover = null
      tryVerify(function() { cover = named(win(), "privateStrip"); return cover !== null }, 1000, "said")
      verify(cover.height > app.height / 2, "over the notes, not a line above them")
      // (A click on it, where that control is under it: nothing happens there.)
      mouseClick(win(), at.x, at.y)
      wait(300)
      compare(Object.keys(ws.index.pages).length, pages, "nothing made under it")
      // Try again: that folder looked at again (a drive mounted since).
      var retried = store.retried
      click(named(cover, "privateStripRetry"))
      compare(store.retried, retried + 1, "looked at again")
      click(named(cover, "privateStripProfiles"))
      tryVerify(function() { return named(win(), "settingsFlick") !== null }, 1000, "Settings, at Profiles")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return named(win(), "settingsFlick") === null }, 1000)
      store.blockedFolder = ""
      store.blockedWhy = ""
      tryVerify(function() { return named(win(), "privateStrip") === null }, 1000, "gone once it can be used")
    }

    // The folder the open profile has, picked again (Settings, Profiles):
    // looked at again, if it couldn't be used (a drive mounted since);
    // another folder is simply the next one.
    function test_3d_the_same_folder_picked_again() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
      verify(profiles.add("Side", "~/Side", false) === "")
      var id = profiles.current.id
      compare(files.retried, 0)
      compare(profiles.setFolder(id, "~/Documents/Uber Notebook"), "")
      compare(files.retried, 1, "looked at again")
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      var side = profiles.list.filter(function(p) { return p.name === "Side" })[0]
      compare(profiles.setFolder(side.id, "~/Side"), "")
      compare(files.retried, 1, "not the one open: nothing to look at")
      compare(profiles.setFolder(id, "~/Documents/Elsewhere"), "")
      compare(files.retried, 1, "another folder: opened as the next one")
      compare(service.settings.folder, "~/Documents/Elsewhere")
    }

    // A new profile's folder is made when it's first opened; once it's
    // open, it isn't new any more (one opened before that's gone is a drive
    // not mounted: never made again, Store.makeNotesFolder). One added and
    // not opened stays new; a folder picked for one is made as a new one's.
    // Notes from before profiles were opened before.
    function test_3e_new_till_opened() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
      tryVerify(function() { return profiles.current !== null && profiles.current.fresh === undefined }, 1000, "opened: not new any more")
      verify(profiles.add("Side", "~/Side", false) === "")
      wait(50)
      function side() { return profiles.list.filter(function(p) { return p.name === "Side" })[0] }
      compare(side().fresh, true, "not opened: still new")
      compare(profiles.use(side().id), "")
      tryVerify(function() { return profiles.current.name === "Side" && profiles.current.fresh === undefined }, 1000, "opened")
      var personal = profiles.list.filter(function(p) { return p.name === "Personal" })[0]
      compare(personal.fresh, undefined)
      compare(profiles.setFolder(personal.id, "~/Documents/Elsewhere"), "")
      wait(50)
      compare(profiles.list.filter(function(p) { return p.name === "Personal" })[0].fresh, true, "a folder picked: made when it's opened")
      // (Not opened yet: not new any more only once it's that folder that's open.)
      compare(profiles.current.name, "Side")
      // From before profiles: opened before.
      fresh({ sounds: false, profile: "p-a", folder: "~/Before", profiles: [{ id: "p-a", name: "Personal", folder: "~/Before" }] })
      wait(50)
      compare(profiles.current.fresh, undefined)
    }

    // In the demo: a strip says so, with the welcome screen a click away (and
    // in the profile menu); closed again (Back to the demo, Esc); gone once
    // there's a profile of your own.
    function test_3b_the_way_out_of_the_demo() {
      fresh()
      click(named(named(win(), "firstRun"), "firstRunDemo"))
      tryVerify(function() { return profiles.inDemo && named(win(), "firstRun") === null }, 2000)
      var strip = null
      tryVerify(function() { strip = named(win(), "demoStrip"); return strip !== null && strip.height > 0 }, 1000, "the strip")
      verify(app.docView.y >= strip.height || app.docView.mapToItem(null, 0, 0).y >= strip.height, "what's under it, under it")
      // Make my own profile: the welcome screen, as the first time; Back to the demo.
      click(named(strip, "demoStripStart"))
      var start = null
      tryVerify(function() { start = named(win(), "firstRun"); return start !== null }, 1000)
      compare(named(win(), "demoStrip"), null, "the strip not over it")
      compare(named(start, "firstRunDemo").text, "Back to the demo")
      click(named(start, "firstRunDemo"))
      tryVerify(function() { return named(win(), "firstRun") === null && named(win(), "demoStrip") !== null }, 1000)
      verify(profiles.inDemo, "still in the demo")
      // From the profile menu: Start screen…; Esc closes it.
      click(named(win(), "profileSwitch"))
      var item = null
      tryVerify(function() { item = named(win(), "profileStart"); return item !== null }, 1000)
      click(item)
      tryVerify(function() { return named(win(), "firstRun") !== null }, 1000)
      verify(named(win(), "firstRunClose") !== null, "it can be closed")
      wait(200)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return named(win(), "firstRun") === null }, 1000)
      // A profile of your own, made there: open, the strip gone.
      profiles.openStart()
      tryVerify(function() { return named(win(), "firstRun") !== null }, 1000)
      verify(profiles.add("Mine", "~/Notes/Mine", true) === "")
      tryVerify(function() { return !profiles.inDemo && named(win(), "firstRun") === null }, 1000)
      compare(named(win(), "demoStrip"), null)
      compare(profiles.current.name, "Mine")
    }

    function test_4_settings() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
      verify(profiles.add("Side", "~/Side", false) === "")
      // (Opened: not new any more, the list as it is from now.)
      tryVerify(function() { return profiles.current.fresh === undefined }, 1000)
      app.openSettings("profiles")
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
      compare(w.folder, "~/Documents/Uber Notebook", "the first: the usual place")
      compare(profiles.current.name, "Work")
      var c = j(api.addProfile("Client", "", "false"))
      compare(c.folder, "~/Documents/Uber Notebook Client", "beside it, named for it")
      compare(profiles.current.name, "Work", "not opened")
      compare(j(api.addProfile("work", "", "false")).error, "There's a profile called that already")
      var list = j(api.profileList())
      compare(list.map(function(p) { return p.name + (p.open ? "*" : "") }).join(","), "Work*,Client")
      compare(j(api.renameProfile("client", "Acme")).name, "Acme")
      compare(j(api.profileFolder("Acme", "~/Clients/Acme")).folder, "~/Clients/Acme")
      compare(j(api.profileFolder("Acme", "~/Documents/Uber Notebook/Acme")).error, "“Work” keeps its notes there")
      compare(j(api.removeProfile("Work")).error, "Open another profile first")
      compare(j(api.openProfile("Acme")).profile, "Acme")
      compare(service.settings.folder, "~/Clients/Acme")
      var gone = j(api.removeProfile("Work"))
      verify(gone.ok && gone.note.indexOf("~/Documents/Uber Notebook") >= 0, JSON.stringify(gone))
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
      fresh({ sounds: false }, { "/tmp/Documents/Uber Notebook/library.json": "{}" })
      compare(profiles.list.length, 1)
      compare(profiles.current.name, "Personal")
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      verify(!profiles.firstRun)
      // A folder set in Settings, and notes in the usual place too: both, the set one open.
      fresh({ sounds: false, folder: "~/Documents/Uber Notebook Demo", inbox: "keep-inbox" }, { "/tmp/Documents/Uber Notebook/Pages/index.json": "{}" })
      compare(profiles.list.map(function(p) { return p.name }).join(","), "Uber Notebook Demo,Personal")
      compare(profiles.current.name, "Uber Notebook Demo")
      compare(service.settings.inbox, "keep-inbox", "its settings, as they were")
      // Its Inbox in the usual place's notes: Personal's, not the open one's.
      fresh({ sounds: false, folder: "~/Documents/Uber Notebook Demo", inbox: "real-inbox", lastPage: "demo-page" }, {
        "/tmp/Documents/Uber Notebook/library.json": "{}", "/tmp/Documents/Uber Notebook/Pages/real-inbox.json": "{}",
        "/tmp/Documents/Uber Notebook Demo/Pages/demo-page.json": "{}" })
      compare(profiles.current.name, "Uber Notebook Demo")
      compare(service.settings.inbox, "", "not the demo's")
      compare(service.settings.lastPage, "demo-page", "the demo's page, its")
      compare(profiles.list.filter(function(p) { return p.name === "Personal" })[0].saved.inbox, "real-inbox")
      profiles.use("Personal")
      compare(service.settings.inbox, "real-inbox", "Personal's, back when it's open")
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      // Nothing anywhere: the first run.
      fresh()
      verify(profiles.firstRun)
      // Profiles there already: the first, if the one open's gone.
      fresh({ sounds: false, profiles: [{ id: "p-x", name: "X", folder: "~/X" }], profile: "p-gone" })
      compare(profiles.current.name, "X")
    }

    // Once the profiles are in: every one's notes folder made yours alone,
    // not only the one opened (one from before was open to others); in your
    // home folder itself, only what Uber Notebook keeps there.
    function test_6_every_profiles_folder_made_private() {
      fresh({ sounds: false, profile: "p-a", folder: "~/Documents/Uber Notebook", profiles: [
        { id: "p-a", name: "Personal", folder: "~/Documents/Uber Notebook" },
        { id: "p-b", name: "Work", folder: "/tmp/data/Work" },
        { id: "p-c", name: "Home", folder: "/tmp" }] }, { "/tmp/field-journal-a1b2/notebook.json": "{}" })
      var made = files.madePrivate
      verify(made.indexOf("/tmp/Documents/Uber Notebook") >= 0, JSON.stringify(made))
      verify(made.indexOf("/tmp/data/Work") >= 0, "not only the one open: " + JSON.stringify(made))
      verify(made.indexOf("/tmp") < 0, "never your home folder itself")
      verify(made.indexOf("/tmp/Pages") >= 0 && made.indexOf("/tmp/library.json") >= 0 && made.indexOf("/tmp/.trash") >= 0, "what's kept there: " + JSON.stringify(made))
      verify(made.indexOf("/tmp/field-journal-a1b2") >= 0, "its notebooks' folders too: " + JSON.stringify(made))
      // (Once, as they're settled: not again with each switch.)
      var n = made.length
      profiles.use("p-b")
      compare(files.madePrivate.length, n)
    }

    // A profile's own folder picked again (to try it again, a drive mounted
    // since): not taken for a new one, so one that's gone isn't made again
    // in its place; another folder picked is (made when it's opened).
    function test_6c_its_own_folder_picked_again_isnt_new() {
      fresh({ sounds: false, profile: "p-a", folder: "~/Vault/Notes", profiles: [{ id: "p-a", name: "Vault", folder: "~/Vault/Notes" }] })
      function vault() { return profiles.list.filter(function(p) { return p.id === "p-a" })[0] }
      verify(!vault().fresh, "opened before")
      verify(profiles.setFolder("p-a", "~/Vault/Notes") === "")
      verify(!vault().fresh, "picked again: still not a new one")
      verify(profiles.setFolder("p-a", "~/Elsewhere") === "")
      compare(vault().fresh, true, "another folder: made when it's opened")
    }

    // `set folder` and `set profile` (the commands) do as Settings does:
    // another profile's folder refused; a folder new to it made when it's
    // opened; another profile opened with its own folder, never the one
    // before's; not while an audio note records. No profile yet: the
    // setting alone, as before.
    function test_6d_set_folder_and_profile_from_the_commands() {
      fresh()
      compare(profiles.setByCommand("folder", "~/Start"), null, "no profile yet")
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
      verify(profiles.add("Work", "~/Work", false) === "")
      var me = profiles.current.id
      var work = profiles.list.filter(function(p) { return p.name === "Work" })[0]
      verify(profiles.setByCommand("folder", "~/Work/Inside") !== "", "another profile's folder: refused")
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      compare(profiles.setByCommand("folder", "~/Moved"), "")
      compare(service.settings.folder, "~/Moved")
      var mine = profiles.list.filter(function(p) { return p.id === me })[0]
      compare(mine.folder, "~/Moved", "kept on the profile, not the setting alone")
      compare(mine.fresh, true, "made when it's opened")
      compare(profiles.setByCommand("profile", "no-such"), "There's no profile like that")
      compare(profiles.setByCommand("profile", work.id), "")
      compare(profiles.current.name, "Work")
      compare(service.settings.folder, "~/Work", "its own folder")
      var rec = service.recorder
      compare(rec.start("audio", "a-block", "/tmp/Work/Pages/assets/note.ogg", function() {}), "")
      compare(profiles.setByCommand("profile", me), "Stop the recording first")
      compare(profiles.setByCommand("folder", "~/Work2"), "Stop the recording first")
      compare(service.settings.folder, "~/Work")
      rec.stop()
      compare(profiles.setByCommand("profile", me), "")
      compare(service.settings.folder, "~/Moved")
    }

    // While an audio note is being recorded (or saved), no other profile is
    // opened, nor the open one's folder changed: its page would be gone from
    // under it, the recording left in no page. Said, from the menu as to
    // agents; one not opened is made; once it's done, it opens.
    function test_6b_not_while_an_audio_note_records() {
      fresh()
      verify(profiles.add("Personal", "~/Documents/Uber Notebook", true) === "")
      verify(profiles.add("Work", "~/Work", false) === "")
      var work = profiles.list.filter(function(p) { return p.name === "Work" })[0]
      var rec = service.recorder
      var got = null
      compare(rec.start("audio", "a-block", "/tmp/Documents/Uber Notebook/Pages/assets/note.ogg", function(ok, r) { got = r }), "")
      // From the dropdown: not opened, and said.
      click(named(win(), "profileSwitch"))
      var choice = null
      tryVerify(function() { choice = find(win(), function(it) { return it.objectName === "profileChoice" && it.text === "Work" }); return choice !== null }, 1000)
      click(choice)
      tryVerify(function() { return find(win(), function(it) { return it.text === "Stop the recording first" }) !== null }, 1000, "said")
      compare(profiles.current.name, "Personal")
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      compare(files.rootPath, "/tmp/Documents/Uber Notebook")
      // Every other way.
      compare(profiles.use(work.id), "Stop the recording first")
      compare(profiles.add("Client", "~/Client", true), "Stop the recording first")
      verify(!profiles.list.some(function(p) { return p.name === "Client" }), "nothing made")
      verify(profiles.add("Client", "~/Client", false) === "", "one not opened: made")
      compare(profiles.setFolder(profiles.current.id, "~/Elsewhere"), "Stop the recording first")
      verify(profiles.setFolder(work.id, "~/Work2") === "", "another one's folder: changed")
      compare(profiles.openDemo(), "Stop the recording first")
      compare(profiles.demo, null, "no demo made")
      var made = profiles.addRestored([{ name: "Old", folder: "~/Old", saved: {} }], true)
      compare(made.length, 1)
      verify(profiles.list.some(function(p) { return p.name === "Old" }), "put back")
      compare(JSON.parse(api.openProfile("Work")).error, "Stop the recording first")
      compare(JSON.parse(api.addProfile("Studio", "", "true")).error, "Stop the recording first")
      compare(JSON.parse(api.profileFolder("Personal", "~/Moved")).error, "Stop the recording first")
      compare(JSON.parse(api.demo(false)).error, "Stop the recording first")
      compare(profiles.current.name, "Personal", "still the one it's recorded in")
      compare(service.settings.folder, "~/Documents/Uber Notebook")
      // Stopped, and being saved (made louder): not yet either.
      rec.phase = "finishing"
      verify(/being saved/.test(profiles.use(work.id)))
      rec.phase = "recording"
      rec.stop()
      compare(got.file, "/tmp/Documents/Uber Notebook/Pages/assets/note.ogg")
      // Done: it opens.
      compare(profiles.use(work.id), "")
      compare(profiles.current.name, "Work")
      compare(service.settings.folder, "~/Work2")
    }
  }
}
