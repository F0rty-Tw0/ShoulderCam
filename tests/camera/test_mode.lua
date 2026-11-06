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

local function test_indoors_mode_when_enabled_and_indoors()
  local db = newDb({ indoorsEnabled = true })

  Assert.equal(Mode.Resolve(db, { indoors = true }), "indoors")
end

local function test_indoors_beats_combat()
  local db = newDb({ indoorsEnabled = true, combatEnabled = true })

  Assert.equal(Mode.Resolve(db, { indoors = true, combat = true }), "indoors")
end

local function test_mounted_beats_indoors()
  local db = newDb({ indoorsEnabled = true, mountedEnabled = true })

  Assert.equal(Mode.Resolve(db, { indoors = true, mounted = true }), "mounted")
end

local function test_indoors_off_falls_through_to_combat()
  local db = newDb({ indoorsEnabled = false, combatEnabled = true })

  Assert.equal(Mode.Resolve(db, { indoors = true, combat = true }), "combat")
end

local function test_outdoors_with_indoors_on_is_on_foot()
  local db = newDb({ indoorsEnabled = true })

  Assert.equal(Mode.Resolve(db, { indoors = false }), "onFoot")
end

local function test_read_state_reads_indoors()
  local W = Wow.Install()
  W.indoors = true

  Assert.equal(Mode.ReadState().indoors, true)
end

local function test_read_state_without_is_indoors_api()
  Wow.Install()
  _G.IsIndoors = nil

  Assert.equal(Mode.ReadState().indoors, false)
end

local INDOOR_EVENT_LIST = "PLAYER_ENTERING_WORLD,SPELL_UPDATE_USABLE,ZONE_CHANGED,ZONE_CHANGED_INDOORS,ZONE_CHANGED_NEW_AREA"

local function test_indoor_events_when_enabled_and_detectable()
  local db = newDb({ indoorsEnabled = true, pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, false, true)), INDOOR_EVENT_LIST)
end

local function test_no_indoor_events_without_api()
  local db = newDb({ indoorsEnabled = true, pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, false, false)), "PLAYER_ENTERING_WORLD")
end

local function test_no_indoor_events_when_disabled()
  local db = newDb({ enabled = false, indoorsEnabled = true })

  Assert.equal(eventList(Mode.Events(db, false, true)), "PLAYER_ENTERING_WORLD")
end

local function test_no_optional_events_without_any_mode_or_pause()
  Assert.equal(eventList(Mode.Events(newDb({ pauseOnTaxi = false }), true)), "PLAYER_ENTERING_WORLD")
end

local function test_mounted_events_for_non_druid()
  local db = newDb({ mountedEnabled = true, pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, false)), "PLAYER_ENTERING_WORLD,PLAYER_MOUNT_DISPLAY_CHANGED")
end

local function test_mounted_events_for_druid_add_shapeshift()
  local db = newDb({ mountedEnabled = true, pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, true)), "PLAYER_ENTERING_WORLD,PLAYER_MOUNT_DISPLAY_CHANGED,UPDATE_SHAPESHIFT_FORM")
end

local function test_druid_forms_off_skips_shapeshift_event()
  local db = newDb({ mountedEnabled = true, druidForms = false, pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, true)), "PLAYER_ENTERING_WORLD,PLAYER_MOUNT_DISPLAY_CHANGED")
end

local function test_combat_events_add_regen_pair()
  local db = newDb({ combatEnabled = true, pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, false)), "PLAYER_ENTERING_WORLD,PLAYER_REGEN_DISABLED,PLAYER_REGEN_ENABLED")
end

local function test_disabled_keeps_only_entering_world()
  local db = newDb({ enabled = false, combatEnabled = true, mountedEnabled = true })

  Assert.equal(eventList(Mode.Events(db, true)), "PLAYER_ENTERING_WORLD")
end

local function test_taxi_pauses_even_when_mounted()
  local db = newDb({ mountedEnabled = true })

  Assert.equal(Mode.Resolve(db, { taxi = true, mounted = true }), "paused")
end

