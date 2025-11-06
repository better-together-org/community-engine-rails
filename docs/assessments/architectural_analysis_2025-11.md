# Better Together Community Engine - Comprehensive Architectural Analysis

**Date:** November 5, 2025  
**Analysis Type:** System Architecture and Documentation Structure  
**Repository:** better-together-org/community-engine-rails  
**Rails Version:** 8.0.2
**Ruby Version:** 3.3+

---

## Executive Summary

This comprehensive architectural analysis examines the Better Together Community Engine, a sophisticated multi-tenant Rails application designed for democratic community governance, cooperative platform operations, and value exchange. The system demonstrates mature software engineering practices with strong separation of concerns, extensive use of Rails patterns, and comprehensive feature coverage across 15 major functional domains.

### Key Architectural Strengths

- **Well-Organized Domain Structure:** 15 distinct functional systems with clear boundaries
- **Extensive Use of Concerns:** 40+ reusable concerns providing cross-cutting functionality
- **Mature Infrastructure Integration:** Redis, Elasticsearch, PostgreSQL+PostGIS, Active Storage, Action Text
- **Modern Front-End Stack:** Hotwire (Turbo + Stimulus), Bootstrap 5.3, real-time WebSocket communication
- **Strong Security Foundation:** Pundit RBAC, Active Record Encryption, Rack::Attack rate limiting
- **Internationalization First:** Mobility gem with multiple translation backends including AI-powered translation
- **Privacy-by-Design:** Comprehensive privacy controls, data protection measures, and user consent management

### System Scale

- **75+ Database Tables** across 15 major domains
- **60+ Active Record Models** with rich associations and validations
- **50+ Controllers** managing CRUD and complex workflows
- **48+ Stimulus Controllers** providing interactive UI behaviors
- **30+ Background Jobs** handling async processing
- **40+ Reusable Concerns** for shared model/controller behavior
- **25+ Pundit Policies** enforcing authorization rules
- **10+ Action Cable Channels** for real-time features

### Documentation Coverage

