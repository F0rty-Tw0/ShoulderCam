local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local Offset = require("ShoulderCam.Camera.Offset")
local Zoom = require("ShoulderCam.Camera.Zoom")
local ZoomMemory = require("ShoulderCam.Camera.ZoomMemory")
local Controller = require("ShoulderCam.Camera.Controller")

local POPUP_EVENT = "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED"

-- Fresh fake client, then Bootstrap and Panel loaded again (both keep module
-- state). `gameEvent` is the GameEvent table present at load, or nil.
local function setup(saved, gameEvent)
  Zoom.Cancel()
  Offset.Stop()
  ZoomMemory.Cancel()
  local W = Wow.Install()
  FlavorCompat.hasActionCam = true
  FlavorCompat.hasSettingsApi = true
  rawset(_G, "GameEvent", gameEvent)
  rawset(_G, "ShoulderCamDB", saved)
  Controller.onRemembered = nil
  package.loaded["Settings.Panel"] = nil
  package.loaded["Bootstrap"] = nil
  require("ShoulderCam.Bootstrap")
  return W
end

local function loaded(saved)
  local W = setup(saved)
  W.Fire("ADDON_LOADED", "ShoulderCam")
  return W
end

local function test_popup_event_is_unregistered_on_ui_parent()
  local W = setup()
  local found = false
  for _, event in ipairs(W.unregistered) do
    found = found or event == POPUP_EVENT
  end
  Assert.equal(found, true)
end

local function test_game_event_popup_handler_is_replaced_when_present()
  local calls = 0
  local original = function()
    calls = calls + 1
  end
  local gameEvent = { HandleExperimentalCVarConfirmationNeeded = original }
  setup(nil, gameEvent)
  Assert.equal(gameEvent.HandleExperimentalCVarConfirmationNeeded ~= original, true, "handler replaced")
  gameEvent.HandleExperimentalCVarConfirmationNeeded()
  Assert.equal(calls, 0, "original never runs")
end

local function test_load_without_game_event_does_not_error()
  setup(nil, nil)
  Assert.equal(_G.GameEvent, nil)
end

local function test_other_addon_loading_is_ignored()
  local saved = { removed = 1 }
  local W = setup(saved)
  W.Fire("ADDON_LOADED", "SomethingElse")
  Assert.equal(_G.ShoulderCamDB, saved, "saved table untouched")
  Assert.equal(_G.SlashCmdList.SHOULDERCAM, nil, "no slash command yet")
end

local function test_addon_loaded_fills_every_default_once()
  local W = loaded({ removed = 1, enabled = false })
  for _, entry in ipairs(Defaults.list) do
    if entry.key and entry.key ~= "enabled" then
      Assert.equal(_G.ShoulderCamDB[entry.key], entry.default, entry.key)
    end
  end
  Assert.equal(_G.ShoulderCamDB.enabled, false, "saved choice kept")
  Assert.equal(_G.ShoulderCamDB.removed, nil, "unknown key dropped")
  Assert.equal(type(Controller.onRemembered), "function", "remembered zoom refreshes the panel")
  for _, frame in ipairs(W.frames) do
    Assert.equal(frame.events.ADDON_LOADED, nil, "ADDON_LOADED unregistered after load")
  end
end

local function test_slash_command_opens_main_category()
  local W = loaded()
  Assert.equal(_G.SLASH_SHOULDERCAM2, "/shc")
  _G.SlashCmdList.SHOULDERCAM("")
  Assert.equal(W.openedCategory, W.categories[1]:GetID())
end

local function test_toggle_binding_flips_enabled_and_turns_camera_off()
  local W = loaded()
  W.Fire("PLAYER_ENTERING_WORLD")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "1", "on foot pitch applied")
  _G.ShoulderCam_ToggleEnabled()
  Assert.equal(_G.ShoulderCamDB.enabled, false)
  Assert.equal(W.cvars.test_cameraDynamicPitch, "0")
end

local function test_swap_binding_flips_left_shoulder()
  loaded()
  _G.ShoulderCam_SwapShoulder()
  Assert.equal(_G.ShoulderCamDB.leftShoulder, true)
  _G.ShoulderCam_SwapShoulder()
  Assert.equal(_G.ShoulderCamDB.leftShoulder, false)
end

local function test_bindings_before_load_do_nothing()
  local saved = { enabled = true }
  setup(saved)
  _G.ShoulderCam_ToggleEnabled()
  _G.ShoulderCam_SwapShoulder()
  Assert.equal(saved.enabled, true)
  Assert.equal(saved.leftShoulder, nil)
end

local function test_binding_labels_are_set()
  setup()
  Assert.equal(_G.BINDING_HEADER_SHOULDERCAM, "ShoulderCam")
  Assert.equal(_G.BINDING_NAME_SHOULDERCAM_TOGGLE, "Toggle ShoulderCam")
  Assert.equal(_G.BINDING_NAME_SHOULDERCAM_SWAP, "Swap shoulder")
end

local function test_compartment_click_opens_main_category()
  local W = loaded()
  _G.ShoulderCam_OnAddonCompartmentClick()
  Assert.equal(W.openedCategory, W.categories[1]:GetID())
end

local function test_compartment_click_before_load_does_not_error()
  local W = setup()
  _G.ShoulderCam_OnAddonCompartmentClick()
  Assert.equal(W.openedCategory, nil)
end

local function test_compartment_hover_shows_and_hides_tooltip()
  setup()
  local button = {}
  _G.ShoulderCam_OnAddonCompartmentEnter(nil, button)
  local tooltip = _G.GameTooltip
  Assert.equal(tooltip.owner, button)
  Assert.equal(tooltip.text, "ShoulderCam")
  Assert.equal(tooltip.lines[1], "Click to open settings.")
  Assert.equal(tooltip:IsShown(), true)
  _G.ShoulderCam_OnAddonCompartmentLeave()
  Assert.equal(tooltip:IsShown(), false)
end

return function()
  test_popup_event_is_unregistered_on_ui_parent()
  test_game_event_popup_handler_is_replaced_when_present()
  test_load_without_game_event_does_not_error()
  test_other_addon_loading_is_ignored()
  test_addon_loaded_fills_every_default_once()
  test_slash_command_opens_main_category()
  test_toggle_binding_flips_enabled_and_turns_camera_off()
  test_swap_binding_flips_left_shoulder()
  test_bindings_before_load_do_nothing()
  test_binding_labels_are_set()
  test_compartment_click_opens_main_category()
  test_compartment_click_before_load_does_not_error()
  test_compartment_hover_shows_and_hides_tooltip()
end
