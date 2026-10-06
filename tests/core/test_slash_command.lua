local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local SlashCommand = require("ShoulderCam.Core.SlashCommand")

local function test_both_slashes_open_settings_once()
  Wow.Install()
  local opened = 0
  SlashCommand.Register(function()
    opened = opened + 1
  end)

  _G.SlashCmdList.SHOULDERCAM("")

  Assert.equal(_G.SLASH_SHOULDERCAM1, "/shouldercam")
  Assert.equal(_G.SLASH_SHOULDERCAM2, "/shc")
  Assert.equal(opened, 1)
end

return function()
  test_both_slashes_open_settings_once()
end
