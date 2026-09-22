#!/bin/bash

# Better Together Documentation Stakeholder Structure Migration
# This script reorganizes documentation by stakeholder groups with shared resources via symlinks

set -e  # Exit on error

echo "🔧 Starting Better Together Stakeholder Documentation Restructure..."

# Create stakeholder directory structure
echo "📁 Creating stakeholder directory structure..."

mkdir -p docs/end_users
mkdir -p docs/community_organizers  
mkdir -p docs/platform_organizers
mkdir -p docs/developers/architecture
mkdir -p docs/developers/development
mkdir -p docs/developers/systems
mkdir -p docs/developers/api
mkdir -p docs/support_staff
mkdir -p docs/content_moderators
mkdir -p docs/legal_compliance
mkdir -p docs/shared
mkdir -p docs/implementation/current_plans
mkdir -p docs/implementation/templates
mkdir -p docs/implementation/completed
mkdir -p docs/diagrams/source
mkdir -p docs/diagrams/exports/png
mkdir -p docs/diagrams/exports/svg
mkdir -p docs/meta
mkdir -p docs/reference

# Create stakeholder README files
echo "📝 Creating stakeholder README files..."

cat > docs/end_users/README.md << 'EOF'
# End User Guide

Welcome! This guide helps community members use Better Together platform features safely and effectively.

## Getting Started
- [Getting Started Guide](getting_started.md) - Your first steps on the platform
- [Platform Welcome](../welcome.md) - Understanding Better Together principles

## Community Features
- [Joining Communities](joining_communities.md) - How to find and join communities
- [Profile Management](profile_management.md) - Managing your personal profile
- [Messaging and Social Features](messaging_and_social.md) - Connecting with others

## Safety and Privacy
- [Safety and Privacy Overview](safety_and_privacy.md) - Protecting yourself and others
- [Blocking and Reporting](blocking_and_reporting.md) - Using safety tools
- [Privacy Settings](../shared/security_and_privacy.md) - Understanding privacy controls

## Need Help?
Contact your community organizers or platform support staff for assistance with any platform features.
EOF

cat > docs/community_organizers/README.md << 'EOF'
# Community Organizer Guide

This guide helps elected community leaders manage their communities effectively within the cooperative framework.

## Community Setup and Management
- [Community Setup](community_setup.md) - Creating and configuring your community
- [Member Management](member_management.md) - Managing community membership
- [Community Management Overview](../community_management.md) - Comprehensive management guide

## Moderation and Engagement
- [Community Moderation](community_moderation.md) - Local moderation tools and processes
- [Engagement Tools](engagement_tools.md) - Building active, engaged communities
- [Analytics and Insights](analytics_and_insights.md) - Understanding community health

## Shared Resources
- [Roles and Permissions](../shared/roles_and_permissions.md) - Understanding authority and responsibilities
- [Democratic Decision-Making](../shared/democratic_principles.md) - Cooperative governance principles
- [Escalation Procedures](../shared/escalation_matrix.md) - When to involve platform organizers

## Cooperative Values
Community organizers are elected by and accountable to their community members. All decisions should reflect cooperative principles of democratic participation and community self-governance.
EOF

cat > docs/platform_organizers/README.md << 'EOF'
# Platform Organizer Guide

This guide helps elected platform organizers manage platform-wide operations while supporting community autonomy and democratic decision-making.

## Platform Management
- [Platform Management](platform_management.md) - Platform-wide configuration and oversight
- [Host Management Guide](../host_management.md) - Technical platform management
- [Host Dashboard Extensions](../host_dashboard_extensions.md) - Advanced management features

## User and Content Oversight
- [User Management](user_management.md) - Platform-wide user administration
- [Moderation Oversight](moderation_oversight.md) - Supporting community moderation
- [Analytics Dashboard](analytics_dashboard.md) - Platform-wide metrics and insights

## Compliance and Governance
- [Compliance and Reporting](compliance_and_reporting.md) - Legal and regulatory compliance
- [Roles and Permissions](../shared/roles_and_permissions.md) - Authority structure and delegation
- [Security and Privacy](../shared/security_and_privacy.md) - Platform security principles

## Democratic Leadership
Platform organizers are elected by the platform community and serve to support community organizers while maintaining platform-wide standards and cooperative values.
EOF

