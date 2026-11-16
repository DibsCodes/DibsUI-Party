# DibsUI-Party requirements

- Repository: `devResources/DibsUI-Party` (github.com/DibsCodes/DibsUI-Party), linked into
  `_forever_/Interface/AddOns/DibsUI-Party`
- Updated: 2026-11-15, Claude
- Implementation matrix: `docs/IMPLEMENTATION-MATRIX.md`
- Companion addon: DibsUI. Its notes are `devResources/DibsUI/docs/IMPLEMENTATION-MATRIX.md`. Read
  the rules there on secret values, taint and secure buttons. They apply here too.
- Original request (2026-11-15): "party frames that replace the default UI party frames. We're
  going to copy a lot of things from DibsUI … This will be a standalone addon but if both addons are
  installed should integrate and share settings."
- Goal: party frames in DibsUI's style (orb with portrait, power ring, class-colored health bar)
  that replace Blizzard's party frames, with their own settings, working with or without DibsUI.

## Requirements

User = the user's words or answers on 2026-11-15. Assumption = Claude's default, open to change.

### Frames

| ID | Requirement | Origin | Acceptance |
|---|---|---|---|
| REQ-001 | Replace Blizzard's party frames. Hide `PartyFrame` and, outside raids, the raid-style party frames (`CompactPartyFrame`) and the raid frame manager tab (`CompactRaidFrameManager`, user 2026-11-16) | User: "replace the default UI party frames"; hiding the raid-style ones is an Assumption | With a party, no Blizzard party frames show in either Edit Mode style. Hiding waits for combat to end after a /reload in combat |
| REQ-002 | Each frame has an orb on the left showing the unit's portrait | User | Each member's 3D-style portrait shows round inside the orb, under DibsUI's glass and rim art |
| REQ-003 | The cast ring position shows the unit's power (mana, rage, energy…) in its power color | User | Ring fills clockwise from 12 o'clock to the power fraction, colored like DibsUI's power colors, and keeps working in combat when power is secret |
| REQ-004 | Health bar to the right of the orb, class colored, with heal and absorb prediction like DibsUI | User | Bar color = class color. Incoming heals and absorbs extend past the fill like DibsUI's bars. Dead, ghost and offline members grey out |
| REQ-005 | Name text on top of the frame | User | Name sits above the health bar, capped to its width, and follows the last-name setting when DibsUI is installed |
| REQ-006 | Health text: value and percent by default (like "84% - 12.4k"), with an option to show it only on mouseover | User | Default shows both. With the option on, the text shows only while the frame is hovered |
| REQ-007 | Use the same art as DibsUI | User: "Keep the art assets the same as DibsUI" | Orb, ring, bar and glass textures are DibsUI's files, copied into this addon so it works alone |
| REQ-015 | Health bar 50% taller than DibsUI's | User, 2026-11-15 | Art, outline, fill and caps all stretched to 1.5x height, so the slants still match. The pet bar sits 3 units under it |
| REQ-016 | The unit's level at the top right of the orb | User, 2026-11-15 | Colored by difficulty for the player, like DibsUI's target level; "??" when unknown |
| REQ-008 | Leader and role icons | User (picked) | Leader crown and a tank/healer/damage icon show on the orb's rim when set |
| REQ-009 | Raid target marker | User (picked) | Marker shows over the orb and updates when changed |
| REQ-010 | Ready check | User (picked) | Ready/not ready/waiting icon over the portrait during a ready check, fading out after it ends |
| REQ-011 | Out-of-range fading | User (picked); values user 2026-11-16 | In range 100%, out of range 30%, including in combat. The party's only fading: DibsUI's opacity modes aren't shared |
| REQ-012 | Party pets get a small bar like DibsUI's target power bar, under the owner's health bar. Pet name shows on mouseover. A member with a pet may take more room | User | Pet bar shows with the pet's health. Hovering it shows the name. The owner's buffs move down below it |
| REQ-013 | Clicking a frame targets the unit, right-click opens its menu. Same for the pet bar | Assumption (standard, as in DibsUI) | Works in and out of combat |
| REQ-014 | Hide in raids | User | In a raid the party frames are gone, and they come back on leaving the raid |

### Auras

| ID | Requirement | Origin | Acceptance |
|---|---|---|---|
| REQ-020 | Buffs: small icons under the frame, growing right then down. Only buffs the player cast on the member | User; filter picked by user | At most 2 rows (cap). Icons show time left |
| REQ-021 | Debuffs: to the right of the frame, icons as tall as the health bar (DEC-012), growing right. All debuffs, dispellable ones first, with type-colored borders | User; filter picked by user | At most 4 (cap). Magic, curse, poison and disease borders colored |
| REQ-022 | Room for the capped auras is reserved, so nothing overlaps in any layout | User (picked) | With 4 debuffs and 2 buff rows on every member, no frame covers another in any of the 5 layouts |
| REQ-023 | Masque can skin aura icons when installed | User: Masque is an optional dependency | With Masque, a "DibsUI-Party" group appears and skins buffs and debuffs |

### Settings

