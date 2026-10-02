import QtQuick
import QtTest
import "../.." as Omanote
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html
import "../../Templates.js" as Templates

// Your own templates in Pages: a page saved as one (out of the tree, in
// Templates), a blank page made from it, one put in where you are
// ("/template"), a new page from it (Templates, the sidebar's menu), what
// new pages inside a page start from, {{date}} filled in, a template a page
// again, and the commands agents use.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  Omanote.Workspace { id: ws; files: files }
  property string lastToast: ""
  property var lastUndo: null

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToast: function(text) { root.lastToast = text }
    onToastUndo: function(text, undo) { root.lastToast = text; root.lastUndo = undo }
  }

  QtObject {
    id: ui
    function saveNow() { view.commit() }
    function addPageBlock(parentId, childId) { return view.pageAddedInto(parentId, childId) }
  }

  Omanote.Api {
    id: api
    workspace: ws
    files: files
    ui: ui
  }

  TestCase {
    name: "Templates"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      root.lastToast = ""
      wait(0)
    }
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
    function click(item) { verify(item !== null); wait(150); mouseClick(item) }
    function type(text) {
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i))
    }
    function openPage(id) {
      view.open(id)
      tryVerify(function() { return view.page && view.page.id === id }, 2000)
      wait(50)
    }
    function plain(b) { return Html.plainText(b.html || "") }
    // A page to make a template of: a heading with {{weekday}}, a to-do,
    // a page inside it.
    function standup() {
      var p = ws.createPage({ parent: "", title: "Standup {{date}}", icon: "\u{1f5d3}", blocks: [
        { type: "h2", html: "{{weekday}}", indent: 0 },
        { type: "check", html: "What I did", indent: 0 },
        { type: "p", html: "", indent: 0 }
      ] })
      var inside = ws.createPage({ parent: p.id, title: "Blockers" })
      ws.editPage(p.id, function(x) { return Workspace.appendPageBlock(x, inside.id) })
      return p
    }
    function today(pattern) { return Qt.formatDate(new Date(), pattern) }

    function test_1_saved_as_a_template() {
      fresh()
      var p = standup()
      openPage(p.id)
      mouseClick(find(root, function(it) { return it.tip === "Font, width, export, trash" }))
      var save = null
      tryVerify(function() { save = named(win(), "saveTemplate"); return save !== null && save.text === "Save as template" }, 1000)
      wait(250)
      mouseClick(save)
      var list = []
      tryVerify(function() { list = Workspace.templates(ws.index); return list.length === 1 }, 2000, "a template")
      var t = list[0]
      compare(t.title, "Standup {{date}}")
      verify(t.id !== p.id, "a copy")
      compare(Workspace.withDescendants(ws.index, t.id).length, 2, "with the page in it")
      // Out of the tree; the page it was made of still there.
      var titles = Workspace.rows(ws.index, {}).map(function(r) { return r.id })
      verify(titles.indexOf(t.id) < 0, "not in the tree")
      verify(titles.indexOf(p.id) >= 0)
      verify(root.lastToast.indexOf("is a template") >= 0, root.lastToast)
      // In Templates, at the sidebar's foot.
      wait(200)
      click(named(win(), "templatesRow"))
      var row = null
      tryVerify(function() { row = named(win(), "templateRow"); return row !== null }, 1000)
      wait(200)
      mouseClick(row)
      tryVerify(function() { return view.page && view.page.id === t.id }, 2000, "opened, to change it")
      tryVerify(function() { return named(win(), "templateNote") !== null }, 1000, "it says it's a template")
    }

    function test_2_a_blank_page_from_it_filled_in() {
      fresh()
      var p = standup()
      var made = ""
      ws.saveAsTemplate(p.id, function(id) { made = id })
      tryVerify(function() { return made !== "" }, 2000)
      view.newPage("")
      tryVerify(function() { return view.page && view.pageBlank }, 2000)
      var chip = null
      tryVerify(function() { chip = named(win(), "userTemplateChip"); return chip !== null }, 1000, "yours, among the templates")
      click(chip)
      tryVerify(function() { return view.editor.serialize().some(function(b) { return b.type === "check" }) }, 2000, "its blocks")
      var blocks = view.editor.serialize()
      compare(plain(blocks[0]), today("dddd"), "{{weekday}} filled in")
      compare(view.page.icon, "\u{1f5d3}")
      view.commit()
      compare(ws.index.pages[view.page.id].title, "Standup " + today("ddd d MMM"), "{{date}} in the title")
      var pageBlock = blocks.filter(function(b) { return b.type === "page" })[0]
      verify(pageBlock !== undefined, "the page in it")
      verify(ws.index.pages[pageBlock.uid].parent === view.page.id, "made inside this one")
      compare(ws.index.pages[pageBlock.uid].title, "Blockers")
      verify(!Workspace.inTemplates(ws.index, pageBlock.uid))
      // Undo takes the blocks back off.
      view.editor.undo()
      tryVerify(function() { return !view.editor.serialize().some(function(b) { return b.type === "check" }) }, 1000)
    }

    function test_3_put_in_where_you_are() {
      fresh()
      var p = standup()
      var made = ""
      ws.saveAsTemplate(p.id, function(id) { made = id })
      tryVerify(function() { return made !== "" }, 2000)
      var host = ws.createPage({ parent: "", title: "Log", blocks: [{ type: "p", html: "Before", indent: 0 }, { type: "p", html: "After", indent: 0 }] })
      openPage(host.id)
      var e = view.editor
      e.focusBlock(e.uidAt(0), -1)
      keyClick(Qt.Key_Return)
      type("/template")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "template")
      keyClick(Qt.Key_Return)
      var choice = null
      tryVerify(function() { choice = named(win(), "templateChoice"); return choice !== null }, 1000)
      wait(250)
      mouseClick(choice)
      tryVerify(function() { return e.serialize().some(function(b) { return b.type === "check" }) }, 2000)
      var list = e.serialize().map(function(b) { return b.type === "page" ? "page" : plain(b) })
      compare(list[0], "Before")
      compare(list[list.length - 1], "After", "after the block you were in, before the rest")
      verify(list.indexOf("What I did") > 0)
    }

    function test_4_new_pages_from_it_and_inside_a_page() {
      fresh()
      var p = standup()
      var made = ""
      ws.saveAsTemplate(p.id, function(id) { made = id })
      tryVerify(function() { return made !== "" }, 2000)
      // From Templates.
      click(named(win(), "templatesRow"))
      var use = null
      tryVerify(function() { use = named(win(), "useTemplate"); return use !== null }, 1000)
      wait(200)
      mouseClick(use)
      tryVerify(function() { return view.page && view.page.title === "Standup " + today("ddd d MMM") && !Workspace.inTemplates(ws.index, view.page.id) }, 2000, "a new page from it")
      compare(ws.index.pages[view.page.id].parent, "")
      // New pages inside "Meetings" start from it.
      var meetings = ws.createPage({ parent: "", title: "Meetings" })
      openPage(meetings.id)
      ws.setChildTemplate(meetings.id, made)
      view.newPage(meetings.id)
      tryVerify(function() { return view.page && view.page.id !== meetings.id && ws.index.pages[view.page.id].parent === meetings.id }, 2000)
      tryVerify(function() { return view.editor.serialize().some(function(b) { return b.type === "check" }) }, 2000, "started from the template")
      view.commit()
      var onMeetings = Workspace.childPages(ws.readPageNow(meetings.id))
      verify(onMeetings.indexOf(view.page.id) >= 0, "its block on the page it's in")
    }

    function test_5_a_page_again_and_kept_apart() {
      fresh()
      var t = view.workspace.newTemplate()
      ws.editPage(t.id, function(x) { x.title = "Weekly review"; return true })
      tryVerify(function() { return ws.index.pages[t.id].title === "Weekly review" }, 1000)
      compare(Workspace.templates(ws.index).length, 1)
      // Not found, not a favorite, not linked to.
      compare(Workspace.findTitles(ws.index, "weekly", 9).length, 0)
      openPage(t.id)
      view.untemplate(t.id)
      compare(Workspace.templates(ws.index).length, 0)
      verify(Workspace.rows(ws.index, {}).some(function(r) { return r.id === t.id }), "in the tree again")
      verify(root.lastToast.indexOf("is a page again") >= 0)
      root.lastUndo()
      compare(Workspace.templates(ws.index).length, 1, "Undo: a template again")
    }

    function test_6_commands() {
      fresh()
      var p = standup()
      var made = ""
      ws.saveAsTemplate(p.id, function(id) { made = id })
      tryVerify(function() { return made !== "" }, 2000)
      var list = JSON.parse(api.templates())
      compare(list.length, 1)
      compare(list[0].title, "Standup {{date}}")
      compare(list[0].pages, 2)
      var r = JSON.parse(api.fromTemplate("standup {{date}}", "", "top"))
      verify(r.ok, JSON.stringify(r))
      compare(r.title, "Standup " + today("ddd d MMM"))
      var page = ws.readPageNow(r.id)
      compare(Html.plainText(Workspace.flatten(page)[0].html), today("dddd"))
      var named = JSON.parse(api.fromTemplate(made, "Monday sync", ""))
      verify(named.ok)
      compare(named.title, "Monday sync")
      verify(named.path.indexOf("Inbox") >= 0, "in the Inbox: " + named.path)
      var bad = JSON.parse(api.fromTemplate("nope", "", ""))
      verify(!bad.ok)
    }
  }
}