cat > docs/developers/README.md << 'EOF'
# Developer Guide

Technical documentation for developers working on the Better Together Community Engine.

## Getting Started
- [Development Setup](development/setup_and_environment.md) - Local development environment
- [Developer Guide Overview](../guide.md) - General development guidance
- [TDD Process](development/tdd_process.md) - Test-driven development approach

## Architecture
- [System Architecture Overview](architecture/overview.md) - High-level system design
- [Data Models](architecture/data_models.md) - Database schema and relationships
- [Authorization System](architecture/authorization_system.md) - RBAC and policy framework
- [Democratic Design](architecture/democratic_design.md) - Cooperative governance architecture

## System Documentation
- [Community System](systems/community_system.md) - Community management implementation
- [Messaging System](systems/messaging_system.md) - Real-time communication features
- [Events System](systems/events_system.md) - Event management system
- [All Systems →](systems/) - Complete system documentation

## Development Standards
- [Coding Standards](development/coding_standards.md) - Code quality requirements
- [Deployment Procedures](development/deployment_procedures.md) - Production deployment
- [Security Principles](../shared/security_and_privacy.md) - Security implementation guidelines

## API Documentation
- [Authentication APIs](api/authentication.md) - Auth endpoints and flows
- [Community APIs](api/communities.md) - Community management endpoints
- [User Management APIs](api/user_management.md) - User and profile management
- [Messaging APIs](api/messaging.md) - Communication endpoints

The Better Together Community Engine follows cooperative principles in its technical architecture, emphasizing democratic governance, community empowerment, and equitable participation.
EOF

cat > docs/support_staff/README.md << 'EOF'
# Support Staff Guide

Documentation for team members who help users with platform issues, onboarding, and general assistance.

## User Assistance
- [User Onboarding](user_onboarding.md) - Helping new users get started
- [Troubleshooting Guide](troubleshooting.md) - Common issues and solutions
- [User Assistance Tools](user_assistance_tools.md) - Support tools and interfaces

## Procedures and Escalation
- [Escalation Procedures](escalation_procedures.md) - When and how to escalate issues
- [FAQ Management](faq_management.md) - Managing help content and resources

## Understanding the Platform
Support staff should understand Better Together's cooperative principles to help users engage effectively with the democratic governance model and community-led features.
EOF

cat > docs/content_moderators/README.md << 'EOF'
# Content Moderator Guide

Documentation for community volunteers who review reports, moderate content, and support platform safety.

## Moderation Guidelines
- [Moderation Guidelines](moderation_guidelines.md) - Community standards and policies
- [Content Review Procedures](content_review.md) - Step-by-step content moderation
- [Report Processing](report_processing.md) - Handling user reports

## Safety Tools
- [User Safety Tools](user_safety_tools.md) - Available moderation tools
- [Escalation Matrix](../shared/escalation_matrix.md) - When to escalate decisions

## Cooperative Moderation
Content moderation in Better Together follows democratic principles, emphasizing community standards, transparent processes, and accountability to community members.
EOF

cat > docs/legal_compliance/README.md << 'EOF'
# Legal/Compliance Guide

Documentation for regulatory compliance, privacy policies, and legal requirements management.

## Privacy and Data Protection
- [Privacy Compliance](privacy_compliance.md) - GDPR and privacy law compliance
- [Data Retention Policies](data_retention.md) - Data management procedures
- [Security Principles](../shared/security_and_privacy.md) - Platform security framework

## Legal Procedures
- [Audit Procedures](audit_procedures.md) - Compliance auditing and reporting
- [Regulatory Requirements](regulatory_requirements.md) - Legal obligations and compliance

## Cooperative Compliance
Better Together's legal compliance reflects cooperative values, emphasizing transparency, user rights, community control, and democratic accountability in all legal and regulatory matters.
EOF

# Move files to stakeholder directories (preparing for current structure)
echo "📂 Preparing file categorization (files will be moved after structure creation)..."

# Note files that should go to developers
echo "Files for developers/systems/:"
echo "  - community_social_system.md"
echo "  - conversations_messaging_system.md"
echo "  - events_system.md"
echo "  - content_management.md"
echo "  - geography_system.md"
echo "  - i18n_mobility_localization_system.md"
echo "  - metrics_system.md"
echo "  - navigation_system.md"
echo "  - notifications_system.md"
echo "  - security_protection_system.md"
echo "  - caching_performance_system.md"
echo "  - accounts_and_invitations.md"

