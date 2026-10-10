// Settings.js - Uber Notebook's settings: the defaults from Defaults.js with the
// user's overrides on top, validated against its SCHEMA, plus the shortcut and
// window-rule registration handed to hypr/uber-notebook.lua.
//
// Shared by Service.qml, the settings panel and tests/settings.test.cjs, so
// keep it plain JavaScript with no QML or Node APIs.
.import "Permissions.js" as Permissions

// Canonical modifier order, and Hyprland's modmask bits for each.
var MODIFIERS = ["SUPER", "CTRL", "ALT", "SHIFT"]
var MODMASK = { SHIFT: 1, CTRL: 4, ALT: 8, SUPER: 64 }
var MODIFIER_ALIASES = { CONTROL: "CTRL", META: "SUPER", WIN: "SUPER", LOGO: "SUPER", MOD4: "SUPER", MOD1: "ALT", OPTION: "ALT", CMD: "SUPER", COMMAND: "SUPER" }

// Every message hypr/uber-notebook.lua may send back. The Lua side checks the same list.
var EVENTS = ["toggle", "quick"]
var EVENT_PREFIX = "marcho78.uber-notebook|"

// The window titles Hyprland's rules match (Notebook.qml sets them).
var WINDOW_TITLE = "Uber Notebook"
var QUICK_TITLE = "Uber Notebook Quick Note"

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function isPlainObject(value) {
  return value !== null && typeof value === "object" && !Array.isArray(value)
}

// "super + n" -> { mods: ["SUPER"], key: "N", modmask: 64, text: "SUPER + N" }.
// "" -> { empty: true }. Anything that isn't a plain modifier chord -> null.
function parseShortcut(text) {
  if (typeof text !== "string") return null
  var trimmed = text.trim()
  if (trimmed === "") return { empty: true, mods: [], key: "", modmask: 0, text: "" }
  if (trimmed.length > 64) return null
  var parts = trimmed.split("+").map(function(part) { return part.trim() })
  if (parts.some(function(part) { return part === "" })) return null
  var key = parts.pop()
  if (!/^[A-Za-z0-9_]{1,32}$/.test(key)) return null
  var mods = []
  for (var i = 0; i < parts.length; i++) {
    var mod = parts[i].toUpperCase()
    if (MODIFIER_ALIASES[mod]) mod = MODIFIER_ALIASES[mod]
    if (MODIFIERS.indexOf(mod) < 0 || mods.indexOf(mod) >= 0) return null
    mods.push(mod)
  }
  mods.sort(function(a, b) { return MODIFIERS.indexOf(a) - MODIFIERS.indexOf(b) })
  var keyName = /^xf86/i.test(key) ? "XF86" + key.slice(4) : key.toUpperCase()
  var modmask = 0
  mods.forEach(function(mod) { modmask |= MODMASK[mod] })
  return { empty: false, mods: mods, key: keyName, modmask: modmask, text: mods.concat([keyName]).join(" + ") }
}

// A shortcut as the app shows it: "Super + N".
function shortcutLabel(text) {
  var shortcut = parseShortcut(text)
  if (!shortcut || shortcut.empty) return ""
  var names = { SUPER: "Super", CTRL: "Ctrl", ALT: "Alt", SHIFT: "Shift" }
  var key = shortcut.key.length === 1 ? shortcut.key : shortcut.key.charAt(0) + shortcut.key.slice(1).toLowerCase()
  return shortcut.mods.map(function(mod) { return names[mod] }).concat([key]).join(" + ")
}

// Why a shortcut can't be used, or "" when it can. A global shortcut needs a
// modifier (a bare key would be taken from every app), except the function
// keys and XF86 media keys.
function shortcutProblem(text) {
  if (typeof text !== "string" || text.trim() === "") return ""
  var shortcut = parseShortcut(text)
  if (!shortcut) return "Use modifiers and a key, like SUPER + N or CTRL + ALT + J."
  if (shortcut.mods.length === 0 && !/^(F([1-9]|1[0-9]|2[0-4])|XF86\w+)$/i.test(shortcut.key))
    return "Add a modifier (SUPER, CTRL, ALT or SHIFT): on its own, " + shortcut.key + " would stop working in every app."
  return ""
}

