// Checks asking your agent from Uber Notebook: the prompt it's handed, and what
// the box says.
// Usage (from the plugin directory): node tests/agent.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Agent = load("Agent.js");
const Docs = load("Docs.js");
let passed = 0;
// Where an agent's program is, and its working folder (Store.qml finds them).
const W = (agent) => ({ exe: "/usr/bin/" + agent, dir: "/run/user/1000/uber-notebook-agent" });
function check(name, fn) { fn(); passed++; }

const base = { request: "Turn this into to-dos", page: { id: "p1", title: "Lisbon" }, skill: "/plugins/uber-notebook/skills/uber-notebook/SKILL.md" };

check("the prompt says where you are and what you'd like", () => {
  const page = Agent.prompt(Object.assign({ scope: "page", blocks: [] }, base));
  assert.ok(page.includes("\u201cLisbon\u201d (page id p1)"));
  assert.ok(page.includes("What I'd like: Turn this into to-dos"));
  assert.ok(page.includes("Use the uber-notebook skill"), "it names the skill");
  assert.ok(page.includes("  /plugins/uber-notebook/skills/uber-notebook/SKILL.md"), "and where it is, for harnesses without skills");
  assert.ok(page.includes("Read and change my notes only through those commands"), "the commands, not the files");
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
  assert.equal(Agent.scopeLabel("new"), "New page");
  assert.ok(plain(Agent.suggestions("new")).length >= 1, "a new page's own, about no page");
  assert.ok(!plain(Agent.suggestions("new")).some((s) => /this page/i.test(s)));
  for (const scope of ["page", "blocks", "words", "line"]) assert.ok(plain(Agent.suggestions(scope)).length >= 3, scope);
});

check("a new page: made for it, open, and written there", () => {
  const top = Agent.prompt(Object.assign({}, base, { scope: "new", page: { id: "n1", title: "" }, request: "A packing list for Lisbon" }));
  assert.ok(top.includes("a new, empty page for this (page id n1), at the top of Pages"), top);
  assert.ok(top.includes("give it a title that says what it is (rename)"));
  assert.ok(top.includes("what goes on it (append)"));
  assert.ok(top.includes("Don't make another page for it."));
  assert.ok(!top.includes("The page I'm on"), "it's not about the page you were on");
  assert.ok(top.includes("What I'd like: A packing list for Lisbon"));
  const inside = Agent.prompt(Object.assign({}, base, { scope: "new", page: { id: "n2", title: "" }, into: { id: "p1", title: "Lisbon" } }));
  assert.ok(inside.includes("(page id n2), inside \u201cLisbon\u201d (page id p1)"), inside);
  const here = Agent.prompt(Object.assign({}, base, { scope: "new", page: { id: "n3", title: "" }, here: true }));
  assert.ok(here.includes("small panel on the page"), "in the panel, as any request");
});

check("/agent is in the slash menu", () => {
  const found = plain(Docs.findCommands("agent"));
  assert.equal(found[0].id, "agent");
  assert.equal(found[0].action, "agent");
  assert.equal(plain(Docs.findCommands("age"))[0].id, "agent", "first, before Page");
  assert.equal(plain(Docs.findCommands(""))[0].id, "agent", "and first in the whole menu");
  assert.ok(plain(Docs.findCommands("ai")).some((c) => c.id === "agent"));
});

