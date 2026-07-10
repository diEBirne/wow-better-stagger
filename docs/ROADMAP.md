# Better Stagger — Roadmap

Living document for planned work, known gaps, and ideas. Updated as the addon evolves.

**Current version:** 0.1.0 (first in-game build, limited testing)

---

## Immediate fixes (done or in progress)

| Item | Status |
|------|--------|
| Settings panel not in Esc → AddOns | Fixed: `RegisterAddOnCategory` before controls; `type(defaultValue)` for checkboxes |
| `/bs config` not opening panel | Fixed: use stored category ID |
| Addon list `?` icon | Fixed: Brewmaster spec icon in `.toc` |
| Bar text always `0% / 400%` | Fixed: default format `current`; Hidden / anchor / offset in settings |
| Breakpoint label position | Added: above / below / on line |
| `shouldShow` Lua error in Core | Fixed |
| README out of date | Updated |

---

## Phase 0 — Validate & stabilize

Manual in-game checklist:

1. `/reload` — no Lua errors in chat
2. Esc → Settings → AddOns → **Better Stagger** visible
3. `/bs config` opens the same panel
4. Width/height sliders change bar live
5. Text: Hidden, Current only, Current/Max; anchor + offset
6. `/bs unlock` → drag → `/reload` → position saved
7. Brewmaster: real Stagger values plausible
8. `/bs test` on non-Brewmaster
9. Breakpoints subpage: edit `100, 200, 300` → Apply
10. Dynamic mode: text shows `dyn NNN%`

---

## Spec gaps (in defaults, limited or no UI)

| Feature | Notes |
|---------|--------|
| Color threshold editor | Defaults only; no UI to edit values/colors |
| Bar texture picker | Hardcoded `UI-StatusBar` |
| Background RGB | Alpha only in panel |
| Text color | Not in panel |
| Breakpoint line color | Not in panel |
| Custom sound file | DB field exists; no picker |
| Text formats `amount`, `amountAndPercent` | Not implemented |
| Test mode animation | Static 237% only |
| Reset all settings | Only position reset |

---

## Phase 1 — Spec completeness (v0.2.0)

- Color threshold editor (values + colors)
- Text color, breakpoint color, background RGB
- Bar texture: small built-in list (no external libs)
- Sound: dropdown of Blizzard sounds
- Test Stagger value slider + optional animation
- Reset all settings to defaults
- Improved DB merge for array defaults (breakpoints)

---

## Phase 2 — UX & best practices (v0.3.0)

- Settings split into real subcategories (Appearance, Scale, …)
- Presets: M+, Raid, Minimal UI
- Addon Compartment entry (quick open settings)
- Optional `SavedVariablesPerCharacter`
- Localization (en/de)
- Named performance presets (Balanced, Relaxed, …)

---

## Phase 3 — Extensions (v1.0+)

- Profile import/export
- Non-linear scale (clearly labeled)
- Vertical bar orientation
- SharedMedia / Masque (only if dependencies OK)
- Edit Mode integration

---

## Explicitly not planned for near term

- Heavy frameworks (Ace3) for settings
- Per-frame updates
- Non-linear scale in v0.2 (confusing without clear UX)

---

## Design principles

1. **Lightweight** — event-first, throttled poll, pause when hidden
2. **Simple** — one bar, one job
3. **Highly customizable** — settings panel as source of truth
4. **Stable** — safe settings registration, pcall on control setup
5. **Readable** — colors/breakpoints use **actual** Stagger %, not fill %
