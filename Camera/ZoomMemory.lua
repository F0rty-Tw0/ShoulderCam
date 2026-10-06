local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("ShoulderCam.Core.Constants")

local floor = math.floor
local max = math.max
local min = math.min

local REMEMBER_POLL = Constants.REMEMBER_POLL
local REMEMBER_ROUND = Constants.REMEMBER_ROUND
local DISTANCE_MIN = Constants.DISTANCE_MIN
local DISTANCE_MAX = Constants.DISTANCE_MAX
local BUDGET_POLLS = Constants.REMEMBER_BUDGET / REMEMBER_POLL

-- Remember zoom (SPEC.md → Zoom): after a manual zoom, poll the camera until
-- two reads match, then hand the rounded distance to `onSave`. The first
-- Start binds the save target until the save, the budget running out, or
-- Cancel. `onSave(modeKey, distance)` is set by the Controller.
local ZoomMemory = { onSave = nil }

local timer
local target
local previous
local pollsLeft

local function clear()
  if timer then
    timer:Cancel()
  end
  timer = nil
  target = nil
  previous = nil
end

local function remembered(zoom)
  local rounded = floor(zoom / REMEMBER_ROUND + 0.5) * REMEMBER_ROUND
  return min(max(rounded, DISTANCE_MIN), DISTANCE_MAX)
end

local function poll()
  timer = nil
  pollsLeft = pollsLeft - 1
  local zoom = _G.GetCameraZoom()
  if zoom == previous then
    local modeKey = target
    clear()
    if ZoomMemory.onSave then
      ZoomMemory.onSave(modeKey, remembered(zoom))
    end
    return
  end
  if pollsLeft <= 0 then
    clear()
    return
  end
  previous = zoom
  timer = _G.C_Timer.NewTimer(REMEMBER_POLL, poll)
end

function ZoomMemory.Start(modeKey)
  if target == nil then
    target = modeKey
  end
  previous = nil
  pollsLeft = BUDGET_POLLS
  if not timer then
    timer = _G.C_Timer.NewTimer(REMEMBER_POLL, poll)
  end
end

ZoomMemory.Cancel = clear

ns.ZoomMemory = ZoomMemory
return ZoomMemory