// "" (the default place), or a folder: absolute, or under your home ("~/…"),
// with no ".." and no control characters.
function cleanFolder(value) {
  if (typeof value !== "string") return null
  var path = value.trim()
  if (path === "") return ""
  if (path.length > 1024 || /[\u0000-\u001f\u007f]/.test(path)) return null
  if (!/^(\/|~\/)/.test(path)) return null
  if (/(^|\/)\.\.(\/|$)/.test(path)) return null
  path = path.replace(/\/+/g, "/")
  if (path.length > 1 && path.charAt(path.length - 1) === "/") path = path.slice(0, -1)
  // ("~/" alone: not a folder of its own, and "~" wouldn't be taken back.)
  if (path === "~") return null
  return path
}

// A setting's value as a command gives it (always text: `set clock 24`):
// read as its kind of setting is (Defaults.js SCHEMA.types), so "24" stays
// the text a clock takes, and "true" is true only for an on/off one.
function commandValue(value, type) {
  var v = String(value)
  if (type === "bool" && (v === "true" || v === "false")) return v === "true"
  if (type === "int" && /^-?\d{1,6}$/.test(v)) return Number(v)
  return v
}

// Profiles as they may be used: at most 30, each with an id, a name (a
// line), a folder, whether it's the demo, and its own settings kept while
// another is open (`saved`: the keys of PROFILE_KEYS, each as it may be).
var PROFILE_KEYS = ["inbox", "lastPage", "lastNotebook", "mirror", "mirrorFolder"]
function cleanProfiles(value, schema) {
  if (!Array.isArray(value)) return null
  var out = []
  var seen = {}
  value.slice(0, 30).forEach(function(p) {
    if (!isPlainObject(p) || typeof p.id !== "string" || !/^[a-z0-9-]{1,40}$/.test(p.id) || seen[p.id]) return
    var name = typeof p.name === "string" ? p.name.replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim().slice(0, 60) : ""
    var folder = cleanFolder(p.folder)
    if (!name || folder === null) return
    var saved = {}
    if (isPlainObject(p.saved)) PROFILE_KEYS.forEach(function(k) {
      if (p.saved[k] === undefined) return
      var checked = validValue(k, p.saved[k], undefined, schema)
      if (checked.ok) saved[k] = checked.value
    })
    seen[p.id] = true
    var kept = { id: p.id, name: name, folder: folder, demo: p.demo === true, saved: saved }
    // (Its folder not opened yet: Profiles.make.)
    if (p.fresh === true) kept.fresh = true
    out.push(kept)
  })
  return out
}

// The folder as a real path: "~/x" under home, "" as the default place.
function resolveFolder(folder, home, hasDocuments) {
  var clean = cleanFolder(folder)
  if (clean === null || clean === "") return (hasDocuments ? home + "/Documents" : home) + "/Uber Notebook"
  if (clean.indexOf("~/") === 0) return home + clean.slice(1)
  return clean
}

function validValue(key, value, fallback, schema) {
  var types = (schema && schema.types) || {}
  var choices = (schema && schema.choices) || {}
  var ranges = (schema && schema.ranges) || {}
  var type = types[key] || typeof fallback

  if (type === "bool") return typeof value === "boolean" ? { ok: true, value: value } : { ok: false }
  if (type === "int") {
    if (typeof value !== "number" || !isFinite(value) || Math.floor(value) !== value) return { ok: false }
    if (choices[key] && choices[key].indexOf(value) < 0) return { ok: false }
    if (ranges[key]) value = Math.min(ranges[key][1], Math.max(ranges[key][0], value))
    return { ok: true, value: value }
  }
  if (type === "shortcut") {
    var shortcut = parseShortcut(value)
    return shortcut && shortcutProblem(value) === "" ? { ok: true, value: shortcut.text } : { ok: false }
  }
  if (type === "folder") {
    var folder = cleanFolder(value)
    return folder === null ? { ok: false } : { ok: true, value: folder }
  }
  if (type === "permissions") {
    return Array.isArray(value) ? { ok: true, value: Permissions.clean(value) } : { ok: false }
  }
  if (type === "profiles") {
    var list = cleanProfiles(value, schema)
    return list === null ? { ok: false } : { ok: true, value: list }
  }
  // A list of names ("projects", "tags"): an array, or the same with commas
  // between them (as `set` gives it); lowercase names only, each once.
  if (type === "list") {
    var items = typeof value === "string" ? value.split(",") : value
    if (!Array.isArray(items)) return { ok: false }
    var names = []
    for (var n = 0; n < items.length && names.length < 40; n++) {
      var item = String(items[n] === undefined || items[n] === null ? "" : items[n]).trim()
      if (!item) continue
      if (!/^[a-z][a-z0-9-]{0,23}$/.test(item)) return { ok: false }
      if (names.indexOf(item) < 0) names.push(item)
    }
    return { ok: true, value: names }
  }
  if (type === "id") {
    return typeof value === "string" && /^[a-z0-9-]{0,80}$/.test(value) ? { ok: true, value: value } : { ok: false }
  }
  if (typeof value !== "string" || value.length > 64) return { ok: false }
  if (choices[key] && choices[key].indexOf(value) < 0) return { ok: false }
  return { ok: true, value: value }
}

