local addonName, ns = ...
if type(ns) ~= "table" then
  ns = {}
end

local Constants = ns.Constants or require("ShoulderCam.Core.Constants")
local Defaults = ns.Defaults or require("ShoulderCam.Settings.Defaults")
local FlavorCompat = ns.FlavorCompat or require("ShoulderCam.Core.FlavorCompat")
local Localization = ns.Localization or require("ShoulderCam.Core.Localization")
local Widgets = ns.Widgets or require("ShoulderCam.Settings.Widgets")

local CATEGORY_NAME = Localization.Text(Constants.DISPLAY_NAME)
local DEFAULTS_KEY = "*defaults"
local LEFT = 16
local TOP = -16
local TITLE_HEIGHT = 36
local TAB_WIDTH = 100
local TAB_HEIGHT = 24
local TAB_GAP = 4
local TAB_TOP = TOP - TITLE_HEIGHT
local INTRO_TOP = TAB_TOP - TAB_HEIGHT - 12
local CONTENT_TOP = INTRO_TOP - 24
local HEADER_HEIGHT = 26
local HEADER_OFFSET_Y = -8
local CHECKBOX_HEIGHT = 26
local SLIDER_ROW_HEIGHT = 46
local COLUMN_WIDTH = 310
local INDENT = 20

-- One canvas page under Options → AddOns (SPEC.md → Settings): a row of
-- tab buttons under the title, one child frame per tab, one tab shown at a
-- time. Until first show only the empty canvas exists; each tab builds its
-- widgets the first time it is selected. Showing the page again keeps the
-- last selected tab. The native Defaults button calls OnDefault.
local Panel = {}

local category
local db, onChanged
local tabs -- { name, intro, entries, frame, button, built } per tab, made on first show
local widgets = {}

-- Mode -> db key of that mode's own switch (combatEnabled, mountedEnabled),
-- and every key whose change can grey or un-grey another row.
local modeToggles, greyingKeys = {}, {}
for _, entry in ipairs(Defaults.list) do
  if entry.modeToggle then
    modeToggles[entry.mode] = entry.key
    greyingKeys[entry.key] = true
  end
  if entry.parent then
    greyingKeys[entry.parent] = true
  end
end

local function addText(frame, font, text, x, y)
  local label = frame:CreateFontString(nil, "ARTWORK", font)
  label:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
  label:SetJustifyH("LEFT")
  label:SetText(text)
  return label
end

-- A row is active while its mode switch (if any) and its parent (if any) are on.
local function isActive(entry)
  local switch = not entry.modeToggle and modeToggles[entry.mode]
  if switch and not db[switch] then
    return false
  end
  return not entry.parent or db[entry.parent] == true
end

local function updateActive()
  for _, widget in ipairs(widgets) do
    widget:SetActive(isActive(Defaults.byKey[widget.key]))
  end
end

local function changed(key)
  if greyingKeys[key] then
    updateActive()
  end
  onChanged(key)
end

