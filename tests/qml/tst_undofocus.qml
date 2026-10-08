import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Calendar.js" as Calendar

// Ctrl+Z after a click on a block's own buttons (an agenda's day, a board's
// card): the change made, the keyboard goes to the page, so it undoes there. It stayed where
// it was, even in a view put away (People), and Ctrl+Z went nowhere. Typing
// in a box of a block's own (a card, a cell, a popup's field) keeps it.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  DocView { id: view; anchors.fill: parent; theme: th; workspace: ws; service: service }

  // Somewhere the keyboard can be left, then put away (as People is).
  TextInput { id: elsewhere; visible: false; width: 10; height: 10 }

  TestCase {
    name: "UndoFocus"
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
    function fresh(list) {
      view.closeEvent()
      files.reset()
      view.page = null
      view.peopleShown = false
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      view.editor.load(list)
      waitForRendering(view)
      wait(100)
    }
    // The keyboard left in something put away.
    function away() {
      elsewhere.visible = true
      elsewhere.forceActiveFocus()
      elsewhere.visible = false
      verify(root.Window.activeFocusItem === elsewhere, "left elsewhere")
    }
    function dayOf(i) { var b = view.editor.blockAt(i); return Calendar.cleanRef(b.calendar || {}).day }
    function agendaButton(i, name) { return named(view.editor.items[view.editor.uidAt(i)], name) }

    function test_1_an_agenda_day_then_ctrl_z() {
      fresh([{ type: "p", html: "Above" }, { type: "agenda" }, { type: "p", html: "" }])
      away()
      mouseClick(agendaButton(1, "agendaOn"))
      wait(50)
      verify(dayOf(1) !== "", "a day on")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      tryVerify(function() { return dayOf(1) === "" }, 1000, "undone")
      keyClick(Qt.Key_Z, Qt.ControlModifier | Qt.ShiftModifier)
      tryVerify(function() { return dayOf(1) !== "" }, 1000, "and redone")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      tryVerify(function() { return dayOf(1) === "" }, 1000)
      keyClick(Qt.Key_Y, Qt.ControlModifier)
      tryVerify(function() { return dayOf(1) !== "" }, 1000, "Ctrl+Y too")
    }

    function test_2_a_board_card_then_ctrl_z() {
      fresh([{ type: "board", indent: 0, data: { columns: [{ id: "a", name: "To do", cards: [{ id: "k", text: "Ship it" }] }] } }, { type: "p", html: "" }])
      var bv = view.editor.items[view.editor.uidAt(0)]
      var card = null
      tryVerify(function() { card = named(bv, "boardCard"); return card !== null }, 1000)
      away()
      mouseClick(card)
      var edit = null
      tryVerify(function() { edit = named(bv, "boardCardEdit"); return edit !== null && edit.activeFocus }, 1000, "writing in the card keeps the keyboard")
      edit.selectAll()
      for (var c of "Draft") keyClick(c)
      keyClick(Qt.Key_Return)
      var text = function() { return JSON.stringify(view.editor.blockAt(0).data) }
      tryVerify(function() { return text().indexOf("Draft") >= 0 }, 1000)
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      tryVerify(function() { return text().indexOf("Ship it") >= 0 && text().indexOf("Draft") < 0 }, 1000, "undone after the card")
    }

    function test_3_back_from_people() {
      fresh([{ type: "p", html: "Above" }, { type: "agenda" }, { type: "p", html: "" }])
      var id = view.page.id
      view.commit()
      view.openPeople("")
      tryVerify(function() { return view.peopleShown }, 1000)
      wait(100)
      view.open(id)
      tryVerify(function() { return !view.peopleShown && view.page && view.page.id === id }, 1000)
      tryVerify(function() { var f = root.Window.activeFocusItem; return f !== null && f.visible }, 1000, "the keyboard back on the page")
      // (The page as it was saved: the agenda again, to change.)
      view.editor.load([{ type: "p", html: "Above" }, { type: "agenda" }, { type: "p", html: "" }])
      waitForRendering(view)
      wait(100)
      mouseClick(agendaButton(1, "agendaOn"))
      wait(50)
      verify(dayOf(1) !== "")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      tryVerify(function() { return dayOf(1) === "" }, 1000, "undone")
    }

    function test_4_typing_where_it_was_clicked() {
      // A popup's field, opened by a block's button, keeps the keyboard.
      fresh([{ type: "p", html: "Above" }, { type: "agenda" }, { type: "p", html: "" }])
      away()
      mouseClick(agendaButton(1, "agendaAdd"))
      var field = null
      tryVerify(function() { field = named(win(), "quickAdd"); return field !== null && field.input.activeFocus }, 1000, "the quick add has it")
      wait(100)
      for (var c of "Lunch") keyClick(c)
      compare(field.text, "Lunch")
      keyClick(Qt.Key_Escape)
      // A table's cell too.
      fresh([{ type: "table", table: { rows: [["a", "b"], ["c", "d"]] } }, { type: "p", html: "" }])
      away()
      var tv = null
      tryVerify(function() { var it = view.editor.items[view.editor.uidAt(0)]; tv = it ? it.tableView : null; return tv !== null }, 1000)
      var cell = null
      tryVerify(function() { cell = tv.cellAt(1, 1); return cell !== null }, 1000)
      mouseClick(cell)
      wait(100)
      for (var k of "xyz") keyClick(k)
      tryVerify(function() { return JSON.stringify(view.editor.serialize()[0].table.rows).indexOf("xyz") >= 0 }, 1000, "typed in the cell")
    }
  }
}
