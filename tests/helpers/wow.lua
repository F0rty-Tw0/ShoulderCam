-- Minimal fake WoW API for the camera addon. Wow.Install() rebuilds every
-- global from scratch and returns the state table `W`; tests drive CVars,
-- camera zoom, player state, time, timers and events through it.

local Wow = {}

-- CVars a client with the action camera has, with their stock values.
-- Install() copies this table into W.cvars; tests remove a key from W.cvars
-- to simulate a client without that CVar.
Wow.CVAR_SEEDS = {
  test_cameraOverShoulder = "0",
  test_cameraDynamicPitch = "0",
  test_cameraTargetFocusEnemyEnable = "0",
  test_cameraTargetFocusInteractEnable = "0",
  test_cameraTargetFocusEnemyStrengthYaw = "0.5",
  test_cameraTargetFocusEnemyStrengthPitch = "0.4",
  test_cameraTargetFocusInteractStrengthYaw = "1",
  test_cameraTargetFocusInteractStrengthPitch = "0.75",
  test_cameraDynamicPitchBaseFovPad = "0.4",
  test_cameraDynamicPitchBaseFovPadDownScale = "0.25",
  test_cameraDynamicPitchBaseFovPadFlying = "0.75",
  CameraKeepCharacterCentered = "1",
  CameraReduceUnexpectedMovement = "1",
  cameraDistanceMaxZoomFactor = "1.9",
  cameraZoomSpeed = "20",
}

local CLASS_IDS = {
  WARRIOR = 1,
  PALADIN = 2,
  HUNTER = 3,
  ROGUE = 4,
  PRIEST = 5,
  DEATHKNIGHT = 6,
  SHAMAN = 7,
  MAGE = 8,
  WARLOCK = 9,
  MONK = 10,
  DRUID = 11,
  DEMONHUNTER = 12,
  EVOKER = 13,
}

local function copy(source)
  local result = {}
  for key, value in pairs(source) do
    result[key] = value
  end
  return result
end

local function addSliderMethods(widget)
  function widget:Init(value, minValue, maxValue, steps, formatters)
    self.value, self.min, self.max, self.steps, self.formatters = value, minValue, maxValue, steps, formatters
  end
  function widget:GetValue()
    return self.value
  end
  function widget:RegisterCallback(event, fn, owner)
    table.insert(self.callbacks, { event = event, fn = fn, owner = owner })
  end
  function widget:SetValue(value)
    self.value = value
    for _, callback in ipairs(self.callbacks) do
      if callback.event == _G.MinimalSliderWithSteppersMixin.Event.OnValueChanged then
        callback.fn(callback.owner, value)
      end
    end
  end
end

local function addFrameMethods(widget)
  function widget:SetSize(width, height)
    self.width, self.height = width, height
  end
  function widget:SetPoint(...)
    self.point = { ... }
  end
  function widget:SetScript(script, fn)
    self.scripts[script] = fn
  end
  function widget:GetScript(script)
    return self.scripts[script]
  end
  function widget:RegisterEvent(event)
    self.events[event] = true
  end
  function widget:UnregisterEvent(event)
    self.events[event] = nil
  end
  function widget:IsEventRegistered(event)
    return self.events[event] == true
  end
  function widget:ClearAllPoints()
    self.point = nil
  end
  function widget:Show()
    self.shown = true
  end
  -- Like the client, hiding a shown frame runs its OnHide script.
  function widget:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown and self.scripts.OnHide then
      self.scripts.OnHide(self)
    end
  end
  function widget:IsShown()
    return self.shown
  end
end

-- Font string text, enabled state and CheckButton behavior.
local function addControlMethods(widget)
  function widget:SetText(text)
    self.text = text
  end
  function widget:GetText()
    return self.text
  end
  function widget:SetFontObject(font)
    self.fontObject = font
  end
  function widget:SetJustifyH(justify)
    self.justifyH = justify
  end
  function widget:SetWidth(width)
    self.width = width
  end
  function widget:SetHitRectInsets(...)
    self.hitRectInsets = { ... }
  end
  function widget:SetEnabled(enabled)
    self.enabled = enabled and true or false
  end
  function widget:IsEnabled()
    return self.enabled
  end
  function widget:SetChecked(checked)
    self.checked = checked and true or false
  end
  function widget:GetChecked()
    return self.checked == true
  end
  -- Like the client, clicking a CheckButton flips it before OnClick runs.
  function widget:Click()
    if self.frameType == "CheckButton" then
      self.checked = not self.checked
    end
    if self.scripts.OnClick then
      self.scripts.OnClick(self, "LeftButton")
    end
  end
