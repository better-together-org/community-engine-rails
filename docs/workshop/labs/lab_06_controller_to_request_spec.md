# Lab 06 — Controller → Request Spec Conversion

Convert a brittle controller spec into a robust request spec aligned with engine routing.

## Objectives
- Replace a controller spec with an equivalent request spec
- Use automatic host setup and auth metadata
- Fix path helper assertions that break under engine isolation

## Steps
1. Pick a controller spec that exercises an engine controller action (or create a minimal one).
2. Create a new request spec mirroring the scenarios; add metadata like `:as_user` or `:as_platform_manager`.
3. Replace direct controller calls with HTTP verbs:
   - `get better_together.some_path(params: { locale: I18n.default_locale })`
4. Assertions:
   - Prefer `expect(response).to have_http_status(:ok)` and `include('/expected/path')` for redirects
   - Avoid direct path helper comparisons in controller specs
5. Remove or mark the old controller spec pending; keep only the request spec.
6. Run: `bin/dc-run bin/ci` (or focus the file).

## Tips
- Engine route names include the engine namespace (e.g., `better_together.*_path`).
- Automatic test configuration often sets up host platform and login when metadata is present.
- For redirects, compare `response.location` with `include('/resource')` instead of helper equality.

