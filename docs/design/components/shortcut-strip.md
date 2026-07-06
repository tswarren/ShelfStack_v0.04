# Shortcut Strip

| Field | Value |
| ----- | ----- |
| Status | Partial exists / legacy CSS |
| Current partial | `app/views/shared/interaction/_shortcut_strip.html.erb` |
| Current CSS | Legacy `shelfstack.css` (`.ss-shortcut-strip*`) |
| Target CSS home | `shelfstack.components.navigation.css` or future keyboard/interaction CSS |
| Related | Navigation, Keyboard shortcuts, POS command bar, Button |
| Design-system priority | Priority 3 interaction shell |

Shortcut strips show available keyboard shortcuts for dense operational workflows.

---

## Purpose

Use shortcut strips to make keyboard/scanner workflows discoverable.

```text
Shortcut strip = visible command legend
Shortcut key / kbd = inline key hint
Command behavior = implemented separately in JavaScript/controllers
```

The strip documents shortcuts. It does not create shortcut behavior.

---

## Use for

| Use case | Example |
| -------- | ------- |
| POS command hints | Complete sale, suspend, customer lookup |
| Keyboard-heavy workflows | receiving, order line entry, inventory counts |
| Operational help | show common escape/confirm/edit keys |
| Inline training | introduce shortcuts without opening help docs |

---

## Do not use for

| Avoid using Shortcut Strip for | Use instead |
| ------------------------------ | ----------- |
| Full help documentation | Help page / documentation |
| Primary navigation | Navigation |
| Action execution | Button / command handler |
| One inline key hint | `.ss-kbd` or `.ss-shortcut-key` |
| Decorative keyboard labels | Plain text or remove |
| Unimplemented shortcuts | Do not show them |

---

## Current partial

```text
app/views/shared/interaction/_shortcut_strip.html.erb
```

Current locals:

```ruby
items: [{ key:, label: }]
```

The current partial emits:

```css
.ss-shortcut-strip
.ss-shortcut-strip__item
.ss-shortcut-strip__key
.ss-shortcut-strip__label
```

---

## Current CSS status

The partial exists, but modular CSS has not yet been extracted. The current styling is legacy-only.

Do not treat `.ss-shortcut-strip*` as a fully modular CSS contract until it is moved into `shelfstack.components.navigation.css` or a dedicated interaction/keyboard file.

---

## Accessibility requirements

1. Only show shortcuts that are actually implemented.
2. Do not make keyboard shortcuts the only way to perform an action.
3. Shortcut labels must be readable and concise.
4. Use `<kbd>` for key labels.
5. The strip should not steal focus.
6. Avoid showing too many shortcuts at once; emphasize the current workflow scope.

---

## Examples

### Current partial usage

```erb
<%= render "shared/interaction/shortcut_strip",
      items: [
        { key: "F2", label: "Customer" },
        { key: "F4", label: "Tender" },
        { key: "Esc", label: "Cancel" }
      ] %>
```

### Expected rendered shape

```erb
<div class="ss-shortcut-strip" aria-label="Keyboard shortcuts">
  <span class="ss-shortcut-strip__item">
    <kbd class="ss-shortcut-strip__key">F2</kbd>
    <span class="ss-shortcut-strip__label">Customer</span>
  </span>
</div>
```

---

## Migration notes

Extract `.ss-shortcut-strip*` from legacy CSS only after confirming the pattern remains generic outside POS. Keep POS-specific placement, density, and command-bar behavior in `shelfstack.domain.pos.css`.
