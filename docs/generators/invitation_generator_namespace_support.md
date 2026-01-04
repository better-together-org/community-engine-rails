# Invitation Generator Namespace Support

## Overview

The Better Together Invitation Generator supports configurable namespacing to accommodate different application architectures. This allows host applications to:

- Use their own custom namespace
- Use no namespace (root-level models)
- Use the default `BetterTogether` namespace (for engine usage)

## Usage

### Default Namespace (BetterTogether)

When used within the Better Together engine or an app that wants to keep the BetterTogether namespace:

```bash
rails generate better_together:invitation project
```

This generates:
- Model: `app/models/better_together/project_invitation.rb`
- Class: `BetterTogether::ProjectInvitation`
- Table: `better_together_project_invitations` (if using `--with-migration`)

### Custom Namespace

For host applications that want to use their own namespace:

```bash
rails generate better_together:invitation project --namespace=MyApp
```

This generates:
- Model: `app/models/my_app/project_invitation.rb`
- Class: `MyApp::ProjectInvitation`
- Table: `my_app_project_invitations` (if using `--with-migration`)

### No Namespace (Root Level)

For applications that prefer root-level models without namespacing:

```bash
rails generate better_together:invitation project --namespace=""
```

This generates:
- Model: `app/models/project_invitation.rb`
- Class: `ProjectInvitation`
- Table: `project_invitations` (if using `--with-migration`)

## Complete Examples

### Example 1: Custom Namespace with Migration

```bash
rails generate better_together:invitation team \
  --namespace=Acme \
  --with-migration \
  --invitable-model=Organization
```

Generated files:
```
app/models/acme/team_invitation.rb
app/mailers/acme/team_invitations_mailer.rb
app/notifiers/acme/team_invitation_notifier.rb
app/policies/acme/team_invitation_policy.rb
spec/factories/acme/team_invitations.rb
spec/models/acme/team_invitation_spec.rb
db/migrate/20241216XXXXXX_create_acme_team_invitations.rb
```

Migration creates table: `acme_team_invitations`

### Example 2: No Namespace with Skip Views

```bash
rails generate better_together:invitation event \
  --namespace="" \
  --skip-views
```

Generated files:
```
app/models/event_invitation.rb
app/mailers/event_invitations_mailer.rb
app/notifiers/event_invitation_notifier.rb
app/policies/event_invitation_policy.rb
spec/factories/event_invitations.rb
spec/models/event_invitation_spec.rb
```

No views generated due to `--skip-views` flag.
Uses STI with `better_together_invitations` table (no separate migration).

## File Structure by Namespace Configuration

### With BetterTogether Namespace (Default)

```
app/
  models/better_together/
    project_invitation.rb
  mailers/better_together/
    project_invitations_mailer.rb
  notifiers/better_together/
    project_invitation_notifier.rb
  policies/better_together/
    project_invitation_policy.rb
  views/better_together/
    project_invitations/
      index.html.erb
      new.html.erb
      ...
spec/
  models/better_together/
    project_invitation_spec.rb
  factories/better_together/
    project_invitations.rb
```

### With Custom Namespace (e.g., MyApp)

```
app/
  models/my_app/
    project_invitation.rb
  mailers/my_app/
    project_invitations_mailer.rb
  notifiers/my_app/
    project_invitation_notifier.rb
  policies/my_app/
    project_invitation_policy.rb
  views/my_app/
    project_invitations/
      index.html.erb
      new.html.erb
      ...
spec/
  models/my_app/
    project_invitation_spec.rb
  factories/my_app/
    project_invitations.rb
```

### With No Namespace

```
app/
  models/
    project_invitation.rb
  mailers/
    project_invitations_mailer.rb
  notifiers/
    project_invitation_notifier.rb
  policies/
    project_invitation_policy.rb
  views/
    project_invitations/
      index.html.erb
      new.html.erb
      ...
spec/
  models/
    project_invitation_spec.rb
  factories/
    project_invitations.rb
```

## Migration Table Naming

The migration generator creates tables with namespace-aware prefixes:

