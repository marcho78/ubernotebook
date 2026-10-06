import QtQuick
import QtTest
import "../../app"

// A menu's line: what it does in full, and its hint (a model's description,
// a shortcut) in the room left beside it, cut short, never over it.
Item {
  id: root
  width: 400
  height: 200

  Theme { id: th }

  Column {
    width: 320
    MenuRow { id: shortcut; width: parent.width; theme: th; icon: th.icons.agent; text: "Find a page"; hint: "Ctrl+P" }
    MenuRow { id: model; width: parent.width; theme: th; icon: th.icons.agent; text: "GPT-6-Astra"; hint: "Frontier intelligence for the most demanding work." }
    MenuRow { id: long; width: parent.width; theme: th; icon: th.icons.agent; text: "A model with a name far too long for this menu"; hint: "Older fast and efficient model." }
  }

  TestCase {
    name: "MenuRow"
    when: windowShown

    function find(item, name) {
      if (!item) return null
      if (item.objectName === name) return item
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) { var f = find(kids[i], name); if (f) return f }
      return null
    }
    function parts(row) {
      var label = find(row, "menuRowText")
      var hint = find(row, "menuRowHint")
      var l = label.mapToItem(row, 0, 0)
      var h = hint.mapToItem(row, 0, 0)
      return { label: label, hint: hint, labelEnd: l.x + label.width, hintStart: h.x, hintEnd: h.x + hint.width }
    }

    function test_a_hint_beside_what_it_does_never_over_it() {
      var s = parts(shortcut)
      compare(s.hint.truncated, false, "a shortcut whole")
      verify(s.hint.visible)
      var rows = [shortcut, model, long]
      for (var i = 0; i < rows.length; i++) {
        var p = parts(rows[i])
        verify(!p.hint.visible || p.hintStart >= p.labelEnd + 10, rows[i].text + ": " + JSON.stringify([p.labelEnd, p.hintStart]))
        verify(p.hintEnd <= rows[i].width, "inside the menu")
      }
      var m = parts(model)
      compare(m.label.truncated, false, "the model's name whole")
      verify(m.hint.truncated, "its description cut short")
      var l = parts(long)
      verify(l.labelEnd <= long.width - 10, "a name too long: cut short too, inside the menu")
    }
  }
}
