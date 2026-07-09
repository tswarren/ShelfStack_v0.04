# CSV classification seeds

Phase 2 and Phase 3B classification reference data loads from `db/seeds/data/*.csv` via `Seeds::CsvClassificationImporter`.

## Validate

```bash
./dev/rails-docker rails shelfstack:seeds:validate
```

## Seed

```bash
./dev/rails-docker rails db:seed
```

BISAC (~5k rows) is skipped in test by default. To include BISAC when seeding:

```bash
SEED_BISAC=1 ./dev/rails-docker rails db:seed
```

To skip BISAC in development:

```bash
SKIP_BISAC_SEED=1 ./dev/rails-docker rails db:seed
```

See [seed-data-spec.md](../specifications/seed-data-spec.md) for column definitions.

## Genre scheme trees (v0.04-16)

Four hierarchical category trees live in `db/seeds/data/` for product entry:

```text
music_genres.csv
video_genres.csv
video_game_genres.csv
sideline_genres.csv
```

`rails shelfstack:seeds:validate` checks tree integrity (duplicate keys, orphan `parent_node_key` refs). Import into `CategoryScheme` records is wired in v0.04-16 (not part of legacy Phase 2/3B `db:seed` until that milestone lands).
