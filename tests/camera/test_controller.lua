local Assert = require("tests.helpers.assert")
local Helper = require("tests.helpers.controller")
local Defaults = require("ShoulderCam.Settings.Defaults")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local ZoomMemory = require("ShoulderCam.Camera.ZoomMemory")
local Controller = require("ShoulderCam.Camera.Controller")

local function test_enter_world_on_foot_applies_defaults()
  local W = Helper.setup()

  W.Fire("PLAYER_ENTERING_WORLD")

  Assert.equal(Controller.ActiveMode(), "onFoot")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "1")
  Assert.equal(W.cvars.test_cameraOverShoulder, "0")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "0")
  Assert.equal(W.cvars.test_cameraTargetFocusInteractEnable, "0")
  Assert.equal(W.cvars.CameraKeepCharacterCentered, "0")
  Assert.equal(W.cvars.CameraReduceUnexpectedMovement, "0")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyStrengthYaw, "1")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyStrengthPitch, "0.75")
  Assert.equal(W.cvars.test_cameraTargetFocusInteractStrengthYaw, "1")
  Assert.equal(W.cvars.test_cameraTargetFocusInteractStrengthPitch, "0.75")
  Assert.equal(W.cvars.test_cameraDynamicPitchBaseFovPad, "0.4")
  Assert.equal(W.cvars.test_cameraDynamicPitchBaseFovPadDownScale, "0.25")
  Assert.equal(W.cvars.test_cameraDynamicPitchBaseFovPadFlying, "0.75")
  Assert.equal(W.cvars.cameraDistanceMaxZoomFactor, "2.6")
  Assert.equal(W.log[#W.log].name, "MoveViewOutStart")
  Assert.equal(W.log[#W.log].args[1], 2)
end

local function test_same_mode_setting_reapply_writes_nothing()
  local W = Helper.setup()
  W.Fire("PLAYER_ENTERING_WORLD")
  Helper.clearLogs(W)

  Controller.Apply("setting", "focusYaw")

  Assert.equal(#W.setCVarCalls, 0)
  Assert.equal(#W.log, 0)
end

local function test_event_with_unchanged_mode_reads_no_cvar()
  local W = Helper.setup({ mountedEnabled = true, combatEnabled = true })
  W.mounted = true
  W.Fire("PLAYER_ENTERING_WORLD")
  Helper.clearLogs(W)
  local reads = 0
  local getCVar = _G.GetCVar
  _G.GetCVar = function(name)
    reads = reads + 1
    return getCVar(name)
  end

  W.inCombat = true
  W.Fire("PLAYER_REGEN_DISABLED")

  Assert.equal(reads, 0)
  Assert.equal(#W.setCVarCalls, 0)
end

local function test_install_only_writes_scroll_speed()
  local W = Helper.setup({ scrollSpeed = 30 })

  Assert.equal(#W.setCVarCalls, 1)
  Assert.equal(W.setCVarCalls[1][1], "cameraZoomSpeed")
  Assert.equal(W.cvars.cameraZoomSpeed, "30")
  Assert.equal(#W.log, 0)
end

local function test_scroll_speed_change_writes_zoom_speed()
  local W, db = Helper.setup()
  W.Fire("PLAYER_ENTERING_WORLD")

  db.scrollSpeed = 30
  Controller.OnSettingChanged("scrollSpeed")

  Assert.equal(W.cvars.cameraZoomSpeed, "30")
end

local function test_off_resets_cvars_and_cancels_timers()
  local W, db = Helper.setup({ offsetOnFoot = true, focusEnemyOnFoot = true })
  W.Fire("PLAYER_ENTERING_WORLD")
  ZoomMemory.Start("OnFoot")
  W.Advance(0.1)
  Assert.equal(W.ActiveTimers(), 3)

  db.enabled = false
  Controller.OnSettingChanged("enabled")

  Assert.equal(Controller.ActiveMode(), "off")
  Assert.equal(W.ActiveTimers(), 0)
  Assert.equal(W.cvars.test_cameraOverShoulder, "0")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "0")
  Assert.equal(W.cvars.test_cameraTargetFocusInteractEnable, "0")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "0")
  Assert.equal(W.log[#W.log].name, "MoveViewOutStop")
end

local function test_no_action_cam_writes_nothing()
  local W, db = Helper.setup()
  W.cvars.test_cameraDynamicPitch = nil
  FlavorCompat.hasActionCam = false
  Helper.clearLogs(W)
  Controller.Install(db)

  W.Fire("PLAYER_ENTERING_WORLD")
  Controller.Apply("enter_world")
  db.scrollSpeed = 30
  Controller.OnSettingChanged("scrollSpeed")
  Controller.OnSettingChanged("*defaults")

  Assert.equal(#W.setCVarCalls, 0)
  Assert.equal(#W.log, 0)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_mounted_toggle_registers_mount_event()
  local W, db = Helper.setup()
  local frame = Helper.frame(W)
  Assert.equal(frame:IsEventRegistered("PLAYER_ENTERING_WORLD"), true)
  Assert.equal(frame:IsEventRegistered("PLAYER_MOUNT_DISPLAY_CHANGED"), false)

  db.mountedEnabled = true
  Controller.OnSettingChanged("mountedEnabled")
  Assert.equal(frame:IsEventRegistered("PLAYER_MOUNT_DISPLAY_CHANGED"), true)

  db.mountedEnabled = false
  Controller.OnSettingChanged("mountedEnabled")
  Assert.equal(frame:IsEventRegistered("PLAYER_MOUNT_DISPLAY_CHANGED"), false)
end

local function test_druid_forms_toggle_registers_shapeshift_event()
  local W, db = Helper.setup()
  W.class = "DRUID"
  local frame = Helper.frame(W)

  db.mountedEnabled = true
  Controller.OnSettingChanged("mountedEnabled")
  Assert.equal(frame:IsEventRegistered("UPDATE_SHAPESHIFT_FORM"), true)

  db.druidForms = false
  Controller.OnSettingChanged("druidForms")
  Assert.equal(frame:IsEventRegistered("UPDATE_SHAPESHIFT_FORM"), false)
end

local function test_non_druid_never_registers_shapeshift_event()
  local W = Helper.setup({ mountedEnabled = true })

  Assert.equal(Helper.frame(W):IsEventRegistered("UPDATE_SHAPESHIFT_FORM"), false)
end

local function test_defaults_recompute_events()
  local W, db = Helper.setup({ mountedEnabled = true, combatEnabled = true })
  local frame = Helper.frame(W)
  Assert.equal(frame:IsEventRegistered("PLAYER_REGEN_DISABLED"), true)

  Defaults.Reset(db)
  Controller.OnSettingChanged("*defaults")

  Assert.equal(frame:IsEventRegistered("PLAYER_MOUNT_DISPLAY_CHANGED"), false)
  Assert.equal(frame:IsEventRegistered("PLAYER_REGEN_DISABLED"), false)
  Assert.equal(frame:IsEventRegistered("PLAYER_ENTERING_WORLD"), true)
end

local function test_mount_event_switches_to_mounted()
  local W = Helper.setup({ mountedEnabled = true, focusEnemyMounted = true })
  W.Fire("PLAYER_ENTERING_WORLD")

  W.mounted = true
  W.Fire("PLAYER_MOUNT_DISPLAY_CHANGED")

  Assert.equal(Controller.ActiveMode(), "mounted")
  Assert.equal(W.cvars.test_cameraTargetFocusEnemyEnable, "1")
  Assert.equal(W.cvars.test_cameraDynamicPitch, "0")
end

return function()
  test_enter_world_on_foot_applies_defaults()
  test_same_mode_setting_reapply_writes_nothing()
  test_event_with_unchanged_mode_reads_no_cvar()
  test_install_only_writes_scroll_speed()
  test_scroll_speed_change_writes_zoom_speed()
  test_off_resets_cvars_and_cancels_timers()
  test_no_action_cam_writes_nothing()
  test_mounted_toggle_registers_mount_event()
  test_druid_forms_toggle_registers_shapeshift_event()
  test_non_druid_never_registers_shapeshift_event()
  test_defaults_recompute_events()
  test_mount_event_switches_to_mounted()
end
