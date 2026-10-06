local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local FlavorCompat = ns.FlavorCompat or require("ShoulderCam.Core.FlavorCompat")
local Constants = ns.Constants or require("ShoulderCam.Core.Constants")
local CVar = ns.CVar or require("ShoulderCam.Core.CVar")
local Mode = ns.Mode or require("ShoulderCam.Camera.Mode")
local Offset = ns.Offset or require("ShoulderCam.Camera.Offset")
local Zoom = ns.Zoom or require("ShoulderCam.Camera.Zoom")
local ZoomMemory = ns.ZoomMemory or require("ShoulderCam.Camera.ZoomMemory")

local ipairs = ipairs
local min = math.min
local pairs = pairs
local select = select

local ZOOM_FACTOR_YARDS = Constants.ZOOM_FACTOR_YARDS
local ENEMY_CVAR = "test_cameraTargetFocusEnemyEnable"
local INTERACT_CVAR = "test_cameraTargetFocusInteractEnable"
local PITCH_CVAR = "test_cameraDynamicPitch"
local ZOOM_SPEED_CVAR = "cameraZoomSpeed"
local DEFAULTS_KEY = "*defaults"

-- Written on every apply while not Off: { CVar, setting key }.
local GLOBAL_CVARS = {
  { "test_cameraTargetFocusEnemyStrengthYaw", "focusYaw" },
  { "test_cameraTargetFocusInteractStrengthYaw", "focusYaw" },
  { "test_cameraTargetFocusEnemyStrengthPitch", "focusPitch" },
  { "test_cameraTargetFocusInteractStrengthPitch", "focusPitch" },
  { "test_cameraDynamicPitchBaseFovPad", "pitchStrength" },
  { "test_cameraDynamicPitchBaseFovPadDownScale", "pitchDown" },
  { "test_cameraDynamicPitchBaseFovPadFlying", "pitchFlying" },
}

-- Settings that change which events can switch the mode.
local EVENT_KEYS = { enabled = true, combatEnabled = true, mountedEnabled = true, druidForms = true, [DEFAULTS_KEY] = true }

-- Applies the active mode (SPEC.md → Modes, Zoom, Shoulder offset animation)
-- on mode-changing events and settings changes. `onRemembered(key)` is set by
-- Bootstrap to refresh the settings page after a remembered distance is saved.
local Controller = { onRemembered = nil }

local db
local frame
local registered = {}
local activeMode

local function flag(value)
  return value and 1 or 0
end

local function updateEvents()
  local isDruid = select(2, _G.UnitClass("player")) == "DRUID"
  local wanted = Mode.Events(db, isDruid)
  for event in pairs(registered) do
    if not wanted[event] then
      frame:UnregisterEvent(event)
      registered[event] = nil
    end
  end
  for event in pairs(wanted) do
    if not registered[event] then
      frame:RegisterEvent(event)
      registered[event] = true
    end
  end
end

local function applyOff()
  Zoom.Cancel()
  ZoomMemory.Cancel()
  Offset.MoveTo(0, 0)
  CVar.Set(ENEMY_CVAR, 0)
  CVar.Set(INTERACT_CVAR, 0)
  CVar.Set(PITCH_CVAR, 0)
end

local function applyGlobals()
  CVar.Set("CameraKeepCharacterCentered", 0)
  CVar.Set("CameraReduceUnexpectedMovement", 0)
  for _, pair in ipairs(GLOBAL_CVARS) do
    CVar.Set(pair[1], db[pair[2]])
  end
  CVar.Set("cameraDistanceMaxZoomFactor", db.maxDistance / ZOOM_FACTOR_YARDS)
end

local function zoomSettingChanged(suffix, key)
  return key == "zoom" .. suffix or key == "distance" .. suffix or key == "maxDistance" or key == DEFAULTS_KEY
end

-- Returns the started zoom transition's duration, or nil.
local function zoomTo(suffix)
  if not db["zoom" .. suffix] then
    return nil
  end
  local target = min(db["distance" .. suffix], db.maxDistance)
  return Zoom.To(target, db.transitionSpeed, db.scrollSpeed)
end

local function applyMode(suffix, zoomAllowed)
  CVar.Set(ENEMY_CVAR, flag(db["focusEnemy" .. suffix]))
  CVar.Set(INTERACT_CVAR, flag(db["focusInteract" .. suffix]))
  CVar.Set(PITCH_CVAR, flag(db["pitch" .. suffix]))
  local zoomDuration = zoomAllowed and zoomTo(suffix) or nil
  local offset = 0
  if db["offset" .. suffix] then
    offset = db.leftShoulder and -db.offsetAmount or db.offsetAmount
  end
  local duration = db.offsetTime
  if db.syncOffset and zoomDuration then
    duration = zoomDuration
  end
  Offset.MoveTo(offset, duration)
end

function Controller.Apply(reason, key)
  if not FlavorCompat.hasActionCam then
    return
  end
  local mode = Mode.Resolve(db, Mode.ReadState())
  -- An event that keeps the mode (e.g. combat while mounted) has nothing to apply.
  if reason == "event" and mode == activeMode then
    return
  end
  local changed = mode ~= activeMode
  if changed then
    ZoomMemory.Cancel()
  end
  activeMode = mode
  if mode == "off" then
    applyOff()
    return
  end
  applyGlobals()
  local suffix = Mode.SUFFIX[mode]
  applyMode(suffix, changed or reason == "enter_world" or zoomSettingChanged(suffix, key))
end

function Controller.OnSettingChanged(key)
  if not FlavorCompat.hasActionCam then
    return
  end
  if EVENT_KEYS[key] then
    updateEvents()
  end
  if key == "scrollSpeed" or key == DEFAULTS_KEY then
    CVar.Set(ZOOM_SPEED_CVAR, db.scrollSpeed)
  end
  Controller.Apply("setting", key)
end

function Controller.ActiveMode()
  return activeMode
end

local function onEvent(_self, event)
  if event == "PLAYER_ENTERING_WORLD" then
    Controller.Apply("enter_world")
  else
    Controller.Apply("event")
  end
end

-- A manual zoom binds the remember-zoom save to the mode active right now.
local function onManualZoom()
  local suffix = Mode.SUFFIX[activeMode]
  if suffix and db["remember" .. suffix] then
    ZoomMemory.Start(suffix)
  end
end

-- Writes the setting only: a remembered distance never triggers a zoom.
local function onSave(suffix, distance)
  local key = "distance" .. suffix
  db[key] = distance
  if Controller.onRemembered then
    Controller.onRemembered(key)
  end
end

-- Call once: Zoom.Install hooks the camera functions again on every call.
-- The first apply comes from PLAYER_ENTERING_WORLD.
function Controller.Install(settings)
  if not FlavorCompat.hasActionCam then
    return
  end
  db = settings
  activeMode = nil
  registered = {}
  frame = _G.CreateFrame("Frame")
  frame:SetScript("OnEvent", onEvent)
  Zoom.Install(onManualZoom)
  ZoomMemory.onSave = onSave
  updateEvents()
  CVar.Set(ZOOM_SPEED_CVAR, db.scrollSpeed)
end

ns.Controller = Controller
return Controller
