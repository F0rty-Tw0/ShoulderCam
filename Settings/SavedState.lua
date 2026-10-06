local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Defaults = ns.Defaults or require("ShoulderCam.Settings.Defaults")

local max, min = math.max, math.min

local SavedState = {}

-- The saved file is user-editable: keep a value only when its type matches
-- the default and is a finite number, clamp sliders into range, and fall back
-- to the default otherwise.
local function sanitize(entry, value)
  if type(value) ~= type(entry.default) then
    return entry.default
  end
  -- NaN - NaN and inf - inf are both NaN, never 0.
  if type(value) == "number" and value - value ~= 0 then
    return entry.default
  end
  if entry.min == nil then
    return value
  end
  return min(max(value, entry.min), entry.max)
end

-- Returns the account-wide settings table. Keys no longer known are dropped
-- so the file never grows.
function SavedState.Initialize(saved)
  saved = type(saved) == "table" and saved or {}
  local db = {}
  for _, entry in ipairs(Defaults.list) do
    if entry.key then
      db[entry.key] = sanitize(entry, saved[entry.key])
    end
  end
  return db
end

ns.SavedState = SavedState
return SavedState
