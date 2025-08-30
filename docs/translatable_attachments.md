## Translatable Attachments (Mobility-style)

Overview
--------

This document describes the project's Mobility-style solution for per-locale
Active Storage attachments. The implementation mirrors mobility-actiontext: we
add a `locale` column to `active_storage_attachments` and provide a Mobility
backend which meta-defines per-attribute, per-locale accessors on models.

Files changed / key artifacts
-----------------------------

- Migration (staged): `db/migrate/20250829000000_add_locale_to_active_storage_attachments.rb`
  - Adds `locale:string` to `active_storage_attachments`, backfills existing
    rows to the default locale, sets NOT NULL, and adds a unique index on
    `[:record_type, :record_id, :name, :locale]`.
- Initializer: `config/initializers/active_storage_locales.rb`
  - Adds `for_locale` scope and basic presence validation helper for
    `ActiveStorage::Attachment` (guarded so pre-migration loads won't break).
- Mobility backend: `lib/mobility/backends/attachments/backend.rb`
  - Central backend implementation. Provides `apply_to` to install
    per-attribute associations and per-locale accessors, plus a `setup` hook
    so it integrates with `translates ... backend: :attachments`.
- DSL shim: `lib/mobility/dsl/attachments.rb`
  - Lightweight DSL `Mobility::DSL::Attachments#translates_attached` for
    early model-definition-time use (tests, engines). Preferred runtime API is
    still `translates :attr, backend: :attachments` when backend registration
    is available early in the boot process.
- Mobility initializer: `config/initializers/mobility.rb`
  - Requires and attempts to register the backend early. Also loads the DSL
    and extends `ActiveRecord::Base` so models can call `translates_attached`.
- View partial: `app/views/better_together/shared/_translated_file_field.html.erb`
  - Reusable tabbed file-field partial that follows the project's translated
    field UI patterns.

Usage (models)
--------------

Preferred (canonical) — when the backend is registered early in boot:

  class Page < ApplicationRecord
    translates :hero_image, backend: :attachments, content_type: [/image/], presence: true
  # Translatable Attachments

  This document explains the project's Mobility-style solution for per-locale
  Active Storage attachments and documents the implementation details introduced
  in the recent changes.

  ## Overview

  Translatable attachments allow a model to have an independent Active Storage
  attachment per locale. The implementation adds a `locale` column to
  `active_storage_attachments` and provides a Mobility backend that generates
  per-attribute, per-locale attachment accessors on models.

  Key goals:
  - One attachment per `record`/`name`/`locale` (for example `hero_image` in
    `:en` and `:es`).
  - Preserve the familiar Active Storage API on models (`hero_image`,
    `hero_image=`, `hero_image_url`, `hero_image?`).
  - Provide explicit per-locale accessors (e.g. `hero_image_en`).
  - Make the writer robust so attachments are created/updated via associations
    and `record_id` (UUID) is always set.

  ## Key files and where to look

  - `lib/mobility/backends/attachments/backend.rb` — Mobility backend that
    dynamically generates per-locale getters, writers, predicates, associations,
    and URL helpers. The writer accepts many attachable shapes (Blob, IO,
    Hash, file path) and creates attachments through the `has_many` association
    so `record_id` is populated.
  - `lib/mobility/dsl/attachments.rb` — small DSL exposing
    `translates_attached` for immediate, class-time wiring (useful in test or
    engine bootstraps). Prefer `translates ... backend: :attachments` when the
    backend is registered earlier in initializers.
  - `db/migrate/20250829000000_add_locale_to_active_storage_attachments.rb` —
    migration that adds the `locale` column, backfills, and adds a unique
    index for `%i[record_type record_id name locale]`.
  - Specs:
    - `spec/models/translatable_attachments_writer_spec.rb`
    - `spec/models/translatable_attachments_api_spec.rb`
    - `spec/features/translatable_attachments_integration_spec.rb`

  ## How it works (high level)

  - For each configured attribute (e.g. `:hero_image`) the backend defines:
    - `has_many :hero_image_attachments_all` — all locales (admin management).
    - `has_one :hero_image_attachment` (scoped to current `Mobility.locale`).
    - Per-locale accessors: `hero_image_en`, `hero_image_en=`, `hero_image_en?`,
      and `hero_image_en_url`.
    - Non-locale delegators: `hero_image` delegates to the accessor for the
      current `Mobility.locale`.

  - Writer behavior:
    - Accepts `ActiveStorage::Blob`, attached wrappers, IO-like objects,
      Hashes with `:io`/`:filename`/`:content_type`, or file paths.
    - If an attachment for the locale exists, the writer updates the
      `blob` on the row. Otherwise it creates the attachment via the
      `has_many` association so ActiveRecord sets `record_id` correctly.
    - Assigning `nil` purges and destroys the localized attachment row.

  ## Model usage

  Preferred (when backend is registered in initializers):

  ```ruby
  class Page < ApplicationRecord
    translates :hero_image, backend: :attachments, content_type: [/^image\//], presence: true
  end
  ```

  Fallback DSL (when immediate generation is required, e.g. in tests or engine
  dummy apps):

  ```ruby
  class Page < ApplicationRecord
    extend Mobility::DSL::Attachments
    translates_attached :hero_image, content_type: [/^image\//], presence: true
  end
  ```

  API surface examples:
  - `page.hero_image_en` — returns `ActiveStorage::Attachment` or `nil`.
  - `page.hero_image` — delegates to `page.hero_image_<current_locale>`.
  - `page.hero_image_url(host: ...)` — returns blob URL, optionally for a
    variant: `page.hero_image_en_url(variant: { resize_to_limit: [300, 300] })`.

  ## Migration details and rollout

  Migration strategy used in the repo (staged, safe for rolling deploys):
  1. Add nullable `locale` string column to `active_storage_attachments`.
  2. Backfill existing rows to `I18n.default_locale` using a single SQL update.
  3. Set `locale` to NOT NULL with a default backfilled value.
  4. Add a unique index on `%i[record_type record_id name locale]` to enforce
     a single attachment per locale.

  Notes:
  - Use `id: :uuid` as necessary in test/dummy tables to match production.
  - Back up production DB before running backfills on large tables.

  ## Testing

  - Run focused specs with the project's Docker helper:

  ```bash
  bin/dc-run bundle exec rspec spec/models/translatable_attachments_writer_spec.rb
  bin/dc-run bundle exec rspec spec/features/translatable_attachments_integration_spec.rb
  ```

  - The writer specs create real `ActiveStorage::Blob` objects and validate
    writer behavior for different attachable inputs. Integration specs attach
    a real blob and verify `rails_blob_url` behavior.
  - The test helper `spec/rails_helper.rb` was updated to accept keyword options
    for `create_table` so specs can use `id: :uuid`.

  ## Linting / RuboCop rationale

  The backend concentrates dynamic method generation in one file which naturally
  triggers RuboCop metrics (class/method length, complexity, ABC size). To
  reduce noise and keep the implementation readable we included a focused
  `rubocop:disable` header with a short justification at the top of the backend
  file and a matching `rubocop:enable` at the end of the file. This is
  documented in the backend source and in this doc. If you'd prefer, we can
  refactor the backend into smaller helpers to remove the disables.

  ## Maintenance and upgrade notes

  - If Active Storage or Mobility changes internal APIs, verify these areas:
    - `attachment_reflections` usage (the backend injects a minimal reflection
      shim to satisfy Active Storage callbacks).
    - `ActiveStorage::Blob.create_and_upload!` semantics.

  - When updating this feature, run:

  ```bash
  bin/dc-run bundle exec rspec
  bin/dc-run bundle exec rubocop -A
  bin/dc-run bundle exec brakeman --quiet --no-pager
  ```

  ## Docs/diagrams

  - If you add diagrams, put Mermaid sources under
    `docs/diagrams/source/translatable_attachments.mmd` and export to
    `docs/diagrams/exports/` using `bin/render_diagrams`.

  Diagram
  -------

  Mermaid source for the translatable-attachments ER diagram is available at:

  `docs/diagrams/source/translatable_attachments.mmd`

  You can render exports by running the project's `bin/render_diagrams` helper
  which writes PNG/SVG exports into `docs/diagrams/exports/`.

  ## Example (console)

  ```ruby
  page = Page.create!(title: 'Home')
  page.hero_image = File.open('spec/fixtures/images/sample.png')
  page.save!
  page.hero_image # => attachment for current locale
  I18n.with_locale(:es) { page.hero_image } # => fallback to default if no Spanish attachment
  ```

  ## Next steps / options

  - Open a PR with the code + docs changes (I can create it for you).
  - Add a Mermaid diagram and wire it into the docs index.
  - Refactor the backend to remove RuboCop disables (larger effort).

  ---

  If you'd like I can open a PR with these docs and the earlier code changes, or
  start the refactor to remove the RuboCop disables — tell me which you prefer.
