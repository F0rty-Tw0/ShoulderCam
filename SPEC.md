# ShoulderCam — Feature Spec

Lightweight take on ActionCamPlus: Blizzard's built-in action camera (`test_camera*` CVars) with
separate On foot / Combat / Mounted modes, all configurable from the default WoW options.
Selling point: **ActionCamPlus behavior at a fraction of the CPU, memory and size.**

Defaults reproduce the ActionCamPlus profile of the retail account that plays Fortytwo
(`_retail_/WTF/Account/DDEBOBOS/SavedVariables/ActionCamPlus.lua`), plus that account's
`cameraDistanceMaxZoomFactor` of 2.6 (`config-cache.wtf`).

## Scope

- Flavors: Retail, all Classic flavors and WoW: Forever. One TOC (`ShoulderCam.toc`) with
  `## Interface-*` lines, same layout as `MouseOverTooltip.toc`.
- Repo format, tooling, conventions, tests and release pipeline copy MouseOverTooltip
  (`_retail_/Interface/AddOns/MouseOverTooltip`, see its `AGENTS.md`). Repo lives at
  `_retail_/Interface/AddOns/ShoulderCam` (so Retail loads it directly); `_classic_beta_`, `_anniversary_`
  and `_classic_` each get a directory junction `Interface/AddOns/ShoulderCam` → the repo, like
  `MouseOverTooltip`. The user runs the link script (Claude's link creation is blocked by permissions).
- ShoulderCam replaces ActionCamPlus on Retail. No ActionCamPlus detection: the player disables or
  uninstalls ActionCamPlus (running both makes them fight over the same CVars).
- English only. Every player-visible string goes through `Localization.Text("...")`.
- If the client lacks the action camera (`GetCVar("test_cameraDynamicPitch")` returns nil), the addon
  applies nothing and the settings page shows one line: "Action camera is not available in this game version."

## Modes

The active mode is picked in this order every time it is re-evaluated:

1. **Off** — the Enabled setting is off.
2. **Mounted** — Mounted mode is enabled and the player is mounted (`IsMounted()`), or
   "Druid travel forms count as mounted" is on and `GetShapeshiftFormID()` is 3, 4, 27, 29 or 48.
3. **Combat** — Combat mode is enabled and `UnitAffectingCombat("player")` is true.
4. **On foot** — everything else.

Re-evaluated on: login/reload/zone (`PLAYER_ENTERING_WORLD`), any settings change, and only while the
matching mode is enabled: `PLAYER_MOUNT_DISPLAY_CHANGED` and, for druids, `UPDATE_SHAPESHIFT_FORM`
(Mounted); `PLAYER_REGEN_DISABLED` / `PLAYER_REGEN_ENABLED` (Combat). Events of a disabled mode
are unregistered. Registration is recomputed on load and on every change to Enabled, Combat mode
enabled, Mounted mode enabled or "Druid travel forms count as mounted". When Enabled is off, only
`PLAYER_ENTERING_WORLD` stays registered.

A mode-switching event that resolves to the already active mode does nothing (no CVar read or write,
running zoom, offset and remember-zoom timers untouched). `PLAYER_ENTERING_WORLD` and settings changes
always apply in full.

Applying a mode sets, from that mode's settings:

| Mode setting | Effect |
| --- | --- |
| Shoulder offset | `test_cameraOverShoulder` moves to ±offset (minus when "Left shoulder" is on), or to 0 when off |
| Focus enemies | `test_cameraTargetFocusEnemyEnable` 1/0 |
| Focus interact | `test_cameraTargetFocusInteractEnable` 1/0 |
| Dynamic pitch | `test_cameraDynamicPitch` 1/0 |
| Change camera zoom | when on, camera zooms to the mode's distance (see Zoom) |

**Off** sets offset 0 (instantly, no animation) and the three enable CVars to 0, cancels any running zoom
transition (stop movement, cancel timer), offset ticker and pending remember-zoom save. It does not
change zoom distance.

Every CVar write goes through one helper that skips CVars the client doesn't have (`GetCVar(name) == nil`)
and values that are already set.

Whenever the addon is not Off it also sets, on every apply (not on an event skipped as above): `CameraKeepCharacterCentered` 0,
`CameraReduceUnexpectedMovement` 0 (Blizzard blocks the action camera otherwise), the focus and pitch
strength CVars from the global sliders, and `cameraDistanceMaxZoomFactor` = max distance / 15.

The "experimental feature" confirmation popup is suppressed at load:
`UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")` (wrapped in `pcall`), and on Retail
`GameEvent.HandleExperimentalCVarConfirmationNeeded` is replaced with a no-op when it exists — the
same two lines ActionCamPlus uses (`ActionCamPlus.lua:347-348`). The client can fire the event at
login before addons load, so a `EXPERIMENTAL_CVAR_WARNING` popup already shown is closed with
`StaticPopup_Hide` (never its Disable button, which resets the camera CVars).

## Zoom

- **When.** The camera zooms to the active mode's distance only when (a) the active mode changes,
  (b) `PLAYER_ENTERING_WORLD` fires, or (c) one of these settings changes: the active mode's "Change camera
  zoom" or distance, or Max camera distance. Other setting changes (sliders, toggles) never move the zoom.
  Nothing happens when the mode's "Change camera zoom" is off.
- **Target.** Target = the mode's distance clamped to Max camera distance. A difference to
  `GetCameraZoom()` under 0.1 yd does nothing.
- **Transition** (same mechanism current ActionCamPlus uses, `ActionCamPlus.lua:117-133`; never touches
  `cameraZoomSpeed`): call `MoveViewOutStart(transitionSpeed / manualScrollSpeed)` or
  `MoveViewInStart(...)`, start one `C_Timer.NewTimer` for `difference / transitionSpeed` seconds, and when it
  fires call `MoveViewOutStop()` and `MoveViewInStop()`, then correct any remaining difference ≥ 0.04 yd
  with `CameraZoomOut(d)` / `CameraZoomIn(d)`. Only one transition at a time: a new one cancels the
  previous timer and stops movement first.
- **Manual zoom wins.** Calls to `CameraZoomIn`, `CameraZoomOut`, `MoveViewInStart`, `MoveViewOutStart`
  that ShoulderCam did not make (a module flag is set around its own calls; `hooksecurefunc` post-hooks run
  synchronously inside the call) cancel a running transition: timer cancelled, no correction. ShoulderCam
  also stops its own movement (`MoveViewOutStop` or `MoveViewInStop`, flagged as its own call) unless the
  manual call is the same `MoveView*Start` it used, so a held zoom key in that direction keeps working.
- **Remember zoom.** On a manual zoom (same four hooks), when the active mode's "Remember my zoom" is on,
  the mode active at that moment becomes the save target (later manual zooms keep it). One poll at a time
  on a cancellable `C_Timer.NewTimer(0.25)` chain: each manual zoom starts it, or resets the running one's
  previous read and its 3 s budget. When two consecutive `GetCameraZoom()` reads are equal (camera
  stopped), round to the nearest 0.5, clamp to 1–39 and store it as the target mode's distance. The budget
  running out saves nothing. A mode change cancels the poll. Storing a remembered distance writes the
  setting only: it is not a settings change under "When" (c), never starts a zoom, and refreshes the
  Situations slider if that page is open. Remembering works whether or not that mode's "Change camera zoom" is on (same as
  ActionCamPlus `ActionCamPlus.lua:240-251`).
