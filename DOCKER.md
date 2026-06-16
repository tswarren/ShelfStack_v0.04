# Docker Development

ShelfStack runs Ruby, Rails, Bundler, and PostgreSQL inside Docker Compose.

---

## Prerequisites

* Docker Desktop or Docker Engine with Compose v2
* Git

---

## Services

| Service | Image / build        | Purpose                          |
| ------- | -------------------- | -------------------------------- |
| `web`   | `Dockerfile.dev`     | Rails application (port 3000)    |
| `db`    | `postgres:17-bookworm` | PostgreSQL database (port 5432) |

Named volumes:

| Volume          | Purpose                              |
| --------------- | ------------------------------------ |
| `bundle`        | Installed gems (persists across runs) |
| `postgres-data` | PostgreSQL data files                |

The app container mounts the project directory at `/app`, so local file edits are reflected immediately.

---

## First-Time Setup

```bash
git clone <repository-url>
cd ShelfStack_v0.03
docker compose up --build
```

In another terminal:

```bash
./dev/rails-docker bin/rails db:create db:migrate db:seed
```

Then open:

```text
http://localhost:3000
```

### Seeded admin user

On **first** seed in development, the terminal prints:

```text
Seeded admin user: admin / ChangeMe###
```

- **Username:** `admin`
- **Password:** shown once when the admin user is created; re-running `db:seed` does **not** change an existing admin password.

After login, assign the browser to a workstation if prompted. See [docs/operations/foundation-runbook.md](docs/operations/foundation-runbook.md).

### Restore setup access

If Admin access is lost after permission changes:

```bash
./dev/rails-docker bin/rails db:seed
```

Or in Rails console: `SuperAdministratorProtection.restore!`

Reset a user password from the CLI:

```bash
./dev/rails-docker bin/rails shelfstack:password:reset USERNAME=admin
```

See [docs/operations/foundation-runbook.md](docs/operations/foundation-runbook.md) for options.

---

## Daily Development

Start the stack:

```bash
docker compose up
```

Stop the stack:

```bash
docker compose down
```

Rebuild after Gemfile changes:

```bash
docker compose build web
docker compose up
```

---

## Running Commands in the Container

Use the `dev/rails-docker` helper to run commands in the `web` service. It uses `docker compose exec` when the container is running, or `docker compose run --rm` otherwise.

```bash
./dev/rails-docker bin/rails console
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails test
./dev/rails-docker bin/rubocop
./dev/rails-docker bundle install
```

You can also call Compose directly:

```bash
docker compose exec web bin/rails console
docker compose run --rm web bin/rails test
```

Optional: add a shell alias for convenience:

```bash
alias rails-docker='./dev/rails-docker'
```

---

## Database

Default development connection (set in `compose.yml`):

| Setting  | Value                    |
| -------- | ------------------------ |
| Host     | `db` (inside Compose)    |
| Port     | `5432`                   |
| User     | `postgres`               |
| Password | `postgres`               |
| Database | `shelfstack_development` |

From the host machine, PostgreSQL is exposed on `localhost:5432` with the same credentials.

Common database commands:

```bash
./dev/rails-docker bin/rails db:create
./dev/rails-docker bin/rails db:migrate
./dev/rails-docker bin/rails db:seed
./dev/rails-docker bin/rails db:reset
./dev/rails-docker bin/rails db:test:prepare
```

---

## Resetting the Environment

Stop containers:

```bash
docker compose down
```

Stop containers and delete volumes (removes the local database and gem cache volume):

```bash
docker compose down -v
```

Warning: `docker compose down -v` deletes the local PostgreSQL database volume. You will need to run `db:create`, `db:migrate`, and `db:seed` again.

---

## Environment Details

| Area              | Value                          |
| ----------------- | ------------------------------ |
| Ruby              | 3.4 (`ruby:3.4-bookworm`)      |
| Rails             | 8.1                            |
| PostgreSQL        | 17 (`postgres:17-bookworm`)    |
| App user in image | `rails` (UID 1000)             |
| Gem path          | `/bundle` (named volume)       |

On Apple Silicon, the default images run natively on ARM. Avoid forcing `linux/amd64` unless required.
