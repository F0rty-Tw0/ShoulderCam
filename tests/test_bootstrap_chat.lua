local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local Offset = require("ShoulderCam.Camera.Offset")
local Zoom = require("ShoulderCam.Camera.Zoom")
local ZoomMemory = require("ShoulderCam.Camera.ZoomMemory")
local Controller = require("ShoulderCam.Camera.Controller")

local BUTTON_NAME = "ShoulderCamMinimapButton"

-- Fresh fake client, then Bootstrap and the settings modules loaded again
-- (they keep module state), with ADDON_LOADED delivered.
local function loaded()
  Zoom.Cancel()
  Offset.Stop()
  ZoomMemory.Cancel()
  local W = Wow.Install()
  FlavorCompat.hasActionCam = true
  FlavorCompat.hasSettingsApi = true
  rawset(_G, "GameEvent", nil)
  rawset(_G, "ShoulderCamDB", nil)
  Controller.onRemembered = nil
  package.loaded["Settings.Panel"] = nil
  package.loaded["Settings.MinimapButton"] = nil
  package.loaded["Bootstrap"] = nil
  require("ShoulderCam.Bootstrap")
  W.Fire("ADDON_LOADED", "ShoulderCam")
  return W
end

-- Runs `action` with `_G.print` captured, then restores it; returns the lines.
local function printedBy(action)
  local printed = {}
  local original = _G.print
  rawset(_G, "print", function(text)
    printed[#printed + 1] = text
  end)
  local ok, err = pcall(action)
  rawset(_G, "print", original)
  assert(ok, err)
  return table.concat(printed, "|")
end

local function slash(msg)
  return printedBy(function()
    _G.SlashCmdList.SHOULDERCAM(msg)
  end)
end

local function click(mouseButton)
  return printedBy(function()
    _G[BUTTON_NAME].scripts.OnClick(_G[BUTTON_NAME], mouseButton)
  end)
end

local function test_slash_toggle_says_the_new_state_each_time()
  loaded()

  Assert.equal(slash("toggle"), "Shoulder Cam: off")
  Assert.equal(slash("toggle"), "Shoulder Cam: on")
end

local function test_slash_swap_says_the_shoulder_after_the_flip()
  loaded()

  Assert.equal(slash("swap"), "Shoulder Cam: left shoulder")
  Assert.equal(slash("swap"), "Shoulder Cam: right shoulder")
end

local function test_slash_open_prints_nothing()
  loaded()

  Assert.equal(slash(""), "")
end

local function test_key_bindings_print_nothing()
  loaded()

  Assert.equal(printedBy(_G.ShoulderCam_ToggleEnabled), "")
  Assert.equal(printedBy(_G.ShoulderCam_SwapShoulder), "")
end

local function test_minimap_clicks_print_nothing()
  loaded()

  Assert.equal(click("RightButton"), "")
  Assert.equal(click("MiddleButton"), "")
  Assert.equal(click("LeftButton"), "")
end

return function()
  test_slash_toggle_says_the_new_state_each_time()
  test_slash_swap_says_the_shoulder_after_the_flip()
  test_slash_open_prints_nothing()
  test_key_bindings_print_nothing()
  test_minimap_clicks_print_nothing()
end
