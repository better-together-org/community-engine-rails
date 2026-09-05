# View DOM Identifier Standard

All interactive and data-bearing elements in Community Engine ERB views must carry
stable, predictable `id` and/or semantic `class` attributes.

## Why this matters

Without stable identifiers, screenshot callout selectors use fragile structural
CSS pseudo-selectors (`nth-of-type`, `first-child`, `:first-of-type`) that break
silently when the surrounding DOM changes. Stable IDs also make accessibility testing
precise, Stimulus controller targeting explicit, and Capybara feature specs resilient.

## Required identifiers by element type

### Containers and record surfaces

Every top-level record container must carry `dom_id(record)`:

```erb
<%# Good %>
<div id="<%= dom_id(@short_link) %>" class="container my-3">

<%# Bad — no way to target this specific record's container %>
<div class="container my-3">
```

### Action button groups

```erb
<div class="btn-group" id="<%= dom_id(@resource, :actions) %>">
```

### Detail / definition list rows (`<dl>`)

Every `<dl>` carrying record attributes must have an `id`, and every `<dd>` that holds
a distinct data point must have a **stable, human-readable `id`**:

```erb
<dl class="row" id="<%= dom_id(@resource, :details) %>">
  <dt>Target URL</dt>
  <dd id="<%= dom_id(@resource, :target_url) %>">…</dd>

  <dt>Status</dt>
  <dd id="<%= dom_id(@resource, :status) %>">…</dd>

  <dt>Total Clicks</dt>
  <dd id="<%= dom_id(@resource, :click_count) %>">…</dd>
</dl>
```

### Status badges

Status badges must carry a semantic class alongside the Bootstrap colour modifier:

```erb
<span class="badge <resource-type>-status-badge bg-<%= colour %>">
  <%= record.status %>
</span>
```

Example: `class="badge short-link-status-badge bg-success"`.  
This allows a selector like `.short-link-status-badge.bg-success` that is unambiguous
without relying on DOM position.

### Tables and index lists

Index tables must have a stable `id`:

```erb
<table class="table" id="<%= controller_name.dasherize %>-table">
```

Example: `id="short-links-table"`.  
Per-row record containers should carry `dom_id(record)` on the `<tr>`:

```erb
<tr id="<%= dom_id(short_link) %>">
```

### Primary action buttons (index)

The primary CTA button on an index page must carry a stable `id`:

```erb
<%= link_to new_resource_path, class: 'btn btn-primary', id: 'new-short-link-btn' do %>
```

Pattern: `new-<resource-singular>-btn`.

### Form fields

Form inputs whose label uses `for=` must have matching `id` attributes (Rails
`form.text_field :field` already generates `id` from the attribute name — do not
override this with a blank or positional id).

## Naming conventions

| Element | Pattern | Example |
|---------|---------|---------|
| Record container | `dom_id(record)` → `better_together_short_link_1` | `id="better_together_short_link_1"` |
| Detail `<dl>` | `dom_id(record, :details)` → `details_better_together_short_link_1` | `id="details_better_together_short_link_1"` |
| Detail `<dd>` field | `dom_id(record, :field_name)` | `id="click_count_better_together_short_link_1"` |
| Static `<dd>` (show page) | `<resource>-<field>` | `id="short-link-click-count"` |
| Index table | `<resource-plural>-table` | `id="short-links-table"` |
| New CTA | `new-<resource>-btn` | `id="new-short-link-btn"` |
| Action group | `<resource>-actions` | `id="short-link-actions"` |
| Status badge class | `<resource>-status-badge` | `class="short-link-status-badge"` |

Prefer `dom_id` helpers for record-scoped elements. Use static kebab-case IDs for
structural elements that don't change with the record.

## What agents must do when generating view code

1. Add `id="<%= dom_id(record) %>"` to every record container.
2. Add `id` to every `<dl>`, `<dd>`, `<table>`, and primary CTA on new views.
3. Add semantic class (e.g. `short-link-status-badge`) to every status badge.
4. Never use structural selectors (`nth-of-type`, `:first-child`) in screenshot specs or
   Capybara feature specs. Always target a stable `id` or semantic class.
5. When adding a `callouts:` entry to a doc screenshot spec, confirm the `selector:`
   resolves to a stable ID or class, not a structural pseudo-selector.

## CI enforcement

The doc screenshot specs under `spec/docs_screenshots/` use stable selectors as their
callout targets. If an element loses its `id`, the next screenshot run will fail to
resolve the selector and the spec output will be visually incorrect, making the gap
visible in code review.

For programmatic enforcement in regular (non-screenshot) CI runs, add DOM contract
specs under `spec/dom_contracts/<feature>_spec.rb`:

```ruby
# spec/dom_contracts/better_together/short_links_spec.rb
RSpec.describe 'Short Links DOM contracts', type: :feature, js: false, :skip_host_setup do
  it 'index has required stable IDs' do
    capybara_login_as_platform_manager
    visit better_together.short_links_path(locale: I18n.default_locale)
    expect(page).to have_css('#short-links-table')
    expect(page).to have_css('#new-short-link-btn')
    expect(page).to have_css('.short-link-status-badge')
  end

  it 'show page has required stable IDs' do
    visit better_together.short_link_path(short_link, locale: I18n.default_locale)
    expect(page).to have_css('#short-link-details')
    expect(page).to have_css('#short-link-click-count')
    expect(page).to have_css('#short-link-target-url')
  end
end
```

These specs run in normal CI without `RUN_DOCS_SCREENSHOTS=1`.

## See also

- `spec/docs_screenshots/_template.rb` — screenshot spec template (uses stable selectors)
- `docs/development/pull_request_evidence_standard.md` — PR tier requirements
- `docs/development/accessibility_testing.md` — WCAG requirements that also depend on stable IDs
