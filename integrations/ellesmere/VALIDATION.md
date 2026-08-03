# Ellesmere Extended Stagger - local in-game validation

After `.\scripts\deploy.ps1 -Target Ellesmere` and `/reload`:

## Prep

1. Disable the standalone **BetterStagger** addon (AddOns list) to avoid a second bar.
2. Log in as **Brewmaster Monk**.
3. Open EllesmereUI -> **Resource & Cast Bars** -> **Class, Power and Health Bars**.

## Checklist

- [ ] Section **Extended Stagger** appears (Brewmaster only), after **Anchor to Cursor**.
- [ ] Toggle **Extended Stagger** is off by default; stock stagger unchanged.
- [ ] With toggle off: no Extended overlay / no extra bar behavior.
- [ ] Enable Extended Stagger: Scale Maximum 400, Zones 4, divider lines on, thickness 2, line color black (fresh profile / after reset).
- [ ] In combat / with Stagger: bar uses extended scale, zone colors, and divider lines (driven by Resource Bars updates; no custom OnUpdate ticker).
- [ ] Changing Scale Maximum / Zones / Zone Colors / line settings updates the live bar.
- [ ] Spec off Brewmaster with feature still enabled: overlay hidden; switching back restores it.
- [ ] Disable feature: stock ceiling/colors restored after refresh.
- [ ] `/reload` keeps Extended settings.

## Standalone regression

`.\scripts\deploy.ps1 -Target Standalone` then enable BetterStagger: `/bs config`, Edit Mode, breakpoints still work.
