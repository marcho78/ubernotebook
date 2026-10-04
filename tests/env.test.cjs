// Checks the environment Uber Notebook's commands get (Env.js).
// Usage (from the plugin directory): node tests/env.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Env = load("Env.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const shell = {
  HOME: "/home/me", LANG: "en_US.UTF-8", XDG_RUNTIME_DIR: "/run/user/1000", WAYLAND_DISPLAY: "wayland-1",
  DBUS_SESSION_BUS_ADDRESS: "unix:path=/run/user/1000/bus", HYPRLAND_INSTANCE_SIGNATURE: "abc", HTTPS_PROXY: "http://proxy:3128",
  PATH: "/home/me/evil:/usr/bin", BASH_ENV: "/home/me/.evil", LD_PRELOAD: "/tmp/x.so", TAR_OPTIONS: "--to-command=sh",
  CURL_HOME: "/tmp", ANTHROPIC_API_KEY: "sk-...", NUL: "a\u0000b", EMPTY: ""
};

check("a tool's command: only what finds your session, PATH as the system's", () => {
  const env = plain(Env.forTools((name) => shell[name]));
  assert.deepEqual(Object.keys(env).sort(), ["DBUS_SESSION_BUS_ADDRESS", "HOME", "HTTPS_PROXY", "HYPRLAND_INSTANCE_SIGNATURE", "LANG", "PATH", "WAYLAND_DISPLAY", "XDG_RUNTIME_DIR"]);
  assert.equal(env.PATH, "/usr/bin", "never the shell's PATH");
  assert.equal(env.HOME, "/home/me");
  for (const bad of ["BASH_ENV", "LD_PRELOAD", "TAR_OPTIONS", "CURL_HOME", "ANTHROPIC_API_KEY"]) assert.equal(env[bad], undefined, bad);
  assert.equal(plain(Env.forTools(() => "a\u0000b")).HOME, undefined, "a value with a NUL isn't one");
  assert.equal(plain(Env.forTools(() => null)).HOME, undefined);
});

check("an agent: the shell's, without what changes how programs start", () => {
  const unset = plain(Env.forAgent());
  for (const name of ["BASH_ENV", "LD_PRELOAD", "LD_LIBRARY_PATH", "TAR_OPTIONS", "NODE_OPTIONS", "PYTHONPATH", "CURL_HOME"]) assert.equal(unset[name], null, name);
  for (const name of ["HOME", "PATH", "ANTHROPIC_API_KEY"]) assert.ok(!(name in unset), name + " stays");
});


console.log(`env: ${passed} checks passed`);
