# Ellesmere Brewmaster Extended Stagger Bar - local in-game validation

After `.\scripts\deploy-ellesmere.ps1` (or `.\deploy-ellesmere.bat`) and `/reload`:

## Prep

1. Disable the standalone **BetterStagger** addon.
2. Log in as **Brewmaster Monk**.
3. Open EllesmereUI -> **Resource & Cast Bars** -> **Class, Power and Health Bars**.

## Checklist

- [ ] Toggle **Brewmaster Monk Extended Stagger Bar** sits near the top of **CLASS RESOURCE BAR** (above Show Class Resource), like Ironfur / Ignore Pain / Arms.
- [ ] Toggle **Brewmaster Monk Extended Stagger Bar** is off by default; dependent controls greyed.
- [ ] Enable: Scale (2-6) / Scale Colors / divider cog work on the Class Resource bar.
- [ ] Each Scale step adds exactly 100% capacity and one color range; Scale 6 fills at 600% with dividers at 100/200/300/400/500%.
- [ ] Anchor to Cursor still belongs to Class Resource (after the shared section).
- [ ] Spec off Brewmaster: rows hidden.
- [ ] `/reload` keeps `brewmasterExtendedStaggerBar*` settings (legacy independent Scale Maximum / Zones migrate to the nearest Scale step).
