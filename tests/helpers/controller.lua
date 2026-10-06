-- Fresh controller per test: clears the camera modules' running timers left
-- by the previous test, rebuilds the fake WoW globals, then installs the
-- controller on them (its hooks wrap the globals present at install time).
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local Offset = require("ShoulderCam.Camera.Offset")
local Zoom = require("ShoulderCam.Camera.Zoom")
local ZoomMemory = require("ShoulderCam.Camera.ZoomMemory")
local Controller = require("ShoulderCam.Camera.Controller")

local ControllerHelper = {}

function ControllerHelper.setup(overrides)
  Zoom.Cancel()
  Offset.Stop()
  ZoomMemory.Cancel()
  local W = Wow.Install()
  FlavorCompat.hasActionCam = true
  local db = {}
  Defaults.Reset(db)
  for key, value in pairs(overrides or {}) do
    db[key] = value
  end
  Controller.onRemembered = nil
  Controller.Install(db)
  return W, db
end

-- The controller's event frame: the only stub frame with an OnEvent script.
function ControllerHelper.frame(W)
  for _, frame in ipairs(W.frames) do
    if frame.scripts.OnEvent then
      return frame
    end
  end
end

function ControllerHelper.count(W, name)
  return W.calls[name] or 0
end

function ControllerHelper.zoomStarts(W)
  return ControllerHelper.count(W, "MoveViewOutStart") + ControllerHelper.count(W, "MoveViewInStart")
end

-- Forgets CVar writes and camera calls made so far.
function ControllerHelper.clearLogs(W)
  W.setCVarCalls = {}
  W.log = {}
  W.calls = {}
end

return ControllerHelper