check("Claude Code works here: its command, and the prompt says so", () => {
  assert.ok(Agent.runsHere("claude"));
  assert.ok(!Agent.runsHere("gemini"), "the others open in a terminal");
  assert.equal(Agent.command("gemini", "x", undefined, undefined, W("gemini")), null);
  const argv = plain(Agent.command("claude", "-starts with a dash", undefined, undefined, W("claude")));
  assert.deepEqual(argv.slice(0, 4), ["/usr/bin/bash", "-c", "exec \"$@\"", "uber-notebook-agent"], "its input kept: it reads its request and your answers there");
  assert.equal(argv[4], "/usr/bin/claude", "by its full path");
  // With the files helper: what it prints, through its ascii-lines (no character cut in two on its way).
  const filt = plain(Agent.command("claude", "x", undefined, undefined, Object.assign(W("claude"), { helper: "/plugin/bin/uber-notebook-files" })));
  assert.deepEqual(filt.slice(0, 6), ["/usr/bin/bash", "-c", "h=$1; shift; set -o pipefail; \"$@\" | /usr/bin/python3 -I -S \"$h\" ascii-lines", "uber-notebook-agent", "/plugin/bin/uber-notebook-files", "/usr/bin/claude"]);
  const codexF = plain(Agent.command("codex", "-x", undefined, undefined, Object.assign(W("codex"), { helper: "/plugin/bin/uber-notebook-files" })));
  assert.ok(codexF[2].indexOf("\"$@\" < /dev/null | /usr/bin/python3") > 0, "Codex: nothing on its input, its output filtered");
  assert.equal(codexF[codexF.length - 1], "-x", "its prompt still last");
  for (const a of ["-p", "--verbose", "--include-partial-messages"]) assert.ok(argv.includes(a), a);
  assert.ok(!argv.includes("--restricted") && !argv.includes("--strict-mcp-config") && !argv.includes("--setting-sources"),
    "your setup as in your terminal: your plugins and MCP servers among it");
  assert.equal(argv[argv.indexOf("--input-format") + 1], "stream-json");
  assert.equal(argv[argv.indexOf("--output-format") + 1], "stream-json");
  assert.equal(argv[argv.indexOf("--permission-prompt-tool") + 1], "stdio", "what's beyond its rules is asked of Uber Notebook (you)");
  assert.equal(argv[argv.indexOf("--tools") + 1], "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch");
  assert.equal(argv[argv.indexOf("--permission-mode") + 1], "manual", "asked, whatever your settings' default mode");
  assert.ok(!argv.includes("--add-dir"), "no skill folder given: none");
  const withSkill = plain(Agent.command("claude", "x", undefined, undefined, Object.assign(W("claude"), { skill: "/home/me/.config/omarchy/plugins/marcho78.uber-notebook/skills/uber-notebook" })));
  assert.deepEqual(withSkill.slice(withSkill.indexOf("--add-dir"), withSkill.indexOf("--add-dir") + 3),
    ["--add-dir", "/home/me/.config/omarchy/plugins/marcho78.uber-notebook/skills/uber-notebook", "--permission-mode"], "its skill read without asking (and the folder list ended)");
  assert.ok(!plain(Agent.command("claude", "x", undefined, undefined, Object.assign(W("claude"), { skill: "skills/*" }))).includes("--add-dir"), "only a full path, no pattern");
  const allowed = argv.slice(argv.indexOf("--allowedTools") + 1, argv.indexOf("--allowedTools") + 4);
  assert.deepEqual(allowed, ["Bash(omarchy-shell uber-notebook-agent *)", "Edit(//run/user/1000/uber-notebook-agent/**)", "Write(//run/user/1000/uber-notebook-agent/**)"],
    "Uber Notebook's commands, and files in its own folder, without asking");
  assert.ok(!argv.some((a) => a.indexOf("starts with a dash") >= 0), "the request isn't in its command line");
  // Its request on its input, and your answers to what it asks.
  assert.deepEqual(JSON.parse(Agent.input("claude", "-starts with a dash")), { type: "user", message: { role: "user", content: "-starts with a dash" } });
  assert.ok(Agent.input("claude", "x").endsWith("\n"));
  assert.equal(Agent.input("codex", "x"), "", "Codex: in its command line");
  assert.deepEqual(JSON.parse(Agent.answer("r1", true, { url: "https://e.org" })), { type: "control_response", response: { subtype: "success", request_id: "r1", response: { behavior: "allow", updatedInput: { url: "https://e.org" } } } });
  assert.deepEqual(JSON.parse(Agent.answer("r2", false, {})).response.response, { behavior: "deny", message: "The user said no." });
  assert.equal(JSON.parse(Agent.unsupported("r3")).response.subtype, "error");
  assert.deepEqual(plain(Agent.fromLine("claude", JSON.stringify({ type: "control_request", request_id: "r9", request: { subtype: "can_use_tool", tool_name: "WebFetch", input: { url: "https://e.org/a" } } }))),
    [{ kind: "ask", id: "r9", tool: "WebFetch", input: { url: "https://e.org/a" } }]);
  assert.deepEqual(plain(Agent.fromLine("claude", JSON.stringify({ type: "control_request", request_id: "r10", request: { subtype: "something_else" } }))), [{ kind: "control", id: "r10" }]);
  assert.equal(Agent.command("claude", "x", {}, null, { exe: "claude", dir: "/run/x" }), null, "never looked up on PATH");
  assert.equal(Agent.command("claude", "x", {}, null, { exe: "/usr/bin/claude", dir: "" }), null, "a folder of its own");
  assert.equal(Agent.command("claude", "x", {}, null, { exe: "/usr/bin/claude", dir: "/run/*" }), null);
  const here = Agent.prompt(Object.assign({ scope: "page", here: true }, base));
  assert.ok(here.includes("with no terminal: what you write shows in a small panel on the page"));
  assert.ok(!Agent.prompt(Object.assign({ scope: "page" }, base)).includes("small panel"), "not in a terminal's prompt");
});

// Lines as Claude Code 2.1 prints them (stream-json), shortened.
const L = (o) => JSON.stringify(o);
const lines = [
  L({ type: "system", subtype: "hook_started", hook_name: "SessionStart:startup" }),
  L({ type: "system", subtype: "init", model: "claude-opus-5-5", tools: ["Bash", "Read"] }),
  L({ type: "stream_event", event: { type: "message_start", message: { content: [] } } }),
  L({ type: "stream_event", event: { type: "content_block_start", index: 0, content_block: { type: "tool_use", name: "Bash", input: {} } } }),
  L({ type: "stream_event", event: { type: "content_block_delta", index: 0, delta: { type: "input_json_delta", partial_json: "{\"comm" } } }),
  L({ type: "assistant", message: { content: [{ type: "tool_use", name: "Bash", input: { command: "omarchy-shell uber-notebook blocks 6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b" } }] } }),
  L({ type: "user", message: { content: [{ type: "tool_result", content: "[...]" }] } }),
  L({ type: "assistant", message: { content: [{ type: "tool_use", name: "Bash", input: { command: "f=$(mktemp \"$XDG_RUNTIME_DIR/uber-notebook-XXXXXX.md\")\ncat > \"$f\" <<'EOF'\n- [ ] Posters\nEOF\nomarchy-shell uber-notebook replace p1 b1 \"$f\"" } }] } }),
  L({ type: "assistant", message: { content: [{ type: "tool_use", name: "Read", input: { file_path: "/home/me/.claude/skills/uber-notebook/SKILL.md" } }, { type: "tool_use", name: "Bash", input: { command: "ls -la" } }] } }),
  L({ type: "stream_event", event: { type: "content_block_start", index: 0, content_block: { type: "text", text: "" } } }),
  L({ type: "stream_event", event: { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "Made the " } } }),
  L({ type: "stream_event", event: { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "checklist." } } }),
  L({ type: "assistant", message: { content: [{ type: "text", text: "Made the checklist." }] } }),
  L({ type: "rate_limit_event", rate_limit_info: { status: "allowed" } }),
  L({ type: "result", subtype: "success", is_error: false, result: "Made the checklist.", duration_ms: 9346, permission_denials: [{ tool_name: "Write" }] }),
  "not json at all",
  ""
];

