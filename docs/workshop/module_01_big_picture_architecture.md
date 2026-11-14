# Module 01 — Big Picture Architecture

This module introduces the platform’s high‑level architecture and provides jumping‑off points into domain systems.

## Objectives
- Understand major components: web app, background jobs, Action Cable, search (ES), DB/PostGIS, storage, email
- Learn high‑level data flows and where privacy/authorization gates apply
- Know where to find deep‑dives and diagrams

## Diagram: Platform Technical Architecture

```mermaid
%% See editable source at: ../diagrams/source/platform_technical_architecture.mmd
```

**Diagram Files:**
- Source: ../diagrams/source/platform_technical_architecture.mmd
- PNG: ../diagrams/exports/png/platform_technical_architecture.png
- SVG: ../diagrams/exports/svg/platform_technical_architecture.svg

## Jumping‑Off Points
- Systems overview: ../developers/systems/
- Roles & permissions: ../shared/roles_and_permissions.md
- Production guides: ../production/
- Notifications: ../developers/systems/notifications_system.md
- Events & Invitations: ../developers/systems/event_invitations_and_attendance.md

## Discussion Prompts
- Where do tokens (platform vs event) alter access paths?
- What failure modes impact jobs vs requests (and how to monitor)?
- What belongs in request specs vs background job specs?

