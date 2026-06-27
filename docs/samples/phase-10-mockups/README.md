# Phase 10 UX Mockups

Static HTML mockups for Phase 10 planning and implementation. **Inspiration only** — not drop-in assets.

## How to view

Open any `.html` file in a browser (double-click or `open docs/samples/phase-10-mockups/shelfstack_pos_mockups.html`).

## Files

| File | Sub-phase | Screens |
| ---- | --------- | ------- |
| [shelfstack_ux_direction_visual.html](shelfstack_ux_direction_visual.html) | 10-A, parent | UX principles, view contracts, item wireframe, message/focus rules |
| [shelfstack_items_mockups.html](shelfstack_items_mockups.html) | 10-B | Overview cockpit, operations + drawer, setup modal |
| [shelfstack_pos_mockups.html](shelfstack_pos_mockups.html) | 10-C | Register workspace, expanded-row line edit, settlement modal |

## Roadmap documents

```text
docs/roadmap/Phase-x10-comprehensive-ux-expansion.md
docs/roadmap/phase-10a-interaction-infrastructure.md
docs/roadmap/phase-10b-item-cockpit-completion.md
docs/roadmap/phase-10c-pos-keyboard-workspace.md
```

## Implementation rule

Map visual patterns to existing `ss-*` classes in `app/assets/stylesheets/shelfstack.css`. Do not copy mockup CSS or variables into production.

## Planned divergences

Mockups show ideas that remain **out of scope or deferred** unless explicitly approved:

| Mockup element | Plan decision |
| -------------- | ------------- |
| Items header `⌘K Commands` + global command search | Defer item command language |
| Items operations command bar (`/focus`, `/tbo`, `/vendor`) | 10-B non-goal; inspiration only |
| Items sidebar "Command ideas" block | Deferred |
| Tab label renames in items mock | Optional polish; preserve URLs/anchors from drill-down contract |
| POS mock topbar grid | Visual target; evolve existing POS partials |
| POS landing centered on **New sale** | 10-C uses **idle workspace**; command field is home base; New sale is secondary mouse path |
| Implicit open-ring from bare amounts or receipt patterns | Removed in 10-C; use `/op` and `/return` explicitly |
| `/gc` auto-posting a line when amount provided | 10-C opens modal with prefilled amount; line not auto-posted |
| F-key legend as completion requirement | Out of scope for 10-C; command aliases and visible controls required |
| Mockup-local CSS/colors | Map to ShelfStack design tokens |
