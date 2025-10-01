# Lab 03 — Policy & Token Access

Practice adding an authorization rule and verifying event access via an invitation token.

## Objectives
- Update or add a Pundit policy rule
- Verify token‑scoped access to a private event
- Exercise policy scope to include events visible via token

## Steps
1. Identify a read rule to tighten (e.g., restrict show without token)
2. Update the corresponding policy and scope
3. Create a pending `EventInvitation` in a spec and pass its token as a param
4. Write a request spec asserting:
   - Without token: 302 to sign‑in or 404 (depending on platform privacy)
   - With valid token: 200 OK and content present
5. Run tests: `bin/dc-run bin/ci`

## Tips
- Use request specs so engine routing and privacy hooks are exercised
- Reuse factories for Person, Event, and EventInvitation if available
- Review `EventsController` privacy override for token handling

