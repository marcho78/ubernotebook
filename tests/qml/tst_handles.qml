import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"

// The + and ⋮⋮ beside a block: there, steady, however the pointer comes to
// them (from its text, from above, from below) and while it rests on them,
// on every kind of block. On the + the hover is the +'s, not the zone's
// behind it: they used to go as you reached them, from above (to-dos,
// toggles), and come back as you moved, blinking.
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
    name: "Handles"
    when: windowShown

    function find(item, test, out) {
      if (!item) return out
      if (test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) find(item.children[i], test, out)
      return out
    }

    function test_the_plus_steady_however_the_pointer_comes() {
      files.reset()
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      ws.ensureStarted()
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      wait(300)
      var pluses = find(root, function(it) { return it.objectName === "blockPlus" }, [])
      verify(pluses.length > 3, "blocks with a +: " + pluses.length)
      var types = {}
      var tried = 0
      for (var k = 0; k < pluses.length; k++) {
        var plus = pluses[k]
        var handles = plus.parent
        var block = handles.parent
        if (types[block.type] >= 2) continue
        var c = plus.mapToItem(root, plus.width / 2, plus.height / 2)
        if (c.y < 60 || c.y > root.height - 60) continue
        types[block.type] = (types[block.type] || 0) + 1
        tried++
        var ways = { "from its text": block.mapToItem(root, handles.x + 160, handles.y + handles.height / 2),
          "from above": Qt.point(c.x, c.y - 40), "from below": Qt.point(c.x, c.y + 40) }
        for (var way in ways) {
          mouseMove(root, root.width - 5, 5)
          wait(30)
          var s = ways[way]
          for (var i = 0; i <= 20; i++) {
            mouseMove(root, s.x + (c.x - s.x) * i / 20, s.y + (c.y - s.y) * i / 20)
            wait(16)
          }
          verify(handles.visible, block.type + ", " + way + ": the + is there under the pointer")
          // Resting on it: no blinking.
          for (var j = 0; j < 15; j++) {
            wait(16)
            verify(handles.visible, block.type + ", " + way + ": still there")
          }
        }
      }
      verify(tried >= 5, "kinds of block tried: " + JSON.stringify(types))
      verify(types.check > 0, "a to-do among them (where it went)")
      // And a click on it: a block below.
      var before = view.editor.model.count
      var first = pluses.filter(function(p) { var y = p.mapToItem(root, 0, 0).y; return y > 60 && y < root.height - 60 })[0]
      var at = first.mapToItem(root, first.width / 2, first.height / 2)
      mouseMove(root, at.x + 60, at.y)
      wait(30)
      mouseMove(root, at.x, at.y)
      wait(30)
      mouseClick(root, at.x, at.y)
      tryCompare(view.editor.model, "count", before + 1, 1000)
    }
  }
}
