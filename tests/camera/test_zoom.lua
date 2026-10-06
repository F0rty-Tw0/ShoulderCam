local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Zoom = require("ShoulderCam.Camera.Zoom")

local TRANSITION_SPEED = 40
local SCROLL_SPEED = 20

local function setup()
  Zoom.Cancel()
  local W = Wow.Install()
  W.manualZooms = 0
  Zoom.Install(function()
    W.manualZooms = W.manualZooms + 1
  end)
  return W
end

local function count(W, name)
  return W.calls[name] or 0
end

local function logNames(W)
  local names = {}
  for index, entry in ipairs(W.log) do
    names[index] = entry.name
  end
  return table.concat(names, ",")
end

local function startOutTransition(W)
  W.zoom = 10
  return Zoom.To(39, TRANSITION_SPEED, SCROLL_SPEED)
end

local function test_starts_moving_out_at_speed_ratio()
  local W = setup()

  local duration = startOutTransition(W)

  Assert.equal(duration, 29 / 40)
  Assert.equal(logNames(W), "MoveViewOutStart")
  Assert.equal(W.log[1].args[1], 2)
  Assert.equal(W.ActiveTimers(), 1)
  Assert.equal(Zoom.IsRunning(), true)
end

local function test_moves_in_when_target_is_closer()
  local W = setup()
  W.zoom = 20

  local duration = Zoom.To(10, TRANSITION_SPEED, SCROLL_SPEED)

  Assert.equal(duration, 10 / 40)
  Assert.equal(logNames(W), "MoveViewInStart")
end

local function test_stops_both_directions_when_timer_fires()
  local W = setup()
  startOutTransition(W)

  W.Advance(0.7)
  Assert.equal(count(W, "MoveViewOutStop"), 0)
  W.zoom = 39
  W.Advance(0.03)

  Assert.equal(logNames(W), "MoveViewOutStart,MoveViewOutStop,MoveViewInStop")
  Assert.equal(W.ActiveTimers(), 0)
  Assert.equal(Zoom.IsRunning(), false)
end

local function test_corrects_remaining_difference_after_stop()
  local W = setup()
  startOutTransition(W)
  W.zoom = 38.5

  W.Advance(1)

  Assert.equal(logNames(W), "MoveViewOutStart,MoveViewOutStop,MoveViewInStop,CameraZoomOut")
  Assert.equal(W.log[4].args[1], 0.5)
end

local function test_skips_correction_below_minimum()
  local W = setup()
  startOutTransition(W)
  W.zoom = 38.97

  W.Advance(1)

  Assert.equal(count(W, "CameraZoomOut"), 0)
  Assert.equal(count(W, "CameraZoomIn"), 0)
end

local function test_small_difference_does_nothing()
  local W = setup()
  W.zoom = 20

  local duration = Zoom.To(20.05, TRANSITION_SPEED, SCROLL_SPEED)

  Assert.equal(duration, nil)
  Assert.equal(#W.log, 0)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_manual_zoom_cancels_transition_without_correction()
  local W = setup()
  startOutTransition(W)

  _G.CameraZoomIn(1)
  W.zoom = 20
  W.Advance(2)

  Assert.equal(logNames(W), "MoveViewOutStart,CameraZoomIn,MoveViewOutStop")
  Assert.equal(W.ActiveTimers(), 0)
  Assert.equal(Zoom.IsRunning(), false)
  Assert.equal(W.manualZooms, 1)
end

local function test_manual_start_in_same_direction_keeps_movement()
  local W = setup()
  startOutTransition(W)

  _G.MoveViewOutStart(1)

  Assert.equal(count(W, "MoveViewOutStop"), 0)
  Assert.equal(count(W, "MoveViewInStop"), 0)
  Assert.equal(W.ActiveTimers(), 0)
  Assert.equal(W.manualZooms, 1)
end

local function test_manual_start_in_other_direction_stops_own_movement()
  local W = setup()
  startOutTransition(W)

  _G.MoveViewInStart(1)

  Assert.equal(logNames(W), "MoveViewOutStart,MoveViewInStart,MoveViewOutStop")
  Assert.equal(W.manualZooms, 1)
end

local function test_manual_zoom_without_transition_only_notifies()
  local W = setup()

  _G.CameraZoomOut(1)

  Assert.equal(logNames(W), "CameraZoomOut")
  Assert.equal(W.manualZooms, 1)
end

local function test_own_calls_never_count_as_manual()
  local W = setup()
  startOutTransition(W)
  W.zoom = 38
  W.Advance(1)
  Zoom.To(10, TRANSITION_SPEED, SCROLL_SPEED)
  Zoom.Cancel()

  Assert.equal(count(W, "CameraZoomOut"), 1)
  Assert.equal(W.manualZooms, 0)
end

local function test_new_transition_stops_previous_first()
  local W = setup()
  startOutTransition(W)
  W.zoom = 20

  Zoom.To(5, TRANSITION_SPEED, SCROLL_SPEED)

  Assert.equal(logNames(W), "MoveViewOutStart,MoveViewOutStop,MoveViewInStart")
  Assert.equal(W.ActiveTimers(), 1)
  Assert.equal(W.manualZooms, 0)
end

local function test_cancel_stops_movement_and_timer()
  local W = setup()
  startOutTransition(W)

  Zoom.Cancel()
  W.Advance(2)

  Assert.equal(logNames(W), "MoveViewOutStart,MoveViewOutStop")
  Assert.equal(W.ActiveTimers(), 0)
  Assert.equal(Zoom.IsRunning(), false)
end

return function()
  test_starts_moving_out_at_speed_ratio()
  test_moves_in_when_target_is_closer()
  test_stops_both_directions_when_timer_fires()
  test_corrects_remaining_difference_after_stop()
  test_skips_correction_below_minimum()
  test_small_difference_does_nothing()
  test_manual_zoom_cancels_transition_without_correction()
  test_manual_start_in_same_direction_keeps_movement()
  test_manual_start_in_other_direction_stops_own_movement()
  test_manual_zoom_without_transition_only_notifies()
  test_own_calls_never_count_as_manual()
  test_new_transition_stops_previous_first()
  test_cancel_stops_movement_and_timer()
end