check("what Claude Code says, as the panel shows it", () => {
  const got = lines.map((l) => plain(Agent.fromClaude(l)));
  assert.deepEqual(got[0], [], "hooks: nothing to show");
  assert.deepEqual(got[1], [{ kind: "start", model: "claude-opus-5-5", session: "" }]);
  assert.deepEqual(got[3], [], "a tool's input, being written: nothing yet");
  assert.deepEqual(got[4], []);
  assert.deepEqual(got[5], [{ kind: "step", text: "Reading the page" }], "a command on your notes, said simply");
  assert.deepEqual(got[6], [], "its result: not shown");
  assert.deepEqual(got[7], [{ kind: "step", text: "Rewriting part of the page" }], "the command in a longer script");
  assert.deepEqual(got[8], [{ kind: "step", text: "Reading the uber-notebook skill" }, { kind: "step", text: "Running a command" }]);
  assert.deepEqual(got[9], [{ kind: "typing", text: "", fresh: true }], "an answer starts");
  assert.deepEqual(got[10], [{ kind: "typing", text: "Made the ", fresh: false }]);
  assert.deepEqual(got[12], [{ kind: "answer", text: "Made the checklist." }]);
  assert.deepEqual(got[13], []);
  assert.deepEqual(got[14], [{ kind: "done", text: "Made the checklist.", seconds: 9.3, denied: ["Write"] }]);
  assert.deepEqual(got[15], [], "not JSON: nothing");
  assert.deepEqual(got[16], []);
});

check("how it went wrong", () => {
  assert.deepEqual(plain(Agent.fromClaude(L({ type: "result", subtype: "success", is_error: true, result: "Not logged in · Please run /login" }))),
    [{ kind: "failed", text: "Not logged in · Please run /login" }], "an error it reports");
  assert.equal(plain(Agent.fromClaude(L({ type: "result", subtype: "error_max_turns", is_error: true })))[0].text, "It ran out of turns before it finished.");
  assert.equal(Agent.failureText("claude", 127, "bash: line 1: exec: claude: not found"), "Claude Code isn't installed here (Omarchy installs it: omarchy default agent claude).");
  assert.equal(Agent.failureText("claude", 1, "Warning: no stdin data received in 3s\nError: Invalid API key"), "Error: Invalid API key", "the last thing it said, not a warning");
  assert.equal(Agent.failureText("codex", 1, "Reading additional input from stdin...\nNot signed in"), "Not signed in", "Codex's note about stdin isn't the reason");
  assert.equal(Agent.failureText("grok", 127, ""), "Grok isn't installed here (Omarchy installs it: omarchy default agent grok).");
  assert.equal(Agent.failureText("claude", 2, ""), "It stopped before it finished (code 2).");
});

check("the model and effort you chose, on each one's command line", () => {
  const c = plain(Agent.command("claude", "p", { model: "sonnet", effort: "low" }, undefined, W("claude")));
  assert.deepEqual(c.slice(c.indexOf("--model"), c.indexOf("--model") + 4), ["--model", "sonnet", "--effort", "low"]);
  assert.ok(!c.includes("p"), "the request on its input, not here");
  const g = plain(Agent.command("grok", "p", { model: "grok-4.7-build-fast", effort: "low" }, undefined, W("grok")));
  assert.deepEqual(g.slice(g.indexOf("-m"), g.indexOf("-m") + 4), ["-m", "grok-4.7-build-fast", "--reasoning-effort", "low"]);
  const x = plain(Agent.command("codex", "p", { model: "gpt-5.5", effort: "high" }, undefined, W("codex")));
  assert.deepEqual(x.slice(x.indexOf("-m"), x.indexOf("-m") + 4), ["-m", "gpt-5.5", "-c", "model_reasoning_effort=\"high\""]);
  assert.ok(!plain(Agent.command("grok", "p", {}, undefined, W("grok"))).includes("-m"), "nothing chosen: as Grok is set up");
  assert.ok(!plain(Agent.command("grok", "p", { model: "x; rm -rf /", effort: "$(boom)" }, undefined, W("grok"))).some((a) => /rm -rf|boom/.test(a)), "never anything but a model's name");
  assert.ok(Agent.prompt(Object.assign({ scope: "page" }, base)).includes("don't open the files my notes are kept in, or Uber Notebook's own files and code"));
});

// The lists the agents keep, as on this machine, shortened.
const grokCache = JSON.stringify({ models: {
  "grok-4.7": { info: { id: "grok-4.7", name: "Grok 4.7", description: "Latest frontier model", hidden: false, reasoning_effort: "high",
    reasoning_efforts: [{ id: "xhigh", value: "xhigh" }, { id: "high", value: "high", default: true }, { id: "medium", value: "medium" }, { id: "low", value: "low" }] } },
  "grok-4.5": { info: { id: "grok-4.5", name: "Grok 4.5", description: null, hidden: false, reasoning_effort: "high",
    reasoning_efforts: [{ id: "high", value: "high" }, { id: "medium", value: "medium" }, { id: "low", value: "low" }] } },
  "grok-secret": { info: { id: "grok-secret", name: "Hidden", hidden: true, reasoning_efforts: [] } } } });
const codexCache = JSON.stringify({ models: [
  { slug: "gpt-5.5", display_name: "GPT-5.5", visibility: "list", priority: 13, default_reasoning_level: "medium", supported_reasoning_levels: [{ effort: "low" }, { effort: "medium" }, { effort: "high" }, { effort: "xhigh" }] },
  { slug: "gpt-6-astra", display_name: "GPT-6-Astra", visibility: "list", priority: 2, default_reasoning_level: "medium", supported_reasoning_levels: [{ effort: "low" }, { effort: "medium" }, { effort: "high" }, { effort: "xhigh" }, { effort: "max" }] },
  { slug: "codex-auto-review", display_name: "Codex Auto Review", visibility: "hide", priority: 43, supported_reasoning_levels: [] }] });

