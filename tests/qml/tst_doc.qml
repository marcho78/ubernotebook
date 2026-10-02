import QtQuick
import QtTest
import "../../app"
import "../../Html.js" as Html
import "../../Workspace.js" as Workspace
import "../../Dates.js" as Dates
import "../../Highlight.js" as Highlight

// The editor in Pages (layout "doc"): blocks inside blocks, toggles, "/",
// Markdown typed inline, dragging, colors. Driven with real keys, offscreen.
Item {
  id: root
  width: 900
  height: 1400

  Editor {
    id: editor
    layout: "doc"
    x: 60
    width: 720
    contentWidth: 720
    focus: true
  }

  SignalSpy { id: opened; target: editor; signalName: "pageOpened" }
  TextEdit { id: clip; visible: false; textFormat: TextEdit.PlainText }

  TestCase {
    name: "Pages editor"
    when: windowShown

    function blocks() { return editor.serialize() }
    function types() { return blocks().map(function(b) { return b.type }).join(",") }
    function depths() { return blocks().map(function(b) { return b.indent }).join(",") }
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

    function test_01_blocks_are_uuids() {
      page(["one", { type: "bullet", html: "two", indent: 1 }])
      blocks().forEach(function(b) { verify(Workspace.isUuid(b.uid), b.uid) })
      focusAt(1, -1)
      keyClick(Qt.Key_Return)
      verify(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(editor.uidAt(2)), "a new block gets a version 4 UUID")
      compare(depths(), "0,1,1", "any block can hold others")
    }

    function test_02_tab_takes_what_is_inside_along() {
      page(["a", "b", { type: "p", html: "c", indent: 1 }, "d"])
      focusAt(1, 0)
      keyClick(Qt.Key_Tab)
      compare(depths(), "0,1,2,0", "b goes inside a, and c with it")
      keyClick(Qt.Key_Tab)
      compare(depths(), "0,1,2,0", "no deeper than one inside the block above")
      focusAt(3, 0)
      keyClick(Qt.Key_Tab)
      compare(depths(), "0,1,2,1")
      focusAt(1, 0)
      keyClick(Qt.Key_Tab, Qt.ShiftModifier)
      compare(depths(), "0,0,1,1", "out again, the blocks after it inside the same block go inside it")
      page([{ type: "h2", html: "Heading" }, "text"])
      focusAt(1, 0)
      keyClick(Qt.Key_Tab)
      compare(depths(), "0,0", "a heading holds nothing")
      page([{ type: "h2", html: "Heading", toggle: true }, "text"])
      focusAt(1, 0)
      keyClick(Qt.Key_Tab)
      compare(depths(), "0,1", "a toggle heading does")
    }

    function test_03_toggles_fold() {
      page([{ type: "toggle", html: "Plan" }, { type: "p", html: "inside", indent: 1 }, { type: "p", html: "deeper", indent: 2 }, "after"])
      var t = editor.uidAt(0)
      editor.setCollapsed(t, true)
      verify(editor.isHidden(editor.uidAt(1)))
      verify(editor.isHidden(editor.uidAt(2)))
      verify(!editor.isHidden(editor.uidAt(3)))
      compare(item(1).height, 0)
      focusAt(0, -1)
      keyClick(Qt.Key_Down)
      compare(editor.focusUid, editor.uidAt(3), "Down goes past what's folded")
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      compare(types(), "toggle,p,p,toggle,p", "Enter after a folded toggle: another after everything in it")
      compare(depths(), "0,1,2,0,0")
      keyClick(Qt.Key_Backspace)
      compare(types(), "toggle,p,p,p,p", "Backspace makes an empty toggle text first...")
      keyClick(Qt.Key_Backspace)
      compare(types(), "toggle,p,p,p", "...then takes it out")
      editor.setCollapsed(t, false)
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      type("first")
      compare(texts(), "Plan|first|inside|deeper|after", "Enter in an open toggle: a block inside it, first")
      compare(depths(), "0,1,1,2,0")
      focusAt(0, -1)
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(blocks()[0].collapsed, true, "Ctrl+Enter folds it")
      editor.reveal(editor.uidAt(3))
      verify(!blocks()[0].collapsed, "showing a block inside unfolds it")
    }

    function test_04_the_slash_menu() {
      page([""])
      focusAt(0, 0)
      type("/to")
      wait(0)
      verify(editor.slash !== null, "the menu is open")
      compare(editor.slashItems[0].label, "To-do list")
      keyClick(Qt.Key_Return)
      compare(types(), "check")
      compare(texts(), "", "what was typed for it goes")
      compare(editor.slash, null)
      type("buy milk ")
      type("/head")
      wait(0)
      compare(editor.slashItems[0].label, "Heading 1")
      keyClick(Qt.Key_Down)
      compare(editor.slashIndex, 1)
      keyClick(Qt.Key_Return)
      compare(types(), "check,h2", "on a line with words, the kind comes after it")
      type("title")
      focusAt(0, -1)
      type(" /red")
      wait(0)
      compare(editor.slashItems[0].label, "Red")
      keyClick(Qt.Key_Return)
      compare(blocks()[0].color, "red")
      compare(texts(), "buy milk  |title")
      type("a/b")
      wait(0)
      compare(editor.slash, null, "a slash in the middle of a word is a slash")
      type(" /nothing")
      wait(0)
      keyClick(Qt.Key_Escape)
      compare(editor.slash, null)
      verify(texts().indexOf("/nothing") > 0, "Esc keeps what was typed")
    }

    function test_05_notion_shortcuts() {
      page([""])
      focusAt(0, 0)
      type("> ")
      wait(0)
      compare(types(), "toggle", "\"> \" is a toggle in Pages")
      page([""])
      focusAt(0, 0)
      type("so **bold**")
      wait(0)
      compare(texts(), "so bold")
      verify(/font-weight:700;">bold/.test(blocks()[0].html), blocks()[0].html)
      type(" x")
      wait(0)
      verify(!/font-weight:700;">[^<]*x/.test(blocks()[0].html), "what's typed after isn't bold")
      type(" `code`")
      wait(0)
      compare(texts(), "so bold x code")
      verify(/font-family/.test(blocks()[0].html))
    }

    function test_06_dragging_a_block() {
      page([{ type: "toggle", html: "T" }, "a", "b", { type: "p", html: "b1", indent: 1 }])
      var b = editor.uidAt(2)
      editor.dragStart(b)
      // Above everything.
      editor.dragMove(0, 2)
      verify(editor.dropTarget !== null)
      compare(editor.dropTarget.index, 0)
      editor.dragEnd(true)
      compare(texts(), "b|b1|T|a", "it goes with what's inside it")
      compare(depths(), "0,1,0,0")
      waitForRendering(editor)
      // Into the toggle: under it, and to the right.
      var a = editor.uidAt(3)
      var t = editor.items[editor.uidAt(2)]
      editor.dragStart(a)
      editor.dragMove(t.x + 60, t.y + t.height + 2)
      compare(editor.dropTarget.depth, 1)
      editor.dragEnd(true)
      compare(texts(), "b|b1|T|a")
      compare(depths(), "0,1,0,1", "now inside the toggle")
      editor.undo()
      compare(depths(), "0,1,0,0", "and one undo puts it back")
    }

    function test_07_moving_duplicating_deleting() {
      page(["a", { type: "p", html: "a1", indent: 1 }, "b"])
      focusAt(2, 0)
      keyClick(Qt.Key_Up, Qt.AltModifier | Qt.ShiftModifier)
      compare(texts(), "b|a|a1", "past the block before it, and what's inside that")
      focusAt(1, 0)
      keyClick(Qt.Key_D, Qt.ControlModifier)
      compare(texts(), "b|a|a1|a|a1", "a copy of it and what's inside it")
      var ids = blocks().map(function(x) { return x.uid })
      verify(ids[3] !== ids[1] && ids[4] !== ids[2], "with ids of their own")
      editor.selectBlocks(editor.uidAt(1), editor.uidAt(1))
      compare(editor.selectedList.length, 2, "picking a block picks what's inside it")
      keyClick(Qt.Key_Delete)
      compare(texts(), "b|a|a1")
    }

    function test_08_colors_and_kinds() {
      page(["one", "two"])
      editor.setBlockColor([editor.uidAt(0)], "blue_background")
      compare(blocks()[0].color, "blue_background")
      verify(editor.docLayout[editor.uidAt(0)].boxes.length === 1, "a background is a box")
      editor.turnInto([editor.uidAt(1)], "h2", true)
      compare(blocks()[1].type, "h2")
      compare(blocks()[1].toggle, true)
      editor.turnInto([editor.uidAt(1)], "h2", false)
      compare(blocks()[1].toggle, undefined)
      editor.turnInto([editor.uidAt(0)], "callout", false)
      compare(blocks()[0].icon, "\u{1f4a1}", "a callout gets an icon")
    }

    function test_09_page_blocks() {
      var sub = Workspace.uuid4()
      page(["text"])
      var made = editor.placeBlock(editor.uidAt(0), { type: "page", id: sub })
      compare(made, sub, "a page block's id is its page's")
      compare(types(), "p,page,p")
      editor.duplicateBlocks([sub])
      compare(types(), "p,page,link,p", "a copy of a page block links to the page")
      compare(blocks()[2].target, sub)
    }

    function test_11_columns_from_the_slash_menu() {
      page([""])
      focusAt(0, 0)
      type("/2 col")
      wait(0)
      compare(editor.slashItems[0].label, "2 columns")
      keyClick(Qt.Key_Return)
      compare(types(), "columns,column,p,column,p,p")
      compare(depths(), "0,1,2,1,2,0")
      waitForRendering(editor)
      var left = item(2)
      var right = item(4)
      compare(left.y, right.y, "side by side")
      verify(right.x > left.x + left.width, "the second to the right of the first")
      compare(Math.round(left.width), Math.round(right.width), "an equal share each")
      type("left")
      keyClick(Qt.Key_Return)
      type("more")
      compare(types(), "columns,column,p,p,column,p,p", "Enter in a column: a block in the same column")
      compare(depths(), "0,1,2,2,1,2,0")
      focusAt(5, 0)
      keyClick(Qt.Key_Backspace)
      compare(types(), "columns,column,p,p,column,p,p", "Backspace at the top of a column leaves the columns be")
      keyClick(Qt.Key_Tab, Qt.ShiftModifier)
      compare(depths(), "0,1,2,2,1,2,0", "and nothing comes out of a column but by dragging")
    }

    function test_12_dragging_a_block_beside_another() {
      page(["left", "right", "after"])
      waitForRendering(editor)
      var target = item(0)
      editor.dragStart(editor.uidAt(1))
      editor.dragMove(target.x + target.width - 10, target.y + target.height / 2)
      verify(editor.dropTarget && editor.dropTarget.side === editor.uidAt(0), "up its right side")
      editor.dragEnd(true)
      compare(types(), "columns,column,p,column,p,p")
      compare(texts(), "||left||right|after")
      waitForRendering(editor)
      compare(item(2).y, item(4).y)
      // Out again, under the columns: they go, as one column isn't columns.
      var below = item(5)
      editor.dragStart(editor.uidAt(4))
      editor.dragMove(10, below.y + below.height - 2)
      editor.dragEnd(true)
      compare(types(), "p,p,p")
      compare(texts(), "left|after|right")
      editor.undo()
      compare(types(), "columns,column,p,column,p,p", "one undo puts them back in columns")
    }

    function test_13_resizing_columns() {
      page([""])
      editor.insertColumns(editor.uidAt(0), 2)
      waitForRendering(editor)
      var cols = editor.uidAt(0)
      var c1 = editor.uidAt(1)
      var c2 = editor.uidAt(3)
      var start = editor.beginColumnResize(cols)
      editor.resizeColumns(start, c1, c2, 120)
      editor.endColumnResize()
      waitForRendering(editor)
      verify(item(2).width > item(4).width + 100, "the first column is wider")
      verify(blocks()[1].width > 0.6, "and says so, to be saved")
      editor.undo()
      waitForRendering(editor)
      compare(Math.round(item(2).width), Math.round(item(4).width))
    }

    function test_14_dates_with_at() {
      page([""])
      focusAt(0, 0)
      type("due @tom")
      wait(0)
      verify(editor.mention !== null)
      compare(editor.mention.kind, "date")
      var t = new Date()
      var tomorrow = new Date(t.getFullYear(), t.getMonth(), t.getDate() + 1)
      compare(editor.mentionItems[0].label, Dates.label(tomorrow, false, t))
      keyClick(Qt.Key_Return)
      var html = blocks()[0].html
      verify(html.indexOf("omanote://date/" + Dates.iso(tomorrow, false)) >= 0, html)
      compare(texts(), "due @" + Dates.label(tomorrow, false, t) + " ")
      type("x")
      verify(/<\/a> x$/.test(blocks()[0].html), "what's typed after it isn't part of it: " + blocks()[0].html)
      compare(editor.mention, null)
      type(" me@example.com")
      wait(0)
      compare(editor.mention, null, "an @ inside a word is just an @")
    }

    function test_15_reminders_with_at() {
      page([""])
      focusAt(0, 0)
      type("call @in 2 hours")
      wait(0)
      compare(editor.mentionItems.length, 2)
      verify(editor.mentionItems[1].remind)
      keyClick(Qt.Key_Down)
      keyClick(Qt.Key_Return)
      var html = blocks()[0].html
      verify(html.indexOf("omanote://remind/") >= 0, html)
      verify(texts().indexOf("\u23f0 ") >= 0, "a reminder shows a clock")
    }

    function test_16_links_to_pages() {
      var plans = Workspace.uuid4()
      var fresh = Workspace.uuid4()
      editor.findPages = function(q) { return [{ id: plans, title: "Plans", icon: "\u{1f5fa}\u{fe0f}", path: "Work" }] }
      editor.pageInfo = function(id) { return id === plans ? { title: "Plans", icon: "\u{1f5fa}\u{fe0f}" } : id === fresh ? { title: "Brand new", icon: "" } : null }
      editor.makePage = function(title) { return title === "Brand new" ? fresh : "" }
      page([""])
      focusAt(0, 0)
      type("see [[pl")
      wait(0)
      compare(editor.mention.kind, "page")
      compare(editor.mentionItems[0].label, "Plans")
      compare(editor.mentionItems[editor.mentionItems.length - 1].kind, "create", "and a new page with that name")
      keyClick(Qt.Key_Return)
      verify(blocks()[0].html.indexOf("omanote://page/" + plans) >= 0)
      compare(texts(), "see \u{1f5fa}\u{fe0f} Plans ")
      opened.clear()
      editor.openLink("omanote://page/" + plans)
      compare(opened.count, 1, "a link to a page opens it")
      compare(opened.signalArguments[0][0], plans)
      type("[[Brand new")
      wait(0)
      keyClick(Qt.Key_Up)
      compare(editor.mentionItems[editor.mentionIndex].kind, "create")
      keyClick(Qt.Key_Return)
      verify(blocks()[0].html.indexOf("omanote://page/" + fresh) >= 0, "a new page, linked")
      // A page's link says what it's called now.
      editor.pageInfo = function(id) { return id === plans ? { title: "Renamed", icon: "" } : null }
      editor.load(blocks())
      verify(item(0).edit.getText(0, item(0).edit.length).indexOf("Renamed") >= 0)
      editor.findPages = function(q) { return [] }
      editor.pageInfo = function(id) { return null }
      editor.makePage = function(title) { return "" }
    }

    function test_17_emoji_by_name() {
      page([""])
      focusAt(0, 0)
      type("launch :rock")
      wait(0)
      compare(editor.mention.kind, "emoji")
      compare(editor.mentionItems[0].label, ":rocket:")
      compare(editor.mentionItems[0].emoji, "\u{1f680}")
      keyClick(Qt.Key_Return)
      compare(texts(), "launch \u{1f680}")
      compare(editor.mention, null)
      editor.undo()
      compare(texts(), "launch :rock", "Undo gives back what was typed")
      editor.redo()
      compare(texts(), "launch \u{1f680}")
      focusAt(0, -1)
      type(" and :tada:")
      wait(0)
      compare(texts(), "launch \u{1f680} and \u{1f389}", "a name typed in full is the emoji")
      type(" :+1:")
      wait(0)
      compare(texts(), "launch \u{1f680} and \u{1f389} \u{1f44d}")
      type(" at 10:30 :) :zzzqq")
      wait(0)
      compare(editor.mention, null, "not a time, a smiley, or what no emoji is called")
      type(" :fire")
      wait(0)
      compare(editor.mention.kind, "emoji")
      keyClick(Qt.Key_Escape)
      compare(editor.mention, null)
      compare(texts(), "launch \u{1f680} and \u{1f389} \u{1f44d} at 10:30 :) :zzzqq :fire", "Esc leaves what's typed")
    }

    function test_18_code_in_its_colors() {
      var light = Highlight.PALETTES.light
      page([{ type: "code", html: "let a = 1", lang: "JavaScript" }, ""])
      var uid = editor.uidAt(0)
      function shown() { var e = item(0).edit; return e.getFormattedText(0, e.length) }
      verify(shown().indexOf(light.keyword) >= 0, "shown in its language's colors")
      compare(blocks()[0].html, "let a = 1", "and stored plain")
      focusAt(0, -1)
      type(" const")
      compare(blocks()[0].html, "let a = 1 const")
      tryVerify(function() { return (shown().match(new RegExp(light.keyword, "g")) || []).length === 2 }, 2000, "colored again after a moment")
      compare(item(0).edit.cursorPosition, 15, "with the cursor where it was")
      item(0).edit.select(0, 3)
      keyClick(Qt.Key_B, Qt.ControlModifier)
      compare(blocks()[0].html, "let a = 1 const", "code has no bold")
      editor.setProp(uid, "lang", "Python")
      verify(shown().indexOf(light.keyword) < 0, "\u201clet\u201d isn't Python")
      compare(blocks()[0].lang, "Python")
      editor.setType([uid], "p")
      compare(blocks()[0].html, "let a = 1 const", "a paragraph made of it has no colors")
      verify(shown().indexOf(light.number) < 0)
      editor.undo()
      compare(types(), "code,p")
      verify(shown().indexOf(light.number) >= 0, "undone, it's code again")
      editor.setProp(uid, "lang", "")
      verify(shown().indexOf(light.number) < 0, "plain text is plain")
      compare(texts(), "let a = 1 const|")
      // Pasted into code, lines stay in it.
      editor.setProp(uid, "lang", "Python")
      clip.text = "\nif x:\n\tpass"
      clip.selectAll()
      clip.copy()
      focusAt(0, -1)
      keyClick(Qt.Key_V, Qt.ControlModifier)
      compare(types(), "code,p")
      compare(texts(), "let a = 1 const\nif x:\n\tpass|")
      compare(item(0).edit.cursorPosition, 27, "the cursor after it")
      verify(shown().indexOf(light.keyword) >= 0, "and in its colors")
    }

    function test_19_habits_and_calendars() {
      page([{ type: "habit", html: "Run", days: "0000000" }, { type: "calendar", month: "2026-09", marks: "" }, ""])
      waitForRendering(editor)
      var habit = item(0)
      // A day's circle, clicked, is ticked; clicked again, not.
      var cx = habit.width - habit.boxRight - habit.daysW + 2 * (habit.dot + habit.dotGap) + habit.dot / 2
      var cy = habit.markY
      mouseClick(habit, cx, cy)
      compare(blocks()[0].days, "0010000", "Wednesday ticked")
      mouseClick(habit, cx, cy)
      compare(blocks()[0].days, "0000000")
      // Enter goes on to the next habit; on an empty one, the habits end.
      focusAt(0, -1)
      keyClick(Qt.Key_Return)
      compare(types(), "habit,habit,calendar,p")
      keyClick(Qt.Key_Return)
      compare(types(), "habit,p,calendar,p")
      // A date on the calendar, clicked, is circled; the month moves on.
      var cal = item(2)
      var offset = 1
      var col = (14 - 1 + offset) % 7
      var row = Math.floor((14 - 1 + offset) / 7)
      mouseClick(cal, cal.bx + (col + 0.5) * (cal.width - cal.bx - cal.boxRight) / 7, cal.st.above + cal.calHead + cal.calWeekdays + (row + 0.5) * cal.calRow)
      compare(blocks()[2].marks, "14", "the 14th circled")
      editor.shiftMonth(editor.uidAt(2), 1)
      compare(blocks()[2].month, "2026-10")
      editor.undo()
      compare(blocks()[2].month, "2026-09", "and back, with Undo")
      // Locked, nothing changes.
      editor.readOnly = true
      editor.toggleDay(editor.uidAt(0), 0)
      editor.toggleMark(editor.uidAt(2), 3)
      editor.shiftMonth(editor.uidAt(2), 1)
      editor.readOnly = false
      compare(blocks()[0].days, "0000000")
      compare(blocks()[2].marks, "14")
      compare(blocks()[2].month, "2026-09")
    }

    function test_20_numbers_in_columns_count_from_one() {
      page([{ type: "columns" }, { type: "column", indent: 1 }, { type: "number", html: "a", indent: 2 }, { type: "number", html: "b", indent: 2 },
        { type: "column", indent: 1 }, { type: "number", html: "c", indent: 2 }, { type: "number", html: "d", indent: 3 }, ""])
      compare(editor.numbers[editor.uidAt(2)], "1.")
      compare(editor.numbers[editor.uidAt(3)], "2.")
      compare(editor.numbers[editor.uidAt(5)], "1.")
      compare(editor.numbers[editor.uidAt(6)], "a.", "inside a numbered item, letters")
    }

    // A mind map's idea, clicked where it's drawn.
    function clickIdea(map, text) {
      var L = map.lay
      var n = L.nodes.filter(function(x) { return x.node.text === text })[0]
      verify(n !== undefined, "an idea called " + text)
      var left = Math.max(0, (map.width - L.width * L.scale) / 2)
      mouseClick(map, left + (n.x + n.w / 2) * L.scale, (n.y + n.h / 2) * L.scale)
    }
    function outline() { return blocks().filter(function(b) { return b.type === "mindmap" })[0].outline }

    function test_21_mind_maps() {
      page([""])
      focusAt(0, 0)
      type("/mindmap")
      wait(0)
      compare(editor.slashItems[0].id, "mindmap")
      keyClick(Qt.Key_Return)
      compare(types(), "mindmap,p")
      var map = item(0).mindMap
      tryVerify(function() { return map.editing }, 1000, "you write the topic first")
      type("Launch")
      keyClick(Qt.Key_Tab)
      type("Marketing")
      keyClick(Qt.Key_Return)
      type("Engineering")
      keyClick(Qt.Key_Escape)
      verify(!map.editing)
      compare(outline(), "Launch\n  Main idea\n  Main idea\n  Main idea\n  Marketing\n  Engineering")
      verify(map.lay.nodes.length === 6 && map.height > 100, "drawn")
      editor.undo()
      compare(outline(), "Central topic\n  Main idea\n  Main idea\n  Main idea", "all that writing is one step")
      editor.redo()
      // Click an idea to write on it; Backspace on an empty one takes it away.
      clickIdea(map, "Marketing")
      verify(map.editing)
      keyClick(Qt.Key_Tab)
      type("Blog")
      keyClick(Qt.Key_Tab)
      keyClick(Qt.Key_Backspace)
      compare(map.current.text, "Blog", "back on the idea it branched from")
      type(" post")
      keyClick(Qt.Key_Up)
      compare(map.current.text, "Marketing", "\u2191: the idea above")
      keyClick(Qt.Key_Escape)
      compare(outline(), "Launch\n  Main idea\n  Main idea\n  Main idea\n  Marketing\n    Blog post\n  Engineering")
      // Ctrl+Backspace takes an idea and its branch; empty ideas don't stay.
      clickIdea(map, "Marketing")
      keyClick(Qt.Key_Backspace, Qt.ControlModifier)
      keyClick(Qt.Key_Return)
      keyClick(Qt.Key_Escape)
      compare(outline(), "Launch\n  Main idea\n  Main idea\n  Main idea\n  Engineering")
      // Folding a branch.
      clickIdea(map, "Engineering")
      keyClick(Qt.Key_Tab)
      type("Release")
      keyClick(Qt.Key_Escape)
      var eng = map.lay.nodes.filter(function(x) { return x.node.text === "Engineering" })[0].node
      map.toggleFold(eng)
      compare(blocks()[0].folds, "4")
      verify(map.lay.nodes.every(function(x) { return x.node.text !== "Release" }), "its branch isn't drawn")
      // A locked page's map only folds.
      editor.readOnly = true
      clickIdea(map, "Launch")
      verify(!map.editing)
      map.toggleFold(map.lay.nodes.filter(function(x) { return x.node.text === "Engineering" })[0].node)
      compare(blocks()[0].folds, "")
      editor.readOnly = false
    }

    function test_22_lists_and_mind_maps() {
      page([{ type: "bullet", html: "Trip" }, { type: "bullet", html: "Pack", indent: 1 }, { type: "check", html: "Passport", indent: 2 },
        { type: "bullet", html: "Book <b>hotel</b>", indent: 1 }, "after"])
      var made = editor.toMindMap([editor.uidAt(0)])
      verify(made !== "")
      compare(types(), "mindmap,p")
      compare(outline(), "Trip\n  Pack\n    Passport\n  Book hotel")
      compare(texts(), "|after")
      editor.mindMapToList(made)
      compare(types(), "bullet,bullet,bullet,bullet,p")
      compare(depths(), "0,1,2,1,0")
      compare(texts(), "Trip|Pack|Passport|Book hotel|after")
      editor.undo()
      compare(types(), "mindmap,p", "both are steps to undo")
      // Several blocks: the ideas of a "Mind map".
      page(["one", "two", "three"])
      editor.toMindMap([editor.uidAt(0), editor.uidAt(2)])
      compare(outline(), "Mind map\n  one\n  three")
      compare(texts(), "|two")
    }

    function test_10_placeholders_and_empty_toggles() {
      page([{ type: "h1", html: "" }, { type: "toggle", html: "Empty" }])
      verify(item(1).emptyToggle, "an open toggle with nothing in it says so")
      editor.addChild(editor.uidAt(1))
      compare(depths(), "0,0,1")
      verify(!item(1).emptyToggle)
    }
  }
}
