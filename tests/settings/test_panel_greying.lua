-- Options page: rows grey out while their mode switch or parent is off,
-- and Refresh / Defaults keep built widgets and greying in step with db.
local Assert = require("tests.helpers.assert")
local P = require("tests.helpers.panel")

local function enabled(widget)
  return widget.frame:IsEnabled()
end

local function test_combat_rows_grey_while_combat_off_switch_never_greys()
  local ctx = P.setup()
  P.open(ctx)
  local combat = P.tab(ctx, "Combat")
  Assert.equal(enabled(combat.offsetCombat), false)
  Assert.equal(enabled(combat.distanceCombat), false)
  Assert.equal(enabled(combat.combatEnabled), true, "the switch itself stays usable")

  combat.combatEnabled.frame:Click()
  Assert.equal(enabled(combat.offsetCombat), true)
  Assert.equal(enabled(combat.distanceCombat), true)

  combat.combatEnabled.frame:Click()
  Assert.equal(enabled(combat.offsetCombat), false)
end

local function test_mounted_rows_grey_incl_druid_forms()
  local ctx = P.setup()
  P.open(ctx)
  local mounted = P.tab(ctx, "Mounted")
  Assert.equal(enabled(mounted.druidForms), false)
  Assert.equal(enabled(mounted.mountedEnabled), true)

  mounted.mountedEnabled.frame:Click()

  Assert.equal(enabled(mounted.druidForms), true)
  Assert.equal(enabled(mounted.distanceMounted), true)
end

local function test_on_foot_rows_have_no_switch()
  local ctx = P.setup()
  P.open(ctx)
  local onFoot = P.tab(ctx, "On foot")

  Assert.equal(enabled(onFoot.offsetOnFoot), true)
  Assert.equal(enabled(onFoot.distanceOnFoot), true)
end

local function test_distance_greys_with_zoom_and_is_indented()
  local ctx = P.setup()
  P.open(ctx)
  local onFoot = P.tab(ctx, "On foot")
  local zoomX = onFoot.zoomOnFoot.frame.point[4]
  Assert.equal(onFoot.distanceOnFoot.frame.point[4] > zoomX, true, "indented under its parent")

  onFoot.zoomOnFoot.frame:Click()
  Assert.equal(enabled(onFoot.distanceOnFoot), false)
  Assert.equal(ctx.db.distanceOnFoot, 39, "saved value untouched")

  onFoot.zoomOnFoot.frame:Click()
  Assert.equal(enabled(onFoot.distanceOnFoot), true)
end

local function test_distance_combat_stays_grey_while_combat_off_even_with_zoom_on()
  local ctx = P.setup()
  P.open(ctx)
  local combat = P.tab(ctx, "Combat")

  Assert.equal(ctx.db.zoomCombat, true)
  Assert.equal(enabled(combat.distanceCombat), false)
  combat.zoomCombat.frame:Click()
  combat.zoomCombat.frame:Click()
  Assert.equal(enabled(combat.distanceCombat), false)
end

-- Counts SetActive calls on every built widget.
local function spyActive()
  local calls = { count = 0 }
  for _, record in ipairs(P.built) do
    local widget = record.widget
    local setActive = widget.SetActive
    widget.SetActive = function(...)
      calls.count = calls.count + 1
      return setActive(...)
    end
  end
  return calls
end

local function test_slider_drag_does_not_regrey_but_zoom_click_does()
  local ctx = P.setup()
  P.open(ctx)
  local onFoot = P.tab(ctx, "On foot")
  local calls = spyActive()

  onFoot.distanceOnFoot.frame:SetValue(20)
  Assert.equal(calls.count, 0, "slider drag")

  onFoot.zoomOnFoot.frame:Click()
  Assert.equal(calls.count > 0, true, "parent click re-greys")
end

local function test_refresh_after_outside_change_updates_and_regreys()
  local ctx = P.setup()
  P.open(ctx)
  local combat = P.tab(ctx, "Combat")

  ctx.db.combatEnabled = true
  ctx.Panel.Refresh()

  Assert.equal(combat.combatEnabled.frame:GetChecked(), true)
  Assert.equal(enabled(combat.offsetCombat), true)
  Assert.equal(#ctx.changes, 0)
end

local function test_refresh_with_unbuilt_tabs_is_safe()
  local ctx = P.setup()
  ctx.Panel.Refresh()
  P.open(ctx)
  local frames = #ctx.W.frames

  ctx.Panel.Refresh()

  Assert.equal(#ctx.W.frames, frames, "refresh builds nothing")
  Assert.equal(select(2, P.widgetsOn(P.tabFrame(ctx, "Combat"))), 0)
end

local function test_refresh_shows_remembered_distance_without_reporting()
  local ctx = P.setup()
  P.open(ctx)
  local onFoot = P.tab(ctx, "On foot")
  ctx.db.distanceOnFoot = 22.5

  ctx.Panel.Refresh()

  Assert.equal(onFoot.distanceOnFoot.frame:GetValue(), 22.5)
  Assert.equal(ctx.db.distanceOnFoot, 22.5)
  Assert.equal(#ctx.changes, 0)
end

local function test_defaults_resets_unbuilt_tabs_reports_once_and_regreys()
  local ctx = P.setup()
  P.open(ctx)
  local combat = P.tab(ctx, "Combat")
  combat.combatEnabled.frame:Click()
  ctx.db.pitchFlying = 0.1
  local changesBefore = #ctx.changes

  P.canvas(ctx).OnDefault()

  Assert.equal(#ctx.changes, changesBefore + 1, "one change report")
  Assert.equal(ctx.changes[#ctx.changes], "*defaults")
  Assert.equal(ctx.db.pitchFlying, 0.75, "Camera feel never opened, still reset")
  Assert.equal(ctx.db.combatEnabled, false)
  Assert.equal(combat.combatEnabled.frame:GetChecked(), false, "built tab refreshed")
  Assert.equal(enabled(combat.offsetCombat), false, "combat rows greyed again")
end

local function test_defaults_with_nothing_changed_reports_nothing()
  local ctx = P.setup()

  P.canvas(ctx).OnDefault()

  Assert.equal(#ctx.changes, 0)
end

return function()
  test_combat_rows_grey_while_combat_off_switch_never_greys()
  test_mounted_rows_grey_incl_druid_forms()
  test_on_foot_rows_have_no_switch()
  test_distance_greys_with_zoom_and_is_indented()
  test_distance_combat_stays_grey_while_combat_off_even_with_zoom_on()
  test_slider_drag_does_not_regrey_but_zoom_click_does()
  test_refresh_after_outside_change_updates_and_regreys()
  test_refresh_with_unbuilt_tabs_is_safe()
  test_refresh_shows_remembered_distance_without_reporting()
  test_defaults_resets_unbuilt_tabs_reports_once_and_regreys()
  test_defaults_with_nothing_changed_reports_nothing()
end
