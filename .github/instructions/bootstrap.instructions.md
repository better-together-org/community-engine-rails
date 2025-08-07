---
applyTo: "**/*.erb,**/*.scss,**/*.css,**/*.html.erb"
---
# Bootstrap 5.3 & Font Awesome 6 Guidelines

## Styling
- Use semantic HTML first; classes only enhance.
- Respect prefers-reduced-motion, color contrast (AAA where possible).
- Prefer Bootstrap utility classes (spacing, flex, grid) before custom CSS.

## Components
- Build reusable partials/partials + Stimulus for interactive widgets.
- Do not inline styles; keep SCSS organized by feature or component.

## Icons
- Use `<i class="fa-solid fa-...">` or `<span class="fa-...">` with proper `aria-hidden="true"` and visually hidden text if icon conveys meaning.

## External Link Pattern
- For `.trix-content` links not matching internal/mailto/tel/pdf, append FA external-link icon via CSS or helper.

## Theming
- Override Bootstrap variables in host app theme SCSS; avoid duplicating entire Bootstrap build.
