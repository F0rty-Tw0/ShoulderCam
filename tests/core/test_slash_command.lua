local Assert = require("tests.helpers.assert")
local Wow = require("tests.helpers.wow")
local SlashCommand = require("ShoulderCam.Core.SlashCommand")

local USAGE = "Shoulder Cam: /shc, /shc toggle, /shc swap"

-- Registers counting actions; returns the counters and the printed lines.
local function register()
  Wow.Install()
  local calls = { open = 0, toggle = 0, swap = 0 }
  local actions = {}
  for name in pairs(calls) do
    actions[name] = function()
      calls[name] = calls[name] + 1
    end
  end
  SlashCommand.Register(actions)
  return calls
end

-- Runs the slash handler with `_G.print` captured, then restores it.
local function run(msg)
  local printed = {}
  local original = _G.print
  rawset(_G, "print", function(text)
    printed[#printed + 1] = text
  end)
  local ok, err = pcall(_G.SlashCmdList.SHOULDERCAM, msg)
  rawset(_G, "print", original)
  assert(ok, err)
  return printed
end

local function assertCalls(calls, open, toggle, swap)
  Assert.equal(calls.open, open, "open")
  Assert.equal(calls.toggle, toggle, "toggle")
  Assert.equal(calls.swap, swap, "swap")
end

local function test_both_slashes_open_settings_once()
  local calls = register()
  run("")
  Assert.equal(_G.SLASH_SHOULDERCAM1, "/shouldercam")
  Assert.equal(_G.SLASH_SHOULDERCAM2, "/shc")
  assertCalls(calls, 1, 0, 0)
end

local function test_whitespace_only_opens_settings()
  local calls = register()
  run("   ")
  assertCalls(calls, 1, 0, 0)
end

local function test_toggle_word_calls_toggle()
  local calls = register()
  run("toggle")
  assertCalls(calls, 0, 1, 0)
end

local function test_swap_word_calls_swap()
  local calls = register()
  run("swap")
  assertCalls(calls, 0, 0, 1)
end

local function test_word_is_trimmed_and_case_folded()
  local calls = register()
  run("  TOGGLE  ")
  assertCalls(calls, 0, 1, 0)
end

local function test_unknown_word_prints_usage_only()
  local calls = register()
  local printed = run("foo")
  assertCalls(calls, 0, 0, 0)
  Assert.equal(#printed, 1, "one line")
  Assert.equal(printed[1], USAGE)
end

local function test_extra_words_print_usage()
  local calls = register()
  local printed = run("toggle now")
  assertCalls(calls, 0, 0, 0)
  Assert.equal(#printed, 1, "one line")
  Assert.equal(printed[1], USAGE)
end

return function()
  test_both_slashes_open_settings_once()
  test_whitespace_only_opens_settings()
  test_toggle_word_calls_toggle()
  test_swap_word_calls_swap()
  test_word_is_trimmed_and_case_folded()
  test_unknown_word_prints_usage_only()
  test_extra_words_print_usage()
end
