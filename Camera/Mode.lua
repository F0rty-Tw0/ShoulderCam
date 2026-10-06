local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("ShoulderCam.Core.Constants")

local DRUID_MOUNT_FORMS = Constants.DRUID_MOUNT_FORMS

-- Picks the active mode (SPEC.md → Modes) and the events that can change it.
local Mode = {
  -- Per-mode setting keys are "<setting><suffix>", e.g. offsetCombat.
  SUFFIX = { onFoot = "OnFoot", combat = "Combat", mounted = "Mounted" },
}

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
  if db.mountedEnabled and countsAsMounted(db, state) then
    return "mounted"
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
  }
end

function Mode.Events(db, isDruid)
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
  return events
end

ns.Mode = Mode
return Mode
