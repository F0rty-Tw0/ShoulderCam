local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("ShoulderCam.Core.Constants")

local DRUID_MOUNT_FORMS = Constants.DRUID_MOUNT_FORMS

-- Picks the active mode (SPEC.md → Modes) and the events that can change it.
local Mode = {
  -- Per-mode setting keys are "<setting><suffix>", e.g. offsetCombat.
  SUFFIX = { onFoot = "OnFoot", indoors = "Indoors", combat = "Combat", mounted = "Mounted" },
}

-- IsIndoors() has no single change event; these are the ones that fire
-- around a doorway (same set DynamicCam uses).
local INDOOR_EVENTS = { "ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "SPELL_UPDATE_USABLE" }

-- Taxi ends with PLAYER_CONTROL_GAINED; UnitInVehicle has its own enter/exit pair.
local TAXI_EVENTS = { "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED" }
local VEHICLE_EVENTS = { "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }

local function countsAsMounted(db, state)
  if state.mounted then
    return true
  end
  return db.druidForms == true and state.formId ~= nil and DRUID_MOUNT_FORMS[state.formId] == true
end

function Mode.Resolve(db, state)
  if not db.enabled then
    return "off"
  end
  if db.pauseOnTaxi and (state.taxi or state.vehicle) then
    return "paused"
  end
  if db.mountedEnabled and countsAsMounted(db, state) then
    return "mounted"
  end
  if db.indoorsEnabled and state.indoors then
    return "indoors"
  end
  if db.combatEnabled and state.combat then
    return "combat"
  end
  return "onFoot"
end

function Mode.ReadState()
  return {
    mounted = _G.IsMounted() == true,
    combat = _G.UnitAffectingCombat("player") == true,
    formId = _G.GetShapeshiftFormID(),
    indoors = _G.IsIndoors ~= nil and _G.IsIndoors() == true,
    taxi = _G.UnitOnTaxi ~= nil and _G.UnitOnTaxi("player") == true,
    vehicle = _G.UnitInVehicle ~= nil and _G.UnitInVehicle("player") == true,
  }
end

function Mode.Events(db, isDruid, canDetectIndoors, canDetectVehicle)
  local events = { PLAYER_ENTERING_WORLD = true }
  if not db.enabled then
    return events
  end
  if db.mountedEnabled then
    events.PLAYER_MOUNT_DISPLAY_CHANGED = true
    if isDruid and db.druidForms then
      events.UPDATE_SHAPESHIFT_FORM = true
    end
  end
  if db.combatEnabled then
    events.PLAYER_REGEN_DISABLED = true
    events.PLAYER_REGEN_ENABLED = true
  end
  if db.indoorsEnabled and canDetectIndoors then
    for _, event in ipairs(INDOOR_EVENTS) do
      events[event] = true
    end
  end
  if db.pauseOnTaxi then
    for _, event in ipairs(TAXI_EVENTS) do
      events[event] = true
    end
    if canDetectVehicle then
      for _, event in ipairs(VEHICLE_EVENTS) do
        events[event] = true
      end
    end
  end
  return events
end

ns.Mode = Mode
return Mode
