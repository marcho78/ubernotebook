import QtQuick
import QtTest
import "../../app"

// A click on a button is the button's: never also on what's under it (in
// Qt, a tap goes on to the handlers under it unless one takes it). Each of
// the app's buttons over something that counts its taps, as a link or a
// bookmark's card on a page would; and the agent panel over one, its
// question's Allow and its empty space clicked.
Item {
  id: root
  width: 900
  height: 700

  Theme { id: th }

  // What's under: a page's link or a bookmark's card.
  Rectangle {
    id: under
    anchors.fill: parent
    color: "white"
    property int taps: 0
    TapHandler { onTapped: under.taps++ }
  }

  property int clicked: 0
  property string answered: ""
  TextButton { id: textButton; x: 20; y: 20; theme: th; text: "Allow this command"; onClicked: root.clicked++ }
  IconButton { id: iconButton; x: 20; y: 80; theme: th; icon: th.icons.close; onClicked: root.clicked++ }
  Toggle { id: toggle; x: 20; y: 140; theme: th; onToggled: function(on) { root.clicked++ } }
  Chip { id: chip; x: 20; y: 200; theme: th; text: "Chip"; onClicked: root.clicked++ }

  AgentPanel {
    id: panel
    x: 300
    y: 20
    theme: th
    maxHeight: 600
    onAsked: function(key, how) { root.answered = key + ":" + how }
  }

  TestCase {
    name: "ClickThrough"
    when: windowShown

    function find(item, name) {
      if (!item) return null
      if (item.objectName === name) return item
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) { var f = find(kids[i], name); if (f) return f }
      return null
    }

    function test_1_a_button_takes_its_click() {
      var buttons = [textButton, iconButton, toggle, chip]
      for (var i = 0; i < buttons.length; i++) {
        under.taps = 0
        var before = root.clicked
        mouseClick(buttons[i])
        tryCompare(root, "clicked", before + 1, 1000)
        wait(50)
        compare(under.taps, 0, "nothing under " + buttons[i] + " clicked")
      }
    }

    function test_2_the_agent_panel_takes_its_clicks() {
      panel.begin("Grok", "Make a page", null)
      panel.asks = [{ key: "k1", text: "run “ls”", detail: "ls", grant: "shell", conversation: "", always: "" }]
      panel.visible = true
      var allow = null
      tryVerify(function() { allow = find(panel, "agentAskOnce"); return allow !== null && allow.visible && allow.width > 0 }, 2000)
      under.taps = 0
      mouseClick(allow)
      tryCompare(root, "answered", "k1:once", 1000)
      wait(50)
      compare(under.taps, 0, "Allow's click isn't the page's")
      // Its empty space too (left of its question's buttons).
      var text = find(panel, "agentAskText")
      verify(text !== null)
      mouseClick(panel, 4, panel.height / 2)
      wait(50)
      compare(under.taps, 0, "the panel's empty space isn't the page's")
      // Closed, it takes nothing.
      panel.visible = false
      mouseClick(root, panel.x + 10, panel.y + 10)
      tryCompare(under, "taps", 1, 1000)
    }
  }
}