- **Manual scroll speed** sets `cameraZoomSpeed` at login and whenever it changes.

## Shoulder offset animation

Moving `test_cameraOverShoulder` to a new value animates linearly over "Offset time" seconds, or over the
zoom transition's duration when "Sync offset with zoom" is on and a zoom transition started in the same
apply. The animation runs on a `C_Timer.NewTicker` at 30 Hz that is cancelled when it reaches the target
or when a new target arrives. No `OnUpdate` handlers.

## Settings

Default WoW options: **Options → AddOns → ShoulderCam** (Settings API canvas pages, same approach as
`MouseOverTooltip/Settings/Panel.lua`). Two pages:

- **ShoulderCam** (main category): General, Shoulder offset, Focus, Pitch.
- **Situations** (subcategory): On foot, Combat, Mounted in three columns.

Every setting takes effect immediately (re-apply on change); there is no Okay/Apply step.
The native **Defaults** button on either page resets **every** ShoulderCam setting, refreshes both pages
and re-applies at once. `/shouldercam` and `/shc` open the main page. An AddOn Compartment entry (TOC
fields) opens the main page; the TOC fields cost nothing where the compartment doesn't exist. Anything
"Retail only" is gated on the API existing, never on the flavor (WoW: Forever reports itself as Retail,
`MouseOverTooltip/Core/FlavorCompat.lua:11-17`).
Key bindings (Options → Keybindings → ShoulderCam): "Toggle ShoulderCam" (flips Enabled) and
"Swap shoulder" (flips Left shoulder).

