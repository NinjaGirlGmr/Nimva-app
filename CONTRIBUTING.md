# Contributing / Working Notes

This is currently a solo project, so "contributing" mostly means *future me knowing what past me was thinking*. A few habits worth keeping consistent:

## The Stray Spark Log 🔥

Every time something breaks, surprises you, or you make a decision worth remembering — log it. See [`STRAY_SPARK_LOG.md`](STRAY_SPARK_LOG.md) for the format.

If working from GitHub Issues instead of the file directly:
- Label: 🔥 `stray-spark`
- Title: short description of the spark
- Body: Spark / Chase / Catch format from the log template
- Close the issue once "Catch" is filled in — closed stray-spark issues become a searchable history of real decisions made during development


## Before Adding a New Screen or Component

Check `docs/design-reference.md` for:
- Color palette (and the coral-replaces-blue rule for the second flexible event color)
- Typography roles (Outfit for headers/numbers, Nunito for body — once applied)
- Cross-screen consistency rules section — covers spacing, glow usage, stat chip patterns

## Accessibility Checklist (quick reference)

From `docs/technical-requirements.md` section 3.3 — keep these in mind for every screen:
- WCAG 2.1 AA contrast ratios
- 44×44px minimum touch targets
- Never color-only — always pair with text/icon/shape
- Animations subtle, non-essential, and don't convey information alone
- Sounds/haptics must be fully toggleable
