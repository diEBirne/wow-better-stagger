# EllesmereUI Brewmaster Monk Extended Stagger Bar (local)

Local-only integration of Better Stagger's engine into **EllesmereUI Resource Bars**.

This is **not** an official Ellesmere module and is **not** intended for upstream PR until discussed with the maintainer.

## What it does

- Adds **Brewmaster Monk Extended Stagger Bar** rows at the top of **CLASS RESOURCE BAR** (above Show Class Resource; same placement as Ironfur / Ignore Pain / Sweeping Strikes).
- Hosts enhancements on the existing Class Resource bar (`ERB_SecondaryBar`).
- Toggle is **default OFF** (stock EUI stagger when off); dependent controls are greyed while off.

## Deploy

From the repo root:

```powershell
.\scripts\deploy-ellesmere.ps1
# or: .\deploy-ellesmere.bat
# or: .\scripts\deploy.ps1 -Target Ellesmere
```

Then `/reload` in WoW.

When testing, disable the standalone **BetterStagger** addon to avoid a second bar.

**After any EllesmereUI / Resource Bars update**, run the deploy again — the updater overwrites our TOC entries, runtime hook, and copied Lua files.

EUI 8.8+: Resource Bars options live in LoadOnDemand `EllesmereUIOptions`. Deploy still patches `EllesmereUIResourceBars` only; the options rows hook `ns.ERB_BuildClassResourceSection` when Options loads.

## Files installed into Resource Bars

- `BrewmasterExtendedStaggerBar.lua` - runtime
- `BrewmasterExtendedStaggerBar_Options.lua` - DualRow / cog UI
- TOC entries after `EllesmereUIResourceBars.lua`
- Idempotent hook after secondary `SetValue`, gated on `sp.brewmasterExtendedStaggerBar`

## SavedVariables

- `brewmasterExtendedStaggerBar` (bool, default false)
- `brewmasterExtendedStaggerBarSettings` (table)
- Migrates legacy `extendedStagger*` / `enhancedStagger*` once
