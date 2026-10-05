import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html

// Page history: versions kept as you write and before commands change a
// page, the history panel, and putting a version back (undoably, with the
// pages in the page kept).
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  TestCase {
    name: "History"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.historyGap = 10 * 60 * 1000
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      wait(0)
      // As if the pages were made in an earlier session (a page made just
      // now counts as just kept).
      ws.keptAt = ({})
      ws.keptJson = ({})
    }
    function versionsOf(id) {
      var dir = Workspace.historyDir(files.rootPath, id) + "/"
      return Object.keys(files.disk).filter(function(p) { return p.indexOf(dir) === 0 }).sort()
    }
    function versionAt(path) { return files.parseJson(files.disk[path]) }
    function texts() { return view.editor.serialize().map(function(b) { return Html.plainText(b.html || "") }) }
    function write(text) {
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, -1)
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i))
      view.markDirty()
      view.commit()
    }

    function test_1_kept_as_you_write() {
      fresh()
      var id = view.page.id
      compare(versionsOf(id).length, 0, "none for a page just made")
      var before = texts()
      write("first")
      var list = versionsOf(id)
      compare(list.length, 1, "the page as it was, before the first change")
      var v = versionAt(list[0])
      compare(v.why, "edit")
      compare(Workspace.flatten(v.page).map(function(b) { return Html.plainText(b.html || "") }), before, "as it was")
      write("second")
      compare(versionsOf(id).length, 1, "not again within ten minutes")
      ws.historyGap = 0
      write("third")
      compare(versionsOf(id).length, 2, "again after ten minutes")
      // Before a command changes it: always.
      ws.historyGap = 10 * 60 * 1000
      verify(ws.keepVersion(id, "command", true))
      list = versionsOf(id)
      compare(list.length, 3)
      compare(versionAt(list[2]).why, "command")
      verify(!ws.keepVersion(id, "command", true), "but not the same page twice")
    }

    // A version that couldn't be written doesn't hold back the next ten
    // minutes: the next save keeps one.
    function test_1b_a_version_not_written_is_kept_next_time() {
      fresh()
      var id = view.page.id
      files.failWrites = Workspace.historyDir(files.rootPath, id)
      write("first")
      compare(versionsOf(id).length, 0, "it couldn't be written")
      files.failWrites = ""
      write("second")
      var list = versionsOf(id)
      compare(list.length, 1, "kept with the next save")
      compare(versionAt(list[0]).page.title, view.page.title)
    }

    function test_2_the_panel_and_putting_a_version_back() {
      fresh()
      var id = view.page.id
      var original = texts()
      var title = view.page.title
      write("changed")
      verify(texts().join("|") !== original.join("|"))
      view.openHistory()
      var panel = view.historyPanel
      tryVerify(function() { return panel.opened && panel.versions.length === 1 && panel.shown !== null }, 2000, "the version, shown")
      compare(panel.shown.page.title, title)
      tryVerify(function() { return panel.previewEditor.model.count > 0 }, 1000)
      compare(panel.previewEditor.serialize().map(function(b) { return Html.plainText(b.html || "") }), original, "the preview is the page as it was")
      verify(panel.previewEditor.readOnly)
      panel.restore()
      tryVerify(function() { return !panel.visible }, 1000)
      compare(texts(), original, "put back")
      compare(view.page.title, title, "its title too")
      var list = versionsOf(id)
      compare(versionAt(list[list.length - 1]).why, "restore", "the page as it was before, kept")
      verify(Workspace.flatten(versionAt(list[list.length - 1]).page).some(function(b) { return Html.plainText(b.html || "").indexOf("changed") >= 0 }))
      // Undo takes it back.
      view.editor.undo()
      verify(texts().some(function(t) { return t.indexOf("changed") >= 0 }), "Undo: the page as it was before")
    }

    function test_3_pages_in_the_page_stay() {
      fresh()
      var id = view.page.id
      write("x")
      // A page made inside it after that version.
      view.newPage(id)
      tryVerify(function() { return view.page && view.page.id !== id }, 2000)
      var child = view.page.id
      view.open(id)
      tryVerify(function() { return view.page && view.page.id === id }, 2000)
      verify(Workspace.childPages(view.page).indexOf(child) >= 0)
      view.openHistory()
      var panel = view.historyPanel
      tryVerify(function() { return panel.shown !== null }, 2000)
      panel.pick(panel.versions.length - 1)
      tryVerify(function() { return panel.shown !== null && panel.current === panel.versions.length - 1 }, 2000)
      verify(Workspace.childPages(panel.shown.page).indexOf(child) < 0, "a version from before it")
      panel.restore()
      tryVerify(function() { return !panel.visible }, 1000)
      verify(Workspace.childPages(view.page).indexOf(child) >= 0, "the page made since is still in it")
      verify(!ws.index.pages[child].trashed, "and not in the trash")
    }

    function test_4_a_page_with_no_history_yet() {
      fresh()
      view.newPage("")
      tryVerify(function() { return view.page && view.page.title === "" }, 2000)
      view.openHistory()
      var panel = view.historyPanel
      tryVerify(function() { return panel.opened && !panel.listing }, 2000)
      compare(panel.versions.length, 0)
      verify(panel.shown === null)
      panel.close()
    }
  }
}
