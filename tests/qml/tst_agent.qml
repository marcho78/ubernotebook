import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html

// Asking your agent from Pages: "/agent", Ctrl+J, the block menu and the
// page's menu open the box; what you ask goes to Omarchy's default agent with
// where you are (FakeFiles keeps what was launched): in a terminal, or, for
// Claude Code, in a panel on the page (FakeFiles feeds what it says), where a
// reply goes on with it in the same conversation.
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
      view.agentTalk = null
      view.agentPage = null
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
    function all(item, test, out) {
      var list = out || []
      if (!item) return list
      if (item.visible && test(item)) list.push(item)
      for (var i = 0; i < item.children.length; i++) all(item.children[i], test, list)
      return list
    }

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
      // Closed: kept with its page; the AI button says so, and goes back to it.
      verify(view.pageChat !== null)
      var aiButton = named(root.Window.window.contentItem, "agentButton")
      verify(aiButton.swatch.a > 0, "a mark under it")
      mouseClick(aiButton)
      tryVerify(function() { return panel.visible }, 1000, "back to it")
      compare(named(panel, "agentPanelAnswer").text, "Made the to-dos.")
      verify(!view.agentBox.visible, "not the box")
      // A new chat: the box.
      mouseClick(named(panel, "agentPanelNew"))
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Summarize this page")
      tryVerify(function() { return files.streamed.length === 2 && view.agentRun !== null }, 1000)
      // Asked again while it works: its panel, no second one; Stop.
      view.openAgent("page")
      verify(!view.agentBox.opened, "not the box while it works")
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
      // It can't: why, and a terminal instead (a new chat, from the box).
      view.openAgent("page")
      tryVerify(function() { return panel.visible }, 1000)
      mouseClick(named(panel, "agentPanelNew"))
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
      // Grok: Claude Code's kind of lines, its own tools (a new chat: the
      // page's is Codex's).
      files.agent = "grok"
      view.openAgent("page")
      tryVerify(function() { return panel.visible && panel.agentLabel === "Codex" }, 1000, "the page's conversation")
      mouseClick(named(panel, "agentPanelNew"))
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
      tryVerify(function() { pick = named(root.Window.window.contentItem, "askChoiceModel_grok-4.7"); return pick !== null && modelButton.parent.menuOpened }, 1000)
      mouseClick(pick)
      compare(service.settings.grokModel, "grok-4.7")
      var effortButton = named(root.Window.window.contentItem, "askChoiceEffort")
      mouseClick(effortButton)
      tryVerify(function() { pick = named(root.Window.window.contentItem, "askChoiceEffort_low"); return pick !== null && modelButton.parent.menuOpened }, 1000)
      verify(named(root.Window.window.contentItem, "askChoiceEffort_xhigh") !== null, "Grok 4.7 takes xhigh")
      mouseClick(pick)
      compare(service.settings.grokEffort, "low")
      // An older model that doesn't take the effort: back to its default.
      service.setSetting("grokEffort", "xhigh")
      mouseClick(modelButton)
      tryVerify(function() { pick = named(root.Window.window.contentItem, "askChoiceModel_grok-4.5"); return pick !== null && modelButton.parent.menuOpened }, 1000)
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

    // The page made for it (an id that wasn't there before).
    function madeSince(old) { return Object.keys(ws.index.pages).filter(function(k) { return old.indexOf(k) < 0 })[0] || "" }
    function win() { return root.Window.window.contentItem }

    // A new page instead of this one: made first, where you said (at the
    // top of Pages, or inside the page you're on), opened, and the agent
    // told to write it there.
    function test_9_a_new_page() {
      fresh()
      var was = view.page.id
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      compare(view.agentBox.mode, "here")
      compare(named(win(), "askPlaceTop"), null, "where a new page goes: only for a new page")
      verify(findText(win(), "Summarize this page") !== null)
      wait(150)
      mouseClick(named(win(), "askNew"))
      compare(view.agentBox.mode, "new")
      verify(named(win(), "askPlaceTop").checked, "at the top of Pages, as Ctrl+N")
      verify(findText(win(), "Plan my week from my calendar") !== null, "a new page's suggestions")
      compare(findText(win(), "Summarize this page"), null)
      var old = Object.keys(ws.index.pages)
      type("A packing list for Lisbon")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return !view.agentBox.opened }, 1000)
      compare(files.launched.length, 1)
      var id = madeSince(old)
      verify(id !== "", "a new page")
      compare(ws.index.pages[id].parent, "", "at the top")
      verify(ws.index.top.indexOf(id) >= 0)
      tryVerify(function() { return view.page && view.page.id === id }, 2000, "open")
      var p = lastPrompt()
      verify(p.indexOf("a new, empty page for this (page id " + id + "), at the top of Pages") >= 0, p)
      verify(p.indexOf("What I'd like: A packing list for Lisbon") >= 0)
      compare(view.agentPage, null, "in a terminal, it's the terminal's to write")
      // Inside the page you were on.
      view.open(was)
      tryVerify(function() { return view.page && view.page.id === was }, 2000)
      var title = view.page.title
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      wait(150)
      mouseClick(named(win(), "askNew"))
      wait(50)
      mouseClick(named(win(), "askPlaceInside"))
      compare(view.agentBox.place, "inside")
      old = Object.keys(ws.index.pages)
      type("Notes for the trip")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return files.launched.length === 2 }, 1000)
      var inner = madeSince(old)
      compare(ws.index.pages[inner].parent, was, "inside it")
      verify(Workspace.childPages(ws.readPageNow(was)).indexOf(inner) >= 0, "its block on that page")
      tryVerify(function() { return view.page && view.page.id === inner }, 2000)
      verify(lastPrompt().indexOf("(page id " + inner + "), inside \u201c" + title + "\u201d (page id " + was + ")") >= 0, lastPrompt())
    }

    // Working here: what it wrote stays; when it couldn't, the page left
    // empty goes as the panel's closed, and you're where you were; a
    // terminal instead keeps it, to write.
    function test_10_a_new_page_written_here() {
      fresh()
      files.agent = "claude"
      var panel = view.agentPanel
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      wait(150)
      mouseClick(named(win(), "askNew"))
      var old = Object.keys(ws.index.pages)
      view.agentBox.send("A packing list for Lisbon")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      var id = madeSince(old)
      tryVerify(function() { return view.page && view.page.id === id }, 2000)
      compare(view.agentPage.id, id)
      var run = files.streamed[0]
      verify(run.argv[run.argv.length - 1].indexOf("(page id " + id + ")") >= 0)
      // It writes on it (as its append does), and it's done.
      verify(view.appendFromCommand(id, [{ type: "check", html: "Passport", indent: 0 }]) === true)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Made the list.", duration_ms: 3000, permission_denials: [] }))
      files.streamEnd(0, "")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      verify(ws.index.pages[id] !== undefined, "written on: it stays")
      compare(view.page.id, id)
      compare(view.agentPage, null)
      // It couldn't: the page goes with the panel, and you're back (a new
      // chat: this page has one).
      view.openAgent("page")
      tryVerify(function() { return panel.visible }, 1000)
      mouseClick(named(panel, "agentPanelNew"))
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      wait(150)
      mouseClick(named(win(), "askNew"))
      old = Object.keys(ws.index.pages)
      view.agentBox.send("Notes for my next meeting")
      tryVerify(function() { return files.streamed.length === 2 }, 1000)
      var gone = madeSince(old)
      tryVerify(function() { return view.page && view.page.id === gone }, 2000)
      files.streamEnd(1, "boom")
      compare(panel.status, "failed")
      verify(ws.index.pages[gone] !== undefined, "not while the panel says why")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      compare(ws.index.pages[gone], undefined, "empty: gone")
      verify(ws.index.top.indexOf(gone) < 0)
      tryVerify(function() { return view.page && view.page.id === id }, 2000, "back where you were")
      // It couldn't, and a terminal instead: kept, for it to write (a new
      // chat: this page has one).
      view.openAgent("page")
      tryVerify(function() { return panel.visible }, 1000)
      mouseClick(named(panel, "agentPanelNew"))
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      wait(150)
      mouseClick(named(win(), "askNew"))
      old = Object.keys(ws.index.pages)
      view.agentBox.send("A reading list")
      tryVerify(function() { return files.streamed.length === 3 }, 1000)
      var kept = madeSince(old)
      files.streamEnd(127, "bash: line 1: exec: claude: not found")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelTerminal"))
      compare(files.launched.length, 1)
      verify(files.launched[0].indexOf("(page id " + kept + ")") >= 0)
      verify(ws.index.pages[kept] !== undefined, "kept")
      compare(view.agentPage, null)
    }

    // No page open (the calendar): Ctrl+J asks for a new page.
    function test_11_ctrl_j_with_no_page_open() {
      fresh()
      view.openCalendar("", false)
      tryVerify(function() { return view.calendarShown && view.page === null }, 1000)
      view.forceActiveFocus()
      keyClick(Qt.Key_J, Qt.ControlModifier)
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      compare(view.agentBox.mode, "new")
      compare(named(win(), "askMode"), null, "nothing else to ask about")
      compare(named(win(), "askPlaceTop"), null, "it goes at the top")
      verify(findText(win(), "New page") !== null, "it says so")
      var old = Object.keys(ws.index.pages)
      view.agentBox.send("Plan my week from my calendar")
      tryVerify(function() { return files.launched.length === 1 }, 1000)
      var id = madeSince(old)
      compare(ws.index.pages[id].parent, "")
      tryVerify(function() { return view.page && view.page.id === id && !view.calendarShown }, 2000, "the new page, open")
      verify(lastPrompt().indexOf("at the top of Pages") >= 0)
    }

    // A conversation: its answer (a question back, say), a reply at the
    // panel's foot, which goes on in the same one (where you are, when that's
    // changed), back in the box when it's done; closed, it's over.
    function test_12_a_conversation() {
      fresh()
      files.agent = "claude"
      var panel = view.agentPanel
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Make a packing list")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      var a1 = files.streamed[0].argv
      var at = a1.indexOf("--session-id")
      verify(at > 0, "a conversation of its own: " + a1.join(" "))
      var id = a1[at + 1]
      verify(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/.test(id), id)
      compare(a1.indexOf("--resume"), -1)
      // While it works: the reply box there, waiting.
      var reply = named(panel, "agentPanelReply")
      verify(reply !== null, "the reply box, at its foot")
      verify(!reply.enabled, "waiting while it works")
      // It asks something back.
      files.streamFeed(JSON.stringify({ type: "system", subtype: "init", session_id: id, model: "claude-opus-5-5" }))
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Which trip is it for?", duration_ms: 2100, permission_denials: [] }))
      files.streamEnd(0, "")
      compare(panel.status, "done")
      verify(reply.enabled)
      verify(!reply.input.activeFocus, "not focused by itself")
      // The reply: in the same conversation, just your words (nothing's changed).
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(reply)
      tryVerify(function() { return reply.input.activeFocus }, 1000)
      type("Lisbon, 4 days")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return files.streamed.length === 2 }, 1000, "sent")
      var a2 = files.streamed[1].argv
      compare(a2[a2.indexOf("--resume") + 1], id, "the same conversation")
      compare(a2.indexOf("--session-id"), -1)
      compare(a2.slice(-2), ["--", "Lisbon, 4 days"])
      compare(reply.text, "", "sent, the box empty")
      compare(panel.status, "working")
      // What was said before, above.
      var turns = all(panel, function(it) { return it.objectName === "agentPanelTurn" })
      compare(turns.length, 1)
      compare(turns[0].request, "Make a packing list")
      compare(turns[0].answer, "Which trip is it for?")
      compare(named(panel, "agentPanelRequest").text, "\u201cLisbon, 4 days\u201d")
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Added a packing list for Lisbon.", duration_ms: 5200, permission_denials: [] }))
      files.streamEnd(0, "")
      compare(panel.status, "done")
      compare(named(panel, "agentPanelAnswer").text, "Added a packing list for Lisbon.")
      tryVerify(function() { return reply.input.activeFocus }, 1000, "back in the box, to go on")
      // On another page, blocks picked: it's told so, then your words.
      var other = ws.createPage({ title: "Weekend in Porto", blocks: [{ type: "p", html: "Day one", indent: 0 }, { type: "p", html: "Day two", indent: 0 }] })
      view.open(other.id)
      tryVerify(function() { return view.page && view.page.id === other.id }, 2000)
      var e = view.editor
      e.selectBlocks(e.uidAt(0), e.uidAt(1))
      panel.replied("Do the same here")
      tryVerify(function() { return files.streamed.length === 3 }, 1000)
      var p3 = files.streamed[2].argv[files.streamed[2].argv.length - 1]
      verify(p3.indexOf("I'm on another page now: \u201cWeekend in Porto\u201d (page id " + other.id + ").") === 0, p3)
      verify(p3.indexOf("The blocks I've picked: " + e.uidAt(0) + ", " + e.uidAt(1)) > 0, p3)
      verify(/Do the same here$/.test(p3), p3)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Done.", duration_ms: 900, permission_denials: [] }))
      files.streamEnd(0, "")
      // Said again from here, the same picked: just your words.
      panel.replied("Shorter, please")
      tryVerify(function() { return files.streamed.length === 4 }, 1000)
      compare(files.streamed[3].argv[files.streamed[3].argv.length - 1], "Shorter, please")
      compare(all(panel, function(it) { return it.objectName === "agentPanelTurn" }).length, 3)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Shortened.", duration_ms: 700, permission_denials: [] }))
      files.streamEnd(0, "")
      // Closed: over. Asked anew: a new conversation, nothing before it.
      e.selectBlocks("", "")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      verify(!panel.visible)
      compare(view.agentTalk, null)
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Something else")
      tryVerify(function() { return files.streamed.length === 5 }, 1000)
      var a5 = files.streamed[4].argv
      verify(a5.indexOf("--session-id") > 0 && a5[a5.indexOf("--session-id") + 1] !== id, "a new one")
      compare(all(panel, function(it) { return it.objectName === "agentPanelTurn" }).length, 0)
      files.streamEnd(0, "")
    }

    // Codex goes on with the conversation it named (its first line), Grok
    // with the one it was given; one that never said: asked anew.
    function test_13_codex_and_grok_go_on_too() {
      fresh()
      var panel = view.agentPanel
      var tid = "01a105cd-1057-70a1-8862-616924424b31"
      files.agent = "codex"
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Turn this into to-dos")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      compare(files.streamed[0].argv.indexOf("resume"), -1)
      files.streamFeed(JSON.stringify({ type: "thread.started", thread_id: tid }))
      files.streamFeed(JSON.stringify({ type: "item.completed", item: { type: "agent_message", text: "Which ones?" } }))
      files.streamFeed(JSON.stringify({ type: "turn.completed", usage: {} }))
      files.streamEnd(0, "")
      panel.replied("All of them")
      tryVerify(function() { return files.streamed.length === 2 }, 1000)
      var c2 = files.streamed[1].argv
      compare(c2.slice(c2.indexOf("resume")), ["resume", "--", tid, "All of them"])
      files.streamFeed(JSON.stringify({ type: "turn.completed", usage: {} }))
      files.streamEnd(0, "")
      // Stopped before it said its conversation: a reply asks anew.
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      view.openAgent("page")
      tryVerify(function() { return panel.visible }, 1000)
      mouseClick(named(panel, "agentPanelNew"))
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Summarize it")
      tryVerify(function() { return files.streamed.length === 3 }, 1000)
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelStop"))
      tryCompare(panel, "status", "stopped", 1000)
      panel.replied("Shorter")
      tryVerify(function() { return files.streamed.length === 4 }, 1000)
      var c4 = files.streamed[3].argv
      compare(c4.indexOf("resume"), -1, "a new one")
      var p4 = c4[c4.length - 1]
      verify(p4.indexOf("We've talked about this before") >= 0 && p4.indexOf("- I said: Summarize it") >= 0, "told what was said: " + p4)
      verify(p4.indexOf("What I'd like now: Shorter") >= 0, p4)
      compare(all(panel, function(it) { return it.objectName === "agentPanelTurn" }).length, 1, "the same conversation, in the panel")
      files.streamEnd(0, "")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      // Grok: --session-id=, then --resume= the same (a new chat).
      files.agent = "grok"
      view.openAgent("page")
      tryVerify(function() { return panel.visible }, 1000)
      mouseClick(named(panel, "agentPanelNew"))
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("What's this page about?")
      tryVerify(function() { return files.streamed.length === 5 }, 1000)
      var g1 = files.streamed[4].argv.filter(function(a) { return a.indexOf("--session-id=") === 0 })
      compare(g1.length, 1)
      var gid = g1[0].slice("--session-id=".length)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, duration_ms: 800, result: "Trams." }))
      files.streamEnd(0, "")
      panel.replied("More?")
      tryVerify(function() { return files.streamed.length === 6 }, 1000)
      var g2 = files.streamed[5].argv
      verify(g2.indexOf("--resume=" + gid) > 0, g2.join(" "))
      compare(g2[g2.length - 1], "--single=More?")
      files.streamEnd(0, "")
    }

    // Closed, a conversation's kept with its page: the AI button says so, and
    // Ctrl+J goes back to it, the reply box ready (what you picked going with
    // your next message); after a restart too, and, when its own
    // conversation's gone, in a new one told what was said. New chat: the
    // box, the one before kept till the new one starts. A page deleted: its
    // conversation goes with it.
    function test_14_kept_and_gone_back_to() {
      fresh()
      files.agent = "claude"
      var panel = view.agentPanel
      var pid = view.page.id
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      view.agentBox.send("Make a packing list")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      var a1 = files.streamed[0].argv
      var id = a1[a1.indexOf("--session-id") + 1]
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Which city?", duration_ms: 900, permission_denials: [] }))
      files.streamEnd(0, "")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      verify(!panel.visible)
      // Kept: with its page, on disk.
      var chat = ws.chatFor(pid)
      verify(chat !== null)
      compare(chat.session, id)
      compare(chat.turns.length, 1)
      compare(chat.turns[0].answer, "Which city?")
      verify(String(files.disk[ws.chatsPath()]).indexOf("Which city?") >= 0, "written")
      compare(named(root.Window.window.contentItem, "agentButton").tip, "Your conversation with Claude Code (1 message)  Ctrl+J")
      // Ctrl+J: back to it, the reply box ready; a reply goes on in it.
      view.openAgent("auto")
      tryVerify(function() { return panel.visible }, 1000)
      compare(named(panel, "agentPanelAnswer").text, "Which city?")
      compare(named(panel, "agentPanelStatus").text, "", "nothing said of how long it took, back then")
      var reply = named(panel, "agentPanelReply")
      tryVerify(function() { return reply.input.activeFocus }, 1000, "the reply box ready")
      type("Lisbon")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return files.streamed.length === 2 }, 1000)
      var a2 = files.streamed[1].argv
      compare(a2[a2.indexOf("--resume") + 1], id, "its own conversation")
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Wrote it.", duration_ms: 900, permission_denials: [] }))
      files.streamEnd(0, "")
      compare(ws.chatFor(pid).turns.length, 2)
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      // Started again: read from disk, and gone back to.
      ws.chats = ({})
      ws.loadChats()
      tryVerify(function() { return ws.chatFor(pid) !== null }, 1000, "read again")
      view.openAgent("page")
      tryVerify(function() { return panel.visible }, 1000)
      compare(all(panel, function(it) { return it.objectName === "agentPanelTurn" }).length, 1)
      compare(named(panel, "agentPanelAnswer").text, "Wrote it.")
      // Its own conversation gone (cleared out): a new one, told what was said.
      panel.replied("Make it for 3 days")
      tryVerify(function() { return files.streamed.length === 3 }, 1000)
      var a3 = files.streamed[2].argv
      compare(a3[a3.indexOf("--resume") + 1], id)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "error_during_execution", is_error: true, result: "", errors: ["No conversation found with session ID: " + id] }))
      compare(panel.status, "working", "not said as failed")
      files.streamEnd(1, "No conversation found with session ID: " + id)
      tryVerify(function() { return files.streamed.length === 4 }, 1000, "asked anew")
      var a4 = files.streamed[3].argv
      var id2 = a4[a4.indexOf("--session-id") + 1]
      verify(id2 && id2 !== id, "a new session: " + id2)
      compare(a4.indexOf("--resume"), -1)
      var p4 = a4[a4.length - 1]
      verify(p4.indexOf("- I said: Make a packing list") >= 0 && p4.indexOf("You said: Which city?") >= 0 && p4.indexOf("- I said: Lisbon") >= 0, p4)
      verify(p4.indexOf("What I'd like now: Make it for 3 days") >= 0, p4)
      compare(panel.status, "working")
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Three days.", duration_ms: 900, permission_denials: [] }))
      files.streamEnd(0, "")
      compare(panel.status, "done")
      compare(ws.chatFor(pid).session, id2, "kept with its new session")
      compare(ws.chatFor(pid).turns.length, 3)
      // What you picked goes with your next message, and says so.
      var e = view.editor
      e.selectBlocks(e.uidAt(0), e.uidAt(1))
      view.openAgent("auto")
      compare(named(panel, "agentPanelContext").text, "The 2 blocks you picked go with it")
      panel.replied("Turn these into to-dos")
      tryVerify(function() { return files.streamed.length === 5 }, 1000)
      var p5 = files.streamed[4].argv[files.streamed[4].argv.length - 1]
      verify(p5.indexOf("The blocks I've picked: " + e.uidAt(0) + ", " + e.uidAt(1)) === 0, p5)
      verify(/Turn these into to-dos$/.test(p5), p5)
      compare(named(panel, "agentPanelContext"), null, "said once")
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Done.", duration_ms: 900, permission_denials: [] }))
      files.streamEnd(0, "")
      e.selectBlocks("", "")
      // New chat: the box; closed without asking, the one before stays.
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelNew"))
      tryVerify(function() { return view.agentBox.opened }, 1000)
      verify(!panel.visible)
      view.agentBox.close()
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      verify(ws.chatFor(pid) !== null, "kept till a new one starts")
      // A page deleted for good: its conversation goes too.
      ws.trashPage(pid, false)
      ws.deleteForever(pid)
      compare(ws.chatFor(pid), null)
      verify(String(files.disk[ws.chatsPath()]).indexOf(pid) < 0, "and from the disk")
    }

    // A new page it asked something about before writing (it finished; the
    // page's still empty): closed, the page stays, with its conversation, to
    // answer on.
    function test_15_a_new_page_waiting_for_your_answer() {
      fresh()
      files.agent = "claude"
      var panel = view.agentPanel
      view.openAgent("page")
      tryVerify(function() { return view.agentBox.opened && view.agentBox.known }, 1000)
      wait(150)
      mouseClick(named(win(), "askNew"))
      var old = Object.keys(ws.index.pages)
      view.agentBox.send("A reading list, but ask me my genre first")
      tryVerify(function() { return files.streamed.length === 1 }, 1000)
      var id = Object.keys(ws.index.pages).filter(function(k) { return old.indexOf(k) < 0 })[0]
      tryVerify(function() { return view.page && view.page.id === id }, 2000)
      files.streamFeed(JSON.stringify({ type: "result", subtype: "success", is_error: false, result: "Which genre do you like?", duration_ms: 900, permission_denials: [] }))
      files.streamEnd(0, "")
      tryVerify(function() { return !view.agentBox.visible }, 1000)
      wait(50)
      mouseClick(named(panel, "agentPanelClose"))
      verify(ws.index.pages[id] !== undefined, "it finished: the page stays")
      verify(ws.chatFor(id) !== null, "with its conversation")
      compare(view.page.id, id)
      view.openAgent("auto")
      tryVerify(function() { return panel.visible }, 1000)
      compare(named(panel, "agentPanelAnswer").text, "Which genre do you like?")
      panel.replied("Science fiction")
      tryVerify(function() { return files.streamed.length === 2 }, 1000)
      verify(files.streamed[1].argv.indexOf("--resume") > 0)
      files.streamEnd(0, "")
    }
  }
}