-- Looked up on the module at build time, never cached: tests wrap them.
local function addWidget(frame, entry, x, y)
  local create = entry.min and Widgets.Slider or Widgets.Checkbox
  local left = entry.parent and x + INDENT or x
  widgets[#widgets + 1] = create(frame, entry, left, y, db, changed)
  return entry.min and SLIDER_ROW_HEIGHT or CHECKBOX_HEIGHT
end

local function buildTab(tab)
  local frame = tab.frame
  addText(frame, "GameFontHighlightSmall", Localization.Text(tab.intro), LEFT, INTRO_TOP)
  local x, y = LEFT, CONTENT_TOP
  for _, entry in ipairs(tab.entries) do
    if entry.column then
      x, y = LEFT + COLUMN_WIDTH, CONTENT_TOP
    elseif entry.header then
      addText(frame, "GameFontNormal", Localization.Text(entry.header), x, y + HEADER_OFFSET_Y)
      y = y - HEADER_HEIGHT
    elseif entry.key and entry.label then
      y = y - addWidget(frame, entry, x, y)
    end
  end
  tab.built = true
  -- Selecting a tab fires no canvas OnShow, so the build greys its own rows.
  updateActive()
end

local function setHighlight(button, locked)
  if locked and button.LockHighlight then
    button:LockHighlight()
  elseif not locked and button.UnlockHighlight then
    button:UnlockHighlight()
  end
end

local function selectTab(index)
  local tab = tabs[index]
  if not tab.built then
    buildTab(tab)
  end
  for i, other in ipairs(tabs) do
    other.frame:SetShown(i == index)
    setHighlight(other.button, i == index)
  end
end

-- Each `tab` marker starts a record holding the entries up to the next one.
local function splitTabs()
  local list = {}
  for _, entry in ipairs(Defaults.list) do
    if entry.tab then
      list[#list + 1] = { name = entry.tab, intro = entry.intro, entries = {}, built = false }
    else
      local entries = list[#list].entries
      entries[#entries + 1] = entry
    end
  end
  return list
end

local function addTabButton(canvas, tab, index)
  local button = _G.CreateFrame("Button", nil, canvas, "UIPanelButtonTemplate")
  button:SetSize(TAB_WIDTH, TAB_HEIGHT)
  button:SetPoint("TOPLEFT", canvas, "TOPLEFT", LEFT + (index - 1) * (TAB_WIDTH + TAB_GAP), TAB_TOP)
  button:SetText(Localization.Text(tab.name))
  button:SetScript("OnClick", function()
    selectTab(index)
  end)
  return button
end

local function buildTabs(canvas)
  addText(canvas, "GameFontNormalLarge", CATEGORY_NAME, LEFT, TOP)
  tabs = splitTabs()
  for index, tab in ipairs(tabs) do
    tab.button = addTabButton(canvas, tab, index)
    tab.frame = _G.CreateFrame("Frame", nil, canvas)
    tab.frame:SetAllPoints(canvas)
    tab.frame:Hide()
  end
  selectTab(1)
end

local function buildUnavailable(frame)
  addText(frame, "GameFontNormalLarge", CATEGORY_NAME, LEFT, TOP)
  addText(frame, "GameFontHighlight", Localization.Text("Action camera is not available in this game version."), LEFT, TOP - TITLE_HEIGHT)
end

-- Re-reads every built widget silently, then re-applies greying.
function Panel.Refresh()
  for _, widget in ipairs(widgets) do
    widget:Refresh(db)
  end
  updateActive()
end

-- The client's "All Settings" reset may call this more than once, so only
-- a reset that changed something reports, and only once.
local function restoreDefaults()
  local differs = false
  for key, entry in pairs(Defaults.byKey) do
    differs = differs or db[key] ~= entry.default
  end
  Defaults.Reset(db)
  Panel.Refresh()
  if differs then
    onChanged(DEFAULTS_KEY)
  end
end

local function newPage(build)
  local frame = _G.CreateFrame("Frame")
  -- New frames start shown. The settings window shows a page by reparenting
  -- it and calling Show(); on an already-shown page OnShow never fires when
  -- the window was showing another addon's page, so the page stayed empty.
  frame:Hide()
  local built = false
  frame:SetScript("OnShow", function(self)
    if not built then
      built = true
      build(self)
    end
    Panel.Refresh()
  end)
  frame.OnCommit = function() end
  frame.OnRefresh = Panel.Refresh
  frame.OnDefault = restoreDefaults
  return frame
end

function Panel.Register(settingsDb, onSettingChanged)
  if not FlavorCompat.hasSettingsApi then
    return nil
  end
  db, onChanged = settingsDb, onSettingChanged
  local settings = _G.Settings
  local build = FlavorCompat.hasActionCam and buildTabs or buildUnavailable
  category = settings.RegisterCanvasLayoutCategory(newPage(build), CATEGORY_NAME)
  settings.RegisterAddOnCategory(category)
  return category
end

function Panel.Open()
  if category then
    _G.Settings.OpenToCategory(category:GetID())
  end
end

ns.Panel = Panel
return Panel
