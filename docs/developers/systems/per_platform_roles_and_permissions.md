# Per-platform roles and permissions

Roles, resource permissions and their join rows belong to one platform each. A platform's default
role set is defined by the `rbac` seed packet and planted for every platform.

## Model

- `Role`, `ResourcePermission` and `RoleResourcePermission` are platform records. Identifiers are unique
  per platform (`idx_bt_roles_on_platform_identifier`, `idx_bt_resource_permissions_on_platform_identifier`)
  and positions are unique per platform and resource type.
- A membership may only hold a role from its own platform (`Membership#role_belongs_to_joinable_platform`).
- `Role.find_default(identifier, platform:)` returns the platform's own copy. When a platform has no roles
  yet it receives the default set first. It never falls through to another platform.

## Seed packet

`config/seeds/better_together/rbac/` holds 46 resource permissions, 21 roles and 208 role permission
links. `AccessControlBuilder.seed_data(platform:)` plants it through `Seeds::Plant`, and
`TenantPlatformProvisioningService` plants it for each new tenant platform. The registry types are
`resource_permission`, `role` and `role_resource_permission` (`Seeds::DefaultTypes.register_rbac`).

## Migration

`ScopeRolesAndPermissionsByPlatform` assigns unowned rows to the host platform, swaps the global unique
indexes for per-platform ones, copies the set to every other platform, and repoints memberships and other
role holders to their platform's copy. It is idempotent and guards every step against partial schema
state. Hosts with no platforms other than the host see no data change.

## Specs

Specs build roles on whichever platform is current. `spec/support/membership_role_alignment.rb` aligns a
membership's role with its joinable's platform before validation; tag an example `:strict_role_platform` to
turn that off when testing the validation itself.

## Adding a permission to existing platforms

The packet only reaches platforms when it is planted, so a new permission also needs a data migration
for platforms that already have roles. `SeedManagePlatformJobsPermission` is the pattern: it creates
`manage_platform_jobs` on every platform that has roles and grants it to each role on that platform
that already holds `manage_platform` or `manage_platform_settings`, so custom roles keep the access
they had. It is idempotent and skips a taken position.
