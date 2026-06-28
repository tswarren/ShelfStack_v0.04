# Foundation Runbook (Phase 1)

## Purpose

Operational tasks for administrators and developers working with the Phase 1 foundation: authentication, workstation assignment, sessions, and admin recovery.

---

## Seeded Development Login

After first `db:seed` in development, the console prints:

```text
Seeded admin user: admin / ChangeMe###
```

The password is set **only when the admin user is newly created**. Re-running `db:seed` does not change an existing admin password.

Default seeded stores: **001** (America/New_York), **002** (America/Los_Angeles).  
Each store has workstations **Front Register** and **Service Desk**.

---

## First Login (Interactive Users)

After workstation assignment (if required):

1. Log in with username and password.
2. If `force_password_change` is set (seeded `admin` on first seed), change password at `/password/edit` (new password and confirmation must match).
3. **Set a PIN** at `/pin/edit` (required before normal navigation; confirmation must match).
4. Continue to the dashboard.

Password change and PIN setup are enforced on login and on subsequent requests until complete.

---

## Classification Reference Seeds (CSV)

Phase 2 and Phase 3B classification reference data loads from `db/seeds/data/*.csv`.

Validate before seeding:

```bash
./dev/rails-docker bin/rails shelfstack:seeds:validate
```

See [../implementation/csv-seeds.md](../implementation/csv-seeds.md) and [../specifications/seed-data-spec.md](../specifications/seed-data-spec.md).

BISAC (~5k rows) is skipped in test by default. In development:

```bash
SKIP_BISAC_SEED=1 ./dev/rails-docker bin/rails db:seed   # skip BISAC
SEED_BISAC=1 ./dev/rails-docker bin/rails db:seed        # include BISAC
```

---

## Assign a Browser to a Workstation

1. Open `http://localhost:3000/login`.
2. If no workstation is assigned, log in as a user with `workstations.assign_browser` (seeded `admin` has this via Super Administrator).
3. You are redirected to **Assign Workstation** (`/workstation_assignment/new`).
4. Select a workstation and submit **Assign Browser**.

The browser stores a secure cookie (`shelfstack_workstation_token`). The database stores only a digest.

---

## Change or Reset Workstation Assignment

Logout does **not** clear the workstation assignment.

### Option A: Assign a different workstation (logged in)

1. Navigate to `/workstation_assignment/new`.
2. Select a different workstation and submit.

Requires `workstations.assign_browser`.

### Option B: Clear assignment completely

1. Log out (optional).
2. Delete the browser cookie **`shelfstack_workstation_token`** (browser DevTools → Application → Cookies).
3. Reload the login page — it should show **No workstation assigned to this browser.**
4. Assign again using **Assign workstation** after login.

### Option C: Revoke on server (does not clear browser cookie)

Rails console:

```ruby
assignment = WorkstationAssignment.active_records.find(...)
WorkstationAssignmentService.revoke!(assignment: assignment, actor: User.find_by!(username: "admin"))
```

The browser must still clear its cookie or complete a new assignment to pick up a fresh token.

---

## Lock and Unlock Session

- **Lock:** Footer **Lock Session** button (while logged in), or **inactivity timeout** (session locks; does not log you out or require password reset).
- **Unlock:** Enter PIN at `/session/unlock` if the user has a PIN set; otherwise enter **password**.
- **Log out instead:** Available on unlock screen.

Every interactive user must have a PIN. Login and navigation redirect to `/pin/edit` until a PIN is set (with confirmation). Manual change is also available from the header user menu.

## Restore Setup Access After Permission Changes

If Admin menu redirects to **Setup Access Required**:

```bash
docker compose exec web bin/rails db:seed
```

Or Rails console:

```ruby
SuperAdministratorProtection.restore!
```

Log out and back in afterward.

---

## Reset Admin Password (Development)

If the admin password is unknown and re-seed should not be used:

```bash
./dev/rails-docker bin/rails shelfstack:password:reset USERNAME=admin PASSWORD='NewPassword123!' FORCE_PASSWORD_CHANGE=false
```

Omit `PASSWORD` to generate a random temporary password (printed once):

```bash
./dev/rails-docker bin/rails shelfstack:password:reset USERNAME=admin
```

Environment variables:

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `USERNAME` | required | Target user |
| `PASSWORD` | generated | New password |
| `FORCE_PASSWORD_CHANGE` | `true` | Require change on next login |
| `UNLOCK` | `true` | Clear lockout counters |

Rails console alternative:

```ruby
UserPasswordReset.call(username: "admin", password: "NewPassword123!", force_password_change: false)
```

---

## Run Tests

```bash
./dev/rails-docker bin/rails test
```

---

## POS Register Operations (Phase 6 + Phase 10-C)

> **Note:** Phase 10-C (keyboard-first POS workspace) is **Complete** (2026-06-26). See [phase-10c-completion.md](../implementation/phase-10c-completion.md). Integration branch: `phase-10c-pos-keyboard-workspace`.

### Workspace landing

1. Log in with POS access (`pos.access`) on a register workstation.
2. Go to **POS** (`/pos`).
3. If no register session is open, choose **Open register** and enter business date and opening cash.
4. When the register is open and **no active draft** exists, the idle workspace appears with the **command field** focused. No draft is created until you scan an item, run a transaction-starting command, or choose **New Sale** from the **Actions** menu.
5. When an **active draft** exists for this register session + workstation + cashier, `/pos` returns directly to that transaction.

### Command field (home base)

- **Non-slash input** (SKU, ISBN, barcode): catalog lookup only. On match, create/resume the active draft and add the line.
- **Slash commands** route explicit workflows. Type `/help` or `?` for the full list.
- Failed lookup does **not** create a draft. Use `/op` for open ring, `/return` for returns, or `/help`.

