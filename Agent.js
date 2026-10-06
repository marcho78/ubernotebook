// Agent.js - asking your agent from Uber Notebook. The agent is Omarchy's default
// coding agent: whichever harness `omarchy default agent` set (Claude Code,
// Codex, OpenCode, Gemini...), launched by Omarchy with a prompt that says
// where you are in your notes and what you'd like. It does the work through
// the uber-notebook skill's commands, so its changes show up in the page as it
// goes, each one a step you can undo.
//
// Shared by the Pages view (app/DocView.qml, app/AgentPop.qml) and
// tests/agent.test.cjs, so keep it plain JavaScript with no QML or Node APIs.
.pragma library
.import "Permissions.js" as Permissions

// The agents Omarchy can have as its default, by the name it keeps for each
// (omarchy-default-agent).
var NAMES = {
  claude: "Claude Code", codex: "Codex", opencode: "OpenCode", gemini: "Gemini", crush: "Crush",
  "cursor-agent": "Cursor CLI", pi: "Pi", omp: "Oh My Pi", copilot: "GitHub Copilot", grok: "Grok",
  openclaw: "OpenClaw", hermes: "Hermes", muse: "Muse Code"
}

function name(agent) {
  var a = String(agent || "").trim()
  return Object.prototype.hasOwnProperty.call(NAMES, a) ? NAMES[a] : a
}

// What it's asked about, for the box: "page", "blocks", "words" (selected
// words in a block), "line" (an empty line, where its writing goes) or
// "new" (a new page, made for it).
function scopeLabel(scope, count) {
  if (scope === "new") return "New page"
  if (scope === "blocks") return count === 1 ? "This block" : count + " blocks"
  if (scope === "words") return "Selected words"
  if (scope === "line") return "This line"
  return "This page"
}

// Ready-made requests for what it's asked about.
function suggestions(scope) {
  if (scope === "new") return ["Plan my week from my calendar", "Notes for my next meeting"]
  if (scope === "words") return ["Rewrite this more clearly", "Turn this into to-dos", "Explain this"]
  if (scope === "blocks") return ["Turn this into to-dos", "Summarize this", "Continue writing from here", "Link related pages"]
  if (scope === "line") return ["Continue writing", "Make a checklist for this page", "Write an outline for this page", "Link related pages"]
  return ["Turn this into to-dos", "Summarize this page", "Continue writing", "Link related pages"]
}

var MAX_REQUEST = 4000
var MAX_WORDS = 1500
// What's said again of a conversation that can't be picked up: its last
// turns, each kept short.
var RECAP_TURNS = 8
var RECAP_CHARS = 600

function clip(text, max) {
  var t = String(text || "").replace(/\r/g, "").trim()
  return t.length > max ? t.slice(0, max) + "\u2026" : t
}

// The prompt the agent starts with. `o`: { request, page: { id, title },
// scope, blocks (ids picked), words (selected), line (the empty line's
// block id), into (for a new page: the page it's in, { id, title }, or none
// for the top of Pages), skill (the uber-notebook skill's SKILL.md),
// earlier (a conversation it can't pick up where it was: [{ request,
// answer }], what was said, for it to go on from), here (in the panel), dir
// (its folder there), agent (who it's for) }. It carries ids, not the
// page's text: the agent reads what it needs (the words you selected are the
// exception, since only you know which they are).
function prompt(o) {
  var page = o.page || {}
  var out = []
  out.push("I'm in Uber Notebook, the notes app in my Omarchy shell, and I'd like your help with my notes.")
  out.push("")
  // A new page, made for it and open: written there, not somewhere else.
  if (o.scope === "new") {
    var into = o.into && o.into.id ? "inside \u201c" + clip(o.into.title || "Untitled", 200) + "\u201d (page id " + o.into.id + ")" : "at the top of Pages"
    out.push("I've made a new, empty page for this (page id " + page.id + "), " + into + ", and it's open in front of me. "
      + "Write it there: give it a title that says what it is (rename), an icon if one fits (icon), and what goes on it (append). "
      + "Don't make another page for it.")
  } else {
    out.push("The page I'm on: \u201c" + clip(page.title || "Untitled", 200) + "\u201d (page id " + page.id + ").")
  }
  if (o.scope === "blocks" && o.blocks && o.blocks.length) {
    out.push("The blocks I picked on it: " + o.blocks.join(", ") + " (with the blocks inside them).")
  } else if (o.scope === "words" && o.blocks && o.blocks.length) {
    out.push("In block " + o.blocks[0] + ", I selected these words:")
    out.push("")
    clip(o.words, MAX_WORDS).split("\n").forEach(function(line) { out.push("> " + line) })
  } else if (o.scope === "line" && o.line) {
    out.push("I'm on an empty line, block " + o.line + ": put what you write there, in its place.")
  }
  out.push("")
  var earlier = (o.earlier || []).filter(function(t) { return t && String(t.request || "").trim() }).slice(-RECAP_TURNS)
  if (earlier.length) {
    out.push("We've talked about this before, in a conversation that can't be picked up where it was; here's what was said:")
    out.push("")
    earlier.forEach(function(t) {
      out.push("- I said: " + clip(t.request, RECAP_CHARS).replace(/\n+/g, " "))
      if (String(t.answer || "").trim()) out.push("  You said: " + clip(t.answer, RECAP_CHARS).replace(/\n+/g, " "))
    })
    out.push("")
  }
  out.push("What I'd like" + (earlier.length ? " now" : "") + ": " + clip(o.request, MAX_REQUEST))
  out.push("")
  if (o.here) {
    out.push("You're working inside Uber Notebook, with no terminal: what you write shows in a small panel on the page, "
      + "so keep it short, and end by saying what you changed in a sentence or two.")
    out.push("Here Uber Notebook's commands go under their panel name: run each as omarchy-shell uber-notebook-agent <command> ... "
      + "(the skill's omarchy-shell uber-notebook <command> ..., the same commands and arguments), and only so: if one's refused, "
      + "say why rather than trying it another way.")
    if (o.dir) out.push("Here only Uber Notebook's commands run (no mktemp, cat or rm): write the Markdown a command takes with your "
      + "file-writing tool, as a file in " + o.dir + " (your working folder), and give the command that file's full path.")
    // (Codex's sandbox has no network here, which keeps its commands from
    // the shell's socket too: they go outside it, each reviewed by Codex.)
    if (o.agent === "codex") out.push("Your sandbox has no network here, and that keeps Uber Notebook's commands from reaching it "
      + "(they'd say omarchy-shell is not running): run each omarchy-shell uber-notebook-agent command with escalated "
      + "permissions, outside the sandbox.")
    out.push("")
  }
  out.push("Use the uber-notebook skill: it explains the omarchy-shell uber-notebook commands that read and change my notes "
    + "(blocks, read, replace, insertAfter, append, add, find). If your harness has no skill mechanism, "
    + "read the skill file directly and follow it instead:")
  out.push("")
  out.push("  " + o.skill)
  out.push("")
  out.push("Read and change my notes only through those commands: don't open the files my notes are kept in, or Uber Notebook's own "
    + "files and code (the skill says what its commands and its Markdown can do). Change only what my request is about. "
    + "When you're done, tell me what you changed.")
  return out.join("\n")
}

