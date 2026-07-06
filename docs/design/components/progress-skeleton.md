# Progress / Skeleton

| Field | Value |
| :---- | :---- |
| Status | CSS only (scaffold) |
| CSS | `app/assets/stylesheets/shelfstack.components.feedback.css` |
| Related | [Empty State](empty-state.md), [Toast](toast.md), copy-button state |
| Design-system priority | Priority 2 (feedback module) |

Progress and skeleton patterns show in-flight or not-yet-loaded content.

## Purpose

| Pattern | Use when |
| :---- | :---- |
| Progress | A bounded operation is underway (upload, batch job, multi-step post) |
| Skeleton | Layout is known but data is still loading |
| Copy state | A copy action has just succeeded |

## CSS

### Implemented

```css
.ss-progress
.ss-progress__bar
.ss-skeleton
```

`.ss-progress` is a horizontal track; `.ss-progress__bar` fills it. `.ss-skeleton` is a shimmer block for placeholder content.

### Related feedback state

```css
.ss-copy-button--copied
```

Only the copied-state modifier exists in modular feedback CSS today. There is no complete base `.ss-copy-button` component contract yet.

Use the copied state only when the underlying copy control already has appropriate button/link semantics.

## Copy button guidance

Copy controls should normally be buttons:

```erb
<button type="button"
        class="ss-btn ss-btn-secondary ss-btn--small"
        data-action="clipboard#copy">
  Copy
</button>
```

After copying, the control may receive copied-state styling:

```erb
<button type="button"
        class="ss-btn ss-btn-secondary ss-btn--small ss-copy-button--copied">
  Copied
</button>
```

Do not treat `.ss-copy-button--copied` as a standalone component. A full copy-button spec should wait until base `.ss-copy-button` styling and repeated usage exist.

## Accessibility requirements

1. Progress must expose `role="progressbar"` with `aria-valuenow` / `aria-valuemin` / `aria-valuemax` when values are known.
2. Skeleton placeholders should be removed or replaced when content loads.
3. Do not use skeleton for empty results; use [Empty State](empty-state.md).
4. Long-running operations should also expose status text where practical.
5. Copy controls must have a clear accessible label and should communicate success without relying only on color.

## Examples

### Progress bar

```erb
<div class="ss-progress" role="progressbar" aria-valuenow="40" aria-valuemin="0" aria-valuemax="100">
  <div class="ss-progress__bar" style="width: 40%"></div>
</div>
```

### Skeleton placeholder

```erb
<div class="ss-skeleton" style="height: 1rem; width: 12rem;" aria-hidden="true"></div>
```

### Copied state

```erb
<button type="button" class="ss-btn ss-btn-secondary ss-btn--small ss-copy-button--copied">
  Copied
</button>
```

## Migration notes

CSS exists but view usage is minimal today. Add a shared progress/skeleton partial only when a real loading workflow needs it (Turbo frame refresh, import progress, etc.).

Do not create a copy-button partial until base `.ss-copy-button` styling exists and the pattern is repeated across multiple workflows.
