local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local Mode = require("ShoulderCam.Camera.Mode")

local function newDb(overrides)
  local db = {}
  Defaults.Reset(db)
  for key, value in pairs(overrides or {}) do
    db[key] = value
  end
  return db
end

local function eventList(events)
  local names = {}
  for name in pairs(events) do
    names[#names + 1] = name
  end
  table.sort(names)
  return table.concat(names, ",")
end

local function test_disabled_is_off_even_when_mounted()
  local db = newDb({ enabled = false, mountedEnabled = true })

  Assert.equal(Mode.Resolve(db, { mounted = true, combat = true }), "off")
end

local function test_mounted_mode_when_enabled_and_mounted()
  local db = newDb({ mountedEnabled = true })

  Assert.equal(Mode.Resolve(db, { mounted = true, combat = false }), "mounted")
end

local function test_mounted_disabled_falls_through_to_combat()
  local db = newDb({ mountedEnabled = false, combatEnabled = true })

  Assert.equal(Mode.Resolve(db, { mounted = true, combat = true }), "combat")
end

local function test_druid_travel_form_counts_as_mounted()
  local db = newDb({ mountedEnabled = true, druidForms = true })

  Assert.equal(Mode.Resolve(db, { mounted = false, combat = false, formId = 27 }), "mounted")
end

local function test_druid_travel_form_ignored_when_setting_off()
  local db = newDb({ mountedEnabled = true, druidForms = false })

  Assert.equal(Mode.Resolve(db, { mounted = false, combat = false, formId = 27 }), "onFoot")
end

local function test_cat_form_is_on_foot()
  local db = newDb({ mountedEnabled = true, druidForms = true })

  Assert.equal(Mode.Resolve(db, { mounted = false, combat = false, formId = 1 }), "onFoot")
end

local function test_combat_without_combat_mode_is_on_foot()
  local db = newDb({ combatEnabled = false })

  Assert.equal(Mode.Resolve(db, { mounted = false, combat = true }), "onFoot")
end

local function test_read_state_reflects_player()
  local W = Wow.Install()
  W.mounted, W.inCombat, W.formId = true, true, 27

  local state = Mode.ReadState()

  Assert.equal(state.mounted, true)
  Assert.equal(state.combat, true)
  Assert.equal(state.formId, 27)
end

local function test_default_events_only_entering_world()
  Assert.equal(eventList(Mode.Events(newDb(), true)), "PLAYER_ENTERING_WORLD")
end

local function test_mounted_events_for_non_druid()
  local db = newDb({ mountedEnabled = true })

  Assert.equal(eventList(Mode.Events(db, false)), "PLAYER_ENTERING_WORLD,PLAYER_MOUNT_DISPLAY_CHANGED")
end

local function test_mounted_events_for_druid_add_shapeshift()
  local db = newDb({ mountedEnabled = true })

  Assert.equal(eventList(Mode.Events(db, true)), "PLAYER_ENTERING_WORLD,PLAYER_MOUNT_DISPLAY_CHANGED,UPDATE_SHAPESHIFT_FORM")
end

local function test_druid_forms_off_skips_shapeshift_event()
  local db = newDb({ mountedEnabled = true, druidForms = false })

  Assert.equal(eventList(Mode.Events(db, true)), "PLAYER_ENTERING_WORLD,PLAYER_MOUNT_DISPLAY_CHANGED")
end

local function test_combat_events_add_regen_pair()
  local db = newDb({ combatEnabled = true })

  Assert.equal(eventList(Mode.Events(db, false)), "PLAYER_ENTERING_WORLD,PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED")
end

local function test_disabled_keeps_only_entering_world()
  local db = newDb({ enabled = false, combatEnabled = true, mountedEnabled = true })

  Assert.equal(eventList(Mode.Events(db, true)), "PLAYER_ENTERING_WORLD")
end

local function test_suffix_builds_per_mode_keys()
  Assert.equal("offset" .. Mode.SUFFIX.onFoot, "offsetOnFoot")
  Assert.equal("offset" .. Mode.SUFFIX.combat, "offsetCombat")
  Assert.equal("offset" .. Mode.SUFFIX.mounted, "offsetMounted")
end

return function()
  test_disabled_is_off_even_when_mounted()
  test_mounted_mode_when_enabled_and_mounted()
  test_mounted_disabled_falls_through_to_combat()
  test_druid_travel_form_counts_as_mounted()
  test_druid_travel_form_ignored_when_setting_off()
  test_cat_form_is_on_foot()
  test_combat_without_combat_mode_is_on_foot()
  test_read_state_reflects_player()
  test_default_events_only_entering_world()
  test_mounted_events_for_non_druid()
  test_mounted_events_for_druid_add_shapeshift()
  test_druid_forms_off_skips_shapeshift_event()
  test_combat_events_add_regen_pair()
  test_disabled_keeps_only_entering_world()
  test_suffix_builds_per_mode_keys()
end