// What you say back to it, in the same conversation (it has the rest): your
// words, after where you are now when that's changed since it last heard
// (`moved`: another page; `scope` "blocks" or "words": what you've picked
// since; "line": the empty line its writing goes on). `o`: { reply, page:
// { id, title }, moved, scope, blocks, words, line }.
function reply(o) {
  var page = o.page || {}
  var out = []
  if (o.moved && page.id) out.push("I'm on another page now: \u201c" + clip(page.title || "Untitled", 200) + "\u201d (page id " + page.id + ").")
  if (o.scope === "blocks" && o.blocks && o.blocks.length) {
    out.push("The blocks I've picked: " + o.blocks.join(", ") + " (with the blocks inside them).")
  } else if (o.scope === "words" && o.blocks && o.blocks.length) {
    out.push("In block " + o.blocks[0] + ", I've selected these words:")
    out.push("")
    clip(o.words, MAX_WORDS).split("\n").forEach(function(line) { out.push("> " + line) })
  } else if (o.scope === "line" && o.line) {
    out.push("I'm on an empty line, block " + o.line + ": put what you write there, in its place.")
  }
  if (out.length) out.push("")
  out.push(clip(o.reply, MAX_REQUEST))
  return out.join("\n")
}

// The agents Omarchy offers, from its menu file (omarchy-menu.jsonc, where
// each is "setup.default.agent.<name>" with its label): [{ name, label }].
// Omarchy keeps that list, so a new agent shows up here when it adds one.
function menuAgents(text) {
  var out = []
  var seen = {}
  var re = /"setup\.default\.agent\.([a-z0-9][a-z0-9-]{0,30})"\s*:\s*\{([^}]*)\}/g
  var m
  while ((m = re.exec(String(text || ""))) !== null) {
    if (seen[m[1]]) continue
    seen[m[1]] = true
    var label = /"label"\s*:\s*"([^"]{1,40})"/.exec(m[2])
    out.push({ name: m[1], label: label ? label[1] : name(m[1]) })
  }
  return out
}

// ---- working here, without a terminal ---------------------------------------------------------
//
// Claude Code, Grok and Codex can work without their terminal and say each
// step as a line of JSON as they go: what they're doing, their answer (as
// it's written, for Claude Code and Grok), how it ended. Uber Notebook shows
// those in a panel on the page (app/AgentPanel.qml). Each is started with
// the permission mode Omarchy starts it with (omarchy-agent); the other
// agents open in a terminal, as Omarchy starts them.

var HERE = ["claude", "grok", "codex"]
function runsHere(agent) { return HERE.indexOf(String(agent || "")) >= 0 }

// The model and effort you chose for an agent ("" for each: as the agent
// is set up), as they may go on a command line.
function cleanChoice(v) {
  var t = String(v || "").trim()
  return /^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$/.test(t) ? t : ""
}

// The command, the agent run by its full path (`where`: { exe, dir, skill }:
// the program, found where it's installed and checked, its working folder,
// and Uber Notebook's skill folder). What it does beyond the panel's needs
// (Uber Notebook's commands, files in its own folder) is asked of you:
//   Claude Code: print mode, stream-json on its input and output (its
//     request, and your answers: input, answer). Your own setup as in your
//     terminal (your plugins and MCP servers, CLAUDE.md, your allow rules);
//     the tools in CLAUDE_TOOLS, and anything beyond its rules asked
//     (--permission-mode manual, whatever your settings' default mode);
//     the skill's folder read without asking;
//   Grok: over ACP, its agent protocol (acpInit...), in its sandbox (env());
//   Codex: exec --json, --approve-for-me (its own folder writable, no
//     network, the rest reviewed for it), outside a git repository.
// With `choice` ({ model, effort }), the model and effort you chose. With
// `session` ({ id, resume }), the conversation it's in: Claude Code starts
// its with the id given (--session-id) and goes on with it (--resume);
// Grok's and Codex's name their own. Codex's prompt is last, never read as
// an option. null without a program or a folder.
// The tools Claude Code has in the panel (beyond its rules, it asks for
// each, and you're asked in the panel; MCP tools, yours, as well).
var CLAUDE_TOOLS = "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch"

