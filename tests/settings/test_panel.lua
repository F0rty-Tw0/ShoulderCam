local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local Widgets = require("ShoulderCam.Settings.Widgets")

local PANEL_MODULE = "Settings.Panel"
local UNAVAILABLE = "Action camera is not available in this game version."

-- Fresh fake client and a freshly loaded Panel (it keeps its pages in
-- module state), registered on a default db.
local function setup(hasActionCam)
  local W = Wow.Install()
  FlavorCompat.hasActionCam = hasActionCam ~= false
  FlavorCompat.hasSettingsApi = true
  package.loaded[PANEL_MODULE] = nil
  local Panel = require("ShoulderCam.Settings.Panel")
  local db = {}
  Defaults.Reset(db)
  local changes = {}
  local category = Panel.Register(db, function(key)
    changes[#changes + 1] = key
  end)
  return { W = W, Panel = Panel, db = db, changes = changes, category = category }
end

local function show(page)
  page.scripts.OnShow(page)
end

local function mainPage(ctx)
  return ctx.W.categories[1].frame
end

local function situationsPage(ctx)
  return ctx.W.categories[2].frame
end

-- Every widget the panel builds, recorded as Widgets returns it.
local built = {}
for _, name in ipairs({ "Checkbox", "Slider" }) do
  local create = Widgets[name]
  Widgets[name] = function(parent, ...)
    local widget = create(parent, ...)
    built[#built + 1] = { parent = parent, widget = widget }
    return widget
  end
end

-- key -> Blizzard frame of every setting widget built on `page`.
local function widgetsOn(_ctx, page)
  local byKey, count = {}, 0
  for _, record in ipairs(built) do
    local key = record.widget.key
    if record.parent == page then
      Assert.equal(byKey[key], nil, "duplicate widget for " .. key)
      byKey[key] = record.widget.frame
      count = count + 1
    end
  end
  return byKey, count
end

local function keysOfPage(pageName)
  local keys, page = {}, nil
  for _, entry in ipairs(Defaults.list) do
    page = entry.page or page
    if entry.key and page == pageName then
      keys[#keys + 1] = entry.key
    end
  end
  return keys
end

local function assertListsEveryKey(ctx, page, pageName)
  local byKey, count = widgetsOn(ctx, page)
  local keys = keysOfPage(pageName)
  for _, key in ipairs(keys) do
    Assert.equal(byKey[key] ~= nil, true, "missing widget for " .. key)
  end
  Assert.equal(count, #keys)
end

local function test_registers_main_category_and_situations_subcategory()
  local ctx = setup()

  Assert.equal(#ctx.W.categories, 2)
  Assert.equal(ctx.category, ctx.W.categories[1])
  Assert.equal(ctx.category.name, "ShoulderCam")
  Assert.equal(ctx.W.addOnCategories[1], ctx.category)
  Assert.equal(ctx.W.categories[2].name, "Situations")
  Assert.equal(ctx.W.categories[2].parent, ctx.category)
end

local function test_nothing_built_before_first_show()
  local ctx = setup()
  local framesAtRegister = #ctx.W.frames

  ctx.Panel.Refresh()

  Assert.equal(#ctx.W.frames, framesAtRegister, "refresh before show builds nothing")
  Assert.equal(#ctx.changes, 0)
  show(mainPage(ctx))
  local framesAfterShow = #ctx.W.frames
  Assert.equal(framesAfterShow > framesAtRegister, true)
  show(mainPage(ctx))
  Assert.equal(#ctx.W.frames, framesAfterShow, "built once")
  Assert.equal(select(2, widgetsOn(ctx, situationsPage(ctx))), 0, "situations waits for its own show")
end

local function test_main_page_lists_every_main_key_once()
  local ctx = setup()
  show(mainPage(ctx))
  assertListsEveryKey(ctx, mainPage(ctx), "main")
end

local function test_situations_page_lists_every_situation_key_in_three_columns()
  local ctx = setup()
  show(situationsPage(ctx))
  assertListsEveryKey(ctx, situationsPage(ctx), "situations")

  local byKey = widgetsOn(ctx, situationsPage(ctx))
  local onFootX = byKey.offsetOnFoot.point[4]
  local combatX = byKey.offsetCombat.point[4]
  local mountedX = byKey.offsetMounted.point[4]
  Assert.equal(onFootX < combatX and combatX < mountedX, true)
end

local function test_checkbox_click_writes_db_and_reports_key()
  local ctx = setup()
  show(mainPage(ctx))

  widgetsOn(ctx, mainPage(ctx)).leftShoulder:Click()

  Assert.equal(ctx.db.leftShoulder, true)
  Assert.equal(#ctx.changes, 1)
  Assert.equal(ctx.changes[1], "leftShoulder")
end

local function test_slider_change_writes_db()
  local ctx = setup()
  show(mainPage(ctx))

  widgetsOn(ctx, mainPage(ctx)).scrollSpeed:SetValue(25)

  Assert.equal(ctx.db.scrollSpeed, 25)
  Assert.equal(ctx.changes[1], "scrollSpeed")
end

local function test_combat_column_greys_while_combat_mode_off()
  local ctx = setup()
  show(situationsPage(ctx))
  local byKey = widgetsOn(ctx, situationsPage(ctx))
  Assert.equal(byKey.offsetCombat:IsEnabled(), false)
  Assert.equal(byKey.distanceCombat:IsEnabled(), false)
  Assert.equal(byKey.combatEnabled:IsEnabled(), true, "the toggle itself stays usable")
  Assert.equal(byKey.offsetOnFoot:IsEnabled(), true)

  byKey.combatEnabled:Click()
  Assert.equal(byKey.offsetCombat:IsEnabled(), true)
  Assert.equal(byKey.distanceCombat:IsEnabled(), true)
  Assert.equal(byKey.offsetMounted:IsEnabled(), false, "mounted column follows its own toggle")

  byKey.combatEnabled:Click()
  Assert.equal(byKey.offsetCombat:IsEnabled(), false)
end

local function test_mounted_column_greys_while_mounted_mode_off()
  local ctx = setup()
  show(situationsPage(ctx))
  local byKey = widgetsOn(ctx, situationsPage(ctx))
  Assert.equal(byKey.druidForms:IsEnabled(), false)
  Assert.equal(byKey.mountedEnabled:IsEnabled(), true)

  byKey.mountedEnabled:Click()

  Assert.equal(byKey.druidForms:IsEnabled(), true)
  Assert.equal(byKey.distanceMounted:IsEnabled(), true)
end

local function test_refresh_shows_remembered_distance_without_reporting()
  local ctx = setup()
  show(situationsPage(ctx))
  ctx.db.distanceOnFoot = 22.5

  ctx.Panel.Refresh()

  Assert.equal(widgetsOn(ctx, situationsPage(ctx)).distanceOnFoot:GetValue(), 22.5)
  Assert.equal(ctx.db.distanceOnFoot, 22.5)
  Assert.equal(#ctx.changes, 0)
end

local function test_defaults_from_situations_resets_main_key_once()
  local ctx = setup()
  show(mainPage(ctx))
  show(situationsPage(ctx))
  widgetsOn(ctx, mainPage(ctx)).scrollSpeed:SetValue(10)
  widgetsOn(ctx, situationsPage(ctx)).combatEnabled:Click()
  local changesBefore = #ctx.changes

  situationsPage(ctx).OnDefault()

  Assert.equal(#ctx.changes, changesBefore + 1, "one change report")
  Assert.equal(ctx.changes[#ctx.changes], "*defaults")
  Assert.equal(ctx.db.scrollSpeed, 20)
  Assert.equal(ctx.db.combatEnabled, false)
  Assert.equal(widgetsOn(ctx, mainPage(ctx)).scrollSpeed:GetValue(), 20, "main page refreshed")
  local situations = widgetsOn(ctx, situationsPage(ctx))
  Assert.equal(situations.combatEnabled:GetChecked(), false, "situations page refreshed")
  Assert.equal(situations.offsetCombat:IsEnabled(), false, "combat column greyed again")
end

local function test_defaults_reports_one_change_even_when_both_pages_reset()
  local ctx = setup()
  ctx.db.scrollSpeed = 10

  situationsPage(ctx).OnDefault()
  mainPage(ctx).OnDefault()

  Assert.equal(#ctx.changes, 1)
  Assert.equal(ctx.changes[1], "*defaults")
end

local function test_open_goes_to_main_category()
  local ctx = setup()

  ctx.Panel.Open()

  Assert.equal(ctx.W.openedCategory, ctx.category:GetID())
end

local function test_no_action_cam_shows_only_unavailable_line()
  local ctx = setup(false)
  Assert.equal(#ctx.W.categories, 1, "no situations page")

  show(mainPage(ctx))

  Assert.equal(select(2, widgetsOn(ctx, mainPage(ctx))), 0)
  local texts = {}
  for _, frame in ipairs(ctx.W.frames) do
    if frame.frameType == "FontString" then
      texts[#texts + 1] = frame:GetText()
    end
  end
  Assert.equal(#texts, 2, "title and the unavailable line")
  Assert.equal(texts[2], UNAVAILABLE)
  ctx.Panel.Refresh()
  mainPage(ctx).OnDefault()
end

local function test_no_settings_api_registers_nothing()
  Wow.Install()
  FlavorCompat.hasSettingsApi = false
  package.loaded[PANEL_MODULE] = nil
  local Panel = require("ShoulderCam.Settings.Panel")

  local category = Panel.Register({}, function() end)

  Assert.equal(category, nil)
  Panel.Open()
  Panel.Refresh()
end

return function()
  test_registers_main_category_and_situations_subcategory()
  test_nothing_built_before_first_show()
  test_main_page_lists_every_main_key_once()
  test_situations_page_lists_every_situation_key_in_three_columns()
  test_checkbox_click_writes_db_and_reports_key()
  test_slider_change_writes_db()
  test_combat_column_greys_while_combat_mode_off()
  test_mounted_column_greys_while_mounted_mode_off()
  test_refresh_shows_remembered_distance_without_reporting()
  test_defaults_from_situations_resets_main_key_once()
  test_defaults_reports_one_change_even_when_both_pages_reset()
  test_open_goes_to_main_category()
  test_no_action_cam_shows_only_unavailable_line()
  test_no_settings_api_registers_nothing()
end