Common commands:

| Command | Purpose |
| ------- | ------- |
| `/op [amount]` | Open-ring sale (creates/resumes draft) |
| `/gc [amount]` | Gift card sale/reload line |
| `/return [receipt]` | Return drawer |
| `/pickup` | Customer pickup drawer |
| `/discount` | Transaction discount modal |
| `/ld` | Line discount on previous discountable line |
| `/tender`, `/cash`, `/card`, `/check` | Settlement modal (tender type prefilled when specified) |
| `/giftredeem`, `/storecredit` | Stored value redemption tender |
| `/hold` | Suspend current transaction (clears active draft slot) |
| `/session` | Register session drawer |
| `/held` | Held/suspended transactions on this workstation |
| `/balance` | Stored value balance inquiry |
| `/cashin`, `/cashout` | Miscellaneous cash in/out (not sale tender) |
| `/close` | Close register (blocked while active draft exists) |
| `/reports` | Navigate to reports (confirms when active draft exists) |

Cash **tender** (`/cash 20`) and cash **movements** (`/cashin`, `/cashout`) are separate workflows.

### Sale

1. Scan or type a SKU in the command field, run `/op` for open ring, or choose **New Sale** from the **Actions** menu when idle.
2. Review cart lines and sidebar totals.
3. Open settlement via **Settle**, `/tender`, or a specific tender command (`/cash`, `/card`, etc.).
4. In the tender modal: use `1`–`4` for tender type, enter detail, **Save** (Enter). Saving sufficient tender marks **Ready to complete** but does **not** auto-complete.
5. **Complete** explicitly when ready (register session must be open).
6. After completion, the **completed workspace** appears with full-width document actions. **New Sale** returns to `/pos` (idle workspace). **View Summary** opens the transaction summary; receipt preview offers a single back link to completed sale or summary.

### Return

1. Run `/return` or open **Return** from the mode switcher.
2. **Receipted:** enter receipt number, choose lines and quantities, set disposition.
3. **No-receipt:** scan items into the draft cart. Supervisor authorization is required at **complete**; `pos.returns.no_receipt` no longer blocks adding draft lines.
4. Return lines commit into the active draft when selected. If settlement/tenders exist on the draft, clear them before adding return lines.
5. Add refund tenders (negative totals use negative cash tender amounts for refunds).
6. Complete the return transaction.

### Suspend, hold, and resume

- **Suspend** (`/hold` or sidebar action) saves the draft to the workstation held list and clears the active draft slot.
- **Held sales** appear in the session drawer (`/held` or **Held sales (N)** on idle workspace). They are **never auto-resumed**.
- **Resume** returns a held transaction to editable draft. Other cashiers need `pos.transactions.resume.other_cashier`.

### Void

Completed transactions can be voided from the transaction detail screen (`pos.transactions.void`). Void reverses inventory via `pos_void` posting.

### Close register

1. Complete, cancel, or hold any active draft first (`/close` is blocked while a draft is active).
2. Run `/close` or open the register session page.
3. Review session activity (cash movements and completed transactions). Held transactions on the workstation are listed in `/session` / `/held`.
4. Expected closing cash is precomputed from opening cash, paid in/out, and net cash tenders.
5. Enter counted cash and **Close register**.
6. **Force close** requires supervisor authorization (`pos.register_sessions.force_close` plus manager PIN grant).

### Reports

- **Drawer report:** session totals and recent sessions (`/pos/reports/drawer`).
- **Sales / returns:** list views with CSV export (`pos.reports.export`).
- From an active draft, `/reports` confirms before navigating away; the draft remains on the server if you cancel.

### Default POS roles (seeded)

| Role key | Purpose |
| -------- | ------- |
| `pos_cashier` | Standard sale, receipted returns, close register |
| `pos_lead` | Open-ring, no-receipt returns, resume other cashier |
| `pos_manager` | Full POS permissions including authorizations and export |

Assign roles in Setup → Users. Managers granting authorizations need `pos.authorizations.grant` and a PIN. Reserved-stock override additionally requires `pos.sell_reserved_stock_override`.

### Customer pickup (Phase 7A)

- Run `/pickup` or use the **Pickup** mode switcher (replaces legacy `?mode=pickup` as primary UX).
- Search by customer name or request number; select a ready reservation to add a pickup line.
- Scanning a SKU with ready reservations offers **Pickup for [Customer]** choice cards.
- Selling into reserved stock without a pickup line requires manager override (`sell_reserved_stock_override`).

### Background jobs (Solid Queue)

Hold expiry runs nightly via `InventoryReservations::ExpireJob` (Solid Queue recurring task). Manual fallback:

```bash
rails shelfstack:inventory:expire_reservations
```

Run the job worker with `bin/jobs` or set `SOLID_QUEUE_IN_PUMA=1` when starting Puma.

---

## ISBNdb API Key (Phase 6.5)

External catalog lookup uses ISBNdb when local ISBN identifiers do not match.

Configure the API key using one of:

1. Rails credentials: `rails credentials:edit` → `isbndb: api_key: YOUR_KEY`
2. Environment variable: `ISBNDB_API_KEY=YOUR_KEY`

The key is **not** stored in `external_data_sources.configuration_json`.

Run a manual health check from **Setup → External Data Sources** (requires `items.external_lookup.configure`).

Direct URL: `/setup/external_data_sources`

---

## Related Documents

- [../implementation/phase-1-completion.md](../implementation/phase-1-completion.md)
- [../implementation/csv-seeds.md](../implementation/csv-seeds.md)
- [../../DOCKER.md](../../DOCKER.md)