// What it may print: a line at most LINE_MAX bytes, OUTPUT_MAX in all, as
// it prints them (through the files helper, counted there before they're
// made ASCII); what reaches the panel then takes up to six times the room.
var LINE_MAX = 4 * 1024 * 1024
var OUTPUT_MAX = 64 * 1024 * 1024
function streamLimits(where) {
  var w = where || {}
  var helper = /^\/[^\u0000-\u001f]{1,4000}$/.test(String(w.helper || ""))
  return helper ? { maxLine: 6 * LINE_MAX + 1024, maxBytes: 6 * OUTPUT_MAX + 1024 * 1024, maxErrors: OUTPUT_MAX } : { maxLine: LINE_MAX, maxBytes: OUTPUT_MAX, maxErrors: OUTPUT_MAX }
}

function command(agent, prompt, choice, session, where) {
  var w = where || {}
  var exe = String(w.exe || "")
  var dir = String(w.dir || "")
  if (!/^\/[^\u0000-\u001f]{1,4000}$/.test(exe) || !/^\/[^\u0000-\u001f*?\[\]]{1,4000}$/.test(dir)) return null
  var skill = /^\/[^\u0000-\u001f*?\[\]]{1,4000}$/.test(String(w.skill || "")) ? String(w.skill) : ""
  // (What it prints, through the files helper's ascii-lines, when there is
  // one: each JSON line again, ASCII only, so no character is cut in two on
  // its way here, the input of a tool it asks to use included.)
  var helper = /^\/[^\u0000-\u001f]{1,4000}$/.test(String(w.helper || "")) ? String(w.helper) : ""
  function filtered(input) {
    return helper ? ["/usr/bin/bash", "-c", "h=$1; n=$2; t=$3; shift 3; set -o pipefail; \"$@\"" + input + " | /usr/bin/python3 -I -S \"$h\" ascii-lines \"$n\" \"$t\"", "uber-notebook-agent", helper, String(LINE_MAX), String(OUTPUT_MAX)]
      : ["/usr/bin/bash", "-c", "exec \"$@\"" + input, "uber-notebook-agent"]
  }
  var head = filtered(" < /dev/null")
  var p = String(prompt)
  var c = choice || {}
  var model = cleanChoice(c.model)
  var effort = cleanChoice(c.effort)
  var s = session && isSessionId(session.id) ? session : null
  // (Claude Code reads its request, and your answers to what it asks, on its
  // input: input(), answer(). Nothing of yours is in its command line.)
  // (Your settings, not its folder's: what's in a project's .claude there
  // could have been put there by an agent.)
  if (agent === "claude") return filtered("").concat([exe, "-p", "--input-format", "stream-json",
    "--output-format", "stream-json", "--verbose", "--include-partial-messages", "--setting-sources", "user", "--tools", CLAUDE_TOOLS]
    .concat(skill ? ["--add-dir", skill] : [], ["--permission-mode", "manual", "--permission-prompt-tool", "stdio",
      "--allowedTools", "Bash(omarchy-shell uber-notebook-agent *)", "Edit(/" + dir + "/**)", "Write(/" + dir + "/**)"])
    .concat(s ? [s.resume ? "--resume" : "--session-id", s.id] : [], model ? ["--model", model] : [], effort ? ["--effort", effort] : []))
  // (Grok works over ACP, its agent protocol, on its input and output:
  // acpInit, acpSession, acpPrompt, fromAcp, reply. Its sandbox: env().)
  if (agent === "grok") return filtered("").concat([exe, "agent"], model ? ["-m", model] : [], effort ? ["--reasoning-effort", effort] : [], ["stdio"])
  if (agent === "codex") {
    var opts = ["--json", "--approve-for-me", "--skip-git-repo-check", "-c", "sandbox_workspace_write.network_access=false"]
      .concat(model ? ["-m", model] : [], effort ? ["-c", "model_reasoning_effort=\"" + effort + "\""] : [])
    if (s && s.resume) return head.concat([exe, "exec"], opts, ["resume", "--", s.id, p])
    return head.concat([exe, "exec"], opts, ["--", p])
  }
  return null
}

// What an agent is told first on its input, when it works there (Claude
// Code, stream-json: its request; Grok, ACP: hello, and the rest follows,
// DocView.runHere): so what it asks can be answered as it works. A line, or
// "" (Codex takes its request in its command line).
function input(agent, prompt) {
  if (agent === "grok") return acpInit()
  if (agent !== "claude") return ""
  return JSON.stringify({ type: "user", message: { role: "user", content: String(prompt) } }) + "\n"
}
// What's in its environment besides yours (Grok: its sandbox, which its agent
// mode takes only from there).
function env(agent) {
  return agent === "grok" ? { GROK_SANDBOX: GROK_PROFILE } : {}
}

