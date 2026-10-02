import QtQuick
import QtTest
import "../../app"

// The quick-note card: where it keeps the note, said at its foot and changed
// there; Ctrl+Enter keeps it, Esc too (only the ✕ throws it away).
Item {
  id: root
  width: 600
  height: 500

  Theme { id: th }

  QuickNote {
    id: card
    anchors.fill: parent
    theme: th
    onDestinationPicked: function(to) { card.destination = to }
  }

  SignalSpy { id: kept; target: card; signalName: "kept" }
  SignalSpy { id: picked; target: card; signalName: "destinationPicked" }
  SignalSpy { id: thrown; target: card; signalName: "thrownAway" }

  TestCase {
    name: "Quick note"
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
    function text(t) { return find(root, function(it) { return it.text === t }) }

    function test_where_it_goes() {
      card.destination = "notebook"
      card.start("Groceries")
      verify(text("Quick notes") !== null, "it says where")
      verify(text("Markdown works") === null)
      mouseClick(find(root, function(it) { return it.objectName === "destination" }))
      compare(picked.count, 1)
      compare(picked.signalArguments[0][0], "pages")
      verify(text("your Pages Inbox") !== null, "and then the other")
      verify(text("Markdown works") !== null, "where Markdown works")
      keyClick(Qt.Key_Space)
      keyClick(Qt.Key_A)
      compare(kept.count, 0, "writing goes on after the click")
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(kept.count, 1)
      compare(kept.signalArguments[0][0], "Groceries a")
      // Esc keeps it too; empty, it's let go.
      card.start("one more")
      keyClick(Qt.Key_Escape)
      compare(kept.count, 2)
      card.start("")
      keyClick(Qt.Key_Escape)
      compare(thrown.count, 1)
    }
  }
}
