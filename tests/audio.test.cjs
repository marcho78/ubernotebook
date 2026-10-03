// Checks audio notes and dictation in Pages: what's kept, levels and
// waveforms, voxtype's output as words, clocks and file names.
// Usage (from the plugin directory): node tests/audio.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const A = load("Audio.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("what's kept", () => {
  assert.deepEqual(plain(A.make()), { src: "", duration: 0, peaks: [], transcript: "", open: true, color: "", background: "" });
  assert.equal(A.clean(null), null);
  assert.equal(A.clean([1]), null);
  const a = plain(A.clean({ src: "assets/audio-1.ogg", duration: 42.567, peaks: [10, 200, -5, "x", 55.6], transcript: "Hi\r\nthere", open: false, color: "blue", background: "#FF8800" }));
  assert.deepEqual(a, { src: "assets/audio-1.ogg", duration: 42.6, peaks: [10, 100, 0, 0, 56], transcript: "Hi\nthere", open: false, color: "blue", background: "#ff8800" });
  assert.equal(A.clean({ src: "../etc/passwd" }).src, "", "only a file in assets");
  assert.equal(A.clean({ src: "assets/../x.ogg" }).src, "");
  assert.equal(A.clean({ src: "assets/a.ogg", color: "javascript:" }).color, "");
  assert.equal(A.clean({ duration: 1e9 }).duration, 6 * 3600);
  assert.equal(A.clean({ peaks: new Array(1000).fill(5) }).peaks.length, 400);
});

check("levels and waveforms", () => {
  assert.equal(A.levelOf(-55), 0);
  assert.equal(A.levelOf(-5), 1);
  assert.equal(A.levelOf(-30), 0.5);
  assert.equal(A.levelOf("x"), 0);
  assert.equal(A.levelIn("lavfi.astats.Overall.RMS_level=-30.0"), 0.5);
  assert.equal(A.levelIn("lavfi.astats.Overall.RMS_level=-inf"), 0, "silence");
  assert.equal(A.levelIn("frame:1    pts:1600    pts_time:0.1"), -1);
  const printed = "frame:0    pts:0       pts_time:0\nlavfi.astats.Overall.RMS_level=-55\nframe:1\nlavfi.astats.Overall.RMS_level=-5\n";
  assert.deepEqual(plain(A.levelsIn(printed)), [0, 1]);
  assert.deepEqual(plain(A.peaks([0, 0.5, 1], 120)), [0, 50, 100], "fewer than the bars: each its own");
  assert.deepEqual(plain(A.peaks([0, 0.2, 0.9, 0.1, 0.3, 0.4], 3)), [20, 90, 40], "the loudest of each share");
  assert.deepEqual(plain(A.peaks([], 10)), []);
  assert.deepEqual(plain(A.fit([10, 20, 30, 40], 2)), [20, 40]);
  assert.deepEqual(plain(A.fit([10, 50], 4)), [10, 10, 50, 50], "stretched");
});

check("voxtype's output, as the words said", () => {
  const out = 'Loading audio file: "/run/user/1000/uber-notebook/d.wav"\nAudio format: 16000 Hz, 1 channel(s), Int\nProcessing 22848 samples (1.43s)...\n\nFront, Center.\n';
  assert.equal(A.transcriptOf(out), "Front, Center.");
  assert.equal(A.transcriptOf("Loading audio file: x\nProcessing 1 samples (0s)...\n\n\n"), "", "nothing said");
  assert.equal(A.transcriptOf("\u001b[2m2026-10-02T17:50:49.442539Z\u001b[0m \u001b[32m INFO\u001b[0m Using local whisper\n [BLANK_AUDIO] \nHello  there.\n"), "Hello there.");
  assert.equal(A.transcriptOf("One.\n\nTwo (music) three."), "One.\nTwo three.");
});

check("clocks, names and words put in", () => {
  assert.equal(A.clock(0), "0:00");
  assert.equal(A.clock(7.9), "0:07");
  assert.equal(A.clock(723), "12:03");
  assert.equal(A.clock(3723), "1:02:03");
  assert.equal(A.fileName(new Date(2026, 9, 2, 10, 53, 12), "k3f"), "audio-20261002-105312-k3f.ogg");
  assert.match(A.fileName(new Date()), /^audio-\d{8}-\d{6}-[a-z0-9]+\.ogg$/);
  assert.equal(A.cleanSrc("assets/" + A.fileName(new Date())) !== "", true, "a name assets takes");
  assert.equal(A.joinAfter("", "hello  world "), "hello world");
  assert.equal(A.joinAfter("Note:", "hello"), " hello");
  assert.equal(A.joinAfter("Note: ", "hello"), "hello");
  assert.equal(A.joinAfter("x", "   "), "");
});

