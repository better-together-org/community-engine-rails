# Lab 02 — Model + Migration with Tests

Create a simple model using migration helpers, add string enums, and write request‑first tests.

## Objectives
- Create a `create_bt_table` migration using helpers
- Define a string enum on the model
- Write a request spec to exercise basic create/show

## Steps
1. Generate migration and model skeleton (manual or via Rails generator inside dc‑run)
2. In the migration:
   - Use `create_bt_table :example_items` block
   - Add `t.string :status, default: "pending"`
   - Add `t.bt_references :person, null: false`
3. In the model:
   - `enum :status, { pending: "pending", active: "active" }`
   - Validations for required fields
4. Write a request spec for `POST /example_items` and `GET /example_items/:id`
5. Run tests: `bin/dc-run bin/ci` (or targeted rspec command)

## Tips
- Follow naming and engine prefix conventions in routes/controllers
- Prefer request specs over controller specs to avoid engine routing pitfalls
- Add missing translations with `bin/dc-run bin/i18n add-missing`

