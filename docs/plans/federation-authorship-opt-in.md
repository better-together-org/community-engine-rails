# Plan: Federation Authorship Opt-In

**Tracking issue:** better-together-org/community-engine-rails#1407
**Related plans:**
- [Posts index search/filter/pagination](posts-index-filter-pagination.md) — PR #1409 (`plan/posts-index-filter-pagination`)
- [Events index search/filter/pagination](events-index-filter-pagination.md) — PR #1410 (`plan/events-index-filter-pagination`)

---

## Background

`FederatedSeedAttributes` currently omits all author identity from the public federation
payload — no `creator_id`, no author name, no profile link. This was a deliberate
privacy-first choice: people on a source platform have not consented to their identity
being broadcast to every platform that subscribes to the public feed.

However, authors should be able to _opt in_ to federating their authorship so that
federated posts, pages, and events display a byline on target platforms.

---

## Goals

1. Add a person-level privacy preference: `federate_authorship` (default: `false`).
2. When `federate_authorship: true`, include a lightweight author stub in the
   `FederatedSeedAttributes` export payload.
3. Ingest side: store the author stub on the imported seed record and surface it
   in the UI as a byline.
4. Provide a UI toggle in person settings so users control this themselves.

---

## Out of Scope

- Per-content-item authorship control (coarser person-level setting is enough for v1).
- Author profile linking across platforms (avatar, bio sync) — future work.
- Retroactive re-export of already-federated seeds when the opt-in flag changes.

---

## Acceptance Criteria

### Person settings

- [ ] `BetterTogether::Person` gains a `federate_authorship` boolean (default `false`).
      Stored in `settings` via Storext (already used on the model) to avoid a migration
      on `better_together_people`, unless DB-level querying is needed.
- [ ] Person edit form exposes the toggle under a "Federation" or "Privacy" section with
      i18n key `better_together.people.edit.federation.federate_authorship`.
- [ ] The field is documented in the person settings i18n locale files (en.yml minimum).

### Export (source platform)

- [ ] `FederatedSeedAttributes.post_attributes(record)` includes an `author` key when
      `record.creator&.federate_authorship?`:
      ```ruby
      author: {
        display_name: record.creator.display_name,
        identifier:   record.creator.identifier,
        platform_url: Current.platform.resolved_host_url
      }
      ```
- [ ] Same for `page_attributes` and `event_attributes`.
- [ ] When `federate_authorship` is `false` or creator is absent, the `author` key is
      absent from the payload entirely (not `null`).

### Ingest (target platform)

- [ ] `FederatedSeedBuilder` / `LinkedSeedIngestService` reads `author` from the payload
      and stores it in a new `federated_author jsonb` column on the record.
- [ ] Migration adds nullable `federated_author jsonb` column to
      `better_together_posts`, `better_together_pages`, and `better_together_events`.
- [ ] Post, page, and event show partials render a byline when `record.federated_author.present?`:
      ```erb
      <span class="federated-author">
        <%= t('.by') %> <%= record.federated_author['display_name'] %>
        — <%= record.federated_author['platform_url'] %>
      </span>
      ```

---

## Required Tests

- [ ] **`FederatedSeedAttributes` unit spec**
  - opt-out person → `author` key absent from payload
  - opt-in person → `author` hash present with `display_name`, `identifier`, `platform_url`
  - nil creator → `author` key absent
- [ ] **`LinkedSeedIngestService` spec**
  - payload with `author` hash → `federated_author` persisted on model
  - payload without `author` → `federated_author` is nil
- [ ] **`Person` model spec**
  - `federate_authorship` defaults to `false`
  - can be toggled to `true` and persisted
- [ ] **System/feature spec**
  - User enables opt-in in settings; publishes a post; asserts federated seed payload
    includes author hash
  - Federated post imported on target platform shows byline in the UI

---

## Stakeholders

| Name | Role |
|------|------|
| Rob Polowick | Product lead — privacy design decisions |
| Platform managers | Configure connections; communicate opt-in to community |
| Community Engine users | People whose authorship may be federated |

---

## Implementation Notes

- Storext `settings` store on `Person` is the path of least resistance — no migration
  on the people table and consistent with other person preference flags.
- `FederatedSeedAttributes` is a pure-Ruby module with no Rails dependencies; easy to
  unit-test without a full Rails load.
- Keep the author stub minimal for v1: display name + identifier + platform URL is
  sufficient for a byline without requiring cross-platform profile lookup.
- The `federated_author` JSONB column is forward-compatible: `avatar_url`, `bio`, etc.
  can be added later by extending the export payload without another migration.

---

## Migration sketch

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_federated_author_to_content.rb
class AddFederatedAuthorToContent < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_posts,  :federated_author, :jsonb
    add_column :better_together_pages,  :federated_author, :jsonb
    add_column :better_together_events, :federated_author, :jsonb
  end
end
```
