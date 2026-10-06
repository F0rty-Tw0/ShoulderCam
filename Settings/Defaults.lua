local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One ordered list drives SavedVariables defaults and both options pages
-- (values and ranges: SPEC.md → Settings). Entry kinds:
--   { page = "main" | "situations" }  starts a page
--   { header = "..." }                section title
--   { column = 2 }                    starts the main page's right column
--   { key, default, label }           checkbox
--   { key, default, label, min, max, step }  slider
-- On the Situations page `mode` places an entry in its column; `modeToggle`
-- marks the mode's own switch, which is never greyed out.
-- Labels are English source text; the pages pass them through Localization.Text.
local Defaults = {
  list = {
    { page = "main" },
    { header = "General" },
    { key = "enabled", default = true, label = "Enabled" },
    { key = "scrollSpeed", default = 20, label = "Manual scroll speed", min = 1, max = 50, step = 1 },
    { key = "transitionSpeed", default = 40, label = "Transition speed", min = 1, max = 50, step = 0.5 },
    { key = "maxDistance", default = 39, label = "Max camera distance (yd)", min = 15, max = 39, step = 0.5 },
    { header = "Shoulder offset" },
    { key = "offsetAmount", default = 1, label = "Offset amount", min = 0.5, max = 5, step = 0.5 },
    { key = "leftShoulder", default = false, label = "Left shoulder" },
    { key = "offsetTime", default = 2, label = "Offset time (s)", min = 0.25, max = 5, step = 0.25 },
    { key = "syncOffset", default = true, label = "Sync offset with zoom" },
    { column = 2 },
    { header = "Focus" },
    { key = "focusYaw", default = 1, label = "Horizontal focus strength", min = 0, max = 1, step = 0.05 },
    { key = "focusPitch", default = 0.75, label = "Vertical focus strength", min = 0, max = 1, step = 0.05 },
    { header = "Pitch" },
    { key = "pitchStrength", default = 0.4, label = "Pitch strength", min = 0, max = 1, step = 0.05 },
    { key = "pitchDown", default = 0.25, label = "Look-down strength", min = 0, max = 1, step = 0.05 },
    { key = "pitchFlying", default = 0.75, label = "Flying pitch strength", min = 0, max = 1, step = 0.05 },

    { page = "situations" },
    { header = "On foot", mode = "onFoot" },
    { key = "offsetOnFoot", default = false, label = "Shoulder offset", mode = "onFoot" },
    { key = "focusEnemyOnFoot", default = false, label = "Focus enemies", mode = "onFoot" },
    { key = "focusInteractOnFoot", default = false, label = "Focus interact", mode = "onFoot" },
    { key = "pitchOnFoot", default = true, label = "Dynamic pitch", mode = "onFoot" },
    { key = "zoomOnFoot", default = true, label = "Change camera zoom", mode = "onFoot" },
    { key = "rememberOnFoot", default = true, label = "Remember my zoom", mode = "onFoot" },
    { key = "distanceOnFoot", default = 39, label = "Distance (yd)", min = 1, max = 39, step = 0.5, mode = "onFoot" },

    { header = "Combat", mode = "combat" },
    { key = "combatEnabled", default = false, label = "Mode enabled", mode = "combat", modeToggle = true },
    { key = "offsetCombat", default = false, label = "Shoulder offset", mode = "combat" },
    { key = "focusEnemyCombat", default = false, label = "Focus enemies", mode = "combat" },
    { key = "focusInteractCombat", default = false, label = "Focus interact", mode = "combat" },
    { key = "pitchCombat", default = true, label = "Dynamic pitch", mode = "combat" },
    { key = "zoomCombat", default = true, label = "Change camera zoom", mode = "combat" },
    { key = "rememberCombat", default = true, label = "Remember my zoom", mode = "combat" },
    { key = "distanceCombat", default = 39, label = "Distance (yd)", min = 1, max = 39, step = 0.5, mode = "combat" },

    { header = "Mounted", mode = "mounted" },
    { key = "mountedEnabled", default = false, label = "Mode enabled", mode = "mounted", modeToggle = true },
    { key = "offsetMounted", default = false, label = "Shoulder offset", mode = "mounted" },
    { key = "focusEnemyMounted", default = false, label = "Focus enemies", mode = "mounted" },
    { key = "focusInteractMounted", default = false, label = "Focus interact", mode = "mounted" },
    { key = "pitchMounted", default = false, label = "Dynamic pitch", mode = "mounted" },
    { key = "zoomMounted", default = true, label = "Change camera zoom", mode = "mounted" },
    { key = "rememberMounted", default = true, label = "Remember my zoom", mode = "mounted" },
    { key = "distanceMounted", default = 36.5, label = "Distance (yd)", min = 1, max = 39, step = 0.5, mode = "mounted" },
    { key = "druidForms", default = true, label = "Druid travel forms count as mounted", mode = "mounted" },
  },
  byKey = {},
}

for _, entry in ipairs(Defaults.list) do
  if entry.key then
    Defaults.byKey[entry.key] = entry
  end
end

function Defaults.Reset(db)
  for _, entry in ipairs(Defaults.list) do
    if entry.key then
      db[entry.key] = entry.default
    end
  end
end

ns.Defaults = Defaults
return Defaults
