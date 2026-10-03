-- A small stand-in for Hyprland's Lua API: just enough of hl.* for
-- hypr/uber-notebook.lua, recording what it registers. Like Hyprland's, window
-- rules can only be switched off, never removed; binds can be removed.
local fake = { binds = {}, rules = {}, events = {} }

hl = {
  dsp = {
    event = function(message)
      assert(type(message) == "string", "hl.dsp.event takes a string")
      return { kind = "event", message = message }
    end,
  },
  dispatch = function(dispatcher)
    assert(type(dispatcher) == "table" and dispatcher.kind == "event", "only events are dispatched")
    fake.events[#fake.events + 1] = dispatcher.message
  end,
  bind = function(keys, dispatcher, options)
    assert(type(keys) == "string")
    local handle = { keys = keys, dispatcher = dispatcher, options = options }
    function handle:remove() fake.binds[self] = nil end
    fake.binds[handle] = true
    return handle
  end,
  window_rule = function(spec)
    assert(type(spec.match) == "table", "window rules match something")
    local rule = { spec = spec, enabled = true }
    function rule:set_enabled(value) self.enabled = value end
    fake.rules[#fake.rules + 1] = rule
    return rule
  end,
}

function fake.active_binds()
  local out = {}
  for handle in pairs(fake.binds) do out[#out + 1] = handle end
  table.sort(out, function(a, b) return a.keys < b.keys end)
  return out
end

function fake.enabled_rules()
  local out = {}
  for _, rule in ipairs(fake.rules) do
    if rule.enabled then out[#out + 1] = rule end
  end
  return out
end

return fake
