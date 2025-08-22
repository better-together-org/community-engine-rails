# Visual Documentation

System diagrams, process flows, and visual aids for the Better Together Community Engine.

## Directory Structure
- `source/` - Mermaid (.mmd) source files (authoritative versions)
- `exports/png/` - PNG exports for documentation embedding
- `exports/svg/` - SVG exports for web use and scalability

## Diagram Categories
- **System Flows**: Process workflows and data flows
- **Architecture**: System relationships and component interactions
- **User Journeys**: Stakeholder workflows and interactions

## Maintenance
Use `bin/render_diagrams` to regenerate exports from source files. Always edit .mmd source files, never edit exports directly.

See [Diagram Maintenance](maintenance.md) for detailed procedures.
