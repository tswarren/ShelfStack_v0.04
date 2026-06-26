# POS Keyboard Workspace

**Status:** Planned (Phase 10-C)

Detailed POS UX specification. Supplements [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md).

## Mockup reference

[shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

| Screen | Content |
| ------ | ------- |
| Register workspace | Context bar, command field, cart, readiness, sidebar, shortcut strip |
| Item modification | Expanded-row line edit |
| Settlement modal | Tenders, change due, complete action |

## View contract

First focus: scan/command field. Primary action: settle/complete. See [view-contracts.md](view-contracts.md).

## Landing

When register session open: route to transaction workspace per `Pos::LandingRouter` rules in roadmap doc.

## Commands and function keys

Full command set and F2–F10 mapping in [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md).

## Reports

`/reports` and utility menu: confirm when in-progress draft exists; navigate same tab to `/reports` on confirm.

## Depends on

[phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md) for modal, drawer, expanded row, focus helpers.
