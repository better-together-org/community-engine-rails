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

#### **Community Organizers** - [`community_organizers/`](community_organizers/)
*People managing and growing communities*
- [README](community_organizers/README.md) - Community organizer resources
- [Community Management](community_organizers/community_management.md) - Tools and best practices
- [Event Invitations Management](community_organizers/event_invitations_management.md) - Invite members/emails and manage delivery

#### **Platform Organizers** - [`platform_organizers/`](platform_organizers/)
*Multi-tenant administrators and platform operators*
- [README](platform_organizers/README.md) - Platform administration guide
- [End-to-End Encryption Rollout](platform_organizers/e2e_encryption_rollout.md) - Encrypted-conversation rollout and support guide
- [Embedded Content & CSP Controls](platform_organizers/embedded_content_and_csp.md) - Trusted iframe/video origin management
- [Host Management](platform_organizers/host_management.md) - Managing platform instances
- [Host Dashboard Extensions](platform_organizers/host_dashboard_extensions.md) - Custom dashboard features
- [GitHub Integration Setup](platform_organizers/github_integration_setup.md) - Configure GitHub OAuth and API access
- [Federation Privacy and Consent](platform_organizers/federation_privacy_and_consent.md) - Safe operation of platform-to-platform trust

#### **Developers** - [`developers/`](developers/)
*Technical documentation for contributors and maintainers*
- [README](developers/README.md) - Developer documentation overview

##### **Systems Documentation** - [`developers/systems/`](developers/systems/)
- [Accounts and Invitations](developers/systems/accounts_and_invitations.md) - User account management
- [Caching Performance System](developers/systems/caching_performance_system.md) - Performance optimization
- [Community Social System](developers/systems/community_social_system.md) - Social features
- [Content Management](developers/systems/content_management.md) - Content creation and management
- [Conversations Messaging System](developers/systems/conversations_messaging_system.md) - Real-time messaging
- [Conversations README](developers/systems/README_conversations.md) - Messaging system overview
- [Events System](developers/systems/events_system.md) - Event management
- [Event Invitations & Attendance](developers/systems/event_invitations_and_attendance.md) - Invitations, tokens, RSVP
- [Federation System](developers/systems/federation_system.md) - Platform connections, scopes, and sync
- [Geography System](developers/systems/geography_system.md) - Location and mapping
- [I18n Mobility Localization System](developers/systems/i18n_mobility_localization_system.md) - Internationalization
- [Metrics System](developers/systems/metrics_system.md) - Analytics and reporting
- [Navigation System](developers/systems/navigation_system.md) - Site navigation
- [Notifications System](developers/systems/notifications_system.md) - Notification delivery
- [Robot Authored Page And Post Publishing](developers/systems/robot_authored_page_post_publishing_system.md) - Narrow workflow for truthful robot bylines on pages and posts
- [Security Protection System](developers/systems/security_protection_system.md) - Security measures

##### **Architecture Documentation** - [`developers/architecture/`](developers/architecture/)
- [Models and Concerns](developers/architecture/models_and_concerns.md) - Data model architecture
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

#### 🧭 **Workshop** - [`workshop/`](workshop/)
- [📘 Index](workshop/index.md) - Course overview and materials
- [🖨️ Intro Agenda (Printable)](workshop/intro_agenda_printable.md)
- [🖼️ Intro Slides Outline](workshop/intro_slides_outline.md)
- [🎞️ Intro Slides (Reveal.js Markdown)](workshop/slides/intro_slides.md)
  - [Slides: Module 00](workshop/slides/module_00.md)
  - [Slides: Module 01](workshop/slides/module_01.md)
  - [Slides: Module 02](workshop/slides/module_02.md)
  - [Slides: Module 03](workshop/slides/module_03.md)
  - [Slides: Module 04](workshop/slides/module_04.md)
  - [Slides: Module 05](workshop/slides/module_05.md)
  - [Slides: Module 06](workshop/slides/module_06.md)
  - [Slides: Module 07](workshop/slides/module_07.md)
  - [Slides: Module 08](workshop/slides/module_08.md)
- [🧑‍🏫 Facilitator Notes: Intro Workshop](workshop/facilitator_notes_intro_workshop.md)
  - [📝 Per‑Module Notes](workshop/facilitator_notes/)
