# Better Together Community Engine - Database Documentation Inventory

## Overview

This document provides a comprehensive inventory of all database tables in the Better Together Community Engine, categorizing them by system/domain and tracking documentation completion status. Based on the schema.rb analysis, we have identified **75 total tables** across **15 major system domains**.

## Documentation Status Summary

### ✅ **Completed Documentation** (4 systems, 28 tables)
- **I18n/Mobility System**: Comprehensive documentation with process flow
- **Caching/Performance System**: Architecture and optimization documentation  
- **Security/Protection System**: Defense-in-depth architecture documentation
- **Geography System**: PostGIS spatial system with mapping documentation

### 🔄 **Partially Documented** (3 systems, 8 tables)
- **Event System**: Basic model coverage, needs comprehensive system documentation
- **Infrastructure System**: Basic building/room models, needs full architectural documentation
- **Joatu Exchange System**: Models exist but need complete workflow documentation

### 📋 **Pending Documentation** (8 systems, 39 tables)
- Major systems requiring comprehensive documentation and process flows

---

## Detailed Table Inventory by System

### ✅ **1. I18n & Mobility System** - DOCUMENTED
**Tables (4):**
- `mobility_string_translations` - String translation storage
- `mobility_text_translations` - Rich text translation storage  
- `action_text_rich_texts` - Action Text content storage
- `better_together_ai_log_translations` - AI translation logging

**Documentation Status:** ✅ Complete
- **File:** `docs/i18n_mobility_localization_system.md` (400+ lines)
- **Diagram:** `docs/i18n_mobility_localization_system_flow.{mmd,png,svg}`
- **Coverage:** Translation backends, AI integration, UI components, performance optimization

---

### ✅ **2. Security & Authentication System** - DOCUMENTED  
**Tables (2):**
- `better_together_jwt_denylists` - JWT token blacklisting
- `better_together_users` - User authentication data

**Documentation Status:** ✅ Complete
- **File:** `docs/security_protection_system.md` (15,800+ bytes)
- **Diagram:** `docs/security_protection_system_flow.{mmd,png,svg}`
- **Coverage:** Authentication, authorization, encryption, rate limiting, defense-in-depth

---

### ✅ **3. Geography & Location System** - DOCUMENTED
**Tables (10):**
- `better_together_geography_continents` - Continental divisions
- `better_together_geography_countries` - National entities with ISO codes
- `better_together_geography_states` - State/provincial divisions
- `better_together_geography_regions` - Custom regional divisions
- `better_together_geography_settlements` - Cities and towns
- `better_together_geography_country_continents` - Continent-country relationships
- `better_together_geography_region_settlements` - Region-settlement relationships
- `better_together_geography_spaces` - Coordinate storage (lat/lng/elevation)
- `better_together_geography_geospatial_spaces` - Polymorphic location joins
- `better_together_geography_locatable_locations` - Flexible location management
- `better_together_geography_maps` - Interactive mapping with PostGIS
- `better_together_addresses` - Structured address information

**Documentation Status:** ✅ Complete  
- **File:** `docs/geography_system.md` (15,000+ characters)
- **Diagram:** `docs/geography_system_flow.{mmd,png,svg}`
- **Coverage:** PostGIS integration, geocoding pipeline, hierarchical organization, mapping

---

### ✅ **4. Performance & Caching System** - DOCUMENTED
**Tables (0 - Configuration/Infrastructure focused):**
- Redis integration (external)
- Elasticsearch integration (external)
- Rails caching framework
- Sidekiq job processing

**Documentation Status:** ✅ Complete
- **File:** `docs/caching_performance_system.md` (12,822+ bytes)
- **Diagram:** `docs/caching_performance_system_flow.{mmd,png,svg}`
- **Coverage:** Multi-layer caching, search optimization, background processing

---

### 🔄 **5. Event & Calendar System** - PARTIALLY DOCUMENTED
**Tables (4):**
- `better_together_events` - Event management and scheduling
- `better_together_event_attendances` - Event attendance tracking
- `better_together_event_hosts` - Event host relationships
- `better_together_calendars` - Calendar containers
- `better_together_calendar_entries` - Calendar entry management

**Documentation Status:** 🔄 Partial (models exist, needs system documentation)
- **Needs:** Complete event lifecycle documentation, notification workflows, calendar integration

---

### 🔄 **6. Infrastructure & Building System** - PARTIALLY DOCUMENTED  
**Tables (4):**
- `better_together_infrastructure_buildings` - Building management
- `better_together_infrastructure_floors` - Floor organization
- `better_together_infrastructure_rooms` - Room/space management
- `better_together_infrastructure_building_connections` - Inter-building relationships

**Documentation Status:** 🔄 Partial (basic models)
- **Needs:** Complete building management system documentation, space allocation workflows

---

### 🔄 **7. Joatu Exchange System** - PARTIALLY DOCUMENTED
**Tables (4):**
- `better_together_joatu_offers` - Marketplace offers
- `better_together_joatu_requests` - Service/item requests  
- `better_together_joatu_agreements` - Exchange agreements
- `better_together_joatu_response_links` - Response tracking