// ---- Grok, over ACP (JSON-RPC, a message a line) ----
// Hello (1), then its session, new or gone on with (2: with Always-approve,
// yours or not, off: it asks), then the request (3).
function acpLine(id, method, params) { return JSON.stringify({ jsonrpc: "2.0", id: id, method: method, params: params }) + "\n" }
function acpInit() {
  return acpLine(1, "initialize", { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: false, writeTextFile: false }, terminal: false } })
}
function acpSession(dir, session) {
  var meta = { yoloMode: false }
  return session && session.resume && isSessionId(session.id)
    ? acpLine(2, "session/load", { sessionId: session.id, cwd: String(dir), mcpServers: [], _meta: meta })
    : acpLine(2, "session/new", { cwd: String(dir), mcpServers: [], _meta: meta })
}
function acpPrompt(sessionId, text) {
  return acpLine(3, "session/prompt", { sessionId: String(sessionId), prompt: [{ type: "text", text: String(text) }] })
}
// What it says over ACP, as the panel's events (fromLine's), and these of its
// own: { kind: "acp", stage: "ready" } (said hello: its session next),
// { kind: "start", session } (its session: the request next).
function fromAcp(line) {
  var e = parse(line)
  if (!e || e.jsonrpc !== "2.0") return []
  if (e.id !== undefined && e.method === undefined) {
    if (e.error) return [{ kind: "failed", text: String((e.error && e.error.message) || "It stopped before it finished.").slice(0, 400) }]
    var r = e.result && typeof e.result === "object" ? e.result : {}
    if (e.id === 1) return [{ kind: "acp", stage: "ready" }]
    if (e.id === 2) return [{ kind: "start", model: "", session: isSessionId(r.sessionId) ? String(r.sessionId) : "" }]
    // (Its turn over: done, what it said its answer; after a No, it waits
    // to be told what to do instead: answer it in the panel.)
    if (e.id === 3) {
      if (r.stopReason === "refusal") return [{ kind: "failed", text: "It wouldn't do that." }]
      return [{ kind: "done", text: "", seconds: 0, denied: [] }]
    }
    return []
  }
  if (e.method === "session/request_permission" && e.id !== undefined) {
    var prm = e.params && typeof e.params === "object" ? e.params : {}
    var tc = prm.toolCall && typeof prm.toolCall === "object" ? prm.toolCall : {}
    var raw = tc.rawInput && typeof tc.rawInput === "object" ? tc.rawInput : {}
    // (What it is, by the kind Grok gives it; its input's "variant" only names it.)
    var kind = String(tc.kind || "")
    return [{ kind: "ask", id: e.id, tool: ACP_TOOLS.hasOwnProperty(kind) ? ACP_TOOLS[kind] : "", name: String(raw.variant || kind || ""),
      input: raw, title: String(tc.title || ""), options: Array.isArray(prm.options) ? prm.options : [] }]
  }
  if (e.method !== undefined && e.id !== undefined) return [{ kind: "control", id: e.id }]
  if (e.method === "session/update" && e.params && e.params.update) {
    var u = e.params.update
    if (u.sessionUpdate === "agent_message_chunk" && u.content && u.content.type === "text") return [{ kind: "typing", text: String(u.content.text || ""), fresh: false }]
    if (u.sessionUpdate === "tool_call") {
      var input = u.rawInput && typeof u.rawInput === "object" ? u.rawInput : {}
      var name = input.command !== undefined ? "Bash" : input.url !== undefined ? "WebFetch" : String(u.title || "")
      return stepText(name, input).split("\n").map(function(t) { return { kind: "step", text: t } })
    }
  }
  return []
}

// Your answer to what it asked: a line for its input (Claude Code's
// control_response; Grok's ACP result, the option that says it).
function answerFor(agent, ev, allow) {
  if (agent === "grok") {
    var want = allow ? "allow_once" : "reject_once"
    var opt = (ev.options || []).filter(function(o) { return o && o.kind === want })[0]
    return JSON.stringify({ jsonrpc: "2.0", id: ev.id, result: { outcome: opt ? { outcome: "selected", optionId: String(opt.optionId) } : { outcome: "cancelled" } } }) + "\n"
  }
  return answer(ev.id, allow, ev.input)
}
// To anything else it asks Uber Notebook, which it doesn't do.
function unsupportedFor(agent, id) {
  if (agent === "grok") return JSON.stringify({ jsonrpc: "2.0", id: id, error: { code: -32601, message: "Uber Notebook doesn't do that" } }) + "\n"
  return unsupported(id)
}
// Your answer to what it asked (Claude Code's can_use_tool): a line for its
// input. And to anything else it asks Uber Notebook, which it doesn't do.
function answer(id, allow, toolInput, message) {
  var response = allow ? { behavior: "allow", updatedInput: toolInput && typeof toolInput === "object" ? toolInput : {} }
    : { behavior: "deny", message: String(message || "The user said no.") }
  return JSON.stringify({ type: "control_response", response: { subtype: "success", request_id: String(id), response: response } }) + "\n"
}
function unsupported(id) {
  return JSON.stringify({ type: "control_response", response: { subtype: "error", request_id: String(id), error: "Uber Notebook doesn't do that" } }) + "\n"
}

// Text it shows you in a question, every character as it is: what can't be
// seen, turns text around (control and direction marks), or looks like
// nothing but isn't a plain space (a no-break space, ideographic and
// braille blanks, Hangul fillers), written out as \u{...}; tabs kept; each
// line break shown (⏎), and a run of more than two blank lines one line
// that says how many, so what comes after them is in sight.
function visible(text) {
  var s = String(text || "").replace(/[\u0000-\u0008\u000b-\u001f\u007f-\u00a0\u00ad\u034f\u061c\u115f\u1160\u1680\u17b4\u17b5\u180e\u2000-\u200f\u2028-\u202f\u205f-\u206f\u2800\u3000\u3164\ufeff\uffa0\ufff9-\ufffb]/g, function(c) {
    return "\\u{" + c.charCodeAt(0).toString(16) + "}"
  })
  var lines = s.split("\n")
  var out = []
  for (var i = 0; i < lines.length; i++) {
    var j = i
    while (j < lines.length - 1 && /^[ \t]*$/.test(lines[j])) j++
    if (j - i > 2) { out.push("\u22ef " + (j - i) + " blank lines \u22ef\u23ce"); i = j - 1; continue }
    out.push(lines[i] + (i < lines.length - 1 ? "\u23ce" : ""))
  }
  return out.join("\n")
}
// How many lines it has (a question says so when it's more than one).
function lineCount(text) { return String(text || "").split("\n").length }

// Grok's tools, by the kind it gives each (ACP's, set by Grok, not by what
// a tool's given): a command, reading a site, reading or changing a file.
var ACP_TOOLS = { execute: "Bash", fetch: "WebFetch", read: "Read", search: "Grep", edit: "Edit", "delete": "Edit", move: "Edit" }
var READ_TOOLS = ["Read", "Glob", "Grep"]
var CHANGE_TOOLS = ["Write", "Edit", "MultiEdit", "NotebookEdit"]
// All a tool was given, as text (for a question), within reason.
function inputText(i) {
  var s = ""
  try { s = JSON.stringify(i, null, 1) } catch (e) { s = "" }
  if (!s || s === "{}") return ""
  return s.length > 20000 ? s.slice(0, 20000) + "\n\u2026 (" + (s.length - 20000) + " more characters)" : s
}

