# Polymorphic Associations & Single Table Inheritance (STI)

This document outlines all polymorphic Active Record associations and Single Table Inheritance (STI) usage in the Better Together Community Engine.

---

## 1. Polymorphic Associations

Polymorphic associations allow a model to belong to more than one other model on a single association.

| Model                             | Association           | Interface Name  | Notes                                                    |
|-----------------------------------|-----------------------|-----------------|----------------------------------------------------------|
| **Authorship**                    | `belongs_to :authorable` | authorable    | Connects author (Person) to various content types        |
|                                   | `belongs_to :author`    | author        | Points to `BetterTogether::Person`                       |
| **ContactDetail**                 | `belongs_to :contactable` | contactable  | Stores contact info (phone, email, address, etc.)       |
| **Identification**                | `belongs_to :agent`      | agent         | Joins agent (User) polymorphically                       |
|                                   | `belongs_to :identity`   | identity      | Connects identity (Person, Community, etc.)              |
| **ResourcePermission**¹           | _(via `Resourceful`)_    | resource_type | Validates permitted actions against various models      |
| **Metrics::Download**             | `belongs_to :downloadable` | downloadable| Tracks file download events for any model               |
| **Upload**²                       | _ActiveStorage_         | record        | Uploaded files attachable to any record                  |

_¹ ResourcePermission uses the `Resourceful` concern to work with a polymorphic `resource_type` column._
_² Upload delegates to `has_one_attached :file`, backed by Active Storage’s polymorphic attachments._

---

## 2. Single Table Inheritance (STI)

STI allows multiple subclasses to share a single database table, distinguished by a `type` column.

| Base Class                        | Subclasses                              | Table Name                         |
|-----------------------------------|-----------------------------------------|------------------------------------|
| **BetterTogether::Content::Block**| Html, Css, Image, Hero, PageBlock, PlatformBlock, RichText, Template | `better_together_content_blocks` |

_Content blocks are defined via STI; each block type extends `Content::Block` and is rendered according to its subclass._

---

## 3. Further Exploration

- See `app/models/better_together/authorship.rb` for Authorship associations.
- See `app/models/better_together/contact_detail.rb` for ContactDetail.
- See `app/models/better_together/identification.rb` for polymorphic identity.
- See `app/models/concerns/better_together/resourceful.rb` for ResourcePermission’s concern.
- See `app/models/better_together/content/block.rb` and its subclasses under `app/models/better_together/content/` for STI details.

---

**Diagram file:** [`docs/models_and_concerns_diagram.mmd`](models_and_concerns_diagram.mmd)
