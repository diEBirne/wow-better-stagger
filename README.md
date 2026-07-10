# Better Stagger

Lightweight World of Warcraft **Retail** addon for **Brewmaster Monks**. Displays a custom Stagger bar that scales beyond the usual 0–100% range, so values like 200%, 300%, or 400% stay visually readable.

**Version:** 0.1.0 · **Author:** di3Birne

## Why Better Stagger?

Default UI and many addons cap Stagger at 100% of max health. In higher content, Brewmaster Stagger often exceeds that. A bar stuck at “full” forces you to read numbers instead of using the bar as a visual indicator.

Better Stagger lets you set the bar maximum (default **400%**). Example: **200% Stagger** with a **400%** scale fills the bar to **50%**.

## Installation

1. Copy the [`BetterStagger/`](BetterStagger/) folder to:
   `World of Warcraft/_retail_/Interface/AddOns/BetterStagger/`
2. Restart WoW or type `/reload`.
3. Log in on a Brewmaster Monk, or use `/bs test` on any character to preview the bar.

## Quick start

| Action | How |
|--------|-----|
| Open settings | **Esc → Settings → AddOns → Better Stagger** or `/bs config` |
| Move the bar | `/bs unlock` → drag → `/bs lock` |
| Test without Stagger | `/bs test` (simulated 237%) |
| Reset position | `/bs reset` or **Reset Bar Position** in settings |

## Features (v0.1.0)

### Scale modes

- **Fixed linear (default):** Upper scale end configurable (default 400%).
- **Peak-based dynamic:** Maximum from recent peak Stagger + buffer, clamped and rounded.

### Bar display

- Fill based on `staggerPercent / scaleMaximum` (clamped 0–1).
- **Colors** by actual Stagger thresholds (green / yellow / orange / red).
- **Absolute breakpoints** at real Stagger values (default 100%, 200%, 300%).
- **Glow warning** above a configurable threshold (default 300%).
- **Sound warning** optional, with cooldown (default off).

### Text on bar

Configurable in **Settings → Text**:

- **Show Bar Text** — master on/off.
- **Text Format:** Hidden, Current only (`237%`), or Current / Maximum (`237% / 400%`).
- **Text Anchor:** Center, Left, Right, Top, Bottom.
- **Text Offset X/Y** — fine-tune position.
- **Font size.**

Default format is **Current only** (`237%`), not `237% / 400%`.

### Breakpoint labels

- Toggle labels on/off.
- **Label position:** Above line, Below line, or On line (centered).
- **Breakpoint values:** Settings → **Breakpoints** subpage — comma-separated (e.g. `100, 200, 300`).

### Visibility

- Show only as Brewmaster (default on).
- Hide out of combat.
- Hide when Stagger is 0.

### Performance

- Event-driven updates + throttled polling (default **0.1 s**, configurable 0.05–0.5).
- OnUpdate pauses when the bar is hidden.

## Slash commands

| Command | Description |
|---------|-------------|
| `/bs` or `/bs help` | Help |
| `/bs config` | Open settings |
| `/bs lock` / `/bs unlock` | Lock/unlock bar movement |
| `/bs reset` | Reset bar position |
| `/bs test` | Toggle test mode |

Full configuration is in the settings panel — slash commands are shortcuts only.

## Example: fixed 400% scale

| Stagger | Bar fill |
|--------:|---------:|
| 100% | 25% |
| 200% | 50% |
| 300% | 75% |
| 400% | 100% |

## Project layout

```text
BetterStagger/
  BetterStagger.toc
  Defaults.lua      Saved variables + defaults
  Utils.lua         Helpers
  Bar.lua           Bar UI
  Core.lua          Update loop + logic
  ConfigPanel.lua   WoW Settings integration
  Slash.lua         Slash commands
```

## Roadmap

See [docs/ROADMAP.md](docs/ROADMAP.md) for planned improvements, known gaps, and future ideas.

## License

Not specified yet — add a license file if you plan to publish the addon.
