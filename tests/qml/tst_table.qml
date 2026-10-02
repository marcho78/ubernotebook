import QtQuick
import QtTest
import "../.." as Omanote
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html
import "../../Docs.js" as Docs

// Tables in Pages: "/table", writing in cells and moving between them, the
// rows' and columns' menus, widths, pasting cells, undo, and the page saved.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  Omanote.Workspace { id: ws; files: files }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  TestCase {
    name: "Tables"
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
      view.editor.readOnly = false
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === " ") keyClick(Qt.Key_Space)
        else keyClick(ch)
      }
    }
    function copy(text) {
      clip.text = text
      clip.selectAll()
      clip.copy()
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
    function anyNamed(item, name) {
      if (!item) return null
      if (item.objectName === name) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = anyNamed(item.children[i], name)
        if (hit) return hit
      }
      return null
    }
    function findText(item, text) { return find(item, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }) }
    function clickText(text) {
      var win = root.Window.window.contentItem
      tryVerify(function() { return findText(win, text) !== null }, 1000, text + " is on screen")
      wait(250)
      mouseClick(findText(win, text))
    }
    // The table's cells as plain text.
    function cellsOf(b) { return b.table.rows.map(function(r) { return r.map(function(c) { return Html.plainText(c) }) }) }
    function tableAt(i) { return view.editor.serialize()[i] }
    function put(rows, header) {
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "table", table: { rows: rows, header: header !== false }, indent: 0 }])
      var uid = e.uidAt(0)
      tryVerify(function() { return e.items[uid] && e.items[uid].tableView }, 1000)
      return e.items[uid].tableView
    }

    function test_1_slash_table_and_writing_in_it() {
      fresh()
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      type("/table")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "table")
      keyClick(Qt.Key_Return)
      var at = e.serialize().map(function(b) { return b.type }).indexOf("table")
      verify(at >= 0, "a table on the page")
      var uid = e.uidAt(at)
      var tv = e.items[uid].tableView
      tryVerify(function() { return tv.writing && tv.curRow === 0 && tv.curCol === 0 }, 1000, "writing in its first cell")
      compare([tv.rowCount, tv.cols], [3, 3])
      type("Name")
      keyClick(Qt.Key_Tab)
      type("Qty")
      keyClick(Qt.Key_Return)
      compare([tv.curRow, tv.curCol], [1, 1], "Enter: the cell below")
      type("3")
      keyClick(Qt.Key_Tab, Qt.ShiftModifier)
      compare([tv.curRow, tv.curCol], [1, 0], "Shift+Tab: the cell before")
      type("Apples")
      compare(cellsOf(tableAt(at)).slice(0, 2), [["Name", "Qty", ""], ["Apples", "3", ""]])
      // Tab in the last cell: a new row, and you're in it.
      tv.focusCell(2, 2, -1)
      keyClick(Qt.Key_Tab)
      tryVerify(function() { return tv.rowCount === 4 && tv.curRow === 3 && tv.curCol === 0 }, 1000, "Tab past the last cell makes a row")
      type("Pears")
      compare(cellsOf(tableAt(at))[3], ["Pears", "", ""])
      // Undo: the writing, then the row.
      e.undo()
      compare(cellsOf(tableAt(at))[3], ["", "", ""], "the writing")
      e.undo()
      compare(tableAt(at).table.rows.length, 3, "then the row")
      verify(cellsOf(tableAt(at))[1][0] === "Apples", "what was written before stays")
      // Saved with the page.
      view.commit()
      var file = files.parseJson(files.disk[Workspace.pageFile(files.rootPath, view.page.id)])
      var saved = file.blocks[uid]
      compare(saved.type, "table")
      compare(saved.table.rows[0].map(Html.plainText), ["Name", "Qty", ""])
    }

    function test_2_the_arrows_and_shift_enter() {
      fresh()
      var e = view.editor
      var tv = put([["a", "b"], ["c", "d"]])
      e.insertBlocksAt(0, [{ type: "p", html: "above", indent: 0 }])
      var uid = e.uidAt(1)
      tv = e.items[uid].tableView
      e.focusBlock(e.uidAt(0), -1)
      keyClick(Qt.Key_Down)
      tryVerify(function() { return tv.writing && tv.curRow === 0 }, 1000, "Down into the table's first row")
      keyClick(Qt.Key_Down)
      compare(tv.curRow, 1)
      keyClick(Qt.Key_Down)
      tryVerify(function() { return !tv.writing }, 1000, "and out at the bottom")
      compare(e.focusUid, e.uidAt(2))
      keyClick(Qt.Key_Up)
      tryVerify(function() { return tv.writing && tv.curRow === 1 }, 1000, "Up into its last row")
      keyClick(Qt.Key_Up)
      keyClick(Qt.Key_Up)
      tryVerify(function() { return e.focusUid === e.uidAt(0) && !tv.writing }, 1000, "out at the top")
      // Left and Right cross cells at their ends.
      tv.focusCell(0, 0, -1)
      keyClick(Qt.Key_Right)
      compare([tv.curRow, tv.curCol], [0, 1])
      keyClick(Qt.Key_Left)
      keyClick(Qt.Key_Left)
      compare([tv.curRow, tv.curCol], [0, 0])
      // Shift+Enter: a new line in the cell.
      tv.focusCell(1, 1, -1)
      keyClick(Qt.Key_Return, Qt.ShiftModifier)
      type("e")
      compare(cellsOf(tableAt(1))[1][1], "d\ne")
      // Esc picks the table.
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return e.selectedMap[uid] === true }, 1000)
    }

    function test_3_rows_and_columns_from_their_handles() {
      fresh()
      var e = view.editor
      var tv = put([["Name", "Qty"], ["Apples", "3"], ["Pears", "10"]])
      var uid = e.uidAt(0)
      var cell = tv.cellAt(1, 1)
      mouseMove(cell, cell.width / 2, cell.height / 2)
      tryVerify(function() { return tv.handleRow === 1 && tv.handleCol === 1 }, 1000, "handles for the row and column under the pointer")
      // The pointer on a handle: it stays where it is, lit up.
      var rowHandle = named(tv, "rowHandle")
      mouseMove(rowHandle, rowHandle.width / 2, rowHandle.height / 2)
      tryVerify(function() { return tv.onRowHandle }, 1000, "the row's handle sees the pointer")
      compare(tv.handleRow, 1, "and stays on its row")
      mouseMove(cell, cell.width / 2, cell.height / 2)
      var colHandle = named(tv, "colHandle")
      mouseMove(colHandle, colHandle.width / 2, colHandle.height - 3)
      tryVerify(function() { return tv.onColHandle }, 1000, "the column's handle sees the pointer")
      compare(tv.handleCol, 1, "and stays on its column")
      verify(colHandle.visible)
      mouseClick(colHandle)
      clickText("Insert column right")
      tryVerify(function() { return tv.cols === 3 }, 1000)
      compare(cellsOf(tableAt(0))[0], ["Name", "Qty", ""])
      compare([tv.curRow, tv.curCol].join(), "0,2", "and you're in it")
      tv.focusCell(1, 2, 0)
      type("kg")
      // The row's menu: move it up, then out.
      cell = tv.cellAt(2, 0)
      mouseMove(cell, 5, 5)
      tryVerify(function() { return tv.handleRow === 2 }, 1000)
      mouseClick(named(tv, "rowHandle"))
      clickText("Move up")
      tryVerify(function() { return cellsOf(tableAt(0))[1][0] === "Pears" }, 1000)
      compare(cellsOf(tableAt(0))[2], ["Apples", "3", "kg"], "the row moved, with what was written")
      cell = tv.cellAt(1, 0)
      mouseMove(cell, 5, 5)
      tryVerify(function() { return tv.handleRow === 1 }, 1000)
      mouseClick(named(tv, "rowHandle"))
      clickText("Delete row")
      tryVerify(function() { return tv.rowCount === 2 }, 1000)
      compare(cellsOf(tableAt(0)), [["Name", "Qty", ""], ["Apples", "3", "kg"]])
      // The header row, off.
      mouseMove(tv.cellAt(0, 0), 5, 5)
      tryVerify(function() { return tv.handleRow === 0 }, 1000)
      mouseClick(named(tv, "rowHandle"))
      clickText("Header row")
      tryVerify(function() { return tableAt(0).table.header === false }, 1000)
      // Each a step to undo.
      e.undo()
      compare(tableAt(0).table.header, true)
      e.undo()
      compare(tableAt(0).table.rows.length, 3)
      // + below: a new row.
      mouseMove(tv.cellAt(1, 1), 5, 5)
      var add = named(tv, "addRow")
      tryVerify(function() { return add.visible }, 1000)
      mouseClick(add)
      tryVerify(function() { return tv.rowCount === 4 }, 1000)
      // + at the right: a new column.
      mouseMove(tv.cellAt(1, 1), 5, 5)
      var addCol = named(tv, "addCol")
      tryVerify(function() { return addCol.visible }, 1000)
      mouseClick(addCol)
      tryVerify(function() { return tv.cols === 4 }, 1000)
    }

    function test_4_widths() {
      fresh()
      var e = view.editor
      var tv = put([["a", "b"], ["c", "d"]])
      compare(tableAt(0).table.widths, [0.5, 0.5])
      var edge = named(tv, "edge")
      verify(edge !== null, "an edge between the columns")
      var y = 20
      mousePress(edge, edge.width / 2, y)
      for (var i = 1; i <= 10; i++) mouseMove(edge, edge.width / 2 + i * 10, y)
      mouseRelease(edge, edge.width / 2 + 100, y)
      tryVerify(function() { return tableAt(0).table.widths[0] > 0.55 }, 1000, "the first column wider")
      var w = tableAt(0).table.widths
      compare(Math.round((w[0] + w[1]) * 1000), 1000)
      e.undo()
      compare(tableAt(0).table.widths, [0.5, 0.5], "one step to undo")
    }

    function test_5_pasting_cells() {
      fresh()
      var e = view.editor
      // From a spreadsheet onto an empty line: a table.
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      copy("Name\tQty\nApples\t3\nPears\t10")
      keyClick(Qt.Key_V, Qt.ControlModifier)
      var list = e.serialize()
      var at = list.map(function(b) { return b.type }).indexOf("table")
      verify(at >= 0, "pasted as a table")
      compare(cellsOf(list[at]), [["Name", "Qty"], ["Apples", "3"], ["Pears", "10"]])
      compare(list[at].table.header, true)
      // Into a cell: they fill the table from there, and it grows.
      var tv = e.items[e.uidAt(at)].tableView
      tryVerify(function() { return tv !== null }, 1000)
      tv.focusCell(2, 1, -1)
      copy("11\tkg\n12\tg")
      keyClick(Qt.Key_V, Qt.ControlModifier)
      tryVerify(function() { return tv.rowCount === 4 && tv.cols === 3 }, 1000)
      compare(cellsOf(tableAt(at)), [["Name", "Qty", ""], ["Apples", "3", ""], ["Pears", "11", "kg"], ["", "12", "g"]])
      e.undo()
      compare(cellsOf(tableAt(at)), [["Name", "Qty"], ["Apples", "3"], ["Pears", "10"]], "one step to undo")
      // Plain words go in where the cursor is.
      tv.focusCell(0, 0, -1)
      copy(" list")
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(cellsOf(tableAt(at))[0][0], "Name list")
      // A Markdown table pasted: a table.
      last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      copy("| A | B |\n|---|---|\n| **1** | 2 |")
      keyClick(Qt.Key_V, Qt.ControlModifier)
      list = e.serialize()
      var md = list.filter(function(b) { return b.type === "table" })
      compare(md.length, 2)
      compare(cellsOf(md[1]), [["A", "B"], ["1", "2"]])
      verify(/font-weight:700/.test(md[1].table.rows[1][0]), "bold kept")
    }

    function test_6_formatting_in_a_cell() {
      fresh()
      var e = view.editor
      var tv = put([["Name", "Note"], ["Apples", "red ones"]])
      tv.focusCell(1, 1, 0)
      var cell = tv.cellAt(1, 1)
      cell.edit.select(0, 3)
      keyClick(Qt.Key_B, Qt.ControlModifier)
      tryVerify(function() { return /font-weight:700/.test(tableAt(0).table.rows[1][1]) }, 1000)
      compare(Html.plainText(tableAt(0).table.rows[1][1]), "red ones")
      compare(cell.edit.selectedText, "red", "still selected")
      e.undo()
      verify(!/font-weight:700/.test(tableAt(0).table.rows[1][1]))
    }

    function test_8_never_lost_by_accident() {
      fresh()
      var e = view.editor
      put([["a", "b"], ["c", "d"]])
      e.insertBlocksAt(0, [{ type: "p", html: "above", indent: 0 }])
      var uid = e.uidAt(1)
      e.focusBlock(e.uidAt(0), -1)
      keyClick(Qt.Key_Delete)
      compare(e.typeOf(uid), "table", "Delete at the end of the line above doesn't take it")
      verify(e.selectedMap[uid] === true, "it picks it")
      e.clearBlockSelection()
      e.focusBlock(e.uidAt(2), 0)
      keyClick(Qt.Key_Backspace)
      compare(e.typeOf(uid), "table", "nor Backspace below it")
      // Turned into a mind map with the line above it: its rows are ideas.
      e.clearBlockSelection()
      e.selectBlocks(e.uidAt(0), uid)
      var made = e.toMindMap(e.selectedList)
      verify(made !== "")
      compare(e.blockAt(e.indexOf(made)).outline, "Mind map\n  above\n  a \u00b7 b\n  c \u00b7 d")
    }

    // A color tile in the color menu that's open.
    function tile(test) {
      var win = root.Window.window.contentItem
      var t = null
      tryVerify(function() { t = find(win, test); return t !== null }, 1000, "the color is on screen")
      wait(250)
      return find(win, test)
    }
    function pickColor(id, background) {
      mouseClick(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === id && it.back === background }))
      // (The menu fades out before what's under it can be clicked.)
      wait(200)
    }

    function test_9_colors() {
      fresh()
      var e = view.editor
      var tv = put([["Item", "Qty"], ["Apples", "3"], ["Pears", "10"]])
      var win = root.Window.window.contentItem
      // The cell you're in: its color button.
      tv.focusCell(1, 1, -1)
      var button = named(tv, "colorButton")
      verify(button !== null && button.visible, "a color button on the cell you're in")
      mouseClick(button)
      pickColor("red", true)
      tryCompare(tableAt(0).table.colors[1], "1", "|red", 1000)
      compare(String(tv.cellAt(1, 1).color), String(Qt.color(Docs.colorEntry("red").background[th.dark ? 1 : 0])), "drawn in it")
      tryVerify(function() { return tv.writing && tv.curRow === 1 && tv.curCol === 1 }, 1000, "and you're still writing in it")
      mouseClick(named(tv, "colorButton"))
      pickColor("blue", false)
      tryCompare(tableAt(0).table.colors[1], "1", "blue|red", 1000)
      compare(String(tv.cellAt(1, 1).edit.color), String(Qt.color(Docs.colorEntry("blue").text[th.dark ? 1 : 0])))
      // A whole row, from its menu.
      mouseMove(tv.cellAt(2, 0), 5, 5)
      tryVerify(function() { return tv.handleRow === 2 }, 1000)
      mouseClick(named(tv, "rowHandle"))
      clickText("Color")
      pickColor("yellow", true)
      tryVerify(function() { return tableAt(0).table.colors && tableAt(0).table.colors[2].join() === "|yellow,|yellow" }, 1000)
      // A color of your own, from the picker: shown as you pick, kept with Enter.
      tv.focusCell(0, 0, -1)
      mouseClick(named(tv, "colorButton"))
      mouseClick(tile(function(it) { return it.plus === true && it.back === true }))
      tryVerify(function() { return findText(win, "Background of your own") !== null }, 1000, "the color picker")
      wait(200)
      var hex = "#2a6f97"
      for (var i = 0; i < hex.length; i++) keyClick(hex.charAt(i))
      tryCompare(tv.cellAt(0, 0), "backHex", hex, 1000, "shown as you pick it")
      compare(tableAt(0).table.colors[0][0], "", "not kept yet")
      keyClick(Qt.Key_Return)
      tryCompare(tableAt(0).table.colors[0], "0", "|" + hex, 1000)
      verify(String(tv.cellAt(0, 0).edit.color) !== String(Qt.color(th.text)) || th.dark, "text readable on it")
      compare(service.settings.recentColors.split(",")[0], hex, "kept among your recent colors")
      // Cancel puts back what was there.
      tryVerify(function() { return findText(win, "Background of your own") === null }, 1000)
      wait(200)
      tv.focusCell(0, 1, -1)
      mouseClick(named(tv, "colorButton"))
      mouseClick(tile(function(it) { return it.plus === true && it.back === false }))
      tryVerify(function() { return findText(win, "Text color of your own") !== null }, 1000)
      wait(200)
      for (var j = 0; j < "#ff0000".length; j++) keyClick("#ff0000".charAt(j))
      tryVerify(function() { return String(tv.cellAt(0, 1).edit.color) === String(Qt.color("#ff0000")) }, 1000)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return String(tv.cellAt(0, 1).edit.color) !== String(Qt.color("#ff0000")) }, 1000, "put back")
      compare(tableAt(0).table.colors[0][1], "")
      // Each color a step to undo; they go with their row.
      e.undo()
      compare(tableAt(0).table.colors[0][0], "", "Undo takes the last off")
      tv.act("row", "up", 2)
      compare(tableAt(0).table.colors[1].join(), "|yellow,|yellow", "colors move with their row")
    }

    function test_7_a_locked_page() {
      fresh()
      var e = view.editor
      var tv = put([["a", "b"], ["c", "d"]])
      e.readOnly = true
      tv.focusCell(1, 1, -1)
      type("x")
      compare(cellsOf(tableAt(0))[1][1], "d", "nothing written")
      mouseMove(tv.cellAt(1, 1), 5, 5)
      wait(100)
      verify(!anyNamed(tv, "rowHandle").visible && !anyNamed(tv, "addRow").visible, "no handles, no +")
      keyClick(Qt.Key_Tab)
      compare(tv.rowCount, 2, "Tab doesn't make rows")
      e.readOnly = false
    }
  }
}
