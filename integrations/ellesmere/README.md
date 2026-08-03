# EllesmereUI Extended Stagger (local)

Local-only integration of Better Stagger's engine into **EllesmereUI Resource Bars**.

This is **not** an official Ellesmere module and is **not** intended for upstream PR until discussed with the maintainer.

## What it does

- Adds an **Extended Stagger** section (Brewmaster only) under Resource Bars -> Class, Power and Health Bars.
- Hosts enhancements on the existing Class Resource bar (`ERB_SecondaryBar`).
- Toggle is **default OFF** (stock EUI stagger when off).

## Deploy

From the repo root:

```powershell
.\scripts\deploy.ps1 -Target Ellesmere
```

Optional path override:

```powershell
.\scripts\deploy.ps1 -Target Ellesmere -WoWAddOnsPath "D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns"
```

Then `/reload` in WoW.

Standalone Better Stagger:

```powershell
.\scripts\deploy.ps1 -Target Standalone
```

When testing Extended Stagger, disable the standalone **BetterStagger** addon to avoid a second bar.

## Files installed into Resource Bars

- `ExtendedStagger.lua` - runtime (ceiling, zone colors, divider lines)
- `ExtendedStagger_Options.lua` - DualRow / cog UI
- TOC entries for both
- Idempotent hook call inside `UpdateSecondaryResource` stagger path (gated on `sp.extendedStagger`)

## Manual test checklist

1. Brewmaster: Resource Bars -> Class Resource visible.
2. **Extended Stagger** toggle off -> stock green/yellow/red stagger.
3. Toggle on -> scale default 400%, zone divider lines, zone colors.
4. Change Scale Maximum / colors / line settings via DualRows + cog.
5. Unlock Mode still moves the Class Resource bar.
6. Spec away from Brewmaster -> Extended section hidden; no extra cost.
7. `/reload` preserves settings under `EllesmereUIResourceBarsDB` (`extendedStagger` / `extendedStaggerSettings`).

## Notes

- Re-run deploy after Ellesmere updates; the hook is re-applied via markers.
- Unit Frames / Nameplates Class Power can still show stagger separately - leave those off if you only want one bar.