// What it asks to do (Claude Code's can_use_tool, Grok's ACP), in words for
// the panel, and what it may be allowed for: { action, target, text,
// detail, always, grant, conversation }: `detail` the whole of it, as it is
// (the panel shows it with visible()); Always (`always`, "" for none) keeps
// it for good (Permissions.js); `grant` and `conversation`, for this
// conversation. What it is comes from the tool (`tool`: Claude Code's name
// for it, or Grok's kind, ACP_TOOLS), never from what it's given: a
// connector's tool given a "command" is still that tool. A command is asked
// once, or for the conversation (Allow shell for this conversation): never
// for good by its program, which can run anything its folder says (git,
// make...); Settings can let an agent run any. A tool it doesn't know
// (`name`, Grok's, only a name): named, all it was given shown, once only.
function askOf(tool, toolInput, title, name) {
  var i = toolInput && typeof toolInput === "object" ? toolInput : {}
  var t = String(tool || "")
  if (/^mcp__[A-Za-z0-9_-]+$/.test(t)) {
    var parts = t.split("__")
    return { action: "tool", target: t, text: "use " + (parts[1] || "a connector") + "\u2019s " + (parts.slice(2).join("__") || "tool"), detail: inputText(i), always: "Always for this tool" }
  }
  // (A site's address and a search, whole in `detail`: what's past the
  // first words of either goes to the site too.)
  // (One with no address: asked as a tool, all it was given shown.)
  if (t === "WebFetch" && String(i.url || "") !== "") {
    var url = String(i.url || "")
    var host = Permissions.hostOf(url)
    return host ? { action: "contact", target: host, text: "contact " + host + ", to read " + clip(url, 200), detail: url, always: "Always for " + host }
      : { action: "", target: "", text: "read " + clip(url, 200), detail: url, always: "" }
  }
  if (t === "WebSearch") return { action: "search", target: "web", text: "search the web for \u201c" + clip(String(i.query || ""), 200) + "\u201d", detail: String(i.query || ""), always: "Always let it search" }
  if (t === "Bash") {
    return { action: "shell", target: "any", text: "run a command", detail: typeof i.command === "string" ? i.command : String(title || inputText(i)), always: "",
      grant: "shell", conversation: "Allow shell for this conversation" }
  }
  if (READ_TOOLS.indexOf(t) >= 0 || CHANGE_TOOLS.indexOf(t) >= 0) {
    var file = String(i.file_path || i.notebook_path || i.path || i.pattern || "")
    return { action: "", target: "", text: (READ_TOOLS.indexOf(t) >= 0 ? "read" : "change") + " a file (" + t + ")", detail: file || String(title || "") || inputText(i), always: "" }
  }
  var called = clip(t || String(name || "") || "a tool", 80)
  var said = [String(title || ""), inputText(i)].filter(function(x) { return x !== "" }).join("\n")
  return { action: "", target: "", text: "use \u201c" + visible(called).replace(/\n/g, " ") + "\u201d", detail: said, always: "" }
}

// Grok's sandbox for the panel, kept in its working folder's
// .grok/sandbox.toml: strict (it reads its folder and the system's, writes
// there and in temp), and it may read where the shell's socket is
// (`runtime`: $XDG_RUNTIME_DIR), so Uber Notebook's commands reach it, and
// the uber-notebook skill's folder (`skill`), so it can read the skill the
// prompt names (as Claude Code's --add-dir); nothing else of yours.
var GROK_PROFILE = "uber-notebook"
function grokSandbox(runtime, skill) {
  var safe = /^\/[A-Za-z0-9._\/-]{1,400}$/
  var r = String(runtime || "")
  if (!safe.test(r)) return ""
  var reads = [r + "/quickshell"]
  var k = String(skill || "")
  if (safe.test(k) && !/(^|\/)\.\.?(\/|$)/.test(k)) reads.push(k)
  return "# Uber Notebook's panel: Grok reads only its own folder, the system's and\n"
    + "# Uber Notebook's skill, writes only there and in temp, and reaches Uber\n"
    + "# Notebook's commands.\n"
    + "[profiles." + GROK_PROFILE + "]\n"
    + "extends = \"strict\"\n"
    + "restrict_network = false\n"
    + "read_only = [" + reads.map(function(p) { return "\"" + p + "\"" }).join(", ") + "]\n"
}

// Where it may be installed: an agent's program found on the shell's PATH
// (`path`), by a script that takes it only if, links resolved, it's a
// regular, executable file owned by you or root that no one else can change,
// in a folder no one else can change, and the folder on the PATH it's in is
// one no one else can change either: lines of "<name>\t<full path>", the
// path as found on the PATH, not where its links lead (a version manager's
// shim, mise's or asdf's, is a link to the manager itself, which tells
// which program to run by the name it's run by). Run with
// bash -c AGENTS_SCRIPT uber-notebook-agents <path> <names...>.
var AGENTS_SCRIPT = "uid=$(/usr/bin/id -u); IFS=: read -r -a dirs <<< \"$1\"; shift; "
  + "mine() { local o m; read -r o m < <(/usr/bin/stat -c '%u %a' -- \"$1\") || return 1; { [ \"$o\" = \"$uid\" ] || [ \"$o\" = 0 ]; } && (( (8#$m & 022) == 0 )); }; "
  + "for a in \"$@\"; do for d in \"${dirs[@]}\"; do case \"$d\" in /*) ;; *) continue ;; esac; "
  + "f=$(/usr/bin/readlink -e -- \"$d/$a\" 2>/dev/null) || continue; [ -f \"$f\" ] && [ -x \"$f\" ] || continue; "
  + "mine \"$f\" && mine \"$(/usr/bin/dirname -- \"$f\")\" && mine \"$d\" || continue; printf '%s\\t%s\\n' \"$a\" \"$d/$a\"; break; done; done; exit 0"

