# Link

| Field | Value |
| :---- | :---- |
| Status | CSS only |
| CSS | `app/assets/stylesheets/shelfstack.components.links.css` |
| Planned partial | `app/views/shared/ui/_link.html.erb` |
| Related | `.ss-btn-link`, `.ss-nav__item`, `.ss-dropdown-menu__item`, breadcrumbs, tabs |
| Design-system priority | Priority 1 |

Links navigate. They take the user to another page, section, resource, filtered view, or external destination.

## Purpose

Use links for navigation and reference. A link should answer:

```
Where will this take me?
```

Use buttons for actions. A button should answer:

```
What will ShelfStack do?
```

## Use for

| Use case | Example |
| :---- | :---- |
| Navigate to detail | View Item, View Customer, View Receipt |
| Navigate back | Back to Items |
| Inline reference | See purchase order, View audit event |
| External URL | Vendor portal, documentation |
| Breadcrumbs | Items \> Product \> Variant |
| Tab navigation | Overview, Operations, Item Setup |

## Do not use for

| Avoid using Link for | Use instead |
| :---- | :---- |
| Save, post, submit, void, close | Button |
| Opening a modal without navigation | Button with `type="button"` |
| Destructive state change | Button / Alert Dialog |
| Dropdown menu command | `.ss-dropdown-menu__item` |
| Static status | Badge / status badge |
| Filter state label | Filter chip / pill |

## Variants

| Variant | Use | Class |
| :---- | :---- | :---- |
| Default link | Standard text navigation | default `a` or `.ss-link` |
| Quiet link | Lower-emphasis supporting navigation | `.ss-link--quiet` |
| Danger link | Rare; navigates to a risky area, not destructive action | `.ss-link--danger` |
| Button-like link | Navigation that should visually sit in action row | `.ss-btn ss-btn-*` |
| Inline action link | Low-emphasis command-like action | `.ss-btn-link` |

`ss-btn-link` is standalone. Do not combine it with `.ss-btn`.

## CSS

```
app/assets/stylesheets/shelfstack.components.links.css
```

Target classes:

### Implemented

```css
.ss-link
.ss-link--quiet
.ss-link--muted
.ss-link--danger
.ss-link--block
.ss-link--button
.ss-back-link
.ss-skip-link
.ss-btn-link
```

`.ss-link--muted` is an alias of quiet styling. `--block` and `--button` are layout/affordance helpers for narrow cases; prefer documented variants above for new markup.

## Rails partial

Current status:

```
Status: CSS only
```

Planned path:

```
app/views/shared/ui/_link.html.erb
```

Suggested future API:

```
<%= render "shared/ui/link",
      label: "View Item",
      url: items_item_path(product_id: product.id),
      variant: :quiet %>
```

## Accessibility requirements

1. Link text must describe the destination.  
2. Avoid vague labels like “click here.”  
3. External links should indicate they leave ShelfStack when context is not obvious.  
4. Do not use `href="#"` for button behavior.  
5. The active navigation link should use `aria-current="page"` when applicable.  
6. Disabled navigation should not be rendered as an active link.

## Examples

### Detail navigation

```
<%= link_to "View Item", items_item_path(product_id: product.id), class: "ss-link" %>
```

### Quiet back link

```
<%= link_to "Back to Items", items_root_path, class: "ss-link ss-link--quiet" %>
```

### Button-like navigation

```
<%= link_to "Add Item", items_new_add_item_path, class: "ss-btn ss-btn-primary" %>
```

### Disabled nav item

```
<span class="ss-nav__item ss-nav__item--disabled" aria-disabled="true">
  POS
</span>
```

## Migration notes

Do not turn every link into a button. During migration, preserve navigation semantics and only use button styling for links that appear in explicit action rows.  