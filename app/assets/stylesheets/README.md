# ShelfStack Preview CSS Bundle

This bundle gives you a preview setup for the visual direction experiments.

## Files

### `shelfstack.visual-preview.css`

Base visual-direction overlay. Load after your existing `shelfstack.css`.

It adds:
- warm paper background
- soft surfaces
- rounded cards/panels
- pill badges
- calmer tables
- item overview cockpit styling
- POS styling that is aligned but less decorative

This file is font-neutral through `--font-ui`, defaulting to Atkinson Hyperlegible.

### `shelfstack.ux-improvements.css`

CSS-only UX experiments. Load after `shelfstack.visual-preview.css`.

It adds:
- page headers as context cards
- first-button primary-action emphasis
- calmer badges
- better zebra table scanability
- item overview refinements
- filter panel styling
- POS restraint

### `shelfstack.lexend.css`

Lexend font experiment. Load after the visual preview and UX-improvement layers.

It imports Lexend and sets:

```css
--font-ui: "Lexend", ...
```

### `shelfstack.lexend-density.css`

Spacing compensation for Lexend. Load after `shelfstack.lexend.css`.

It tightens:
- buttons
- badges
- tables
- filters
- forms
- item overview
- POS panels
- dropdowns
- summaries

### `shelfstack.preview-atkinson.css`

Convenience import file for the Atkinson/default preview.

### `shelfstack.preview-lexend.css`

Convenience import file for the full Lexend preview.

## Recommended Rails import options

### Option A — Atkinson/default visual preview

```css
@import "shelfstack.css";
@import "shelfstack.preview-atkinson.css";
```

### Option B — Lexend visual preview

```css
@import "shelfstack.css";
@import "shelfstack.preview-lexend.css";
```

### Option C — Explicit import order

```css
@import "shelfstack.css";
@import "shelfstack.visual-preview.css";
@import "shelfstack.ux-improvements.css";
@import "shelfstack.lexend.css";
@import "shelfstack.lexend-density.css";
```

## Notes

- These files are preview overlays. They are intentionally loaded after the current CSS.
- Keep them removable until you decide which visual changes should become permanent.
- The first-button primary-action emphasis is a heuristic. Long term, use explicit `.ss-btn-primary`, `.ss-btn-secondary`, and `.ss-btn-tertiary` classes.
- In production, consider self-hosting fonts or loading them through the Rails asset pipeline rather than using Google Fonts imports directly.
