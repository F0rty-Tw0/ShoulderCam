local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

-- One ordered list drives SavedVariables defaults and the tabbed options
-- page (values and ranges: SPEC.md → Settings). Entry kinds:
--   { tab = "...", intro = "..." }    starts a tab (English button text)
--   { header = "..." }                section title
--   { column = 2 }                    starts the tab's right column
--   { key, default, label, hint }     checkbox
--   { key, default, label, hint, min, max, step }  slider
--   { key, default }                  stored only, never drawn
-- Sliders may add `suffix` ("yd", "s") or `percent = true` to their value
-- text. `parent` names the checkbox a row depends on: the row is indented
-- and greyed while that checkbox is off. `mode` ties a row to its mode's
-- switch (`modeToggle`), which greys the rest of that tab while off.
-- Text is English source text; the page passes it through Localization.Text.
local Defaults = {
  list = {
    { tab = "General", intro = "Turn the camera on and set zoom and shoulder basics." },
    { header = "Camera" },
    {
      key = "enabled",
      default = true,
      label = "Enable Shoulder Cam",
      hint = "Turns the shoulder camera on or off. Off puts the camera back behind you; zoom stays.",
    },
    {
      key = "minimapButton",
      default = true,
      label = "Show minimap button",
      hint = "Left-click opens these options, right-click turns the camera on or off.",
    },
    -- Degrees around the minimap, 0 = east, counter-clockwise; set by dragging.
    { key = "minimapAngle", default = 225 },
    {
      key = "scrollSpeed",
      default = 20,
      label = "Mouse wheel zoom speed",
      hint = "How fast the camera zooms when you use the mouse wheel.",
      min = 1,
      max = 50,
      step = 1,
    },
    {
      key = "transitionSpeed",
      default = 40,
      label = "Auto-zoom speed",
      hint = "How fast the camera glides to a situation's zoom distance.",
      min = 1,
      max = 50,
      step = 0.5,
    },
    {
      key = "maxDistance",
      default = 39,
      label = "Max camera distance",
      hint = "Farthest the camera can zoom out. Zoom distances above this are capped.",
      min = 15,
      max = 39,
      step = 0.5,
      suffix = "yd",
    },
    { column = 2 },
    { header = "Shoulder offset" },
    {
      key = "offsetAmount",
      default = 1,
      label = "Side offset",
      hint = "How far to the side the camera sits in over-the-shoulder view.",
      min = 0.5,
      max = 5,
      step = 0.5,
    },
    {
      key = "leftShoulder",
      default = false,
      label = "Use left shoulder",
      hint = "Puts the camera over your left shoulder instead of the right.",
    },
    {
      key = "offsetTime",
      default = 2,
      label = "Shoulder move time",
      hint = "How long the camera takes to slide onto or off the shoulder.",
      min = 0.25,
      max = 5,
      step = 0.25,
      suffix = "s",
    },
    {
      key = "syncOffset",
      default = true,
      label = "Move shoulder with zoom",
      hint = "Slides onto the shoulder in step with an auto-zoom, not on its own timer.",
    },

    { tab = "Camera feel", intro = "Strengths used by every situation that turns focus or tilt on." },
    { header = "Target focus" },
    {
      key = "focusYaw",
      default = 1,
      label = "Horizontal focus",
      hint = "How strongly the camera turns sideways toward your target.",
      min = 0,
      max = 1,
      step = 0.05,
      percent = true,
    },
    {
      key = "focusPitch",
      default = 0.75,
      label = "Vertical focus",
      hint = "How strongly the camera tilts up or down toward your target.",
      min = 0,
      max = 1,
      step = 0.05,
      percent = true,
    },
    { column = 2 },
    { header = "Camera tilt" },
    {
      key = "pitchStrength",
      default = 0.4,
      label = "Tilt amount",
      hint = "How far the camera tilts to keep your character lower on screen.",
      min = 0,
      max = 1,
      step = 0.05,
      percent = true,
    },
    {
      key = "pitchDown",
      default = 0.25,
      label = "Tilt when looking down",
      hint = "Tilt used when you look down toward the ground.",
      min = 0,
      max = 1,
      step = 0.05,
      percent = true,
    },
    {
      key = "pitchFlying",
      default = 0.75,
      label = "Tilt while flying",
      hint = "Tilt used while flying.",
      min = 0,
      max = 1,
      step = 0.05,
      percent = true,
    },
  },
  byKey = {},
}

-- The three mode tabs share their rows; only keys, defaults and the
-- Combat / Mounted switches differ.
local MODE_TABS = {
  {
    tab = "On foot",
    intro = "Camera used unless the Combat or Mounted camera is turned on and takes over.",
    mode = "onFoot",
    suffix = "OnFoot",
    defaults = { pitch = true, distance = 39 },
  },
  {
    tab = "Combat",
    intro = "Camera used in combat. When off, combat uses the On foot camera.",
    mode = "combat",
    suffix = "Combat",
    defaults = { pitch = true, distance = 39 },
    switch = {
      key = "combatEnabled",
      label = "Use a combat camera",
      hint = "Switches to the settings below while you are in combat.",
    },
  },
  {
    tab = "Mounted",
    intro = "Camera used while mounted. When off, mounted uses the Combat or On foot camera.",
    mode = "mounted",
    suffix = "Mounted",
    defaults = { pitch = false, distance = 36.5 },
    switch = {
      key = "mountedEnabled",
      label = "Use a mounted camera",
      hint = "Switches to the settings below while you are mounted.",
    },
  },
}

local function addModeTab(list, spec)
  local mode, suffix = spec.mode, spec.suffix
  local function add(entry)
    entry.mode = mode
    list[#list + 1] = entry
  end
  list[#list + 1] = { tab = spec.tab, intro = spec.intro }
  if spec.switch then
    local switch = spec.switch
    add({ key = switch.key, default = false, label = switch.label, hint = switch.hint, modeToggle = true })
  end
  add({
    key = "offset" .. suffix,
    default = false,
    label = "Over-the-shoulder view",
    hint = "Moves the camera to your shoulder. Which side and how far are on the General tab.",
  })
  add({
    key = "focusEnemy" .. suffix,
    default = false,
    label = "Turn toward enemies",
    hint = "Camera turns toward your enemy target. Strength is on the Camera feel tab.",
  })
  add({
    key = "focusInteract" .. suffix,
    default = false,
    label = "Turn toward NPCs",
    hint = "Camera turns toward the NPC or object you interact with.",
  })
  add({
    key = "pitch" .. suffix,
    default = spec.defaults.pitch,
    label = "Camera tilt",
    hint = "Tilts the camera so your character sits lower on screen.",
  })
  add({
    key = "zoom" .. suffix,
    default = true,
    label = "Zoom to set distance",
    hint = "Camera zooms to the distance below when this situation starts.",
  })
  add({
    key = "distance" .. suffix,
    default = spec.defaults.distance,
    label = "Zoom distance",
    hint = "Distance the camera zooms to. Capped by Max camera distance.",
    min = 1,
    max = 39,
    step = 0.5,
    suffix = "yd",
    parent = "zoom" .. suffix,
  })
  add({
    key = "remember" .. suffix,
    default = true,
    label = "Remember my manual zoom",
    hint = "When you zoom by hand, saves where you stop as this situation's distance.",
  })
end

for _, spec in ipairs(MODE_TABS) do
  addModeTab(Defaults.list, spec)
end
Defaults.list[#Defaults.list + 1] = {
  key = "druidForms",
  default = true,
  label = "Druid travel forms count as mounted",
  hint = "Travel, flight and aquatic forms use the mounted camera.",
  mode = "mounted",
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
