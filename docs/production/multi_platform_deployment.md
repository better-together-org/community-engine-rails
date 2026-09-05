# Multi-Platform Deployment Guide

## Overview

Community Engine supports running multiple independent platforms from a single Rails instance. This guide covers the operational setup needed to deploy and manage multiple platforms on one server.

**What "multi-platform" means in Community Engine:**
- Multiple distinct communities/organizations run on the same database and Rails application
- Each platform has its own content, members, configurations, and feature gates
- Platforms are isolated by hostname-based routing (not separate databases or instances)
- All platforms share infrastructure: PostgreSQL, Redis, Elasticsearch, background jobs
- This is suitable for SaaS deployments, cooperatives running multiple communities, or federation scenarios

**What this is NOT:**
- Schema-isolated multi-tenancy (all platforms share the same schema)
- Separate database instances per platform (all in one PostgreSQL database)
- Separate Rails instances (one Rails app serves all platforms)

For architectural details, see [Multi-Tenant Platform Runtime](../developers/systems/multi_tenant_platform_runtime.md).

---

## Architecture Quick Reference

Every request to Community Engine follows this flow:

```
1. Incoming HTTP request
        ↓
2. HAProxy/nginx reverse proxy routes by hostname
        ↓
3. Rack middleware: PlatformContextMiddleware resolves hostname → Platform
        ↓
4. Current.platform set in thread-local context
        ↓
5. Controllers query/create content scoped to Current.platform
        ↓
6. Response rendered with platform-specific data
```

**Key components:**
- **PlatformDomain**: Maps incoming hostnames to platforms (stored in database)
- **Platform**: Represents a distinct community/organization
- **Current.platform**: Thread-local context available to all code during request
- **PlatformScoped models**: Page, Post, Event, ShortLink, etc. — all have `platform_id` required

---

## Step-by-Step Setup

### 1. Create Host Platform (First Time Only)

When you deploy Community Engine for the first time, create the host platform:

```ruby
# Via Rails console (bin/dc-run-dummy rails console)
community = Community.create!(
  name: 'Main Community',
  identifier: 'main-community',
  host: true,
  privacy: 'public'
)

host_platform = Platform.create!(
  community:,
  name: 'Main Platform',
  identifier: 'main-platform',
  host: true,
  host_url: 'https://main.example.com',  # Your primary domain with HTTPS
  privacy: 'public',
  requires_invitation: false
)
```

The `host: true` flag marks this as the default platform. Only ONE platform can be marked `host: true`.

**Important:** Creating a Platform with a `host_url` automatically creates a `PlatformDomain` record via the `sync_primary_platform_domain!` callback. You do not need to create it separately.

### 2. Add a New Platform

To add a second platform (tenant), create it similarly but with `host: false`:

```ruby
tenant_community = Community.create!(
  name: 'Tenant A',
  identifier: 'tenant-a',
  host: false,
  privacy: 'private'
)

tenant_platform = Platform.create!(
  community: tenant_community,
  name: 'Tenant A Platform',
  identifier: 'tenant-a-platform',
  host: false,
  host_url: 'https://tenant-a.example.com',
  privacy: 'private',
  requires_invitation: true  # Set per-platform
)

# This automatically creates a PlatformDomain:
# PlatformDomain.find_by(platform: tenant_platform, primary_flag: true)
```

### 3. Add Domain Aliases (Optional)

If a platform should be accessible via multiple hostnames (e.g., www and non-www versions):

```ruby
# Add an alias domain pointing to the same platform
PlatformDomain.create!(
  platform: tenant_platform,
  hostname: 'alias.example.com',
  primary_flag: false,  # This is an alias, not primary
  active: true
)
```

The `primary_flag: true` domain is used in canonical links; aliases route to the same platform but links point back to the primary.

### 4. Configure HAProxy or Reverse Proxy

Route all hostnames to the same Rails upstream. Example HAProxy configuration:

```haproxy
# /etc/haproxy/haproxy.cfg (simplified)

frontend http_in
  bind 0.0.0.0:80
  redirect scheme https code 301 if !{ ssl_fc }

frontend https_in
  bind 0.0.0.0:443 ssl crt /path/to/certificate.pem
  
  # Route all hostnames to the same backend
  default_backend rails_backend

backend rails_backend
  # All requests (any hostname) go to the same Rails instance
  server rails1 127.0.0.1:3000
  # In production, add multiple Rails instances with load balancing
```

**Key point:** HAProxy doesn't care about the hostname — it just forwards the `Host` header to Rails. Rails' middleware reads the `Host` header to resolve which platform to use.

