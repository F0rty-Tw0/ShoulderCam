local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.controller")
local Controller = require("ShoulderCam.Camera.Controller")

local INDOOR_EVENTS = { "ZONE_CHANGED_INDOORS", "ZONE_CHANGED", "ZONE_CHANGED_NEW_AREA", "SPELL_UPDATE_USABLE" }

-- Counts IsMounted calls: Mode.ReadState makes one, so zero means Apply never ran.
local function countMountedReads()
  local counter = { calls = 0 }
  local isMounted = _G.IsMounted
  _G.IsMounted = function()
    counter.calls = counter.calls + 1
    return isMounted()
  end
  return counter
end

local function test_walking_indoors_applies_indoor_camera()
  local W = Helper.setup({ indoorsEnabled = true, pitchOnFoot = false })
  W.Fire("PLAYER_ENTERING_WORLD")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "0")
  W.zoom = 30

  W.indoors = true
  W.Fire("ZONE_CHANGED_INDOORS")

  Assert.equal(Controller.ActiveMode(), "indoors")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "1")
  Assert.equal(W.log[#W.log].name, "MoveViewInStart")
end

local function test_leaving_indoors_in_combat_uses_combat_camera()
  local W = Helper.setup({ indoorsEnabled = true, combatEnabled = true })
  W.indoors, W.inCombat = true, true
  W.Fire("PLAYER_ENTERING_WORLD")
  Assert.equal(Controller.ActiveMode(), "indoors")

  W.indoors = false
  W.Fire("ZONE_CHANGED")

  Assert.equal(Controller.ActiveMode(), "combat")
end

local function test_usable_event_without_flip_does_nothing()
  local W = Helper.setup({ indoorsEnabled = true })
  W.Fire("PLAYER_ENTERING_WORLD")
  Helper.clearLogs(W)
  local reads = countMountedReads()
  Assert.equal(Helper.frame(W):IsEventRegistered("SPELL_UPDATE_USABLE"), true)

  W.Fire("SPELL_UPDATE_USABLE")

  Assert.equal(#W.setCVarCalls, 0)
  Assert.equal(reads.calls, 0)
end

local function test_usable_event_with_flip_applies()
  local W = Helper.setup({ indoorsEnabled = true })
  W.Fire("PLAYER_ENTERING_WORLD")

  W.indoors = true
  W.Fire("SPELL_UPDATE_USABLE")

  Assert.equal(Controller.ActiveMode(), "indoors")
end

-- The mode stays Mounted, but the indoor flip must still be remembered so
-- the next usable event is skipped.
local function test_usable_event_tracks_indoors_while_mounted()
  local W = Helper.setup({ indoorsEnabled = true, mountedEnabled = true })
  W.mounted = true
  W.Fire("PLAYER_ENTERING_WORLD")
  Assert.equal(Helper.frame(W):IsEventRegistered("SPELL_UPDATE_USABLE"), true)
  W.indoors = true
  W.Fire("SPELL_UPDATE_USABLE")
  Assert.equal(Controller.ActiveMode(), "mounted")
  local reads = countMountedReads()

  W.Fire("SPELL_UPDATE_USABLE")

  Assert.equal(reads.calls, 0)
end

local function test_indoors_toggle_registers_events()
  local W, db = Helper.setup()
  local frame = Helper.frame(W)
  Assert.equal(frame:IsEventRegistered("ZONE_CHANGED_INDOORS"), false)

  db.indoorsEnabled = true
  Controller.OnSettingChanged("indoorsEnabled")
  for _, event in ipairs(INDOOR_EVENTS) do
    Assert.equal(frame:IsEventRegistered(event), true, event .. " registered")
  end

  db.indoorsEnabled = false
  Controller.OnSettingChanged("indoorsEnabled")
  for _, event in ipairs(INDOOR_EVENTS) do
    Assert.equal(frame:IsEventRegistered(event), false, event .. " unregistered")
  end
end

local function test_no_indoor_events_without_api()
  local W, db = Helper.setup()
  _G.IsIndoors = nil

  db.indoorsEnabled = true
  Controller.OnSettingChanged("indoorsEnabled")

  Assert.equal(Helper.frame(W):IsEventRegistered("SPELL_UPDATE_USABLE"), false)
end

return function()
  test_walking_indoors_applies_indoor_camera()
  test_leaving_indoors_in_combat_uses_combat_camera()
  test_usable_event_without_flip_does_nothing()
  test_usable_event_with_flip_applies()
  test_usable_event_tracks_indoors_while_mounted()
  test_indoors_toggle_registers_events()
  test_no_indoor_events_without_api()
end