| Namespace | Invitation Name | Table Name |
|-----------|----------------|------------|
| BetterTogether (default) | project | `better_together_project_invitations` |
| MyApp | project | `my_app_project_invitations` |
| "" (none) | project | `project_invitations` |

## Class Naming

Generated classes follow the namespace:

| Namespace | Invitation Name | Full Class Name |
|-----------|----------------|-----------------|
| BetterTogether | project | `BetterTogether::ProjectInvitation` |
| MyApp | project | `MyApp::ProjectInvitation` |
| "" (none) | project | `ProjectInvitation` |

## Use Cases

### Engine Usage (Default)

When using the Better Together Community Engine in a Rails application, use the default BetterTogether namespace to keep invitation types organized within the engine's namespace:

```bash
rails generate better_together:invitation community
rails generate better_together:invitation platform
```

### Host Application with Own Namespace

For applications that want all invitation types under their own namespace:

```bash
# All invitations under MyApp namespace
rails generate better_together:invitation project --namespace=MyApp
rails generate better_together:invitation team --namespace=MyApp
rails generate better_together:invitation event --namespace=MyApp
```

### Legacy Application (No Namespace)

For existing applications that don't use namespacing:

```bash
# Root-level invitation models
rails generate better_together:invitation project --namespace=""
rails generate better_together:invitation team --namespace=""
```

## Technical Implementation

The generator provides these namespace-aware helper methods:

- `module_name` - Returns the configured namespace (or nil)
- `namespaced?` - Boolean check for namespace presence
- `namespace_path` - Underscored namespace path for file paths
- `table_name_prefix` - Prefix for database table names
- `invitation_class_name` - Full qualified class name

All path helper methods (e.g., `invitation_model_path`, `invitation_mailer_path`) use these methods to generate namespace-appropriate paths.

## Migration Template Variables

The migration template has access to:

- `module_name` - Namespace module name (e.g., "BetterTogether", "MyApp", or nil)
- `table_name_prefix` - Table prefix with underscore (e.g., "better_together_", "my_app_", or "")
- `invitation_name` - Singular invitation name (e.g., "project")

Example migration class name generation:
```ruby
class Create<%= module_name.present? ? module_name.gsub('::', '') : '' %><%= invitation_name.camelize %>Invitations
```

Results in:
- `CreateBetterTogetherProjectInvitations` (BetterTogether namespace)
- `CreateMyAppProjectInvitations` (MyApp namespace)
- `CreateProjectInvitations` (no namespace)

## Considerations

### STI vs Separate Tables

The namespace option works with both approaches:

**STI (Default - No Migration):**
- Uses shared `better_together_invitations` table
- Type column differentiates invitation types
- Namespace affects only class/file organization
- Models inherit from `BetterTogether::Invitation`

**Separate Tables (--with-migration):**
- Creates namespace-prefixed table
- No type column needed
- Models should NOT inherit from `BetterTogether::Invitation`
- Full isolation per invitation type

### Routing Considerations

When using custom namespaces or no namespace, you may need to adjust routing:

**BetterTogether namespace:**
```ruby
# Engine automatically handles routing
```

**Custom namespace:**
```ruby
namespace :my_app do
  resources :projects do
    resources :invitations
  end
end
```

**No namespace:**
```ruby
resources :projects do
  resources :invitations
end
```

### Policy Inheritance

Ensure your invitation policies inherit appropriately:

**BetterTogether namespace:**
```ruby
class BetterTogether::ProjectInvitationPolicy < BetterTogether::InvitationPolicy
```

**Custom namespace:**
```ruby
class MyApp::ProjectInvitationPolicy < BetterTogether::InvitationPolicy
# or
class MyApp::ProjectInvitationPolicy < MyApp::ApplicationPolicy
```

**No namespace:**
```ruby
class ProjectInvitationPolicy < ApplicationPolicy
```

## Backward Compatibility

The default namespace remains `BetterTogether`, ensuring backward compatibility with existing code. All existing invocations without the `--namespace` option will continue to work exactly as before.

## Summary

The namespace option provides flexibility for different application architectures while maintaining the generator's powerful scaffolding capabilities. Choose the approach that best fits your application's organizational needs.