check("microphones, the voice made louder, and a test", () => {
  assert.equal(A.cleanInput("alsa_input.pci-0000_e6_00.3.HiFi__Mic__source"), "alsa_input.pci-0000_e6_00.3.HiFi__Mic__source");
  assert.equal(A.cleanInput("-i /etc/passwd"), "", "never an option or a path");
  assert.equal(A.cleanInput(""), "");
  const json = JSON.stringify([
    { name: "alsa_output.speaker.monitor", description: "Monitor of Speakers", monitor_of_sink: "alsa_output.speaker" },
    { name: "alsa_input.mic", description: "Internal Microphone", monitor_of_sink: null },
    { name: "bad name; rm", description: "x" },
  ]);
  assert.deepEqual(plain(A.sourcesOf(json)), [{ name: "alsa_input.mic", label: "Internal Microphone" }], "the microphones, not the monitors");
  assert.deepEqual(plain(A.sourcesOf("not json")), []);
  const c = A.recordCommand("audio", "/x/a.ogg", { input: "alsa_input.mic", boost: true });
  assert.equal(c[c.indexOf("-i") + 1], "alsa_input.mic");
  assert.ok(c[c.indexOf("-filter_complex") + 1].includes("dynaudnorm"), "the level shown is the voice made louder");
  assert.equal(c[c.indexOf("-b:a") + 1], "64k", "recorded well, to be made louder after");
  const d = A.recordCommand("audio", "/x/a.ogg", { input: "; rm -rf", boost: false });
  assert.equal(d[d.indexOf("-i") + 1], "default");
  assert.ok(!d[d.indexOf("-filter_complex") + 1].includes("dynaudnorm"));
  const t = A.recordCommand("test", "", {});
  assert.deepEqual(plain(t.slice(-3)), ["-f", "null", "-"], "a test keeps nothing");
  assert.equal(t[t.indexOf("-t") + 1], "8");
  assert.equal(A.verdict([]), "silent");
  assert.equal(A.verdict([0.01, 0.05, 0.02]), "silent");
  assert.equal(A.verdict([0.1, 0.2, 0.3, 0.25]), "quiet");
  assert.equal(A.verdict([0.1, 0.5, 0.7, 0.6, 0.65]), "good");
  assert.equal(A.verdict([1, 1, 1, 0.99]), "loud");
  assert.equal(A.isQuiet([10, 40, 55]), true);
  assert.equal(A.isQuiet([10, 80]), false);
  assert.equal(A.isQuiet([]), false);
});

check("the commands", () => {
  const d = A.recordCommand("dictation", "/run/user/1000/uber-notebook/d.wav");
  assert.equal(d[0], "/usr/bin/ffmpeg");
  assert.equal(d[d.indexOf("-t") + 1], "600");
  assert.equal(d[d.length - 1], "/run/user/1000/uber-notebook/d.wav");
  assert.ok(d.includes("pcm_s16le"));
  const a = A.recordCommand("audio", "/home/x/Pages/assets/a.ogg");
  assert.ok(a.includes("libopus"));
  assert.equal(a[a.indexOf("-t") + 1], String(3 * 3600));
  assert.equal(A.transcribeTimeout(60), 240000);
});

check("what was said, found by search and listed for agents", () => {
  const W = load("Workspace.js");
  const page = W.newPage({ title: "Standup", blocks: [{ type: "audio", audio: { src: "assets/a.ogg", duration: 61, transcript: "Ship the release notes" } }, { type: "audio" }] });
  assert.match(W.pageText(page), /Ship the release notes/);
  const listed = plain(W.blockList(page, (h) => h, () => ""));
  assert.equal(listed[0].type, "audio");
  assert.equal(listed[0].text, "Ship the release notes");
  assert.equal(listed[0].duration, 61);
  assert.equal(listed[1].text, "(an audio note, not recorded yet)");
});

console.log(`audio: ${passed} checks passed`);
