# ShelfStack Layout Width Model

ShelfStack uses a wide default application canvas because most screens combine operational content, side context, filters, summary cards, action rows, and tables.

**Implementation detail** (import order, token definitions, `.ss-main--*` in layouts): see [app/assets/stylesheets/README.md](../../app/assets/stylesheets/README.md#layout-width-model).

The guiding distinction is:

```text
Page canvas width != readable content width
```

The app should give operational screens enough horizontal room by default, then constrain specific content inside that canvas when needed.

## Width tokens

| Token | Value | Purpose |
| --- | ---: | --- |
| `--layout-narrow` | `42rem` | Focused forms, login/unlock/session/account cards |
| `--layout-readable` | `1180px` | Readable reports, text-heavy pages, simple detail pages |
| `--layout-standard` | `1440px` | Default application canvas for most operational screens |
| `--layout-max` | `var(--layout-standard)` | Backward-compatible default alias |
| `--layout-item-detail` | `var(--layout-standard)` | Semantic alias for item detail pages |
| `--layout-wide` | `1500px` | POS, receiving, inventory grids, and very dense workspaces |

## Main layout classes

| Class | Width | Use |
| --- | --- | --- |
| `.ss-main` | `--layout-standard` | Default app canvas |
| `.ss-main--readable` | `--layout-readable` | Text-heavy/detail/report pages that should not use the full canvas |
| `.ss-main--narrow` | `--layout-narrow` | Focused forms and account/session screens |
| `.ss-main--items` | `--layout-item-detail` | Item detail pages; semantic alias of standard width |
| `.ss-main--wide` | `--layout-wide` | POS, receiving, inventory grids, dense operations |
| `.ss-main--full` | no max width | Rare full-width operational workspaces |

## Internal constraints

Use internal constraints when the page canvas is wide but the content should not stretch.

```css
.ss-readable {
  max-width: var(--layout-readable);
}

.ss-text-measure {
  max-width: 70ch;
}
```

Examples:

| Content | Recommended constraint |
| --- | --- |
| Long explanatory text | `.ss-text-measure` |
| Simple report body | `.ss-readable` or `.ss-main--readable` |
| Focused form card | `.ss-main--narrow` or card max-width |
| Wide data table | Default canvas or `.ss-main--wide` |
| Item detail | Default canvas / `.ss-main--items` |

## Design rule

Do not ask first whether a page should be wide. The default answer is yes: ShelfStack is an operational app.

Ask instead:

```text
What parts of this wide canvas should be constrained?
```

This keeps ShelfStack screens spacious enough for bookstore operations while preserving readability for forms, text, and small detail panels.