// What AGENTS_SCRIPT printed: { name: full path }.
function agentPaths(output) {
  var out = {}
  String(output || "").split("\n").forEach(function(line) {
    var m = /^([a-z][a-z0-9-]{0,30})\t(\/[^\t\u0000-\u001f]{1,4000})$/.exec(line)
    if (m && !out[m[1]]) out[m[1]] = m[2]
  })
  return out
}

// ---- a conversation: going on with it ------------------------------------------------------

// What an agent says when the conversation it's asked to go on with isn't
// there any more (cleared out, another computer): Claude Code's, Codex's,
// Grok's. Then it's started anew with what was said (prompt's `earlier`).
function lostSession(text) {
  return /No conversation found with session ID|no rollout found for thread id|not found locally|Failed to restore session|session[^\n]{0,80}not found/i.test(String(text || ""))
}

// The conversations kept with their pages (Pages/chats.json), so one can be
// gone back to: { pageId: { agent, session, page (the page it last heard
// about), picked, updated, turns: [{ request, steps, answer, status,
// failure }] } }. Only what's checked here is kept: an agent that works
// here, a session that's an id, the last MAX_CHAT_TURNS turns (each kept
// short), the MAX_CHATS last talked in.
var MAX_CHATS = 200
var MAX_CHAT_TURNS = 40
function cleanChat(c) {
  if (!c || typeof c !== "object" || !runsHere(c.agent)) return null
  var turns = (Array.isArray(c.turns) ? c.turns : []).map(cleanTurn).filter(function(t) { return t !== null }).slice(-MAX_CHAT_TURNS)
  if (!turns.length) return null
  return { agent: String(c.agent), session: isSessionId(c.session) ? String(c.session) : "", page: cleanId(c.page), picked: clip(c.picked, 2000),
    folder: isConversationFolder(c.folder) ? String(c.folder) : "",
    updated: /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(String(c.updated || "")) ? String(c.updated) : "", turns: turns }
}
function cleanTurn(t) {
  if (!t || typeof t !== "object" || !String(t.request || "").trim()) return null
  var status = ["done", "stopped", "failed"].indexOf(t.status) >= 0 ? t.status : "stopped"
  return { request: clip(t.request, MAX_REQUEST), steps: (Array.isArray(t.steps) ? t.steps : []).slice(-40).map(function(x) { return clip(x, 200) }),
    answer: clip(t.answer, 8000), status: status, failure: status === "failed" ? clip(t.failure, 400) : "" }
}
function cleanId(id) { return /^[A-Za-z0-9_-]{1,64}$/.test(String(id || "")) ? String(id) : "" }
// A conversation's folder of its own (in Uber Notebook's agent folder): "c-"
// and 12 hex.
function isConversationFolder(name) { return /^c-[0-9a-f]{12}$/.test(String(name || "")) }
function cleanChats(raw) {
  var all = raw && typeof raw === "object" && raw.chats && typeof raw.chats === "object" ? raw.chats : {}
  var list = []
  Object.keys(all).forEach(function(id) {
    var c = cleanId(id) ? cleanChat(all[id]) : null
    if (c) list.push({ id: id, chat: c })
  })
  list.sort(function(a, b) { return a.chat.updated < b.chat.updated ? 1 : a.chat.updated > b.chat.updated ? -1 : 0 })
  var out = {}
  list.slice(0, MAX_CHATS).forEach(function(e) { out[e.id] = e.chat })
  return out
}
// What the page's AI button says of its conversation.
function chatTip(chat) {
  if (!chat) return ""
  var n = chat.turns.length
  return "Your conversation with " + name(chat.agent) + " (" + n + (n === 1 ? " message" : " messages") + ")"
}

// A conversation's id, as the agents write them (a UUID).
function isSessionId(id) { return /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(String(id || "")) }
// A new one, for Claude Code or Grok to start with (Codex names its own: "").
// `random`: 0 <= n < 1 (Math.random's).
function newSessionId(agent, random) {
  // (Codex and Grok name their own: their first answer says.)
  if (agent === "codex" || agent === "grok") return ""
  var r = typeof random === "function" ? random : Math.random
  var hex = "0123456789abcdef"
  var out = ""
  for (var i = 0; i < 36; i++) {
    if (i === 8 || i === 13 || i === 18 || i === 23) out += "-"
    else if (i === 14) out += "4"
    else if (i === 19) out += hex.charAt(8 + Math.floor(r() * 4))
    else out += hex.charAt(Math.floor(r() * 16))
  }
  return out
}

// ---- models and effort -------------------------------------------------------------------------
//
// What each agent can work with: Grok's and Codex's lists of models (the ones
// they keep, ~/.grok/models_cache.json and ~/.codex/models_cache.json), each
// with the efforts it takes; Claude Code's names for its latest models
// (claude --help) and its efforts. [{ id, name, description, efforts:
// [{ id, label }], effort (its default) }].

var EFFORT_LABELS = { minimal: "Minimal", low: "Low", medium: "Medium", high: "High", xhigh: "Extra high", max: "Max", ultra: "Ultra" }
function effortLabel(id) { return EFFORT_LABELS[id] || String(id || "") }
function effortList(ids) { return ids.map(function(id) { return { id: id, label: effortLabel(id) } }) }

var CLAUDE_EFFORTS = ["low", "medium", "high", "xhigh", "max"]
var CLAUDE_MODELS = [
  { id: "fable", name: "Fable", description: "Claude's latest Fable model" },
  { id: "opus", name: "Opus", description: "Claude's latest Opus model" },
  { id: "sonnet", name: "Sonnet", description: "Claude's latest Sonnet model" }
]

