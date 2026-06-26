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

When register session is open:

* **One draft** (cashier + workstation): redirect to transaction edit
* **Multiple drafts**: compact picker
* **No drafts**: compact workspace with explicit **New sale** — **no silent auto-create**

After the user starts a sale, transaction edit opens with command field focused.

Authoritative detail: [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md).

## Commands and function keys

Command set and registry: [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md).

Function keys F2–F10 are **enhancement-tier**; required keyboard behavior does not depend on F-key reliability.

## Reports

`/reports` and utility menu: confirm when in-progress draft exists; navigate same tab to `/reports` on confirm.

## Depends on

[phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md) for modal, drawer, expanded row, focus helpers.
