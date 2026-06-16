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