// Defaults with the user's overrides on top. Unknown keys and invalid values
// are dropped, so a hand-edited shell.json can never feed bad data onwards.
function merge(defaults, user, schema) {
  var settings = clone(defaults || {})
  user = isPlainObject(user) ? user : {}
  Object.keys(settings).forEach(function(key) {
    if (user[key] === undefined || user[key] === null) return
    var checked = validValue(key, user[key], settings[key], schema)
    if (checked.ok) settings[key] = checked.value
  })
  return settings
}

// Only what differs from the defaults, so plugin updates can improve them.
function overrides(defaults, settings) {
  var out = {}
  Object.keys(defaults || {}).forEach(function(key) {
    if (settings[key] === undefined) return
    if (JSON.stringify(settings[key]) !== JSON.stringify(defaults[key])) out[key] = clone(settings[key])
  })
  return out
}

// Uber Notebook's own entry, without its id, from the copy of the bar configuration
// the Omarchy shell hands plugins (its `barConfig`). With its bar icon, the
// entry lives in bar.layout, where updateEntryInline() writes it.
function entryInBar(barConfig, pluginId) {
  var layout = isPlainObject(barConfig) && isPlainObject(barConfig.layout) ? barConfig.layout : {}
  var sections = ["left", "center", "right"]
  for (var s = 0; s < sections.length; s++) {
    var entries = Array.isArray(layout[sections[s]]) ? layout[sections[s]] : []
    for (var i = 0; i < entries.length; i++) {
      var entry = entries[i]
      if (isPlainObject(entry) && entry.id === pluginId) {
        var copy = clone(entry)
        delete copy.id
        return copy
      }
    }
  }
  return {}
}

// ---- Hyprland --------------------------------------------------------------------

var BIND_SUFFIX = " (Uber Notebook)"

function wantedBinds(settings) {
  var out = []
  var toggle = parseShortcut(settings ? settings.shortcut : "")
  if (toggle && !toggle.empty)
    out.push({ keys: toggle.text, key: toggle.key, modmask: toggle.modmask, event: "toggle", description: "Open or close the notebook" })
  var quick = parseShortcut(settings ? settings.quickShortcut : "")
  if (quick && !quick.empty && (!toggle || quick.text !== toggle.text))
    out.push({ keys: quick.text, key: quick.key, modmask: quick.modmask, event: "quick", description: "Jot a quick note" })
  return out
}

// Splits the wanted binds into those that are free and those some other bind
// already uses. hyprBinds is the parsed output of `hyprctl -j binds`. When
// that couldn't be read, no bind is known to be free, so none is: every one
// comes back taken, marked unknown, rather than possibly doubling one of yours.
function checkBinds(wanted, hyprBinds) {
  var taken = []
  var free = []
  if (!Array.isArray(hyprBinds)) {
    wanted.forEach(function(bind) {
      taken.push({ keys: bind.keys, event: bind.event, description: bind.description, usedBy: "", unknown: true })
    })
    return { free: free, taken: taken }
  }
  wanted.forEach(function(bind) {
    var clash = null
    for (var i = 0; i < hyprBinds.length; i++) {
      var other = hyprBinds[i]
      if (!other || other.mouse === true) continue
      if (String(other.submap || "") !== "") continue
      var description = String(other.description || "")
      if (description.length >= BIND_SUFFIX.length && description.slice(-BIND_SUFFIX.length) === BIND_SUFFIX) continue
      if (Number(other.modmask) === bind.modmask && String(other.key || "").toUpperCase() === bind.key.toUpperCase()) {
        clash = description || String(other.dispatcher || "another binding")
        break
      }
    }
    if (clash) taken.push({ keys: bind.keys, event: bind.event, description: bind.description, usedBy: clash })
    else free.push(bind)
  })
  return { free: free, taken: taken }
}

