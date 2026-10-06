local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local ZoomMemory = require("ShoulderCam.Camera.ZoomMemory")

local POLL = 0.25

local function setup()
  ZoomMemory.Cancel()
  local W = Wow.Install()
  W.saves = {}
  ZoomMemory.onSave = function(modeKey, distance)
    table.insert(W.saves, { modeKey = modeKey, distance = distance })
  end
  return W
end

-- Camera moves to `zoom`, then stays: the next two polls read it twice.
local function settleAt(W, zoom)
  W.zoom = zoom
  W.Advance(POLL * 2)
end

local function test_saves_once_when_zoom_stops()
  local W = setup()
  W.zoom = 20
  ZoomMemory.Start("OnFoot")
  W.Advance(POLL)

  settleAt(W, 25)
  W.Advance(POLL * 4)

  Assert.equal(#W.saves, 1)
  Assert.equal(W.saves[1].modeKey, "OnFoot")
  Assert.equal(W.saves[1].distance, 25)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_rounds_to_nearest_half_yard()
  local W = setup()
  ZoomMemory.Start("OnFoot")

  settleAt(W, 24.8)

  Assert.equal(W.saves[1].distance, 25)
end

local function test_clamps_to_max_distance()
  local W = setup()
  ZoomMemory.Start("OnFoot")

  settleAt(W, 45)

  Assert.equal(W.saves[1].distance, 39)
end

local function test_clamps_to_min_distance()
  local W = setup()
  ZoomMemory.Start("OnFoot")

  settleAt(W, 0.2)

  Assert.equal(W.saves[1].distance, 1)
end

local function test_budget_out_saves_nothing()
  local W = setup()
  W.zoom = 10
  ZoomMemory.Start("OnFoot")

  for _ = 1, 14 do
    W.zoom = W.zoom + 1
    W.Advance(POLL)
  end
  W.Advance(POLL * 4)

  Assert.equal(#W.saves, 0)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_start_resets_budget()
  local W = setup()
  W.zoom = 10
  ZoomMemory.Start("OnFoot")
  for _ = 1, 10 do
    W.zoom = W.zoom + 1
    W.Advance(POLL)
  end

  ZoomMemory.Start("OnFoot")
  for _ = 1, 6 do
    W.zoom = W.zoom + 1
    W.Advance(POLL)
  end
  W.Advance(POLL * 2)

  Assert.equal(#W.saves, 1)
  Assert.equal(W.saves[1].distance, 26)
end

local function test_start_resets_previous_read()
  local W = setup()
  W.zoom = 20
  ZoomMemory.Start("OnFoot")
  W.Advance(POLL)

  ZoomMemory.Start("OnFoot")
  W.Advance(POLL)

  Assert.equal(#W.saves, 0)
  W.Advance(POLL)
  Assert.equal(#W.saves, 1)
end

local function test_second_start_keeps_first_target()
  local W = setup()
  W.zoom = 20
  ZoomMemory.Start("OnFoot")
  W.Advance(POLL / 2)

  ZoomMemory.Start("Combat")
  settleAt(W, 25)

  Assert.equal(#W.saves, 1)
  Assert.equal(W.saves[1].modeKey, "OnFoot")
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_start_after_save_binds_new_target()
  local W = setup()
  ZoomMemory.Start("OnFoot")
  settleAt(W, 25)

  ZoomMemory.Start("Combat")
  settleAt(W, 30)

  Assert.equal(#W.saves, 2)
  Assert.equal(W.saves[2].modeKey, "Combat")
  Assert.equal(W.saves[2].distance, 30)
end

local function test_cancel_saves_nothing_and_stops_timer()
  local W = setup()
  ZoomMemory.Start("OnFoot")
  W.Advance(POLL)

  ZoomMemory.Cancel()
  W.Advance(POLL * 4)

  Assert.equal(#W.saves, 0)
  Assert.equal(W.ActiveTimers(), 0)
end

local function test_start_after_cancel_binds_new_target()
  local W = setup()
  ZoomMemory.Start("OnFoot")
  W.Advance(POLL)
  ZoomMemory.Cancel()

  ZoomMemory.Start("Combat")
  settleAt(W, 25)

  Assert.equal(#W.saves, 1)
  Assert.equal(W.saves[1].modeKey, "Combat")
end

return function()
  test_saves_once_when_zoom_stops()
  test_rounds_to_nearest_half_yard()
  test_clamps_to_max_distance()
  test_clamps_to_min_distance()
  test_budget_out_saves_nothing()
  test_start_resets_budget()
  test_start_resets_previous_read()
  test_second_start_keeps_first_target()
  test_start_after_save_binds_new_target()
  test_cancel_saves_nothing_and_stops_timer()
  test_start_after_cancel_binds_new_target()
end
