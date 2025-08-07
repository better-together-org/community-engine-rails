---
applyTo: "**/*.rb,**/*.erb,**/*.js"
---
# Security & Encryption

- Use Active Record Encryption for sensitive columns (PII, messages).
- Encrypt Active Storage files at rest.
- Enforce CSP with nonces for inline JS; never use `unsafe-inline`.
- Scrub params/logs for secrets.
- Validate user input; never trust params for authorization decisions.
