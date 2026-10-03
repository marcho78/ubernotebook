-- Uber Notebook (marcho78.uber-notebook): the Hyprland half.
--
-- The service runs this inside Hyprland with `hyprctl eval` when the shell
-- starts, after every Hyprland config reload, and when the settings change:
--
--   return dofile("<plugin>/hypr/uber-notebook.lua")({ binds = { ... }, window = { ... } })
--
-- It registers the keyboard shortcuts, which send a message to the service
-- over Hyprland's event socket (hl.dsp.event), and the window rules for the
-- notebook window, the quick-note card and the picture picker: floating in
-- the middle of the screen at the size you picked (or tiling, if you turned
-- floating off), and always fully opaque, since paper isn't see-through. Nothing here runs
-- programs or reads or writes files. Your Hyprland config is never edited: a
-- config reload drops all of this, and the service registers again.
--
-- Anything that didn't register is raised as an error: `hyprctl eval` shows
-- only "ok" for a returned value, but prints an error and fails, so the
-- settings can say what went wrong.

local PREFIX = "marcho78.uber-notebook|"
local EVENTS = { toggle = true, quick = true }
local STATE = "__marcho78_uber_notebook"
local CLASS = "^org\\.quickshell$"
local MAIN_TITLE = "^Uber Notebook$"
local QUICK_TITLE = "^Uber Notebook Quick Note$"
local PICKER_TITLE = "^(Choose a picture|Import notes|Import a folder of notes|Export to)$"

return function(options)
  options = type(options) == "table" and options or {}

  -- What earlier runs registered in this Lua state (a config reload starts a
  -- fresh one). Shortcuts are replaced every time. Hyprland can't delete a
  -- window rule, only switch it off, so each distinct set of rules is made
  -- once, kept under a key, and switched on or off after that.
  local state = rawget(_G, STATE)
  if type(state) ~= "table" then
    state = { binds = {}, rules = {} }
    rawset(_G, STATE, state)
  end
  for _, bind in ipairs(state.binds or {}) do pcall(function() bind:remove() end) end
  state.binds = {}
  state.rules = type(state.rules) == "table" and state.rules or {}
  for _, set in pairs(state.rules) do
    for _, rule in ipairs(set) do pcall(function() rule:set_enabled(false) end) end
  end

  local problems = {}
  local function problem(text)
    problems[#problems + 1] = tostring(text):gsub("[\r\n|;]", " ")
  end

  if options.remove == true then return "ok" end

  -- The window rules.
  local window = type(options.window) == "table" and options.window or {}
  local floating = window.floating ~= false
  local width = math.floor(tonumber(window.width) or 1320)
  local height = math.floor(tonumber(window.height) or 900)
  if width < 640 or width > 5000 then width = 1320 end
  if height < 480 or height > 4000 then height = 900 end
  local key = (floating and "float" or "tile") .. ":" .. width .. "x" .. height

  local set = state.rules[key]
  if set then
    for _, rule in ipairs(set) do pcall(function() rule:set_enabled(true) end) end
  else
    set = {}
    local function add(label, spec)
      local ok, rule = pcall(hl.window_rule, spec)
      if ok and rule then set[#set + 1] = rule else problem(label .. ": " .. tostring(rule)) end
    end

    -- Paper isn't see-through: keep the notebook fully opaque, like Omarchy
    -- does for video players.
    add("notebook opacity", { match = { class = CLASS, title = MAIN_TITLE }, tag = "-default-opacity", opacity = "1 1" })
    if floating then
      add("notebook window", { match = { class = CLASS, title = MAIN_TITLE }, float = true, center = true, size = { width, height } })
    end
    -- The file picker for pictures floats over the notebook.
    add("picture picker", { match = { class = CLASS, title = PICKER_TITLE }, float = true, center = true, size = { 980, 640 } })
    -- The quick note is a sticky note that floats wherever you are: its
    -- window is see-through around the note, so no border, shadow, blur or
    -- title bar of Hyprland's own.
    add("quick note", {
      match = { class = CLASS, title = QUICK_TITLE },
      float = true,
      center = true,
      size = { 520, 440 },
      tag = "-default-opacity",
      opacity = "1 1",
      border_size = 0,
      no_shadow = true,
      no_blur = true,
      decorate = false,
    })
    state.rules[key] = set
  end

  for _, bind in ipairs(type(options.binds) == "table" and options.binds or {}) do
    local keys = type(bind) == "table" and bind.keys or nil
    local event = type(bind) == "table" and bind.event or nil
    local description = type(bind) == "table" and bind.description or ""
    if type(keys) ~= "string" or #keys > 64 or not keys:match("^[%w_ %+]+$") then
      problem("skipped a shortcut with invalid keys")
    elseif not EVENTS[event] then
      problem("skipped " .. keys .. ": unknown action")
    else
      if type(description) ~= "string" or #description > 80 or not description:match("^[%w%p ]*$") then
        description = "Uber Notebook"
      end
      local done, handle = pcall(hl.bind, keys, hl.dsp.event(PREFIX .. event), { description = description })
      if done and handle then
        state.binds[#state.binds + 1] = handle
      else
        -- Hyprland turns down a key it doesn't know without an error.
        problem(keys .. ": " .. (done and "Hyprland didn't take it (is the key name right?)" or tostring(handle)))
      end
    end
  end

  if #problems == 0 then return "ok" end
  error(table.concat(problems, "; "), 0)
end
