local Assert = require("tests.helpers.assert")
local Defaults = require("ShoulderCam.Settings.Defaults")
local SavedState = require("ShoulderCam.Settings.SavedState")

local function test_new_install_gets_every_default()
  local db = SavedState.Initialize(nil)
  for _, entry in ipairs(Defaults.list) do
    if entry.key then
      Assert.equal(db[entry.key], entry.default, entry.key)
    end
  end
end

local function test_valid_saved_values_survive()
  local db = SavedState.Initialize({ enabled = false, distanceMounted = 20, pitchMounted = true })
  Assert.equal(db.enabled, false)
  Assert.equal(db.distanceMounted, 20)
  Assert.equal(db.pitchMounted, true)
end

local function test_wrong_type_falls_back_to_default()
  local db = SavedState.Initialize({ distanceOnFoot = "39", enabled = 1 })
  Assert.equal(db.distanceOnFoot, 39)
  Assert.equal(db.enabled, true)
end

local function test_slider_above_range_clamps_to_max()
  local db = SavedState.Initialize({ pitchStrength = 7 })
  Assert.equal(db.pitchStrength, 1)
end

local function test_slider_below_range_clamps_to_min()
  local db = SavedState.Initialize({ scrollSpeed = 0 })
  Assert.equal(db.scrollSpeed, 1)
end

local function test_nan_slider_falls_back_to_default()
  local db = SavedState.Initialize({ transitionSpeed = 0 / 0 })
  Assert.equal(db.transitionSpeed, 40)
end

local function test_unknown_saved_keys_are_dropped()
  local db = SavedState.Initialize({ removedSetting = true })
  Assert.equal(db.removedSetting, nil)
end

local function test_non_table_saved_gives_defaults()
  local db = SavedState.Initialize("broken")
  Assert.equal(db.distanceMounted, 36.5)
end

return function()
  test_new_install_gets_every_default()
  test_valid_saved_values_survive()
  test_wrong_type_falls_back_to_default()
  test_slider_above_range_clamps_to_max()
  test_slider_below_range_clamps_to_min()
  test_nan_slider_falls_back_to_default()
  test_unknown_saved_keys_are_dropped()
  test_non_table_saved_gives_defaults()
end