| ID | Requirement | Origin | Acceptance |
|---|---|---|---|
| REQ-030 | Settings window in DibsUI's style with one tab on the left, "Party Frames" | User | Same look as DibsUI's window: logo, top bar, vertical tab list |
| REQ-031 | Show test frames | User | Shows sample members with auras, pets and prediction so the layout can be set up alone. Turns off when combat starts. Not saved |
| REQ-032 | Show buffs | User | Default on |
| REQ-033 | Show debuffs | User | Default on |
| REQ-034 | Show player in party, placed last | User | Default off. The player's frame comes after the party members |
| REQ-035 | Class icon portraits: switch between portraits and class icons | User | Default off (portraits) |
| REQ-036 | Layout: vertical grow up, vertical grow down, horizontal grow left, horizontal grow right, horizontal centered | User | Default vertical grow down. Switching keeps the group's anchor point still |
| REQ-037 | Health text on mouseover only (see REQ-006) | User | Default off |
| REQ-038 | Unlock/Lock Frames button in the top bar to drag the group, like DibsUI | User (picked) | Drag handle shows while unlocked. Position saved |
| REQ-039 | Settings open with a slash command | User 2026-11-16 | `/dui party` opens the DibsUI window on the Party Frames tab. No `/dup` or `/dibsparty`. DibsUI-Options' AddOns page lists the addon |
| REQ-041 | Scale slider | User, 2026-11-15 | 0.5 to 2, default 1. The anchor corner stays put while scaling. Locked in combat |
| REQ-042 | Width slider for the health bars | User, 2026-11-15 | 0.75 to 2, default 1 (0.5 left no room for the text). Stretches the straight middle of the health and pet bars like DibsUI's width setting; buffs per row, debuff position and reserved room follow. Locked in combat |
| REQ-040 | Settings apply immediately and survive /reload | Assumption | Every switch toggles live and is kept after /reload |

### Working with DibsUI

| ID | Requirement | Origin | Acceptance |
|---|---|---|---|
| REQ-050 | Works on its own without DibsUI | User | With DibsUI disabled: frames, settings window and saved settings all work |
| REQ-051 | With DibsUI installed: one window. DibsUI's settings window gets a "Party Frames" tab, and `/dibsparty` opens that tab | User (picked option 1) | Only one window opens, with the Party Frames tab in DibsUI's tab list |
| REQ-052 | With DibsUI installed, party settings are saved in DibsUI's profiles and switch with them | User (picked option 1) | Switching DibsUI profile changes the party settings. The first time, the standalone settings are copied into the active profile |
| REQ-053 | With DibsUI installed, party frames follow DibsUI's master font and last names | User (picked option 1); narrowed by user 2026-11-16: heal prediction and opacity aren't shared | Changing those in DibsUI changes the party frames live. Party heal prediction always shows |
| REQ-054 | DibsUI's Unlock Frames button also unlocks the party frames | User (picked) | One button unlocks both |

### Constraints

| ID | Requirement | Origin |
|---|---|---|
| REQ-060 | English only, no controller support (same as DibsUI) | User, 2026-11-15 |
| REQ-061 | Target WoW Forever only, interface 16001 | User: "for wow forever" |
| REQ-062 | DibsUI and Masque are optional dependencies | User |
| REQ-063 | Follow DibsUI's rules: secret values only go into widgets; secure buttons aren't moved or shown/hidden from Lua in combat; Blizzard frames hidden without taint | DibsUI notes |

## Target and API evidence

Target: WoW Forever, interface 16001. Source pinned to Gethe/wow-ui-source `forever`
`bebcb6bf309cf41b41bd74f8ca651e6a105b2676` (1.60.1.70938), checked 2026-11-15. Bundled plugin
data is `eac30af` (1.60.1.70790). None of this has been checked at runtime yet.

| Need | Evidence | Uncertainty |
|---|---|---|
| Power ring with secret values (REQ-003) | `SimpleStatusBarAPI:SetRenderMode` with `Enum.StatusBarRenderMode.Radial` ("driving the managed texture's radial progress fill percent"). Textures also have `SetRadialProgressBarStartOffset/EndOffset/Reverse/Feather` | Never used by DibsUI. Check in the sim, and in game with secret power. Fallback: DibsUI's combo-ring approach, with N segment bars each covering one step |
| Blizzard party frames (REQ-001) | `Blizzard_UnitFrame/Shared/PartyFrame.lua` (`PartyFrameMixin`, member pool, `ShouldShow` checks `EditModeManagerFrame:UseRaidStylePartyFrames()`), `Shared/CompactPartyFrame.lua`, and a Forever-specific `Camelot/PartyMemberFrame.lua` | How to hide without breaking Edit Mode. Hide by reparenting like DibsUI does for TargetFrame, checked in the sim and in game |
| Heal prediction (REQ-004) | `CreateUnitHealPredictionCalculator`, `UnitGetDetailedHealPrediction`, as DibsUI uses | Works for player in game (DibsUI 0.1.6). Party units not checked |
| Auras (REQ-020/021) | `AuraContainer` frame type with `CustomAuraContainerTemplate` from `Blizzard_AuraContainer`, as DibsUI uses for target | DibsUI's target groups aren't checked in game. Filters `HELPFUL|PLAYER`, `HARMFUL`, and sorting dispellable-first need checking |
| Range (REQ-011) | `UnitInRange` | May return secret values. Use `SetAlphaFromBoolean` if so |
| Roles (REQ-008) | `UnitGroupRolesAssigned` | Forever may rarely assign roles outside the dungeon finder. Shows nothing then |

