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
// answer }], what was said, for it to go on from) }. It carries ids, not the
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

// The command, with nothing to read on its input:
//   Claude Code: print mode (stream-json), --permission-mode auto, Uber
//     Notebook's commands allowed outright;
//   Grok: single-turn mode (streaming-messages-json, the same lines as
//     Claude Code's), --permission-mode bypassPermissions;
//   Codex: exec --json, --approve-for-me (its own folder writable, the rest
//     reviewed for it), outside a git repository.
// With `choice` ({ model, effort }), the model and effort you chose. With
// `session` ({ id, resume }), the conversation it's in: Claude Code and Grok
// start theirs with the id given (--session-id) and go on with it
// (--resume); Codex names its own (its first line says, see fromCodex) and
// goes on with it (exec resume). The prompt is always last, never read as an
// option.
function command(agent, prompt, choice, session) {
  var head = ["/usr/bin/bash", "-c", "exec \"$@\" < /dev/null", "uber-notebook-agent"]
  var p = String(prompt)
  var c = choice || {}
  var model = cleanChoice(c.model)
  var effort = cleanChoice(c.effort)
  var s = session && isSessionId(session.id) ? session : null
  if (agent === "claude") return head.concat(["claude", "-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages",
    "--permission-mode", "auto", "--allowedTools", "Bash(omarchy-shell uber-notebook *)"],
    s ? [s.resume ? "--resume" : "--session-id", s.id] : [], model ? ["--model", model] : [], effort ? ["--effort", effort] : [], ["--", p])
  if (agent === "grok") return head.concat(["grok", "--output-format", "streaming-messages-json", "--include-partial-messages",
    "--permission-mode", "bypassPermissions"], s ? [(s.resume ? "--resume=" : "--session-id=") + s.id] : [],
    model ? ["-m", model] : [], effort ? ["--reasoning-effort", effort] : [], ["--single=" + p])
  if (agent === "codex") {
    var opts = ["--json", "--approve-for-me", "--skip-git-repo-check"].concat(model ? ["-m", model] : [], effort ? ["-c", "model_reasoning_effort=\"" + effort + "\""] : [])
    if (s && s.resume) return head.concat(["codex", "exec"], opts, ["resume", "--", s.id, p])
    return head.concat(["codex", "exec"], opts, ["--", p])
  }
  return null
}

// ---- a conversation: going on with it ------------------------------------------------------

// What an agent says when the conversation it's asked to go on with isn't
// there any more (cleared out, another computer): Claude Code's, Codex's,
// Grok's. Then it's started anew with what was said (prompt's `earlier`).
function lostSession(text) {
  return /No conversation found with session ID|no rollout found for thread id|not found locally|Failed to restore session/i.test(String(text || ""))
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
    updated: /^\d{4}-\d{2}-\d{2}T[\d:.]+Z$/.test(String(c.updated || "")) ? String(c.updated) : "", turns: turns }
}
function cleanTurn(t) {
  if (!t || typeof t !== "object" || !String(t.request || "").trim()) return null
  var status = ["done", "stopped", "failed"].indexOf(t.status) >= 0 ? t.status : "stopped"
  return { request: clip(t.request, MAX_REQUEST), steps: (Array.isArray(t.steps) ? t.steps : []).slice(-40).map(function(x) { return clip(x, 200) }),
    answer: clip(t.answer, 8000), status: status, failure: status === "failed" ? clip(t.failure, 400) : "" }
}
function cleanId(id) { return /^[A-Za-z0-9_-]{1,64}$/.test(String(id || "")) ? String(id) : "" }
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
  if (agent === "codex") return ""
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
  var re = /omarchy-shell\s+uber-notebook\s+([A-Za-z]+)/g
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
  return String(name || "A step")
}

// One line of what an agent says, as what the panel shows: a list of
//   { kind: "start", model, session }  (session: its conversation's id)
//   { kind: "step", text }             a step it's taking
//   { kind: "typing", text, fresh }    more of its answer (fresh: a new one starts)
//   { kind: "answer", text }           what it said, whole
//   { kind: "done", text, seconds, denied: [tools it wasn't allowed] }
//   { kind: "failed", text }
function fromLine(agent, line) {
  return agent === "codex" ? fromCodex(line) : fromMessages(line)
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