echo "Files for developers/architecture/:"
echo "  - models_and_concerns.md"
echo "  - rbac_overview.md"
echo "  - polymorphic_and_sti.md"

echo "Files for shared/:"
echo "  - democratic_by_design.md"
echo "  - privacy_principles.md"

echo "Files for platform_organizers/:"
echo "  - host_management.md"
echo "  - host_dashboard_extensions.md"

echo "Files for implementation/:"
echo "  - community_social_system_implementation_plan.md"
echo "  - community_social_system_acceptance_criteria.md"
echo "  - tdd_acceptance_criteria_template.md"  
echo "  - implementation_plan_template.md"
echo "  - system_documentation_template.md"

# Create shared resource files
echo "📝 Creating shared resource files..."

cat > docs/shared/README.md << 'EOF'
# Shared Documentation

Documentation that serves multiple stakeholder groups, covering cross-cutting concerns and collaborative processes.

## Core Shared Resources
- [Roles and Permissions](roles_and_permissions.md) - Platform authority and responsibility structure
- [Security and Privacy](security_and_privacy.md) - Platform security principles and privacy framework
- [Democratic Principles](democratic_principles.md) - Cooperative governance and decision-making
- [Escalation Matrix](escalation_matrix.md) - Decision-making and escalation procedures
- [Platform Glossary](glossary.md) - Common terminology and definitions

## Usage
These documents are referenced from multiple stakeholder directories via symbolic links, ensuring single-source maintenance while serving different audiences.
EOF

cat > docs/implementation/README.md << 'EOF'
# Implementation Documentation

Project management, planning, and implementation tracking for Better Together Community Engine features.

## Current Active Projects
- [Community Social System Implementation Plan](current_plans/community_social_system_plan.md)
- [Community Social System Acceptance Criteria](current_plans/community_social_system_acceptance_criteria.md)

## Templates and Standards
- [TDD Acceptance Criteria Template](templates/tdd_acceptance_criteria_template.md)
- [Implementation Plan Template](templates/implementation_plan_template.md)
- [System Documentation Template](templates/system_documentation_template.md)

## Process
All implementation follows the stakeholder-focused TDD approach with collaborative review before development begins.
EOF

cat > docs/diagrams/README.md << 'EOF'
# Visual Documentation

System diagrams, process flows, and visual aids for the Better Together Community Engine.

## Directory Structure
- `source/` - Mermaid (.mmd) source files (authoritative versions)
- `exports/png/` - PNG exports for documentation embedding
- `exports/svg/` - SVG exports for web use and scalability

## Diagram Categories
- **System Flows**: Process workflows and data flows
- **Architecture**: System relationships and component interactions
- **User Journeys**: Stakeholder workflows and interactions

## Maintenance
Use `bin/render_diagrams` to regenerate exports from source files. Always edit .mmd source files, never edit exports directly.

See [Diagram Maintenance](maintenance.md) for detailed procedures.
EOF

cat > docs/meta/README.md << 'EOF'
# Meta Documentation

Documentation about the documentation system, quality standards, and maintenance procedures.

## Documentation Management
- [Documentation Standards](documentation_standards.md) - Quality requirements and guidelines
- [Maintenance Procedures](maintenance_procedures.md) - How to maintain and update documentation
- [Assessment and Progress](assessment_and_progress.md) - Documentation quality tracking

## Tools and Automation
- [Update Tools](update_tools.sh) - Automated maintenance scripts

This meta-documentation ensures the stakeholder-focused documentation structure remains organized, accessible, and aligned with cooperative principles.
EOF

# Create basic shared files
cat > docs/shared/roles_and_permissions.md << 'EOF'
# Roles and Permissions

*This document serves multiple stakeholder groups with information about platform authority, responsibilities, and decision-making structures.*

## Overview
The Better Together Community Engine implements a democratic role-based access control system that emphasizes community self-governance and cooperative decision-making.

## Stakeholder Roles

### End Users (Community Members)
- **Authority**: Personal profile and privacy settings
- **Responsibilities**: Follow community guidelines and platform policies
- **Decision Scope**: Personal participation and engagement choices

