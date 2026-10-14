-- Shared setup for the options page tests: a fresh fake client, a freshly
-- loaded Panel registered on a default db, and lookups for its tabs and
-- the widgets each tab built.
local Wow = require("tests.helpers.wow")
local Defaults = require("ShoulderCam.Settings.Defaults")
local FlavorCompat = require("ShoulderCam.Core.FlavorCompat")
local Widgets = require("ShoulderCam.Settings.Widgets")

local PANEL_MODULE = "Settings.Panel"

local P = {}

P.TAB_NAMES = { "General", "Camera feel", "On foot", "Combat", "Mounted" }

-- Every widget the panel builds, recorded as Widgets returns it.
local built = {}
for _, name in ipairs({ "Checkbox", "Slider" }) do
  local create = Widgets[name]
  Widgets[name] = function(parent, ...)
    local widget = create(parent, ...)
    built[#built + 1] = { parent = parent, widget = widget }
    return widget
  end
end
P.built = built

function P.setup(hasActionCam)
  local W = Wow.Install()
  FlavorCompat.hasActionCam = hasActionCam ~= false
  FlavorCompat.hasSettingsApi = true
  package.loaded[PANEL_MODULE] = nil
  local Panel = require("ShoulderCam.Settings.Panel")
  local db = {}
  Defaults.Reset(db)
  local changes = {}
  local category = Panel.Register(db, function(key)
    changes[#changes + 1] = key
  end)
  return { W = W, Panel = Panel, db = db, changes = changes, category = category }
end

function P.canvas(ctx)
  return ctx.W.categories[1].frame
end

-- Opens the page the way the settings window does.
function P.open(ctx)
  P.canvas(ctx):Show()
end

-- Tab buttons share text with nothing else today, but a header could;
-- only a button with an OnClick script counts.
function P.tabButton(ctx, name)
  for _, frame in ipairs(ctx.W.frames) do
    if frame.parent == P.canvas(ctx) and frame.text == name and frame.scripts.OnClick then
      return frame
    end
  end
  return nil
end

function P.clickTab(ctx, name)
  local button = assert(P.tabButton(ctx, name), "no tab button " .. name)
  button.scripts.OnClick(button, "LeftButton")
end

-- The canvas's child Frames, one per tab, in tab order.
function P.tabFrame(ctx, name)
  local index = 0
  for _, frame in ipairs(ctx.W.frames) do
    if frame.parent == P.canvas(ctx) and frame.frameType == "Frame" then
      index = index + 1
      if P.TAB_NAMES[index] == name then
        return frame
      end
    end
  end
  return nil
end

-- key -> wrapper of every setting widget built on `frame`, and the count.
function P.widgetsOn(frame)
  local byKey, count = {}, 0
  for _, record in ipairs(built) do
    if record.parent == frame then
      local key = record.widget.key
      assert(byKey[key] == nil, "duplicate widget for " .. key)
      byKey[key] = record.widget
      count = count + 1
    end
  end
  return byKey, count
end

-- Wrappers on the named tab, building it first.
function P.tab(ctx, name)
  P.clickTab(ctx, name)
  return (P.widgetsOn(P.tabFrame(ctx, name)))
end

return P