check("the models each can work with, and the efforts each takes", () => {
  const g = plain(Agent.models("grok", grokCache));
  assert.deepEqual(g.map((m) => m.id), ["grok-4.7", "grok-4.5"], "not the hidden ones");
  assert.deepEqual(g[0], { id: "grok-4.7", name: "Grok 4.7", description: "Latest frontier model", efforts: [{ id: "xhigh", label: "Extra high" }, { id: "high", label: "High" }, { id: "medium", label: "Medium" }, { id: "low", label: "Low" }], effort: "high" });
  const c = plain(Agent.models("codex", codexCache));
  assert.deepEqual(c.map((m) => m.id), ["gpt-6-astra", "gpt-5.5"], "in Codex's order, not the hidden ones");
  assert.equal(c[0].effort, "medium");
  const cl = plain(Agent.models("claude", ""));
  assert.deepEqual(cl.map((m) => m.id), ["fable", "opus", "sonnet"], "Claude Code's names for its latest");
  assert.deepEqual(cl[0].efforts.map((e) => e.id), ["low", "medium", "high", "xhigh", "max"]);
  assert.deepEqual(plain(Agent.models("grok", "not json")), [], "no list: none");
  assert.deepEqual(plain(Agent.models("gemini", grokCache)), []);
  // Efforts: the model's; as it's set up, the ones every model takes.
  assert.deepEqual(plain(Agent.efforts(g, "grok-4.5")).map((e) => e.id), ["high", "medium", "low"]);
  assert.deepEqual(plain(Agent.efforts(g, "")).map((e) => e.id), ["high", "medium", "low"], "xhigh isn't every model's");
  assert.deepEqual(plain(Agent.efforts(c, "")).map((e) => e.id), ["low", "medium", "high", "xhigh"]);
  assert.equal(Agent.choiceLabel(g, "grok-4.7", "low"), "Grok 4.7 \u00b7 Low");
  assert.equal(Agent.choiceLabel(g, "", ""), "Default model");
  assert.equal(Agent.choiceLabel(g, "", "xhigh"), "Default model \u00b7 Extra high");
});

check("a script of several commands: each kind of change, in order, once", () => {
  const script = "omarchy-shell uber-notebook icon p \u2728 && omarchy-shell uber-notebook cover p gradient:6\nput replace b1; omarchy-shell uber-notebook replace p b1 \"$f\"\nomarchy-shell uber-notebook replace p b2 \"$f\"\nomarchy-shell uber-notebook color p b3 blue_background\nomarchy-shell uber-notebook board p b4 columnColor Done green";
  const want = ["Changing a page's icon", "Changing a page's cover", "Rewriting part of the page", "Coloring a block", "Changing a board"];
  assert.deepEqual(plain(Agent.fromLine("grok", JSON.stringify({ jsonrpc: "2.0", method: "session/update", params: { sessionId: "s", update: { sessionUpdate: "tool_call", toolCallId: "c1", title: "run_terminal_command", rawInput: { command: script } } } }))).map((e) => e.text), want);
  assert.deepEqual(plain(Agent.fromLine("codex", JSON.stringify({ type: "item.started", item: { type: "command_execution", command: "/usr/bin/bash -lc '" + script + "'" } }))).map((e) => e.text), want);
});

