Goal:
Perform an in-depth review of the Role-Based Access Control (RBAC) system in this Ruby on Rails application, analyzing its architecture, policies, and enforcement patterns to identify improvements in security, maintainability, and clarity.

Context:
The app is a multi-tenant, community-oriented Rails 7+ platform under the BetterTogether namespace.
It uses Pundit (or a custom policy layer) for authorization, Devise-style authentication, and Membership + Role models to govern access across Platform, Community, and Person levels.
Access rules extend to content editing, community management, messaging, and metrics dashboards.
Accessibility, data privacy, and federated governance are core design principles.

Instructions for Copilot

System Mapping

Identify all components participating in RBAC: authentication layer, User/Person models, Membership, Role, Permission, and Policy classes.

Diagram relationships between these entities (Platform → Community → Person).

Note any redundant or unclear associations.

Policy Review

Examine existing Pundit (or custom) policy classes and scopes.

Check for duplication, over-permissive rules, or missing scope logic.

Suggest consistent patterns (e.g., base policy inheritance or role mixins).

Access Enforcement Audit

Trace authorization calls in controllers, services, and views (authorize, policy_scope, policy(...)).

Identify any actions bypassing authorization or using weak conditional checks.

Recommend ensuring explicit authorization for all CRUD and management operations.

Security and Privacy

Assess tenant isolation — no user should access records outside their community or platform.

Verify use of secure IDs, scoping queries to membership, and avoiding mass-assignment leaks.

Recommend best practices for multi-tenant policy scoping and least-privilege design.

Extensibility & Maintainability

Evaluate whether new features (e.g., Metrics, Messaging, Financial Exchange) can easily extend the RBAC layer.

Suggest refactors for common patterns — shared RoleConcern, centralized PermissionRegistry, or hierarchical roles.

Identify areas for policy auto-generation or declarative permissions.

Testing & Documentation

Review spec coverage for policy behavior, unauthorized access, and edge cases.

Suggest RSpec helpers for concise policy tests.

Recommend adding a developer guide describing RBAC concepts and role hierarchy.

Deliverables

A structured RBAC Assessment Report in docs/assessments including:

High Impact: security flaws, missing isolation, or unsafe bypasses.

Medium: redundant logic or maintainability concerns.

Low: style, test gaps, or doc improvements.

A 5-step improvement roadmap covering refactors, tests, and documentation updates.

Expected Output Format:

## RBAC Assessment Summary  
- Identified Models: User, Membership, Role, Community, Policy  
- Authorization Coverage: 85% (3 controllers missing checks)  

## Key Findings  
**High Impact:** Membership scope leaks across platforms.  
**Medium:** Duplicate role logic in CommunityPolicy.  
**Low:** Inconsistent naming of roles.  

## Recommendations  
1. Introduce BasePolicy inheritance and shared role concerns.  
2. Add system-level specs for unauthorized actions.  
3. Implement role hierarchy registry.  
4. Tighten multi-tenant query scoping.  
5. Update developer RBAC documentation.  

End with a concise summary of priorities — highlighting immediate security fixes and structural improvements to make the RBAC system scalable and future-proof.