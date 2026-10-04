// Permissions.js - what you've let agents working in Uber Notebook's panel
// do without asking: [{ agent, action, target }], kept in settings
// (agentPermissions), which an agent can't change (Scope.js). An agent:
// "claude", "grok" or "codex". An action, and its target:
//   contact  a site, by its exact name (https only): the agent reads it, or
//            Uber Notebook does for it (a link's title and picture)
//   search   "web": it searches the web
//   command  a program it runs, by name ("git": a plain git command;
//            Agent.programOf says which commands can be)
//   tool     one of your connectors' tools, by its id ("mcp__figma__...")
// Anything not here is asked, each time (Allow once, Always, No).
//
// Shared with tests/permissions.test.cjs, so keep it plain JavaScript with
// no QML or Node APIs.
.pragma library

var AGENTS = ["claude", "grok", "codex"]
var ACTIONS = ["contact", "search", "command", "tool"]
var MAX = 300

// A site's exact name ("example.com", "docs.example.com"), lowercase, or "".
function cleanHost(value) {
  var h = String(value || "").trim().toLowerCase()
  if (h.length > 253) return ""
  return /^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)+$/.test(h) ? h : ""
}

// The site an https link goes to, or "" (anything else: never without asking).
function hostOf(url) {
  var m = /^https:\/\/([^\/?#:@]+)(:443)?([\/?#]|$)/i.exec(String(url || "").trim())
  return m ? cleanHost(m[1]) : ""
}

function cleanTarget(action, target) {
  var t = String(target || "").trim()
  if (action === "contact") return cleanHost(t)
  if (action === "search") return t === "web" ? t : ""
  if (action === "command") return /^[A-Za-z0-9][A-Za-z0-9._+-]{0,63}$/.test(t) ? t : ""
  if (action === "tool") return /^mcp__[A-Za-z0-9_-]{1,200}$/.test(t) ? t : ""
  return ""
}
function rule(agent, action, target) {
  var a = String(agent || "")
  var act = String(action || "")
  var t = cleanTarget(act, target)
  return AGENTS.indexOf(a) >= 0 && ACTIONS.indexOf(act) >= 0 && t ? { agent: a, action: act, target: t } : null
}

// The list as it's kept: only rules that make sense, each once, at most MAX.
function clean(list) {
  var out = []
  var seen = {}
  ;(Array.isArray(list) ? list : []).forEach(function(r) {
    if (out.length >= MAX || !r || typeof r !== "object") return
    var c = rule(r.agent, r.action, r.target)
    if (!c) return
    var key = c.agent + " " + c.action + " " + c.target
    if (seen[key]) return
    seen[key] = true
    out.push(c)
  })
  return out
}

// Whether `agent` may have `action` done for `target` without asking.
function allowed(list, agent, action, target) {
  var c = rule(agent, action, target)
  if (!c) return false
  return clean(list).some(function(r) { return r.agent === c.agent && r.action === c.action && r.target === c.target })
}

// The list with that allowed (Always), or without it (taken back).
function withAllowed(list, agent, action, target) {
  var c = rule(agent, action, target)
  var out = clean(list)
  if (!c || allowed(out, agent, action, target)) return out
  return clean(out.concat([c]))
}
function without(list, agent, action, target) {
  var c = rule(agent, action, target)
  return clean(list).filter(function(r) { return !c || r.agent !== c.agent || r.action !== c.action || r.target !== c.target })
}

// What it says, for Settings and the panel.
function agentName(agent) { return agent === "claude" ? "Claude Code" : agent === "grok" ? "Grok" : agent === "codex" ? "Codex" : "An agent" }
// For Settings: { label, note }.
function describe(r) {
  if (!r) return { label: "", note: "" }
  var who = agentName(r.agent)
  if (r.action === "contact") return { label: r.target, note: who + " may contact it without asking (or have Uber Notebook do so, for a link)" }
  if (r.action === "search") return { label: "Web search", note: who + " may search the web without asking" }
  if (r.action === "command") return { label: r.target + " commands", note: who + " may run plain " + r.target + " commands without asking" }
  if (r.action === "tool") {
    var parts = r.target.split("__")
    return { label: (parts[1] || "A connector") + "\u2019s " + (parts.slice(2).join("__") || "tool"), note: who + " may use it without asking" }
  }
  return { label: r.target, note: "" }
}
