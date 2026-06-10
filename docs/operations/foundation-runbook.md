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

- **Lock:** Footer **Lock Session** button (while logged in).
- **Unlock:** Enter PIN at `/session/unlock`.
- **Log out instead:** Available on unlock screen.

Users must set a PIN at `/pin/edit` (header user menu → **Set PIN**) before unlock works.

---

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

```ruby
admin = User.find_by!(username: "admin")
admin.password = "NewPassword123!"
admin.password_confirmation = "NewPassword123!"
admin.force_password_change = false
admin.save!
```

---

## Run Tests

```bash
./dev/rails-docker bin/rails test
```

---

## Related Documents

- [../implementation/phase-1-completion.md](../implementation/phase-1-completion.md)
- [../../DOCKER.md](../../DOCKER.md)
