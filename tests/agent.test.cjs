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
  assert.equal(Agent.command("gemini", "x"), null);
  const argv = plain(Agent.command("claude", "-starts with a dash"));
  assert.deepEqual(argv.slice(0, 4), ["/usr/bin/bash", "-c", "exec \"$@\" < /dev/null", "uber-notebook-agent"], "nothing to read on its input");
  assert.equal(argv[4], "claude");
  for (const a of ["-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages"]) assert.ok(argv.includes(a), a);
  assert.equal(argv[argv.indexOf("--permission-mode") + 1], "auto", "as Omarchy starts it");
  assert.equal(argv[argv.indexOf("--allowedTools") + 1], "Bash(omarchy-shell uber-notebook *)", "Uber Notebook's commands allowed");
  assert.deepEqual(argv.slice(-2), ["--", "-starts with a dash"], "the prompt last, after --, never read as an option");
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
  const c = plain(Agent.command("claude", "p", { model: "sonnet", effort: "low" }));
  assert.deepEqual(c.slice(c.indexOf("--model"), c.indexOf("--model") + 4), ["--model", "sonnet", "--effort", "low"]);
  assert.deepEqual(c.slice(-2), ["--", "p"], "the prompt still last");
  const g = plain(Agent.command("grok", "p", { model: "grok-4.7-build-fast", effort: "low" }));
  assert.deepEqual(g.slice(g.indexOf("-m"), g.indexOf("-m") + 4), ["-m", "grok-4.7-build-fast", "--reasoning-effort", "low"]);
  const x = plain(Agent.command("codex", "p", { model: "gpt-5.5", effort: "high" }));
  assert.deepEqual(x.slice(x.indexOf("-m"), x.indexOf("-m") + 4), ["-m", "gpt-5.5", "-c", "model_reasoning_effort=\"high\""]);
  assert.ok(!plain(Agent.command("grok", "p", {})).includes("-m"), "nothing chosen: as Grok is set up");
  assert.ok(!plain(Agent.command("grok", "p", { model: "x; rm -rf /", effort: "$(boom)" })).some((a) => /rm -rf|boom/.test(a)), "never anything but a model's name");
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
  assert.deepEqual(plain(Agent.fromLine("grok", JSON.stringify({ type: "assistant", message: { content: [{ type: "tool_use", name: "run_terminal_command", input: { command: script } }] } }))).map((e) => e.text), want);
  assert.deepEqual(plain(Agent.fromLine("codex", JSON.stringify({ type: "item.started", item: { type: "command_execution", command: "/usr/bin/bash -lc '" + script + "'" } }))).map((e) => e.text), want);
});

check("Grok and Codex work here too: their commands, as Omarchy starts them", () => {
  assert.ok(Agent.runsHere("grok"));
  assert.ok(Agent.runsHere("codex"));
  const g = plain(Agent.command("grok", "-a prompt"));
  assert.equal(g[4], "grok");
  assert.equal(g[g.indexOf("--output-format") + 1], "streaming-messages-json");
  assert.ok(g.includes("--include-partial-messages"));
  assert.equal(g[g.indexOf("--permission-mode") + 1], "bypassPermissions", "as Omarchy starts Grok");
  assert.equal(g[g.length - 1], "--single=-a prompt", "the prompt as --single's value, never read as an option");
  const c = plain(Agent.command("codex", "-a prompt"));
  assert.deepEqual(c.slice(4, 7), ["codex", "exec", "--json"]);
  assert.ok(c.includes("--approve-for-me"), "as Omarchy starts Codex");
  assert.ok(c.includes("--skip-git-repo-check"), "its folder isn't a git repository");
  assert.deepEqual(c.slice(-2), ["--", "-a prompt"]);
});

