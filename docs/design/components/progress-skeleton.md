# Progress / Skeleton

| Field | Value |
| :---- | :---- |
| Status | CSS only (scaffold) |
| CSS | `app/assets/stylesheets/shelfstack.components.feedback.css` |
| Related | [Empty State](empty-state.md), [Toast](toast.md) |
| Design-system priority | Priority 2 (feedback module) |

Progress and skeleton patterns show in-flight or not-yet-loaded content.

## Purpose

| Pattern | Use when |
| :---- | :---- |
| Progress | A bounded operation is underway (upload, batch job, multi-step post) |
| Skeleton | Layout is known but data is still loading |

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

Lives in the same file; documents success styling on copy actions, not a standalone component.

## Accessibility requirements

1. Progress must expose `role="progressbar"` with `aria-valuenow` / `aria-valuemin` / `aria-valuemax` when values are known.  
2. Skeleton placeholders should be removed or replaced when content loads.  
3. Do not use skeleton for empty results; use [Empty State](empty-state.md).  
4. Long-running operations should also expose status text where practical.

## Examples

### Progress bar

```
<div class="ss-progress" role="progressbar" aria-valuenow="40" aria-valuemin="0" aria-valuemax="100">
  <div class="ss-progress__bar" style="width: 40%"></div>
</div>
```

### Skeleton placeholder

```
<div class="ss-skeleton" style="height: 1rem; width: 12rem;" aria-hidden="true"></div>
```

## Migration notes

CSS exists but view usage is minimal today. Add a shared partial only when a real loading workflow needs it (Turbo frame refresh, import progress, etc.).
