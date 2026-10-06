local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Offset = require("ShoulderCam.Camera.Offset")

local TOLERANCE = 0.05

local function setup()
  Offset.Stop()
  return Wow.Install()
end

local function offsetValue(W)
  return tonumber(W.cvars.test_cameraOverShoulder)
end

local function assertNear(actual, expected)
  if math.abs(actual - expected) > TOLERANCE then
    error(string.format("expected %s +- %s, got %s", tostring(expected), tostring(TOLERANCE), tostring(actual)), 2)
  end
end

local function test_halfway_after_half_the_duration()
  local W = setup()

  Offset.MoveTo(1, 2)
  W.Advance(1)

  assertNear(offsetValue(W), 0.5)
  Assert.equal(W.ActiveTimers(), 1)
end

local function test_arrives_exactly_and_cancels_ticker()
  local W = setup()

  Offset.MoveTo(1, 2)
  W.Advance(1)
  W.Advance(1.1)

  Assert.equal(W.cvars.test_cameraOverShoulder, "1")
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_retarget_continues_from_current_value()
  local W = setup()
  Offset.MoveTo(1, 2)
  W.Advance(1)
  local midway = offsetValue(W)

  Offset.MoveTo(0, 2)
  Assert.equal(W.ActiveTimers(), 1)
  W.Advance(0.1)

  local value = offsetValue(W)
  assert(value < midway and value > midway - 2 * TOLERANCE, "expected a step down from " .. midway .. ", got " .. value)
  Assert.equal(W.ActiveTimers(), 1)
  W.Advance(2)
  Assert.equal(W.cvars.test_cameraOverShoulder, "0")
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_zero_duration_sets_instantly()
  local W = setup()

  Offset.MoveTo(-1.5, 0)

  Assert.equal(#W.setCVarCalls, 1)
  Assert.equal(W.cvars.test_cameraOverShoulder, "-1.5")
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_same_value_starts_no_ticker()
  local W = setup()

  Offset.MoveTo(0, 2)

  Assert.equal(#W.setCVarCalls, 0)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_stop_keeps_value_and_kills_ticker()
  local W = setup()
  Offset.MoveTo(1, 2)
  W.Advance(0.5)
  local value = W.cvars.test_cameraOverShoulder
  local writes = #W.setCVarCalls

  Offset.Stop()
  W.Advance(3)

  Assert.equal(W.cvars.test_cameraOverShoulder, value)
  Assert.equal(#W.setCVarCalls, writes)
  Assert.equal(W.ActiveTimers(), 0)
end

return function()
  test_halfway_after_half_the_duration()
  test_arrives_exactly_and_cancels_ticker()
  test_retarget_continues_from_current_value()
  test_zero_duration_sets_instantly()
  test_same_value_starts_no_ticker()
  test_stop_keeps_value_and_kills_ticker()
end