function models(agent, cacheText) {
  if (agent === "claude") return CLAUDE_MODELS.map(function(m) { return { id: m.id, name: m.name, description: m.description, efforts: effortList(CLAUDE_EFFORTS), effort: "" } })
  var data = null
  try { data = JSON.parse(String(cacheText || "")) } catch (x) { return [] }
  if (!data || typeof data !== "object") return []
  if (agent === "grok") {
    var g = data.models && typeof data.models === "object" ? data.models : {}
    return Object.keys(g).map(function(k) { return g[k] && g[k].info ? g[k].info : null }).filter(function(i) { return i && cleanChoice(i.id) && !i.hidden }).map(function(i) {
      var ef = (Array.isArray(i.reasoning_efforts) ? i.reasoning_efforts : []).map(function(e) { return cleanChoice(e && (e.value || e.id)) }).filter(function(e) { return e })
      return { id: i.id, name: String(i.name || i.id), description: String(i.description || ""), efforts: effortList(ef), effort: cleanChoice(i.reasoning_effort) }
    })
  }
  if (agent === "codex") {
    var list = Array.isArray(data.models) ? data.models : []
    return list.filter(function(m) { return m && cleanChoice(m.slug) && m.visibility !== "hide" })
      .sort(function(a, b) { return (Number(a.priority) || 0) - (Number(b.priority) || 0) })
      .map(function(m) {
        var ef = (Array.isArray(m.supported_reasoning_levels) ? m.supported_reasoning_levels : []).map(function(e) { return cleanChoice(e && e.effort) }).filter(function(e) { return e })
        return { id: m.slug, name: String(m.display_name || m.slug), description: String(m.description || ""), efforts: effortList(ef), effort: cleanChoice(m.default_reasoning_level) }
      })
  }
  return []
}

// The efforts to offer: the chosen model's; with no model chosen (as the
// agent is set up), the ones every model takes.
function efforts(list, model) {
  var l = list || []
  var m = l.filter(function(x) { return x.id === model })[0]
  if (m) return m.efforts
  if (!l.length) return []
  var common = l[0].efforts.map(function(e) { return e.id }).filter(function(id) { return l.every(function(x) { return x.efforts.some(function(e) { return e.id === id }) }) })
  return effortList(common)
}

// What the box and the panel say about a choice: "Grok 4.7 Fast · Low", or
// "Default" for as the agent is set up.
function choiceLabel(list, model, effort) {
  var m = (list || []).filter(function(x) { return x.id === model })[0]
  var name = m ? m.name : model ? model : "Default model"
  return effort ? name + " \u00b7 " + effortLabel(effort) : name
}

// What a step is, said simply.
var STEP_WORDS = {
  help: "Reading Uber Notebook's commands", read: "Reading the page", blocks: "Reading the page",
  find: "Searching your notes", list: "Looking through your pages", library: "Looking through the Library",
  tags: "Looking at your tags", tagged: "Looking at a tag", contacts: "Looking in People", contact: "Looking in People",
  events: "Looking at your calendar", templates: "Looking at your templates", projects: "Looking at your projects",
  notebooks: "Looking at your notebooks", notebook: "Reading a notebook", readNotebook: "Reading a notebook",
  history: "Looking at the page's history", version: "Reading an earlier version",
  add: "Making a page", addTo: "Making a page", fromTemplate: "Making a page from a template",
  append: "Writing on the page", insertAfter: "Writing on the page", replace: "Rewriting part of the page",
  check: "Ticking a to-do", color: "Coloring a block", board: "Changing a board", removeBlock: "Taking a block off",
  rename: "Renaming a page", move: "Moving a page", icon: "Changing a page's icon", cover: "Changing a page's cover",
  trash: "Putting a page in the trash", restore: "Restoring a page", duplicate: "Copying a page",
  addEvent: "Adding to your calendar", editEvent: "Changing your calendar", removeEvent: "Changing your calendar",
  addContact: "Adding to People", editContact: "Changing People", tagColor: "Coloring a tag", renameTag: "Renaming a tag",
  project: "Changing a project", archive: "Archiving a page", attach: "Putting a file on the page",
  bookmark: "Adding a bookmark", addToNotebook: "Writing in a notebook", restoreVersion: "Putting back an earlier version"
}
function baseName(path) { var p = String(path || "").split("/"); return p[p.length - 1] || "a file" }
// A command's steps: each kind of change a script makes (in order, once
// each), or what the command is.
function commandSteps(cmd) {
  var c = String(cmd || "")
  var out = []
  var re = /omarchy-shell\s+uber-notebook(?:-agent)?\s+([A-Za-z]+)/g
  var m
  while ((m = re.exec(c)) !== null) {
    var t = STEP_WORDS[m[1]] || "Running " + m[1]
    if (out.indexOf(t) < 0) out.push(t)
  }
  if (out.length) return out
  // (Codex reads the skill with a command.)
  if (/uber-notebook\/SKILL\.md/.test(c)) return ["Reading the uber-notebook skill"]
  return ["Running a command"]
}
function commandStep(cmd) { return commandSteps(cmd)[0] }
// A tool's step: Claude Code's tools (Bash, Read...) and Grok's
// (run_terminal_command, read_file...).
function stepText(name, input) {
  var i = input && typeof input === "object" ? input : {}
  var file = i.file_path || i.target_file || i.path || ""
  if (name === "Bash" || name === "run_terminal_command") return commandSteps(i.command || i.cmd).join("\n")
  if (name === "Skill") return "Reading the uber-notebook skill"
  if (name === "Read" || name === "read_file") return /SKILL\.md$/.test(String(file)) ? "Reading the uber-notebook skill" : "Reading " + baseName(file)
  if (name === "Write" || name === "Edit" || name === "search_replace" || name === "write_file") return "Writing " + baseName(file)
  if (name === "Glob" || name === "Grep" || name === "grep" || name === "list_dir") return "Searching files"
  if (name === "TodoWrite" || name === "todo_write") return "Planning"
  if (name === "WebFetch") { var h = Permissions.hostOf(i.url); return h ? "Reading " + h : "Reading a web page" }
  if (name === "WebSearch") return "Searching the web"
  return String(name || "A step")
}

