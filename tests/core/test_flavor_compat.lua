local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

-- Flags are computed when the file loads, so each case reloads it.
local function load()
  return dofile("Core/FlavorCompat.lua")
end

local function test_action_cam_present_when_pitch_cvar_exists()
  local W = Wow.Install()
  W.cvars.test_cameraDynamicPitch = "0"

  Assert.equal(load().hasActionCam, true)
end

local function test_action_cam_absent_when_pitch_cvar_missing()
  local W = Wow.Install()
  W.cvars.test_cameraDynamicPitch = nil

  Assert.equal(load().hasActionCam, false)
end

local function test_action_cam_absent_without_get_cvar()
  Wow.Install()
  rawset(_G, "GetCVar", nil)

  Assert.equal(load().hasActionCam, false)
end

local function test_settings_api_follows_canvas_category()
  Wow.Install()
  Assert.equal(load().hasSettingsApi, true)

  rawset(_G, "Settings", nil)
  Assert.equal(load().hasSettingsApi, false)
end

local function test_event_known_follows_client_check()
  local W = Wow.Install()
  W.unknownEvents.UNIT_ENTERED_VEHICLE = true

  Assert.equal(load().IsEventKnown("UNIT_ENTERED_VEHICLE"), false)
  Assert.equal(load().IsEventKnown("PLAYER_CONTROL_LOST"), true)
end

local function test_event_known_without_client_check()
  Wow.Install()
  rawset(_G, "C_EventUtils", nil)

  Assert.equal(load().IsEventKnown("UNIT_ENTERED_VEHICLE"), true)
end

return function()
  test_action_cam_present_when_pitch_cvar_exists()
  test_action_cam_absent_when_pitch_cvar_missing()
  test_action_cam_absent_without_get_cvar()
  test_settings_api_follows_canvas_category()
  test_event_known_follows_client_check()
  test_event_known_without_client_check()
end
