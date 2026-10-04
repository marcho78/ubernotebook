import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Html.js" as Html
import "../../Notes.js" as Notes
import "../../Markdown.js" as Markdown
import "../../Import.js" as Import

// Footnotes in Pages: "/footnote" (its words in a small box), shown as its
// number, the list at the end of the page, numbered down the page (again
// when one goes in before), one clicked and changed or taken out (or from
// the list), and what's saved and written as Markdown.
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
    name: "Footnotes"
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
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === " ") keyClick(Qt.Key_Space)
        else keyClick(ch)
      }
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
    function all(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) all(item.children[i], test, out)
      return out
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    function newLine() {
      var e = view.editor
      e.insertBlocksAt(e.model.count, [{ type: "p", html: "", indent: 0 }])
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      return e.uidAt(e.model.count - 1)
    }
    function htmlOf(uid) { var e = view.editor; e.syncAll(); var i = e.indexOf(uid); return i >= 0 ? e.blockAt(i).html : "" }
    function listed() { return all(win(), function(it) { return it.objectName === "pageNote" }, []).map(function(r) { return r.words }) }
    // A footnote typed in at the end of a line, from the "/" menu (after a
    // space, which it takes the place of).
    function addNote(words) {
      var e = view.editor
      type(" /footnote")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 && e.slashItems[0].id === "footnote" }, 1000)
      keyClick(Qt.Key_Return)
      tryVerify(function() { return e.noteBox.opened }, 1000, "its box")
      verify(find(win(), function(it) { return it.objectName === "SlashMenu" }) === null, "the / menu gone, picked quickly as it was")
      named(win(), "noteField").text = words
      keyClick(Qt.Key_Return)
      // (All the way closed, not only closing: nothing in front of the line.)
      tryVerify(function() { return !e.noteBox.visible }, 1000)
    }

    function test_1_added_numbered_listed() {
      fresh()
      var e = view.editor
      var b = newLine()
      type("A later claim")
      addNote("Second source")
      compare(Notes.inText(htmlOf(b)), ["Second source"])
      compare(e.items[b].edit.length, 14, "one character to the cursor")
      verify(e.items[b].edit.getFormattedText(0, e.items[b].edit.length).indexOf(Notes.MARK) >= 0, "shown as its number")
      tryCompare(e, "pageNotes", ["Second source"])
      tryVerify(function() { return listed().join("|") === "Second source" }, 1000, "listed at the end")
      // Written on after it: not part of it.
      type(" and on")
      compare(Html.plainText(htmlOf(b)), "A later claimSecond source and on")
      compare(Notes.inText(htmlOf(b)), ["Second source"])
      // One in a line before it: numbered first, the other second.
      var a = e.uidAt(e.indexOf(b) - 1)
      e.focusBlock(a, e.items[a].edit.length)
      addNote("First source")
      tryVerify(function() { return listed().join("|") === "First source|Second source" }, 2000, "numbered down the page: " + listed().join("|"))
      compare(e.noteNumber("Second source"), 2)
      // Saved, and as Markdown: [^1], their words at the end.
      view.commit()
      var page = ws.readPageNow(view.page.id)
      verify(page.blocks[b].html.indexOf("uber-notebook://note/") >= 0)
      var md = Markdown.fromDocPage(page, function() { return null }, {})
      verify(md.indexOf("A later claim[^2] and on") >= 0, md)
      verify(md.indexOf("[^1]: First source\n[^2]: Second source") >= 0, md)
    }

    function test_2_clicked_changed_taken_out() {
      fresh()
      var e = view.editor
      var b = newLine()
      type("Claim")
      addNote("Smith 2021")
      var item = e.items[b]
      wait(100)
      var r = item.edit.positionToRectangle(5)
      var r2 = item.edit.positionToRectangle(6)
      mouseClick(item.edit, (r.x + r2.x) / 2, r.y + r.height / 2)
      tryVerify(function() { return e.noteBox.opened }, 1000, "its box")
      compare(named(win(), "noteField").text, "Smith 2021")
      compare(e.noteBox.number, 1)
      named(win(), "noteField").text = "Smith 2022, p. 4"
      keyClick(Qt.Key_Return)
      tryVerify(function() { return !e.noteBox.opened }, 1000)
      compare(Notes.inText(htmlOf(b)), ["Smith 2022, p. 4"])
      tryVerify(function() { return listed().join("|") === "Smith 2022, p. 4" }, 1000)
      // From the list: its box, at its place.
      wait(250)
      mouseClick(find(win(), function(it) { return it.text === "Smith 2022, p. 4" && it.width > 0 && typeof it.textFormat !== "undefined" && it.objectName === "" && it.parent && it.parent.objectName === "pageNote" }))
      tryVerify(function() { return e.noteBox.opened }, 1000, "opened from the list")
      wait(150)
      mouseClick(named(win(), "noteRemove"))
      tryVerify(function() { return !e.noteBox.opened }, 1000)
      compare(Notes.inText(htmlOf(b)), [], "taken out")
      compare(Html.plainText(htmlOf(b)), "Claim")
      tryCompare(e, "pageNotes", [])
      compare(named(win(), "pageNotes"), null, "no list without footnotes")
    }

    function test_3_from_markdown() {
      fresh()
      var e = view.editor
      // As agents write it ([^1] with its words at the end, or ^[words]),
      // put on the page open (as their append does).
      var got = Import.fromMarkdown("Text with a note[^1] and an inline one^[Said here].\n\n[^1]: The note.\n", {}, {})
      verify(view.appendFromCommand(view.page.id, got.blocks) === true)
      tryVerify(function() { return e.pageNotes.length === 2 }, 2000, "both: " + JSON.stringify(e.pageNotes))
      compare(e.pageNotes, ["The note.", "Said here"])
      tryVerify(function() { return listed().join("|") === "The note.|Said here" }, 1000)
    }
  }
}
