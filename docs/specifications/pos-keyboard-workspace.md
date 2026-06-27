# POS Keyboard Workspace

**Status:** Planned (Phase 10-C)

Detailed POS UX supplement. **Authoritative behavior:** [phase-10c-pos-keyboard-workspace-spec.md](phase-10c-pos-keyboard-workspace-spec.md) and [phase-10c-pos-keyboard-workspace.md](../roadmap/phase-10c-pos-keyboard-workspace.md).

## Mockup reference

[shelfstack_pos_mockups.html](../samples/phase-10-mockups/shelfstack_pos_mockups.html)

| Screen | Content |
| ------ | ------- |
| Register workspace | Context bar, command field, cart, readiness, sidebar, help strip |
| Item modification | Expanded-row line edit |
| Settlement modal | Tenders, change due, complete action |

## View contract

First focus: command field. Primary action when transaction active: settle/complete. See [view-contracts.md](view-contracts.md).

## Landing

When register session is open:

* **No active draft** (session + workstation + cashier): **idle workspace** — command field focused; no silent auto-create
* **One active draft**: return to active draft (including empty)
* **Multiple draft candidates**: conflict picker
* **Held/suspended**: access only; no auto-resume

**New sale** remains a mouse-accessible explicit start path; command field is home base.

## Commands

Two-lane parser: slash commands → registry; non-slash → scan/catalog lookup only. No implicit open-ring, receipt, or amount guessing.

| Area | Commands |
| ---- | -------- |
| Line discount | `/linediscount`, `/ld`, legacy `/d` |
| Transaction discount | `/discount`, `/di`, legacy `/dt` |
| Gift card sale | `/giftcard`, `/gc` — modal-first; amount prefills modal, does not auto-post |
| Gift card redeem | `/giftredeem`, `/gr` |
| Cash tender vs drawer | `/cash` (tender) vs `/cashin` / `/cashout` (drawer movement) |
| Cash drop | `/cashdrop` — planned/disabled in 10-C |
| Return / pickup | `/return`, `/pickup` — drawer workflows; draft on commit |
| Close register | `/close`, `/cl` — blocked while active draft exists |

Transactionless commands (`/balance`, `/session`, `/help`, etc.) work while an active draft exists; blocked only by modal/dirty state.

Function keys are **out of scope** for 10-C completion. Command aliases and visible controls are required.

## Reports

`/reports` and utility menu: confirm when active draft exists; navigate same tab to `/reports` on confirm.

## Depends on

[phase-10a-interaction-infrastructure-spec.md](phase-10a-interaction-infrastructure-spec.md) for modal, drawer, expanded row, focus helpers.