// Grok's lines (streaming-messages-json) are Claude Code's, with its own tools' names.
check("what Grok says, as the panel shows it", () => {
  const f = (o) => plain(Agent.fromLine("grok", JSON.stringify(o)));
  assert.deepEqual(f({ type: "system", subtype: "init", model: "grok-4.6", permissionMode: "default" }), [{ kind: "start", model: "grok-4.6", session: "" }]);
  assert.deepEqual(f({ type: "assistant", message: { content: [{ type: "text", text: "I'll read `ideas.md`." }, { type: "tool_use", name: "read_file", input: { target_file: "ideas.md" } }] } }),
    [{ kind: "answer", text: "I'll read `ideas.md`." }, { kind: "step", text: "Reading ideas.md" }]);
  assert.deepEqual(f({ type: "assistant", message: { content: [{ type: "tool_use", name: "run_terminal_command", input: { command: "omarchy-shell uber-notebook insertAfter p1 b1 /run/user/1000/x.md" } }] } }),
    [{ kind: "step", text: "Writing on the page" }]);
  assert.deepEqual(f({ type: "stream_event", event: { type: "content_block_delta", index: 0, delta: { type: "text_delta", text: "I'll" } } }), [{ kind: "typing", text: "I'll", fresh: false }]);
  assert.deepEqual(f({ type: "result", subtype: "success", is_error: false, duration_ms: 3870, result: "A printed zine for the launch" }),
    [{ kind: "done", text: "A printed zine for the launch", seconds: 3.9, denied: [] }]);
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
  // Claude Code: --session-id to start, --resume to go on; the prompt last.
  const c1 = tail(Agent.command("claude", "Hi", {}, { id: id, resume: false }));
  assert.deepEqual(c1.slice(c1.indexOf("--session-id"), c1.indexOf("--session-id") + 2), ["--session-id", id]);
  const c2 = tail(Agent.command("claude", "And then?", { model: "opus" }, { id: id, resume: true }));
  assert.deepEqual(c2.slice(c2.indexOf("--resume"), c2.indexOf("--resume") + 2), ["--resume", id]);
  assert.equal(c2.indexOf("--session-id"), -1);
  assert.deepEqual(c2.slice(-2), ["--", "And then?"]);
  assert.ok(c2.indexOf("--model") > 0);
  // Grok: the same, as --flag=value.
  const g1 = tail(Agent.command("grok", "Hi", {}, { id: id, resume: false }));
  assert.ok(g1.indexOf("--session-id=" + id) > 0);
  const g2 = tail(Agent.command("grok", "And then?", {}, { id: id, resume: true }));
  assert.ok(g2.indexOf("--resume=" + id) > 0);
  assert.equal(g2[g2.length - 1], "--single=And then?");
  // Codex: its own id, from its first line; exec's options, then resume.
  const x1 = tail(Agent.command("codex", "Hi", {}, { id: "", resume: false }));
  assert.deepEqual(x1, ["codex", "exec", "--json", "--approve-for-me", "--skip-git-repo-check", "--", "Hi"]);
  const t = "01a105cd-1057-70a1-8862-616924424b31";
  const x2 = tail(Agent.command("codex", "-and then?", { effort: "low" }, { id: t, resume: true }));
  assert.deepEqual(x2, ["codex", "exec", "--json", "--approve-for-me", "--skip-git-repo-check", "-c", "model_reasoning_effort=\"low\"", "resume", "--", t, "-and then?"]);
  // Not an id: not on the command line (a new conversation, as before).
  const bad = tail(Agent.command("claude", "Hi", {}, { id: "--dangerous", resume: true }));
  assert.equal(bad.indexOf("--resume"), -1);
  assert.equal(bad.indexOf("--dangerous"), -1);
  assert.deepEqual(tail(Agent.command("claude", "Hi", {})), tail(Agent.command("claude", "Hi", {}, null)), "none: as before");
});

check("a conversation's id: a new one for Claude Code and Grok, Codex's from its first line", () => {
  let n = 0;
  const seq = () => ((n++ * 7) % 16) / 16;
  const made = Agent.newSessionId("claude", seq);
  assert.ok(Agent.isSessionId(made), made);
  assert.equal(made.charAt(14), "4", "a version 4 UUID");
  assert.ok("89ab".indexOf(made.charAt(19)) >= 0);
  assert.ok(Agent.isSessionId(Agent.newSessionId("grok")));
  assert.notEqual(Agent.newSessionId("grok"), Agent.newSessionId("grok"));
  assert.equal(Agent.newSessionId("codex"), "", "Codex names its own");
  assert.equal(Agent.isSessionId("13FFD9F2-02B8-4C3B-AFF2-D13AEE8E4464"), true);
  assert.equal(Agent.isSessionId("t1"), false);
  assert.equal(Agent.isSessionId("13ffd9f2-02b8-4c3b-aff2-d13aee8e4464 --x"), false);
  // Its id, as each says it.
  const t = "01a105cd-1057-70a1-8862-616924424b31";
  assert.deepEqual(plain(Agent.fromLine("codex", JSON.stringify({ type: "thread.started", thread_id: t }))), [{ kind: "start", model: "", session: t }]);
  const u = "96265d42-9b62-4091-a10d-7004d41b5418";
  assert.deepEqual(plain(Agent.fromLine("grok", JSON.stringify({ type: "system", subtype: "init", session_id: u, model: "grok-4.6" }))), [{ kind: "start", model: "grok-4.6", session: u }]);
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