**Documentation Status:** 🔄 Partial (models exist)
- **Needs:** Complete exchange workflow documentation, agreement lifecycle, notification integration

---

### 📋 **8. Community & Social System** - NEEDS DOCUMENTATION
**Tables (8):**
- `better_together_communities` - Community entities
- `better_together_person_community_memberships` - Community membership
- `better_together_platforms` - Multi-tenant platforms
- `better_together_person_platform_memberships` - Platform membership  
- `better_together_platform_invitations` - Platform invitation system
- `better_together_people` - Person entities
- `better_together_identifications` - Identity management
- `better_together_invitations` - General invitation system

**Priority:** 🔥 **HIGH** - Core social functionality
**Estimated Scope:** Major system (500+ lines documentation)

---

### 📋 **9. Content Management System** - NEEDS DOCUMENTATION  
**Tables (9):**
- `better_together_content_blocks` - Modular content blocks
- `better_together_pages` - Page management
- `better_together_posts` - Blog/article posts
- `better_together_content_page_blocks` - Page-block relationships
- `better_together_content_platform_blocks` - Platform-block relationships
- `better_together_authorships` - Content authorship tracking
- `better_together_uploads` - File upload management
- `active_storage_*` (3 tables) - File attachment system

**Priority:** 🔥 **HIGH** - Core content functionality  
**Estimated Scope:** Major system (400+ lines documentation)

---

### 📋 **10. Communication & Messaging System** - NEEDS DOCUMENTATION
**Tables (4):**
- `better_together_conversations` - Conversation management
- `better_together_conversation_participants` - Conversation membership
- `better_together_messages` - Message storage
- `noticed_events` - Notification events
- `noticed_notifications` - Notification delivery

**Priority:** 🔥 **HIGH** - Core communication functionality
**Estimated Scope:** Major system (350+ lines documentation)

---

### 📋 **11. Contact & Relationship Management** - NEEDS DOCUMENTATION
**Tables (6):**
- `better_together_contact_details` - Contact information containers
- `better_together_email_addresses` - Email management
- `better_together_phone_numbers` - Phone number management  
- `better_together_social_media_accounts` - Social media links
- `better_together_website_links` - Website URL management
- `better_together_places` - Location associations

**Priority:** 🟡 **MEDIUM** - Supporting functionality
**Estimated Scope:** Medium system (300+ lines documentation)

---

### 📋 **12. Navigation & UI System** - NEEDS DOCUMENTATION
**Tables (2):**
- `better_together_navigation_areas` - Navigation section management
- `better_together_navigation_items` - Navigation menu items

**Priority:** 🟡 **MEDIUM** - UI infrastructure
**Estimated Scope:** Small system (200+ lines documentation)

---

### 📋 **13. Workflow & Process Management** - NEEDS DOCUMENTATION
**Tables (4):**
- `better_together_wizards` - Multi-step workflow containers
- `better_together_wizard_step_definitions` - Workflow step templates
- `better_together_wizard_steps` - User workflow progress
- `better_together_calls_for_interest` - Interest expression system

**Priority:** 🟡 **MEDIUM** - Process automation
**Estimated Scope:** Medium system (250+ lines documentation)

---

### 📋 **14. Analytics & Metrics System** - NEEDS DOCUMENTATION
**Tables (7):**
- `better_together_metrics_page_views` - Page view tracking
- `better_together_metrics_page_view_reports` - Page view analytics
- `better_together_metrics_link_clicks` - Link interaction tracking
- `better_together_metrics_link_click_reports` - Click analytics
- `better_together_metrics_downloads` - Download tracking
- `better_together_metrics_search_queries` - Search analytics
- `better_together_metrics_shares` - Content sharing metrics

**Priority:** 🟡 **MEDIUM** - Analytics infrastructure  
**Estimated Scope:** Medium system (300+ lines documentation)

---

### 📋 **15. Content Organization & Taxonomy** - NEEDS DOCUMENTATION
**Tables (8):**
- `better_together_categories` - Hierarchical categorization
- `better_together_categorizations` - Content-category relationships
- `better_together_comments` - Comment system
- `better_together_activities` - Activity stream/feed
- `better_together_reports` - Content reporting system
- `better_together_roles` - Role-based access control
- `better_together_role_resource_permissions` - Role permissions
- `better_together_resource_permissions` - Resource-level permissions

**Priority:** 🟡 **MEDIUM** - Content organization
**Estimated Scope:** Medium system (350+ lines documentation)

---

### 📋 **16. Agreement & Legal System** - NEEDS DOCUMENTATION
**Tables (3):**
- `better_together_agreements` - Legal agreement management
- `better_together_agreement_participants` - Agreement parties
- `better_together_agreement_terms` - Agreement term details

**Priority:** 🔴 **LOW** - Specialized functionality
**Estimated Scope:** Small system (200+ lines documentation)

