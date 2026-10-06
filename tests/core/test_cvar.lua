local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local CVar = require("ShoulderCam.Core.CVar")

local function test_missing_cvar_is_skipped()
  local W = Wow.Install()
  W.cvars.test_cameraDynamicPitch = nil

  Assert.equal(CVar.Set("test_cameraDynamicPitch", 1), false)
  Assert.equal(#W.setCVarCalls, 0)
  Assert.equal(W.cvars.test_cameraDynamicPitch, nil)
end

local function test_unchanged_number_is_skipped()
  local W = Wow.Install()
  W.cvars.test_cameraDynamicPitch = "1"

  Assert.equal(CVar.Set("test_cameraDynamicPitch", 1), false)
  Assert.equal(#W.setCVarCalls, 0)
end

local function test_whole_float_is_written_without_decimals()
  local W = Wow.Install()

  Assert.equal(CVar.Set("test_cameraOverShoulder", 2.0), true)
  Assert.equal(W.cvars.test_cameraOverShoulder, "2")
  Assert.equal(W.setCVarCalls[1][2], "2")
end

local function test_computed_float_is_normalized()
  local W = Wow.Install()

  Assert.equal(CVar.Set("cameraDistanceMaxZoomFactor", 39 / 15), true)
  Assert.equal(W.cvars.cameraDistanceMaxZoomFactor, "2.6")
  Assert.equal(CVar.Set("test_cameraDynamicPitchBaseFovPad", 0.1 + 0.2), true)
  Assert.equal(W.cvars.test_cameraDynamicPitchBaseFovPad, "0.3")
end

local function test_normalized_float_equal_to_current_is_skipped()
  local W = Wow.Install()
  W.cvars.cameraDistanceMaxZoomFactor = "2.6"

  Assert.equal(CVar.Set("cameraDistanceMaxZoomFactor", 39 / 15), false)
  Assert.equal(#W.setCVarCalls, 0)
end

local function test_new_value_is_written_and_recorded()
  local W = Wow.Install()

  Assert.equal(CVar.Set("CameraKeepCharacterCentered", 0), true)
  Assert.equal(#W.setCVarCalls, 1)
  Assert.equal(W.setCVarCalls[1][1], "CameraKeepCharacterCentered")
  Assert.equal(W.setCVarCalls[1][2], "0")
  Assert.equal(W.cvars.CameraKeepCharacterCentered, "0")
end

local function test_string_value_is_written_as_is()
  local W = Wow.Install()

  Assert.equal(CVar.Set("test_cameraOverShoulder", "-1.5"), true)
  Assert.equal(W.cvars.test_cameraOverShoulder, "-1.5")
end

return function()
  test_missing_cvar_is_skipped()
  test_unchanged_number_is_skipped()
  test_whole_float_is_written_without_decimals()
  test_computed_float_is_normalized()
  test_normalized_float_equal_to_current_is_skipped()
  test_new_value_is_written_and_recorded()
  test_string_value_is_written_as_is()
end
