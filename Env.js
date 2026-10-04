// Env.js - the environment Uber Notebook's commands run in.
//
// The programs Uber Notebook runs (Run.qml, Stream.qml) don't inherit the
// shell's whole environment. A tool's own command gets only what it needs to
// find your session (your home, your language, the Wayland, D-Bus and
// PipeWire sockets, Hyprland's instance, a proxy you set), with PATH as the
// system's: nothing that changes how a shell, a library or a tool starts
// (BASH_ENV, LD_PRELOAD, TAR_OPTIONS, CURL_HOME...). An agent (Claude Code,
// Grok, Codex) is your own program, set up your way, so it gets your
// environment, without what would change how a program starts.
//
// Shared by Run.qml, Stream.qml and tests/env.test.cjs, so keep it plain
// JavaScript with no QML or Node APIs.
.pragma library

var PATH = "/usr/bin"

// What a tool's command gets, from the shell's environment.
var TOOLS = [
  "HOME", "USER", "LOGNAME", "LANG", "LANGUAGE", "LC_ALL", "LC_CTYPE", "LC_MESSAGES", "LC_TIME", "LC_NUMERIC", "LC_COLLATE", "TZ",
  "XDG_RUNTIME_DIR", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_CACHE_HOME", "XDG_STATE_HOME", "XDG_DATA_DIRS", "XDG_CONFIG_DIRS",
  "XDG_CURRENT_DESKTOP", "XDG_SESSION_TYPE", "XDG_SESSION_DESKTOP", "DESKTOP_SESSION",
  "WAYLAND_DISPLAY", "DISPLAY", "DBUS_SESSION_BUS_ADDRESS", "HYPRLAND_INSTANCE_SIGNATURE", "PULSE_SERVER", "PIPEWIRE_REMOTE",
  "http_proxy", "https_proxy", "no_proxy", "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY"
]

// What's never passed on, to an agent either: what makes the dynamic linker,
// a shell, an interpreter or a tool run something else as it starts.
var NEVER = ["LD_PRELOAD", "LD_LIBRARY_PATH", "LD_AUDIT", "LD_DEBUG", "LD_PROFILE", "BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS",
  "PROMPT_COMMAND", "CDPATH", "GLOBIGNORE", "PS4", "PYTHONSTARTUP", "PYTHONPATH", "PYTHONHOME", "PYTHONINSPECT", "NODE_OPTIONS",
  "NODE_PATH", "PERL5OPT", "PERL5LIB", "PERLLIB", "RUBYOPT", "RUBYLIB", "TAR_OPTIONS", "UNZIP", "UNZIPOPT", "ZIPOPT", "CURL_HOME",
  "GCONV_PATH", "LOCPATH", "GLIBC_TUNABLES", "MALLOC_CHECK_", "MALLOC_PERTURB_"]

function allowedValue(value) {
  return typeof value === "string" && value.length > 0 && value.length <= 32768 && value.indexOf("\u0000") < 0
}

// A tool's environment: { name: value }, for a process that starts with an
// empty one. `get(name)` reads the shell's.
function forTools(get) {
  var out = {}
  TOOLS.forEach(function(name) {
    var v = get(name)
    if (allowedValue(v)) out[name] = v
  })
  out.PATH = PATH
  return out
}

// An agent's: the shell's environment, but what NEVER names ({ name: null },
// for a process that starts with the shell's).
function forAgent() {
  var out = {}
  NEVER.forEach(function(name) { out[name] = null })
  return out
}