---

### 📋 **17. Support Systems** - NEEDS DOCUMENTATION
**Tables (4):**
- `better_together_person_blocks` - User blocking system
- `friendly_id_slugs` - URL slug management
- `better_together_identifications` - Identity verification
- Various audit/tracking columns across all tables

**Priority:** 🔴 **LOW** - Infrastructure support
**Estimated Scope:** Small system (150+ lines documentation)

---

## Documentation Expansion Plan

### **Phase 1: Core Social & Content Systems** (Priority: 🔥 HIGH)
**Timeline:** 4-6 weeks  
**Deliverables:**
1. **Community & Social System Documentation**
   - Community lifecycle, membership management, multi-tenancy
   - Process flow for community creation, invitation, and governance
   - 500+ lines comprehensive documentation

2. **Content Management System Documentation**  
   - Content block architecture, page builder, authorship tracking
   - File upload integration with Active Storage
   - 400+ lines with content workflow diagrams

3. **Communication & Messaging System Documentation**
   - Conversation threading, notification integration
   - Message delivery patterns, real-time features
   - 350+ lines with messaging flow diagrams

### **Phase 2: Event & Exchange Systems** (Priority: 🔥 HIGH)  
**Timeline:** 3-4 weeks
**Deliverables:**
4. **Event & Calendar System Documentation** (Complete existing partial work)
   - Event lifecycle, attendance management, calendar integration
   - Notification workflows, recurring events
   - 300+ lines with event workflow diagrams

5. **Joatu Exchange System Documentation** (Complete existing partial work)
   - Marketplace mechanics, agreement lifecycle, response tracking
   - Exchange workflows, dispute resolution
   - 350+ lines with exchange process flows

6. **Infrastructure & Building System Documentation** (Complete existing partial work)
   - Building/room management, space allocation
   - Connection management, resource booking
   - 250+ lines with facility management flows

### **Phase 3: Supporting Systems** (Priority: 🟡 MEDIUM)
**Timeline:** 4-5 weeks  
**Deliverables:**
7. **Contact & Relationship Management Documentation**
   - Contact aggregation, communication preferences
   - Multi-channel contact management
   - 300+ lines documentation

8. **Analytics & Metrics System Documentation**
   - Data collection, reporting, privacy compliance  
   - Performance metrics, user analytics
   - 300+ lines with analytics flow diagrams

9. **Content Organization & Taxonomy Documentation**
   - Category hierarchy, content tagging, activity streams
   - Role-based permissions, content moderation
   - 350+ lines documentation

10. **Workflow & Process Management Documentation**
    - Wizard-based workflows, step management
    - Interest capture, process automation
    - 250+ lines with workflow diagrams

### **Phase 4: Infrastructure & Support Systems** (Priority: 🟡-🔴 MEDIUM/LOW)
**Timeline:** 2-3 weeks
**Deliverables:**
11. **Navigation & UI System Documentation**
    - Dynamic navigation, menu management
    - 200+ lines documentation

12. **Agreement & Legal System Documentation**
    - Legal agreement lifecycle, participant management
    - 200+ lines documentation

13. **Support Systems Documentation**
    - User blocking, slug management, identity verification
    - 150+ lines documentation

---

## Success Metrics

### **Documentation Quality Standards**
- **Minimum 200 lines** comprehensive technical documentation per system
- **Process flow diagram** with Mermaid source, PNG, and SVG outputs
- **Implementation examples** with code snippets and configuration
- **API endpoint documentation** where applicable
- **Performance considerations** and optimization strategies
- **Security implications** and best practices
- **Troubleshooting guides** with common issues

### **Completion Tracking**
- **Current Status:** 4/15 systems fully documented (27% complete)
- **Phase 1 Target:** 7/15 systems (47% complete) 
- **Phase 2 Target:** 10/15 systems (67% complete)
- **Phase 3 Target:** 14/15 systems (93% complete)
- **Phase 4 Target:** 15/15 systems (100% complete)

### **Documentation Metrics**
- **Total Tables:** 75
- **Currently Documented:** 28 tables (37%)
- **Final Target:** 75 tables (100%)
- **Estimated Final Documentation:** 4,000+ lines across 15 system documents
- **Estimated Diagrams:** 15 process flow diagrams with multiple output formats

---

## Resource Requirements

### **Development Time Estimate**
- **Total Effort:** 13-18 weeks for complete documentation
- **Average per System:** 1-2 weeks depending on complexity
- **High Priority Systems:** 2-3 weeks each (complex workflows)
- **Medium/Low Priority:** 1-2 weeks each (simpler systems)

### **Technical Requirements**
- **Mermaid CLI** for diagram generation
- **Schema analysis tools** for database exploration  
- **Code exploration tools** for system understanding
- **Documentation validation** for consistency checks

This inventory provides a clear roadmap for achieving comprehensive system documentation across all Better Together Community Engine components, prioritized by business importance and system complexity.
