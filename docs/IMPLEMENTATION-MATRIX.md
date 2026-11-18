# DibsUI-Party implementation matrix

Read this and `REQUIREMENTS.md` first when picking DibsUI-Party back up.

- Requirements: `docs/REQUIREMENTS.md`
- Owner: Claude, with the user testing in game
- Updated: 2026-11-15

## Where things are

Paths are relative to the WoW install, `~/Games/Battlenet_Games/World of Warcraft`.

| What | Where |
|---|---|
| Repo (also the installed addon, through a link) | `devResources/DibsUI-Party` ← `_forever_/Interface/AddOns/DibsUI-Party` |
| DibsUI, for code and art to copy | `_forever_/Interface/AddOns/DibsUI`, notes in `devResources/DibsUI/docs` |
| Saved settings | The `DibsUI-Party` table in each profile of `DibsUIOptionsDB` (`_forever_/WTF/Account/<account>/SavedVariables/DibsUI-Options.lua`) |

## Planned files (TOC load order)

| File | Does |
|---|---|
| `Core.lua` | Media paths, layout numbers (DibsUI's, scaled), colors, `CreateArt`, number shortening, hiding Blizzard's party frames |
| `Settings.lua` | Defaults, standalone `DibsUIPartyDB`, or the DibsUI profile's `party` table when DibsUI is there; change callbacks |
| `Text.lua` | Name and health text (a trimmed copy of DibsUI's) |
| `Frame.lua` | One party frame: secure button, orb, portrait/class icon, power ring, health bar, prediction, name, pet bar |
| `Indicators.lua` | Leader, role, raid marker, ready check, range fading |
| `Auras.lua` | Buffs and debuffs on Blizzard's aura containers, test icons, Masque |
| `Group.lua` | The five layouts, player last, reserved aura room, hide in raids, mover, deferring layout to after combat |
| `TestMode.lua` | Sample members for test frames |
| `Widgets.lua` | Settings controls copied from DibsUI's `Config.lua` (toggle rows, dropdown, cards, scroll page) |
| `Config.lua` | The Party Frames page, the standalone window, slash commands, AddOns page, and registering the tab with DibsUI |

Changes to DibsUI (slice S8): a small public table, `DibsUI_API`, with: register a settings tab,
get the current profile's `party` table and be told when the profile changes, read the master
font / heal prediction / last names / opacity settings and be told when they change, and be told
when frames are locked or unlocked.

## Implementation coverage

Status: planned / in progress / built / sim-checked / game-checked.

| Row | REQ IDs | Slice | Depends on | Files | Status | Checks |
|---|---|---|---|---|---|---|
| IMP-01 | 061, 062, 007 | S1: TOC, Core, copied Media, standalone settings | – | TOC, Core, Settings, Media | built, sim-checked | luac; loads in sim with no errors |
| IMP-02 | 002–006, 013, 035, 037 | S2: one frame: orb, portrait/class icon, power ring, health bar, prediction, name, health text, click | IMP-01 | Frame, Text | planned | Sim: test frames look right; ring uses Radial mode. Game: secret values in combat |
| IMP-03 | 001, 014, 034, 036, 038, 022 | S3: group: 5 layouts, player last, hide Blizzard frames, hide in raids, mover, reserved room | IMP-02 | Group, Core | planned | Sim: each layout, no overlap with capped auras. Game: Blizzard frames gone, raid hiding |
| IMP-04 | 012 | S4: pet bars, name on mouseover, buffs move down | IMP-02, IMP-03 | Frame, Group | planned | Sim with test pet. Game: real pet, pet appearing mid-combat |
| IMP-05 | 008–011 | S5: leader, role, marker, ready check, range fading | IMP-02 | Indicators | planned | Sim with faked APIs. Game: range in combat |
| IMP-06 | 020, 021, 023 | S6: buffs and debuffs, test icons, Masque | IMP-03 | Auras | built, sim-checked | Sim: test icons. Game: real auras in combat, dispellable sort, Masque |
| IMP-07 | 031 | S6b: test frames switch | IMP-02–06 | TestMode | planned | Sim |
| IMP-08 | 030–040 | S7: settings window, Party Frames tab, slash, AddOns page | IMP-01 | Widgets, Config | planned | Sim: every option live, survives /reload |
| IMP-09 | 050–054 | S8: DibsUI integration (and the `DibsUI_API` hook in DibsUI) | IMP-08 | Config, Settings; DibsUI Config/Position/Text/Opacity | planned | Sim with both addons: one window, profile switch, font/prediction/surname/opacity follow, one unlock. Sim with DibsUI-Party alone |

## Order of work

1. **Mock-up (for approval):** IMP-01, IMP-02, IMP-03, the test frames, and the settings tab
   with stub switches, enough to show the look and every layout in UIForever. Pets, indicators
   and auras are drawn with test data. The user reviews and settles Q-001 to Q-003.
2. After approval: finish IMP-04 to IMP-08 with real unit data.
3. IMP-09: the DibsUI hook. This changes DibsUI, so it ships as a DibsUI release too.
4. The user tests in game. Then commit and push.

## Validation evidence

| ID | Rows | Mode | Result |
|---|---|---|---|
| V-01 | IMP-01–03, 05, 07, 08 | static | `luac5.1 -p *.lua` passes |
| V-02 | IMP-01–03, 07, 08 | sim (UIForever 1.60.1.70450, 1920x1080, UI 0.71), mock-up build 2026-11-15 | Loads with 0 errors. Test frames: portraits, power ring (test frames use a held Cooldown swipe), class-colored bars, heal (Selwyn) and absorb (Gorvak) prediction, name, value-and-percent text, leader/role/marker/ready icons, out-of-range fade, pet bar with buffs moved below it, buffs 2 rows, 4 debuffs with type borders. Class icons, show player (last), mouseover text, all 5 layouts, unlock handle, settings window all work |
| V-04 | REQ-015, 016, 041, 042 | sim, 2026-11-15 | Taller bar keeps its slants; level shows top right of the orb; width 1.6 and 0.5 laid out with no errors (buffs per row 6 and 2); 0.5 too cramped, so the minimum is now 0.75; a saved 0.5 loads as 0.75 |
| V-05 | IMP-06 (REQ-020, 021, 023) | sim, Dungeon scenario (in combat) and Solo, with Masque from the sim catalog | Containers made at login for party1-4 and player. The sim's party has no buffs from the player and no debuffs, so nothing showed, which is correct. With the filters swapped to HELPFUL from the console: buffs under the bars (under the pet bar for the hunter), debuff row at the bar's tip, capped at 4 with the "dispellable" group first. Masque: two groups, "DibsUI-Party: Buffs" and "Debuffs", skinned with Blizzard Classic; test icons skinned too; stack count shows. 0 errors. Not checkable in sim: real secret auras, HARMFUL|RAID dispellable classification, UnitFrameDebuff order, roster changes refreshing the containers |
| V-06 | IMP-09 (REQ-050–054, DEC-016) | sim, 2026-11-16, DibsUI 0.3.1 + DibsUI-Options 0.2.0 | One window: DibsUI's tabs and Party Frames under headings, then Profiles. /dup opens the Party Frames tab. DibsUI's Last names switch shows "Gorvak Ironhide" live (at width 1.5; at width 1 the last name is left out instead of cutting the first name). DibsUI's heal prediction switch reaches the party (fired through SettingsChanged). Opacity Smart: group alpha 0.3 at rest. New profile gives party defaults (width 1), switching back restores 1.5. DibsUIOptions:SetLocked(false) shows the party mover with DibsUI's. With DibsUI disabled: only Party Frames + Profiles, alpha 1, no last names. 0 errors; only missing API is SetRenderMode |
| V-07 | REQ-001, 011, 039, 053 (2026-11-16 changes) | sim, Dungeon then Raid scenario | Dungeon: IsInGroup true, CompactRaidFrameManager hidden, party frames shown, all members in range at alpha 1.00. `/dui party` opens the Party Frames tab; `/dup` is unknown; `/dui xyz` lists the commands. Raid: party frames hidden, Blizzard raid frames and the manager tab show. 0 errors. Out-of-range 30% not reachable in sim (everyone in range) |
| V-03 | IMP-02 (REQ-003) | sim | **Not checkable in sim**: UIForever lists `StatusBar:SetRenderMode` as a missing API, so the real-unit radial ring can only be checked in game |

## Bronze theme mock-up (2026-11-18)

DibsUI got a Theme setting (Default / Bronze; see DibsUI's matrix). Party's `OrbFrame`, `BarHealthFrame` and
`BarPowerFrame` are byte-identical to DibsUI's, so the Bronze files (`DibsUI/art/themes/Bronze/`) drop straight
in. Mock-up in a scratch copy (Bronze TGAs in Media, rim drawn at `orbQuad * 1.25` in Frame.lua): loads with 0
errors (1 missing API, the known `StatusBar:SetRenderMode`). Test frames look right: bronze rim with the small
crest, the 1.5x-tall health bar's bronze stretches cleanly, fills and slices line up. Screenshot
`DibsUI/art/themes/Bronze/sim-party-mockup.png`. Nothing in the repo changed. Open question for the user: follow
DibsUI's Theme setting (like the master font) or a separate party setting.
**Answered: separate settings, with a popup offering to match the other addon.** Built 2026-11-18,
uncommitted: Party Frames > Theme (Default / Bronze), profile key `theme` (CleanSettings), `ns.Themes` in Core.lua
(same keys as DibsUI's), `ns.CreateArt` swaps themed files live, every member's and test frame's rim is centred
and sized `orbQuad * rimScale` (`ns.AddRim`). Popup and `"ThemeRequested"` listener in Config.lua, mirror of
DibsUI's (see DibsUI's matrix). Bronze files in `Media/Themes/Bronze/`. Sim-checked with DibsUI; in-game test
pending. The earlier uncommitted `Group.lua` change (player frame visibility) is separate and untouched.

## Resume checkpoint

- Updated: 2026-11-16, Claude
- Repo: `devResources/DibsUI-Party`, branch `main`. v0.1.1-beta released 2026-11-16 (CurseForge slug `dibsui-party-frames`, ID 1810230), with DibsUI-Options v0.2.1-beta and DibsUI v0.3.2-beta. Releases go through `devResources/publish-suite.sh`
- DEC-016 (2026-11-15): DibsUI-Options replaced the plan for a `DibsUI_API` hook in DibsUI. DibsUI-Party is a module of it
  (key `DibsUI-Party`, one tab "Party Frames"), with its settings in the shared profiles; its own window,
  Widgets.lua, `DibsUIPartyDB` and AddOns page are gone. `Look.lua` reads DibsUI's profile table (masterFont,
  showSurnames) and refreshes on DibsUI-Options'
  `"SettingsChanged", "DibsUI"` callback (API 2), fired by DibsUI 0.3.1
- 2026-11-16 user changes: only font and last names shared (no opacity or prediction); range fade 100%/30%; `/dui party`
  (module `slash`, DibsUI-Options) replaces `/dup`; `CompactRaidFrameManager` hidden outside raids via hook on
  `CompactRaidFrameManager_UpdateShown` (not protected, Mainline family file loads for Camelot)
- Last names: DibsUI's style (80% size, off-white), but dropped when the pair won't fit, since party bars are narrow
- Uncommitted elsewhere: DibsUI-Options 0.2.0 (callbacks), DibsUI 0.3.1 (fires SettingsChanged). DibsUI-Party needs both
- Next: user tests in game (real party, secret values, radial power ring V-03, real auras V-05); then commit all three. Party
  needs a `.pkgmeta` (required dependency dibsui-options) and CurseForge project before its first release
- Testing: UIForever sim on workspace 4 (user's choice); the user tests in game
- Controller and localization: excluded by the user (REQ-060)
