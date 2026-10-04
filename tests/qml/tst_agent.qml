import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html

// Asking your agent from Pages: "/agent", Ctrl+J, the block menu and the
// page's menu open the box; what you ask goes to Omarchy's default agent with
// where you are (FakeFiles keeps what was launched): in a terminal, or, for
// Claude Code, in a panel on the page (FakeFiles feeds what it says).
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
      // (An agent that opens in a terminal; test_6 has Claude Code, which works here.)
      files.agent = "gemini"
      if (view.agentPanel.visible) { view.stopAgent(); view.agentPanel.status = ""; view.agentPanel.visible = false }
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
      tryCompare(view.agentBox, "agent", "gemini")
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

    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }

    // Claude Code works here: a panel on the page with its steps and its
    // answer as they come, no terminal; asked again while it works, it says
    // so; Stop; when it can't, why, and a terminal instead.
    function test_6_claude_code_works_here() {
      fresh()
      files.agent = "claude"
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      compare(view.agentBox.agent, "claude")
      verify(find(root.Window.window.contentItem, function(it) { return typeof it.text === "string" && it.text.indexOf("Claude Code works here, in a panel on the page") === 0 }) !== null, "the box says where it works")
      view.agentBox.send("Turn this into to-dos")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      compare(files.launched.length, 0, "no terminal")
      var run = files.streamed[0]
      compare(run.argv[4], "claude")
      var prompt = run.argv[run.argv.length - 1]
      verify(prompt.indexOf("What I'd like: Turn this into to-dos") >= 0, prompt)
      verify(prompt.indexOf("(page id " + view.page.id + ")") >= 0)
      verify(prompt.indexOf("small panel on the page") >= 0, "it knows where its words go")
      compare(run.cwd, files.runtimeDir + "/uber-notebook-agent")
      var panel = view.agentPanel
      verify(panel.visible)
      compare(panel.status, "working")
      compare(panel.agentLabel, "Claude Code")
      // Its steps, and its answer as it's written.
      files.streamFeed(JSON.stringify({ type: "system", subtype: "init", model: "claude-opus-5-5" }))
      files.streamFeed(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", name: "Bash", input: { command: "omarchy-shell uber-notebook blocks " + view.page.id } }] } }))
      compare(panel.steps, ["Reading the page"])
      tryVerify(function() { var st = named(panel, "agentPanelStep"); return st !== null && st.text === "Reading the page" }, 1000)
      files.streamFeed(JSON.stringify({ type: "stream_event", event: { type: "content_block_start", content_block: { type: "text", text: "" } } }))
      files.streamFeed(JSON.stringify({ type: "stream_event", event: { type: "content_block_delta", delta: { type: "text_delta", text: "Made the " } } }))
      tryCompare(named(panel, "agentPanelAnswer"), "text", "Made the ", 1000)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Made the to-dos.", duration_ms: 4200, permission_denials: [] }))
      compare(panel.status, "done")
      compare(named(panel, "agentPanelAnswer").text, "Made the to-dos.")
      files.streamEnd(0, "")
      compare(view.agentRun, null)
      compare(named(panel, "agentPanelStatus").text, "done in 4.2s")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      verify(!panel.visible)
      // Asked again while it works: no second one; Stop.
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Summarize this page")
      tryVerify(function() { return files.streamed.length === 2 && view.agentRun !== null }, 1000)
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("And again")
      compare(files.streamed.length, 2, "one at a time")
      verify(panel.visible)
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelStop"))
      tryCompare(panel, "status", "stopped", 1000)
      compare(view.agentRun, null)
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      // It can't: why, and a terminal instead.
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Link related pages")
      tryVerify(function() { return files.streamed.length === 3 }, 1000)
      files.streamEnd(127, "bash: line 1: exec: claude: not found")
      compare(panel.status, "failed")
      verify(named(panel, "agentPanelFailure").text.indexOf("isn't installed") >= 0)
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelTerminal"))
      compare(files.launched.length, 1, "the usual way")
      verify(files.launched[0].indexOf("What I'd like: Link related pages") >= 0)
      verify(!panel.visible)
    }

    // Grok and Codex work here too, each as Omarchy starts it, their steps
    // and answers in the same panel.
    function test_7_grok_and_codex_work_here_too() {
      fresh()
      var panel = view.agentPanel
      // Codex: its items, whole.
      files.agent = "codex"
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Turn this into to-dos")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      compare(files.launched.length, 0, "no terminal")
      compare(files.streamed[0].argv.slice(4, 7), ["codex", "exec", "--json"])
      compare(panel.agentLabel, "Codex")
      files.streamFeed(JSON.stringify({ type: "thread.started", thread_id: "t1" }))
      files.streamFeed(JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "I'll read the page first." } }))
      files.streamFeed(JSON.stringify({ type: "item.started", item: { type: "command_execution", command: "/usr/bin/bash -lc 'omarchy-shell uber-notebook blocks " + view.page.id + "'" } }))
      files.streamFeed(JSON.stringify({ type: "item.started", item: { type: "command_execution", command: "/usr/bin/bash -lc 'omarchy-shell uber-notebook insertAfter p b /run/user/1000/t.md'" } }))
      compare(panel.steps, ["Reading the page", "Writing on the page"])
      files.streamFeed(JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "Added three to-dos." } }))
      files.streamFeed(JSON.stringify({ type: "turn.completed", usage: {} }))
      compare(panel.status, "done")
      compare(panel.answer, "Added three to-dos.", "its last message")
      files.streamEnd(0, "Reading additional input from stdin...")
      compare(panel.status, "done")
      verify(panel.seconds >= 0)
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      // Grok: Claude Code's kind of lines, its own tools.
      files.agent = "grok"
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Summarize this page")
      tryVerify(function() { return files.streamed.length === 2 }, 1000)
      var g = files.streamed[1].argv
      compare(g[4], "grok")
      verify(g[g.length - 1].indexOf("--single=") === 0)
      compare(panel.agentLabel, "Grok")
      files.streamFeed(JSON.stringify({ type: "system", subtype: "init", model: "grok-4.6" }))
      files.streamFeed(JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", name: "run_terminal_command", input: { command: "omarchy-shell uber-notebook read " + view.page.id } }] } }))
      compare(panel.steps, ["Reading the page"])
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, duration_ms: 3870, result: "It's a page about trams." }))
      compare(panel.status, "done")
      compare(panel.answer, "It's a page about trams.")
      files.streamEnd(0, "")
    }

    // The model and effort, chosen in the box: kept for that agent, and on
    // its command line; the panel says which.
    function test_8_model_and_effort_in_the_box() {
      fresh()
      files.disk["/tmp/.grok/models_cache.json"] = '{"models":{"grok-4.7":{"info":{"id":"grok-4.7","name":"Grok 4.7","description":"Latest","hidden":false,"reasoning_effort":"high","reasoning_efforts":[{"id":"xhigh","value":"xhigh"},{"id":"high","value":"high"},{"id":"medium","value":"medium"},{"id":"low","value":"low"}]}},"grok-4.5":{"info":{"id":"grok-4.5","name":"Grok 4.5","hidden":false,"reasoning_effort":"high","reasoning_efforts":[{"id":"high","value":"high"},{"id":"medium","value":"medium"},{"id":"low","value":"low"}]}}}}'
      files.agent = "grok"
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known && view.agentBox.models.length === 2 }, 1000, "Grok's models")
      var modelButton = null
      tryVerify(function() { modelButton = named(root.Window.window.contentItem, "askChoiceModel"); return modelButton !== null }, 1000)
      compare(find(modelButton, function(it) { return it.text === "Default model" }) !== null, true)
      mouseClick(modelButton)
      var pick = null
      tryVerify(function() { pick = named(root.Window.window.contentItem, "askChoiceModel_grok-4.7"); return pick !== null }, 1000)
      wait(100)
      mouseClick(pick)
      compare(service.settings.grokModel, "grok-4.7")
      var effortButton = named(root.Window.window.contentItem, "askChoiceEffort")
      mouseClick(effortButton)
      tryVerify(function() { pick = named(root.Window.window.contentItem, "askChoiceEffort_low"); return pick !== null }, 1000)
      verify(named(root.Window.window.contentItem, "askChoiceEffort_xhigh") !== null, "Grok 4.7 takes xhigh")
      wait(100)
      mouseClick(pick)
      compare(service.settings.grokEffort, "low")
      // An older model that doesn't take the effort: back to its default.
      service.setSetting("grokEffort", "xhigh")
      mouseClick(modelButton)
      tryVerify(function() { pick = named(root.Window.window.contentItem, "askChoiceModel_grok-4.5"); return pick !== null }, 1000)
      wait(100)
      mouseClick(pick)
      compare(service.settings.grokModel, "grok-4.5")
      compare(service.settings.grokEffort, "", "4.5 doesn't take xhigh")
      service.setSetting("grokModel", "grok-4.7")
      service.setSetting("grokEffort", "low")
      view.agentBox.send("Summarize this page")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      var argv = files.streamed[0].argv
      compare(argv.slice(argv.indexOf("-m"), argv.indexOf("-m") + 4), ["-m", "grok-4.7", "--reasoning-effort", "low"])
      compare(view.agentPanel.choiceText, "Grok 4.7 \u00b7 Low")
      view.stopAgent()
      tryCompare(view.agentPanel, "status", "stopped", 1000)
      service.setSetting("grokModel", "")
      service.setSetting("grokEffort", "")
    }

    function test_5_the_ai_button_and_the_agent_chooser() {
      fresh()
      files.agent = "claude"
      // The AI button at the top of the page opens the box.
      verify(!view.agentBox.opened)
      var button = find(root.Window.window.contentItem, function(it) { return it.tip === "Ask your agent  Ctrl+J" })
      verify(button !== null, "an AI button at the top of the page")
      mouseClick(button)
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      // Your agent, and the others installed: choose one, and nothing opens.
      compare(view.agentBox.agents.map(function(a) { return a.name }).join(","), "claude,codex,gemini")
      clickText("Claude")
      clickText("Gemini")
      compare(files.agent, "gemini", "Omarchy's default, from now on")
      compare(view.agentBox.agent, "gemini")
      verify(findText(root.Window.window.contentItem, "Gemini") !== null, "the box says which")
      compare(files.launched.length, 0, "nothing launched")
      compare(files.picked, 0)
      view.agentBox.send("Summarize this page")
      compare(files.launched.length, 1, "what you ask goes to the agent you chose")
      verify(files.launched[0].indexOf("What I'd like: Summarize this page") >= 0)
    }
  }
}
