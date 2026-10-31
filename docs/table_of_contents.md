# Better Together Community Engine - Documentation Table of Contents

Welcome to the comprehensive documentation for the Better Together Community Engine. This documentation is organized by stakeholder groups to help you quickly find relevant information.

## Quick Navigation

### **Main Entry Points**
- [Main README](README.md) - Project overview and getting started
- [This Table of Contents](table_of_contents.md) - Complete documentation index
- [Contributing Guide](../CONTRIBUTING.md) - How to contribute
- [Code of Conduct](../CODE_OF_CONDUCT.md) - Community expectations

### **Stakeholder Documentation**

#### **End Users** - [`end_users/`](end_users/)
*Community members using the platform*
- [README](end_users/README.md) - User documentation overview
- [User Guide](end_users/guide.md) - How to use the platform
- [Welcome Guide](end_users/welcome.md) - Getting started for new users
- [Exchange Process](end_users/exchange_process.md) - How to participate in exchanges
- [Event Invitations & RSVP](end_users/events_invitations_and_rsvp.md) - Responding to invitations and managing attendance
- [Safety and Reporting Tools](end_users/safety_reporting.md) - Main safety guide
- [Blocking and Boundaries](end_users/blocking_and_boundaries.md) - User blocking and boundaries guide
- [Reporting Harm and Safety Concerns](end_users/reporting_harm_and_safety_concerns.md) - Reporting guide
- [After You Report](end_users/after_you_report.md) - What happens after submission
- [Privacy and Safety Preferences](end_users/privacy_and_safety_preferences.md) - Privacy and safety choices
- [Emergency and Urgent Situations](end_users/emergency_and_urgent_situations.md) - Emergency boundary guidance
- [Message Requests and Linked Access](end_users/message_requests_and_linked_access.md) - Message requests, messaging permissions, person links and access grants

#### **Community Organizers** - [`community_organizers/`](community_organizers/)
*People managing and growing communities*
- [README](community_organizers/README.md) - Community organizer resources
- [Community Management](community_organizers/community_management.md) - Tools and best practices
- [Event Invitations Management](community_organizers/event_invitations_management.md) - Invite members/emails and manage delivery

#### **Platform Organizers** - [`platform_organizers/`](platform_organizers/)
*Multi-tenant administrators and platform operators*
- [README](platform_organizers/README.md) - Platform administration guide
- [Embedded Content & CSP Controls](platform_organizers/embedded_content_and_csp.md) - Trusted iframe/video origin management
- [Host Management](platform_organizers/host_management.md) - Managing platform instances
- [Host Dashboard Extensions](platform_organizers/host_dashboard_extensions.md) - Custom dashboard features
- [GitHub Integration Setup](platform_organizers/github_integration_setup.md) - Configure GitHub OAuth and API access
- [Federation Privacy and Consent](platform_organizers/federation_privacy_and_consent.md) - Safe operation of platform-to-platform trust
- [Short Links](platform_organizers/short_links.md) - Short share links, expiry and visit tracking
- [Content Security and Malware Scanning](platform_organizers/content_security_and_malware_scanning.md) - ClamAV scanning, held uploads and review

#### **Developers** - [`developers/`](developers/)
*Technical documentation for contributors and maintainers*
- [README](developers/README.md) - Developer documentation overview