**DNS:** Your DNS should point all platform hostnames to the same IP (your HAProxy server):
```dns
main.example.com    A 192.0.2.100
tenant-a.example.com A 192.0.2.100
tenant-b.example.com A 192.0.2.100
```

### 5. SSL Certificates

Each platform hostname needs an SSL certificate. Options:

- **Single wildcard certificate:** `*.example.com` covers all subdomains (if all are subdomains)
- **Multiple certificates:** Use SNI (Server Name Indication) in HAProxy to select the right cert per hostname
- **Let's Encrypt:** Automate with `certbot` and HAProxy plugins

HAProxy example with SNI:
```haproxy
bind 0.0.0.0:443 ssl \
  crt /path/to/main.example.com.pem \
  crt /path/to/tenant-a.example.com.pem
```

---

## Domain Configuration Details

### Primary vs. Alias Domains

Each `PlatformDomain` record has:
- `hostname`: The incoming request hostname to match
- `primary_flag`: Whether this is the canonical domain for the platform
- `active`: Whether this domain is currently accepting requests

**Canonical links:** The platform uses the primary domain in canonical links and redirects. This is important for SEO.

Example:
```ruby
# Primary domain
PlatformDomain.create!(
  platform: tenant_platform,
  hostname: 'tenant-a.example.com',
  primary_flag: true,
  active: true
)

# Aliases (common misspellings, old names, etc.)
PlatformDomain.create!(
  platform: tenant_platform,
  hostname: 'www.tenant-a.example.com',
  primary_flag: false,
  active: true
)

# Deactivated domain (was once used, no longer)
PlatformDomain.create!(
  platform: tenant_platform,
  hostname: 'old-tenant-a.example.com',
  primary_flag: false,
  active: false
)
```

When a user visits `www.tenant-a.example.com`, they are served content but canonical links point to `tenant-a.example.com`.

### Updating a Platform's Primary Domain

If you need to change the primary hostname:

```ruby
tenant_platform.update!(host_url: 'https://newtenant-a.example.com')
# This triggers sync_primary_platform_domain! which:
# 1. Updates the primary PlatformDomain hostname
# 2. Invalidates the cache key for the old hostname
```

---

## Feature Gates Per Platform

Each platform can independently enable or disable features. Control this via platform settings:

```ruby
tenant_platform.update!(
  feature_gate_rollouts: {
    'new_content_blocks' => 'stable',    # Enabled for all users
    'developer_settings' => 'alpha',     # Only users with alpha access
    'some_experimental' => 'off'         # Disabled for everyone
  }
)
```

Valid rollout values: `'stable'`, `'beta'`, `'alpha'`, `'off'`

**Checking in code:**
```ruby
if BetterTogether::FeatureGate.enabled?(:new_content_blocks, actor: user.person, platform: current_platform)
  # Feature is enabled for this user on this platform
end
```

Each platform's rollout setting overrides the global feature registry default. If not set on a platform, the registry default applies.

---

## Verification Checklist

After setting up a new platform, verify:

### 1. Routing Verification
```bash
# Test from your HAProxy server
curl -I https://tenant-a.example.com/en
# Should return 200 OK

curl -I https://www.tenant-a.example.com/en
# Should also return 200 OK (alias domain)
```

### 2. Content Isolation Verification

Log into tenant-a.example.com and create a test page. Then:
```bash
# Access via tenant-a domain — should see the page
curl https://tenant-a.example.com/en/test-page

# Access via main.example.com with same slug — should be 404 or show main's version
curl https://main.example.com/en/test-page
```

### 3. Platform Context Verification

Rails console check:
```ruby
# On the host Rails instance
rails console

# Simulate a request to tenant-a
Rack::MockRequest.env_for("https://tenant-a.example.com/en", method: "GET")
# In real requests, middleware sets Current.platform automatically
```

### 4. Feature Gate Verification

```ruby
tenant_platform = Platform.find_by(identifier: 'tenant-a-platform')
tenant_platform.feature_rollout_for(:new_content_blocks)  # Should be 'stable'
```

### 5. Database Integrity

```ruby
# Verify no cross-platform leaks
BetterTogether::Page.for_platform(tenant_platform).count  # Count on this platform
BetterTogether::Page.count  # Total across all platforms

# They should sum correctly; no page should be visible on multiple platforms
```

---

## Troubleshooting

### Symptom: Request to new platform returns 500 or routing error

**Likely cause:** Platform or PlatformDomain not created, or middleware not configured.

**Fix:**
```ruby
# Check platform exists
Platform.find_by(identifier: 'tenant-a-platform')

# Check domain is created
PlatformDomain.find_by(hostname: 'tenant-a.example.com')

# Restart Rails to pick up changes
```

### Symptom: Content from different platforms is mixed

