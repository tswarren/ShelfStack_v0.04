# Phase 10-A — Interaction Infrastructure

**Status:** Complete

**Branch:** `phase-10a-interaction-infrastructure`

**Roadmap:** [phase-10a-interaction-infrastructure.md](../roadmap/phase-10a-interaction-infrastructure.md)

**Spec:** [phase-10a-interaction-infrastructure-spec.md](../specifications/phase-10a-interaction-infrastructure-spec.md)

**Test plan:** [phase-10a-test-plan.md](../specifications/phase-10a-test-plan.md)

---

## Deliverables

### Shared modal and drawer shells

* CSS: `ss-modal*`, `ss-drawer*` in `app/assets/stylesheets/shelfstack.css`
* Partials: `app/views/shared/interaction/_modal.html.erb`, `_drawer.html.erb`
* Stimulus: `modal_controller.js`, `drawer_controller.js`, `focus_controller.js`
* Utilities: `focus_trap.js`, `focus_restore.js`, `overlay_lock.js`, `overlay_shell.js`
* Stack-aware body lock for `body.ss-modal-open` and `body.ss-drawer-open`
* Safe-close contract: escape, backdrop, dirty guard
* ARIA: `role="dialog"`, `aria-modal`, `aria-labelledby`, close button labels

### Toast, keyboard scope, expanded row chrome

* `_toast_region.html.erb`, `_toast.html.erb` — server-rendered append; Stimulus lifecycle only
* `toast_controller.js`, `keyboard_scope_controller.js`
* `_expanded_row.html.erb`, `_shortcut_strip.html.erb`
* Toast region in `application` and `pos` layouts

### Pilot migration

* Item customer demand drawer uses shared `ss-drawer` shell (`id="item-demand-drawer"`)
* `item_customer_demand_drawer_controller.js` slimmed to content/state (`prepareOpen` only)
* Operations tab openers use `drawer#open` with `data-drawer-target-id-param`

### Tests

* Integration: interaction shell markup, layout toast region, demand drawer markup, existing POST flows
* System: modal/drawer shell fixture (`/test/interaction_shell`), pilot drawer open/focus restore
* Test-only route: `GET /test/interaction_shell` (test env)

### Documentation

* [phase-10a-test-plan.md](../specifications/phase-10a-test-plan.md)
* Updated [ui-components.md](../specifications/ui-components.md), [modal-and-drawer-patterns.md](../specifications/modal-and-drawer-patterns.md), [keyboard-and-focus.md](../specifications/keyboard-and-focus.md)

---

## Verification

```bash
./dev/rails-docker bin/rails test test/integration/interaction_infrastructure_integration_test.rb
./dev/rails-docker bin/rails test test/integration/items_customer_demand_drawer_integration_test.rb
./dev/rails-docker bin/rails test test/system/interaction/modal_drawer_shell_test.rb   # requires Chrome in container
./dev/rails-docker bin/rails test test/system/items/customer_demand_drawer_test.rb
```

Manual: Items → product → Operations → demand action → drawer open/close/Esc/focus restore.

---

## Known gaps / deferred

* POS settlement modal still uses `ss-pos-modal*` and `pos_settlement_panel_controller` (**10-C**)
* Buyback line drawer still ad-hoc (**10-D**)
* No shared `lookup_controller` / `line_entry_controller` (documented contract only; domain controllers remain authoritative)

## System test runtime

* Docker: rebuild `web` after Dockerfile changes (`docker compose build web`); run system tests with `docker compose run --rm -e RAILS_ENV=test web bin/rails test test/system` (not the stale `exec` container without Chromium)
* CI: GitHub Actions installs `chromium-browser` and sets `CHROME_BIN`

---

## 10-B unblock

Phase 10-B may proceed: shared drawer and modal shells, focus restoration, and stack-aware body lock are available.
