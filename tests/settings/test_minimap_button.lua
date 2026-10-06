local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")

local MODULE = "Settings.MinimapButton"
local BUTTON_NAME = "ShoulderCamMinimapButton"
local RADIUS_PAD = 5
local DRAG_TICK = 0.02
-- Lua 5.1 and 5.4 print floats differently: compare as shortest round-trip text.
local NUMBER_FORMAT = "%.14g"

-- Fresh fake client and a freshly loaded module (it keeps the button, db and
-- actions in module state); `db` overrides the shown-at-225 defaults.
local function setup(db)
  local W = Wow.Install()
  package.loaded[MODULE] = nil
  local MinimapButton = require("ShoulderCam.Settings.MinimapButton")
  local settings = { minimapButton = true, minimapAngle = 225 }
  for key, value in pairs(db or {}) do
    settings[key] = value
  end
  local calls = { open = 0, toggle = 0 }
  local actions = {
    open = function()
      calls.open = calls.open + 1
    end,
    toggle = function()
      calls.toggle = calls.toggle + 1
    end,
  }
  return { W = W, MinimapButton = MinimapButton, db = settings, calls = calls, actions = actions }
end

local function installed(db)
  local ctx = setup(db)
  ctx.MinimapButton.Install(ctx.db, ctx.actions)
  return ctx
end

local function button()
  return _G[BUTTON_NAME]
end

local function text(value)
  return string.format(NUMBER_FORMAT, value)
end

-- Puts the cursor at `angle` degrees from the minimap's center, in screen pixels.
local function cursorAt(ctx, angle)
  local minimap = ctx.W.minimap
  local scale = minimap.scale
  ctx.W.cursorX = (minimap.centerX + math.cos(math.rad(angle)) * 50) * scale
  ctx.W.cursorY = (minimap.centerY + math.sin(math.rad(angle)) * 50) * scale
end

local function test_shown_at_install_and_placed_at_saved_angle()
  local ctx = installed({ minimapAngle = 30 })

  local radius = ctx.W.minimap.width / 2 + RADIUS_PAD
  local point = button().point
  Assert.equal(button():IsShown(), true)
  Assert.equal(button().parent, ctx.W.minimap)
  Assert.equal(point[1], "CENTER")
  Assert.equal(point[2], ctx.W.minimap)
  Assert.equal(point[3], "CENTER")
  Assert.equal(text(point[4]), text(math.cos(math.rad(30)) * radius))
  Assert.equal(text(point[5]), text(math.sin(math.rad(30)) * radius))
end

local function test_not_created_when_hidden_at_install()
  local ctx = installed({ minimapButton = false })

  for _, frame in ipairs(ctx.W.frames) do
    Assert.equal(frame.name ~= BUTTON_NAME, true, "button frame created")
  end
end

local function test_refresh_follows_the_setting()
  local ctx = installed()

  ctx.db.minimapButton = false
  ctx.MinimapButton.Refresh()
  Assert.equal(button():IsShown(), false)

  ctx.db.minimapButton = true
  ctx.MinimapButton.Refresh()
  Assert.equal(button():IsShown(), true)
end

local function test_left_click_opens_and_right_click_toggles()
  local ctx = installed()

  button().scripts.OnClick(button(), "LeftButton")
  Assert.equal(ctx.calls.open, 1)
  Assert.equal(ctx.calls.toggle, 0)

  button().scripts.OnClick(button(), "RightButton")
  Assert.equal(ctx.calls.open, 1)
  Assert.equal(ctx.calls.toggle, 1)
end

local function test_drag_saves_cursor_angle_while_held_then_stops_ticking()
  local ctx = installed()
  ctx.W.minimap.scale = 2

  button().scripts.OnDragStart(button())
  Assert.equal(ctx.W.ActiveTimers(), 1, "drag ticker running")
  cursorAt(ctx, 270)
  ctx.W.Advance(DRAG_TICK)
  Assert.equal(text(ctx.db.minimapAngle), text(270), "angle normalized to [0, 360)")

  cursorAt(ctx, 180)
  button().scripts.OnDragStop(button())
  Assert.equal(text(ctx.db.minimapAngle), text(180), "final position saved on release")
  Assert.equal(ctx.W.ActiveTimers(), 0)
end

local function test_hiding_mid_drag_cancels_ticker()
  local ctx = installed()
  button().scripts.OnDragStart(button())

  button():Hide()

  Assert.equal(ctx.W.ActiveTimers(), 0)
end

local function test_no_minimap_installs_nothing()
  local ctx = setup()
  rawset(_G, "Minimap", nil)

  ctx.MinimapButton.Install(ctx.db, ctx.actions)
  ctx.MinimapButton.Refresh()

  Assert.equal(button(), nil)
end

local function test_hover_shows_tooltip_and_leave_hides_it()
  installed()
  local tooltip = _G.GameTooltip

  button().scripts.OnEnter(button())
  Assert.equal(tooltip.owner, button())
  Assert.equal(tooltip.anchor, "ANCHOR_LEFT")
  Assert.equal(tooltip.text, "ShoulderCam")
  Assert.equal(tooltip.lines[1], "Left-click: settings")
  Assert.equal(tooltip.lines[2], "Right-click: toggle on/off")
  Assert.equal(tooltip:IsShown(), true)

  button().scripts.OnLeave(button())
  Assert.equal(tooltip:IsShown(), false)
end

local function test_drag_start_hides_tooltip()
  installed()
  button().scripts.OnEnter(button())

  button().scripts.OnDragStart(button())

  Assert.equal(_G.GameTooltip:IsShown(), false)
  button().scripts.OnDragStop(button())
end

local function test_refresh_before_install_does_not_error()
  local ctx = setup()

  ctx.MinimapButton.Refresh()

  Assert.equal(button(), nil)
end

return function()
  test_shown_at_install_and_placed_at_saved_angle()
  test_not_created_when_hidden_at_install()
  test_refresh_follows_the_setting()
  test_left_click_opens_and_right_click_toggles()
  test_drag_saves_cursor_angle_while_held_then_stops_ticking()
  test_hiding_mid_drag_cancels_ticker()
  test_no_minimap_installs_nothing()
  test_hover_shows_tooltip_and_leave_hides_it()
  test_drag_start_hides_tooltip()
  test_refresh_before_install_does_not_error()
end
