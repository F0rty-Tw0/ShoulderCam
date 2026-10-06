local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.controller")
local Defaults = require("ShoulderCam.Settings.Defaults")
local Controller = require("ShoulderCam.Camera.Controller")

local POLL = 0.25

local function test_slider_change_does_not_zoom()
  local W, db = Helper.setup()
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(2)
  W.zoom = 20
  Helper.clearLogs(W)

  db.pitchStrength = 0.5
  Controller.OnSettingChanged("pitchStrength")

  Assert.equal(W.cvars.test_cameraDynamicPitchBaseFovPad, "0.5")
  Assert.equal(#W.log, 0)
end

local function test_active_mode_distance_change_zooms()
  local W, db = Helper.setup()
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(2)
  W.zoom = 39
  Helper.clearLogs(W)

  db.distanceCombat = 20
  Controller.OnSettingChanged("distanceCombat")
  Assert.equal(Helper.zoomStarts(W), 0)

  db.distanceOnFoot = 20
  Controller.OnSettingChanged("distanceOnFoot")
  Assert.equal(W.log[#W.log].name, "MoveViewInStart")
end

local function test_combat_event_zooms_to_combat_distance()
  local W = Helper.setup({ combatEnabled = true, focusEnemyCombat = true, distanceCombat = 25 })
  W.zoom = 39
  W.Fire("PLAYER_ENTERING_WORLD")
  Helper.clearLogs(W)

  W.inCombat = true
  W.Fire("PLAYER_REGEN_DISABLED")
  W.zoom = 25.5
  W.Advance(1)

  Assert.equal(Controller.ActiveMode(), "combat")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "1")
  Assert.equal(W.log[1].name, "MoveViewInStart")
  Assert.equal(W.log[#W.log].name, "CameraZoomIn")
  Assert.equal(W.log[#W.log].args[1], 0.5)
end

local function test_distance_clamps_to_max_distance()
  local W = Helper.setup({ maxDistance = 20 })
  W.zoom = 10

  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(0.24)
  Assert.equal(Helper.count(W, "MoveViewOutStop"), 0)
  W.zoom = 19.5
  W.Advance(0.02)

  Assert.equal(W.cvars.cameraDistanceMaxZoomFactor, string.format("%.14g", 20 / 15))
  Assert.equal(W.log[#W.log].name, "CameraZoomOut")
  Assert.equal(W.log[#W.log].args[1], 0.5)
end

local function test_zoom_off_skips_zoom()
  local W = Helper.setup({ zoomOnFoot = false })

  W.Fire("PLAYER_ENTERING_WORLD")

  Assert.equal(#W.log, 0)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_mode_switch_cancels_pending_memory()
  local W, db = Helper.setup({ combatEnabled = true, zoomCombat = false })
  W.zoom = 39
  W.Fire("PLAYER_ENTERING_WORLD")
  W.zoom = 20
  _G.CameraZoomIn(19)

  W.inCombat = true
  W.Fire("PLAYER_REGEN_DISABLED")
  W.Advance(POLL * 4)

  Assert.equal(db.distanceOnFoot, 39)
  Assert.equal(db.distanceCombat, 39)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_remembered_distance_writes_db_without_zoom()
  local W, db = Helper.setup()
  local remembered = {}
  Controller.onRemembered = function(key)
    table.insert(remembered, key)
  end
  W.zoom = 39
  W.Fire("PLAYER_ENTERING_WORLD")
  Helper.clearLogs(W)

  _G.CameraZoomIn(5)
  W.zoom = 34
  W.Advance(POLL * 4)

  Assert.equal(db.distanceOnFoot, 34)
  Assert.equal(#remembered, 1)
  Assert.equal(remembered[1], "distanceOnFoot")
  Assert.equal(Helper.zoomStarts(W), 0)
  Assert.equal(#W.setCVarCalls, 0)
end

local function test_remember_off_saves_nothing()
  local W, db = Helper.setup({ rememberOnFoot = false })
  W.zoom = 39
  W.Fire("PLAYER_ENTERING_WORLD")

  _G.CameraZoomIn(5)
  W.zoom = 34
  W.Advance(POLL * 4)

  Assert.equal(db.distanceOnFoot, 39)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_defaults_mid_transition_leaves_one_timer()
  local W, db = Helper.setup({ combatEnabled = true, distanceCombat = 25, scrollSpeed = 30 })
  W.inCombat = true
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(0.1)
  Helper.clearLogs(W)

  Defaults.Reset(db)
  db.combatEnabled = true
  Controller.OnSettingChanged("*defaults")

  Assert.equal(Controller.ActiveMode(), "combat")
  Assert.equal(W.ActiveTimers(), 1)
  Assert.equal(Helper.zoomStarts(W), 1)
  Assert.equal(W.cvars.cameraZoomSpeed, "20")
end

-- 20 yd at transition speed 40 → a 0.5 s zoom; offset time stays 2 s.
local function offsetValueAt(syncOffset, seconds)
  local W = Helper.setup({ offsetOnFoot = true, syncOffset = syncOffset })
  W.zoom = 19
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(seconds)
  return W.cvars.test_cameraOverShoulder
end

local function test_offset_syncs_with_zoom_duration()
  Assert.equal(offsetValueAt(true, 0.45) ~= "1", true)
  Assert.equal(offsetValueAt(true, 0.55), "1")
end

local function test_offset_uses_offset_time_without_sync()
  Assert.equal(offsetValueAt(false, 0.55) ~= "1", true)
  Assert.equal(offsetValueAt(false, 1.95) ~= "1", true)
  Assert.equal(offsetValueAt(false, 2.05), "1")
end

local function test_left_shoulder_moves_offset_negative()
  local W = Helper.setup({ offsetOnFoot = true, leftShoulder = true, offsetAmount = 2 })
  W.zoom = 39
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(2.1)

  Assert.equal(W.cvars.test_cameraOverShoulder, "-2")
end

return function()
  test_slider_change_does_not_zoom()
  test_active_mode_distance_change_zooms()
  test_combat_event_zooms_to_combat_distance()
  test_distance_clamps_to_max_distance()
  test_zoom_off_skips_zoom()
  test_mode_switch_cancels_pending_memory()
  test_remembered_distance_writes_db_without_zoom()
  test_remember_off_saves_nothing()
  test_defaults_mid_transition_leaves_one_timer()
  test_offset_syncs_with_zoom_duration()
  test_offset_uses_offset_time_without_sync()
  test_left_shoulder_moves_offset_negative()
end
