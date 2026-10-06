-- Smoke test for the fake WoW API: timers fire on time, cancelled timers
-- never fire, and events reach only frames registered for them.
local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local function test_advance_fires_after_timer_once()
  local W = Wow.Install()
  local fired = 0
  _G.C_Timer.After(0.5, function()
    fired = fired + 1
  end)

  W.Advance(1)
  W.Advance(1)

  Assert.equal(fired, 1)
  Assert.equal(W.now, 2)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_cancelled_new_timer_never_fires()
  local W = Wow.Install()
  local fired = false
  local timer = _G.C_Timer.NewTimer(0.5, function()
    fired = true
  end)

  timer:Cancel()
  W.Advance(1)

  Assert.equal(fired, false)
  Assert.equal(timer:IsCancelled(), true)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_ticker_reschedules_until_cancelled()
  local W = Wow.Install()
  local times = {}
  _G.C_Timer.NewTicker(0.25, function(ticker)
    times[#times + 1] = W.now
    if #times == 3 then
      ticker:Cancel()
    end
  end)

  W.Advance(2)

  Assert.equal(table.concat(times, ","), "0.25,0.5,0.75")
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_timer_created_during_advance_runs_when_due()
  local W = Wow.Install()
  local firedAt
  _G.C_Timer.NewTimer(0.25, function()
    _G.C_Timer.NewTimer(0.25, function()
      firedAt = W.now
    end)
  end)

  W.Advance(1)

  Assert.equal(firedAt, 0.5)
end

local function test_fire_reaches_registered_frame_only()
  local W = Wow.Install()
  local received = {}
  local function onEvent(frame, event, arg)
    received[#received + 1] = frame.label .. ":" .. event .. ":" .. tostring(arg)
  end
  local listening = _G.CreateFrame("Frame")
  listening.label = "listening"
  listening:SetScript("OnEvent", onEvent)
  listening:RegisterEvent("X")
  local left = _G.CreateFrame("Frame")
  left.label = "left"
  left:SetScript("OnEvent", onEvent)
  left:RegisterEvent("X")
  left:UnregisterEvent("X")

  W.Fire("X", 7)

  Assert.equal(table.concat(received, ","), "listening:X:7")
  Assert.equal(left:IsEventRegistered("X"), false)
end

local function test_missing_cvar_reads_nil_and_set_cvar_is_logged()
  local W = Wow.Install()
  W.cvars.test_cameraDynamicPitch = nil

  _G.SetCVar("test_cameraOverShoulder", 1.5)

  Assert.equal(_G.GetCVar("test_cameraDynamicPitch"), nil)
  Assert.equal(_G.GetCVar("cameraDistanceMaxZoomFactor"), "1.9")
  Assert.equal(_G.GetCVar("test_cameraOverShoulder"), "1.5")
  Assert.equal(#W.setCVarCalls, 1)
  Assert.equal(W.setCVarCalls[1][1], "test_cameraOverShoulder")
end

local function test_camera_calls_are_counted_and_logged()
  local W = Wow.Install()
  W.zoom = 12

  _G.MoveViewOutStart(0.5)
  _G.CameraZoomIn(2)

  Assert.equal(_G.GetCameraZoom(), 12)
  Assert.equal(W.calls.MoveViewOutStart, 1)
  Assert.equal(W.log[2].name, "CameraZoomIn")
  Assert.equal(W.log[2].args[1], 2)
end

local function test_hooksecurefunc_runs_after_original()
  local W = Wow.Install()
  local order = {}
  _G.hooksecurefunc("CameraZoomOut", function(distance)
    order[#order + 1] = "hook:" .. tostring(W.calls.CameraZoomOut) .. ":" .. distance
  end)

  _G.CameraZoomOut(3)

  Assert.equal(table.concat(order, ","), "hook:1:3")
end

local function test_settings_categories_are_recorded()
  local W = Wow.Install()
  local mainFrame = _G.CreateFrame("Frame")
  local main = _G.Settings.RegisterCanvasLayoutCategory(mainFrame, "ShoulderCam")
  local sub = _G.Settings.RegisterCanvasLayoutSubcategory(main, _G.CreateFrame("Frame"), "Situations")
  _G.Settings.RegisterAddOnCategory(main)

  _G.Settings.OpenToCategory(main:GetID())

  Assert.equal(#W.categories, 2)
  Assert.equal(W.categories[2], sub)
  Assert.equal(main.frame, mainFrame)
  Assert.equal(W.openedCategory, main:GetID())
  Assert.equal(main:GetID() ~= sub:GetID(), true)
end

local function test_uiparent_unregister_is_recorded()
  local W = Wow.Install()

  _G.UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

  Assert.equal(W.unregistered[1], "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
end

local function test_check_button_click_runs_on_click()
  Wow.Install()
  local box = _G.CreateFrame("CheckButton")
  local clicked
  box:SetScript("OnClick", function(self)
    clicked = self:GetChecked()
  end)
  box:SetChecked(false)

  box:Click()

  Assert.equal(clicked, true)
end

local function test_slider_set_value_fires_value_changed()
  Wow.Install()
  local slider = _G.CreateFrame("Frame", nil, nil, "MinimalSliderWithSteppersTemplate")
  local owner = {}
  local got
  slider:Init(5, 1, 10, 9, {})
  slider:RegisterCallback(_G.MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(cbOwner, value)
    got = { cbOwner, value }
  end, owner)

  slider:SetValue(7)

  Assert.equal(got[1], owner)
  Assert.equal(got[2], 7)
  Assert.equal(slider:GetValue(), 7)
end

local function test_player_state_reads_from_w()
  local W = Wow.Install()
  W.mounted, W.inCombat, W.formId, W.class = true, true, 27, "DRUID"

  local _, classFile = _G.UnitClass("player")

  Assert.equal(_G.IsMounted(), true)
  Assert.equal(_G.UnitAffectingCombat("player"), true)
  Assert.equal(_G.GetShapeshiftFormID(), 27)
  Assert.equal(classFile, "DRUID")
end

return function()
  test_advance_fires_after_timer_once()
  test_cancelled_new_timer_never_fires()
  test_ticker_reschedules_until_cancelled()
  test_timer_created_during_advance_runs_when_due()
  test_fire_reaches_registered_frame_only()
  test_missing_cvar_reads_nil_and_set_cvar_is_logged()
  test_camera_calls_are_counted_and_logged()
  test_hooksecurefunc_runs_after_original()
  test_settings_categories_are_recorded()
  test_uiparent_unregister_is_recorded()
  test_check_button_click_runs_on_click()
  test_slider_set_value_fires_value_changed()
  test_player_state_reads_from_w()
end