## UI and accepted design

- Mock-up: the user's DibsUI workflow is mock-up in the UIForever simulator → user approves →
  build → user tests in game → commit. The user asked for the UIForever sim on workspace 4.
- Accepted design: none yet.
- Art: DibsUI's `Media` textures, copied unchanged.
- States to show in the mock-up: 4 members of different classes and powers (mana, rage, energy), one
  hunter with a pet, heal and absorb prediction, a dead and an offline member, out of range, buffs
  wrapping to 2 rows, 4 debuffs of different types, leader/role/marker/ready-check icons, all 5
  layouts, portraits vs class icons, and the settings tab, standalone and inside DibsUI's window.

## Options and localization

- Discovery: the addon's own window (REQ-030), slash commands and Options > AddOns page (REQ-039);
  inside DibsUI's window when it is installed (REQ-051).
- Storage: standalone, `DibsUIPartyDB` (account-wide, one set of settings). With DibsUI, a `party`
  table inside each DibsUI profile (REQ-052). Test frames aren't saved.
- Localization: English only, by the user's choice (REQ-060).

## Controller

Excluded by the user's choice (REQ-060), as with DibsUI. Mouse and keyboard only.

## Testing

- Route: UIForever simulator (https://uiforever.com/app?flavor=forever) on Hyprland workspace 4,
  driven with Claude in Chrome. The user's choice, 2026-11-15.
- In game: the user tests. Never run Wow.exe from automation.
- Needs the real client: secret values in combat (ring, bars, prediction, range), real auras on
  party members, pets appearing mid-combat, ready checks, roles, Masque, DibsUI profile sharing.

## Open questions

| ID | Question | Status |
|---|---|---|
| Q-001 | "Debuffs … match the party frame in height": the whole frame or the health bar? | **Answered 2026-11-15: bar height** (DEC-012). Orb height made horizontal layouts wider than a 1920 screen |
| Q-002 | Default frame size | **Answered 2026-11-15: keep the size, add a Scale slider** (DEC-013) |
| Q-003 | Whether the health bar sits level with the orb's centre or higher, like DibsUI's target bar | To settle in the mock-up |

## Decisions

| ID | Decision | Source |
|---|---|---|
| DEC-001 | Standalone and integrated modes: one window, settings inside DibsUI's profiles when DibsUI is there | User, 2026-11-15 |
| DEC-002 | Hide in raids | User |
| DEC-003 | English only, no controller | User |
| DEC-004 | Moving: Unlock button like DibsUI, no Edit Mode | User |
| DEC-005 | Health text value and percent by default, mouseover-only option | User |
| DEC-006 | Indicators: leader, role, raid marker, ready check, range fading | User |
| DEC-007 | Buffs: mine only, max 2 rows. Debuffs: all, dispellable first, max 4. Room reserved | User |
| DEC-008 | Player frame last when shown | User |
| DEC-009 | Party pet bars in v1, using the target power bar art, name on mouseover | User |
| DEC-010 | Layout changes (pets appearing, roster changes) wait for combat to end. Secure click areas can't move in combat | Implementation constraint (REQ-063) |
| DEC-012 | Debuffs are as tall as the health bar (34 units), level with it, swipe only (no time text at that size) | User, 2026-11-15, after the mock-up |
| DEC-013 | Scale slider (0.5–2, default 1) on the Party Frames page, locked in combat | User, 2026-11-15 |
| DEC-014 | Health bar 50% taller by stretching DibsUI's art vertically (no new art). Debuffs follow it to 51 units | User request 2026-11-15; stretching is Claude's choice, checked in the sim |
| DEC-015 | Real auras use Blizzard's aura containers (as DibsUI). Buffs: one group, HELPFUL\|PLAYER. Debuffs: "dispellable" (HARMFUL\|RAID) then "others" (HARMFUL\|!RAID, Blizzard's unit frame debuff order). Caps by clipping each holder to its rows. Containers made at PLAYER_LOGIN; UpdateAllAuras on roster changes. Under a Masque skin the debuff type color sits behind the icon, as in DibsUI, so it doesn't show | Implementation, 2026-11-15, from the Forever source at bebcb6b |
| DEC-011 | Shared code is copied from DibsUI, not loaded from it, so DibsUI-Party works alone. DibsUI gets a small public hook (`DibsUI_API`) for the tab, profiles and unlock | Implementation decision for REQ-050–054 |

## Completion criteria

Every REQ above has a matrix row that is built, checked in the sim where the sim can show it, and
checked in game by the user. Anything the sim can't show (secret values, real auras, pets in
combat) stays open until the user checks it in game.
