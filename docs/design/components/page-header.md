# Page Header

| Field | Value |
| :---- | :---- |
| Status | Mixed / partial exists |
| CSS | `app/assets/stylesheets/shelfstack.layout.css` |
| Current partial | `app/views/shared/forms/_page_header.html.erb` |
| Planned generic partial | `app/views/shared/ui/_page_header.html.erb` |
| Related | Button, Alert, Card |
| Design-system priority | Priority 1 |

Page headers identify the page, explain its purpose, and expose top-level page actions.

## Purpose

Use a page header at the top of index, detail, setup, report, and workflow pages.

## Use for

| Use case | Example |
| :---- | :---- |
| Index page | Items, Customers, Reports |
| Detail page | Purchase Order, Register Session |
| Workflow page | Receive Order, Add Item |
| Setup page | Tax Categories, Users |
| Report page | Register Summary |

## Do not use for

| Avoid using Page Header for | Use instead |
| :---- | :---- |
| Card section title | Section Header |
| Modal title | Dialog Header |
| POS workspace session bar | POS Workspace Header |
| Inline table group | Section Header |
| Repeated nested content | Card Header |

## CSS

### Implemented

```css
.ss-page-header
.ss-page-description
.ss-page-actions
.ss-page-header__actions
.ss-eyebrow
```

Title styling targets a plain `<h1>` inside `.ss-page-header`. There is no `.ss-page-header__title` class in CSS.

`shared/forms/_page_header.html.erb` matches this pattern: eyebrow (optional), `<h1>`, description, actions.

## Current partial

Form-oriented:

```
app/views/shared/forms/_page_header.html.erb
```

Use it for compatible form pages. A generic UI partial should be extracted later.

## Accessibility requirements

1. The page should have one clear `h1`.  
2. Page actions should be visually and structurally grouped.  
3. Descriptions should be concise.  
4. Header actions must not duplicate global navigation.  
5. The page header should not become a dumping ground for workflow state; use alerts/panels for that.

## Action order

Page headers use a **title/context block on the left** and **`.ss-page-actions` on the right**.

Within `.ss-page-actions`, order buttons **secondary → primary** (left to right). The primary action is **rightmost** in the cluster.

```text
[ Inactivate ]  [ Edit ]
 secondary       primary
```

Do not place delete or other danger actions in the page header. Use a separated **danger zone** on setup detail show pages (see [button.md](button.md#action-order-shelfstack-standard)).

Form pages that use this header for title/description only should keep submit/cancel in `.ss-form-actions` below the form: **primary left, cancel tertiary right**.

## Example

```
<div class="ss-page-header">
  <div>
    <h1>Items</h1>
    <p class="ss-page-description">
      Search and browse catalog items, selling setup, and sellable SKUs.
    </p>
  </div>

  <div class="ss-page-actions">
    <%= link_to "Add Item", items_new_add_item_path, class: "ss-btn ss-btn-primary" %>
  </div>
</div>
```

## Migration notes

When refactoring, prefer consistent page header structure before extracting a generic partial.  