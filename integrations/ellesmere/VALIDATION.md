# Ellesmere Enhanced Stagger — local in-game validation

After `.\scripts\deploy.ps1 -Target Ellesmere` and `/reload`:

## Prep

1. Disable the standalone **BetterStagger** addon (AddOns list) to avoid a second bar.
2. Log in as **Brewmaster Monk**.
3. Open EllesmereUI → **Resource & Cast Bars** → **Class, Power and Health Bars**.

## Checklist

- [ ] Section **ENHANCED STAGGER** appears (Brewmaster only).
- [ ] Toggle **Enhanced Stagger** is off by default.
- [ ] Cog icon size matches other Class Resource cogs.
- [ ] Enable Enhanced Stagger + **Test Mode**, set **Test Stagger %** to ~200.
- [ ] Bar fill/color reacts immediately to Test Stagger %, Scale Maximum, and Fill Color.
- [ ] Breakpoint lines are uniform thickness; **Line Thickness** in the cog changes them.
- [ ] **Add Color Rule** / **-** remove works; labels are **From %** / **Fill Color**.
- [ ] Unlock Mode still moves the Class Resource bar.
- [ ] Spec off Brewmaster: Enhanced section hidden.
- [ ] `/reload` keeps Enhanced settings.

## Standalone regression

`.\scripts\deploy.ps1 -Target Standalone` then enable BetterStagger: `/bs config`, Edit Mode, breakpoints still work.
