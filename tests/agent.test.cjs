// Checks asking your agent from Uber Notebook: the prompt it's handed, and what
// the box says.
// Usage (from the plugin directory): node tests/agent.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Agent = load("Agent.js");
const Docs = load("Docs.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const base = { request: "Turn this into to-dos", page: { id: "p1", title: "Lisbon" }, skill: "/plugins/uber-notebook/skills/uber-notebook/SKILL.md" };

check("the prompt says where you are and what you'd like", () => {
  const page = Agent.prompt(Object.assign({ scope: "page", blocks: [] }, base));
  assert.ok(page.includes("\u201cLisbon\u201d (page id p1)"));
  assert.ok(page.includes("What I'd like: Turn this into to-dos"));
  assert.ok(page.includes("Use the uber-notebook skill"), "it names the skill");
  assert.ok(page.includes("  /plugins/uber-notebook/skills/uber-notebook/SKILL.md"), "and where it is, for harnesses without skills");
  assert.ok(page.includes("never by editing Uber Notebook's files"));
  const blocks = Agent.prompt(Object.assign({ scope: "blocks", blocks: ["b1", "b2"] }, base));
  assert.ok(blocks.includes("The blocks I picked on it: b1, b2"));
  const words = Agent.prompt(Object.assign({ scope: "words", blocks: ["b1"], words: "book the tram\nand pastries" }, base));
  assert.ok(words.includes("In block b1, I selected these words:\n\n> book the tram\n> and pastries"));
  const line = Agent.prompt(Object.assign({ scope: "line", line: "b9" }, base));
  assert.ok(line.includes("I'm on an empty line, block b9: put what you write there"));
});

check("it carries ids, not the page's text, and keeps long things short", () => {
  const p = Agent.prompt(Object.assign({ scope: "page" }, base, { request: "x".repeat(10000) }));
  assert.ok(p.length < 6000, "a long request is cut");
  assert.ok(p.includes("\u2026"));
  const w = Agent.prompt(Object.assign({ scope: "words", blocks: ["b1"], words: "y".repeat(5000) }, base));
  assert.ok(w.length < 3500, "and so are long selections");
});

check("the box: the agents' names, what it's about, suggestions", () => {
  assert.equal(Agent.name("claude"), "Claude Code");
  assert.equal(Agent.name("cursor-agent"), "Cursor CLI");
  assert.equal(Agent.name("newagent"), "newagent", "one Omarchy adds later goes by its own name");
  assert.equal(Agent.name(""), "");
  assert.equal(Agent.scopeLabel("blocks", 1), "This block");
  assert.equal(Agent.scopeLabel("blocks", 3), "3 blocks");
  assert.equal(Agent.scopeLabel("page"), "This page");
  for (const scope of ["page", "blocks", "words", "line"]) assert.ok(plain(Agent.suggestions(scope)).length >= 3, scope);
});

check("/agent is in the slash menu", () => {
  const found = plain(Docs.findCommands("agent"));
  assert.equal(found[0].id, "agent");
  assert.equal(found[0].action, "agent");
  assert.equal(plain(Docs.findCommands("age"))[0].id, "agent", "first, before Page");
  assert.equal(plain(Docs.findCommands(""))[0].id, "agent", "and first in the whole menu");
  assert.ok(plain(Docs.findCommands("ai")).some((c) => c.id === "agent"));
});

console.log(`agent: ${passed} checks passed`);
