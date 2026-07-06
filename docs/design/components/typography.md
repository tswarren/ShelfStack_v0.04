# Typography

| Field | Value |
| ----- | ----- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.typography.css` |
| Planned partial | None |
| Related | Layout Shell, Page Header, Utilities, Tokens |
| Design-system priority | Priority 3 foundation |

Typography defines ShelfStack’s text hierarchy, supporting copy, labels, numeric formatting, and code blocks.

---

## Purpose

Use typography classes to clarify hierarchy and readability while preserving semantic HTML.

```text
Semantic HTML first.
Typography classes refine presentation.
Do not use typography classes to fake document structure.
```

---

## Use for

| Pattern | Use |
| ------- | --- |
| `h1`–`h4` | Semantic headings and section hierarchy |
| `.ss-heading--page` / `.ss-page-title` | Page-title letter spacing treatment |
| `.ss-page-description` | Description under page title |
| `.ss-help` / `.ss-hint` / `.ss-inline-note` | Supporting explanatory copy |
| `.ss-muted` / `.ss-text-muted` | Low-emphasis text |
| `.ss-text-subtle` | Even quieter supporting text |
| `.ss-label` / `.ss-eyebrow` | Short uppercase labels/context |
| `.ss-tabular` / `.ss-money` / `.ss-percent` / `.ss-num` | Comparable numeric values |
| `.ss-code` / `.ss-code-block` | Technical strings and examples |

---

## Do not use for

| Avoid using typography classes for | Use instead |
| --------------------------------- | ----------- |
| Replacing heading semantics | Correct `h1`–`h4` structure |
| Status/state | Badge / Status Badge |
| Alerts/warnings | Alert / Attention Panel |
| Button labels/actions | Button / Link components |
| Form labels when using field partial | Existing field label output |
| Layout spacing | Layout/utility/component classes |

---

## Implemented CSS

### Heading treatment

```css
h1
h2
h3
h4
.ss-heading--page
.ss-page-title
```

### Supporting text

```css
.ss-page-description
.ss-help
.ss-hint
.ss-inline-note
.ss-text-muted
.ss-muted
.ss-text-subtle
```

### Labels and context

```css
.ss-label
.ss-eyebrow
```

### Numeric text

```css
.ss-tabular
.ss-money
.ss-percent
.ss-num
```

### Code

```css
.ss-code
.ss-code-block
code
pre
```

---

## Accessibility requirements

1. Use one meaningful `h1` per page.
2. Do not skip heading levels only for visual size.
3. Muted/subtle text must still meet readability requirements for supporting content.
4. Do not rely on typography alone to convey status or severity.
5. Numeric values should include clear labels and units where needed.
6. Code/pre blocks should be horizontally scrollable when content can overflow.

---

## Examples

### Page title and description

```erb
<header class="ss-page-header">
  <div>
    <h1>Items</h1>
    <p class="ss-page-description">Search catalog, selling setup, and sellable SKUs.</p>
  </div>
</header>
```

### Eyebrow/context label

```erb
<p class="ss-eyebrow">Purchasing</p>
<h2>Vendor sources</h2>
```

### Muted supporting text

```erb
<p class="ss-muted">Last received: <%= display_time(@variant.last_received_at) %></p>
```

### Numeric value

```erb
<td class="ss-num"><%= @stock.on_hand %></td>
<td class="ss-money"><%= number_to_currency(@stock.value) %></td>
```

### Code block

```erb
<pre class="ss-code-block"><code>bin/rails test test/system/app_shell_contract_test.rb</code></pre>
```

---

## Migration notes

Prefer semantic heading and text markup first. Add typography classes only when the reusable visual treatment is intended. Avoid creating page-specific text classes when an existing typography class is sufficient.
