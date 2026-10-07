import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Html.js" as Html
import "../../Docs.js" as Docs
import "../../Colors.js" as Colors

// Colors of your own in Pages, as mind maps and tables have them: on words
// you select (the toolbar over them) and on whole blocks (⋮⋮ → Color), the
// colors you picked last and Custom…, the color picker. There were only
// Pages' nine.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  DocView { id: view; anchors.fill: parent; theme: th; workspace: ws; service: service }

  TestCase {
    name: "Colors"
    when: windowShown

    function fresh(blocks) {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      view.editor.readOnly = false
      view.editor.load(blocks)
      waitForRendering(view)
      wait(50)
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
    function win() { return root.Window.window.contentItem }
    function findText(item, text) { return find(item, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }) }
    function clickText(text) {
      tryVerify(function() { return findText(win(), text) !== null }, 1000, text + " is on screen")
      wait(250)
      mouseClick(findText(win(), text))
    }
    function tile(test) {
      tryVerify(function() { return find(win(), test) !== null }, 1000, "the color is on screen")
      wait(250)
      return find(win(), test)
    }
    function typeHex(hex) {
      wait(200)
      for (var i = 0; i < hex.length; i++) keyClick(hex.charAt(i))
    }
    function html(i) { return view.editor.serialize()[i].html || "" }
    function colorOf(i) { return view.editor.serialize()[i].color || "" }
    // The words from `a` to `b` in block i, selected; the toolbar's color button.
    function select(i, a, b) {
      var e = view.editor
      e.focusBlock(e.uidAt(i), b, a)
      tryVerify(function() { return e.formatState.hasSelection === true }, 1000)
      var button = null
      tryVerify(function() { button = find(win(), function(it) { return it.tip === "Color" && it.width > 0 }); return button !== null }, 1000, "the toolbar's color button")
      wait(150)
      return button
    }

    function test_1_words_take_a_color_of_your_own() {
      fresh([{ type: "p", html: "Paint these words only" }, { type: "p", html: "" }])
      mouseClick(select(0, 6, 11))
      // Pages' nine are there, and Custom… for the text and behind it.
      verify(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === "red" && it.back === false }))
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText(win(), "Text color of your own") !== null }, 1000, "the color picker")
      typeHex("#2a6f97")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return html(0).indexOf("#2a6f97") >= 0 }, 1000, "the words in it")
      var words = Html.plainText(html(0))
      compare(words, "Paint these words only", "nothing else changed")
      verify(/color:#2a6f97;?">these<\/span>/.test(html(0)), html(0))
      compare(service.settings.recentColors.split(",")[0], "#2a6f97", "kept among your recent colors")
      // Other words: it's there, among the ones you picked last.
      tryVerify(function() { return findText(win(), "Text color of your own") === null }, 1000)
      mouseClick(select(0, 18, 22))
      mouseClick(tile(function(it) { return it.custom === "#2a6f97" && it.back === false }))
      tryVerify(function() { return /color:#2a6f97;?">only<\/span>/.test(html(0)) }, 1000, html(0))
      // Behind them.
      wait(200)
      mouseClick(select(0, 0, 5))
      mouseClick(tile(function(it) { return it.plus === true && it.back === true }))
      tryVerify(function() { return findText(win(), "Background of your own") !== null }, 1000)
      typeHex("#ffd166")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return html(0).indexOf("background-color:#ffd166") >= 0 }, 1000, html(0))
      // Esc: nothing.
      tryVerify(function() { return findText(win(), "Background of your own") === null }, 1000)
      var before = html(0)
      mouseClick(select(0, 12, 17))
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText(win(), "Text color of your own") !== null }, 1000)
      typeHex("#ff0000")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return findText(win(), "Text color of your own") === null }, 1000)
      compare(html(0), before, "put back as it was")
    }

    function test_2_blocks_take_a_color_of_your_own() {
      fresh([{ type: "p", html: "A note" }, { type: "p", html: "Another" }, { type: "p", html: "" }])
      var e = view.editor
      e.blockMenuRequested(e.uidAt(0))
      clickText("Color")
      // The same colors as words: Pages' (red, behind it), kept as before.
      mouseClick(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === "red" && it.back === true }))
      tryCompare(e.serialize()[0], "color", "red_background", 1000)
      wait(250)
      // One of your own: on the block as you pick, kept with Enter, one step.
      e.blockMenuRequested(e.uidAt(0))
      clickText("Color")
      verify(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === "red" && it.back === true }).chosen, "what it has, marked")
      mouseClick(tile(function(it) { return it.plus === true && it.back === true }))
      tryVerify(function() { return findText(win(), "Background of your own") !== null }, 1000)
      typeHex("#14213d")
      tryCompare(e.serialize()[0], "color", "#14213d_background", 1000, "shown as you pick it")
      var item = e.items[e.uidAt(0)]
      compare(String(item.inkColor), String(Qt.color(Colors.readableOn("#14213d", String(th.text)))), "its text reads on it")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return findText(win(), "Background of your own") === null }, 1000)
      compare(colorOf(0), "#14213d_background")
      compare(service.settings.recentColors.split(",")[0], "#14213d")
      e.undo()
      compare(colorOf(0), "red_background", "one step to undo")
      e.redo()
      compare(colorOf(0), "#14213d_background")
      // Cancel puts back what was there.
      wait(250)
      e.blockMenuRequested(e.uidAt(1))
      clickText("Color")
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText(win(), "Text color of your own") !== null }, 1000)
      typeHex("#ff0000")
      tryCompare(e.serialize()[1], "color", "#ff0000", 1000)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return findText(win(), "Text color of your own") === null }, 1000)
      compare(colorOf(1), "", "put back")
      // A recent one, from the grid; and saved and read back as it is.
      wait(250)
      e.blockMenuRequested(e.uidAt(1))
      clickText("Color")
      mouseClick(tile(function(it) { return it.custom === "#14213d" && it.back === false }))
      tryCompare(e.serialize()[1], "color", "#14213d", 1000)
      view.commit()
      var page = ws.readPageNow(view.page.id)
      var kept = Object.keys(page.blocks).map(function(k) { return page.blocks[k].color }).filter(function(c) { return c })
      verify(kept.indexOf("#14213d") >= 0 && kept.indexOf("#14213d_background") >= 0, JSON.stringify(kept))
    }
  }
}