##### **Systems Documentation** - [`developers/systems/`](developers/systems/)
- [Accounts and Invitations](developers/systems/accounts_and_invitations.md) - User account management
- [Actor-Safe Creator and Authorship Migration Plan](developers/systems/actor_safe_creator_authorship_migration_plan.md) - Phased path toward governed-agent-safe creator and authorship models
- [Caching Performance System](developers/systems/caching_performance_system.md) - Performance optimization
- [Community Action Network Governance System](developers/systems/community_action_network_governance_system.md) - Constitutional governance model for people, bots, and shared resources
- [Contribution Attribution System](developers/systems/contribution_attribution_system.md) - Governed contributor roles, contribution types, and structured attribution details
- [Public Publishing Agreement Gate System](developers/systems/public_publishing_agreement_gate_system.md) - Enforced agreement acceptance before governed public visibility
- [PR 1494 Scope Consolidation](developers/systems/pr_1494_scope_consolidation.md) - Cut line for governed publishing, contribution, and evidence scope in PR 1494
- [Robot Author Identity System](developers/systems/robot_author_identity_system.md) - Proposed model for truthful robot authorship on governed content
- [Community Social System](developers/systems/community_social_system.md) - Social features
- [Content Management](developers/systems/content_management.md) - Content creation and management
- [Conversations Messaging System](developers/systems/conversations_messaging_system.md) - Real-time messaging
- [Conversations README](developers/systems/README_conversations.md) - Messaging system overview
- [Events System](developers/systems/events_system.md) - Event management
- [Event Invitations & Attendance](developers/systems/event_invitations_and_attendance.md) - Invitations, tokens, RSVP
- [Federation System](developers/systems/federation_system.md) - Platform connections, scopes, and sync
- [Geography System](developers/systems/geography_system.md) - Location and mapping
- [Settlement naming and wording assessment](assessments/settlement_to_town_rename_assessment.md) - Why "Settlement" stays, where the gloss lives, and the edit-point map for a future rename
- [I18n Mobility Localization System](developers/systems/i18n_mobility_localization_system.md) - Internationalization
- [Metrics System](developers/systems/metrics_system.md) - Analytics and reporting
- [Navigation System](developers/systems/navigation_system.md) - Site navigation
- [Notifications System](developers/systems/notifications_system.md) - Notification delivery
- [Search Backend Adapter System](developers/systems/search_backend_adapter_system.md) - Adapterized backend selection across pg_search (default) and database search modes, with Elasticsearch as an optional extension gem
- [Robot Authored Page And Post Publishing](developers/systems/robot_authored_page_post_publishing_system.md) - Narrow workflow for truthful robot bylines on pages and posts
- [Security Protection System](developers/systems/security_protection_system.md) - Security measures
- [Short Links System](developers/systems/short_links_system.md) - Short URLs, redirect, visit tracking
- [Person Links, Access Grants and Messaging Permissions](developers/systems/person_links_grants_and_messaging_system.md) - Message requests, messaging grants, cross-platform person links
- [Seed Catalog and Seed Plantings](developers/systems/seed_catalog_and_plantings_system.md) - On-demand reference data and planting audit records
- [Event Recurrence and Occurrences](developers/systems/event_recurrence_and_occurrences_system.md) - Recurrence rules and lazily created occurrence overrides
- [Event Series and Sessions](event-series-and-sessions-design.md) - Series that group the dates of a run, with the API and the cancel or delete choice
- [Person Deletion Requests and Purge Audits](developers/systems/person_deletion_and_purge_audit_system.md) - Anonymizing and hard deletion with audit records
- [Content Security Ingress System](developers/systems/content_security_ingress_system.md) - Attachment gating, malware scanning, review records
- [Safety and Federation Review Workflow](developers/systems/safety_and_federation_review_workflow.md) - Reviewer surfaces, safety cases, actions and notes

##### **Billing** - [`billing/`](billing/)
- [Billing Foundation and Processor Adapters](billing/processor-adapters.md) - Vendor-neutral billing core, host configuration and the adapter contract
- [Billing Notifications](billing/notifications.md) - Who is told what about orders, payments and billing operations, never twice, never with payment details
- [Billing Purchase Agreements](billing/purchase_agreements.md) - Which agreements a buyer accepts before paying, how they are chosen, and where they apply in the flow
- [Billing Orders and Payments](billing/orders_and_payments.md) - Orders, lines, payments and refunds, and how an order's status moves
- [Billing Offline Payment Methods](billing/offline_payment_methods.md) - Paying a seller directly by cash, cheque or e-transfer: the buyer's screen, the seller's confirmation (no buyer claim needed), late payments, sales in person
- [Billing Payment Methods](billing/payment_methods.md) - Cash, cheque and e-transfer: how a seller turns them on, what buyers are told, the limits
- [Billing Plan Catalog](billing/plan_catalog.md) - Plans, creating them at the processor, fields the processor fixes, async option lists
- [Billing Platform Isolation](billing/platform_isolation.md) - How billing records are bound to exactly one platform
- [Billing Data Encryption](billing/encryption.md) - What is encrypted at rest, the rules, and key rotation
- [Hosted Billing Roadmap](billing/hosted_billing_roadmap.md) - What is in place for per-platform processors and community-managed plans, and what is left

