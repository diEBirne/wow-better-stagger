# AGENTS.md

## Purpose

This file provides instructions for AI coding agents working in this repository.

## Workflow

For non-trivial tasks:

1. Inspect relevant files.
2. Summarize understanding.
3. Create a short plan.
4. Ask for confirmation before large changes.
5. Implement in small steps.
6. Run relevant checks.
7. Summarize changes, test results, and risks.

## Engineering Behavior Rules

### 1. Ask, do not silently assume

Do not make silent assumptions about intent, requirements, architecture, data semantics, or user-facing behavior.

If something important is unclear, ask before changing code.

If working unattended or the assumption is minor and low-risk, choose the most reasonable interpretation, proceed carefully, and explicitly record the assumption in the final summary.

### 2. Match solution complexity to problem complexity

Use the simplest solution that correctly solves the problem.

Do not over-engineer, add premature abstractions, or introduce flexibility that is not needed yet.

Prefer existing project patterns over new architecture.

### 3. Keep changes focused

Do not modify unrelated code.

Do not fix unrelated code smells, formatting, naming, or architecture issues in the same change unless explicitly requested.

If you discover unrelated problems, report them separately as follow-up suggestions.

### 4. Flag uncertainty explicitly

If you are uncertain, say so.

When useful, perform a small, localized, low-risk experiment to validate a hypothesis, such as running a focused test, inspecting a narrow code path, or checking a configuration file.

Report the hypothesis, validation result, and remaining uncertainty.

Do not present guesses as facts.

### 5. Suggest strategic improvements separately

If you see a simpler, more maintainable, or longer-lasting approach, suggest it.

Do not implement broad strategic changes without approval.

Separate tactical fixes from architectural or long-term improvement proposals.

### General Rules

- Do not add dependencies without asking.
- Do not modify secrets, credentials, `.env` files, generated files, or build artifacts.
- Do not commit, push, deploy, or modify production systems unless explicitly asked.
- Do not run destructive git/npm scripts from `package.json` (`git:rollback`, `db:reset-migrations`, `db:push:live`, `git:deploy`, `git:prod`) unless explicitly requested.

## Commands

WoW Retail addon — no automated test runner. Validate manually in-game.

- **Install:** Copy the `BetterStagger/` folder to `World of Warcraft/_retail_/Interface/AddOns/`, then `/reload`.
- **Configure:** Esc → Settings → AddOns → **Better Stagger**, or `/bs config`.
- **Slash shortcuts:** `/bs lock`, `/bs unlock`, `/bs reset`, `/bs test`, `/bs help`.
- **Default update interval:** 0.1 s (configurable 0.05–0.5 in Performance settings).
- **Lint / Typecheck / Build:** N/A (Lua addon, no build step).
- **Deploy Standalone:** `.\scripts\deploy.ps1 -Target Standalone`
- **Deploy Ellesmere Brewmaster Extended Stagger Bar (local):** `.\scripts\deploy-ellesmere.ps1` or `.\deploy-ellesmere.bat` (same as `.\scripts\deploy.ps1 -Target Ellesmere`). Re-run after any EllesmereUI / Resource Bars update; the updater wipes TOC entries, runtime hook, and copied Lua.

## Standalone freeze / EUI work

- Tag `v0.2.0-standalone` freezes the pre-EUI standalone product.
- Branch `eui-integration` holds Core split + local Ellesmere Resource Bars integration (`integrations/ellesmere/`).
- Standalone engine lives under `BetterStagger/Core/`; shell is `Core.lua` + ConfigPanel/EditMode/Slash.
- EUI product name: **Brewmaster Monk Extended Stagger Bar** (opt-in rows under Resource Bars -> CLASS RESOURCE BAR, same pattern as Ironfur / Ignore Pain). Not a separate EUI sidebar module or section header. SavedVariables: `brewmasterExtendedStaggerBar` / `brewmasterExtendedStaggerBarSettings` (migrates legacy `extendedStagger*` / `enhancedStagger*`).
- Runtime (acceptance-oriented): default OFF; updates ride the Resource Bars secondary `SetValue` hook gated on `sp.brewmasterExtendedStaggerBar`; no OnUpdate ticker; `PLAYER_SPECIALIZATION_CHANGED` only while the toggle is ON; overlay created lazily.
- EUI 8.8+: Resource Bars options moved to LoadOnDemand `EllesmereUIOptions`; deploy still patches `EllesmereUIResourceBars` (TOC after main lua + SetValue hook). Options UI wraps `ns.ERB_BuildClassResourceSection` when `EllesmereUIOptions` loads (not only at login).

## Key Design Rule: Documentation Style and Quality

Documentation should be easy to understand for human readers, including readers without a deep technical background.

The goal is that a reader can quickly understand:

- what happens
- why it happens
- where it happens
- where to change it, if they need to maintain it

### Documentation style

For new or substantially changed documentation sections in the `docs/` tree (`user-guide`, `technical`, and module reference pages), use a mixed style:

1. Plain language first, technical references second.
2. Start important sections with a short plain-language summary.
3. For process or workflow descriptions, cover:
   - what happens
   - why it happens
   - where it happens
   - where to change it, when relevant, including file/function references
4. Explain technical terms in simple words the first time they appear on a page.
   Examples: override, mapping, baseline, fixture, pipeline.
5. Prefer concrete mini-examples over abstract architecture wording.
   Example:
   `input file -> config mapping -> normalized output`
6. Add direct links to deeper documentation for details.
7. Do not duplicate long low-level explanations across many pages.
8. Keep documentation concise and maintainable.

### Source of truth

- The current code, configuration, tests, and CI are the source of truth.
- Existing documentation may be outdated.
- Before changing docs, verify important claims against the current implementation.
- If documentation and code disagree, report the mismatch instead of silently copying old documentation.
- Do not change existing documentation unless the task explicitly includes documentation work or the doc update is necessary to keep the repository consistent.

### Documentation quality gate

Before closing documentation tasks, check that:

- The affected docs are understandable for non-programmers.
- Technical references are still present for maintainers.
- Local vs Docker/VM path differences are explicit where relevant.
- File names, links, page order, and workflow references are up to date.
- Technical terms are explained on first use.
- Examples are concrete and match the current code/configuration.
- Long details are linked instead of duplicated.
- If a page intentionally remains technical, the target audience is stated at the top.

## Workflow for agents

1. Read relevant module docs as appropriate and if available.
2. Plan small steps; avoid unrelated refactors.
3. Implement; add/update tests for behavior changes.
4. Run targeted pytest; document if DB/network required and skipped.
5. Summarize files changed, tests run, and risks.

## Project Memory Maintenance

AI agents must preserve durable project knowledge.

During development, if an agent discovers any of the following, it should propose an update to this file or to `.cursor/rules/*.mdc`:

- recurring bugs or pitfalls
- important commands
- test execution issues
- architecture conventions
- data format assumptions
- input/output mapping rules
- customer-specific terminology
- known generated/reference directories
- CI quirks
- environment/setup requirements
- workflow rules that prevent mistakes

Rules for updates:

- Keep additions concise and factual.
- Do not duplicate existing instructions.
- Do not add secrets, credentials, tokens, customer-private data, or raw sensitive sample data.
- Mark assumptions clearly.
- Prefer general durable knowledge over one-off task details.
- At the end of each non-trivial task, report whether `AGENTS.md` or `.cursor/rules` should be updated.
  
## Definition of Done

A task is done when:

- The requested change is implemented.
- Relevant tests were added or updated where practical.
- Relevant checks were run, or the reason they could not be run is documented.
- The changed files are summarized.
- Remaining risks or assumptions are listed.