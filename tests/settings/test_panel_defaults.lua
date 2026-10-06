-- Defaults pressed on the Situations page while Combat mode is active and
-- the camera is mid-transition, wired to the real controller.
local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.controller")
local Controller = require("ShoulderCam.Camera.Controller")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local Panel = require("ShoulderCam.Settings.Panel")
local Widgets = require("ShoulderCam.Settings.Widgets")

-- key -> Blizzard frame of every slider/checkbox the panel builds.
local frames = {}
for _, name in ipairs({ "Checkbox", "Slider" }) do
  local create = Widgets[name]
  Widgets[name] = function(...)
    local widget = create(...)
    frames[widget.key] = widget.frame
    return widget
  end
end

local function test_defaults_mid_combat_transition_resets_once_without_stacked_timers()
  local W, db = Helper.setup({ combatEnabled = true, offsetCombat = true, distanceCombat = 20 })
  FlavorCompat.hasSettingsApi = true
  W.zoom = 30
  W.inCombat = true
  W.Fire("PLAYER_ENTERING_WORLD")
  W.Advance(0.1)
  Assert.equal(Controller.ActiveMode(), "combat")
  Assert.equal(W.ActiveTimers(), 2, "zoom stop timer and offset ticker running")
  local reports = {}
  Panel.Register(db, function(key)
    reports[#reports + 1] = key
    Controller.OnSettingChanged(key)
  end)
  local situations = W.categories[2].frame
  W.categories[1].frame.scripts.OnShow(W.categories[1].frame)
  situations.scripts.OnShow(situations)
  Helper.clearLogs(W)

  situations.OnDefault()

  Assert.equal(#reports, 1)
  Assert.equal(reports[1], "*defaults")
  Assert.equal(db.combatEnabled, false)
  Assert.equal(Controller.ActiveMode(), "onFoot")
  Assert.equal(Helper.zoomStarts(W), 1, "one re-apply, one new transition")
  Assert.equal(W.ActiveTimers(), 2, "previous transition replaced, not stacked")
  Assert.equal(frames.combatEnabled:GetChecked(), false, "situations page refreshed")
  Assert.equal(frames.distanceCombat:GetValue(), 39, "situations slider refreshed")
  Assert.equal(frames.distanceCombat:IsEnabled(), false, "combat column greyed again")
end

return function()
  test_defaults_mid_combat_transition_resets_once_without_stacked_timers()
end
