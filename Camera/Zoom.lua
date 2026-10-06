local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("ShoulderCam.Core.Constants")

local abs = math.abs
local ipairs = ipairs

local ZOOM_PRECISION = Constants.ZOOM_PRECISION
local ZOOM_MIN_CORRECTION = Constants.ZOOM_MIN_CORRECTION
local MANUAL_ZOOM_CALLS = { "CameraZoomIn", "CameraZoomOut", "MoveViewInStart", "MoveViewOutStart" }

-- Zoom transition on the game's own camera movement plus one stop timer
-- (SPEC.md → Zoom). `own` is true while ShoulderCam itself calls a hooked
-- camera function, so the hooks can tell its calls from the player's.
local Zoom = { own = false }

local timer
local direction -- "Out" or "In" while a transition runs

local function ownCall(fn, ...)
  Zoom.own = true
  fn(...)
  Zoom.own = false
end

local function stopOwnDirection()
  ownCall(_G["MoveView" .. direction .. "Stop"])
end

local function clear()
  timer:Cancel()
  timer = nil
  direction = nil
end

function Zoom.IsRunning()
  return timer ~= nil
end

function Zoom.Cancel()
  if not timer then
    return
  end
  stopOwnDirection()
  clear()
end

local function finish(target)
  timer = nil
  direction = nil
  ownCall(_G.MoveViewOutStop)
  ownCall(_G.MoveViewInStop)
  local remaining = target - _G.GetCameraZoom()
  if remaining >= ZOOM_MIN_CORRECTION then
    ownCall(_G.CameraZoomOut, remaining)
  elseif -remaining >= ZOOM_MIN_CORRECTION then
    ownCall(_G.CameraZoomIn, -remaining)
  end
end

function Zoom.To(target, transitionSpeed, scrollSpeed)
  Zoom.Cancel()
  local difference = target - _G.GetCameraZoom()
  if abs(difference) < ZOOM_PRECISION then
    return nil
  end
  direction = difference > 0 and "Out" or "In"
  ownCall(_G["MoveView" .. direction .. "Start"], transitionSpeed / scrollSpeed)
  local duration = abs(difference) / transitionSpeed
  timer = _G.C_Timer.NewTimer(duration, function()
    finish(target)
  end)
  return duration
end

-- A held key in the transition's own direction keeps moving, so only a
-- different call stops ShoulderCam's movement.
local function onManualZoom(name, callback)
  if Zoom.own then
    return
  end
  if timer then
    if name ~= "MoveView" .. direction .. "Start" then
      stopOwnDirection()
    end
    clear()
  end
  callback()
end

function Zoom.Install(callback)
  for _, name in ipairs(MANUAL_ZOOM_CALLS) do
    _G.hooksecurefunc(name, function()
      onManualZoom(name, callback)
    end)
  end
end

ns.Zoom = Zoom
return Zoom
