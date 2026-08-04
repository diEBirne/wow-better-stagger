# EllesmereUI Brewmaster Monk Extended Stagger Bar (local)

Local-only integration of Better Stagger's engine into **EllesmereUI Resource Bars**.

This is **not** an official Ellesmere module and is **not** intended for upstream PR until discussed with the maintainer.

## What it does

- Adds **Brewmaster Monk Extended Stagger Bar** rows inside **CLASS RESOURCE BAR** (same pattern as Ironfur / Ignore Pain / Sweeping Strikes).
- Hosts enhancements on the existing Class Resource bar (`ERB_SecondaryBar`).
- Toggle is **default OFF** (stock EUI stagger when off); dependent controls are greyed while off.

## Deploy

From the repo root:

```powershell
.\scripts\deploy.ps1 -Target Ellesmere
```

Then `/reload` in WoW.

When testing, disable the standalone **BetterStagger** addon to avoid a second bar.

## Files installed into Resource Bars

- `BrewmasterExtendedStaggerBar.lua` - runtime
- `BrewmasterExtendedStaggerBar_Options.lua` - DualRow / cog UI
- TOC entries for both
- Idempotent hook gated on `sp.brewmasterExtendedStaggerBar`

## SavedVariables

- `brewmasterExtendedStaggerBar` (bool, default false)
- `brewmasterExtendedStaggerBarSettings` (table)
- Migrates legacy `extendedStagger*` / `enhancedStagger*` once
