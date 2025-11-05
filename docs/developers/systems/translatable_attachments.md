## Translatable Attachments (developer guide)

Overview
--------

This guide documents the Mobility-style solution for per-locale Active Storage
attachments used in the project. Implementation highlights:

- Adds `locale:string` to `active_storage_attachments` and backfills to the
  default locale.
- Provides a Mobility backend in `lib/mobility/backends/attachments/backend.rb`
  which defines per-attribute, per-locale associations and accessors.
- Includes a small DSL at `lib/mobility/dsl/attachments.rb` to apply the
  backend setup immediately at class-definition time (`translates_attached`).

Where to look
-------------

- Backend implementation: `lib/mobility/backends/attachments/backend.rb`
- DSL for early use: `lib/mobility/dsl/attachments.rb` (`Mobility::DSL::Attachments`)
- Initializer wiring: `config/initializers/mobility.rb` (requires + registers
  the backend and loads the DSL)
- Migration: `db/migrate/20250829000000_add_locale_to_active_storage_attachments.rb`
- Example form partial: `app/views/better_together/shared/_translated_file_field.html.erb`

Model usage
-----------

Canonical (preferred when backend registration runs early):

  class Page < ApplicationRecord
    translates :hero_image, backend: :attachments, content_type: [/image/], presence: true
  end

Early-definition (tests, engines):

  class Page < ApplicationRecord
    extend Mobility::DSL::Attachments
    translates_attached :hero_image, content_type: [/image/], presence: true
  end

The backend will generate accessors like `hero_image_en`, `hero_image_en=`,
`hero_image_en?`, and `hero_image_en_url` for each configured locale.

Migration notes
---------------

Use a staged migration: add a nullable `locale` column, backfill existing
attachment rows to the default locale, then set NOT NULL and add a unique
index on `[:record_type, :record_id, :name, :locale]`.

Testing
-------

- Unit: `spec/lib/mobility_attachments_backend_spec.rb` demonstrates the
  generation of accessors. The test uses `translates_attached` to guarantee
  generation timing in the test environment.
- Integration: Add feature specs to exercise form uploads using the
  `_translated_file_field` partial and verify controller param handling.

Developer tips
--------------

- Prefer the canonical `translates` API when possible. The DSL is intended
  for boot-order-sensitive contexts.
- Validate `content_type` and `presence` server-side via the backend options.
- When deploying, ensure migrations are run and backfills complete before
  enabling any model to rely on the `locale` column being present and NOT NULL.

## Process Flow Diagram

```mermaid
%% Translatable Attachments flow
flowchart LR
  subgraph DB[Database]
    A[active_storage_attachments table]
  end

  M[Migration adds `locale` column & backfill] --> A

  Init[Mobility initializer]
  Init -->|require backend| B[Attachments backend (lib/mobility/backends/...)]
  Init -->|register backend| Mobility[Mobility.register_backend(:attachments)]

  B -->|provides| Apply[AttachmentsBackend.apply_to / setup]

  ModelCanonical[Model: `translates :hero_image, backend: :attachments`]
  ModelDSL[Model: `extend Mobility::DSL::Attachments`\n`translates_attached :hero_image`]

  ModelCanonical --> Apply
  ModelDSL --> Apply

  Apply -->|defines associations| Assoc[has_many :hero_image_attachments_all\nhas_one :hero_image_attachment]
  Apply -->|defines accessors| Accessors[hero_image_en, hero_image_en=, hero_image_en?, hero_image_en_url]

  View[Form partial: translated file field tabs]
  View -->|uploads per-locale| Controller

  Controller[Controller] -->|permits locale params or maps| Model
  Model -->|writer methods| ActiveStorage[Create/modify ActiveStorage::Attachment rows]
  ActiveStorage --> A

  Serve[URL helper / rails_blob_url] -->|serves blob| UserBrowser[User's browser]

  Accessors -->|getter fallback| Fallback[Default-locale fallback if enabled]
  Fallback --> ActiveStorage

  classDef infra fill:#f8f9fa,stroke:#333,stroke-width:1px;
  class DB,Init,B,Apply,Assoc,Accessors,View,Controller,ActiveStorage,Serve,Fallback infra;
```

Diagram files:

- Mermaid source: `docs/diagrams/source/translatable_attachments_flow.mmd` - editable source
- (Optional) PNG/SVG exports: `docs/diagrams/exports/...` - add via `bin/render_diagrams` if you generate exports