local function test_vehicle_pauses_over_indoors_and_combat()
  local db = newDb({ indoorsEnabled = true, combatEnabled = true })

  Assert.equal(Mode.Resolve(db, { vehicle = true, indoors = true, combat = true }), "paused")
end

local function test_pause_option_off_ignores_taxi()
  local db = newDb({ pauseOnTaxi = false })

  Assert.equal(Mode.Resolve(db, { taxi = true }), "onFoot")
end

local function test_disabled_is_off_even_on_taxi()
  local db = newDb({ enabled = false })

  Assert.equal(Mode.Resolve(db, { taxi = true }), "off")
end

local function test_read_state_reads_taxi_and_vehicle()
  local W = Wow.Install()
  W.onTaxi, W.inVehicle = true, true

  local state = Mode.ReadState()

  Assert.equal(state.taxi, true)
  Assert.equal(state.vehicle, true)
end

local function test_read_state_without_vehicle_api()
  Wow.Install()
  _G.UnitInVehicle = nil

  Assert.equal(Mode.ReadState().vehicle, false)
end

local PAUSE_EVENT_LIST = "PLAYER_CONTROL_GAINED,PLAYER_CONTROL_LOST,PLAYER_ENTERING_WORLD"
local VEHICLE_EVENT_LIST = "PLAYER_CONTROL_GAINED,PLAYER_CONTROL_LOST,PLAYER_ENTERING_WORLD,UNIT_ENTERED_VEHICLE,UNIT_EXITED_VEHICLE"

local function test_default_events_add_taxi_control_pair()
  Assert.equal(eventList(Mode.Events(newDb(), false, false, false)), PAUSE_EVENT_LIST)
end

local function test_vehicle_events_when_detectable()
  Assert.equal(eventList(Mode.Events(newDb(), false, false, true)), VEHICLE_EVENT_LIST)
end

local function test_no_pause_events_when_option_off()
  local db = newDb({ pauseOnTaxi = false })

  Assert.equal(eventList(Mode.Events(db, false, false, true)), "PLAYER_ENTERING_WORLD")
end

local function test_no_pause_events_when_disabled()
  local db = newDb({ enabled = false })

  Assert.equal(eventList(Mode.Events(db, false, false, true)), "PLAYER_ENTERING_WORLD")
end

local function test_suffix_builds_per_mode_keys()
  Assert.equal("offset" .. Mode.SUFFIX.onFoot, "offsetOnFoot")
  Assert.equal("offset" .. Mode.SUFFIX.combat, "offsetCombat")
  Assert.equal("offset" .. Mode.SUFFIX.mounted, "offsetMounted")
  Assert.equal("offset" .. Mode.SUFFIX.indoors, "offsetIndoors")
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
  test_indoors_mode_when_enabled_and_indoors()
  test_indoors_beats_combat()
  test_mounted_beats_indoors()
  test_indoors_off_falls_through_to_combat()
  test_outdoors_with_indoors_on_is_on_foot()
  test_read_state_reads_indoors()
  test_read_state_without_is_indoors_api()
  test_indoor_events_when_enabled_and_detectable()
  test_no_indoor_events_without_api()
  test_no_indoor_events_when_disabled()
  test_no_optional_events_without_any_mode_or_pause()
  test_mounted_events_for_non_druid()
  test_mounted_events_for_druid_add_shapeshift()
  test_druid_forms_off_skips_shapeshift_event()
  test_combat_events_add_regen_pair()
  test_disabled_keeps_only_entering_world()
  test_taxi_pauses_even_when_mounted()
  test_vehicle_pauses_over_indoors_and_combat()
  test_pause_option_off_ignores_taxi()
  test_disabled_is_off_even_on_taxi()
  test_read_state_reads_taxi_and_vehicle()
  test_read_state_without_vehicle_api()
  test_default_events_add_taxi_control_pair()
  test_vehicle_events_when_detectable()
  test_no_pause_events_when_option_off()
  test_no_pause_events_when_disabled()
  test_suffix_builds_per_mode_keys()
end