// Options for hypr/uber-notebook.lua. Everything in here is a validated number,
// boolean, or string from a fixed set, so it can be written out as Lua.
function hyprOptions(freeBinds, settings) {
  var s = settings || {}
  var width = typeof s.width === "number" && isFinite(s.width) ? Math.round(s.width) : 1320
  var height = typeof s.height === "number" && isFinite(s.height) ? Math.round(s.height) : 900
  return {
    binds: (freeBinds || []).filter(function(bind) {
      return EVENTS.indexOf(bind.event) >= 0 && /^[A-Za-z0-9_ +]{1,64}$/.test(bind.keys)
    }).map(function(bind) {
      return { keys: bind.keys, event: bind.event, description: bind.description + BIND_SUFFIX }
    }),
    window: {
      floating: s.floating !== false,
      width: Math.max(640, Math.min(5000, width)),
      height: Math.max(480, Math.min(4000, height))
    }
  }
}

// The same, from the module's text (kept as Uber Notebook started): what's
// run as it stops, when its folder may be gone already (`omarchy plugin
// remove` moves it away as soon as it's unloaded).
function hyprRegistrationText(source, options) {
  return "return load(" + luaString(source) + ")()(" + luaLiteral(options) + ")"
}

function luaString(text) {
  var out = "\""
  var value = String(text)
  for (var i = 0; i < value.length; i++) {
    var c = value.charAt(i)
    var code = value.charCodeAt(i)
    if (c === "\\" || c === "\"") out += "\\" + c
    else if (code >= 32 && code < 127) out += c
    else if (code < 128) out += "\\" + ("00" + code).slice(-3)
    else {
      // UTF-8 encode anything else (only file paths can contain it).
      var bytes = unescape(encodeURIComponent(c + (code >= 0xd800 && code < 0xdc00 ? value.charAt(++i) : "")))
      for (var j = 0; j < bytes.length; j++) out += "\\" + ("00" + bytes.charCodeAt(j)).slice(-3)
    }
  }
  return out + "\""
}

function luaLiteral(value) {
  if (value === null || value === undefined) return "nil"
  if (typeof value === "boolean") return value ? "true" : "false"
  if (typeof value === "number") return isFinite(value) ? String(value) : "0"
  if (typeof value === "string") return luaString(value)
  if (Array.isArray(value)) return "{" + value.map(luaLiteral).join(", ") + "}"
  if (isPlainObject(value)) {
    return "{" + Object.keys(value).filter(function(key) {
      return /^[A-Za-z_][A-Za-z0-9_]*$/.test(key)
    }).map(function(key) {
      return key + " = " + luaLiteral(value[key])
    }).join(", ") + "}"
  }
  return "nil"
}

// The code `hyprctl eval` runs: load hypr/uber-notebook.lua from the plugin and
// register with the given options. Returns the module's status string.
function hyprRegistration(moduleFile, options) {
  return "return dofile(" + luaString(moduleFile) + ")(" + luaLiteral(options) + ")"
}

// "marcho78.uber-notebook|toggle" → { type: "command", command: "toggle" };
// null for anything else.
function parseEvent(data) {
  var text = String(data || "")
  if (text.length > 80 || text.indexOf(EVENT_PREFIX) !== 0) return null
  var command = text.slice(EVENT_PREFIX.length)
  return EVENTS.indexOf(command) >= 0 ? { type: "command", command: command } : null
}

// ---- the app launcher ---------------------------------------------------------------

// Uber Notebook's entry in ~/.local/share/applications, so it's in the app
// launcher with its icon; "" when the plugin's folder isn't a plain absolute
// path. Backslashes are escaped as the Desktop Entry spec asks.
function desktopEntry(pluginDir) {
  var dir = String(pluginDir || "")
  if (!/^\/[^\u0000-\u001f\u007f]{1,4000}$/.test(dir)) return ""
  return "[Desktop Entry]\n"
    + "Type=Application\n"
    + "Name=Uber Notebook\n"
    + "GenericName=Notebook\n"
    + "Comment=Notebooks that look and feel like paper\n"
    + "Exec=/usr/bin/omarchy-shell uber-notebook show\n"
    + "Icon=" + dir.replace(/\\/g, "\\\\") + "/icon.svg\n"
    + "Terminal=false\n"
    + "Categories=Office;\n"
    + "Keywords=notes;notebook;journal;diary;paper;writing;sketch;\n"
    + "StartupNotify=false\n"
}

