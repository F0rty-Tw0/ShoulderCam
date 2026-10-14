local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local P = require("tests.helpers.panel")
local Defaults = require("ShoulderCam.Settings.Defaults")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")

local UNAVAILABLE = "Action camera is not available in this game version."
local CHECKBOX_HEIGHT = 26
local SLIDER_OFFSET_Y = -16

local function test_registers_one_category()
  local ctx = P.setup()

  Assert.equal(#ctx.W.categories, 1)
  Assert.equal(ctx.category, ctx.W.categories[1])
  Assert.equal(ctx.category.name, "Shoulder Cam")
  Assert.equal(ctx.W.addOnCategories[1], ctx.category)
end

local function test_nothing_built_before_first_show()
  local ctx = P.setup()
  local framesAtRegister = #ctx.W.frames

  ctx.Panel.Refresh()

  Assert.equal(P.canvas(ctx):IsShown(), false, "canvas starts hidden")
  Assert.equal(#ctx.W.frames, framesAtRegister, "refresh before show builds nothing")
  Assert.equal(#ctx.changes, 0)
end

-- The settings window shows a page with frame:Show(); that must run OnShow
-- even when the page was never shown before.
local function test_settings_window_show_builds_tabs_and_general()
  local ctx = P.setup()

  P.open(ctx)

  for _, name in ipairs(P.TAB_NAMES) do
    Assert.equal(P.tabButton(ctx, name) ~= nil, true, name .. " tab button")
  end
  Assert.equal(select(2, P.widgetsOn(P.tabFrame(ctx, "General"))) > 0, true, "General built")
  Assert.equal(select(2, P.widgetsOn(P.tabFrame(ctx, "Camera feel"))), 0, "Camera feel waits for its click")
end

local function test_tab_click_builds_rows_once()
  local ctx = P.setup()
  P.open(ctx)

  P.clickTab(ctx, "Combat")
  local _, count = P.widgetsOn(P.tabFrame(ctx, "Combat"))
  local frames = #ctx.W.frames
  P.clickTab(ctx, "General")
  P.clickTab(ctx, "Combat")

  Assert.equal(count > 0, true)
  Assert.equal(#ctx.W.frames, frames, "nothing rebuilt")
end

local function test_tab_click_switches_frame_and_highlight()
  local ctx = P.setup()
  P.open(ctx)
  Assert.equal(P.tabButton(ctx, "General").highlightLocked, true)

  P.clickTab(ctx, "Combat")

  Assert.equal(P.tabFrame(ctx, "Combat"):IsShown(), true)
  Assert.equal(P.tabFrame(ctx, "General"):IsShown(), false)
  Assert.equal(P.tabButton(ctx, "Combat").highlightLocked, true)
  Assert.equal(P.tabButton(ctx, "General").highlightLocked, false)
end

local function test_reclicking_selected_tab_keeps_it_shown()
  local ctx = P.setup()
  P.open(ctx)

  P.clickTab(ctx, "General")

  Assert.equal(P.tabFrame(ctx, "General"):IsShown(), true)
  Assert.equal(P.tabButton(ctx, "General").highlightLocked, true)
end

local function test_reshow_keeps_last_tab()
  local ctx = P.setup()
  P.open(ctx)
  P.clickTab(ctx, "Mounted")

  P.canvas(ctx):Hide()
  P.canvas(ctx):Show()

  Assert.equal(P.tabFrame(ctx, "Mounted"):IsShown(), true)
  Assert.equal(P.tabFrame(ctx, "General"):IsShown(), false)
end

local function test_every_drawn_key_on_exactly_one_tab()
  local ctx = P.setup()
  P.open(ctx)
  local drawn = {}
  for _, name in ipairs(P.TAB_NAMES) do
    for key in pairs(P.tab(ctx, name)) do
      Assert.equal(drawn[key], nil, key .. " drawn twice")
      drawn[key] = name
    end
  end

  for key, entry in pairs(Defaults.byKey) do
    Assert.equal(drawn[key] ~= nil, entry.label ~= nil, key)
  end
  Assert.equal(drawn.minimapAngle, nil, "minimapAngle is stored only")
  Assert.equal(drawn.distanceCombat, "Combat")
end

local function test_entry_without_label_takes_no_row()
  local ctx = P.setup()
  P.open(ctx)
  local general = P.widgetsOn(P.tabFrame(ctx, "General"))

  local rowY = general.minimapButton.frame.point[5]
  Assert.equal(general.scrollSpeed.frame.point[5], rowY - CHECKBOX_HEIGHT + SLIDER_OFFSET_Y, "slider right below the checkbox")
end

local function test_general_columns_sit_side_by_side()
  local ctx = P.setup()
  P.open(ctx)
  local general = P.widgetsOn(P.tabFrame(ctx, "General"))

  Assert.equal(general.offsetAmount.frame.point[4] > general.enabled.frame.point[4], true)
end

local function test_checkbox_click_writes_db_and_reports_key()
  local ctx = P.setup()
  P.open(ctx)

  P.widgetsOn(P.tabFrame(ctx, "General")).leftShoulder.frame:Click()

  Assert.equal(ctx.db.leftShoulder, true)
  Assert.equal(#ctx.changes, 1)
  Assert.equal(ctx.changes[1], "leftShoulder")
end

local function test_slider_change_writes_db()
  local ctx = P.setup()
  P.open(ctx)

  P.widgetsOn(P.tabFrame(ctx, "General")).scrollSpeed.frame:SetValue(25)

  Assert.equal(ctx.db.scrollSpeed, 25)
  Assert.equal(ctx.changes[1], "scrollSpeed")
end

local function test_canvas_keeps_settings_window_callbacks()
  local ctx = P.setup()

  Assert.equal(P.canvas(ctx).OnRefresh, ctx.Panel.Refresh)
  Assert.equal(type(P.canvas(ctx).OnCommit), "function")
  Assert.equal(type(P.canvas(ctx).OnDefault), "function")
end

local function test_open_goes_to_main_category()
  local ctx = P.setup()

  ctx.Panel.Open()

  Assert.equal(ctx.W.openedCategory, ctx.category:GetID())
end

local function test_no_action_cam_shows_only_unavailable_line()
  local ctx = P.setup(false)
  Assert.equal(#ctx.W.categories, 1)

  P.open(ctx)

  local texts = {}
  for _, frame in ipairs(ctx.W.frames) do
    if frame.frameType == "FontString" then
      texts[#texts + 1] = frame:GetText()
    end
  end
  Assert.equal(#texts, 2, "title and the unavailable line")
  Assert.equal(texts[2], UNAVAILABLE)
  Assert.equal(P.tabButton(ctx, "General"), nil, "no tabs")
  ctx.Panel.Refresh()
  P.canvas(ctx).OnDefault()
end

local function test_no_settings_api_registers_nothing()
  Wow.Install()
  FlavorCompat.hasSettingsApi = false
  package.loaded["Settings.Panel"] = nil
  local Panel = require("ShoulderCam.Settings.Panel")

  local category = Panel.Register({}, function() end)

  Assert.equal(category, nil)
  Panel.Open()
  Panel.Refresh()
end

return function()
  test_registers_one_category()
  test_nothing_built_before_first_show()
  test_settings_window_show_builds_tabs_and_general()
  test_tab_click_builds_rows_once()
  test_tab_click_switches_frame_and_highlight()
  test_reclicking_selected_tab_keeps_it_shown()
  test_reshow_keeps_last_tab()
  test_every_drawn_key_on_exactly_one_tab()
  test_entry_without_label_takes_no_row()
  test_general_columns_sit_side_by_side()
  test_checkbox_click_writes_db_and_reports_key()
  test_slider_change_writes_db()
  test_canvas_keeps_settings_window_callbacks()
  test_open_goes_to_main_category()
  test_no_action_cam_shows_only_unavailable_line()
  test_no_settings_api_registers_nothing()
end
