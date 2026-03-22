---
applyTo: "**/*.js,**/*.erb,**/*.html.erb"
---
# Hotwire (Turbo + Stimulus) Guidelines

## Core Ideas
- Turbo for navigation/partial updates; Stimulus for behavior.
- Progressive enhancement first; degrade gracefully.

## Turbo Drive/Frames/Streams
- Use Frames to isolate sections, Streams for live updates (append, replace, morph, etc.).
- Use `data-turbo-permanent` for elements that must persist across visits.
- Prefer morphing refresh (`<meta name="turbo-refresh-method" content="morph">`).

## Stimulus
- One responsibility per controller; name semantically.
- Use `values`, `targets`, `classes` APIs; avoid manual DOM queries.
- Attach behavior via `data-action` and `data-controller`, not inline JS.

## Integration Tips
- Listen for Turbo lifecycle events in controllers (`turbo:load`, `turbo:before-frame-render`).
- Cleanup in `disconnect` to avoid duplicates on Turbo nav.

## Accessibility
- Keep dynamic focus management in mind.
- Announce content updates to assistive tech (ARIA live regions where needed).
