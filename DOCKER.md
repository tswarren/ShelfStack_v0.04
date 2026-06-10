## Docker Development

This project runs Ruby, Rails, Bundler, and PostgreSQL inside Docker.

### Start the app

```bash
docker compose up
```

### Load local command shortcuts

```shell
source dev/aliases.zsh
```

### Common commands

```shell
rails db:create
rails db:migrate
rails console
rubocop
bundle install
```

### Reset containers

```shell
docker compose down
```

### Reset containers and volumes

```shell
docker compose down -v
```

Warning: `docker compose down -v` deletes the local PostgreSQL database volume.

--- 

# 17. My recommended defaults

For your use case, I would use:

| Area | Recommendation |
|---|---|
| Ruby | `ruby:3.4-bookworm` |
| Database | `postgres:17-bookworm` |
| Rails execution | `docker compose run/exec web ...` |
| Local shortcuts | `dev/aliases.zsh` shell functions |
| VSCode | Installed locally, editing mounted project files |
| Gems | Docker named volume: `bundle:/bundle` |
| DB data | Docker named volume: `postgres-data:/var/lib/postgresql/data` |
| Mac ARM | Avoid forcing `linux/amd64` unless absolutely necessary |

This gives you a clean Docker-based Rails development environment while still letting you type familiar commands like:

```bash
rails db:migrate
rails console
rubocop
bundle install
```