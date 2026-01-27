# MCP Integration Acceptance Criteria

**Feature**: Model Context Protocol (MCP) Integration with Privacy-Aware Authorization

**Date Created**: 2026-01-27

**Status**: Implementation In Progress

**Related Implementation Plan**: TBD

## Overview

Integrate Fast MCP into the Better Together Community Engine to enable AI model interactions while respecting the platform's existing Pundit authorization policies and privacy scoping.

## Acceptance Criteria by Stakeholder

### Platform Organizers

**AC-PO-1: Configure MCP Server Settings**
- **As a** platform organizer
- **I want** to enable/disable MCP functionality through configuration
- **So that** I can control whether AI models can access platform data

**Acceptance Tests:**
- [ ] MCP can be enabled via Rails initializer configuration
- [ ] MCP can be disabled via configuration without breaking the application
- [ ] MCP routes are only mounted when enabled
- [ ] Authentication token can be configured for secure access

**AC-PO-2: Manage AI Access Permissions**
- **As a** platform organizer
- **I want** MCP tools and resources to respect platform permissions
- **So that** AI models cannot access data that platform managers shouldn't see

**Acceptance Tests:**
- [ ] Platform manager permissions apply to MCP tools
- [ ] MCP resources filter data based on user permissions
- [ ] Unauthorized access attempts are logged and rejected

### Developers

**AC-DEV-1: Create Privacy-Aware MCP Tools**
- **As a** developer
- **I want** to create MCP tools that inherit from a base class with Pundit integration
- **So that** authorization is enforced consistently across all tools

**Acceptance Tests:**
- [ ] ApplicationTool base class exists and integrates with Pundit
- [ ] Tools have access to current user context
- [ ] Tools can check permissions using `authorize` method
- [ ] Tools follow Rails naming conventions (ActionTool::Base alias)

**AC-DEV-2: Create Privacy-Aware MCP Resources**
- **As a** developer
- **I want** to create MCP resources that filter data using Pundit policy scopes
- **So that** AI models only receive data the current user is authorized to see

**Acceptance Tests:**
- [ ] ApplicationResource base class exists and integrates with Pundit
- [ ] Resources have access to current user context
- [ ] Resources use policy_scope to filter data
- [ ] Resources follow Rails naming conventions (ActionResource::Base alias)

**AC-DEV-3: Use Existing Privacy Scoping**
- **As a** developer
- **I want** MCP resources to automatically respect Privacy concern settings
- **So that** public/private data filtering works without additional code

**Acceptance Tests:**
- [ ] Resources for models with Privacy concern filter by privacy level
- [ ] Public data is accessible to unauthenticated AI requests
- [ ] Private data requires authentication and authorization
- [ ] Creator-owned private data is accessible to creators

### End Users

**AC-EU-1: Privacy Settings Apply to AI Access**
- **As an** end user
- **I want** my privacy settings to be respected in AI interactions
- **So that** my private data isn't exposed to AI models without permission

**Acceptance Tests:**
- [ ] AI cannot access user's private posts through MCP
- [ ] AI cannot access user's private events through MCP
- [ ] AI cannot access blocked users' data in queries
- [ ] AI can access user's own private data when authenticated

**AC-EU-2: Community Privacy Boundaries**
- **As an** end user
- **I want** AI to respect community privacy boundaries
- **So that** private community content isn't leaked

**Acceptance Tests:**
- [ ] AI cannot access private communities without membership
- [ ] AI cannot access community-private posts without membership
- [ ] AI can access public community data
- [ ] AI respects invitation-only community restrictions

### Content Moderators

**AC-CM-1: Monitor AI Tool Usage**
- **As a** content moderator
- **I want** to see what MCP tools are being invoked
- **So that** I can identify misuse or data leakage

**Acceptance Tests:**
- [ ] MCP tool invocations are logged
- [ ] Logs include user context and requested data
- [ ] Logs are accessible to platform managers
- [ ] Failed authorization attempts are logged with details

## Technical Requirements

### TR-1: Fast MCP Integration
- Add fast-mcp gem to gemspec dependencies
- Create Rails initializer for MCP configuration
- Mount MCP routes in engine routes
- Support both STDIO and HTTP/SSE transports

### TR-2: Pundit Integration
- ApplicationTool includes Pundit::Authorization
- ApplicationResource includes Pundit::Authorization
- Current user context available in tools/resources
- Policy classes applied to all data access

### TR-3: Privacy Scoping
- Resources use ApplicationPolicy::Scope patterns
- Privacy concern filtering applies automatically
- Blocked users excluded from results
- Community membership checked for private content

### TR-4: Security
- Authentication required for non-public endpoints
- Authorization checked before tool execution
- SQL injection prevention via Arel usage
- Input validation on all tool arguments

### TR-5: Testing
- Request specs for MCP endpoints
- Unit specs for ApplicationTool and ApplicationResource
- Integration specs for example tools/resources
- Security specs for authorization enforcement

## Example Implementations Required

### Example Tools
1. **ListCommunitiesTool** - List communities with privacy filtering
2. **SearchPostsTool** - Search posts respecting privacy settings
3. **GetEventDetailsTool** - Get event details with authorization check

### Example Resources
1. **PublicCommunitiesResource** - Public communities list
2. **UserPostsResource** - User's own posts (authenticated)
3. **CommunityEventsResource** - Events for a specific community

## Success Metrics

- [ ] All acceptance tests pass
- [ ] Security scan (Brakeman) shows no new high-confidence issues
- [ ] All RuboCop offenses resolved
- [ ] Test coverage > 95% for MCP code
- [ ] Documentation complete with examples
- [ ] Integration works with Claude Desktop inspector

## Out of Scope for MVP

- Advanced caching strategies
- Real-time resource subscriptions
- Pagination for large datasets
- Rate limiting (rely on Rack::Attack)
- Multi-tenancy support beyond single platform
- Custom transport implementations
- WebSocket support

## Dependencies

- fast-mcp gem (>= 1.6.0)
- Existing Pundit policies
- Existing Privacy concern
- Existing ApplicationPolicy::Scope patterns

## Risks and Mitigations

**Risk**: Privacy leakage through AI queries
**Mitigation**: Comprehensive test coverage of privacy filtering, security audit

**Risk**: Performance impact of policy checks
**Mitigation**: Use policy_scope for efficient database queries, add caching later

**Risk**: Breaking changes in fast-mcp gem
**Mitigation**: Pin gem version, comprehensive integration tests

## Documentation Requirements

- [ ] README section on MCP integration
- [ ] Developer guide for creating tools/resources
- [ ] Security considerations document
- [ ] API reference for base classes
- [ ] Example implementations with explanations

## Review and Approval

- **Technical Review**: Pending
- **Security Review**: Pending
- **Stakeholder Approval**: Pending
