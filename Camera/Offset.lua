local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("ShoulderCam.Core.Constants")
local CVar = ns.CVar or require("ShoulderCam.Core.CVar")

local tonumber = tonumber

local OFFSET_CVAR = "test_cameraOverShoulder"
local OFFSET_TICK = Constants.OFFSET_TICK

-- Linear shoulder-offset animation on one 30 Hz ticker that lives only while
-- the offset moves (SPEC.md → Shoulder offset animation).
local Offset = {}

local ticker
local movingTo

function Offset.Stop()
  if ticker then
    ticker:Cancel()
    ticker = nil
  end
end

-- Progress comes from GetTime(), so late ticks don't slow the curve; arrival
-- writes `target` itself, never a computed value. The same target again
-- keeps the running animation, so a re-apply doesn't stretch it.
function Offset.MoveTo(target, duration)
  if ticker and target == movingTo and duration > 0 then
    return
  end
  Offset.Stop()
  movingTo = target
  local from = tonumber(_G.GetCVar(OFFSET_CVAR))
  if duration <= 0 or from == nil or from == target then
    CVar.Set(OFFSET_CVAR, target)
    return
  end
  local startedAt = _G.GetTime()
  ticker = _G.C_Timer.NewTicker(OFFSET_TICK, function()
    local progress = (_G.GetTime() - startedAt) / duration
    if progress >= 1 then
      Offset.Stop()
      CVar.Set(OFFSET_CVAR, target)
      return
    end
    CVar.Set(OFFSET_CVAR, from + (target - from) * progress)
  end)
end

ns.Offset = Offset
return Offset