// One line of what an agent says, as what the panel shows: a list of
//   { kind: "start", model, session }  (session: its conversation's id)
//   { kind: "step", text }             a step it's taking
//   { kind: "typing", text, fresh }    more of its answer (fresh: a new one starts)
//   { kind: "answer", text }           what it said, whole
//   { kind: "done", text, seconds, denied: [tools it wasn't allowed] }
//   { kind: "failed", text }
//   { kind: "ask", id, tool, input }   it asks to use a tool (answer)
//   { kind: "control", id }            it asks something else (unsupported)
function fromLine(agent, line) {
  return agent === "codex" ? fromCodex(line) : agent === "grok" ? fromAcp(line) : fromMessages(line)
}

function parse(line) {
  var e = null
  try { e = JSON.parse(String(line || "")) } catch (x) { return null }
  return e && typeof e === "object" ? e : null
}

// Claude Code's lines (stream-json), and Grok's (streaming-messages-json),
// which are the same: Anthropic's message stream, then a result.
function fromMessages(line) {
  var e = parse(line)
  if (!e) return []
  // (Claude Code asking for a tool beyond its rules: you're asked.)
  if (e.type === "control_request" && typeof e.request_id === "string" && e.request && typeof e.request === "object") {
    if (e.request.subtype === "can_use_tool") return [{ kind: "ask", id: e.request_id, tool: String(e.request.tool_name || ""),
      input: e.request.input && typeof e.request.input === "object" ? e.request.input : {} }]
    return [{ kind: "control", id: e.request_id }]
  }
  if (e.type === "system" && e.subtype === "init") return [{ kind: "start", model: String(e.model || ""), session: isSessionId(e.session_id) ? String(e.session_id) : "" }]
  if (e.type === "stream_event" && e.event) {
    var ev = e.event
    if (ev.type === "content_block_start" && ev.content_block && ev.content_block.type === "text") return [{ kind: "typing", text: String(ev.content_block.text || ""), fresh: true }]
    if (ev.type === "content_block_delta" && ev.delta && ev.delta.type === "text_delta") return [{ kind: "typing", text: String(ev.delta.text || ""), fresh: false }]
    return []
  }
  if (e.type === "assistant" && e.message && Array.isArray(e.message.content)) {
    var out = []
    e.message.content.forEach(function(c) {
      if (!c || typeof c !== "object") return
      if (c.type === "tool_use") stepText(c.name, c.input).split("\n").forEach(function(t) { out.push({ kind: "step", text: t }) })
      else if (c.type === "text" && String(c.text || "").trim()) out.push({ kind: "answer", text: String(c.text) })
    })
    return out
  }
  if (e.type === "result") {
    var denied = (Array.isArray(e.permission_denials) ? e.permission_denials : []).map(function(d) { return d && d.tool_name ? String(d.tool_name) : "" }).filter(function(n) { return n })
    if (e.is_error || e.subtype !== "success") {
      var errors = (Array.isArray(e.errors) ? e.errors : []).map(function(x) { return String(x || "").trim() }).filter(function(x) { return x })
      var why = String(e.result || "").trim() || errors[0] || (e.subtype === "error_max_turns" ? "It ran out of turns before it finished." : "It stopped before it finished.")
      return [{ kind: "failed", text: why.slice(0, 400) }]
    }
    return [{ kind: "done", text: String(e.result || ""), seconds: Math.round((Number(e.duration_ms) || 0) / 100) / 10, denied: denied }]
  }
  return []
}
// (What it was called when only Claude Code worked here.)
function fromClaude(line) { return fromMessages(line) }

// Codex's lines (exec --json): a thread of items (its messages, the
// commands it runs, files it changes), whole as each starts or ends.
function fromCodex(line) {
  var e = parse(line)
  if (!e) return []
  var item = e.item && typeof e.item === "object" ? e.item : null
  if (e.type === "thread.started") return [{ kind: "start", model: "", session: isSessionId(e.thread_id) ? String(e.thread_id) : "" }]
  if (e.type === "item.started" && item && item.type === "command_execution") return commandSteps(item.command).map(function(t) { return { kind: "step", text: t } })
  if (e.type === "item.completed" && item) {
    if (item.type === "agent_message" && String(item.text || "").trim()) return [{ kind: "answer", text: String(item.text).trim() }]
    if (item.type === "file_change") {
      var files = (Array.isArray(item.changes) ? item.changes : []).map(function(c) { return baseName(c && c.path) })
      return [{ kind: "step", text: files.length ? "Writing " + files.join(", ") : "Writing a file" }]
    }
    return []
  }
  if (e.type === "turn.completed") return [{ kind: "done", text: "", seconds: 0, denied: [] }]
  if (e.type === "turn.failed") return [{ kind: "failed", text: String(e.error && e.error.message || "It stopped before it finished.").slice(0, 400) }]
  if (e.type === "error" && e.message) return [{ kind: "failed", text: String(e.message).slice(0, 400) }]
  return []
}

// Why it didn't work, from how it ended: its exit code and what it said on
// stderr (code -1: you stopped it).
function failureText(agent, code, errors) {
  if (code === 127) return name(agent) + " isn't installed here (Omarchy installs it: omarchy default agent " + agent + ")."
  var lines = String(errors || "").split("\n").map(function(l) { return l.trim() })
    .filter(function(l) { return l && !/^Warning:/.test(l) && !/^Reading additional input from stdin/.test(l) })
  if (lines.length) return lines[lines.length - 1].slice(0, 300)
  return "It stopped before it finished" + (code > 0 ? " (code " + code + ")." : ".")
}
