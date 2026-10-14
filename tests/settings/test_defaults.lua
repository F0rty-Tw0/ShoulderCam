local Assert = require("tests.helpers.assert")
local Defaults = require("ShoulderCam.Settings.Defaults")

-- SPEC.md → Settings, one row per key: { key, default, min, max, step }.
local SPEC = {
  { "enabled", true },
  { "minimapButton", true },
  { "minimapAngle", 225 },
  { "scrollSpeed", 20, 1, 50, 1 },
  { "transitionSpeed", 40, 1, 50, 0.5 },
  { "maxDistance", 39, 15, 39, 0.5 },
  { "offsetAmount", 1, 0.5, 5, 0.5 },
  { "leftShoulder", false },
  { "offsetTime", 2, 0.25, 5, 0.25 },
  { "syncOffset", true },
  { "focusYaw", 1, 0, 1, 0.05 },
  { "focusPitch", 0.75, 0, 1, 0.05 },
  { "pitchStrength", 0.4, 0, 1, 0.05 },
  { "pitchDown", 0.25, 0, 1, 0.05 },
  { "pitchFlying", 0.75, 0, 1, 0.05 },
  { "combatEnabled", false },
  { "mountedEnabled", false },
  { "druidForms", true },
  { "offsetOnFoot", false },
  { "offsetCombat", false },
  { "offsetMounted", false },
  { "focusEnemyOnFoot", false },
  { "focusEnemyCombat", false },
  { "focusEnemyMounted", false },
  { "focusInteractOnFoot", false },
  { "focusInteractCombat", false },
  { "focusInteractMounted", false },
  { "pitchOnFoot", true },
  { "pitchCombat", true },
  { "pitchMounted", false },
  { "zoomOnFoot", true },
  { "zoomCombat", true },
  { "zoomMounted", true },
  { "rememberOnFoot", true },
  { "rememberCombat", true },
  { "rememberMounted", true },
  { "distanceOnFoot", 39, 1, 39, 0.5 },
  { "distanceCombat", 39, 1, 39, 0.5 },
  { "distanceMounted", 36.5, 1, 39, 0.5 },
}

local function test_every_default_and_range_matches_spec()
  for _, row in ipairs(SPEC) do
    local key = row[1]
    local entry = Defaults.byKey[key]
    Assert.equal(entry ~= nil, true, "missing " .. key)
    Assert.equal(entry.default, row[2], key)
    Assert.equal(entry.min, row[3], key .. ".min")
    Assert.equal(entry.max, row[4], key .. ".max")
    Assert.equal(entry.step, row[5], key .. ".step")
    -- minimapAngle is the one stored-only key (the drag saves it).
    if key ~= "minimapAngle" then
      Assert.equal(type(entry.label), "string", key .. ".label")
    end
  end
end

local function test_minimap_entries_follow_enabled_in_general()
  local index = {}
  for i, entry in ipairs(Defaults.list) do
    if entry.key then
      index[entry.key] = i
    end
  end
  Assert.equal(index.minimapButton, index.enabled + 1)
  Assert.equal(index.minimapAngle, index.enabled + 2)
  Assert.equal(Defaults.byKey.minimapButton.label, "Show minimap button")
end

local function test_list_has_no_keys_beyond_spec()
  local count = 0
  for _, entry in ipairs(Defaults.list) do
    if entry.key then
      count = count + 1
    end
  end
  Assert.equal(count, #SPEC)
end

-- Each list entry paired with the tab it sits on.
local function entriesByTab()
  local rows, tab = {}, nil
  for _, entry in ipairs(Defaults.list) do
    tab = entry.tab or tab
    rows[#rows + 1] = { tab = tab, entry = entry }
  end
  return rows
end

local function test_mode_tab_rows_carry_mode()
  local modeOf = { ["On foot"] = "onFoot", Combat = "combat", Mounted = "mounted" }
  for _, row in ipairs(entriesByTab()) do
    local mode = modeOf[row.tab]
    if row.entry.key then
      Assert.equal(row.entry.mode, mode, row.entry.key)
    end
  end
  Assert.equal(Defaults.byKey.druidForms.mode, "mounted")
end

local function test_tabs_in_order()
  Assert.equal(Defaults.list[1].tab ~= nil, true, "list starts with a tab")
  local names = {}
  for _, entry in ipairs(Defaults.list) do
    if entry.tab then
      names[#names + 1] = entry.tab
      Assert.equal(type(entry.intro) == "string" and #entry.intro > 0, true, entry.tab .. " intro")
    end
  end
  Assert.equal(table.concat(names, ","), "General,Camera feel,On foot,Combat,Mounted")
end

local MAX_HINT = 90

local function test_every_drawn_entry_has_short_hint()
  for _, entry in ipairs(Defaults.list) do
    if entry.key and entry.label then
      local hint = entry.hint
      Assert.equal(type(hint) == "string" and #hint > 0 and #hint <= MAX_HINT, true, entry.key .. " hint")
    end
  end
end

local function test_parents_are_earlier_plain_checkboxes_on_same_tab()
  local seen = {}
  for _, row in ipairs(entriesByTab()) do
    local entry = row.entry
    local parent = entry.parent and Defaults.byKey[entry.parent]
    if entry.parent then
      Assert.equal(seen[entry.parent], row.tab, entry.key .. " parent earlier on same tab")
      Assert.equal(parent.min == nil and parent.parent == nil, true, entry.key .. " parent is a plain checkbox")
    end
    if entry.key then
      seen[entry.key] = row.tab
    end
  end
  Assert.equal(Defaults.byKey.distanceOnFoot.parent, "zoomOnFoot")
end

local function test_units_per_spec()
  local units = {
    maxDistance = "yd",
    distanceOnFoot = "yd",
    distanceCombat = "yd",
    distanceMounted = "yd",
    offsetTime = "s",
    focusYaw = "%",
    focusPitch = "%",
    pitchStrength = "%",
    pitchDown = "%",
    pitchFlying = "%",
  }
  for key, entry in pairs(Defaults.byKey) do
    local unit = entry.percent and "%" or entry.suffix
    Assert.equal(unit, units[key], key .. " unit")
  end
end

local function test_only_mode_switches_are_mode_toggles()
  Assert.equal(Defaults.byKey.combatEnabled.mode, "combat")
  Assert.equal(Defaults.byKey.combatEnabled.modeToggle, true)
  Assert.equal(Defaults.byKey.mountedEnabled.mode, "mounted")
  Assert.equal(Defaults.byKey.mountedEnabled.modeToggle, true)
  Assert.equal(Defaults.byKey.druidForms.modeToggle, nil)
end

local function test_reset_restores_changed_db()
  local db = { enabled = false, distanceMounted = 10, pitchMounted = true }

  Defaults.Reset(db)

  for _, row in ipairs(SPEC) do
    Assert.equal(db[row[1]], row[2], row[1])
  end
end

return function()
  test_every_default_and_range_matches_spec()
  test_list_has_no_keys_beyond_spec()
  test_minimap_entries_follow_enabled_in_general()
  test_mode_tab_rows_carry_mode()
  test_only_mode_switches_are_mode_toggles()
  test_tabs_in_order()
  test_every_drawn_entry_has_short_hint()
  test_parents_are_earlier_plain_checkboxes_on_same_tab()
  test_units_per_spec()
  test_reset_restores_changed_db()
end
