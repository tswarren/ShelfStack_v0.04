# Phase 10-A Test Plan

**Spec:** [phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md)

---

## Test layers

| Behavior | Layer |
| -------- | ----- |
| Shared partial markup, layout targets, server POST flows, turbo_stream append | **Integration** |
| Focus trap, Esc/backdrop close, focus restore, body-lock stack, toast lifecycle | **System** (JS-capable) |
| Pilot drawer open/close/focus/Esc/dirty guard | **System** |
| Pilot demand form POSTs and turbo_stream error toast | **Integration** |

System tests require Chromium + Chromedriver. In Docker, use a rebuilt `web` image (`docker compose build web`) and run with `docker compose run --rm -e RAILS_ENV=test web bin/rails test test/system`.

---

## Modal shell

**Fixture:** `GET /test/interaction_shell` (test env only)

- Drawer/modal hidden by default
- Open via `data-drawer-target-id-param` / `data-modal-target-id-param`
- Focus moves to first meaningful control
- Esc closes when form is clean; dirty guard blocks close when form changed
- Backdrop closes modal when `close_on_backdrop` enabled
- Focus restores to opener on close
- Nested modal over open drawer: modal stacks above drawer; closing modal keeps `body.ss-drawer-open`

**Files:** `test/system/interaction/modal_drawer_shell_test.rb`

---

## Drawer shell

Same fixture as modal. See modal shell tests plus drawer-specific backdrop default (`close_on_backdrop: true`).

---

## Toast

- `#toast_region` present in `application` and `pos` layouts
- Server/Turbo append `_toast.html.erb` partials via `Interaction::ToastStreamable#append_toast_stream`
- Stimulus handles dismiss and auto-dismiss only; toast does not take focus on append
- Production path: item customer demand validation errors (`format.turbo_stream`)

**Files:**

- `test/system/interaction/toast_lifecycle_test.rb`
- `test/integration/interaction_infrastructure_integration_test.rb`
- `test/integration/items_customer_demand_drawer_integration_test.rb`

---

## Turbo behind drawer

- Fixture button inside open drawer POSTs turbo_stream update
- Background `turbo_frame` updates while drawer remains open

**Files:** `test/system/interaction/turbo_behind_drawer_test.rb`

---

## Keyboard scope

- `keyboard_scope_controller` ignores keydown from focused inputs/textareas by default
- Dispatches `keyboard-scope:keydown` for host-level bindings when active

**Files:** `test/system/interaction/keyboard_scope_test.rb`

---

## Pilot: item customer demand drawer

**Integration**

- Operations tab renders `id="item-demand-drawer"` and shared `ss-drawer` classes
- Existing hold / special order / notify POST flows remain green
- Special order validation appends error toast via turbo_stream

**System**

- Open from operations demand button; variant summary visible
- Close restores focus to opener
- Esc closes when clean; dirty guard blocks Esc

**Files:**

- `test/integration/items_customer_demand_drawer_integration_test.rb`
- `test/system/items/customer_demand_drawer_test.rb`

---

## Regression

- Buyback line drawer unchanged (10-D migration)
- POS settlement modal unchanged (10-C migration)

---

## Manual verification

1. Items → product → Operations → Hold for customer → drawer opens, Esc closes, focus returns
2. Change a field → Esc does not close until reset or explicit close
3. Submit invalid special order (walk-in only) → error toast appends; page flash unchanged for HTML submits
