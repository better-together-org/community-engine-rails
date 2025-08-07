---
applyTo: "**/*.erb,**/*.rb,**/*.js,**/*.scss"
---
# Accessibility (WCAG AA/AAA) Checklist

- Semantic HTML, correct landmarks (`<main>`, `<nav>`, `<aside>`).
- Labels for every form input; visible or `aria-label`.
- Keyboard navigable: no keyboard traps; visible focus states.
- Announce dynamic content (ARIA live regions / role="status").
- Color contrast ≥ 4.5:1 (text) / 3:1 (large text & UI).
- Provide skip links and logical heading order.
- Respect motion & color preference media queries.
