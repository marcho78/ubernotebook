// Agent.js - asking your agent from Omanote. The agent is Omarchy's default
// coding agent: whichever harness `omarchy default agent` set (Claude Code,
// Codex, OpenCode, Gemini...), launched by Omarchy with a prompt that says
// where you are in your notes and what you'd like. It does the work through
// the omanote skill's commands, so its changes show up in the page as it
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
// words in a block) or "line" (an empty line, where its writing goes).
function scopeLabel(scope, count) {
  if (scope === "blocks") return count === 1 ? "This block" : count + " blocks"
  if (scope === "words") return "Selected words"
  if (scope === "line") return "This line"
  return "This page"
}

// Ready-made requests for what it's asked about.
function suggestions(scope) {
  if (scope === "words") return ["Rewrite this more clearly", "Turn this into to-dos", "Explain this"]
  if (scope === "blocks") return ["Turn this into to-dos", "Summarize this", "Continue writing from here", "Link related pages"]
  if (scope === "line") return ["Continue writing", "Make a checklist for this page", "Write an outline for this page", "Link related pages"]
  return ["Turn this into to-dos", "Summarize this page", "Continue writing", "Link related pages"]
}

var MAX_REQUEST = 4000
var MAX_WORDS = 1500

function clip(text, max) {
  var t = String(text || "").replace(/\r/g, "").trim()
  return t.length > max ? t.slice(0, max) + "\u2026" : t
}

// The prompt the agent starts with. `o`: { request, page: { id, title },
// scope, blocks (ids picked), words (selected), line (the empty line's
// block id), skill (the omanote skill's SKILL.md) }. It carries ids, not the
// page's text: the agent reads what it needs (the words you selected are
// the exception, since only you know which they are).
function prompt(o) {
  var page = o.page || {}
  var out = []
  out.push("I'm in Omanote, the notes app in my Omarchy shell, and I'd like your help with my notes.")
  out.push("")
  out.push("The page I'm on: \u201c" + clip(page.title || "Untitled", 200) + "\u201d (page id " + page.id + ").")
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
  out.push("What I'd like: " + clip(o.request, MAX_REQUEST))
  out.push("")
  out.push("Use the omanote skill: it explains the omarchy-shell omanote commands that read and change my notes "
    + "(blocks, read, replace, insertAfter, append, add, find). If your harness has no skill mechanism, "
    + "read the skill file directly and follow it instead:")
  out.push("")
  out.push("  " + o.skill)
  out.push("")
  out.push("Change my notes only through those commands, never by editing Omanote's files, and change only what "
    + "my request is about. When you're done, tell me what you changed.")
  return out.join("\n")
}