### Community Organizers (Elected Community Leaders)
- **Authority**: Community-specific moderation and member management
- **Responsibilities**: Serve community members democratically and transparently  
- **Decision Scope**: Community policies, membership, and local moderation
- **Accountability**: To community members who elect them

### Platform Organizers (Elected Platform Staff)
- **Authority**: Platform-wide oversight and policy enforcement
- **Responsibilities**: Support community organizers while maintaining platform standards
- **Decision Scope**: Platform policies, user management, and compliance
- **Accountability**: To the broader platform community

### Content Moderators (Safety Volunteers)
- **Authority**: Report review and content safety decisions
- **Responsibilities**: Apply community standards fairly and transparently
- **Decision Scope**: Content removal, user safety interventions
- **Escalation**: To community or platform organizers for complex cases

## Permission Structure
Technical implementation follows cooperative principles with role-based permissions that support democratic governance rather than hierarchical control.

For technical details, see [RBAC Overview](../developers/architecture/authorization_system.md).
EOF

cat > docs/shared/democratic_principles.md << 'EOF'
# Democratic Principles

*Core cooperative and democratic principles that guide Better Together Community Engine design and governance.*

## Cooperative Values
- **Democratic Control**: Members democratically control the platform
- **Voluntary Membership**: Open and voluntary participation
- **Economic Participation**: Members contribute to and democratically control resources
- **Autonomy and Independence**: Community self-determination and autonomy
- **Education and Training**: Commitment to member education and development
- **Cooperation**: Cooperation among communities and platforms
- **Community Concern**: Sustainable development of communities

## Platform Implementation
- **Elected Leadership**: Community and platform organizers elected by members
- **Transparent Decision-Making**: Open processes with member input
- **Community Self-Governance**: Local decision-making authority
- **Collaborative Development**: Democratic participation in platform development
- **Equitable Access**: Equal access to platform features and governance

## Stakeholder Participation
Each stakeholder group participates in democratic governance within their scope of authority and responsibility, with escalation procedures that maintain accountability to the broader community.

See also: [Democratic by Design](../democratic_by_design.md)
EOF

cat > docs/shared/escalation_matrix.md << 'EOF'
# Escalation Matrix

*Decision-making authority and escalation procedures for different types of platform decisions.*

## Escalation Levels

### Level 1: Individual User Decisions
- **Authority**: End Users
- **Examples**: Personal privacy settings, community participation, blocking users
- **Escalation**: To community organizers for harassment or safety issues

### Level 2: Community-Level Decisions  
- **Authority**: Community Organizers
- **Examples**: Community policies, membership decisions, local moderation
- **Escalation**: To platform organizers for policy conflicts or technical issues

### Level 3: Platform-Level Decisions
- **Authority**: Platform Organizers
- **Examples**: Platform policies, user management, compliance requirements
- **Escalation**: To legal/compliance team for regulatory issues

### Level 4: Legal/Regulatory Decisions
- **Authority**: Legal/Compliance Team
- **Examples**: Privacy compliance, data protection, regulatory requirements
- **Escalation**: To external legal counsel or regulatory bodies as required

## Cross-Stakeholder Collaboration
Many decisions involve multiple stakeholder groups working together within the cooperative framework, maintaining democratic accountability while ensuring effective platform operation.
EOF

echo "🔗 Creating symbolic links for shared resources..."

# Create symbolic links (these will be created after directories exist)
echo "Symbolic links to be created:"
echo "  community_organizers/roles_and_permissions.md -> ../shared/roles_and_permissions.md"
echo "  platform_organizers/roles_and_permissions.md -> ../shared/roles_and_permissions.md"
echo "  platform_organizers/security_and_privacy.md -> ../shared/security_and_privacy.md"
echo "  developers/security_and_privacy.md -> ../shared/security_and_privacy.md"
echo "  content_moderators/escalation_matrix.md -> ../shared/escalation_matrix.md"
echo "  legal_compliance/security_and_privacy.md -> ../shared/security_and_privacy.md"

echo "✅ Stakeholder directory structure created successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Review the created stakeholder directory structure"
echo "2. Move existing files to appropriate stakeholder directories"
echo "3. Create symbolic links for shared resources"
echo "4. Update internal documentation links"
echo "5. Test navigation and accessibility of new structure"
echo ""
echo "📊 New stakeholder-focused structure:"
tree docs -I "*.png|*.svg|*.mmd" -L 3