- **Current Status:** 47% complete (7/15 systems fully documented)
- **High Priority Systems:** Community, Content, Communication, Platform Management
- **Documentation Types:** System docs, flow diagrams, API references, developer guides

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Core Systems and Subsystems](#core-systems-and-subsystems)
3. [Cross-System Integration Map](#cross-system-integration-map)
4. [Infrastructure and Integration Layers](#infrastructure-and-integration-layers)
5. [Architectural Patterns](#architectural-patterns)
6. [Data Flow and Dependencies](#data-flow-and-dependencies)
7. [Recommended Documentation Structure](#recommended-documentation-structure)
8. [Mermaid Diagram Recommendations](#mermaid-diagram-recommendations)
9. [Natural Documentation Boundaries](#natural-documentation-boundaries)
10. [Implementation Insights](#implementation-insights)

---

## System Overview

The Better Together Community Engine is organized into 15 major functional systems, each with well-defined responsibilities and clear interfaces.

### Core Systems (High Priority)

1. **Platform Management System** - Multi-tenant platform configuration and administration
2. **Community Management System** - Community creation, membership, and governance
3. **Content Management System** - Pages, blocks, rich text content, and media
4. **Communication System** - Conversations, messages, and real-time chat
5. **Authentication & Authorization System** - User accounts, roles, and permissions
6. **Event & Calendar System** - Event creation, invitations, and attendance tracking
7. **Joatu Exchange System** - Offers, requests, agreements, and value exchange

### Supporting Systems (Medium Priority)

8. **Geography & Location System** - Continents, countries, regions, settlements, maps
9. **Metrics & Analytics System** - Page views, link clicks, downloads, search queries
10. **Navigation System** - Site navigation areas and menu items
11. **Notification System** - Multi-channel notifications (email, in-app, real-time)
12. **Content Organization System** - Categories, tags, and content relationships
13. **Contact Management System** - Addresses, phone numbers, email addresses, social media

### Specialized Systems (Lower Priority)

14. **Infrastructure System** - Buildings, floors, rooms for physical space mapping
15. **Workflow Management System** - Wizards, checklists, and guided processes

---

## Core Systems and Subsystems

### 1. Platform Management System

**Purpose:** Multi-tenant platform configuration, branding, and administrative control

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Platform Configuration** | Platform-level settings, branding, timezone | `Platform`, `Content::PlatformBlock` | Storext, Active Storage |
| **Host Management** | Host/peer platform relationships and federation | `Platform` (host flag), `PlatformHost` concern | None |
| **Platform Invitations** | Invitation-based platform access control | `PlatformInvitation`, `PlatformInvitationMailerJob` | Noticed, Sidekiq |
| **Platform Membership** | Person-to-Platform relationships | `PersonPlatformMembership`, `Role` | RBAC System |
| **Custom CSS/Theming** | Platform-specific styling and branding | `Content::Css` block | Content System |

#### Key Dependencies
- **Internal:** Community Management, RBAC System, Content Management
- **External:** Redis (caching), Active Storage (images), Sidekiq (jobs)

#### Primary Controllers
- `PlatformsController` - Platform CRUD operations
- `HostDashboardController` - Platform admin dashboard
- `PlatformInvitationsController` - Invitation management

---

### 2. Community Management System

**Purpose:** Community creation, membership management, and social interactions

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Community Core** | Community profiles and configuration | `Community`, `PrimaryCommunity` concern | Platform Management |
| **Membership Management** | Person-to-Community relationships | `PersonCommunityMembership`, `Role` | RBAC System |
| **Social Safety** | Blocking, reporting, moderation | `PersonBlock`, `Report` | Notification System |
| **Calendars** | Community event calendars | `Calendar` | Event System |
| **Infrastructure Links** | Physical location associations | `BuildingConnection` | Infrastructure System |

#### Key Dependencies
- **Internal:** Platform Management, RBAC System, Event System
- **External:** Active Storage (profile/cover images)

#### Primary Controllers
- `CommunitiesController` - Community CRUD
- `PersonCommunityMembershipsController` - Membership management
- `PersonBlocksController` - Block management
- `ReportsController` - Content/user reporting

---

### 3. Content Management System

**Purpose:** CMS functionality for pages, blocks, and rich media content

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Pages** | Full CMS pages with layouts | `Page`, `Authorship` | Author, Publishing concerns |
| **Content Blocks** | Modular content components (STI) | `Content::Block` and 10+ subclasses | Storext attributes |
| **Rich Text** | Action Text integration | `Content::RichText` block, `ActionText::RichText` | Trix editor, Active Storage |
| **Media Management** | Images, uploads, attachments | `Content::Image`, `Upload`, Active Storage | Active Storage, variants |
| **Block Composition** | Page-to-Block relationships | `Content::PageBlock`, `Content::PlatformBlock` | Positioning concern |
| **Content Search** | Elasticsearch-powered search | `Searchable` concern | Elasticsearch |

#### Content Block Types (STI Hierarchy)
- `Content::Block` (base class)
  - `Content::Html` - Raw HTML content
  - `Content::RichText` - Action Text rich content
  - `Content::Image` - Image blocks
  - `Content::Link` - Hyperlinks
  - `Content::Hero` - Hero banners
  - `Content::Css` - Custom CSS styling
  - `Content::Template` - Reusable templates

#### Key Dependencies
- **Internal:** RBAC System, Metrics System (page views)
- **External:** Action Text, Active Storage, Elasticsearch, Trix

#### Primary Controllers
- `PagesController` - Page CRUD and viewing
- `Content::BlocksController` - Block management
- `UploadsController` - File upload handling
- `StaticPagesController` - Static content rendering

---

### 4. Communication System

**Purpose:** Private messaging, conversations, and real-time chat

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Conversations** | Multi-participant message threads | `Conversation`, `ConversationParticipant` | Privacy controls |
| **Messages** | Encrypted rich text messages | `Message` (encrypted content) | Action Text, Encryption |
| **Real-Time Messaging** | WebSocket-based live chat | `ConversationsChannel`, `MessagesChannel` | Action Cable, Turbo Streams |
| **Notifications** | Message delivery notifications | `NewMessageNotifier` | Notification System |
| **Privacy Controls** | Message settings and preferences | `Person` preferences | Privacy System |

#### Key Dependencies
- **Internal:** Person model, Notification System, Privacy System
- **External:** Action Cable, Redis (pub/sub), Active Record Encryption

#### Primary Controllers
- `ConversationsController` - Conversation management
- `MessagesController` - Message creation

#### Channels
- `ConversationsChannel` - Real-time conversation updates
- `MessagesChannel` - Live message streaming

---

### 5. Authentication & Authorization System (RBAC)

**Purpose:** User authentication, role-based access control, and permission management

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Authentication** | User accounts and sign-in | `User` (Devise), `Identification` | Devise, JWT |
| **Identity Management** | Person-to-User linking | `Identification` (polymorphic) | Person, User models |
| **Role Management** | Role definitions and assignment | `Role`, `RoleResourcePermission` | i18n (Mobility) |
| **Permission System** | Fine-grained permissions | `ResourcePermission`, `Permissible` concern | Pundit |
| **Authorization Policies** | 25+ Pundit policies | `ApplicationPolicy` and subclasses | Pundit gem |
| **Session Security** | JWT denylist, rate limiting | `JwtDenylist` | Rack::Attack, Redis |

#### Key Dependencies
- **Internal:** Platform Management, Community Management
- **External:** Devise, Pundit, Rack::Attack, Redis

#### Primary Controllers
- `Users::RegistrationsController` - User registration
- `Users::SessionsController` - Authentication
- `Users::PasswordsController` - Password reset
- `RolesController` - Role management
- `ResourcePermissionsController` - Permission assignment

---

### 6. Event & Calendar System

**Purpose:** Event scheduling, invitations, and attendance management

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Events** | Event creation and management | `Event`, `EventHost` | Geography (location) |
| **Calendars** | Event organization | `Calendar` | Community System |
| **Invitations** | Email/member event invites | `EventInvitation` (token-based) | Notification System |
| **Attendance** | RSVP and attendance tracking | `EventAttendance` | Event model |
| **Event Reminders** | Scheduled reminder notifications | `EventReminderJob`, `EventReminderNotifier` | Sidekiq, Noticed |
| **Categorization** | Event categories and filtering | `EventCategory`, `Category` | Content Organization |

#### Key Dependencies
- **Internal:** Community Management, Geography System, Notification System
- **External:** Sidekiq (reminders), Noticed (notifications)

#### Primary Controllers
- `EventsController` - Event CRUD
- `Events::InvitationsController` - Invitation management

#### Background Jobs
- `EventReminderScanJob` - Finds events needing reminders
- `EventReminderSchedulerJob` - Schedules individual reminders
- `EventReminderJob` - Sends reminder notifications

---

### 7. Joatu Exchange System

**Purpose:** Value exchange platform for offers, requests, and agreements

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Offers** | Services/goods offered | `Joatu::Offer` | Person, Community |
| **Requests** | Services/goods requested | `Joatu::Request` | Person, Community |
| **Agreements** | Matched offers and requests | `Joatu::Agreement` | Offer, Request models |
| **Response Links** | Offer↔Request connections | `Joatu::ResponseLink` | Safe class resolution |
| **Categories** | Exchange categorization | `Joatu::Category` | Content Organization |
| **Notifications** | Agreement status updates | `Joatu::AgreementNotifier` | Notification System |

#### Key Dependencies
- **Internal:** Person, Community, Notification System
- **External:** Noticed (notifications)

#### Primary Controllers
- `Joatu::OffersController` - Offer management
- `Joatu::RequestsController` - Request management
- `Joatu::AgreementsController` - Agreement handling
- `Joatu::CategoriesController` - Category management
- `Joatu::HubController` - Exchange dashboard

---

### 8. Geography & Location System

**Purpose:** Hierarchical geographic data and mapping functionality

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Geographic Hierarchy** | World geography structure | `Continent`, `Country`, `State`, `Region`, `Settlement` | Mobility (translations) |
| **Geospatial Data** | Coordinates and boundaries | `GeospatialSpace` (PostGIS) | PostGIS extension |
| **Location Linking** | Entity-to-location associations | `LocatableLocation` (polymorphic) | Various models |
| **Maps** | Visual map representations | `Map`, `CommunityMap`, `CommunityCollectionMap` | Communities |
| **Geocoding** | Address-to-coordinates conversion | `GeocodingJob` | External geocoding API |

#### Key Dependencies
- **Internal:** Community System, Event System
- **External:** PostgreSQL PostGIS, Geocoding services

#### Primary Controllers
- `Geography::MapsController` - Map management
- Various controllers using `Locatable` concern

---

### 9. Metrics & Analytics System

**Purpose:** Activity tracking, analytics, and reporting

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Page Views** | Content view tracking | `Metrics::PageView`, `Metrics::PageViewReport` | Viewable concern |
| **Link Tracking** | Click analytics | `Metrics::LinkClick`, `Metrics::LinkClickReport` | Pages, rich text |
| **Downloads** | File download tracking | `Metrics::Download` | Active Storage |
| **Search Analytics** | Search query tracking | `Metrics::SearchQuery` | Search system |
| **Shares** | Content sharing metrics | `Metrics::Share` | Shareable content |
| **Link Checker** | Internal link validation | `Metrics::LinkCheckerReport`, `Metrics::RichTextLink` | Background jobs |

#### Key Dependencies
- **Internal:** Content System, Person model
- **External:** Sidekiq (background tracking), Redis (caching)

#### Background Jobs
- `Metrics::TrackPageViewJob`
- `Metrics::TrackLinkClickJob`
- `Metrics::TrackDownloadJob`
- `Metrics::TrackSearchQueryJob`
- `Metrics::TrackShareJob`
- `Metrics::InternalLinkCheckerJob`
- `Metrics::LinkCheckerReportSchedulerJob`

---

### 10. Navigation System

**Purpose:** Site navigation management and menu structures

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Navigation Areas** | Menu containers | `NavigationArea` | Positioning, Protection |
| **Navigation Items** | Menu links and structure | `NavigationItem` (tree structure) | Polymorphic linkable |

#### Key Dependencies
- **Internal:** Content System (pages), RBAC (protected items)
- **External:** None

#### Primary Controllers
- `NavigationAreasController` - Area management
- `NavigationItemsController` - Item management

---

### 11. Notification System

**Purpose:** Multi-channel notification delivery and management

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Notification Delivery** | Noticed-based notifications | `Noticed::Notification`, `Noticed::Event` | Noticed gem |
| **Email Notifications** | Email delivery | Various notifier classes | Action Mailer |
| **In-App Notifications** | Web notifications | `NotificationsChannel` | Action Cable |
| **Real-Time Updates** | WebSocket notification push | `NotificationsChannel` | Turbo Streams |
| **Notification Preferences** | User notification settings | `Person` preferences | Person model |

#### Notifier Classes
- `NewMessageNotifier`
- `EventInvitationNotifier`
- `EventReminderNotifier`
- `EventUpdateNotifier`
- `PageAuthorshipNotifier`
- `Joatu::AgreementNotifier`

#### Key Dependencies
- **Internal:** Person model, various event sources
- **External:** Noticed gem, Action Cable, Redis

#### Channels
- `NotificationsChannel` - Real-time notification streaming

---

### 12. Content Organization System

**Purpose:** Content categorization and taxonomies

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Categories** | Hierarchical categories | `Category` (tree structure) | Positioning, Labelable |
| **Categorization** | Content-to-category links | `Categorization` (polymorphic) | Various categorizable models |

#### Key Dependencies
- **Internal:** Content System, Event System, Joatu System
- **External:** None

#### Primary Controllers
- `CategoriesController` - Category management

---

### 13. Contact Management System

**Purpose:** Contact information management for people and communities

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Contact Details** | Base contact information | `ContactDetail` (polymorphic STI base) | Contactable concern |
| **Email Addresses** | Email contact points | `EmailAddress` | ContactDetail |
| **Phone Numbers** | Phone contact points | `PhoneNumber` | ContactDetail |
| **Physical Addresses** | Mailing addresses | `Address` | ContactDetail, Geography |
| **Social Media** | Social media profiles | `SocialMediaAccount` | ContactDetail |
| **Websites** | Website URLs | `WebsiteLink` | ContactDetail |

#### Key Dependencies
- **Internal:** Person, Community, Geography System
- **External:** None

---

### 14. Infrastructure System

**Purpose:** Physical infrastructure mapping (buildings, floors, rooms)

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Buildings** | Building structures | `Infrastructure::Building` | Geography System |
| **Building Connections** | Community-building links | `Infrastructure::BuildingConnection` | Community System |
| **Floors** | Building floor levels | `Infrastructure::Floor` | Building |
| **Rooms** | Individual rooms/spaces | `Infrastructure::Room` | Floor |

#### Key Dependencies
- **Internal:** Community System, Geography System
- **External:** None

---

### 15. Workflow Management System

**Purpose:** Guided workflows, wizards, and task management

#### Subsystems

| Subsystem | Purpose | Key Models | Dependencies |
|-----------|---------|------------|--------------|
| **Wizards** | Multi-step workflows | `Wizard`, `WizardStep`, `WizardStepDefinition` | State machine |
| **Checklists** | Task lists | `Checklist`, `ChecklistItem` | Positioning |
| **User Progress** | Individual task completion | `PersonChecklistItem` | Person model |

#### Key Dependencies
- **Internal:** Person model
- **External:** None

#### Primary Controllers
- `WizardsController`
- `WizardStepsController`
- `ChecklistsController`
- `ChecklistItemsController`
- `PersonChecklistItemsController`

---

## Cross-System Integration Map

### Major System Relationships

```
Platform Management
├── owns → Community Management (1:N)
├── configures → Content Management (theming)
└── controls → RBAC System (platform roles)

Community Management
├── contains → Person Memberships (N:N via PersonCommunityMembership)
├── hosts → Events (1:N)
├── organizes → Calendars (1:N)
├── uses → Infrastructure System (building links)
└── controls → RBAC System (community roles)

Person (Core Entity)
├── participates in → Communities (via memberships)
├── participates in → Platforms (via memberships)
├── creates → Content (via Authorship)
├── sends/receives → Messages (via Conversations)
├── creates → Offers/Requests (Joatu)
├── manages → Events (via EventHost)
├── has → Contact Information
└── receives → Notifications

Content Management
├── authored by → People (via Authorship)
├── categorized by → Categories
├── tracked by → Metrics System (views, clicks)
├── indexed by → Elasticsearch
└── displayed in → Navigation System

Communication System
├── participants → People
├── triggers → Notifications
├── uses → Action Cable (real-time)
└── respects → Privacy Settings

Event System
├── hosted by → Communities/People
├── located at → Geography entities
├── categorized by → Categories
├── invites → People (via EventInvitation)
├── tracks → Attendance
├── triggers → Notifications (invites, reminders)
└── managed in → Calendars

Joatu Exchange System
├── created by → People
├── belongs to → Communities
├── creates → Agreements (Offer + Request)
├── categorized by → Joatu::Category
├── triggers → Notifications (agreement updates)
└── displayed in → Hub dashboard

Metrics System
├── tracks → Page views (Content)
├── tracks → Link clicks (Content)
├── tracks → Downloads (Active Storage)
├── tracks → Search queries (Elasticsearch)
└── generates → Reports (background jobs)

Notification System
├── triggered by → Multiple systems (Events, Messages, Joatu, etc.)
├── delivers to → People
├── streams via → Action Cable
└── respects → Notification Preferences
```

### Shared Services and Infrastructure

**Redis**
- Session storage
- Cache store
- Sidekiq job queue
- Action Cable pub/sub
- Rack::Attack throttling

**PostgreSQL + PostGIS**
- Primary data store
- Geographic/spatial data
- Full-text search (basic)

**Elasticsearch**
- Advanced full-text search
- Content indexing (Pages, Posts)
- Search analytics

**Active Storage**
- Profile/cover images
- File uploads
- Content attachments
- Media variants

**Action Text / Trix**
- Rich text editing
- Embedded content
- Rich text storage

**Sidekiq**
- Background job processing
- Scheduled jobs (reminders, reports)
- Async operations (email, indexing)

**Action Cable**
- Real-time messaging
- Live notifications
- WebSocket connections

**Noticed**
- Notification delivery
- Multi-channel support
- Notification tracking

---

## Infrastructure and Integration Layers

### External Service Integration

| Service | Purpose | Integration Points | Configuration |
|---------|---------|-------------------|---------------|
| **Redis** | Caching, sessions, pub/sub | Cache store, Sidekiq, Action Cable, Rack::Attack | `config/cable.yml`, `config/sidekiq.yml` |
| **Elasticsearch 7** | Full-text search | Pages, Posts (via `Searchable` concern) | `config/initializers/elasticsearch.rb` |
| **PostgreSQL** | Primary database | All ActiveRecord models | `config/database.yml` |
| **PostGIS** | Geographic data | Geography models, spatial queries | PostgreSQL extension |
| **AWS S3 / MinIO** | File storage | Active Storage, image uploads | `config/storage.yml` |
| **SMTP** | Email delivery | Action Mailer, notifications | `config/environments/*.rb` |
| **Cloudflare** | CDN, DNS, DDoS protection | Asset delivery, tunnels | External configuration |

### Rails Framework Integration

| Component | Usage | Implementation |
|-----------|-------|----------------|
| **Active Record** | ORM, migrations, validations | 60+ models, 75+ tables |
| **Action Text** | Rich text editing | `Content::RichText`, `Page.content` |
| **Active Storage** | File uploads | Images, attachments, variants |
| **Action Cable** | WebSockets | 5+ channels for real-time features |
| **Action Mailer** | Email sending | Notifiers, job-based delivery |
| **Active Job** | Background processing | 30+ job classes, Sidekiq backend |
| **Internationalization** | Multi-language support | Mobility gem, 40+ translated models |

### Third-Party Gem Integration

| Gem | Purpose | Usage |
|-----|---------|-------|
| **Devise** | Authentication | User registration, login, password reset |
| **Pundit** | Authorization | 25+ policy classes, resource scoping |
| **Mobility** | Translations | String, text, Action Text backends |
| **Noticed** | Notifications | Multi-channel notification delivery |
| **Storext** | JSON attributes | Settings, preferences, metadata |
| **FriendlyId** | Slugs | SEO-friendly URLs for content |
| **Rack::Attack** | Rate limiting | Request throttling, security |
| **Brakeman** | Security scanning | Static analysis, vulnerability detection |

---

## Architectural Patterns

### Domain-Driven Design Patterns

1. **Namespace Organization**
   - All models under `BetterTogether` namespace
   - Subdomain namespaces: `Content`, `Joatu`, `Geography`, `Infrastructure`, `Metrics`
   - Clear domain boundaries with minimal coupling

2. **Rich Domain Models**
   - Business logic in models (not controllers)
   - State machines for complex workflows (e.g., Agreement status)
   - Domain-specific validations and callbacks

3. **Service Objects**
   - `BetterTogether::SafeClassResolver` - Dynamic class resolution
   - Service layer for complex operations (Joatu matching, etc.)

### Rails Architectural Patterns

1. **Concerns for Cross-Cutting Concerns**
   - **40+ Reusable Concerns:**
     - `Identifier` - Unique identifiers
     - `FriendlySlug` - SEO-friendly URLs
     - `Translatable` - I18n support
     - `Privacy` - Privacy level controls
     - `Protected` - System protection flags
     - `Authorable` - Content authorship
     - `Categorizable` - Category associations
     - `Publishable` - Publishing workflows
     - `Searchable` - Elasticsearch integration
     - `Viewable` - View tracking
     - `Joinable` - Membership support (communities)
     - `Member` - Membership support (people)
     - `Permissible` - RBAC integration
     - `Contactable` - Contact information
     - `HostsEvents` - Event hosting
     - `Positioned` - Ordering/sorting
     - `Visible` - Visibility controls
     - And 20+ more...

2. **Single Table Inheritance (STI)**
   - `Content::Block` hierarchy (10+ block types)
   - `ContactDetail` hierarchy (5+ contact types)
   - Shared attributes, specialized behavior

3. **Polymorphic Associations**
   - `Identification` - Agent/Identity linking
   - `Authorship` - Authorable content
   - `Categorization` - Categorizable entities
   - `ContactDetail` - Contactable entities
   - `LocatableLocation` - Geographic entities
   - `ResourcePermission` - Permissible resources
   - `Reportable` - Report targets

4. **Join Table Pattern**
   - Explicit join models over HABTM
   - Rich join tables with attributes (timestamps, roles, status)
   - Examples: `PersonCommunityMembership`, `ConversationParticipant`, `EventAttendance`

5. **Builder Pattern**
   - `PlatformBuilder` - Platform setup wizards
   - Page builders - Complex page construction

### Front-End Architectural Patterns

1. **Hotwire Architecture**
   - **Turbo Drive** - Navigation without full page reloads
   - **Turbo Frames** - Independent page fragment updates
   - **Turbo Streams** - Real-time server-pushed updates
   - Minimal JavaScript, server-rendered HTML

2. **Stimulus Controllers (48+)**
   - Progressive enhancement
   - Scoped, reusable behaviors
   - Examples:
     - `message-form-controller` - Message composition
     - `conversation-messages-controller` - Real-time chat
     - `person-search-controller` - Live person search
     - `page-blocks-controller` - Block editor
     - `event-datetime-controller` - Event scheduling
     - `location-selector-controller` - Map integration
     - `metrics-charts-controller` - Analytics visualization

3. **Bootstrap 5.3 Components**
   - Modals, dropdowns, tooltips
   - Form components
   - Card-based layouts
   - Responsive grid system

### Security Patterns

1. **Defense in Depth**
   - Multiple security layers (authentication, authorization, rate limiting)
   - Input validation at multiple levels
   - Output escaping and sanitization

2. **Principle of Least Privilege**
   - Default-deny authorization
   - Explicit permission grants
   - Role-based access control

3. **Privacy by Design**
   - Privacy-level controls on all content
   - User preference management
   - Data encryption at rest (Active Record Encryption)
   - Encrypted messaging

4. **Safe Dynamic Resolution**
   - Allowlist-based class resolution (no `constantize` on user input)
   - `SafeClassResolver` service for Joatu response links
   - Concerns with `included_in_models` for safe reflection

---

## Data Flow and Dependencies

### Request Flow: Typical User Action

```
1. User Request
   └─→ Rails Router
       └─→ Controller Action
           ├─→ Authentication (Devise)
           ├─→ Authorization (Pundit Policy)
           ├─→ Model Query (ActiveRecord)
           ├─→ Business Logic (Model methods/services)
           ├─→ View Rendering (ERB + Turbo Frames)
           └─→ Response
               ├─→ Turbo Stream updates (real-time)
               └─→ Background Job enqueue (Sidekiq)
```

### Real-Time Messaging Flow

```
1. User sends message
   └─→ MessagesController#create
       ├─→ MessagePolicy#create? (authorization)
       ├─→ Message.create (with encryption)
       ├─→ Turbo Stream broadcast (Action Cable)
       ├─→ NewMessageNotifier.deliver (Noticed)
       └─→ Response (redirect or JSON)

2. WebSocket receives broadcast
   └─→ ConversationsChannel#subscribed
       └─→ Turbo Stream updates DOM
           └─→ Message appears in all participants' browsers
```

### Background Job Flow: Event Reminders

```
1. EventReminderScanJob (scheduled, runs every 10 minutes)
   └─→ Finds events with reminders needed
       └─→ EventReminderSchedulerJob.perform_later (per event)
           └─→ EventReminderJob.perform_later (per attendee)
               ├─→ EventReminderNotifier.with(...).deliver(person)
               │   ├─→ Email delivery (Action Mailer)
               │   └─→ In-app notification (Noticed)
               └─→ Update event reminder status
```

### Search Flow: Elasticsearch Integration

```
1. User searches
   └─→ SearchController#search
       ├─→ Elasticsearch query (via Searchable concern)
       ├─→ Results from indexed Pages/Posts
       ├─→ Metrics::TrackSearchQueryJob.perform_later
       └─→ Render results (with highlighting)

2. Content updated
   └─→ Page.save (after_commit callback)
       └─→ ElasticsearchIndexJob.perform_later
           └─→ Update Elasticsearch index
```

### Notification Flow: Multi-Channel Delivery

```
1. Notifiable event occurs (e.g., new message, event invitation)
   └─→ Notifier.with(params).deliver(recipient)
       ├─→ Email delivery (if preference enabled)
       │   └─→ MailerJob.perform_later
       │       └─→ SMTP delivery
       │
       ├─→ In-app notification
       │   └─→ Noticed::Notification record created
       │       └─→ Accessible via notifications dropdown
       │
       └─→ Real-time push (if user online)
           └─→ NotificationsChannel#broadcast
               └─→ Turbo Stream DOM update
```

---

## Recommended Documentation Structure

### Proposed Documentation Hierarchy

Based on the analysis, here is the ideal documentation structure for the Better Together Community Engine:

```
docs/
├── README.md                          # Documentation hub and quick links
├── table_of_contents.md              # Complete documentation index (EXISTING)
├── GETTING_STARTED.md                # Quick start guide for developers
│
├── stakeholder_docs/                 # Organized by stakeholder groups (EXISTING PATTERN)
│   ├── end_users/                    # End user documentation
│   ├── community_organizers/         # Community organizer guides
│   ├── platform_organizers/          # Platform administrator guides
│   ├── developers/                   # Technical documentation
│   │   ├── architecture/             # Architectural documentation
│   │   │   ├── overview.md           # High-level system architecture (NEW)
│   │   │   ├── models_and_concerns.md # Model relationships (EXISTING)
│   │   │   ├── polymorphic_and_sti.md # Database patterns (EXISTING)
│   │   │   ├── rbac_overview.md      # RBAC architecture (EXISTING)
│   │   │   ├── data_flow.md          # Data flow patterns (NEW)
│   │   │   └── integration_architecture.md # External integrations (NEW)
│   │   │
│   │   ├── systems/                  # System-level documentation (EXISTING)
│   │   │   ├── platform_management.md
│   │   │   ├── community_management.md
│   │   │   ├── content_management.md
│   │   │   ├── communication_system.md
│   │   │   ├── authentication_authorization.md
│   │   │   ├── events_system.md
│   │   │   ├── joatu_exchange.md
│   │   │   ├── geography_system.md
│   │   │   ├── metrics_analytics.md
│   │   │   ├── navigation_system.md
│   │   │   ├── notification_system.md
│   │   │   ├── content_organization.md
│   │   │   ├── contact_management.md
│   │   │   ├── infrastructure_system.md
│   │   │   └── workflow_management.md
│   │   │
│   │   ├── api/                      # API documentation (NEW)
│   │   │   ├── rest_endpoints.md
│   │   │   ├── action_cable_channels.md
│   │   │   ├── background_jobs.md
│   │   │   └── webhooks.md
│   │   │
│   │   ├── guides/                   # Developer guides
│   │   │   ├── adding_a_new_model.md
│   │   │   ├── creating_concerns.md
│   │   │   ├── implementing_policies.md
│   │   │   ├── adding_stimulus_controllers.md
│   │   │   ├── background_jobs.md
│   │   │   ├── testing_guide.md
│   │   │   ├── i18n_guide.md
│   │   │   └── security_best_practices.md
│   │   │
│   │   └── reference/                # Quick reference docs
│   │       ├── concerns_reference.md
│   │       ├── model_reference.md
│   │       ├── controller_reference.md
│   │       ├── policy_reference.md
│   │       └── job_reference.md
│   │
│   ├── content_moderators/           # Moderation guides
│   ├── support_staff/                # Support documentation
│   └── legal_compliance/             # Legal/compliance docs
│
├── diagrams/                         # Visual documentation (EXISTING)
│   ├── source/                       # Mermaid source files (.mmd)
│   │   ├── architecture/
│   │   │   ├── system_overview.mmd
│   │   │   ├── system_interactions.mmd
│   │   │   └── infrastructure_layers.mmd
│   │   ├── data_models/
│   │   │   ├── platform_community_erd.mmd
│   │   │   ├── content_system_erd.mmd
│   │   │   ├── communication_erd.mmd
│   │   │   ├── events_erd.mmd
│   │   │   └── joatu_erd.mmd
│   │   ├── flows/
│   │   │   ├── authentication_flow.mmd
│   │   │   ├── message_delivery_flow.mmd
│   │   │   ├── event_reminder_flow.mmd
│   │   │   ├── agreement_creation_flow.mmd
│   │   │   └── content_publishing_flow.mmd
│   │   └── sequences/
│   │       ├── user_registration_sequence.mmd
│   │       ├── message_sending_sequence.mmd
│   │       └── event_invitation_sequence.mmd
│   │
│   └── exports/                      # Rendered diagrams
│       ├── png/                      # PNG exports (high-res)
│       └── svg/                      # SVG exports (vector)
│
├── assessments/                      # System reviews and assessments (EXISTING)
│   ├── architectural_analysis_2025-11.md (THIS DOCUMENT)
│   ├── platform_management_system_review.md
│   ├── community_management_system_review.md
│   ├── content_management_system_review.md
│   ├── communication_messaging_system_review.md
│   └── events_feature_review_and_improvements.md
│
├── implementation/                   # Implementation planning (EXISTING)
│   ├── current_plans/
│   └── templates/
│
└── shared/                          # Cross-cutting documentation (EXISTING)
    ├── democratic_principles.md
    ├── privacy_principles.md
    └── roles_and_permissions.md
```

### Documentation Grouping Logic

**By Stakeholder (Primary Organization)**
- End Users - Using the platform
- Community Organizers - Managing communities
- Platform Organizers - Platform administration
- Developers - Building and maintaining
- Content Moderators - Content safety
- Support Staff - Troubleshooting
- Legal/Compliance - Regulatory concerns

**By System (Developer Focus)**
- Each of 15 core systems gets dedicated documentation
- Consistent structure across all system docs:
  - Purpose and scope
  - Core models and relationships
  - Key features and workflows
  - API/interface documentation
  - Configuration options
  - Common use cases
  - Troubleshooting guide
  - Related systems and dependencies

**By Type (Reference Material)**
- Architecture - High-level design
- Systems - Feature-level documentation
- API - Interface specifications
- Guides - How-to documentation
- Reference - Quick lookups

---

## Mermaid Diagram Recommendations

### Diagram Categories and Purposes

#### 1. **Entity Relationship Diagrams (ERD)**

**Purpose:** Show database schema and model relationships

**Recommended Diagrams:**

1. **Platform & Community ERD**
   ```mermaid
   erDiagram
       PLATFORM ||--o{ COMMUNITY : owns
       PLATFORM ||--o{ PERSON_PLATFORM_MEMBERSHIP : has
       COMMUNITY ||--o{ PERSON_COMMUNITY_MEMBERSHIP : has
       PERSON ||--o{ PERSON_PLATFORM_MEMBERSHIP : participates
       PERSON ||--o{ PERSON_COMMUNITY_MEMBERSHIP : participates
       ROLE ||--o{ PERSON_COMMUNITY_MEMBERSHIP : defines
       ROLE ||--o{ PERSON_PLATFORM_MEMBERSHIP : defines
   ```

2. **Content Management ERD**
   - Page, Block, PageBlock, Authorship, Category relationships

3. **Communication System ERD**
   - Conversation, Message, ConversationParticipant relationships

4. **Event System ERD**
   - Event, Calendar, EventInvitation, EventAttendance, EventHost relationships

5. **Joatu Exchange ERD**
   - Offer, Request, Agreement, ResponseLink relationships

6. **Geography System ERD**
   - Continent, Country, State, Region, Settlement hierarchy

7. **Complete System ERD** (for reference)
   - All major models and relationships

#### 2. **Architecture Diagrams**

**Purpose:** Show high-level system structure and component interactions

**Recommended Diagrams:**

1. **System Overview Architecture**
   ```mermaid
   graph TB
       User[User Browser]
       Rails[Rails Application]
       DB[(PostgreSQL + PostGIS)]
       Redis[(Redis)]
       ES[(Elasticsearch)]
       S3[(S3/MinIO)]
       
       User -->|HTTP/WebSocket| Rails
       Rails -->|ActiveRecord| DB
       Rails -->|Cache/Jobs| Redis
       Rails -->|Search| ES
       Rails -->|Files| S3
   ```

2. **System Interaction Map**
   - Shows how 15 major systems interact

3. **Infrastructure Layers**
   - Web tier, application tier, data tier
   - External services and integrations

4. **Multi-Tenancy Architecture**
   - Platform → Community → Person relationships

#### 3. **Flowchart Diagrams**

**Purpose:** Show process flows and decision logic

**Recommended Diagrams:**

1. **User Authentication Flow**
2. **Content Publishing Workflow**
3. **Event Reminder Flow**
4. **Agreement Creation Flow**
5. **Message Delivery Flow**
6. **Authorization Check Flow** (Pundit)
7. **Search Indexing Flow** (Elasticsearch)

#### 4. **Sequence Diagrams**

**Purpose:** Show time-ordered interactions between components

**Recommended Diagrams:**

1. **User Registration Sequence**
   ```mermaid
   sequenceDiagram
       actor User
       participant Browser
       participant Controller
       participant Devise
       participant UserModel
       participant PersonModel
       participant DB
       
       User->>Browser: Fill registration form
       Browser->>Controller: POST /users/sign_up
       Controller->>Devise: create user
       Devise->>UserModel: create
       UserModel->>DB: INSERT users
       UserModel->>PersonModel: create via Identification
       PersonModel->>DB: INSERT people
       Controller->>User: Redirect to dashboard
   ```

2. **Real-Time Message Sending**
3. **Event Invitation Delivery**
4. **Background Job Processing**
5. **Notification Multi-Channel Delivery**

#### 5. **State Diagrams**

**Purpose:** Show state transitions for stateful entities

**Recommended Diagrams:**

1. **Agreement Status State Machine** (pending → accepted/rejected)
2. **Event Invitation Status** (pending → accepted/declined/maybe)
3. **Content Publication Status** (draft → published → archived)

#### 6. **Component Diagrams**

**Purpose:** Show component structure and dependencies

**Recommended Diagrams:**

1. **Concern Hierarchy**
   - Shows reusable concerns and which models include them

2. **STI Hierarchies**
   - Content::Block subclasses
   - ContactDetail subclasses

3. **Stimulus Controller Organization**
   - Groups of related front-end controllers

#### 7. **Class Diagrams**

**Purpose:** Show object-oriented design for key classes

**Recommended Diagrams:**

1. **Platform-Community-Person Class Diagram**
2. **Content Management Class Diagram**
3. **RBAC Class Diagram** (Role, Permission, Policy)
4. **Joatu Exchange Class Diagram**

---

## Natural Documentation Boundaries

### Logical Documentation Boundaries

Based on the architectural analysis, here are the natural boundaries for organizing documentation:

#### 1. **System Boundaries (Primary)**

Each of the 15 major systems represents a natural documentation boundary:
- Clear functional scope
- Well-defined models and controllers
- Identifiable user-facing features
- Distinct authorization concerns

**Documentation Unit:** One comprehensive system document per major system
- **Size Target:** 200-400 lines per system
- **Includes:** Models, controllers, jobs, views, flows, diagrams

#### 2. **Stakeholder Boundaries (Secondary)**

Documentation can also be organized by stakeholder perspective:
- End Users (feature guides)
- Community Organizers (community management)
- Platform Organizers (platform administration)
- Developers (technical implementation)
- Content Moderators (safety tools)

**Documentation Unit:** Stakeholder-specific guides and workflows
- **Size Target:** Varies by complexity
- **Includes:** User stories, workflows, best practices

#### 3. **Layer Boundaries (Tertiary)**

Technical documentation can follow architectural layers:
- Data Layer (models, migrations, database)
- Business Logic Layer (services, concerns, jobs)
- Presentation Layer (controllers, views, Stimulus)
- Integration Layer (external services, APIs)

**Documentation Unit:** Layer-specific implementation guides
- **Size Target:** 100-200 lines per topic
- **Includes:** Code patterns, examples, anti-patterns

### Documentation Cross-Cutting Concerns

Some topics span multiple boundaries and require cross-referencing:

1. **RBAC** - Affects all systems, needs central documentation + system-specific notes
2. **I18n/Mobility** - Translation patterns used across 40+ models
3. **Hotwire** - Front-end patterns used throughout the app
4. **Privacy** - Privacy controls embedded in multiple systems
5. **Notifications** - Triggered from many systems, centralized delivery

**Recommendation:** Create dedicated "cross-cutting concerns" documentation with system-specific examples in system docs.

---

## Implementation Insights

### Key Architectural Patterns Observed

1. **Concern-Driven Design**
   - Heavy use of concerns (40+) for code reuse
   - Consistent patterns across similar models
   - **Benefit:** DRY code, consistent behavior
   - **Consideration:** Can create implicit dependencies

2. **Polymorphic Association Preference**
   - Used for flexible relationships (Authorable, Reportable, Linkable, etc.)
   - **Benefit:** Flexible, extensible design
   - **Consideration:** Requires careful database indexing

3. **Explicit Join Models**
   - Preferred over HABTM for membership relationships
   - **Benefit:** Can store additional attributes (role, timestamps, status)
   - **Consideration:** More models to maintain

4. **STI for Type Hierarchies**
   - Used for Content::Block and ContactDetail hierarchies
   - **Benefit:** Shared behavior, simple queries
   - **Consideration:** Table can grow wide

5. **Background Jobs for Async Operations**
   - Extensive use of Sidekiq for async processing
   - **Benefit:** Responsive UI, scalable operations
   - **Consideration:** Requires job monitoring, error handling

6. **Hotwire-First Front-End**
   - Minimal JavaScript, server-rendered updates
   - **Benefit:** Simpler front-end, leverages Rails strengths
   - **Consideration:** May require Stimulus for complex interactions

### Scalability Considerations

**Current Architecture Scales Well For:**
- Multi-tenancy (isolated communities)
- Content management (modular blocks)
- Background processing (Sidekiq)
- Real-time features (Action Cable + Redis)

**Potential Bottlenecks:**
- N+1 queries (mitigated with includes, but requires vigilance)
- Elasticsearch indexing (async jobs help)
- Image processing (Active Storage variants)
- WebSocket connection limits (Action Cable)

**Recommendations:**
- Implement query result caching for expensive RBAC checks
- Add database indexes on frequently queried columns
- Consider read replicas for reporting queries
- Monitor Sidekiq queue depths and scaling

### Security Strengths

1. **Multiple Security Layers**
   - Authentication (Devise)
   - Authorization (Pundit)
   - Rate limiting (Rack::Attack)
   - Encryption (Active Record Encryption)

2. **Safe Dynamic Resolution**
   - No unsafe `constantize` on user input
   - Allowlist-based class resolution

3. **Privacy Controls**
   - Privacy levels on content
   - User preference management
   - Encrypted messaging

### Testing Recommendations

**Current Testing Needs:**

1. **System Integration Tests**
   - Test complete user workflows across systems
   - Example: User registration → Community join → Event RSVP

2. **Policy Tests**
   - Comprehensive testing of all 25+ Pundit policies
   - Test matrix of roles × actions × resources

3. **Real-Time Feature Tests**
   - Action Cable channel tests
   - Turbo Stream delivery tests

4. **Background Job Tests**
   - Job execution tests
   - Job scheduling tests (Sidekiq Scheduler)

5. **Performance Tests**
   - N+1 query detection
   - Load testing for WebSocket connections
   - Search performance (Elasticsearch)

### Documentation Priorities

**High Priority (Complete First):**
1. ✅ Platform Management System (partially documented)
2. ✅ Community Management System (reviewed)
3. ✅ Content Management System (reviewed)
4. ❌ Communication System (needs full documentation)
5. ❌ Authentication & Authorization System (partial RBAC docs exist)
6. ✅ Event System (documented)
7. ❌ Joatu Exchange System (needs expansion)

**Medium Priority:**
8. ✅ Geography System (documented)
9. ❌ Metrics & Analytics System (needs documentation)
10. ❌ Navigation System (needs documentation)
11. ❌ Notification System (needs documentation)
12. ❌ Content Organization System (needs documentation)
13. ❌ Contact Management System (needs documentation)

**Lower Priority:**
14. ❌ Infrastructure System (needs documentation)
15. ❌ Workflow Management System (needs documentation)

---

## Conclusion

The Better Together Community Engine demonstrates a mature, well-architected Rails application with strong separation of concerns, extensive feature coverage, and thoughtful design patterns. The 15 major functional systems provide clear boundaries for documentation, with natural groupings that align with both technical architecture and stakeholder needs.

### Key Takeaways

1. **System Boundaries Are Clear** - Each of 15 systems has well-defined scope and responsibilities
2. **Concerns Are Central** - 40+ concerns provide consistent behavior across models
3. **Integration Is Comprehensive** - Redis, Elasticsearch, PostgreSQL, Active Storage, Action Cable all deeply integrated
4. **Hotwire Drives UX** - Modern, responsive UI with minimal JavaScript complexity
5. **Security Is Robust** - Multiple layers of defense, safe dynamic resolution, privacy controls
6. **Documentation Has Strong Foundation** - 47% complete with good patterns established

### Next Steps for Documentation

1. **Complete High-Priority System Docs** (Communication, Auth/RBAC, Joatu expansion)
2. **Create Architecture Overview Docs** (Data flow, integration architecture)
3. **Generate Missing Mermaid Diagrams** (ERDs, sequence diagrams, flowcharts)
4. **Develop API Reference Documentation** (REST endpoints, channels, jobs)
5. **Write Developer Guides** (Adding models, creating concerns, implementing policies)
6. **Create Quick Reference Cards** (Concerns, models, controllers, policies)

### Recommended Documentation Template

For each system, follow this structure:

```markdown
# [System Name] - System Documentation

## Overview
- Purpose and scope
- Key features
- Stakeholders

## Architecture
- Core models and associations
- Controllers and actions
- Background jobs
- Channels (if applicable)

## Database Schema
- Tables and columns
- Indexes and constraints
- Relationships diagram (ERD)

## Key Features
- Feature 1 with workflow
- Feature 2 with workflow
- etc.

## Authorization
- Relevant Pundit policies
- Permission requirements

## API Reference
- REST endpoints
- Channel subscriptions
- Job classes

## Configuration
- Environment variables
- Settings and preferences

## Integration Points
- Dependencies on other systems
- External service integrations

## Performance Considerations
- Caching strategies
- N+1 query prevention
- Background job usage

## Security Considerations
- Authorization requirements
- Data protection
- Privacy controls

## Testing Guide
- Key test scenarios
- Example tests

## Troubleshooting
- Common issues
- Debugging tips

## Related Documentation
- Links to related system docs
- Relevant diagrams
```

---

**End of Architectural Analysis**

*This document serves as the foundation for comprehensive system documentation, diagram creation, and developer onboarding materials for the Better Together Community Engine.*
