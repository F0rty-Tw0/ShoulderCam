local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = {
  VERSION = "v0.1.0",

  -- Zoom: a smaller difference to the target does nothing; after the
  -- transition timer, a remainder of at least this much is corrected.
  ZOOM_PRECISION = 0.1,
  ZOOM_MIN_CORRECTION = 0.04,

  -- Remember zoom: seconds between stable-read polls, seconds before giving
  -- up, and the yards a stored distance rounds to.
  REMEMBER_POLL = 0.25,
  REMEMBER_BUDGET = 3,
  REMEMBER_ROUND = 0.5,

  -- Camera distance range in yards; cameraDistanceMaxZoomFactor = max distance / 15.
  DISTANCE_MIN = 1,
  DISTANCE_MAX = 39,
  ZOOM_FACTOR_YARDS = 15,

  -- Shoulder offset animation runs at 30 Hz.
  OFFSET_TICK = 1 / 30,

  -- GetShapeshiftFormID values that count as mounted when
  -- "Druid travel forms count as mounted" is on.
  DRUID_MOUNT_FORMS = { [3] = true, [4] = true, [27] = true, [29] = true, [48] = true },
}

ns.Constants = Constants
return Constants
