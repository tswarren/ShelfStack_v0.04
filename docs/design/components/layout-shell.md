# Layout Shell

| Field | Value |
| ----- | ----- |
| Status | Implemented |
| CSS | `app/assets/stylesheets/shelfstack.layout.css` |
| Partials | `app/views/layouts/_header.html.erb`, `_nav.html.erb`, `_footer.html.erb` |
| Layouts | `app/views/layouts/application.html.erb`, `app/views/layouts/pos.html.erb` |
| Related docs | `docs/design/app-shell-and-pos-shell.md`, `docs/design/layout-width-model.md` |
| Related | Page Header, Navigation, Dropdown Menu, Flash, Appearance Switcher |
| Design-system priority | Priority 2 |

The layout shell is ShelfStack’s global page frame: body contract, header, search, navigation, main canvas, footer, and shell-level feedback regions.

---

## Purpose

The layout shell gives every app area a consistent frame:

```text
Where am I?
Which store/workstation am I using?
What top-level area am I in?
Who am I signed in as?
Where is global search?
How do I lock/logout/change view mode?
```

POS pages should use the same global shell plus POS workspace chrome inside page content.

---

## Use for

| Region | Purpose |
| ------ | ------- |
| Body attributes | Typeface, density, color mode, app/POS body classes |
| Header | Logo, store/workstation context, global search, user menu |
| Nav | Top-level workspace navigation |
| Main | Page content canvas |
| Flash region | Page-level result messages inside `<main>` |
| Toast region | Transient interaction feedback after `</main>` |
| Footer | Version, copyright, Lock Session |
| POS main class | Wider POS workspace canvas |

---

## Do not use layout shell for

| Avoid | Use instead |
| ----- | ----------- |
| POS transaction/session state | POS workspace header |
| Page-specific actions | Page Header / page actions |
| Workflow warnings | Alert / Attention Panel |
| Modal/drawer content | Dialog / Drawer |
| Page title | Page Header |
| Domain-specific navigation | Sidebar / tabs / workflow nav |

Do not create alternate top-level headers/navs for domain areas.

---

## Implemented CSS

### Shell/body/app chrome

```css
.ss-app-shell
.ss-app-shell--focused
.ss-app-chrome
.ss-app-chrome--sticky
```

### Header

```css
.ss-header
.ss-header__left
.ss-header__brand
.ss-header__logo
.ss-header__context
.ss-header__search
.ss-header__actions
.ss-header-actions
.ss-header-logo
.ss-header-context
.ss-user-menu
```

### Search form in header

```css
.ss-search-form
```

### Main canvas

```css
.ss-main
.ss-main--readable
.ss-main--wide
.ss-pos-main
.ss-main--items
.ss-main--full
.ss-main--narrow
.ss-readable
.ss-text-measure
```

### Footer

```css
.ss-footer
.ss-footer__version
.ss-footer__copyright
.ss-footer__actions
```

### Page/section shell helpers

```css
.ss-page-header
.ss-page-header__actions
.ss-page-actions
.ss-section-actions
.ss-section-header
```

---

## Width model

Use the main canvas class that matches the workflow:

| Class | Purpose |
| ----- | ------- |
| `.ss-main` | Default standard app canvas |
| `.ss-main--readable` | Text-heavy pages and readable reports |
| `.ss-main--narrow` | Focused forms/session pages |
| `.ss-main--items` | Item detail/index workspace canvas |
| `.ss-main--wide` | Dense operational workspaces |
| `.ss-pos-main` | POS workspace width alias/extension |
| `.ss-main--full` | Rare no-max-width pages |

Page canvas width is not the same as text measure. Use `.ss-readable` or `.ss-text-measure` inside wide pages when text should not stretch.

---

## Accessibility requirements

1. Application layout should include a skip link to `#main_content`.
2. Header should use banner semantics.
3. Primary navigation should have an accessible label.
4. Active nav links should use `aria-current="page"`.
5. Disabled nav items should use `aria-disabled="true"` and should not be links.
6. Main content must use `main#main_content`.
7. The user menu must be keyboard reachable.
8. Flash messages must be announced without blocking the page.
9. App shell should remain consistent between POS and non-POS areas.

---

## Examples

### Main landmark

```erb
<main id="main_content" class="<%= shelfstack_class_names("ss-main", content_for(:main_class)) %>">
  <%= render "shared/feedback/flash_region" %>
  <%= yield %>
</main>
<%= render "shared/interaction/toast_region" %>
```

`application.html.erb` renders the toast region after `</main>` so transient messages do not compete with page content inside the main landmark.

### POS page width

```erb
<% content_for :main_class, "ss-main--wide ss-pos-main" %>
```

### Item workspace width

```erb
<% content_for :main_class, "ss-main--items" %>
```

### Footer layout

```erb
<footer class="ss-footer">
  <div class="ss-footer__version">ShelfStack v0.04.12</div>
  <div class="ss-footer__copyright">© <%= Time.current.year %> ShelfStack</div>
  <div class="ss-footer__actions">
    <%= button_to "Lock Session",
          session_lock_path,
          method: :post,
          class: "ss-btn ss-btn-ghost ss-btn--small",
          form: { class: "ss-inline-form" } %>
  </div>
</footer>
```

---

## Responsive behavior

The header uses a three-area grid on wider screens:

```text
left | search | actions
```

Below the medium breakpoint, search moves to a second row:

```text
left | actions
search search
```

The footer collapses from three columns to one centered column on narrow screens.

---

## Migration notes

Keep global chrome centralized in the layout partials. POS may have a workspace header, but it must sit below the shared global shell. Future focused/register mode should be an explicit shell variant, not a duplicate header/nav implementation.