**Likely cause:** `PlatformScoped` model not properly scoped in query, or `platform_id` missing.

**Fix:**
```ruby
# Always use the scoped query in controllers:
pages = BetterTogether::Page.for_platform(current_platform)  # Correct

# Never use unscoped queries:
pages = BetterTogether::Page.all  # Wrong! Gets pages from all platforms
```

### Symptom: Canonical links point to wrong domain

**Likely cause:** Primary domain not set, or cache stale.

**Fix:**
```ruby
# Verify primary domain
PlatformDomain.find_by(platform:, primary_flag: true)

# Clear cache if needed
Rails.cache.clear
```

### Symptom: Feature gates not working

**Likely cause:** Feature rollout not configured on platform, or feature key typo.

**Fix:**
```ruby
# Check platform has rollout configured
platform.feature_gate_rollouts  # Should include the feature key

# Check feature exists in registry
BetterTogether::FeatureRegistry.find(:new_content_blocks)

# Test directly:
BetterTogether::FeatureGate.enabled?(:new_content_blocks, actor: user.person, platform:)
```

### Symptom: Cache key format in logs mentions `bt:platform_domain:...`

**Background:** The middleware caches domain resolution under key `"bt:platform_domain:#{normalized_hostname}"`. Normalized hostname is lowercase with trailing dots removed.

**Fix:** If you suspect cache stale-ness:
```bash
# In Rails console:
Rails.cache.delete("bt:platform_domain:tenant-a.example.com")

# Or clear all cache:
Rails.cache.clear
```

### Symptom: Platform ID is nil in background jobs

**Cause:** Background jobs need explicit platform context (unlike web requests where middleware sets it).

**Fix:** In job code, set `Current.platform` explicitly:
```ruby
class MyJob
  include Sidekiq::Worker

  def perform(platform_id)
    platform = BetterTogether::Platform.find(platform_id)
    BetterTogether::Current.platform = platform

    # Now platform_scoped operations work
    posts = BetterTogether::Page.for_platform(platform)
  end
end
```

---

## Database Scaling Considerations

All platforms share one PostgreSQL database. Consider:

- **Connection pool size:** Each Rails process uses pool connections. With N Rails processes and pool size P, you need N×P total connections available. Set in `config/database.yml`:
  ```yaml
  pool: <%= ENV.fetch('RAILS_MAX_THREADS') { 5 } %>
  ```

- **Backups:** One backup covers all platforms. Backup size grows with each platform's content.

- **Replication:** If using read replicas, all platforms replicate together.

- **Performance:** Heavy load on one platform doesn't affect routing to others (queries are scoped), but shares connection pool and cache.

For deployments with 10+ platforms or very high load, consider schema-per-tenant isolation (future feature).

---

## Operating Multiple Platforms

### Adding a Platform
See **Step-by-Step Setup** above.

### Removing a Platform

**Warning:** Content is not automatically deleted. Decide first whether to archive or destroy.

```ruby
# Archive approach: mark platform as inactive
platform.update!(external: true)  # or add an 'archived' flag

# Destroy approach: delete all content first
platform.pages.destroy_all
platform.posts.destroy_all
platform.events.destroy_all
# Then destroy the platform
platform.destroy
```

### Updating Platform Settings

```ruby
platform.update!(
  requires_invitation: true,  # Restrict registration
  allow_membership_requests: true,  # Allow users to request join
  feature_gate_rollouts: {
    'new_content_blocks' => 'beta'
  }
)
```

### Monitoring

Monitor per-platform:
- Page loads by platform (in `better_together_metrics_page_views` table, scoped by `platform_id`)
- Content created (pages, posts, events) by platform
- User sign-ups and activity by platform

Example:
```ruby
# Activity on tenant-a platform
BetterTogether::Metrics::PageView.where(platform_id: tenant_a_platform.id).count
BetterTogether::Page.for_platform(tenant_a_platform).count
BetterTogether::PersonPlatformMembership.where(joinable: tenant_a_platform).count  # members
```

---

## Related Documentation

- **[Multi-Tenant Platform Runtime](../developers/systems/multi_tenant_platform_runtime.md)** — Technical architecture for developers
- **[Multi-Tenant Platform Runtime Flow Diagram](../diagrams/source/multi_tenant_platform_runtime_flow.mmd)** — Visual reference
- **[Storage Configuration Guide](../platform_organizers/storage_configuration_guide.md)** — Per-platform storage setup
- **[Platform Setup Wizard](../releases/0.11.0_setup_wizard_and_platform_bootstrap.md)** — First-time host platform setup
- **[Deployment on Dokku](./deployment-dokku.md)** — Server-level deployment
- **[External Services Configuration](./external-services-to-configure.md)** — Environment variables reference
