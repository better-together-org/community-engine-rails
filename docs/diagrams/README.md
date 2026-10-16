# Diagram exports

The subsystem diagram package is generated from live Rails reflections so the exported ERDs and layer maps stay aligned with the current codebase rather than a hand-maintained snapshot.

## Regenerate the whole-schema diagrams

```bash
bin/export_schema_diagrams            # DBML + full-schema ERD + subsystem ERDs
bin/export_schema_diagrams --skip-subsystems   # no database needed
```

Run it after any migration or change to `spec/dummy/db/schema.rb`. It:

1. writes `db/community-engine-db.dbml` from `spec/dummy/db/schema.rb` (`scripts/export_schema_dbml.rb`, no database)
2. renders `docs/diagrams/exports/svg/ce_full_schema_erd.svg` and `docs/diagrams/exports/png/ce_full_schema_erd.png` from the DBML (`scripts/render_schema_diagram.cjs`: Graphviz neato layout, PNG rasterized by headless Chrome and capped at 16,000 px on its long side, so use the SVG to zoom)
3. runs the subsystem export below

The `Schema Diagrams` workflow fails a pull request that changes `db/migrate/**` or `spec/dummy/db/schema.rb` while these files are stale. Set `CHROME_PATH` if Chrome is not in a standard location.

## Regenerate subsystem inventories and diagrams

```bash
bin/export_subsystem_diagrams
```

That command:

1. runs `scripts/export_subsystem_diagrams.rb` through the CE container harness
2. refreshes the generated Mermaid sources in `docs/diagrams/source/`
3. renders PNG/SVG exports through `bin/render_diagrams`

## Generated reference exports

- `docs/diagrams/reference/ce_subsystem_inventory.md`
- `docs/diagrams/reference/ce_subsystem_inventory.json`
- `docs/diagrams/reference/ce_concern_capability_assessment.md`

## Generated Mermaid sources

Each subsystem now has:

- `*_schema_erd.mmd` for database tables, direct foreign-key associations, and external subsystem references
- `*_rails_layers.mmd` for controller/model layering with compact concern and weak-link summaries on each live class node

Cross-cutting exports:

- `ce_subsystem_interaction_map.mmd`
- `ce_polymorphic_association_map.mmd` for subsystem-level weak-reference summaries grouped by live model family
