# Role-Based Access Control (RBAC)

This document explains the RBAC system centered on People, Communities, Platforms, Memberships, Roles, and Resource Permissions.

## Core Entities

- Person: The actor identity. A Person performs actions, receives notifications, and holds memberships in Communities and Platforms.
- Community / Platform: Joinable entities. People join them via memberships and gain Roles within each joinable.
- Memberships:
  - PersonCommunityMembership: Person ↔ Community + Role
  - PersonPlatformMembership: Person ↔ Platform + Role
  - Each membership has one Role whose permissions scope to the joinable.
- Role:
  - Translated `name` and `description`, ordered by `position` per `resource_type`.
  - Has many ResourcePermissions (through RoleResourcePermissions).
- ResourcePermission:
  - Defines a permission at the resource level. Attributes:
    - `resource_type` (e.g., BetterTogether::Platform)
    - `action` from: create, read, update, delete, list, manage, view
    - `identifier` string (e.g., "manage_platform", "read_community") used for policy checks.
- RoleResourcePermission: Join model linking Role ↔ ResourcePermission (unique per pair).

## How Permission Checks Work

- Entry point: `person.permitted_to?(permission_identifier, record=nil)`
  - Looks up ResourcePermission by `identifier` in the Person’s cached permission set.
  - If no `record` is given (global check): returns true if any Role of the Person has the ResourcePermission.
  - If a `record` is given (record-scoped check):
    1) Resolve the membership class for the record’s joinable type (Community/Platform).
    2) Find memberships for `member: person`, `joinable_id: record.id`.
    3) Return true if any membership.role has the ResourcePermission.

- Caching:
  - Person caches its Roles, RoleResourcePermissions, and ResourcePermissions (12 hours) to avoid repeated DB lookups.
  - `permitted_to?` memoizes permissions-by-identifier per instance.

- Policies:
  - Pundit policies call `permitted_to?` (and sometimes compare to record creators) to gate actions.
  - Common checks include `permitted_to?('manage_platform')`, update/read permissions for Communities, Pages, Joatu resources, etc.

## Typical Flows

1) Assigning Permissions to a Role
- Create ResourcePermissions (e.g., manage_platform, read_community, update_community).
- Create Roles (e.g., platform_manager, community_admin, member).
- Link them via RoleResourcePermission (Role.assign_resource_permissions([...]) available).

2) Granting a Role to a Person
- Create a PersonPlatformMembership or PersonCommunityMembership with the Role.
- Person’s cache (roles → role_resource_permissions → resource_permissions) picks this up; after cache expiry or invalidation, `permitted_to?` reflects new permissions.

3) Authorization Check in Policies/Controllers
- Policy calls `permitted_to?('update_community', community)` to require a membership with a Role that includes `update_community` permission for that community.
- For platform-level checks, use global permissions: `user.permitted_to?('manage_platform')`.

## Design Notes

- Roles are scoped by `resource_type` for ordering and uniqueness; a Role is reusable across joinables of the same type.
- Membership validates uniqueness of Role within the [joinable, member] pair.
- Permissions are decoupled from models via `identifier` strings; policies remain expressive and testable.
- Permissible concern exposes helpers to fetch available roles per class.

## Gotchas & Tips

- Record-scoped checks require the record class to expose its `joinable_type` consistent with membership class naming.
- Remember to invalidate or wait out caches when changing Role ↔ Permission wiring in dev.
- Prefer record-scoped checks when actions depend on a specific Community/Platform; use global checks for host/platform-wide actions.

## Concrete Example: Community Admin Role

Goal: A Community Admin can list/read/update their Community and manage People memberships within that Community. They do not have platform‑wide privileges.

1) Define Resource Permissions (once)

```ruby
# In a seed or console (identifiers are strings used by policies)
BetterTogether::ResourcePermission.create!(
  resource_type: 'BetterTogether::Community', action: 'list',   identifier: 'list_community',   position: 10
)
BetterTogether::ResourcePermission.create!(
  resource_type: 'BetterTogether::Community', action: 'read',   identifier: 'read_community',   position: 20
)
BetterTogether::ResourcePermission.create!(
  resource_type: 'BetterTogether::Community', action: 'update', identifier: 'update_community', position: 30
)
BetterTogether::ResourcePermission.create!(
  resource_type: 'BetterTogether::Person',    action: 'update', identifier: 'update_person',    position: 10
)
BetterTogether::ResourcePermission.create!(
  resource_type: 'BetterTogether::Person',    action: 'list',   identifier: 'list_person',      position: 20
)
```

2) Create the Role and Link Permissions

```ruby
admin = BetterTogether::Role.create!(
  identifier: 'community_admin',
  name: 'Community Admin',
  resource_type: 'BetterTogether::Community',
  position: 1
)

admin.assign_resource_permissions(%w[
  list_community read_community update_community list_person update_person
])
```

3) Grant the Role via Membership

```ruby
person    = BetterTogether::Person.first
community = BetterTogether::Community.first

BetterTogether::PersonCommunityMembership.create!(
  member: person,
  joinable: community,
  role: admin
)
```

4) Authorization Checks

```ruby
# Global checks (no record):
person.permitted_to?('manage_platform') # => false (no platform role)

# Record‑scoped checks (with record):
person.permitted_to?('update_community', community) # => true
person.permitted_to?('list_person', community)      # => true (allowed via role on this community)

other_community = BetterTogether::Community.where.not(id: community.id).first
person.permitted_to?('update_community', other_community) # => false (no membership there)
```

Note: Policies typically call `permitted_to?` internally. For example, `CommunityPolicy#update?` might require `permitted_to?('update_community', record)`.