##### **Architecture Documentation** - [`developers/architecture/`](developers/architecture/)
- [Models and Concerns](developers/architecture/models_and_concerns.md) - Data model architecture
- [Model Concerns Reference](reference/model_concerns_reference.md) - Concerns new or changed in 0.11.0
- [Polymorphic and STI](developers/architecture/polymorphic_and_sti.md) - Database design patterns
- [RBAC Overview](developers/architecture/rbac_overview.md) - Role-based access control

##### **Development Resources** - [`developers/development/`](developers/development/)
- [Automatic Test Configuration](developers/development/automatic_test_configuration.md) - Automated test setup and authentication
- [Diagram Rendering](developers/development/diagram_rendering.md) - Documentation diagram system
- [I18n TODO](developers/development/i18n_todo.md) - Internationalization tasks

##### **API Integrations** - [`developers/`](developers/)
- [GitHub API Integration](developers/github_api_integration.md) - OAuth-based GitHub API access with Octokit

#### **Support Staff** - [`support_staff/`](support_staff/)
*Customer support and troubleshooting resources*
- [README](support_staff/README.md) - Support documentation overview

#### **Content Moderators** - [`content_moderators/`](content_moderators/)
*Content moderation tools and guidelines*
- [README](content_moderators/README.md) - Content moderation guide

#### **Legal Compliance** - [`legal_compliance/`](legal_compliance/)
*Legal, privacy, and compliance documentation*
- [README](legal_compliance/README.md) - Legal compliance overview

### **Specialized Documentation**

#### **Shared Resources** - [`shared/`](shared/)
*Cross-cutting documentation relevant to multiple stakeholder groups*
- [README](shared/README.md) - Shared resources overview
- [Democratic By Design](shared/democratic_by_design.md) - Platform governance principles
- [Democratic Principles](shared/democratic_principles.md) - Community governance
- [Roles and Permissions](shared/roles_and_permissions.md) - Access control system
- [Escalation Matrix](shared/escalation_matrix.md) - Issue resolution procedures
- [Privacy Principles](shared/privacy_principles.md) - Privacy policy and practices
- [Documentation Accessibility Rubric](shared/documentation_accessibility_rubric.md) - Standards for user docs, inline help, and hints
- [Sitemap Generation System](shared/sitemap_generation_system.md) - Multi-locale XML sitemap generation

#### **Implementation** - [`implementation/`](implementation/)
*Project management, planning, and templates*
- [README](implementation/README.md) - Implementation resources overview

#### **Release Notes** - [`releases/`](releases/)
*Release summaries and coverage checks*
- [0.11.0 Release Overview](releases/0.11.0.md) - `0.10.0` to current `main`, including late release-candidate fixes

##### **Current Plans** - [`implementation/current_plans/`](implementation/current_plans/)
- [Community Social System Acceptance Criteria](implementation/current_plans/community_social_system_acceptance_criteria.md)
- [Community Social System Implementation Plan](implementation/current_plans/community_social_system_implementation_plan.md)
- [Sitemap Generator Fixes Implementation Plan](implementation/current_plans/sitemap_generator_fixes_implementation_plan.md)

##### **Completed Work** - [`implementation/completed_work/`](implementation/completed_work/)
- [Sitemap Multi-Locale Implementation Summary](implementation/completed_work/sitemap_multi_locale_implementation_summary.md)

##### **Templates** - [`implementation/templates/`](implementation/templates/)
- [Implementation Plan Template](implementation/templates/implementation_plan_template.md) - Standard planning template
- [System Documentation Template](implementation/templates/system_documentation_template.md) - Documentation standards
- [TDD Acceptance Criteria Template](implementation/templates/tdd_acceptance_criteria_template.md) - Testing templates

