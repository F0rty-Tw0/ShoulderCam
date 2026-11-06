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

return function()
  test_taxi_start_puts_camera_back()
  test_landing_restores_camera_and_zoom()
end
