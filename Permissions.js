// Permissions.js - what you've let agents working in Uber Notebook's panel
// do without asking: [{ agent, action, target }], kept in settings
// (agentPermissions), which an agent can't change (Scope.js). An agent:
// "claude", "grok" or "codex". An action, and its target:
//   contact  a site, by its exact name (https only): the agent reads it, or
//            Uber Notebook does for it (a link's title and picture)
//   search   "web": it searches the web
//   tool     one of your connectors' tools, by its id ("mcp__figma__...")
//   trash    "pages": it moves pages to the trash (they can be put back)
//   shell    "any": it runs any command (Settings only: through a command
//            it can read any file you can and reach any site, so no program
//            is safe to allow by its name: git or make run what their
//            folder says)
//   files    a folder, by its full path: Uber Notebook takes a file from it
//            (or a folder in it) that the agent gives a command, as if from
//            its own folder; never a hidden folder (.ssh, .config...) or one
//            in one, and never the root (Api offers it for no home folder)
// Anything not here is asked (a command once, or for the conversation). A
// rule for a program by its name ("command", from before) is no longer
// kept: it's dropped as the list is read.
//
// Shared with tests/permissions.test.cjs, so keep it plain JavaScript with
// no QML or Node APIs.
.pragma library

var AGENTS = ["claude", "grok", "codex"]
var ACTIONS = ["contact", "search", "tool", "trash", "shell", "files"]
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

// A folder files may be taken from without asking: a full path, no hidden
// folder in it (a name starting with "."), not the root, or "".
function cleanFolder(value) {
  var f = String(value || "")
  if (!/^\/[^\u0000-\u001f\u007f]{1,1000}$/.test(f) || /\/$/.test(f)) return ""
  var parts = f.split("/").slice(1)
  if (parts.length < 2 || parts.some(function(p) { return p === "" || p.charAt(0) === "." })) return ""
  return f
}
// The folder a file's in ("" for a path that isn't a plain full one).
function folderOf(path) {
  var p = String(path || "")
  if (!/^\/[^\u0000-\u001f\u007f]{1,4000}$/.test(p) || /(^|\/)\.\.?(\/|$)/.test(p)) return ""
  var i = p.lastIndexOf("/")
  return i > 0 ? p.slice(0, i) : ""
}
// Whether `agent` may give a command the file at `path` without asking: a
// rule for its folder, or a folder it's in (no hidden folder between).
function allowedFile(list, agent, path) {
  var folder = folderOf(path)
  var name = String(path || "").slice(folder.length + 1)
  if (!folder || !name || name.charAt(0) === ".") return false
  return clean(list).some(function(r) {
    if (r.agent !== agent || r.action !== "files") return false
    if (folder === r.target) return true
    if (folder.indexOf(r.target + "/") !== 0) return false
    return folder.slice(r.target.length + 1).split("/").every(function(p) { return p !== "" && p.charAt(0) !== "." })
  })
}

function cleanTarget(action, target) {
  var t = String(target || "").trim()
  if (action === "files") return cleanFolder(String(target || ""))
  if (action === "contact") return cleanHost(t)
  if (action === "search") return t === "web" ? t : ""
  if (action === "trash") return t === "pages" ? t : ""
  if (action === "shell") return t === "any" ? t : ""
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
  if (r.action === "trash") return { label: "Trashing pages", note: who + " may move pages to the trash without asking (they can be put back from it)" }
  if (r.action === "shell") return { label: "Any command", note: who + " may run any command without asking: through one, it can read any file you can and reach any site" }
  if (r.action === "files") return { label: r.target, note: who + " may put files from this folder on a page without asking" }
  if (r.action === "tool") {
    var parts = r.target.split("__")
    return { label: (parts[1] || "A connector") + "\u2019s " + (parts.slice(2).join("__") || "tool"), note: who + " may use it without asking" }
  }
  return { label: r.target, note: "" }
}