end

-- Strata, level, click/drag registration and textures.
local function addButtonMethods(widget)
  function widget:SetFrameStrata(strata)
    self.strata = strata
  end
  function widget:SetFrameLevel(level)
    self.level = level
  end
  function widget:RegisterForClicks(...)
    self.clicks = { ... }
  end
  function widget:RegisterForDrag(...)
    self.drags = { ... }
  end
  function widget:SetTexture(path)
    self.texture = path
  end
  function widget:SetHighlightTexture(path)
    self.highlightTexture = path
  end
end

-- Every stub frame carries every method; tests only call the ones that fit.
local function newWidget(W, frameType, name, parent)
  local widget = { frameType = frameType, name = name, parent = parent, scripts = {}, events = {}, callbacks = {}, shown = true, enabled = true }
  addFrameMethods(widget)
  addControlMethods(widget)
  addSliderMethods(widget)
  addButtonMethods(widget)
  function widget:CreateFontString(_name, _layer, font)
    local fontString = newWidget(W, "FontString", nil, self)
    fontString.fontObject = font
    return fontString
  end
  function widget:CreateTexture(_name, layer)
    local texture = newWidget(W, "Texture", nil, self)
    texture.layer = layer
    return texture
  end
  if name then
    rawset(_G, name, widget)
  end
  table.insert(W.frames, widget)
  return widget
end

-- Timers and tickers share one record that is also the handle passed to
-- callbacks; `interval` is set only for tickers.
local function installTimers(W)
  local seq = 0
  local function schedule(delay, fn, interval)
    seq = seq + 1
    local timer = { at = W.now + delay, fn = fn, interval = interval, seq = seq }
    function timer:Cancel()
      self.cancelled = true
    end
    function timer:IsCancelled()
      return self.cancelled == true
    end
    table.insert(W.timers, timer)
    return timer
  end

  local function isActive(timer)
    return not timer.cancelled and not timer.fired
  end

  local function nextDue(deadline)
    local best
    for _, timer in ipairs(W.timers) do
      if isActive(timer) and timer.at <= deadline and (not best or timer.at < best.at or (timer.at == best.at and timer.seq < best.seq)) then
        best = timer
      end
    end
    return best
  end

  function W.Advance(seconds)
    local deadline = W.now + seconds
    local timer = nextDue(deadline)
    while timer do
      W.now = timer.at
      if timer.interval then
        timer.at = timer.at + timer.interval
      else
        timer.fired = true
      end
      timer.fn(timer)
      timer = nextDue(deadline)
    end
    W.now = deadline
  end

  function W.ActiveTimers()
    local count = 0
    for _, timer in ipairs(W.timers) do
      if isActive(timer) then
        count = count + 1
      end
    end
    return count
  end

  rawset(_G, "C_Timer", {
    After = function(delay, fn)
      return schedule(delay, fn)
    end,
    NewTimer = function(delay, fn)
      return schedule(delay, fn)
    end,
    NewTicker = function(interval, fn)
      return schedule(interval, fn, interval)
    end,
  })
end

local function installSettings(W)
  local function newCategory(frame, name, parent)
    local id = #W.categories + 1
    local category = { frame = frame, name = name, parent = parent }
    function category:GetID()
      return id
    end
    table.insert(W.categories, category)
    return category
  end

  rawset(_G, "Settings", {
    RegisterCanvasLayoutCategory = function(frame, name)
      return newCategory(frame, name)
    end,
    RegisterCanvasLayoutSubcategory = function(parent, frame, name)
      return newCategory(frame, name, parent)
    end,
    RegisterAddOnCategory = function(category)
      table.insert(W.addOnCategories, category)
    end,
    OpenToCategory = function(id)
      W.openedCategory = id
    end,
  })
  rawset(_G, "MinimalSliderWithSteppersMixin", { Event = { OnValueChanged = "OnValueChanged" }, Label = { Right = 3 } })
  rawset(_G, "CreateMinimalSliderFormatter", function(_label, fn)
    return fn
  end)
end

