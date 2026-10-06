local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local Localization = require("ShoulderCam.Core.Localization")
local Widgets = require("ShoulderCam.Settings.Widgets")

local ROW_X, ROW_Y = 16, -40

-- Fresh fake client, default db and a recorder for onChanged calls.
local function setup()
  local W = Wow.Install()
  local db = {}
  Defaults.Reset(db)
  local changes = {}
  local function onChanged(key)
    changes[#changes + 1] = key
  end
  return W, db, changes, onChanged
end

local function test_checkbox_shows_saved_value_with_localized_label()
  local W, db, _changes, onChanged = setup()
  Localization.catalog["Left shoulder"] = "Linke Schulter"
  db.leftShoulder = true

  local box = Widgets.Checkbox(W.frames[1], Defaults.byKey.leftShoulder, ROW_X, ROW_Y, db, onChanged)

  Localization.catalog["Left shoulder"] = nil
  Assert.equal(box.frame.template, "UICheckButtonTemplate")
  Assert.equal(box.frame:GetChecked(), true)
  Assert.equal(box.label:GetText(), "Linke Schulter")
  Assert.equal(box.key, "leftShoulder")
end

local function test_checkbox_click_writes_db_and_reports_key()
  local W, db, changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], Defaults.byKey.syncOffset, ROW_X, ROW_Y, db, onChanged)

  box.frame:Click()

  Assert.equal(db.syncOffset, false)
  Assert.equal(#changes, 1)
  Assert.equal(changes[1], "syncOffset")
end

local function test_checkbox_refresh_reads_db_without_reporting()
  local W, db, changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], Defaults.byKey.enabled, ROW_X, ROW_Y, db, onChanged)
  db.enabled = false

  box:Refresh(db)

  Assert.equal(box.frame:GetChecked(), false)
  Assert.equal(#changes, 0)
end

local function test_checkbox_set_active_greys_box_and_label()
  local W, db, _changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], Defaults.byKey.enabled, ROW_X, ROW_Y, db, onChanged)
  local activeFont = box.label.fontObject

  box:SetActive(false)
  Assert.equal(box.frame:IsEnabled(), false)
  Assert.equal(box.label.fontObject ~= activeFont, true, "label greyed")

  box:SetActive(true)
  Assert.equal(box.frame:IsEnabled(), true)
  Assert.equal(box.label.fontObject, activeFont)
end

local function test_slider_inits_from_entry_range()
  local W, db, _changes, onChanged = setup()
  db.maxDistance = 30

  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.maxDistance, ROW_X, ROW_Y, db, onChanged)

  local frame = slider.frame
  Assert.equal(frame.template, "MinimalSliderWithSteppersTemplate")
  Assert.equal(frame:GetValue(), 30)
  Assert.equal(frame.min, 15)
  Assert.equal(frame.max, 39)
  Assert.equal(frame.steps, 48)
  Assert.equal(slider.label:GetText(), "Max camera distance (yd)")
  Assert.equal(slider.label.point[5] > frame.point[5], true, "title sits above the slider")
end

local function test_slider_change_writes_db_and_reports_key()
  local W, db, changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.scrollSpeed, ROW_X, ROW_Y, db, onChanged)

  slider.frame:SetValue(25)

  Assert.equal(db.scrollSpeed, 25)
  Assert.equal(#changes, 1)
  Assert.equal(changes[1], "scrollSpeed")
end

local function test_slider_value_snaps_to_step()
  local W, db, _changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.offsetTime, ROW_X, ROW_Y, db, onChanged)

  slider.frame:SetValue(1.3)

  Assert.equal(db.offsetTime, 1.25)
end

local function test_slider_snap_stores_clean_decimal()
  local W, db, _changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.pitchStrength, ROW_X, ROW_Y, db, onChanged)

  slider.frame:SetValue(0.351)

  Assert.equal(db.pitchStrength == 0.35, true, "db holds 0.35, got " .. string.format("%.17g", db.pitchStrength))
end

local function rightLabel(W, key, value)
  local db = {}
  Defaults.Reset(db)
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey[key], ROW_X, ROW_Y, db, function() end)
  return slider.frame.formatters[_G.MinimalSliderWithSteppersMixin.Label.Right](value)
end

local function test_slider_label_shows_clean_number()
  local W = setup()

  Assert.equal(rightLabel(W, "pitchStrength", 7 * 0.05), "0.35")
  Assert.equal(rightLabel(W, "pitchStrength", 0.5), "0.5")
  Assert.equal(rightLabel(W, "distanceMounted", 36.5), "36.5")
  Assert.equal(rightLabel(W, "scrollSpeed", 20), "20")
  Assert.equal(rightLabel(W, "scrollSpeed", 20.0), "20", "no 20.0 on Lua 5.3+")
end

-- Our API lives on a wrapper so it can never shadow a Blizzard template
-- or mixin member of the same name.
local function test_widgets_add_nothing_to_blizzard_frames()
  local W, db, _changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], Defaults.byKey.enabled, ROW_X, ROW_Y, db, onChanged)
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.scrollSpeed, ROW_X, ROW_Y, db, onChanged)

  for _, frame in ipairs({ box.frame, slider.frame }) do
    for _, name in ipairs({ "Refresh", "SetActive", "label", "key", "refreshing" }) do
      Assert.equal(rawget(frame, name), nil, frame.template .. " got " .. name)
    end
  end
  Assert.equal(box.key, "enabled")
  Assert.equal(slider.key, "scrollSpeed")
end

local function test_slider_same_value_reports_nothing()
  local W, db, changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.scrollSpeed, ROW_X, ROW_Y, db, onChanged)

  slider.frame:SetValue(20.2)

  Assert.equal(db.scrollSpeed, 20)
  Assert.equal(#changes, 0)
end

local function test_slider_refresh_does_not_write_back()
  local W, db, changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.distanceOnFoot, ROW_X, ROW_Y, db, onChanged)
  local remembered = 12.3
  db.distanceOnFoot = remembered

  slider:Refresh(db)

  Assert.equal(slider.frame:GetValue(), remembered)
  Assert.equal(db.distanceOnFoot, remembered, "refresh never snaps or rewrites db")
  Assert.equal(#changes, 0)
end

local function test_slider_set_active_greys_slider_and_title()
  local W, db, _changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], Defaults.byKey.distanceCombat, ROW_X, ROW_Y, db, onChanged)
  local activeFont = slider.label.fontObject

  slider:SetActive(false)
  Assert.equal(slider.frame:IsEnabled(), false)
  Assert.equal(slider.label.fontObject ~= activeFont, true, "title greyed")

  slider:SetActive(true)
  Assert.equal(slider.frame:IsEnabled(), true)
  Assert.equal(slider.label.fontObject, activeFont)
end

return function()
  test_checkbox_shows_saved_value_with_localized_label()
  test_checkbox_click_writes_db_and_reports_key()
  test_checkbox_refresh_reads_db_without_reporting()
  test_checkbox_set_active_greys_box_and_label()
  test_slider_inits_from_entry_range()
  test_slider_change_writes_db_and_reports_key()
  test_slider_value_snaps_to_step()
  test_slider_snap_stores_clean_decimal()
  test_slider_label_shows_clean_number()
  test_widgets_add_nothing_to_blizzard_frames()
  test_slider_same_value_reports_nothing()
  test_slider_refresh_does_not_write_back()
  test_slider_set_active_greys_slider_and_title()
end
