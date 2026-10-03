import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html

// Asking your agent from Pages: "/agent", Ctrl+J, the block menu and the
// page's menu open the box; what you ask goes to Omarchy's default agent with
// where you are (FakeFiles keeps what was launched).
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  TestCase {
    name: "Ask agent"
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
      if (view.agentBox.opened) view.agentBox.close()
      tryVerify(function() { return !view.agentBox.visible }, 1000)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i))
    }
    function lastPrompt() { return files.launched[files.launched.length - 1] || "" }

    function test_1_slash_agent_on_an_empty_line() {
      fresh()
      var e = view.editor
      var last = e.uidAt(e.model.count - 1)
      e.focusBlock(last, 0)
      type("/agent")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "agent", "Ask agent is there")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "line")
      compare(view.agentBox.ask.line, last)
      compare(Html.plainText(e.blockAt(e.indexOf(last)).html), "", "the /agent typed is gone")
      tryCompare(view.agentBox, "agent", "claude")
      type("Write an outline")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return !view.agentBox.opened }, 1000)
      compare(files.launched.length, 1)
      var p = lastPrompt()
      verify(p.indexOf("(page id " + view.page.id + ")") >= 0, p)
      verify(p.indexOf("block " + last + ": put what you write there") >= 0, "the line it writes on")
      verify(p.indexOf("What I'd like: Write an outline") >= 0)
      verify(p.indexOf(service.skillPath) >= 0, "and the skill")
      verify(Object.keys(view.page.blocks).indexOf(last) >= 0, "the line is on the page as written, for the agent to find")
    }

    function test_2_ctrl_j_works_out_what_its_about() {
      fresh()
      var e = view.editor
      // Words selected in a block.
      var first = e.uidAt(0)
      e.focusBlock(first, 0)
      e.items[first].edit.select(0, 10)
      keyClick(Qt.Key_J, Qt.ControlModifier)
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "words")
      compare(view.agentBox.ask.blocks, [first])
      compare(view.agentBox.ask.words, Html.plainText(e.blockAt(0).html).slice(0, 10))
      view.agentBox.close()
      // Blocks picked.
      e.selectBlocks(e.uidAt(1), e.uidAt(2))
      view.forceActiveFocus()
      keyClick(Qt.Key_J, Qt.ControlModifier)
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "blocks")
      compare(view.agentBox.ask.blocks.length, 2)
      view.agentBox.close()
      e.clearBlockSelection()
      // Nothing picked: the page.
      view.forceActiveFocus()
      keyClick(Qt.Key_J, Qt.ControlModifier)
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "page")
      // A suggestion goes straight off.
      view.agentBox.send("Summarize this page")
      compare(files.launched.length, 1)
      verify(lastPrompt().indexOf("What I'd like: Summarize this page") >= 0)
    }

    // A visible Text saying `text`, anywhere in the window (popups too).
    function findText(item, text) {
      if (!item) return null
      if (item.text === text && item.visible && item.width > 0 && typeof item.textFormat !== "undefined") return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = findText(item.children[i], text)
        if (hit) return hit
      }
      return null
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
    // Clicks it once it's on screen and what it's in has finished opening.
    function clickText(text) {
      tryVerify(function() { return findText(root.Window.window.contentItem, text) !== null }, 1000, text + " is on screen")
      wait(250)
      mouseClick(findText(root.Window.window.contentItem, text))
    }

    function test_3_the_menus_and_the_toolbar() {
      fresh()
      var e = view.editor
      // A block's ⋮⋮ menu.
      var uid = e.uidAt(1)
      e.blockMenuRequested(uid)
      clickText("Ask agent")
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "blocks")
      compare(view.agentBox.ask.blocks, [uid])
      view.agentBox.close()
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      e.clearBlockSelection()
      // The toolbar over selected words.
      var first = e.uidAt(0)
      e.focusBlock(first, 0)
      e.items[first].edit.select(0, 8)
      clickText("Ask")
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "words")
      view.agentBox.close()
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      // The page's ⋯ menu.
      verify(findText(root.Window.window.contentItem, "Ask agent about this page") === null, "in the menu, not on the page")
      var more = find(root.Window.window.contentItem, function(it) { return it.tip === "Font, width, export, trash" })
      verify(more !== null)
      mouseClick(more)
      clickText("Ask agent about this page")
      tryVerify(function() { return view.agentBox.opened }, 1000)
      compare(view.agentBox.ask.scope, "page")
      view.agentBox.close()
    }

    function test_4_no_default_agent_yet() {
      fresh()
      files.agent = ""
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      compare(view.agentBox.agent, "")
      view.agentBox.send("Summarize this page")
      compare(files.launched.length, 0, "nothing is launched")
      compare(files.picked, 0, "not Omarchy's menu (it would launch the agent)")
      clickText("Gemini")
      compare(files.agent, "gemini", "chosen in the box")
      compare(files.launched.length, 0, "and nothing opens")
      view.agentBox.close()
      tryVerify(function() { return !view.agentBox.visible }, 1000)
    }

    function test_5_the_ai_button_and_the_agent_chooser() {
      fresh()
      // The AI button at the top of the page opens the box.
      verify(!view.agentBox.opened)
      var button = find(root.Window.window.contentItem, function(it) { return it.tip === "Ask your agent  Ctrl+J" })
      verify(button !== null, "an AI button at the top of the page")
      mouseClick(button)
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      // Your agent, and the others installed: choose one, and nothing opens.
      compare(view.agentBox.agents.map(function(a) { return a.name }).join(","), "claude,codex,gemini")
      clickText("Claude")
      clickText("Codex")
      compare(files.agent, "codex", "Omarchy's default, from now on")
      compare(view.agentBox.agent, "codex")
      verify(findText(root.Window.window.contentItem, "Codex") !== null, "the box says which")
      compare(files.launched.length, 0, "nothing launched")
      compare(files.picked, 0)
      view.agentBox.send("Summarize this page")
      compare(files.launched.length, 1, "what you ask goes to the agent you chose")
      verify(files.launched[0].indexOf("What I'd like: Summarize this page") >= 0)
    }
  }
}