#### **Visual Documentation** - [`diagrams/`](diagrams/)
*Mermaid diagrams and visual system documentation*
- [README](diagrams/README.md) - Diagram system overview

##### **Diagram Sources** - [`diagrams/source/`](diagrams/source/)
*Mermaid (.mmd) source files*
- [Accounts Flow](diagrams/source/accounts_flow.mmd)
- [Agreements System Flow](diagrams/source/agreements_system_flow.mmd)
- [Billing Event Pipeline Flow](diagrams/source/billing_event_pipeline_flow.mmd)
- [Billing Notification Flow](diagrams/source/billing_notification_flow.mmd)
- [Billing Offline Payment State Machine](diagrams/source/billing_offline_payment_state_machine.mmd)
- [Billing Order Lifecycle Flow](diagrams/source/billing_order_lifecycle_flow.mmd)
- [Billing Payment Methods Model](diagrams/source/billing_payment_methods_model.mmd)
- [Billing Plan Processor Sync Flow](diagrams/source/billing_plan_processor_sync_flow.mmd)
- [Billing Processor Adapter Contract Model](diagrams/source/billing_processor_adapter_contract_model.mmd)
- [Billing Purchase Agreement Flow](diagrams/source/billing_purchase_agreement_flow.mmd)
- [Billing Queue Topology](diagrams/source/billing_queue_topology.mmd)
- [Billing Schema ERD](diagrams/source/billing_schema_erd.mmd)
- [Billing Tenancy and Ownership Model](diagrams/source/billing_tenancy_and_ownership_model.mmd)
- [⚡ Caching Performance Flow](diagrams/source/caching_performance_flow.mmd)
- [Community Action Network Governance Flow](diagrams/source/community_action_network_governance_flow.mmd)
- [Community Social System Flow](diagrams/source/community_social_system_flow.mmd)
- [Content Flow](diagrams/source/content_flow.mmd)
- [Conversations Messaging Flow](diagrams/source/conversations_messaging_flow.mmd)
- [Documentation System Flow](diagrams/source/documentation_system_flow.mmd)
- [Events Flow](diagrams/source/events_flow.mmd)
- [Exchange Flow](diagrams/source/exchange_flow.mmd)
- [Geography System Flow](diagrams/source/geography_system_flow.mmd)
- [I18n Mobility Localization Flow](diagrams/source/i18n_mobility_localization_flow.mmd)
- [Metrics Flow](diagrams/source/metrics_flow.mmd)
- [Navigation Flow](diagrams/source/navigation_flow.mmd)
- [Notifications Flow](diagrams/source/notifications_flow.mmd)
- [PR 1479 Search Backend Architecture](diagrams/source/pr_1479_search_backend_architecture.mmd)
- [PR 1479 Search Backend Flow](diagrams/source/pr_1479_search_backend_flow.mmd)
- [PR 1479 Search Backend Process](diagrams/source/pr_1479_search_backend_process.mmd)
- [PR 1496 Robot Authored Page And Post Flow](diagrams/source/pr_1496_robot_authored_page_post_flow.mmd)
- [0.11.0 Release Capability Map](diagrams/source/release_0_11_0_capability_map.mmd)
- [Role Based Access Control Flow](diagrams/source/role_based_access_control_flow.mmd)
- [Security Protection Flow](diagrams/source/security_protection_flow.mmd)
- [Sitemap Generation Flow](diagrams/source/sitemap_generation_flow.mmd)

##### **Conceptual Diagrams** - [`diagrams/source/`](diagrams/source/)
- [Democratic by Design Map](diagrams/source/democratic_by_design_map.mmd)
- [Models and Concerns Diagram](diagrams/source/models_and_concerns_diagram.mmd)

##### **Exported Diagrams**
- **PNG Exports**: [`diagrams/exports/png/`](diagrams/exports/png/) - High-resolution PNG files
- **SVG Exports**: [`diagrams/exports/svg/`](diagrams/exports/svg/) - Vector graphics files

#### **UI Documentation** - [`ui/`](ui/)
*User interface and design documentation*
- [Help Banners](ui/help-banners.md) - UI help system
- [Navigation Sidebar Guide](ui/navigation_sidebar_guide.md) - Navigation design
- [Resource Toolbar](ui/resource_toolbar.md) - Toolbar documentation