check("finding an agent: where it's installed, checked, by its full path", () => {
  assert.deepEqual(plain(Agent.agentPaths("claude\t/home/me/.local/bin/claude\ngrok\t/usr/bin/grok\nbad line\nx\trelative/path\nclaude\t/other\n")),
    { claude: "/home/me/.local/bin/claude", grok: "/usr/bin/grok" });
  assert.ok(Agent.AGENTS_SCRIPT.includes("readlink -e") && Agent.AGENTS_SCRIPT.includes("8#$m & 022"), "where links lead, checked; nothing anyone else can change");
  const p = Agent.prompt(Object.assign({ scope: "page", here: true, dir: "/run/user/1000/uber-notebook-agent" }, base));
  assert.ok(p.includes("as a file in /run/user/1000/uber-notebook-agent (your working folder)"), "it's told where its files go");
  assert.ok(p.includes("run each as omarchy-shell uber-notebook-agent <command>"), "and the commands' panel name");
  assert.ok(p.includes("and only so: if one's refused, say why rather than trying it another way"), "only it");
  assert.ok(!Agent.prompt(Object.assign({ scope: "page", here: false }, base)).includes("uber-notebook-agent"), "not in a terminal: the usual name");
  // Codex: its commands outside its sandbox (no network there, the shell's socket among it).
  const codexHere = Agent.prompt(Object.assign({ scope: "page", here: true, dir: "/run/user/1000/uber-notebook-agent", agent: "codex" }, base));
  assert.ok(codexHere.includes("run each omarchy-shell uber-notebook-agent command with escalated permissions, outside the sandbox"));
  assert.ok(!p.includes("escalated") && !Agent.prompt(Object.assign({ scope: "page", here: false, agent: "codex" }, base)).includes("escalated"),
    "not for the others, nor in a terminal");
  // Its steps, by either name.
  assert.deepEqual(plain(Agent.fromLine("claude", JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", name: "Bash", input: { command: "omarchy-shell uber-notebook-agent blocks 1111" } }] } }))).map((e) => e.text), ["Reading the page"]);
});

check("finding an agent for real: the path on the PATH (a version manager's shim kept), checked where it leads", () => {
  const fs = require("node:fs"), os = require("node:os"), path = require("node:path"), { spawnSync } = require("node:child_process");
  const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "uber-notebook-agents-"));
  try {
    const bin = path.join(tmp, "bin"), shims = path.join(tmp, "shims"), open = path.join(tmp, "open"), plain = path.join(tmp, "plain");
    for (const d of [bin, shims, open, plain]) fs.mkdirSync(d, { mode: 0o755 });
    // A version manager: one program, its shims links to it by each tool's name.
    fs.writeFileSync(path.join(bin, "manager"), "#!/bin/sh\n", { mode: 0o755 });
    fs.symlinkSync(path.join(bin, "manager"), path.join(shims, "claude"));
    fs.symlinkSync(path.join(bin, "manager"), path.join(shims, "grok"));
    // A program installed plainly; one in a folder anyone can change; one anyone can change.
    fs.writeFileSync(path.join(plain, "codex"), "#!/bin/sh\n", { mode: 0o755 });
    // (A link to it, safe as that is, in a folder anyone can change: anyone could swap the link.)
    fs.symlinkSync(path.join(bin, "manager"), path.join(open, "grok"));
    fs.chmodSync(open, 0o777);
    fs.writeFileSync(path.join(plain, "gemini"), "#!/bin/sh\n", { mode: 0o755 });
    fs.chmodSync(path.join(plain, "gemini"), 0o777);
    const run = (PATH, names) => spawnSync("/usr/bin/bash", ["-c", Agent.AGENTS_SCRIPT, "uber-notebook-agents", PATH].concat(names), { encoding: "utf8", env: { PATH: "/usr/bin" } });
    const found = plain_(Agent.agentPaths(run([open, shims, plain].join(":"), ["claude", "grok", "codex", "gemini"]).stdout));
    assert.equal(found.claude, path.join(shims, "claude"), "the shim, as it's on the PATH: the manager knows the tool by that name");
    assert.equal(found.grok, path.join(shims, "grok"), "not the one in a folder anyone can change (first on the PATH)");
    assert.equal(found.codex, path.join(plain, "codex"));
    assert.equal(found.gemini, undefined, "not one anyone can change");
  } finally {
    fs.rmSync(tmp, { recursive: true, force: true });
  }
  function plain_(v) { return JSON.parse(JSON.stringify(v)) }
});

check("what Claude Code asks, in words; Always only for what can be allowed for good", () => {
  const ask = (tool, input) => plain(Agent.askOf(tool, input));
  assert.deepEqual(ask("WebFetch", { url: "https://Docs.Example.com/a" }), { action: "contact", target: "docs.example.com", text: "contact docs.example.com, to read https://Docs.Example.com/a", always: "Always for docs.example.com" });
  assert.equal(ask("WebFetch", { url: "http://plain.example.com/" }).always, "", "not https: once only");
  assert.deepEqual(ask("WebSearch", { query: "lisbon trams" }), { action: "search", target: "web", text: "search the web for \u201clisbon trams\u201d", always: "Always let it search" });
  assert.equal(ask("Bash", { command: "git log -3" }).always, "Always for git commands");
  for (const c of ["git status && curl x", "ls; rm -rf ~", "cat a | sh", "echo $(id)", "ls > /tmp/x", "bash -c x", "env x=1 sh", "python3 -c x", "/usr/bin/git x", "xargs rm", "find . -delete", "sudo x"]) {
    assert.equal(ask("Bash", { command: c }).always, "", c);
  }
  assert.equal(Agent.programOf("LANG=C make -j4"), "make");
  assert.deepEqual(ask("mcp__figma__get_screenshot", {}), { action: "tool", target: "mcp__figma__get_screenshot", text: "use figma\u2019s get_screenshot", always: "Always for this tool" });
  assert.equal(ask("Read", { file_path: "/etc/passwd" }).text, "read /etc/passwd");
  assert.equal(ask("Edit", { file_path: "/home/me/x" }).always, "", "a file outside its folder: once only");
  assert.deepEqual(plain(Agent.fromLine("claude", JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", name: "WebFetch", input: { url: "https://e.org/a" } }, { type: "tool_use", name: "WebSearch", input: {} }] } }))).map((e) => e.text), ["Reading e.org", "Searching the web"]);
});

check("Grok and Codex work here too: their commands, in their sandboxes", () => {
  assert.ok(Agent.runsHere("grok"));
  assert.ok(Agent.runsHere("codex"));
  const g = plain(Agent.command("grok", "-a prompt", undefined, undefined, W("grok")));
  assert.deepEqual(g.slice(4), ["/usr/bin/grok", "agent", "stdio"], "its agent protocol (ACP), on its input and output");
  assert.ok(!g.some((a) => a.indexOf("a prompt") >= 0), "the request not in its command line");
  assert.deepEqual(plain(Agent.env("grok")), { GROK_SANDBOX: "uber-notebook" }, "in its sandbox: its agent mode takes it from there");
  assert.deepEqual(plain(Agent.env("claude")), {});
  const box = Agent.grokSandbox("/run/user/1000");
  assert.ok(box.includes('[profiles.uber-notebook]\nextends = "strict"\nrestrict_network = false\nread_only = ["/run/user/1000/quickshell"]\n'), box);
  assert.equal(Agent.grokSandbox("/run/user/1000\"]\nread_write = [\"/"), "", "nothing but a folder's path in it");
  const c = plain(Agent.command("codex", "-a prompt", undefined, undefined, W("codex")));
  assert.deepEqual(c.slice(4, 7), ["/usr/bin/codex", "exec", "--json"]);
  assert.ok(c.includes("--approve-for-me"), "as Omarchy starts Codex");
  assert.equal(c[c.indexOf("sandbox_workspace_write.network_access=false") - 1], "-c", "no network in its sandbox");
  assert.ok(c.includes("--skip-git-repo-check"), "its folder isn't a git repository");
  assert.deepEqual(c.slice(-2), ["--", "-a prompt"]);
});

// Grok over ACP (JSON-RPC, a message a line), as grok 1.0.46 speaks it.
check("Grok over ACP: hello, its session (Always-approve off), the request, what it says, and your answers", () => {
  const id = "01a108d9-b7d2-7a71-9149-2d1ef7ff75fe";
  assert.deepEqual(JSON.parse(Agent.input("grok", "x")), { jsonrpc: "2.0", id: 1, method: "initialize", params: { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: false, writeTextFile: false }, terminal: false } } });
  assert.deepEqual(JSON.parse(Agent.acpSession("/run/x", null)), { jsonrpc: "2.0", id: 2, method: "session/new", params: { cwd: "/run/x", mcpServers: [], _meta: { yoloMode: false } } });
  assert.deepEqual(JSON.parse(Agent.acpSession("/run/x", { id: id, resume: true })).method, "session/load");
  assert.deepEqual(JSON.parse(Agent.acpPrompt(id, "-a prompt")).params, { sessionId: id, prompt: [{ type: "text", text: "-a prompt" }] });
  const f = (o) => plain(Agent.fromLine("grok", JSON.stringify(Object.assign({ jsonrpc: "2.0" }, o))));
  assert.deepEqual(f({ id: 1, result: { protocolVersion: 1 } }), [{ kind: "acp", stage: "ready" }]);
  assert.deepEqual(f({ id: 2, result: { sessionId: id, configOptions: [] } }), [{ kind: "start", model: "", session: id }]);
  assert.deepEqual(f({ method: "session/update", params: { sessionId: id, update: { sessionUpdate: "agent_message_chunk", content: { type: "text", text: "I'll" } } } }), [{ kind: "typing", text: "I'll", fresh: false }]);
  assert.deepEqual(f({ method: "session/update", params: { sessionId: id, update: { sessionUpdate: "tool_call", toolCallId: "c1", title: "run_terminal_command", rawInput: { command: "omarchy-shell uber-notebook-agent insertAfter p1 b1 /run/user/1000/x.md" } } } }),
    [{ kind: "step", text: "Writing on the page" }]);
  assert.deepEqual(f({ method: "session/update", params: { sessionId: id, update: { sessionUpdate: "tool_call", toolCallId: "c2", title: "web_fetch", rawInput: { url: "https://e.org/a" } } } }), [{ kind: "step", text: "Reading e.org" }]);
  assert.deepEqual(f({ method: "session/update", params: { sessionId: id, update: { sessionUpdate: "tool_call_update", toolCallId: "c2", status: "completed" } } }), [], "updates: nothing more to show");
  assert.deepEqual(f({ method: "_x.ai/session_notification", params: {} }), [], "its own extras: nothing");
  assert.equal(f({ id: 3, result: { stopReason: "end_turn" } })[0].kind, "done");
  assert.equal(f({ id: 3, result: { stopReason: "cancelled" } })[0].kind, "done", "after a No: done, waiting to be told what instead");
  assert.equal(f({ id: 3, result: { stopReason: "refusal" } })[0].kind, "failed");
  assert.deepEqual(f({ id: 3, error: { code: -32000, message: "Session not found" } }), [{ kind: "failed", text: "Session not found" }]);
  assert.ok(Agent.lostSession("Session not found"), "gone: asked anew");
  // It asks: you're asked; your answer, the option that says it.
  const options = [{ optionId: "allow-always-domain", kind: "allow_always" }, { optionId: "allow-once", kind: "allow_once" }, { optionId: "reject-once", kind: "reject_once" }];
  const ask = f({ id: 7, method: "session/request_permission", params: { sessionId: id, toolCall: { toolCallId: "c3", title: "Fetch: https://e.org", kind: "fetch", rawInput: { variant: "WebFetch", url: "https://e.org" } }, options: options } });
  assert.deepEqual(ask, [{ kind: "ask", id: 7, tool: "WebFetch", input: { variant: "WebFetch", url: "https://e.org" }, title: "Fetch: https://e.org", options: options }]);
  assert.deepEqual(JSON.parse(Agent.answerFor("grok", ask[0], true)), { jsonrpc: "2.0", id: 7, result: { outcome: { outcome: "selected", optionId: "allow-once" } } }, "once: never Grok's own Always (yours is kept in Uber Notebook)");
  assert.equal(JSON.parse(Agent.answerFor("grok", ask[0], false)).result.outcome.optionId, "reject-once");
  assert.deepEqual(JSON.parse(Agent.answerFor("grok", { id: 8, options: [] }, true)).result.outcome, { outcome: "cancelled" }, "no option that says it: cancelled");
  assert.equal(plain(Agent.askOf(ask[0].tool, ask[0].input, ask[0].title)).always, "Always for e.org");
  assert.equal(plain(Agent.askOf("Unknown", {}, "Do a thing")).text, "do this: Do a thing");
  assert.deepEqual(f({ id: 9, method: "fs/read_text_file", params: {} }), [{ kind: "control", id: 9 }], "anything else it asks: not done");
  assert.equal(JSON.parse(Agent.unsupportedFor("grok", 9)).error.code, -32601);
});

// Codex's lines (exec --json), as codex-cli 0.160 prints them.
check("what Codex says, as the panel shows it", () => {
  const f = (o) => plain(Agent.fromLine("codex", JSON.stringify(o)));
  assert.deepEqual(f({ type: "thread.started", thread_id: "01a1" }), [{ kind: "start", model: "", session: "" }], "not an id: none");
  assert.deepEqual(f({ type: "turn.started" }), []);
  assert.deepEqual(f({ type: "item.completed", item: { id: "item_0", type: "agent_message", text: "I'll read ideas.md without changing it.\n" } }),
    [{ kind: "answer", text: "I'll read ideas.md without changing it." }]);
  assert.deepEqual(f({ type: "item.started", item: { id: "item_1", type: "command_execution", command: "/usr/bin/bash -lc 'cat ideas.md'", status: "in_progress" } }),
    [{ kind: "step", text: "Running a command" }]);
  assert.deepEqual(f({ type: "item.started", item: { type: "command_execution", command: "/usr/bin/bash -lc 'omarchy-shell uber-notebook blocks p1'" } }),
    [{ kind: "step", text: "Reading the page" }]);
  assert.deepEqual(f({ type: "item.completed", item: { id: "item_1", type: "command_execution", command: "/usr/bin/bash -lc 'cat ideas.md'", exit_code: 0, status: "completed" } }), [], "a command finishing: its step was shown when it started");
  assert.deepEqual(f({ type: "item.completed", item: { type: "file_change", changes: [{ path: "/run/user/1000/todo.md", kind: "add" }] } }), [{ kind: "step", text: "Writing todo.md" }]);
  assert.deepEqual(f({ type: "item.started", item: { type: "command_execution", command: "/usr/bin/bash -lc \"sed -n '1,220p' /home/me/.codex/skills/uber-notebook/SKILL.md\"" } }),
    [{ kind: "step", text: "Reading the uber-notebook skill" }], "the skill, read with a command");
  assert.deepEqual(f({ type: "item.completed", item: { type: "reasoning", text: "..." } }), [], "its thinking: not shown");
  assert.deepEqual(f({ type: "turn.completed", usage: { input_tokens: 40524 } }), [{ kind: "done", text: "", seconds: 0, denied: [] }]);
  assert.deepEqual(f({ type: "turn.failed", error: { message: "You've hit your usage limit." } }), [{ kind: "failed", text: "You've hit your usage limit." }]);
  assert.deepEqual(plain(Agent.fromLine("codex", "Reading additional input from stdin...")), [], "not JSON: nothing");
});

check("a conversation: started with its id, gone on with in the same one", () => {
  const id = "13ffd9f2-02b8-4c3b-aff2-d13aee8e4464";
  const tail = (argv) => plain(argv).slice(4);
  // Claude Code: --session-id to start, --resume to go on; what's said, on its input.
  const c1 = tail(Agent.command("claude", "Hi", {}, { id: id, resume: false }, W("claude")));
  assert.deepEqual(c1.slice(c1.indexOf("--session-id"), c1.indexOf("--session-id") + 2), ["--session-id", id]);
  const c2 = tail(Agent.command("claude", "And then?", { model: "opus" }, { id: id, resume: true }, W("claude")));
  assert.deepEqual(c2.slice(c2.indexOf("--resume"), c2.indexOf("--resume") + 2), ["--resume", id]);
  assert.equal(c2.indexOf("--session-id"), -1);
  assert.ok(!c2.includes("And then?"), "not in its command line");
  assert.ok(c2.indexOf("--model") > 0);
  // Grok: names its own (session/new), gone on with by it (session/load).
  assert.equal(Agent.newSessionId("grok"), "");
  assert.equal(JSON.parse(Agent.acpSession("/run/x", { id: id, resume: true })).params.sessionId, id);
  // Codex: its own id, from its first line; exec's options, then resume.
  const x1 = tail(Agent.command("codex", "Hi", {}, { id: "", resume: false }, W("codex")));
  assert.deepEqual(x1, ["/usr/bin/codex", "exec", "--json", "--approve-for-me", "--skip-git-repo-check", "-c", "sandbox_workspace_write.network_access=false", "--", "Hi"]);
  const t = "01a105cd-1057-70a1-8862-616924424b31";
  const x2 = tail(Agent.command("codex", "-and then?", { effort: "low" }, { id: t, resume: true }, W("codex")));
  assert.deepEqual(x2, ["/usr/bin/codex", "exec", "--json", "--approve-for-me", "--skip-git-repo-check", "-c", "sandbox_workspace_write.network_access=false", "-c", "model_reasoning_effort=\"low\"", "resume", "--", t, "-and then?"]);
  // Not an id: not on the command line (a new conversation, as before).
  const bad = tail(Agent.command("claude", "Hi", {}, { id: "--dangerous", resume: true }, W("claude")));
  assert.equal(bad.indexOf("--resume"), -1);
  assert.equal(bad.indexOf("--dangerous"), -1);
  assert.deepEqual(tail(Agent.command("claude", "Hi", {}, undefined, W("claude"))), tail(Agent.command("claude", "Hi", {}, null, W("claude"))), "none: as before");
});

check("a conversation's id: a new one for Claude Code, Grok's and Codex's from their first answer", () => {
  let n = 0;
  const seq = () => ((n++ * 7) % 16) / 16;
  const made = Agent.newSessionId("claude", seq);
  assert.ok(Agent.isSessionId(made), made);
  assert.equal(made.charAt(14), "4", "a version 4 UUID");
  assert.ok("89ab".indexOf(made.charAt(19)) >= 0);
  assert.notEqual(Agent.newSessionId("claude"), Agent.newSessionId("claude"));
  assert.equal(Agent.newSessionId("grok"), "", "Grok names its own (its session/new)");
  assert.equal(Agent.newSessionId("codex"), "", "Codex names its own");
  assert.equal(Agent.isSessionId("13FFD9F2-02B8-4C3B-AFF2-D13AEE8E4464"), true);
  assert.equal(Agent.isSessionId("t1"), false);
  assert.equal(Agent.isSessionId("13ffd9f2-02b8-4c3b-aff2-d13aee8e4464 --x"), false);
  // Its id, as each says it.
  const t = "01a105cd-1057-70a1-8862-616924424b31";
  assert.deepEqual(plain(Agent.fromLine("codex", JSON.stringify({ type: "thread.started", thread_id: t }))), [{ kind: "start", model: "", session: t }]);
  const u = "96265d42-9b62-4091-a10d-7004d41b5418";
  assert.deepEqual(plain(Agent.fromLine("grok", JSON.stringify({ jsonrpc: "2.0", id: 2, result: { sessionId: u } }))), [{ kind: "start", model: "", session: u }]);
  assert.deepEqual(plain(Agent.fromLine("claude", JSON.stringify({ type: "system", subtype: "init", session_id: u, model: "claude-opus-5-5" }))), [{ kind: "start", model: "claude-opus-5-5", session: u }]);
});

check("a reply: your words, after where you are when that's changed", () => {
  assert.equal(Agent.reply({ reply: "Make it shorter", page: { id: "p1", title: "Trip" } }), "Make it shorter", "nothing changed: just your words");
  const moved = Agent.reply({ reply: "Do the same here", page: { id: "p2", title: "Packing" }, moved: true });
  assert.equal(moved, "I'm on another page now: \u201cPacking\u201d (page id p2).\n\nDo the same here");
  const picked = Agent.reply({ reply: "Turn these into to-dos", page: { id: "p2", title: "Packing" }, scope: "blocks", blocks: ["b1", "b2"] });
  assert.ok(picked.indexOf("The blocks I've picked: b1, b2") === 0, picked);
  const words = Agent.reply({ reply: "Say it better", page: { id: "p2" }, moved: true, scope: "words", blocks: ["b3"], words: "the old\nwords" });
  assert.ok(words.indexOf("I'm on another page now: \u201cUntitled\u201d") === 0, words);
  assert.ok(words.indexOf("In block b3, I've selected these words:\n\n> the old\n> words\n\nSay it better") > 0, words);
  assert.ok(Agent.reply({ reply: "x".repeat(5000) }).length <= 4001, "kept short");
});

check("a lost conversation: as each agent says it, then asked anew, told what was said", () => {
  assert.equal(Agent.lostSession("No conversation found with session ID: 5e13e2b0-d539-4306-8c80-6631d886e14a"), true);
  assert.equal(Agent.lostSession("Error: thread/resume: thread/resume failed: no rollout found for thread id 5e13 (code -32600)"), true);
  assert.equal(Agent.lostSession('Session "5e13" not found locally, restoring conversation from remote...\nError: Failed to restore session from remote: fetching session record: session get failed: 404 Not Found'), true);
  assert.equal(Agent.lostSession("Credit balance is too low"), false);
  assert.equal(Agent.lostSession(""), false);
  // Claude Code's last line, when it is: its errors say why.
  assert.deepEqual(plain(Agent.fromLine("claude", JSON.stringify({ type: "result", subtype: "error_during_execution", is_error: true, result: "", errors: ["No conversation found with session ID: x"] }))),
    [{ kind: "failed", text: "No conversation found with session ID: x" }]);
  // What was said: its last turns, each kept short; what's asked "now".
  const turns = Array.from({ length: 10 }, (_, i) => ({ request: "Question " + i, answer: i === 9 ? "x".repeat(900) : "Answer " + i }));
  const p = Agent.prompt({ request: "And then?", page: { id: "p1", title: "Trip" }, scope: "page", earlier: turns, here: true, skill: "/s/SKILL.md" });
  assert.ok(p.indexOf("We've talked about this before") > 0, p);
  assert.ok(p.indexOf("Question 1\n") < 0 && p.indexOf("Question 0") < 0, "only the last ones");
  assert.ok(p.indexOf("- I said: Question 2") > 0 && p.indexOf("- I said: Question 9") > 0);
  assert.ok(p.indexOf("  You said: Answer 8") > 0);
  assert.ok(p.indexOf("x".repeat(601)) < 0, "kept short");
  assert.ok(p.indexOf("What I'd like now: And then?") > 0);
  assert.equal(Agent.prompt({ request: "Hi", page: { id: "p1" }, scope: "page", skill: "s" }).indexOf("talked about this before"), -1, "none: as before");
});

check("conversations kept with their pages: checked, kept short, the last talked in", () => {
  const sid = "13ffd9f2-02b8-4c3b-aff2-d13aee8e4464";
  const turn = (i, extra) => Object.assign({ request: "Q" + i, steps: ["Reading the page"], answer: "A" + i, status: "done", failure: "" }, extra || {});
  const raw = { version: 1, chats: {
    p1: { agent: "claude", session: sid, page: "p1", picked: "", updated: "2026-10-04T08:00:00.000Z", turns: [turn(1), turn(2, { status: "working" }), { request: "  " }] },
    p2: { agent: "gemini", session: sid, turns: [turn(1)] },
    "../x": { agent: "claude", turns: [turn(1)] },
    p3: { agent: "codex", session: "nope", turns: [] },
    p4: { agent: "grok", session: "--resume", page: "p4", updated: "2026-10-04T09:00:00.000Z", turns: Array.from({ length: 50 }, (_, i) => turn(i, { status: i === 49 ? "failed" : "done", failure: "why " + i })) }
  } };
  const c = plain(Agent.cleanChats(raw));
  assert.deepEqual(Object.keys(c), ["p4", "p1"], "the last talked in first; an agent that doesn't work here, a bad id, nothing said: left out");
  assert.equal(c.p1.session, sid);
  assert.equal(c.p1.turns.length, 2, "an empty one left out");
  assert.equal(c.p1.turns[1].status, "stopped", "working when it was kept: stopped");
  assert.equal(c.p4.session, "", "not an id");
  assert.equal(c.p4.turns.length, Agent.MAX_CHAT_TURNS);
  assert.equal(c.p4.turns[c.p4.turns.length - 1].failure, "why 49");
  assert.equal(c.p4.turns[0].failure, "", "a failure only for one that failed");
  assert.equal(Agent.chatTip(c.p1), "Your conversation with Claude Code (2 messages)");
  assert.equal(Agent.chatTip(null), "");
  assert.deepEqual(plain(Agent.cleanChats(null)), {});
  assert.deepEqual(plain(Agent.cleanChats({ chats: [1, 2] })), {});
  const many = { chats: {} };
  for (let i = 0; i < Agent.MAX_CHATS + 5; i++) many.chats["p" + i] = { agent: "claude", updated: "2026-10-04T08:00:00.000Z", turns: [turn(i)] };
  assert.equal(Object.keys(Agent.cleanChats(many)).length, Agent.MAX_CHATS, "the last ones");
});

check("a reply on an empty line: its writing goes there", () => {
  assert.equal(Agent.reply({ reply: "A packing list", page: { id: "p1" }, scope: "line", line: "b9" }),
    "I'm on an empty line, block b9: put what you write there, in its place.\n\nA packing list");
});

console.log(`agent: ${passed} checks passed`);