local function installFrames(W)
  rawset(_G, "CreateFrame", function(frameType, name, parent, template)
    local widget = newWidget(W, frameType, name, parent)
    widget.template = template
    return widget
  end)

  local uiParent = newWidget(W, "Frame")
  rawset(_G, "UIParent", uiParent)
  local unregister = uiParent.UnregisterEvent
  function uiParent:UnregisterEvent(event)
    table.insert(W.unregistered, event)
    unregister(self, event)
  end

  local tooltip = newWidget(W, "GameTooltip")
  rawset(_G, "GameTooltip", tooltip)
  tooltip.shown = false
  function tooltip:SetOwner(owner, anchor)
    self.owner, self.anchor = owner, anchor
    self.lines = {}
  end
  function tooltip:AddLine(text)
    table.insert(self.lines, text)
  end

  -- Calls OnEvent on every frame registered for the event, like the client.
  function W.Fire(event, ...)
    for _, frame in ipairs(copy(W.frames)) do
      if frame.events[event] and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, event, ...)
      end
    end
  end
end

-- The minimap and the cursor, in screen pixels; tests move W.cursorX/Y.
local function installMinimap(W)
  local minimap = newWidget(W, "Frame", "Minimap")
  minimap.width, minimap.centerX, minimap.centerY, minimap.scale = 140, 500, 400, 1
  function minimap:GetWidth()
    return self.width
  end
  function minimap:GetCenter()
    return self.centerX, self.centerY
  end
  function minimap:GetEffectiveScale()
    return self.scale
  end
  W.minimap = minimap
  W.cursorX, W.cursorY = 0, 0
  rawset(_G, "GetCursorPosition", function()
    return W.cursorX, W.cursorY
  end)
  -- Named frames are rawset into _G: drop the last test's button.
  rawset(_G, "ShoulderCamMinimapButton", nil)
end

local function installPlayer(W)
  rawset(_G, "IsMounted", function()
    return W.mounted == true
  end)
  rawset(_G, "UnitAffectingCombat", function(unit)
    return unit == "player" and W.inCombat == true
  end)
  rawset(_G, "GetShapeshiftFormID", function()
    return W.formId
  end)
  rawset(_G, "UnitClass", function(_unit)
    return W.class, W.class, CLASS_IDS[W.class]
  end)
  rawset(_G, "GetTime", function()
    return W.now
  end)
end

local function installCamera(W)
  rawset(_G, "GetCVar", function(name)
    return W.cvars[name]
  end)
  rawset(_G, "SetCVar", function(name, value)
    W.cvars[name] = tostring(value)
    table.insert(W.setCVarCalls, { name, value })
  end)
  rawset(_G, "GetCameraZoom", function()
    return W.zoom
  end)
  -- Literal names so LuaLS sees each global; none of these move W.zoom.
  local function logged(name)
    return function(...)
      W.calls[name] = (W.calls[name] or 0) + 1
      table.insert(W.log, { name = name, args = { ... } })
    end
  end
  rawset(_G, "CameraZoomIn", logged("CameraZoomIn"))
  rawset(_G, "CameraZoomOut", logged("CameraZoomOut"))
  rawset(_G, "MoveViewInStart", logged("MoveViewInStart"))
  rawset(_G, "MoveViewOutStart", logged("MoveViewOutStart"))
  rawset(_G, "MoveViewInStop", logged("MoveViewInStop"))
  rawset(_G, "MoveViewOutStop", logged("MoveViewOutStop"))
  rawset(_G, "hooksecurefunc", function(target, name, hook)
    if type(target) == "string" then
      target, name, hook = _G, target, name
    end
    local original = target[name]
    target[name] = function(...)
      local results = { original(...) }
      hook(...)
      ---@diagnostic disable-next-line: deprecated
      return (table.unpack or unpack)(results)
    end
  end)
end

function Wow.Install()
  local W = {
    cvars = copy(Wow.CVAR_SEEDS),
    setCVarCalls = {},
    zoom = 15,
    calls = {},
    log = {},
    class = "WARRIOR",
    now = 0,
    timers = {},
    frames = {},
    categories = {},
    addOnCategories = {},
    unregistered = {},
  }

  rawset(_G, "WOW_PROJECT_ID", 1)
  rawset(_G, "WOW_PROJECT_MAINLINE", 1)
  rawset(_G, "SlashCmdList", {})
  installTimers(W)
  installSettings(W)
  installFrames(W)
  installMinimap(W)
  installPlayer(W)
  installCamera(W)
  return W
end

return Wow
