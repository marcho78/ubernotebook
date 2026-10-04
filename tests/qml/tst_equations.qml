import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Html.js" as Html
import "../../Equations.js" as Equations

// Equations in Pages: "/equation" (a code block in Math, drawn by MathJax in
// a worker; its LaTeX and the drawing under it while it's written), "$$…$$"
// typed in a line (kept as a link that holds its LaTeX, shown as its
// drawing), one clicked and changed or taken out, "/inline equation", and
// what's saved.
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
    name: "Equations"
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
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    function newLine() {
      var e = view.editor
      e.insertBlocksAt(e.model.count, [{ type: "p", html: "", indent: 0 }])
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      return e.uidAt(e.model.count - 1)
    }
    function htmlOf(uid) { var e = view.editor; e.syncAll(); var i = e.indexOf(uid); return i >= 0 ? e.blockAt(i).html : "(gone: " + uid + ")" }
    function shownOf(uid) { var it = view.editor.items[uid]; return it ? it.edit.getFormattedText(0, it.edit.length) : "" }
    // Drawn by MathJax (not the placeholder): a path from its fonts.
    function drawnIn(html) { return decodeURIComponent(html).indexOf("MJX-") >= 0 }

    function test_1_an_equation_block() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("/equation")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "equation")
      keyClick(Qt.Key_Return)
      tryCompare(e.blockAt(e.indexOf(uid)), "type", "code")
      compare(e.blockAt(e.indexOf(uid)).lang, "Math")
      var item = e.items[uid]
      verify(item.mathCode && item.edit.activeFocus, "its LaTeX, written in it")
      type("\\frac{a}{b} + x^2")
      // The drawing under it as it's written.
      tryVerify(function() { return item.mathSized !== null }, 8000, "drawn by MathJax, in the worker")
      verify(named(item, "drawnBlock") !== null)
      verify(item.edit.visible, "still being written: its LaTeX shows")
      // Somewhere else: just the drawing.
      var other = newLine()
      tryVerify(function() { return item.drawnView }, 1000)
      verify(!item.edit.visible, "its LaTeX away")
      var img = named(item, "mathImage")
      verify(img !== null && img.width > 20 && img.height > 20, "the equation, drawn: " + (img ? img.width + "x" + img.height : "none"))
      compare(Html.plainText(htmlOf(uid)), "\\frac{a}{b} + x^2", "kept as its LaTeX")
      // A click on it: its LaTeX again, to change.
      wait(100)
      mouseClick(img)
      tryVerify(function() { return item.edit.activeFocus && !item.drawnView }, 1000, "written again")
      // A mistake: said under it.
      e.focusBlock(uid, item.edit.length)
      type("}")
      tryVerify(function() { return item.mathError !== "" }, 8000, "what's wrong")
      verify(named(item, "drawnProblem") !== null)
      keyClick(Qt.Key_Backspace)
      tryVerify(function() { return item.mathError === "" }, 8000)
      // Saved as code in Math.
      view.commit()
      var saved = ws.readPageNow(view.page.id).blocks[uid]
      compare(saved.type, "code")
      compare(saved.lang, "Math")
    }

    function test_2_typed_in_a_line() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("Energy $$E = mc^2$$")
      tryVerify(function() { return Equations.inText(htmlOf(uid)).length === 1 }, 1000, "an equation")
      compare(Equations.inText(htmlOf(uid))[0], "E = mc^2")
      compare(Html.plainText(htmlOf(uid)), "Energy E = mc^2", "kept as its LaTeX: search and agents read it")
      verify(shownOf(uid).indexOf(Equations.MARK) >= 0, "shown as an image")
      compare(e.items[uid].edit.length, 8, "one character to the cursor")
      tryVerify(function() { return drawnIn(shownOf(uid)) }, 8000, "its drawing once MathJax drew it")
      // Writing on after it.
      type(" ok")
      compare(Html.plainText(htmlOf(uid)), "Energy E = mc^2 ok")
      compare(Equations.inText(htmlOf(uid)), ["E = mc^2"])
      // Saved, and opened again: still one.
      view.commit()
      var id = view.page.id
      verify(ws.readPageNow(id).blocks[uid].html.indexOf("uber-notebook://math/") >= 0)
      view.page = null
      view.open(id)
      tryVerify(function() { return view.page && view.page.id === id && view.editor.items[uid] }, 2000)
      tryVerify(function() { return drawnIn(shownOf(uid)) }, 2000, "drawn again at once (kept)")
      // Not in code.
      var code = newLine()
      e.convert(code, "code", false)
      e.focusBlock(code, 0)
      type("echo $$x$$")
      compare(Equations.inText(htmlOf(code)), [], "code stays code")
    }

    function test_3_one_clicked_and_changed() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("Area $$\\pi r^2$$ here")
      tryVerify(function() { return drawnIn(shownOf(uid)) }, 8000)
      var item = e.items[uid]
      // Where the image is (after "Area ").
      var r = item.edit.positionToRectangle(5)
      var r2 = item.edit.positionToRectangle(6)
      wait(100)
      mouseClick(item.edit, (r.x + r2.x) / 2, r.y + r.height / 2)
      var box = e.mathBox
      tryVerify(function() { return box.opened }, 1000, "its box")
      compare(box.tex, "\\pi r^2")
      var field = named(win(), "mathField")
      field.text = "\\pi r^2 h"
      field.edited(field.text)
      tryVerify(function() { return box.sized !== null }, 8000, "drawn as it's written")
      wait(50)
      mouseClick(named(win(), "mathDone"))
      tryVerify(function() { return !box.opened }, 1000)
      compare(Equations.inText(htmlOf(uid)), ["\\pi r^2 h"])
      compare(Html.plainText(htmlOf(uid)), "Area \\pi r^2 h here")
      // Taken out.
      wait(250)
      r = item.edit.positionToRectangle(5)
      r2 = item.edit.positionToRectangle(6)
      mouseClick(item.edit, (r.x + r2.x) / 2, r.y + r.height / 2)
      tryVerify(function() { return box.opened }, 1000)
      wait(50)
      mouseClick(named(win(), "mathRemove"))
      tryVerify(function() { return !box.opened }, 1000)
      compare(Equations.inText(htmlOf(uid)), [])
      compare(Html.plainText(htmlOf(uid)), "Area  here")
      // Undo brings it back.
      e.undo()
      tryVerify(function() { return Equations.inText(htmlOf(uid)).length === 1 }, 1000)
    }

    function test_4_inline_equation_from_the_menu() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("Sum: /inline")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 && e.slashItems[0].id === "inlinemath" }, 1000)
      keyClick(Qt.Key_Return)
      var box = e.mathBox
      tryVerify(function() { return box.opened }, 1000, "its box, empty")
      compare(box.tex, "")
      var field = named(win(), "mathField")
      field.text = "\\sum_i x_i"
      keyClick(Qt.Key_Return)
      tryVerify(function() { return !box.opened }, 1000)
      compare(Equations.inText(htmlOf(uid)), ["\\sum_i x_i"])
      compare(Html.plainText(htmlOf(uid)), "Sum: \\sum_i x_i")
    }
  }
}
