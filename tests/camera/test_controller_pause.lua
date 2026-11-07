local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.controller")
local Controller = require("ShoulderCam.Camera.Controller")

-- On foot with the shoulder offset, dynamic pitch and focus enemy all on, settled.
local function setupOnFoot()
  local W, db = Helper.setup({ offsetOnFoot = true, focusEnemyOnFoot = true })
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(5)
  Assert.equal(W.cvars.test_cameraOverShoulder, "1")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "1")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "1")
  return W, db
end

local function test_taxi_start_puts_camera_back()
  local W = setupOnFoot()

  W.onTaxi = true
  W.Fire("PLAYER_CONTROL_LOST")

  Assert.equal(Controller.ActiveMode(), "paused")
  Assert.equal(W.cvars.test_cameraOverShoulder, "0")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "0")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "0")
end

local function test_landing_restores_camera_and_zoom()
  local W = setupOnFoot()
  W.onTaxi = true
  W.Fire("PLAYER_CONTROL_LOST")
  W.cvars.CameraKeepCharacterCentered = "1"
  Helper.clearLogs(W)

  W.onTaxi = false
  W.Fire("PLAYER_CONTROL_GAINED")

  Assert.equal(Controller.ActiveMode(), "onFoot")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "1")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "1")
  Assert.equal(W.cvars.CameraKeepCharacterCentered, "0")
  Assert.equal(Helper.zoomStarts(W), 1)
  W.Advance(5)
  Assert.equal(W.cvars.test_cameraOverShoulder, "1")
end

local function test_losing_control_off_taxi_changes_nothing()
  local W = setupOnFoot()
  Helper.clearLogs(W)

  W.Fire("PLAYER_CONTROL_LOST")

  Assert.equal(Controller.ActiveMode(), "onFoot")
  Assert.equal(#W.setCVarCalls, 0)
end

local function test_other_units_vehicle_changes_nothing()
  local W = setupOnFoot()
  Assert.equal(Helper.frame(W):IsEventRegistered("UNIT_ENTERED_VEHICLE"), true)
  Helper.clearLogs(W)

  W.inVehicle = false
  W.Fire("UNIT_ENTERED_VEHICLE", "party1")

  Assert.equal(Controller.ActiveMode(), "onFoot")
  Assert.equal(#W.setCVarCalls, 0)
end

local function test_vehicle_ride_pauses_and_leaving_resumes()
  local W = setupOnFoot()

  W.inVehicle = true
  W.Fire("UNIT_ENTERED_VEHICLE", "player")
  Assert.equal(Controller.ActiveMode(), "paused")

  W.inVehicle = false
  W.Fire("UNIT_EXITED_VEHICLE", "player")
  Assert.equal(Controller.ActiveMode(), "onFoot")
end

local function test_turning_option_off_while_paused_resumes_and_unregisters()
  local W, db = setupOnFoot()
  W.onTaxi = true
  W.Fire("PLAYER_CONTROL_LOST")
  Assert.equal(Controller.ActiveMode(), "paused")

  db.pauseOnTaxi = false
  Controller.OnSettingChanged("pauseOnTaxi")

  Assert.equal(Controller.ActiveMode(), "onFoot")
  Assert.equal(Helper.frame(W):IsEventRegistered("PLAYER_CONTROL_LOST"), false)
  Assert.equal(Helper.frame(W):IsEventRegistered("PLAYER_CONTROL_GAINED"), false)
  Assert.equal(Helper.frame(W):IsEventRegistered("UNIT_ENTERED_VEHICLE"), false)
  Assert.equal(Helper.frame(W):IsEventRegistered("UNIT_EXITED_VEHICLE"), false)
end

local function test_no_vehicle_events_without_api()
  local W, db = Helper.setup()
  Assert.equal(Helper.frame(W):IsEventRegistered("UNIT_ENTERED_VEHICLE"), true)
  rawset(_G, "UnitInVehicle", nil)

  Controller.OnSettingChanged("pauseOnTaxi")

  Assert.equal(db.pauseOnTaxi, true)
  Assert.equal(Helper.frame(W):IsEventRegistered("UNIT_ENTERED_VEHICLE"), false)
  Assert.equal(Helper.frame(W):IsEventRegistered("PLAYER_CONTROL_LOST"), true)
end

local function test_manual_zoom_while_paused_remembers_nothing()
  local W, db = setupOnFoot()
  W.onTaxi = true
  W.Fire("PLAYER_CONTROL_LOST")

  _G.CameraZoomIn(5)
  W.zoom = 10
  W.Advance(2)

  Assert.equal(db.distanceOnFoot, 39)
end

return function()
  test_taxi_start_puts_camera_back()
  test_landing_restores_camera_and_zoom()
  test_losing_control_off_taxi_changes_nothing()
  test_other_units_vehicle_changes_nothing()
  test_vehicle_ride_pauses_and_leaving_resumes()
  test_turning_option_off_while_paused_resumes_and_unregisters()
  test_no_vehicle_events_without_api()
  test_manual_zoom_while_paused_remembers_nothing()
end