- [🧭 Module 00: Orientation](workshop/module_00_orientation.md)
- [🏗️ Module 01: Big Picture Architecture](workshop/module_01_big_picture_architecture.md)
- [💻 Module 02: Local Setup (Docker)](workshop/module_02_local_setup.md)
- [🧱 Module 03: Data & Conventions](workshop/module_03_data_and_conventions.md)
- [🔐 Module 04: Authorization & Privacy](workshop/module_04_authorization_and_privacy.md)
- [🌍 Module 05: I18n & UI](workshop/module_05_i18n_and_ui.md)
- [📣 Module 06: Jobs, Notifications, Search](workshop/module_06_jobs_notifications_search.md)
- [🧪 Module 07: Testing, CI, Security](workshop/module_07_testing_ci_security.md)
- [🚀 Module 08: Deployments & Day‑2 Ops](workshop/module_08_deployments_and_day2_ops.md)
- [✅ Preflight Checklist](workshop/checklists/preflight_checklist.md)
- [⌨️ Commands Cheat Sheet](workshop/cheat_sheets/commands_cheat_sheet.md)
- [🧪 Lab 01: Hello Engine](workshop/labs/lab_01_hello_engine.md)
- [🧪 Lab 02: Model + Migration](workshop/labs/lab_02_model_and_migration.md)
- [🧪 Lab 03: Policy & Token Access](workshop/labs/lab_03_policy_and_token_access.md)
- [🧪 Lab 04: I18n Add Strings & Health](workshop/labs/lab_04_i18n_add_strings_and_health.md)
- [🧪 Lab 05: Notifier + Job + ES Query](workshop/labs/lab_05_notifier_and_job_with_es_query.md)
- [🧪 Lab 06: Controller → Request Spec](workshop/labs/lab_06_controller_to_request_spec.md)
- [🧪 Lab 07: Dokku Deploy + Rollback](workshop/labs/lab_07_dokku_deploy_and_rollback.md)
- [🎓 Capstone Overview](workshop/capstone/README.md)
- [📏 Capstone Rubric](workshop/capstone/rubric.md)
- [🧩 Capstone Submission Template](workshop/capstone/submission_template.md)

##### **Diagram Sources** - [`diagrams/source/`](diagrams/source/)
*Mermaid (.mmd) source files*
- [Accounts Flow](diagrams/source/accounts_flow.mmd)
- [Agreements System Flow](diagrams/source/agreements_system_flow.mmd)
- [⚡ Caching Performance Flow](diagrams/source/caching_performance_flow.mmd)
- [Community Social System Flow](diagrams/source/community_social_system_flow.mmd)
- [Content Flow](diagrams/source/content_flow.mmd)
- [Conversations Messaging Flow](diagrams/source/conversations_messaging_flow.mmd)
- [E2E Encrypted Conversation Flow](diagrams/source/e2e_encrypted_conversation_flow.mmd)
- [Documentation System Flow](diagrams/source/documentation_system_flow.mmd)
- [Events Flow](diagrams/source/events_flow.mmd)
- [Exchange Flow](diagrams/source/exchange_flow.mmd)
- [Geography System Flow](diagrams/source/geography_system_flow.mmd)
- [I18n Mobility Localization Flow](diagrams/source/i18n_mobility_localization_flow.mmd)
- [Metrics Flow](diagrams/source/metrics_flow.mmd)
- [Navigation Flow](diagrams/source/navigation_flow.mmd)
- [Notifications Flow](diagrams/source/notifications_flow.mmd)
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
- [⚙️ External Services Configuration](production/external-services-to-configure.md) - Third-party integrations
- [Raspberry Pi Setup](production/raspberry-pi-setup.md) - Self-hosting guide

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
- [♿ Accessibility Testing](development/accessibility_testing.md) - Browser accessibility and screenshot testing guidance
- [Pull Request Evidence Standard](development/pull_request_evidence_standard.md) - Tiered evidence requirements for PR docs, diagrams, and screenshots
- [Screenshot And Documentation Tooling Assessment](development/screenshot_and_documentation_tooling_assessment.md) - CE and management-tool tooling assessment

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
- [🛠️ Slide Render Script](../docs/scripts/render_slides.sh)
- [🛠️ PDF Export Script](../docs/scripts/export_pdfs.sh)