#### **Production** - [`production/`](production/)
*Deployment and production environment documentation*
- [Deployment (Dokku)](production/deployment-dokku.md) - Production deployment guide
- [Multi-Platform Deployment](production/multi_platform_deployment.md) - Running multiple platforms on a single instance
- [⚙️ External Services Configuration](production/external-services-to-configure.md) - Third-party integrations
- [Raspberry Pi Setup](production/raspberry-pi-setup.md) - Self-hosting guide
- [Billing Queue Rollout](production/billing_queue_rollout.md) - Dedicated high-priority Sidekiq queue and capsule for payment jobs

#### **Scripts** - [`scripts/`](scripts/)
*Documentation maintenance and automation scripts*
- [Create Stakeholder Structure](scripts/create_stakeholder_structure.sh) - Documentation reorganization
- [Migrate Diagrams](scripts/migrate_diagrams_to_new_structure.sh) - Diagram migration utility
- [✅ Validate Documentation Tooling](scripts/validate_documentation_tooling.sh) - Validation suite
- [Update Progress](scripts/update_progress.sh) - Progress tracking utility

### **Development and Reference**

#### **Development** - [`development/`](development/)
*Development setup and configuration*
- [README](development/README.md) - Development resources overview
- [Development Setup](development/dev-setup.md) - Local development guide
- [Cloud Agent Session Environment](development/cloud_session_environment.md) - Running dev/test in Claude Code cloud sessions (`bin/cloud-session-env`)
- [♿ Accessibility Testing](development/accessibility_testing.md) - Browser accessibility and screenshot testing guidance
- [Pull Request Evidence Standard](development/pull_request_evidence_standard.md) - Tiered evidence requirements for PR docs, diagrams, and screenshots
- [Screenshot And Documentation Tooling Assessment](development/screenshot_and_documentation_tooling_assessment.md) - CE and management-tool tooling assessment
- [Community Subtypes](development/community_subtypes.md) - Host app Community subtypes, role scoping and the Resourceful registry

#### **Joatu Exchange System** - [`joatu/`](joatu/)
*Specialized exchange/marketplace functionality*
- [README](joatu/README.md) - Joatu system overview
- [Agreements](joatu/agreements.md) - Exchange agreements
- [Categories](joatu/categories.md) - Item categorization
- [Matching and Notifications](joatu/matching-and-notifications.md) - Matching system
- [Offers](joatu/offers.md) - Offer management
- [Requests](joatu/requests.md) - Request management

#### **Meta Documentation** - [`meta/`](meta/)
*Documentation about documentation - project management and organization*
- [README](meta/README.md) - Meta documentation overview
- [Documentation Assessment](meta/documentation_assessment.md) - Documentation quality metrics
- [Documentation Inventory](meta/documentation_inventory.md) - Complete file inventory
- [Documentation Restructure Plan](meta/documentation_restructure_plan.md) - Reorganization planning
- [Stakeholder Documentation Structure](meta/stakeholder_documentation_structure.md) - Organizational design

---

## Documentation Statistics

- **Total Documentation Files**: 55+ markdown files
- **Stakeholder Groups**: 7 primary categories
- **System Documentation**: 13 major systems covered
- **Visual Diagrams**: 18 Mermaid diagrams with PNG/SVG exports
- **Implementation Resources**: Templates, plans, and current work
- **Specialized Sections**: UI, Production, Scripts, Reference, Meta

## Maintenance

This table of contents is automatically maintained. When adding new documentation or diagrams:

1. **Update this file** to include new entries in the appropriate section
2. **Run diagram rendering** with `bin/render_diagrams` for new .mmd files
3. **Update progress tracking** with `docs/scripts/update_progress.sh`
4. **Follow documentation standards** using templates in `implementation/templates/`

---

*Last Updated: August 22, 2025*
*Documentation Structure: Stakeholder-Focused Organization*
*Diagram Integration: GitHub-compatible Mermaid rendering with multi-format exports*
