import QtQuick
import Quickshell
import Quickshell.Io
// (tests/agents/smoke.cjs writes the plugin folder here, as a file: URL, and
// the commands below, made from Service.qml's.)
import "@PLUGIN@" as UN
import "@PLUGIN@/Agent.js" as Agent
import "@PLUGIN@/Scope.js" as Scope

// The real-agent smoke test's Uber Notebook: the real Store, Workspace and
// Api, on notes of its own in a folder made for the run (never yours), and
// the panel's agent run (DocView.runHere: Agent.js's command, input,
// protocol and answers, the same sandbox and folder rules), with every
// question an agent asks answered "Allow once" (and kept, for the report).
// The agent's `omarchy-shell` comes here (smoke.cjs puts one in its folder,
// first on its PATH): uber-notebook-agent, as Service.qml's, scoped
// (Scope.js) to the agent working. smoke.cjs drives it over IPC ("smoke").
ShellRoot {
  id: smoke

  readonly property string notes: Quickshell.env("SMOKE_NOTES") || ""
  readonly property string base: Quickshell.env("SMOKE_RUNTIME") || ""
  readonly property string skillDir: Quickshell.env("SMOKE_SKILL") || ""
  // The model and effort you chose for each agent (smoke.cjs, from your settings).
  readonly property var choices: { try { return JSON.parse(Quickshell.env("SMOKE_CHOICES") || "{}") } catch (e) { return {} } }
  // (Service.skillText's: the skill, for its skill command.)
  function skillText() { return store.readNow(skillDir + "/SKILL.md", 1024 * 1024) || "" }
  readonly property string grokHome: /^\//.test(String(Quickshell.env("GROK_HOME") || "")) ? String(Quickshell.env("GROK_HOME")) : String(Quickshell.env("HOME")) + "/.grok"

  UN.Store { id: store; folder: smoke.notes; active: smoke.notes !== ""; welcome: false }
  UN.Workspace { id: ws; files: store; starter: "templates" }
  UN.Api {
    id: api
    workspace: ws
    files: store
    inbox: ""
    settings: ({})
    agentScope: smoke.scope
    // (What Uber Notebook asks you itself, a file from outside the agent's
    // folder: answered "Allow once", and kept for the report.)
    ui: QtObject {
      function askAgentPermission(req) {
        smoke.status.asks.push("Uber Notebook: " + String(req.text || "") + (req.detail ? ": " + req.detail : ""))
        Qt.callLater(function() { try { req.run([]) } catch (e) { console.warn("smoke: " + e) } })
        return true
      }
    }
  }

  // The agent working, as Service.beginAgentScope makes it; null between runs.
  property var scope: null
  // (As Service.scoped: a file from outside its folders asked about.)
  function scoped(command, args, run) {
    var why = Scope.forCaller(true, smoke.scope, command, args)
    if (why) {
      var outside = Scope.outsideFiles(smoke.scope, command, args)
      if (outside && outside.length && Scope.check(Scope.withApproved(smoke.scope, outside), command, args) === "") {
        return api.askForFiles(smoke.scope, outside, run)
      }
      return JSON.stringify({ ok: false, error: why })
    }
    api.caller = smoke.scope
    try { return run() } finally { api.caller = null }
  }

  // What the run in progress did: { agent, done, code, failure, steps, answer, asks }.
  property var status: ({ done: true })
  property var running: null

  function begin(agent, dir) {
    var pictures = agent === "grok" ? [Agent.grokPictures(grokHome, dir)].filter(function(p) { return p !== "" }) : []
    scope = { agent: Agent.name(agent), id: agent, dir: dir, pictures: pictures, frozen: false, grants: {}, talk: "" }
  }

  // The panel's run (DocView.runHere, its first turn), answered "Allow once".
  function runAgent(agent, pageId, request, dirName) {
    var page = ws.index.pages[pageId]
    if (!page) return "no such page"
    var dir = smoke.base + "/" + dirName
    var st = { agent: agent, done: false, code: 0, failure: "", steps: [], answer: "", asks: [], dir: dir }
    smoke.status = st
    var prompt = Agent.prompt({ request: request, page: { id: pageId, title: page.title || "Untitled" }, scope: "page",
      skill: smoke.skillDir + "/SKILL.md", here: true, dir: dir, agent: agent })
    var session = { id: Agent.newSessionId(agent), resume: false }
    var choice = smoke.choices[agent] || { model: "", effort: "" }
    var where = null
    function finish(code, failure) {
      st.done = true
      st.code = code
      st.failure = String(failure || "")
      smoke.scope = null
      smoke.running = null
      smoke.status = st
    }
    function go() {
      var argv = Agent.command(agent, prompt, choice, session, where)
      if (!argv) { finish(127, "couldn't be started"); return }
      var first = Agent.input(agent, prompt)
      var run = null
      var env = Agent.env(agent)
      env.PATH = dir + "/.smoke-bin:" + String(Quickshell.env("PATH") || "/usr/bin")
      run = store.stream(argv, function(line) {
        Agent.fromLine(agent, line).forEach(function(ev) {
          if (ev.kind === "ask") {
            var a = Agent.askOf(ev.tool, ev.input, ev.title, ev.name)
            // (As the panel: Uber Notebook's own commands, alone, not asked.)
            if (a.action === "shell" && ev.input && Agent.ownCommand(ev.input.command)) { if (run && run.send) run.send(Agent.answerFor(agent, ev, true)); return }
            if (Agent.ownFile(ev.tool, ev.input, dir)) { if (run && run.send) run.send(Agent.answerFor(agent, ev, true)); return }
            st.asks.push(String(a.text || ev.tool || "a tool") + (a.detail ? ": " + String(a.detail).slice(0, 160) : ""))
            if (run && run.send) run.send(Agent.answerFor(agent, ev, true))
            return
          }
          if (ev.kind === "control") { if (run && run.send) run.send(Agent.unsupportedFor(agent, ev.id)); return }
          if (ev.kind === "acp") { if (run && run.send) run.send(Agent.acpSession(dir, session)); return }
          if (ev.kind === "start" && agent === "grok") {
            var sid = ev.session || ""
            if (!sid) { if (run && run.closeInput) run.closeInput(); st.failure = "Grok didn't start its session"; return }
            if (run && run.send) run.send(Agent.acpPrompt(sid, prompt))
          }
          if ((ev.kind === "done" || ev.kind === "failed") && run && run.closeInput) run.closeInput()
          if (ev.kind === "step") st.steps.push(String(ev.text || ""))
          if (ev.kind === "typing") st.answer += String(ev.text || "")
          if (ev.kind === "answer") st.answer = String(ev.text || "")
          if (ev.kind === "failed") st.failure = String(ev.text || "")
        })
      }, function(code, errors) {
        finish(code, st.failure || (code !== 0 ? Agent.failureText(agent, code, errors) : ""))
      }, { cwd: dir, input: first !== "", env: env, maxLine: Agent.streamLimits(where).maxLine, maxBytes: Agent.streamLimits(where).maxBytes, maxErrors: Agent.streamLimits(where).maxErrors })
      smoke.running = run
      if (first && run && run.send) run.send(first)
    }
    begin(agent, dir)
    store.mkdirs([dir, dir + "/.grok", dir + "/.smoke-bin"], function() {
      store.agentPath(agent, function(exe) {
        if (!exe) { finish(127, Agent.name(agent) + " isn't installed where Uber Notebook can find it"); return }
        where = { exe: exe, dir: dir, skill: smoke.skillDir, helper: store.filesHelper || "" }
        // (Its omarchy-shell: this instance, never your shell.)
        var shim = "#!/usr/bin/bash\n# The smoke test's omarchy-shell: its calls go to the smoke test's Uber Notebook.\n"
          + "[[ ${1:-} == -q ]] && shift\nexec /usr/bin/qs ipc --pid " + Quickshell.processId + " call -- \"$@\"\n"
        store.putFile(dir, ".smoke-bin/omarchy-shell", shim, function(ok) {
          store.exec(["/usr/bin/chmod", "755", dir + "/.smoke-bin/omarchy-shell"], function() {
            if (agent === "grok") store.putFile(dir, ".grok/sandbox.toml", Agent.grokSandbox(store.runtimeDir, where.skill), function(ok2) {
              if (ok2) go(); else finish(127, "Grok's sandbox couldn't be set up in its folder")
            })
            else go()
          })
        })
      })
    })
    return "started"
  }

  Timer {
    id: seedTimer
    property string page: ""
    property int tries: 0
    property bool done: false
    interval: 300
    onTriggered: {
      done = false
      var r = {}
      try { r = JSON.parse(api.append(page, smoke.base + "/seed.md")) } catch (e) { r = {} }
      if (r.ok === true) { done = true; return }
      if (--tries > 0) restart()
    }
  }

  IpcHandler {
    target: "smoke"
    function ready(): string { return String(ws.loaded === true) }
    function newPage(title: string): string {
      var p = ws.createPage({ parent: "", title: String(title || "") })
      return p ? p.id : ""
    }
    // What a page starts with (Markdown), before the agent's asked: written,
    // then appended (the Api reads a file in the background, then takes it).
    function seed(page: string, markdown: string): string {
      store.putFile(smoke.base, "seed.md", String(markdown || ""), function() { seedTimer.page = page; seedTimer.tries = 20; seedTimer.restart() })
      return "seeding"
    }
    function seeded(): string { return String(seedTimer.done) }
    function run(agent: string, page: string, request: string, dirName: string): string { return smoke.runAgent(agent, page, request, dirName) }
    function status(): string { return JSON.stringify(smoke.status) }
    function stop(): void { if (smoke.running) smoke.running.stop() }
    function blocks(page: string): string { return api.blocks(page) }
    function read(page: string): string { return api.read(page) }
  }

  // The panel's agent's commands (Service.qml's uber-notebook-agent ones).
  IpcHandler {
    target: "uber-notebook-agent"
@HANDLERS@
  }
}
