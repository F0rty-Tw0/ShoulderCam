local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local Localization = require("ShoulderCam.Core.Localization")
local Widgets = require("ShoulderCam.Settings.Widgets")

local ROW_X, ROW_Y = 16, -40

-- Tests that check label, value or hint text use their own entries, so
-- rewording the options in Defaults never breaks them.
local LEFT_SHOULDER = { key = "leftShoulder", default = false, label = "Left shoulder" }
local MAX_DISTANCE = { key = "maxDistance", default = 39, label = "Max camera distance", min = 15, max = 39, step = 0.5 }
local DISTANCE = { key = "distanceMounted", default = 36.5, label = "Zoom distance", min = 1, max = 39, step = 0.5, suffix = "yd" }
local STRENGTH = { key = "focusPitch", default = 0.75, label = "Vertical focus", min = 0, max = 1, step = 0.05, percent = true }
local TIME =
  { key = "offsetTime", default = 2, label = "Shoulder move time", min = 0.25, max = 5, step = 0.25, suffix = "s", hint = "How long it takes." }
local TILT = { key = "pitchOnFoot", default = true, label = "Camera tilt", hint = "Tilts the camera." }

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

  local box = Widgets.Checkbox(W.frames[1], LEFT_SHOULDER, ROW_X, ROW_Y, db, onChanged)

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

  local slider = Widgets.Slider(W.frames[1], MAX_DISTANCE, ROW_X, ROW_Y, db, onChanged)

  local frame = slider.frame
  Assert.equal(frame.template, "MinimalSliderWithSteppersTemplate")
  Assert.equal(frame:GetValue(), 30)
  Assert.equal(frame.min, 15)
  Assert.equal(frame.max, 39)
  Assert.equal(frame.steps, 48)
  Assert.equal(slider.label:GetText(), "Max camera distance")
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

local function rightLabel(W, entry, value)
  local db = { [entry.key] = entry.default }
  local slider = Widgets.Slider(W.frames[1], entry, ROW_X, ROW_Y, db, function() end)
  return slider.frame.formatters[_G.MinimalSliderWithSteppersMixin.Label.Right](value)
end

local function test_slider_label_shows_clean_number()
  local W = setup()
  local strength = { key = "pitchStrength", default = 0.4, min = 0, max = 1, step = 0.05 }
  local distance = { key = "distanceMounted", default = 36.5, min = 1, max = 39, step = 0.5 }
  local speed = { key = "scrollSpeed", default = 20, min = 1, max = 50, step = 1 }

  Assert.equal(rightLabel(W, strength, 7 * 0.05), "0.35")
  Assert.equal(rightLabel(W, strength, 0.5), "0.5")
  Assert.equal(rightLabel(W, distance, 36.5), "36.5")
  Assert.equal(rightLabel(W, speed, 20), "20")
  Assert.equal(rightLabel(W, speed, 20.0), "20", "no 20.0 on Lua 5.3+")
end

local function test_slider_value_shows_yards_suffix()
  local W = setup()

  Assert.equal(rightLabel(W, DISTANCE, 36.5), "36.5 yd")
  Assert.equal(rightLabel(W, DISTANCE, 39), "39 yd")
end

local function test_slider_value_shows_seconds_suffix()
  local W = setup()

  Assert.equal(rightLabel(W, TIME, 1.25), "1.25 s")
end

local function test_slider_value_shows_percent()
  local W = setup()

  Assert.equal(rightLabel(W, STRENGTH, 0.75), "75%")
  Assert.equal(rightLabel(W, STRENGTH, 7 * 0.05), "35%")
  Assert.equal(rightLabel(W, STRENGTH, 0), "0%")
end

local function test_checkbox_hover_shows_label_and_hint()
  local W, db, _changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], TILT, ROW_X, ROW_Y, db, onChanged)
  local tooltip = _G.GameTooltip

  box.frame.scripts.OnEnter(box.frame)
  Assert.equal(tooltip.owner, box.frame)
  Assert.equal(tooltip.anchor, "ANCHOR_RIGHT")
  Assert.equal(tooltip.text, "Camera tilt")
  Assert.equal(tooltip.lines[1], "Tilts the camera.")
  Assert.equal(tooltip.wrap, true)
  Assert.equal(tooltip.shown, true)

  box.frame.scripts.OnLeave(box.frame)
  Assert.equal(tooltip.shown, false)
end

local function test_slider_hover_shows_hint_on_inner_slider()
  local W, db, _changes, onChanged = setup()
  local slider = Widgets.Slider(W.frames[1], TIME, ROW_X, ROW_Y, db, onChanged)
  local track, tooltip = slider.frame.Slider, _G.GameTooltip

  track.scripts.OnEnter(track)
  Assert.equal(tooltip.owner, track)
  Assert.equal(tooltip.text, "Shoulder move time")
  Assert.equal(tooltip.lines[1], "How long it takes.")
  Assert.equal(tooltip.shown, true)

  track.scripts.OnLeave(track)
  Assert.equal(tooltip.shown, false)
end

local function test_checkbox_keeps_hint_while_disabled()
  local W, db, _changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], TILT, ROW_X, ROW_Y, db, onChanged)

  Assert.equal(box.frame.motionWhileDisabled, true)
end

local function test_entry_without_hint_hooks_nothing()
  local W, db, _changes, onChanged = setup()
  local box = Widgets.Checkbox(W.frames[1], LEFT_SHOULDER, ROW_X, ROW_Y, db, onChanged)

  Assert.equal(box.frame.scripts.OnEnter, nil)
end

local function test_slider_without_inner_slider_builds()
  local W, db, _changes, onChanged = setup()
  local createFrame = _G.CreateFrame
  rawset(_G, "CreateFrame", function(...)
    local frame = createFrame(...)
    frame.Slider = nil
    return frame
  end)

  local slider = Widgets.Slider(W.frames[1], TIME, ROW_X, ROW_Y, db, onChanged)

  Assert.equal(slider.key, "offsetTime")
end

-- Our API lives on a wrapper so it can never shadow a Blizzard template
-- or mixin member of the same name.
local function test_widgets_add_nothing_to_blizzard_frames()
  local W, db, _changes, onChanged = setup()
  local enabled = { key = "enabled", default = true, label = "Enable", hint = "Turns it on." }
  local speed = { key = "scrollSpeed", default = 20, label = "Speed", hint = "How fast.", min = 1, max = 50, step = 1 }
  local box = Widgets.Checkbox(W.frames[1], enabled, ROW_X, ROW_Y, db, onChanged)
  local slider = Widgets.Slider(W.frames[1], speed, ROW_X, ROW_Y, db, onChanged)

  for _, frame in ipairs({ box.frame, slider.frame, slider.frame.Slider }) do
    for _, name in ipairs({ "Refresh", "SetActive", "label", "key", "refreshing", "hint" }) do
      Assert.equal(rawget(frame, name), nil, frame.frameType .. " got " .. name)
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
  test_slider_value_shows_yards_suffix()
  test_slider_value_shows_seconds_suffix()
  test_slider_value_shows_percent()
  test_checkbox_hover_shows_label_and_hint()
  test_slider_hover_shows_hint_on_inner_slider()
  test_checkbox_keeps_hint_while_disabled()
  test_entry_without_hint_hooks_nothing()
  test_slider_without_inner_slider_builds()
  test_widgets_add_nothing_to_blizzard_frames()
  test_slider_same_value_reports_nothing()
  test_slider_refresh_does_not_write_back()
  test_slider_set_active_greys_slider_and_title()
end
