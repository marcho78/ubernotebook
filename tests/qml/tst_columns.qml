import QtQuick
import QtTest
import "../../app"

// Guides for columns in Pages: an outline round each while you're working
// in them (the pointer over them, writing or a block picked in one, a drag),
// "Empty column" in an empty one, what a drop beside a block will make, and
// the block dropped picked after. There were none: an empty column showed
// nothing, a drag only a thin line at the page's edge.
Item {
  id: root
  width: 900
  height: 900

  Editor {
    id: editor
    layout: "doc"
    x: 60
    width: 720
    contentWidth: 720
    focus: true
  }

  TestCase {
    name: "Columns"
    when: windowShown

    function find(item, test, out) {
      if (!item) return out
      if (test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) find(item.children[i], test, out)
      return out
    }
    function named(name) { return find(editor, function(it) { return it.objectName === name && it.visible }, []) }
    function outlines() { return named("columnOutline").length }
    function sets() { return find(editor, function(it) { return it.objectName === "columnSet" }, []) }
    function item(i) { return editor.items[editor.uidAt(i)] }
    function page(list) {
      editor.readOnly = false
      editor.load(list.map(function(b) { return typeof b === "string" ? { type: "p", html: b } : b }))
      waitForRendering(editor)
      wait(50)
    }
    function away() {
      mouseMove(root, root.width - 2, root.height - 2)
      wait(30)
    }
    function hints() {
      return find(editor, function(it) { return it.text === "Empty column" && it.visible }, []).length
    }

    function test_1_new_columns_show_where_they_are() {
      page(["intro", ""])
      editor.insertColumns(editor.uidAt(1), 3)
      waitForRendering(editor)
      away()
      compare(sets().length, 1)
      compare(sets()[0].modelData.cols.length, 3)
      compare(outlines(), 3, "writing in the first: all three outlined")
      compare(hints(), 2, "the two you're not in say they're empty")
      // Writing elsewhere, the pointer away: none.
      editor.focusBlock(editor.uidAt(0), -1)
      wait(30)
      compare(outlines(), 0, "reading: no lines")
      compare(hints(), 3)
      // Something written in one: it isn't empty.
      editor.focusBlock(editor.uidAt(3), 0)
      keyClick("a")
      editor.focusBlock(editor.uidAt(0), -1)
      wait(30)
      compare(hints(), 2)
    }

    function test_2_the_pointer_over_them() {
      page(["intro", { type: "columns" }, { type: "column", indent: 1 }, { type: "p", html: "left", indent: 2 },
        { type: "column", indent: 1 }, { type: "p", html: "right", indent: 2 }, "after"])
      editor.focusBlock(editor.uidAt(0), -1)
      away()
      compare(outlines(), 0)
      var right = item(5)
      var at = right.mapToItem(root, 40, right.height / 2)
      for (var i = 0; i <= 8; i++) { mouseMove(root, at.x - 80 + i * 10, at.y); wait(16) }
      compare(outlines(), 2, "over them: outlined")
      var handles = find(right, function(it) { return it.objectName === "blockHandles" }, [])[0]
      verify(handles.visible, "and the block's own + and ⋮⋮ still come up")
      // In the gap between them too.
      var gap = editor.columnGaps[0]
      var lay = editor.docLayout[gap.left]
      var g = editor.mapToItem(root, lay.left + lay.w + editor.columnGap / 2, gap.top + 4)
      mouseMove(root, g.x, g.y)
      wait(30)
      compare(outlines(), 2)
      var below = item(6).mapToItem(root, 40, item(6).height - 2)
      mouseMove(root, below.x, below.y)
      wait(30)
      compare(outlines(), 0, "past them: gone")
      // A locked page: none.
      editor.readOnly = true
      mouseMove(root, at.x, at.y)
      wait(30)
      compare(outlines(), 0)
      editor.readOnly = false
    }

    function test_3_a_drop_beside_a_block_shows_what_it_makes() {
      page(["left", "right", "after"])
      away()
      var target = item(0)
      editor.dragStart(editor.uidAt(1))
      editor.dragMove(target.x + target.width - 10, target.y + target.height / 2)
      var t = editor.dropTarget
      verify(t && t.side === editor.uidAt(0))
      compare(t.preview.length, 2, "two columns there'll be")
      verify(!t.preview[0].fresh && t.preview[1].fresh, "the new one on the right")
      compare(Math.round(t.preview[0].w), Math.round(t.preview[1].w))
      verify(t.preview[1].x > t.preview[0].x + t.preview[0].w)
      wait(30)
      compare(named("columnPreviewNew").length, 1)
      compare(named("columnPreview").length, 1)
      editor.dragEnd(true)
      compare(named("columnPreviewNew").length, 0, "gone after the drop")
      // What moved: picked, and its columns outlined a moment.
      var moved = editor.uidAt(4)
      compare(editor.selectedList.length, 1)
      compare(editor.selectedList[0], moved)
      compare(editor.columnsFlash, editor.uidAt(0))
      wait(30)
      compare(outlines(), 2)
      editor.clearBlockSelection()
      tryCompare(editor, "columnsFlash", "", 2500)
      away()
      editor.focusBlock(editor.uidAt(5), -1)
      wait(30)
      compare(outlines(), 0)
    }

    function test_4_a_drop_into_columns_shows_where_it_goes() {
      page([{ type: "columns" }, { type: "column", indent: 1 }, { type: "p", html: "a", indent: 2 },
        { type: "column", indent: 1 }, { type: "p", html: "b", indent: 2 }, "dragged", "after"])
      away()
      var b = item(4)
      editor.dragStart(editor.uidAt(5))
      editor.dragMove(b.x + b.width - 10, b.y + b.height / 2)
      var t = editor.dropTarget
      verify(t && t.side === editor.uidAt(4))
      compare(t.set, editor.uidAt(0))
      compare(t.preview.map(function(p) { return p.fresh }).join(","), "false,false,true", "the columns as they are, the slot after b")
      var lay = editor.docLayout[editor.uidAt(3)]
      verify(t.preview[2].x > lay.left + lay.w, "in the gap after its column")
      wait(30)
      compare(outlines(), 0, "the preview, not the outlines as well")
      compare(named("columnPreview").length, 2)
      editor.dragEnd(true)
      compare(editor.serialize().map(function(x) { return x.type }).join(","), "columns,column,p,column,p,column,p,p")
      compare(editor.selectedList[0], editor.uidAt(6))
      editor.clearBlockSelection()
      // Beside a's: the slot between the two.
      page([{ type: "columns" }, { type: "column", indent: 1 }, { type: "p", html: "a", indent: 2 },
        { type: "column", indent: 1 }, { type: "p", html: "b", indent: 2 }, "dragged"])
      var a = item(2)
      editor.dragStart(editor.uidAt(5))
      editor.dragMove(a.x + a.width - 10, a.y + a.height / 2)
      compare(editor.dropTarget.preview.map(function(p) { return p.fresh }).join(","), "false,true,false")
      editor.dragEnd(false)
    }

    function test_5_six_at_most_but_its_own_column_goes() {
      var list = [{ type: "columns" }]
      for (var c = 0; c < 6; c++) {
        list.push({ type: "column", indent: 1 })
        list.push({ type: "p", html: "c" + c, indent: 2 })
      }
      list.push("outside")
      page(list)
      var first = item(2)
      editor.dragStart(editor.uidAt(13))
      editor.dragMove(first.x + first.width - 6, first.y + first.height / 2)
      verify(!editor.dropTarget || !editor.dropTarget.side, "a seventh: no")
      editor.dragEnd(false)
      // The last column's only block, beside the first: its column goes, so
      // there's room.
      editor.dragStart(editor.uidAt(12))
      editor.dragMove(first.x + first.width - 6, first.y + first.height / 2)
      verify(editor.dropTarget && editor.dropTarget.side === editor.uidAt(2))
      editor.dragEnd(true)
      var cols = editor.serialize().filter(function(x) { return x.type === "column" }).length
      compare(cols, 6)
      compare(editor.serialize().map(function(x) { return x.html || "" }).filter(function(h) { return h }).slice(0, 3).join(","), "c0,c5,c1")
    }
  }
}
