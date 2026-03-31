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
- **Release Maps**: visual summaries for release scope and rollout posture

## Current release maps

- [`source/release_0_11_0_capability_map.mmd`](source/release_0_11_0_capability_map.mmd) - `0.11.0` capability coverage and late release-candidate fixes
- [`source/e2e_encrypted_conversation_flow.mmd`](source/e2e_encrypted_conversation_flow.mmd) - E2EE bootstrap, key backup, and message-path lifecycle

## Maintenance
Use `bin/render_diagrams` to regenerate exports from source files. Always edit .mmd source files, never edit exports directly.

See [Diagram Rendering Guide](../developers/development/diagram_rendering.md) for detailed procedures.
