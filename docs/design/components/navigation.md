# Navigation Components

| Field | Value |
| ----- | ----- |
| Status | CSS only / app nav implemented |
| CSS | `app/assets/stylesheets/shelfstack.components.navigation.css` |
| Related partials | `app/views/layouts/_nav.html.erb` for global primary nav |
| Related | App Shell, Links, Dropdown Menu, Disclosure |
| Design-system priority | Priority 2 |

Navigation components help users move between app areas, sections, tabs, and workflow steps.

---

## Purpose

Use navigation components to answer:

```text
Where am I?
Where can I go next?
Which section or step is active?
```

ShelfStack distinguishes global navigation from page/workspace navigation:

```text
Global nav = top-level app areas
Tabs/sidebar/breadcrumbs/steps = local page or workflow navigation
```

---

## Use for

| Pattern | Use case | Example |
| ------- | -------- | ------- |
| Primary nav | Top-level app areas | Dashboard, POS, Items, Inventory |
| Sidebar | Local section navigation | setup groups, report sections |
| Breadcrumbs | Hierarchical location | Items > Product > Variant |
| Tabs | Peer sections inside a page | Overview, Operations, Item Setup |
| Steps | Progress through a workflow | Draft > Review > Post |
| Shortcut key | Visible keyboard hint | `/`, `Esc`, `F2` |

---

## Do not use for

| Avoid using Navigation for | Use instead |
| -------------------------- | ----------- |
| Form submission | Button |
| Menu action list | Dropdown Menu |
| Workflow warning | Alert / Attention Panel |
| Static status | Badge |
| Large command search | Command palette or search pattern when implemented |

---

## Implemented CSS

```css
.ss-nav
.ss-nav__item
.ss-nav__item--active
.ss-nav__item--disabled

.ss-sidebar
.ss-sidebar__section
.ss-sidebar__title
.ss-sidebar__item
.ss-sidebar__item--active

.ss-breadcrumbs
.ss-tabs
.ss-tab-list
.ss-tab
.ss-tab--active

.ss-steps
.ss-step
.ss-step--active
.ss-step--complete
.ss-step--error

.ss-shortcut-key
.ss-kbd
```

Compatibility selectors also exist for old nav markup:

```css
.ss-nav a
.ss-nav a.active
.ss-nav .disabled
.ss-tabs a
.ss-tabs a.active
```

---

## Accessibility requirements

1. Primary nav must have an accessible label, such as `aria-label="Primary navigation"`.
2. Active current-page nav links should use `aria-current="page"`.
3. Disabled nav items should not be rendered as active links; use non-link markup with `aria-disabled="true"`.
4. Tabs should expose active state visually and semantically when JS tab behavior is added.
5. Breadcrumb links should reflect hierarchy, not browser history.
6. Shortcut hints must not be the only way to discover an action.

---

## Examples

### Global nav item

```erb
<%= link_to "Items",
      items_root_path,
      class: shelfstack_nav_item_class(active: current_page?(items_root_path)),
      aria: { current: current_page?(items_root_path) ? "page" : nil } %>
```

### Disabled nav item

```erb
<span class="ss-nav__item ss-nav__item--disabled" aria-disabled="true">
  POS
</span>
```

### Sidebar

```erb
<nav class="ss-sidebar" aria-label="Setup sections">
  <section class="ss-sidebar__section">
    <h2 class="ss-sidebar__title">Store setup</h2>
    <%= link_to "Stores", setup_stores_path, class: "ss-sidebar__item ss-sidebar__item--active" %>
  </section>
</nav>
```

### Tabs

Target contract for new work:

```erb
<nav class="ss-tabs" aria-label="Item sections">
  <div class="ss-tab-list">
    <%= link_to "Overview", item_path(@item), class: "ss-tab ss-tab--active", aria: { current: "page" } %>
    <%= link_to "Operations", item_operations_path(@item), class: "ss-tab" %>
  </div>
</nav>
```

Live Items show still uses compat markup: `.ss-tabs.ss-item-tabs` with plain `active` on links (styled via `.ss-tabs a.active` and legacy `.ss-item-tabs` in `shelfstack.css`). Prefer BEM tab classes when touching that page. Tab panel wrappers may use `.ss-tab-content`; that hook is not styled in modular or legacy CSS today.

### Steps

```erb
<ol class="ss-steps">
  <li class="ss-step ss-step--complete">Draft</li>
  <li class="ss-step ss-step--active">Review</li>
  <li class="ss-step">Post</li>
</ol>
```

### Shortcut key

```erb
<span class="ss-shortcut-key" aria-label="Slash key">/</span>
```

---

## Migration notes

Keep top-level app navigation in `layouts/_nav.html.erb`. Do not create domain-specific duplicate primary nav bars. Use tabs/sidebar/steps for local navigation inside a page or workflow. When migrating legacy tab pages, replace `active` with `.ss-tab--active` and drop unstyled hooks such as `.ss-tab-content` unless panel styling is added.
