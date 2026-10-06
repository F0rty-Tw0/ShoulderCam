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

local function test_situation_entries_name_their_column()
  for _, suffix in ipairs({ "OnFoot", "Combat", "Mounted" }) do
    local mode = suffix == "OnFoot" and "onFoot" or string.lower(suffix)
    for _, prefix in ipairs({ "offset", "focusEnemy", "focusInteract", "pitch", "zoom", "remember", "distance" }) do
      Assert.equal(Defaults.byKey[prefix .. suffix].mode, mode, prefix .. suffix)
    end
  end
  Assert.equal(Defaults.byKey.druidForms.mode, "mounted")
end

local function test_only_mode_switches_are_mode_toggles()
  Assert.equal(Defaults.byKey.combatEnabled.mode, "combat")
  Assert.equal(Defaults.byKey.combatEnabled.modeToggle, true)
  Assert.equal(Defaults.byKey.mountedEnabled.mode, "mounted")
  Assert.equal(Defaults.byKey.mountedEnabled.modeToggle, true)
  Assert.equal(Defaults.byKey.druidForms.modeToggle, nil)
end

local function test_pages_split_main_and_situations()
  Assert.equal(Defaults.list[1].page, "main")
  local pageOf, page = {}, nil
  for _, entry in ipairs(Defaults.list) do
    page = entry.page or page
    if entry.key then
      pageOf[entry.key] = page
    end
  end
  Assert.equal(pageOf.pitchFlying, "main")
  Assert.equal(pageOf.combatEnabled, "situations")
  Assert.equal(pageOf.distanceOnFoot, "situations")
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
  test_situation_entries_name_their_column()
  test_only_mode_switches_are_mode_toggles()
  test_pages_split_main_and_situations()
  test_reset_restores_changed_db()
end
