import QtQuick
import QtTest
import "../.." as Omanote
import "../../app"
import "../../Workspace.js" as Workspace

// A new Omanote's Pages: the examples (Starter.js) made the first time it's
// opened in an empty folder: the pages in their places (the Welcome page
// first, and open), Favorites, a project, templates, the people and events
// they name, the email written into Pages/assets, the Library full; every
// page opens. Opened again, nothing's made twice.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  Omanote.Workspace { id: ws; files: files; starter: "examples" }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  TestCase {
    name: "Starter"
    when: windowShown

    function fresh() {
      wait(100)
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
    }
    function titled(t) { return Workspace.pageNamed(ws.index, t) }
    function find(item, test) {
      if (!item) return null
      if (item.visible && test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }

    function test_1_a_new_pages() {
      fresh()
      var ix = ws.index
      var top = ix.top.filter(function(id) { return !ix.pages[id].template })
      compare(ix.pages[top[0]].title, "Welcome to Omanote", "first in the tree")
      compare(view.page.id, top[0], "and open")
      verify(top.length >= 9, top.length)
      var welcome = titled("Welcome to Omanote")
      compare(ix.pages[welcome].children.length, 3, "the basics inside it")
      compare(ix.pages[titled("Weekly sync")].parent, titled("Website relaunch"))
      compare(ix.favorites.length, 2)
      verify(ix.favorites.indexOf(welcome) >= 0)
      // A project, templates, tags.
      var projects = Workspace.projectList(ix, new Date()).map(function(p) { return ix.pages[p.id] ? ix.pages[p.id].title : p.title })
      verify(projects.indexOf("Website relaunch") >= 0, JSON.stringify(projects))
      verify(Workspace.templates(ix).length >= 5)
      verify(Workspace.pagesTagged(ix, "launch").length >= 2)
      // People and events.
      compare(ws.contacts.contacts.length, 4)
      compare(ws.calendar.events.length, 6)
      compare(ws.contactsUndo.length, 0, "not a step to undo")
      var sync = ws.calendar.events.filter(function(e) { return e.title === "Weekly sync" })[0]
      compare(sync.page, titled("Weekly sync"), "the event's notes page")
      // The email, written; the PDF and the picture, copied from the plugin.
      var eml = Object.keys(files.disk).filter(function(p) { return /\/Pages\/assets\/example-flight-confirmation\.eml$/.test(p) })
      compare(eml.length, 1)
      verify(files.disk[eml[0]].indexOf("Subject: Your trip to Lisbon is booked") >= 0)
      // The Library has it all.
      var kinds = {}
      Workspace.collected(ix).forEach(function(r) { kinds[r.kind] = true })
      ;["link", "file", "picture", "email", "person", "meeting", "sketch"].forEach(function(k) { verify(kinds[k], "the Library's " + k) })
    }

    function test_2_every_page_opens() {
      fresh()
      var ids = Object.keys(ws.index.pages)
      ids.forEach(function(id) {
        view.open(id)
        tryVerify(function() { return view.page && view.page.id === id }, 2000, ws.index.pages[id].title)
        verify(view.editor.model.count > 1, ws.index.pages[id].title + " has its blocks")
      })
    }

    // A contact card says a birthday as People does ("14 May", not "--05-14");
    // the Library has someone once for each page they're on.
    function test_2b_people_on_pages() {
      fresh()
      view.open(titled("People to follow up"))
      tryVerify(function() { return find(view.editor, function(it) { return it.text === "14 May" }) !== null }, 2000, "Sam's birthday")
      verify(find(view.editor, function(it) { return typeof it.text === "string" && it.text.indexOf("-05-14") >= 0 }) === null)
      var seen = {}
      Workspace.collected(ws.index).filter(function(r) { return r.kind === "person" }).forEach(function(r) {
        var k = r.page + r.person
        verify(!seen[k], "once on " + r.pageTitle)
        seen[k] = true
      })
    }

    // Another notes folder (`set folder`): the page open from the one before
    // goes (its change not written into this one), and an empty one starts
    // with the examples; back again, it's as it was.
    function test_4_another_folder() {
      fresh()
      var home = files.rootPath
      var count = Object.keys(ws.index.pages).length
      var old = titled("Reading list")
      view.open(old)
      tryVerify(function() { return view.page && view.page.id === old }, 2000)
      view.markDirty()
      files.rootPath = "/tmp/omanote-other"
      tryVerify(function() { return ws.ready && view.page !== null && view.page.title === "Welcome to Omanote" && ws.index.pages[view.page.id] !== undefined }, 3000, "the new folder's examples, open")
      verify(view.page.id !== titled("Reading list") || ws.folder === "/tmp/omanote-other/Pages")
      compare(Object.keys(files.disk).filter(function(p) { return p.indexOf("/tmp/omanote-other/Pages/" + old) === 0 }).length, 0, "nothing of the old folder's written here")
      compare(ws.contacts.contacts.length, 4)
      // Back.
      files.rootPath = home
      tryVerify(function() { return ws.ready && view.page !== null && ws.folder === home + "/Pages" && ws.index.pages[view.page.id] !== undefined }, 3000)
      compare(Object.keys(ws.index.pages).length, count, "as it was: nothing made twice")
    }

    function test_3_only_once() {
      fresh()
      var count = Object.keys(ws.index.pages).length
      ws.welcomed = false
      compare(ws.ensureStarted(), false, "a Pages with pages isn't started again")
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      compare(Object.keys(ws.index.pages).length, count)
      compare(ws.contacts.contacts.length, 4, "nobody added twice")
      compare(ws.calendar.events.length, 6)
    }
  }
}
