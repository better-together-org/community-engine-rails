# Diagram exports

The subsystem diagram package is generated from live Rails reflections so the exported ERDs and layer maps stay aligned with the current codebase rather than a hand-maintained snapshot.

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
