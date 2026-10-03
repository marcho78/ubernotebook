-- Runs hypr/uber-notebook.lua against a fake Hyprland API.
-- Usage (from the plugin directory): lua tests/hypr.test.lua
package.path = "./tests/?.lua;" .. package.path
local fake = require("fake_hl")
local register = dofile("hypr/uber-notebook.lua")

local passed = 0
local function check(condition, message)
  if not condition then error("FAILED: " .. message, 2) end
  passed = passed + 1
end

local function find_rule(title, field)
  for _, rule in ipairs(fake.enabled_rules()) do
    if rule.spec.match.title == title and rule.spec[field] ~= nil then return rule end
  end
  return nil
end

local options = {
  binds = {
    { keys = "SUPER + N", event = "toggle", description = "Open or close the notebook (Uber Notebook)" },
    { keys = "SUPER + ALT + N", event = "quick", description = "Jot a quick note (Uber Notebook)" },
  },
  window = { floating = true, width = 1320, height = 900 },
}

check(register(options) == "ok", "registers cleanly")
check(#fake.active_binds() == 2, "two shortcuts")
check(#fake.enabled_rules() == 4, "opacity, notebook window, picture picker and quick note rules")
local placed = find_rule("^Uber Notebook$", "float")
check(placed and placed.spec.center == true, "the notebook floats in the middle")
check(placed.spec.size[1] == 1320 and placed.spec.size[2] == 900, "at the size in the settings")
check(placed.spec.match.class == "^org\\.quickshell$", "matched on Quickshell's windows only")
local opaque = find_rule("^Uber Notebook$", "opacity")
check(opaque and opaque.spec.opacity == "1 1" and opaque.spec.tag == "-default-opacity", "paper is never see-through")
check(find_rule("^Uber Notebook Quick Note$", "float"), "the quick note floats")
local card = find_rule("^Uber Notebook Quick Note$", "float")
check(card.spec.border_size == 0 and card.spec.no_shadow and card.spec.decorate == false, "the quick note is just the note")
check(find_rule("^(Choose a picture|Import notes|Import a folder of notes|Export to)$", "float"), "the picture picker and the import and export dialogs float")

-- Registering again replaces the shortcuts and reuses the rules, so nothing piles up.
check(register(options) == "ok", "registers again")
check(#fake.active_binds() == 2, "still two shortcuts")
check(#fake.rules == 4, "the same four rules, not new ones")
check(#fake.enabled_rules() == 4, "all still on")

-- The shortcuts send their events.
fake.events = {}
for _, bind in ipairs(fake.active_binds()) do hl.dispatch(bind.dispatcher) end
table.sort(fake.events)
check(fake.events[1] == "marcho78.uber-notebook|quick" and fake.events[2] == "marcho78.uber-notebook|toggle", "each shortcut sends its event")

-- A new size makes a new set of rules and switches the old set off.
check(register({ binds = options.binds, window = { floating = true, width = 1000, height = 700 } }) == "ok", "resizes")
check(#fake.rules == 8, "a new set")
check(#fake.enabled_rules() == 4, "only one set on")
check(find_rule("^Uber Notebook$", "float").spec.size[1] == 1000, "at the new size")

-- Tiling: no float rule for the notebook, but it stays opaque.
check(register({ binds = options.binds, window = { floating = false, width = 1000, height = 700 } }) == "ok", "tiles")
check(find_rule("^Uber Notebook$", "float") == nil, "the notebook tiles")
check(find_rule("^Uber Notebook$", "opacity") ~= nil, "and stays opaque")

-- Going back to an earlier set switches it back on instead of making it again.
local before = #fake.rules
check(register(options) == "ok", "back to the first size")
check(#fake.rules == before, "no new rules")
check(find_rule("^Uber Notebook$", "float").spec.size[1] == 1320, "the first set is back on")

-- Nonsense sizes fall back to the defaults.
check(register({ window = { floating = true, width = 99999, height = -3 } }) == "ok", "bad sizes")
check(find_rule("^Uber Notebook$", "float").spec.size[1] == 1320 and find_rule("^Uber Notebook$", "float").spec.size[2] == 900, "use the defaults")

-- Bad input is skipped, never registered, and reported as an error (the only
-- thing `hyprctl eval` passes on besides "ok").
local ok, err = pcall(register, { binds = {
  { keys = "SUPER + N; exec rm", event = "toggle" },
  { keys = "SUPER + X", event = "exec" },
  { keys = "SUPER + Y", event = "toggle", description = "bad\ndescription" },
} })
check(not ok, "problems are raised")
check(tostring(err):find("invalid keys", 1, true) and tostring(err):find("unknown action", 1, true), "and named: " .. tostring(err))
check(#fake.active_binds() == 1, "only the valid bind")
check(fake.active_binds()[1].options.description == "Uber Notebook", "a bad description is replaced")

-- A bind Hyprland refuses is reported too.
local realBind = hl.bind
hl.bind = function() error("Unknown keysym NN") end
local refused, message = pcall(register, { binds = { { keys = "SUPER + NN", event = "toggle" } } })
hl.bind = realBind
check(not refused and tostring(message):find("Unknown keysym", 1, true), "refused binds are named: " .. tostring(message))

-- A key Hyprland doesn't know is turned down without an error; still reported.
hl.bind = function() return nil end
local unknown, why = pcall(register, { binds = { { keys = "SUPER + NN", event = "toggle" } } })
hl.bind = realBind
check(not unknown and tostring(why):find("didn't take it", 1, true), "unknown keys are named: " .. tostring(why))

-- Removing takes everything back out; registering again turns the rules back on.
check(register({ remove = true }) == "ok", "removes")
check(#fake.active_binds() == 0, "no shortcuts left")
check(#fake.enabled_rules() == 0, "no rules left on")
check(register(options) == "ok", "registers after removing")
check(#fake.enabled_rules() == 4, "the rules come back on")

print(("hypr: %d checks passed"):format(passed))
