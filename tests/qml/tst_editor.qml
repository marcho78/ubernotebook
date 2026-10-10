import QtQuick
import QtTest
import "../../app"
import "../../Html.js" as Html

// The page editor, driven with real keys, offscreen.
// Usage (from the plugin directory): tests/run, or
//   QT_QPA_PLATFORM=offscreen qmltestrunner -input tests/qml
Item {
  id: root
  width: 800
  height: 1200

  Editor {
    id: editor
    width: 700
    contentWidth: 700
    focus: true
  }

  // Puts text on the clipboard, as another app would.
  TextEdit {
    id: source
    visible: false
    textFormat: TextEdit.RichText
  }

  TestCase {
    name: "Editor"
    when: windowShown

    function blocks() { return editor.serialize() }
    function types() { return blocks().map(function(b) { return b.type }).join(",") }
    function texts() { return blocks().map(function(b) { return Html.plainText(b.html || "") }).join("|") }
    function item(i) { return editor.items[editor.uidAt(i)] }
    function focusAt(i, pos) { editor.focusBlock(editor.uidAt(i), pos); wait(0) }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === " ") keyClick(Qt.Key_Space)
        else keyClick(ch)
      }
    }
    function page(list) {
      editor.load(list.map(function(b) { return typeof b === "string" ? { type: "p", html: b } : b }))
      waitForRendering(editor)
    }

    function test_01_load_and_save() {
      page([{ type: "h1", html: "Title" }, "Hello <span style=\" font-weight:700;\">world</span>", { type: "check", html: "milk", checked: true }])
      compare(types(), "h1,p,check")
      compare(texts(), "Title|Hello world|milk")
      compare(blocks()[2].checked, true)
      verify(/font-weight:700/.test(blocks()[1].html))
    }

    function test_02_typing() {
      page([""])
      focusAt(0, 0)
      type("abc")
      compare(texts(), "abc")
    }

    function test_03_enter_splits() {
      page(["Hello <span style=\" font-weight:700;\">world</span>"])
      focusAt(0, 8)
      keyClick(Qt.Key_Return)
      compare(texts(), "Hello wo|rld")
      verify(/font-weight:700/.test(blocks()[1].html), "formatting goes with the text")
      compare(editor.focusUid, editor.uidAt(1))
      compare(item(1).edit.cursorPosition, 0)
    }

    function test_04_enter_after_heading_is_text() {
      page([{ type: "h1", html: "Title" }])
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      type("x")
      compare(types(), "h1,p")
      compare(texts(), "Title|x")
    }

    function test_05_lists_continue_and_end() {
      page([{ type: "bullet", html: "one" }])
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      type("two")
      compare(types(), "bullet,bullet")
      keyClick(Qt.Key_Return)
      keyClick(Qt.Key_Return)
      compare(types(), "bullet,bullet,p", "Enter on an empty item ends the list")
      page([{ type: "check", html: "done", checked: true }])
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      compare(blocks()[1].type, "check")
      compare(blocks()[1].checked, false, "a new item isn't done")
    }

    function test_06_backspace_joins_and_converts() {
      page(["abc", "<span style=\" font-style:italic;\">def</span>"])
      focusAt(1, 0)
      keyClick(Qt.Key_Backspace)
      compare(texts(), "abcdef")
      compare(item(0).edit.cursorPosition, 3)
      verify(/italic/.test(blocks()[0].html))
      page(["x", { type: "bullet", html: "item", indent: 1 }])
      focusAt(1, 0)
      keyClick(Qt.Key_Backspace)
      compare(types(), "x,p".replace("x", "p"), "a list item becomes text first")
      compare(blocks()[1].indent, 1)
      keyClick(Qt.Key_Backspace)
      compare(blocks()[1].indent, 0, "then outdents")
      keyClick(Qt.Key_Backspace)
      compare(texts(), "xitem", "then joins")
    }

    function test_07_delete_at_end_joins() {
      page(["ab", "cd"])
      focusAt(0, -1)
      keyClick(Qt.Key_Delete)
      compare(texts(), "abcd")
    }

    function test_08_markdown_shortcuts() {
      var cases = [["-", "bullet"], ["1.", "number"], ["[]", "check"], ["#", "h1"], ["##", "h2"], [">", "quote"], ["```", "code"]]
      for (var i = 0; i < cases.length; i++) {
        page([""])
        focusAt(0, 0)
        type(cases[i][0] + " x")
        compare(types(), cases[i][1], cases[i][0])
        compare(texts(), "x", cases[i][0])
      }
      page([""])
      focusAt(0, 0)
      type("---")
      keyClick(Qt.Key_Return)
      compare(types(), "divider,p")
      page([{ type: "bullet", html: "" }])
      focusAt(0, 0)
      type("[] y")
      compare(types(), "check", "list kinds switch")
    }

    function test_09_bold_selection_and_toggle() {
      page(["hello world"])
      var e = item(0).edit
      focusAt(0, 0)
      e.select(0, 5)
      keyClick(Qt.Key_B, Qt.ControlModifier)
      verify(/font-weight:700;">hello</.test(blocks()[0].html), blocks()[0].html)
      compare(e.selectionStart, 0)
      compare(e.selectionEnd, 5)
      keyClick(Qt.Key_B, Qt.ControlModifier)
      verify(!/font-weight/.test(blocks()[0].html), "toggled off")
    }

    // Ctrl+Shift+X: strikethrough on the words picked; never a cut, of the
    // words or of blocks picked.
    function test_09b_strikethrough_never_cuts() {
      page(["hello world", "second"])
      var e = item(0).edit
      focusAt(0, 0)
      e.select(0, 5)
      keyClick(Qt.Key_X, Qt.ControlModifier | Qt.ShiftModifier)
      verify(/line-through[^>]*>hello</.test(blocks()[0].html), blocks()[0].html)
      verify(Html.plainText(blocks()[0].html) === "hello world", "nothing cut")
      editor.selectBlocks(editor.uidAt(0), editor.uidAt(1))
      keyClick(Qt.Key_X, Qt.ControlModifier | Qt.ShiftModifier)
      compare(blocks().length, 2, "blocks picked: not cut")
      compare(Html.plainText(blocks()[1].html), "second")
    }

    function test_10_bold_for_what_you_type_next() {
      page(["ab"])
      focusAt(0, -1)
      keyClick(Qt.Key_B, Qt.ControlModifier)
      type("cd")
      verify(/font-weight:700;">cd</.test(blocks()[0].html), blocks()[0].html)
      compare(texts(), "abcd")
    }

    function test_11_undo_and_redo() {
      page(["one"])
      focusAt(0, -1)
      type(" two")
      editor.closeBurst()
      keyClick(Qt.Key_Return)
      type("three")
      editor.closeBurst()
      compare(texts(), "one two|three")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      compare(texts(), "one two|", "typing undone")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      compare(texts(), "one two", "the split undone")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      compare(texts(), "one")
      keyClick(Qt.Key_Z, Qt.ShiftModifier | Qt.ControlModifier)
      keyClick(Qt.Key_Z, Qt.ShiftModifier | Qt.ControlModifier)
      keyClick(Qt.Key_Z, Qt.ShiftModifier | Qt.ControlModifier)
      compare(texts(), "one two|three", "and redone")
    }

    function test_12_arrows_move_between_blocks() {
      page(["first line", "second line"])
      focusAt(0, 3)
      keyClick(Qt.Key_Down)
      compare(editor.focusUid, editor.uidAt(1))
      verify(Math.abs(item(1).edit.cursorPosition - 3) <= 1, "keeps its place across: " + item(1).edit.cursorPosition)
      keyClick(Qt.Key_Up)
      compare(editor.focusUid, editor.uidAt(0))
      focusAt(1, 0)
      keyClick(Qt.Key_Left)
      compare(editor.focusUid, editor.uidAt(0))
      compare(item(0).edit.cursorPosition, item(0).edit.length)
    }

    function test_13_checkboxes_and_indent() {
      page([{ type: "check", html: "task" }])
      focusAt(0, 2)
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(blocks()[0].checked, true)
      keyClick(Qt.Key_Tab)
      compare(blocks()[0].indent, 1)
      keyClick(Qt.Key_Backtab, Qt.ShiftModifier)
      compare(blocks()[0].indent, 0)
      keyClick(Qt.Key_9, Qt.ControlModifier | Qt.ShiftModifier)
      compare(types(), "p", "Ctrl+Shift+9 takes the checklist off")
    }

    function test_14_numbering() {
      page([{ type: "number", html: "a" }, { type: "number", html: "b" }, { type: "number", html: "c", indent: 1 }, "x", { type: "number", html: "d" }])
      var labels = [0, 1, 2, 4].map(function(i) { return editor.numbers[editor.uidAt(i)] })
      compare(labels.join(" "), "1. 2. a. 1.")
    }

    function test_15_picking_blocks() {
      page(["a", "b", "c", "d"])
      focusAt(1, 0)
      keyClick(Qt.Key_Escape)
      compare(editor.selectedList.length, 1)
      keyClick(Qt.Key_Down, Qt.ShiftModifier)
      compare(editor.selectedList.length, 2)
      keyClick(Qt.Key_Backspace)
      compare(texts(), "a|d")
      compare(editor.selectedList.length, 0)
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      compare(texts(), "a|b|c|d", "undone")
    }

    function test_16_move_and_duplicate() {
      page(["a", "b", "c"])
      focusAt(2, 0)
      keyClick(Qt.Key_Up, Qt.AltModifier | Qt.ShiftModifier)
      compare(texts(), "a|c|b")
      keyClick(Qt.Key_D, Qt.ControlModifier)
      compare(texts(), "a|c|c|b")
    }

    function test_17_paste_lines_become_blocks() {
      source.text = "<p>first</p><ul><li>item</li></ul><p><b>last</b></p>"
      source.selectAll()
      source.copy()
      page(["[here]"])
      focusAt(0, 1)
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(texts(), "[first|item|last" + "here]")
      compare(types(), "p,bullet,p")
      source.text = "<p>just <i>words</i></p>"
      source.selectAll()
      source.copy()
      page(["ab"])
      focusAt(0, 1)
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(texts(), "ajust wordsb")
      verify(/italic/.test(blocks()[0].html))
    }

    function test_18_dark_paper_colors() {
      editor.dark = true
      page(["<span style=\" color:#1e4fa3;\">blue</span>"])
      var shown = item(0).edit.getFormattedText(0, 4)
      verify(/#8ab4f8/.test(shown), "shown as the dark twin")
      focusAt(0, -1)
      type("!")
      verify(/color:#1e4fa3/.test(blocks()[0].html), "stored as the light ink: " + blocks()[0].html)
      editor.dark = false
    }

    function test_19_find() {
      page(["cat and dog", "the cat"])
      compare(editor.find("CAT"), 2)
      compare(editor.showMatch(1), 1)
      compare(editor.findCurrentUid, editor.uidAt(1))
      editor.clearFind()
      compare(editor.find(""), 0)
    }

    function test_25_text_sizes() {
      page(["make this big"])
      var b = item(0)
      compare(b.height, 30, "one ruled line")
      focusAt(0, 0)
      b.edit.select(10, 13)
      keyClick(Qt.Key_Greater, Qt.ControlModifier | Qt.ShiftModifier)
      verify(/font-size:18px;">big</.test(blocks()[0].html), "one size up: " + blocks()[0].html)
      keyClick(Qt.Key_Greater, Qt.ControlModifier | Qt.ShiftModifier)
      verify(/font-size:20px;">big</.test(blocks()[0].html), "and another")
      compare(b.height, 30, "still fits its line")
      editor.formatInline("size", 40)
      verify(/font-size:40px;">big</.test(blocks()[0].html))
      tryCompare(b, "lineRows", 2)
      compare(b.height, 60, "big writing takes two ruled lines")
      compare(b.edit.selectionStart, 10, "the words stay selected")
      editor.formatInline("size", 0)
      verify(!/font-size/.test(blocks()[0].html), "back to the block's own size")
      tryCompare(b, "height", 30)
      keyClick(Qt.Key_Less, Qt.ControlModifier | Qt.ShiftModifier)
      verify(/font-size:16px;">big</.test(blocks()[0].html), "one size down")
      // Undo walks it back.
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      verify(!/font-size/.test(blocks()[0].html))
      // Big text survives saving and loading, and still takes two lines.
      editor.formatInline("size", 48)
      page(blocks())
      compare(item(0).lineRows, 2)
    }

    function test_26_one_undo_step_per_change() {
      page(["abc def"])
      focusAt(0, 0)
      item(0).edit.select(0, 3)
      keyClick(Qt.Key_B, Qt.ControlModifier)
      wait(50)
      keyClick(Qt.Key_I, Qt.ControlModifier)
      wait(50)
      compare(editor.undoStack.length, 2, "two changes, two steps")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      verify(/font-weight:700/.test(blocks()[0].html) && !/italic/.test(blocks()[0].html), "one Ctrl+Z takes the italic off")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      verify(!/font-weight/.test(blocks()[0].html), "the next takes the bold off")
    }

    function test_24_one_cursor_only() {
      page(["one", "two", "three"])
      focusAt(0, -1)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Return)
      type("four")
      // Qt's own cursor, in the text's color: shown only where you're writing.
      var shown = 0
      for (var i = 0; i < editor.model.count; i++) {
        var e = item(i).edit
        compare(e.cursorDelegate, null, "the standard cursor")
        if (e.cursorVisible) shown++
      }
      compare(shown, 1, "only the block being written in shows a cursor")
    }

    function test_23_shortcuts_from_an_input_method() {
      // fcitx and ibus commit text instead of sending key presses.
      page([""])
      focusAt(0, 0)
      var commit = Qt.createQmlObject('import QtQuick; TextSelection {}', root)
      commit.document = item(0).edit.textDocument
      commit.text = "[]"
      commit.selectionStart = 2
      commit.selectionEnd = 2
      item(0).edit.cursorPosition = 2
      commit.text = " "
      compare(item(0).edit.cursorPosition, 3)
      wait(0)
      compare(types(), "check")
      compare(texts(), "")
    }

    function test_22_spaces_are_kept() {
      page([{ type: "code", html: "" }])
      focusAt(0, 0)
      type("if x:")
      keyClick(Qt.Key_Return)
      type("    return  1")
      var saved = blocks()
      page(saved)
      compare(texts(), "if x:\n    return  1")
      compare(item(0).edit.getText(0, item(0).edit.length).replace(/\u2028/g, "\n"), "if x:\n    return  1")
      // Enter on an empty last line leaves the code block.
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      keyClick(Qt.Key_Return)
      type("after")
      compare(types(), "code,p")
      compare(texts(), "if x:\n    return  1|after")
    }

    function test_21_dragging_across_blocks_picks_them() {
      page(["one", "two", "three", "four"])
      var a = item(0)
      var c = item(2)
      mousePress(a.edit, 4, 10)
      mouseMove(editor, 30, a.y + 18, -1, Qt.LeftButton)
      mouseMove(editor, 30, c.y + 12, -1, Qt.LeftButton)
      mouseMove(editor, 30, c.y + 14, -1, Qt.LeftButton)
      mouseRelease(editor, 30, c.y + 14)
      wait(0)
      compare(editor.selectedList.length, 3)
      compare(editor.selectedList[2], editor.uidAt(2))
      verify(a.edit.selectByMouse, "text selection works again after")
      keyClick(Qt.Key_Delete)
      compare(texts(), "four")
    }

    function test_20_highlight_and_links() {
      page(["mark this"])
      var e = item(0).edit
      focusAt(0, 0)
      e.select(5, 9)
      editor.formatInline("highlight", "#fff27a")
      verify(/background-color:#fff27a;">this/.test(blocks()[0].html))
      editor.formatInline("highlight", "#fff27a")
      verify(!/background-color/.test(blocks()[0].html), "the same color again takes it off")
      e.select(0, 4)
      editor.setLink("example.com")
      verify(/<a href="https:\/\/example.com">mark<\/a>/.test(blocks()[0].html), blocks()[0].html)
    }

    function test_31_formatting_keeps_spaces() {
      page(["one two three"])
      var e = item(0).edit
      focusAt(0, 0)
      e.select(3, 8)
      editor.formatInline("bold")
      compare(texts(), "one two three", "the spaces at either end of what's bolded stay")
      verify(/font-weight:700;"> two </.test(blocks()[0].html), blocks()[0].html)
    }

    function labels() { return blocks().map(function(b) { return b.label || "" }).join(",") }

    function test_27_a_schedule() {
      page([{ type: "time", label: "07:00", html: "run" }, { type: "time", label: "08:00" }, "after"])
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      compare(types(), "time,time,p", "Enter goes on to the next slot")
      compare(editor.focusUid, editor.uidAt(1))
      type("eat")
      keyClick(Qt.Key_Return)
      compare(types(), "time,time,time,p", "and after the last, starts the next one")
      compare(labels(), "07:00,08:00,09:00,")
      keyClick(Qt.Key_Return)
      compare(types(), "time,time,p,p", "an empty last slot ends the schedule")
      // A time typed at the start of a line makes a slot.
      page([""])
      focusAt(0, 0)
      type("9:30 ")
      wait(0)
      compare(types(), "time")
      compare(labels(), "09:30")
      type("standup")
      keyClick(Qt.Key_Return)
      compare(labels(), "09:30,10:30")
      // The time can be changed, and that's one undo step.
      editor.setLabel(editor.uidAt(1), "11:00 ")
      compare(labels(), "09:30,11:00")
      editor.undo()
      compare(labels(), "09:30,10:30")
    }

    function test_28_habits() {
      page([{ type: "habit", html: "read" }])
      var b = item(0)
      verify(b.textW < b.width - b.daysW, "the text leaves room for the days")
      // Wednesday's circle.
      var x = b.width - b.daysW + 2 * (b.dot + b.dotGap) + b.dot / 2
      var y = b.textBaseline - b.st.size * 0.32
      mouseClick(b, x, y)
      compare(blocks()[0].days, "0010000")
      mouseClick(b, x, y)
      compare(blocks()[0].days, "0000000")
      editor.toggleDay(editor.uidAt(0), 6)
      compare(blocks()[0].days, "0000001")
      editor.undo()
      compare(blocks()[0].days, "0000000")
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      type("walk")
      compare(types(), "habit,habit")
      compare(blocks()[1].days, "0000000", "a new habit starts with no days")
      keyClick(Qt.Key_Return)
      keyClick(Qt.Key_Return)
      compare(types(), "habit,habit,p", "an empty habit ends the list")
    }

    function test_29_a_calendar() {
      page([{ type: "calendar", month: "2026-09" }, "after"])
      var b = item(0)
      compare(b.rows, 7, "a row for the month, one for the days of the week, five weeks")
      // The 14th: a Monday, in the fourth row of dates.
      var colW = b.width / 7
      mouseClick(b, colW * 0.5, (2 + 2) * b.pitch + b.pitch * 0.6)
      compare(blocks()[0].marks, "14")
      mouseClick(b, colW * 1.5, (2 + 0) * b.pitch + b.pitch * 0.6)
      compare(blocks()[0].marks, "1,14")
      mouseClick(b, colW * 0.5, (2 + 2) * b.pitch + b.pitch * 0.6)
      compare(blocks()[0].marks, "1", "a second click rubs it out")
      editor.shiftMonth(editor.uidAt(0), 1)
      compare(blocks()[0].month, "2026-10")
      compare(blocks()[0].marks, "", "circles were September's")
      editor.undo()
      compare(blocks()[0].month, "2026-09")
      compare(blocks()[0].marks, "1")
      // A click away from the dates picks the calendar.
      mouseClick(b, 4, b.pitch * 0.5)
      compare(editor.selectedList.length, 1)
    }

    function test_30_hints() {
      page([{ type: "callout", tone: "blue", hint: "The lecture in a few lines" }])
      var hint = findText(item(0), "The lecture in a few lines")
      verify(hint !== null, "the hint is written")
      verify(hint.visible)
      focusAt(0, 0)
      type("x")
      verify(!hint.visible, "and goes when you write")
      compare(blocks()[0].hint, "The lecture in a few lines", "it's kept for when the note is empty again")
    }

    function findText(root, text) {
      if (root.text === text && root.visible !== undefined && root.font !== undefined && root.textFormat === Text.PlainText) return root
      for (var i = 0; i < root.children.length; i++) {
        var found = findText(root.children[i], text)
        if (found) return found
      }
      return null
    }
  }
}
