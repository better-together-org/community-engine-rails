 # Models & Concerns Overview

 This document summarizes the core models in the Better Together Community Engine,
 the concerns (mix-ins) they include, and illustrates how they relate.

 ## 1. Models by Domain

 ### A. Core & Identity

 | Model                | Purpose                                  | Concerns / Mix-ins                                            |
 |----------------------|------------------------------------------|---------------------------------------------------------------|
 | `BetterTogether::Person`       | A human participant                      | `Author`, `Contactable`, `FriendlySlug`, `Identifier`, `Identity`,<br>`Member`, `PrimaryCommunity`, `Privacy`, `Viewable`, `RemoveableAttachment` |
 | `BetterTogether::User`         | Devise User linked via `Identification` | `DeviseUser`                                                 |
 | `BetterTogether::Identification` | Polymorphic join (`agent`)             | `Identity`                                                  |

 ### B. Community & Platform

 | Model                           | Purpose                                | Concerns / Mix-ins                                          |
 |---------------------------------|----------------------------------------|-------------------------------------------------------------|
 | `BetterTogether::Community`     | Community instance                     | `Contactable`, `Host`, `Identifier`, `BuildingConnections`, `Joinable`, `Protected`, `Privacy`, `Permissible`, `RemoveableAttachment` |
 | `BetterTogether::Platform`      | Top-level platform                     | `Contactable`, `Host`, `Identifier`, `Joinable`, `Protected`, `Privacy`, `Permissible` |
 | `BetterTogether::PersonCommunityMembership` | Person ↔ Community join      | `Membership`                                               |
 | `BetterTogether::PersonPlatformMembership`  | Person ↔ Platform join       | `Membership`                                               |

 ### C. Content & Navigation

 | Model                | Purpose                                      | Concerns / Mix-ins                     |
 |----------------------|----------------------------------------------|----------------------------------------|
 | `BetterTogether::Post`                 | Blog-style posts                         | `Authorable`, `FriendlySlug`, `Categorizable`, `Identifier`, `Privacy`, `Publishable` |
 | `BetterTogether::Page`                 | CMS pages                                | `Authorable`, `FriendlySlug`, `Categorizable`, `Identifier`, `Privacy`, `Publishable` |
 | `BetterTogether::Category`             | Category buckets                         | `Labelable`, `Positioned`             |
 | `BetterTogether::Categorization`       | Join table for content categories        | —                                      |
 | `BetterTogether::NavigationArea`       | Menu container                           | `Positioned`, `Protected`             |
 | `BetterTogether::NavigationItem`       | Menu item/link                           | `Positioned`, `Protected`, `Visible`  |

 ### D. Communication

 | Model                    | Purpose                                  | Concerns / Mix-ins |
 |--------------------------|------------------------------------------|--------------------|
 | `BetterTogether::Conversation`           | Message thread                           | —                  |
 | `BetterTogether::ConversationParticipant`| Person ↔ Conversation join                | —                  |
 | `BetterTogether::Message`                | Chat messages                            | —                  |
 | `BetterTogether::Comment`                | Comments on content                      | —                  |

 ### E. Events & Calendar

 | Model                             | Purpose                                   | Concerns / Mix-ins                                                   |
 |-----------------------------------|-------------------------------------------|----------------------------------------------------------------------|
 | `BetterTogether::Event`           | Scheduled events                          | `Attachments::Images`, `Categorizable`, `Creatable`, `FriendlySlug`, `Geospatial::One`, `Locatable::One`, `Identifier`, `Privacy`, `TrackedActivity`, `Viewable` |
 | `BetterTogether::EventCategory`   | Event ↔ Category join                     | —                                                                    |
 | `BetterTogether::Calendar`        | Calendar container                        | —                                                                    |
 | `BetterTogether::CalendarEntry`   | Single calendar entry                     | —                                                                    |

 ### F. Geography & Infrastructure (abbreviated)

 | Model                                   | Purpose                           | Concerns / Mix-ins               |
 |-----------------------------------------|-----------------------------------|----------------------------------|
 | `BetterTogether::Geography::Continent` …| Geospatial taxonomy               | —                                |
 | `BetterTogether::Geography::Map` …      | Map definitions                   | —                                |
 | `BetterTogether::Infrastructure::Building` …| Physical infrastructure       | `BuildingConnections`            |

 ### G. Metrics & Analytics (abbreviated)

 | Model                                  | Purpose                            | Concerns / Mix-ins |
 |----------------------------------------|------------------------------------|--------------------|
 | `BetterTogether::Metrics::PageView` …  | Track user activity                | —                  |
 | `BetterTogether::Metrics::LinkClick` … | Track link clicks                  | —                  |

 ### H. Contact & Address (abbreviated)

 | Model                          | Purpose                       | Concerns / Mix-ins |
 |--------------------------------|-------------------------------|--------------------|
 | `BetterTogether::Address`      | Physical / mailing address    | `Contactable`      |
 | `BetterTogether::ContactDetail`| Generic contact points        | `Contactable`      |

 ## 2. Mermaid Diagram

 The following Mermaid diagram illustrates main associations and concerns.

 ```mermaid
 %% Models & Concerns class diagram
 classDiagram
   direction TB

   %% Core identity
   class Person {
     <<Author,Contactable,Identity,Member,PrimaryCommunity,
       FriendlySlug,Privacy,Viewable,RemoveableAttachment>>
   }
   class User {
     <<DeviseUser>>
   }
   class Identification
   Person "1" o-- "1" Identification : has_one
   User "1" <-- Identification : agent

   %% Community & Platform
   class Community {
     <<Contactable,Host,Joinable,Identifier,
       Protected,Privacy,Permissible,RemoveableAttachment>>
   }
   class Platform {
     <<Contactable,Host,Joinable,Identifier,
       Protected,Privacy,Permissible>>
   }
   class PersonCommunityMembership {
     <<Membership>>
   }
   class PersonPlatformMembership {
     <<Membership>>
   }
   PersonCommunityMembership *-- Community
   PersonCommunityMembership *-- Person
   PersonPlatformMembership *-- Platform
   PersonPlatformMembership *-- Person
   Community o-- PersonCommunityMembership
   Platform o-- PersonPlatformMembership
   Person o-- PersonCommunityMembership
   Person o-- PersonPlatformMembership

   %% Post & Page
   class Post {
     <<Authorable,Categorizable,Identifier,Privacy,Publishable,
       FriendlySlug>>
   }
   class Page {
     <<Authorable,Categorizable,Identifier,Privacy,Publishable,
       FriendlySlug>>
   }
   class Category
   class Categorization
   Post *-- Categorization
   Category *-- Categorization
   Page *-- Categorization

   %% Conversations
   class Conversation
   class ConversationParticipant
   class Message
   Conversation "1" o-- "*" ConversationParticipant
   ConversationParticipant "*" o-- "1" Person
   Conversation "1" o-- "*" Message
   Message "*" o-- "1" Person : sender

   %% Events & Calendar
   class Event {
     <<Attachments::Images,Categorizable,Creatable,
       FriendlySlug,Geospatial::One,Locatable::One,Identifier,
       Privacy,TrackedActivity,Viewable>>
   }
   class EventCategory
   class Calendar
   class CalendarEntry
   Event *-- EventCategory
   Calendar *-- CalendarEntry
   CalendarEntry --> Event : entry

   %% Infrastructure (abbreviated)
   class Building {
     <<BuildingConnections>>
   }
   class Floor
   class Room
   Building "1" o-- "*" Floor
   Floor "1" o-- "*" Room

   %% Contact
   class Address
   class ContactDetail
   Person "1" o-- "*" ContactDetail
   Community "1" o-- "*" ContactDetail
 ```

 **Diagram file:** [`docs/diagrams/source/models_and_concerns_diagram.mmd`](diagrams/source/models_and_concerns_diagram.mmd)
