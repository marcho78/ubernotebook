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
    // (Each test counts from nothing, the card empty.)
    function init() { card.clear(); kept.clear(); picked.clear(); thrown.clear() }

    // Words given back for one profile (its folder couldn't be used), and
    // another open by the time they're saved: not written there unless you
    // save again, told.
    function test_given_back_for_another_profile() {
      card.nameOf = function(id) { return id === "p-a" ? "Client" : id === "p-b" ? "Personal" : "" }
      card.openProfile = "p-b"
      card.hold("For the client", "Not saved: that folder can't be used", "p-a")
      card.keep()
      compare(kept.count, 0, "not written into the other")
      verify(/kept for \u201cClient\u201d/.test(card.problem), card.problem)
      verify(/keep them in \u201cPersonal\u201d/.test(card.problem), card.problem)
      card.keep()
      compare(kept.count, 1, "saved again: kept where you are")
      compare(kept.signalArguments[0][0], "For the client")
      // Theirs open again: kept straight away.
      card.clear()
      kept.clear()
      card.openProfile = "p-a"
      card.hold("Again", "", "p-a")
      card.keep()
      compare(kept.count, 1)
      card.openProfile = ""
      card.nameOf = null
    }

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

    // A note that couldn't be kept stays in the card, with why: opened
    // again (its shortcut, to try again), it's as it was, never wiped.
    function test_opened_again_keeps_what_wasnt_kept() {
      card.start("Call the bank")
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(kept.count, 1)
      // (The service said no: the card stays up, the note in it.)
      card.problem = "Not saved: this profile's notes folder can't be used"
      verify(card.held)
      card.open()
      compare(card.problem, "Not saved: this profile's notes folder can't be used", "why, still said")
      verify(card.held, "its words still there")
      keyClick(Qt.Key_Space)
      keyClick(Qt.Key_A)
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(kept.count, 2)
      compare(kept.signalArguments[1][0], "Call the bank a", "the same note, written on")
      // Kept (or thrown away): nothing left; opened again, a new one.
      card.clear()
      verify(!card.held)
      card.open()
      compare(card.problem, "")
      keyClick(Qt.Key_Escape)
      compare(thrown.count, 1, "empty: let go")
    }

    // A note kept for a while, given back (its profile's folder couldn't be
    // used after all): put in after what's there, with why.
    function test_a_note_given_back() {
      card.start("Draft")
      card.hold("Call Bob", "Not saved: pick another folder")
      compare(card.problem, "Not saved: pick another folder")
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(kept.count, 1)
      compare(kept.signalArguments[0][0], "Draft\n\nCall Bob")
      card.clear()
      card.hold("Only this", "")
      keyClick(Qt.Key_Return, Qt.ControlModifier)
      compare(kept.signalArguments[1][0], "Only this")
      card.clear()
    }
  }
}