Account-wide SavedVariables: `ShoulderCamDB`. On load each value is kept only if its type matches the
default; slider values are also clamped to their range. Anything else falls back to the default.

### Main page

| Setting | Default | Range / step |
| --- | --- | --- |
| **General** | | |
| Enabled | on | |
| Manual scroll speed | 20 | 1–50 / 1 |
| Transition speed | 40 | 1–50 / 0.5 |
| Max camera distance (yd) | 39 | 15–39 / 0.5 |
| **Shoulder offset** | | |
| Offset amount | 1 | 0.5–5 / 0.5 |
| Left shoulder | off | |
| Offset time (s) | 2 | 0.25–5 / 0.25 |
| Sync offset with zoom | on | |
| **Focus** | | |
| Horizontal focus strength | 1 | 0–1 / 0.05 → `test_cameraTargetFocusEnemyStrengthYaw` + `...InteractStrengthYaw` |
| Vertical focus strength | 0.75 | 0–1 / 0.05 → `test_cameraTargetFocusEnemyStrengthPitch` + `...InteractStrengthPitch` |
| **Pitch** | | |
| Pitch strength | 0.4 | 0–1 / 0.05 → `test_cameraDynamicPitchBaseFovPad` |
| Look-down strength | 0.25 | 0–1 / 0.05 → `test_cameraDynamicPitchBaseFovPadDownScale` |
| Flying pitch strength | 0.75 | 0–1 / 0.05 → `test_cameraDynamicPitchBaseFovPadFlying` |

### Situations page

| Setting | On foot | Combat | Mounted |
| --- | --- | --- | --- |
| Mode enabled | always | off | off |
| Shoulder offset | off | off | off |
| Focus enemies | off | off | off |
| Focus interact | off | off | off |
| Dynamic pitch | on | on | off |
| Change camera zoom | on | on | on |
| Remember my zoom | on | on | on |
| Distance (yd, 1–39 / 0.5) | 39 | 39 | 36.5 |
| Druid travel forms count as mounted | — | — | on |

Settings of a disabled mode stay visible but greyed out.

## Performance rules (non-negotiable)

1. No `OnUpdate` handlers. Timers only while something is moving (zoom transition stop, offset ticker,
   remember-zoom stable-read poll), cancelled when done.
2. No libraries.
3. Mount/form events registered only while Mounted mode is on; combat events only while Combat mode is on.
4. A mode switch writes only CVars whose value changes.
5. Settings pages build their widgets on first open.

## Out of scope (decided)

- ActionCamPlus per-mount zoom memory (on in the Fortytwo profile, but never applied there because Mounted
  mode is off).
- ActionCamPlus's +1.5 yd zoom bonus in druid combat forms (`ActionCamPlus.lua:638-640`).
- Transition style (Linear / Ease In / Ease Out) and "transition time" instead of speed: zoom uses the game's
  own movement, which has no easing curve. Offset animation is linear.
- Switching modes early when a mount or harmful spell cast starts; waiting for player input before leaving
  combat mode. Modes switch on the state events above.
- Importing settings from an installed ActionCamPlus. Profiles, per-character settings, minimap button.

## Tests (unit, plain Lua with stubbed WoW API)

Following MouseOverTooltip's TDD rules, unit tests must cover at least: mode selection (every row of the
Modes order, druid forms), event registration per enabled mode, unchanged-mode event skip, CVar writes per mode including the
skip-unchanged and skip-missing rules, zoom trigger rules (when it zooms / when not), transition start,
stop, correction and cancel-by-manual-zoom, remember-zoom target binding / stable read / rounding /
cancel-on-mode-change, offset ticker start/finish/retarget and sync duration, SavedState type check and
clamping, Defaults reset, slash commands, key binding handlers, TOC load order and TOC icon.

## Verify in game (cannot be unit-tested)

- `test_camera*` CVars, `CameraReduceUnexpectedMovement`, `GetCameraZoom`, `PLAYER_MOUNT_DISPLAY_CHANGED`
  exist on WoW: Forever 1.60.
- Mouse-wheel zoom goes through the global `CameraZoomIn` / `CameraZoomOut` (so the hooks see it).
- `MoveViewOutStart(multiplier)` transitions run at the expected speed and land within 0.5 yd.
- A mouse-wheel zoom during a ShoulderCam transition stops the transition movement.
- 39 yd is reachable with factor 2.6 on Classic flavors.
- `Settings.RegisterCanvasLayoutSubcategory` and the slider widget work on every flavor.
