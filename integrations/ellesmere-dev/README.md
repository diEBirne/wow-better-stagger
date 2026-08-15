# Ellesmere Extended Stagger screenshot helper

Temporary, separate WoW addon for taking screenshots of the local
**Brewmaster Monk Extended Stagger Bar** integration.

It does not modify or add test code to the production integration. The helper
has no SavedVariables and its test mode is off after every reload.

## Deploy

From the repository root:

```powershell
.\scripts\deploy-ellesmere-dev.ps1
```

This first deploys the local Ellesmere integration, then copies
`BrewmasterExtendedStaggerBarDev` into the WoW AddOns folder.

After deployment, enable **Brewmaster Extended Stagger Bar Dev** in the WoW
AddOns list and `/reload`.

## Requirements

- Log in as a Brewmaster Monk.
- Enable **Show Class Resource**.
- Enable **Brewmaster Monk Extended Stagger Bar** in Resource Bars.

## Commands

```text
/bestest              Toggle a fixed 237% preview
/bestest 350          Show a fixed 350% preview
/bestest random       Change to a random value every second
/bestest off          Stop and restore the live bar
/bestest help         Show command help
```

`/esbtest` is an alias for `/bestest`.

Disable or delete this addon after screenshots are complete.

## Why the preview repaints so often

Resource Bars keeps pushing live stagger values (with easing) while test mode
is on. A slow timer would let those live values show through as flicker, so the
preview repaints every frame and also re-applies right after each Resource Bars
update, including the count text.
