# Schema-Per-Tenant Multi-Tenancy Implementation Plan

**Version:** 1.0  
**Date:** January 26, 2026  
**Status:** Planning

## Executive Summary

Implement PostgreSQL schema-per-tenant multi-tenancy architecture for the Better Together Community Engine using the ros-apartment gem. Only the platforms table remains in the PUBLIC schema, with all other data isolated in tenant-specific schemas. Support both custom domains and subdomains for tenant platforms, with automatic schema provisioning, backup/restore tooling, and tenant-aware background jobs.

## Architecture Overview

### Current State
- Single-host mode with `host: true` flag on Platform model
- All data stored in PUBLIC schema with row-level `platform_id` scoping
- Single domain per deployment via `url` column
- No tenant isolation at database level

### Target State
- Schema-per-tenant PostgreSQL architecture
- Only `better_together_platforms` table in PUBLIC schema
- Host platform has dedicated tenant schema (e.g., `tenant_host_abc123`)
- Tenant platforms have isolated schemas (e.g., `tenant_forum_def456`)
- Support for custom domains (`mycommunity.org`) and subdomains (`forum.example.com`)
- Automatic schema provisioning with seed data
- Tenant-aware Sidekiq jobs and ActionMailer
- Per-tenant backup/restore capabilities

### Key Components
1. **ros-apartment gem** - Schema switching and migration tooling
2. **TenantResolver** - Request-based platform detection via domain/subdomain
3. **Apartment Elevator** - Rack middleware for per-request schema switching
4. **Sidekiq Middleware** - Tenant context preservation in background jobs
5. **Provisioning Job** - Async schema creation with retry and notifications
6. **Backup/Restore Tasks** - Per-tenant database operations

---

## User Stories by Stakeholder

### Platform Organizers

#### Story 1: Custom Domain Configuration
**As a** platform organizer  
**I want to** configure a custom domain for my platform  
**So that** my community members can access our platform at our branded domain

**Acceptance Criteria:**
- Platform organizers can set a custom domain in platform settings
- Domain validation ensures proper format (e.g., `community.org`)
- Platform organizers can optionally configure subdomain (e.g., `forum.community.org`)
- Domain uniqueness is enforced across all platforms
- Changes to domain require confirmation to prevent accidental breaking changes
- Platform automatically provisions new schema based on subdomain/domain
- Previous domain continues to redirect to new domain for 30 days

#### Story 2: Platform Provisioning Status Visibility
**As a** platform organizer  
**I want to** see the provisioning status of my platform  
**So that** I know when my platform is ready to use

**Acceptance Criteria:**
- Platform list shows provision status badge (pending, provisioning, completed, failed)
- Timestamp shows when provisioning completed
- Failed platforms display error message with details
- Retry button available for failed provisioning attempts
- Provisioning progress shows estimated completion time
- Email notification sent when provisioning completes or fails

#### Story 3: Platform Data Backup Management
**As a** platform organizer  
**I want to** manage backups of my platform's data  
**So that** I can restore in case of data loss or corruption

**Acceptance Criteria:**
- Platform organizers can trigger manual backup from admin panel
- Backup list shows all available backups with timestamps and sizes
- Automatic daily backups run for all active platforms
- Last backup timestamp visible in platform list with warning if > 7 days old
- Platform organizers can download backup files
- Backup retention policy automatically removes old backups (7 daily + 4 weekly + 12 monthly)
- Restore operation requires confirmation and shows data loss warning

---

### End Users

#### Story 4: Seamless Tenant Access
**As an** end user  
**I want to** access my community platform via its custom domain  
**So that** I have a consistent branded experience

**Acceptance Criteria:**
- Users can navigate to platform's custom domain (e.g., `mycommunity.org`)
- Users can navigate to platform via subdomain (e.g., `forum.example.com`)
- All authentication and session management works correctly per tenant
- User data is isolated to their platform's schema (no cross-tenant data leakage)
- Page load performance is comparable to current single-tenant architecture
- Unknown domains redirect to host platform or show 404 page

#### Story 5: Platform Registration and Onboarding
**As a** new community organizer  
**I want to** create a new platform through the setup wizard  
**So that** I can start building my community

**Acceptance Criteria:**
- Setup wizard prompts for platform domain/subdomain configuration
- Domain availability checked in real-time
- Schema provisioning happens synchronously during host platform setup
- Setup wizard shows provisioning progress indicator
- Failed provisioning displays error with retry option (doesn't block platform creation)
- Successful setup redirects to new platform domain
- Initial seed data (communities, roles, settings) populated automatically

---

### Developers

#### Story 6: Tenant-Aware Background Jobs
**As a** developer  
**I want** background jobs to automatically execute in the correct tenant schema  
**So that** data operations affect the intended platform

**Acceptance Criteria:**
- All Sidekiq jobs automatically inherit tenant context from request
- Jobs explicitly accept `platform_id` parameter for tenant resolution
- Sidekiq middleware switches to correct schema before job execution
- Current.platform set correctly in job context
- Failed tenant switch raises clear error with platform details
- Job retry preserves original tenant context
- Job logs include tenant schema name for debugging

#### Story 7: Tenant-Aware Mailers
**As a** developer  
**I want** mailers to render with correct tenant context and URLs  
**So that** emails contain platform-specific branding and links

**Acceptance Criteria:**
- Mailers automatically switch to tenant schema for data queries
- Email URLs use tenant's custom domain for links
- Default URL options set from Current.platform.domain
- Mailer jobs inherit tenant context via Sidekiq middleware
- Email templates can access tenant-scoped data (users, posts, etc.)
- Noticed notifications properly scope to tenant platform

#### Story 8: Migration and Schema Management
**As a** developer  
**I want** database migrations to run in all tenant schemas automatically  
**So that** schema changes apply consistently across platforms

**Acceptance Criteria:**
- `rails db:migrate` runs migrations in PUBLIC schema first
- `apartment:migrate` runs migrations in all tenant schemas in parallel
- Failed tenant migrations don't block other tenants
- Migration status tracked per tenant
- Rake tasks available for manual tenant schema operations
- Rollback procedures documented and tested
- Migrations can target PUBLIC-only or tenant-only tables

---

### System Administrators

#### Story 9: Host Platform Data Migration
**As a** system administrator  
**I want to** migrate existing host platform data from PUBLIC to tenant schema  
**So that** architecture is consistent across all platforms

**Acceptance Criteria:**
- `tenant:migrate_host_to_schema` rake task available
- Pre-flight checks validate: host exists, schema completed, backup exists, no active jobs
- Task requires `CONFIRM=yes` environment variable to prevent accidents
- Migration wrapped in database transaction for rollback capability
- Row counts verified before and after migration
- PUBLIC tables dropped only after manual confirmation
- Rollback procedure documented with step-by-step instructions
- Migration can be tested on staging environment first

#### Story 10: Automated Tenant Backups
**As a** system administrator  
**I want** automated daily backups for all tenant schemas  
**So that** data is protected without manual intervention

**Acceptance Criteria:**
- Daily background job runs for all completed platforms
- Platforms without backup in 24h automatically backed up
- Backups uploaded to Active Storage (S3/MinIO) with timestamp
- Backup metadata tracked in platforms table (last_backup_at, schema_size_bytes)
- Failed backups trigger admin notification
- Automatic cleanup enforces retention policy (7 daily + 4 weekly + 12 monthly)
- Backup size monitoring alerts when schema grows unusually large
- Backup verification performed periodically (monthly test restore)

#### Story 11: Schema Provisioning Monitoring
**As a** system administrator  
**I want to** monitor schema provisioning success/failure rates  
**So that** I can identify and resolve infrastructure issues

**Acceptance Criteria:**
- Admin dashboard shows provision success/failure metrics
- Platforms stuck in "provisioning" status for >10 minutes flagged
- Failed provision count displayed with trend graph
- Average provision time tracked and alerted on anomalies
- Failed platforms show detailed error logs in admin panel
- Bulk retry operation available for multiple failed platforms
- Schema size metrics displayed per platform with sorting capability
- Export provision history to CSV for analysis

#### Story 12: Cross-Tenant Operations
**As a** system administrator  
**I want to** perform global search and reporting across all platforms  
**So that** I can analyze usage patterns and identify issues

**Acceptance Criteria:**
- Admin global search iterates all tenant schemas via `Apartment::Tenant.each`
- Search results indicate source platform for each result
- Performance warnings displayed when >10 platforms exist
- Elasticsearch integration recommended and documented for cross-tenant search
- Cross-platform reports aggregate data from all schemas
- Query timeout protection prevents long-running cross-tenant operations
- Documentation includes performance implications and best practices
- Ability to exclude specific platforms from global operations

---

## Technical Implementation Steps

### Phase 1: Foundation (Sprint 1)

#### Step 1.1: Add ros-apartment Dependency
**Tasks:**
- Add `spec.add_dependency 'ros-apartment', '~> 3.4'` to `better_together.gemspec`
- Add to `Gemfile` for development
- Run `bundle install`
- Require in `lib/better_together/engine.rb` via `require 'apartment'`

**Acceptance Criteria:**
- Gem successfully added to gemspec dependencies
- Bundle install completes without errors
- Engine loads without errors in development/test
- No version conflicts with existing gems

#### Step 1.2: Configure Apartment
**Tasks:**
- Create `config/initializers/apartment.rb`
- Exclude only `better_together_platforms` from tenant schemas
- Configure `use_schemas: true` for PostgreSQL
- Set `default_schema: 'public'`
- Configure `parallel_migration_threads: 4`
- Set `tenant_names` lambda querying completed platforms

**Acceptance Criteria:**
- Initializer loads without errors
- Configuration uses PostgreSQL schema mode
- Only platforms table excluded from tenant schemas
- Tenant names dynamically loaded from database
- Parallel migrations enabled for performance

#### Step 1.3: Database Schema Changes
**Tasks:**
- Create migration adding columns to `better_together_platforms`:
  - `domain` (string, nullable)
  - `subdomain` (string, nullable)
  - `schema_name` (string, nullable)
  - `provision_status` (string, default: 'pending')
  - `provision_error` (text, nullable)
  - `provisioned_at` (datetime)
  - `last_backup_at` (datetime)
  - `schema_size_bytes` (bigint, default: 0)
- Add composite unique index on `[:subdomain, :domain]`
- Add unique index on `schema_name`
- Add index on `provision_status`

**Acceptance Criteria:**
- Migration runs successfully in development/test
- Indexes created for performance
- Existing platforms have null values for new columns
- No data loss during migration
- Rollback works correctly

---

### Phase 2: Core Tenant Logic (Sprint 1-2)

#### Step 2.1: Platform Model Enhancements
**Tasks:**
- Add enum `provision_status: { pending, provisioning, completed, failed }`
- Add validations:
  - Subdomain format: `/\A[a-z0-9]+(?:-[a-z0-9]+)*\z/`
  - Schema name format: `/\A[a-z_][a-z0-9_]*\z/`
  - `validates :schema_name, absence: true, if: :external?`
- Add `before_validation :populate_domain_from_url` callback
- Add `before_validation :generate_schema_name` callback
- Implement schema name generation with SecureRandom suffix
- Add uniqueness retry loop for schema name collisions

**Acceptance Criteria:**
- Enum states work correctly with state transitions
- Subdomain validation rejects invalid formats
- Schema name validation ensures PostgreSQL compatibility
- External platforms cannot have schema names
- Domain populated from existing url column data
- Schema names globally unique with format `tenant_{subdomain/identifier}_{hex}`
- Collision retry generates new name automatically

#### Step 2.2: TenantResolver Service
**Tasks:**
- Create `lib/better_together/tenant_resolver.rb`
- Implement request host parsing
- Match Platform by exact `domain` first
- Extract subdomain and match `[subdomain, domain]` composite
- Filter `where(external: false, provision_status: 'completed')`
- Return matched Platform record
- Fallback to `Platform.find_by(host: true, provision_status: 'completed')`
- Handle nil platform with public schema default

**Acceptance Criteria:**
- Custom domains match correctly (e.g., `mycommunity.org`)
- Subdomain patterns match (e.g., `forum.example.com`)
- Only completed, non-external platforms matched
- Host platform returned for unknown domains
- Public schema used when no platform found
- Thread-safe for concurrent requests
- Comprehensive test coverage for all match scenarios

#### Step 2.3: Apartment Elevator
**Tasks:**
- Create `lib/better_together/apartment_elevator.rb`
- Implement `parse_tenant_name(request)` method
- Detect setup wizard routes (`/setup/*`) returning `'public'`
- Call TenantResolver for other routes
- Return `platform.schema_name || 'public'`
- Mount elevator in `lib/better_together/engine.rb`
- Configure via `config.middleware.use Apartment::Elevators::Generic`

**Acceptance Criteria:**
- Setup wizard always uses public schema
- Other routes resolve to tenant schema correctly
- Middleware properly integrated in request cycle
- Current schema available via `Apartment::Tenant.current`
- Failed tenant resolution returns public schema
- Elevator executes before controller actions
- Performance overhead < 2ms per request

---

### Phase 3: Provisioning System (Sprint 2)

#### Step 3.1: TenantSchema Concern
**Tasks:**
- Create `app/models/concerns/better_together/tenant_schema.rb`
- Implement `provision_schema_now!` method:
  - Update status to `provisioning`
  - Call `Apartment::Tenant.create(schema_name)`
  - Switch to new schema
  - Run migrations via `ActiveRecord::Migrator.migrate`
  - Load seed data via `Rails.application.load_seed`
  - Update status to `completed` with timestamp
  - Rescue errors to set `failed` with error message (no raise)
- Implement `enqueue_provision_job` method
- Add `after_create :provision_or_enqueue` callback
- Add `retry_provisioning!` method

**Acceptance Criteria:**
- Synchronous provisioning completes for host platform during setup
- Async provisioning enqueued for tenant platforms
- Schema creation, migration, and seeding work correctly
- Errors captured and logged without raising exceptions
- Provision status updated throughout lifecycle
- Retry method resets status and re-runs provisioning
- Empty database provisions successfully (setup wizard case)

#### Step 3.2: Provisioning Background Job
**Tasks:**
- Create `app/jobs/better_together/provision_tenant_schema_job.rb`
- Accept `platform_id` parameter
- Load platform and call `provision_schema_now!`
- Configure retry: `retry_on StandardError, wait: :exponentially_longer, attempts: 5`
- On max retries, send `PlatformProvisionFailedNotifier`
- Include error details and retry button in notification
- Log all provisioning attempts with outcomes

**Acceptance Criteria:**
- Job enqueues successfully from platform creation
- Retries occur with exponential backoff (3s, 9s, 27s, 81s, 243s)
- Max retries exhausted triggers notification
- Platform creator receives notification with retry link
- Error details logged for debugging
- Job execution isolated to tenant schema
- Multiple platforms can provision concurrently

---

### Phase 4: Sidekiq Integration (Sprint 2-3)

#### Step 4.1: Sidekiq Client Middleware
**Tasks:**
- Create `lib/better_together/sidekiq/client_middleware.rb`
- Capture `Current.platform&.id` when job enqueued
- Store as `tenant_platform_id` in job payload
- Handle nil platform (public schema case)

**Acceptance Criteria:**
- All enqueued jobs include tenant context
- Platform ID stored in job metadata
- Works with Sidekiq's default serialization
- No performance impact on job enqueuing
- Handles nil platform gracefully

#### Step 4.2: Sidekiq Server Middleware
**Tasks:**
- Create `lib/better_together/sidekiq/server_middleware.rb`
- Extract `tenant_platform_id` from job payload
- Load Platform record
- Switch to platform's schema via `Apartment::Tenant.switch`
- Set `Current.platform` for job duration
- Ensure schema reset after job completes

**Acceptance Criteria:**
- Jobs execute in correct tenant schema
- Current.platform available in job context
- Schema resets to public after execution
- Failed jobs don't leak schema context
- Thread-safe across Sidekiq workers
- Works with retried jobs
- Handles missing/deleted platforms gracefully

#### Step 4.3: Sidekiq Configuration
**Tasks:**
- Create or update `config/initializers/sidekiq.rb`
- Register client middleware in `Sidekiq.configure_client`
- Register server middleware in `Sidekiq.configure_server`
- Ensure middleware order correct relative to other middleware

**Acceptance Criteria:**
- Middleware registered in correct order
- Client and server middleware both active
- Works with existing Sidekiq configuration
- No conflicts with other middleware
- Initialization completes without errors

---

### Phase 5: ActionMailer Integration (Sprint 3)

#### Step 5.1: ApplicationMailer Tenant Context
**Tasks:**
- Update `app/mailers/better_together/application_mailer.rb`
- Wrap `mail()` calls in `Apartment::Tenant.switch` block
- Use `Current.platform&.schema_name || 'public'` for schema
- Set `default_url_options` dynamically
- Use `Current.platform&.domain` for host
- Ensure mailer jobs inherit Sidekiq middleware

**Acceptance Criteria:**
- Mailers query data from correct tenant schema
- Email URLs use tenant's custom domain
- Links in emails point to tenant domain
- Template rendering accesses tenant data correctly
- Mailer jobs execute with tenant context via Sidekiq
- Public schema used when no tenant context available
- Noticed notifications work with tenant scoping

---

### Phase 6: Admin Interface (Sprint 3-4)

#### Step 6.1: Setup Wizard Updates
**Tasks:**
- Update `app/controllers/better_together/setup/platforms_controller.rb`
- Add `prepend_before_action :use_public_schema`
- Implement `use_public_schema` method calling `Apartment::Tenant.reset`
- Check `provision_status` after platform creation
- Show error page if status is `failed`
- Provide retry button calling `retry_provisioning!`
- Redirect to platform domain only when `completed`

**Acceptance Criteria:**
- Setup wizard executes in public schema
- Host platform provisioning completes synchronously
- Failed provisioning shows error with retry option
- Successful provisioning redirects to new domain
- Setup wizard accessible even with failed provisioning
- User feedback clear throughout provisioning process

#### Step 6.2: Platform List Enhancements
**Tasks:**
- Update `app/views/better_together/platforms/index.html.erb`
- Add provision status badge column (color-coded)
- Add provisioned_at timestamp column
- Add last_backup_at column with warning if > 7 days
- Add schema size display from `pg_total_relation_size` query
- Add retry button for failed platforms
- Enable sorting by provision status and schema size
- Update controller to add `retry_provisioning` action

**Acceptance Criteria:**
- Provision status visible at a glance with color coding
- Timestamps display in user's timezone
- Backup warnings appear for outdated backups
- Schema sizes shown in human-readable format (MB/GB)
- Retry button only visible for failed platforms
- Sorting works correctly on all columns
- Retry action successfully re-provisions failed platforms

#### Step 6.3: Platform Provision Failed Notifier
**Tasks:**
- Create `app/notifiers/better_together/platform_provision_failed_notifier.rb`
- Extend from `Noticed::Base`
- Accept platform and error parameters
- Configure delivery methods (database, email)
- Create email template with error details
- Include retry button linking to retry action
- Send to platform creator

**Acceptance Criteria:**
- Notification sent when max retries exhausted
- Email includes clear error description
- Retry link navigates to platform admin with retry option
- Database notification visible in user's notification center
- Notification marked as read when retry attempted
- Template styled consistently with platform branding

---

### Phase 7: Backup & Restore (Sprint 4)

#### Step 7.1: Backup Rake Tasks
**Tasks:**
- Create `lib/tasks/better_together/tenant_backup.rake`
- Implement `tenant:backup[platform_id]` task:
  - Execute `pg_dump -n schema_name -Fc`
  - Upload to Active Storage with timestamp
  - Update `last_backup_at` and `schema_size_bytes`
- Implement `tenant:list_backups[platform_id]` task
- Implement `tenant:cleanup_old_backups[platform_id]` task
- Enforce retention: 7 daily + 4 weekly + 12 monthly

**Acceptance Criteria:**
- Backup creates compressed PostgreSQL dump
- Dump uploaded to configured storage (S3/MinIO)
- Timestamp included in filename
- Platform record updated with backup metadata
- List shows all available backups with sizes
- Cleanup removes old backups per retention policy
- Tasks handle missing platforms gracefully
- Progress feedback provided during backup

#### Step 7.2: Restore Rake Task
**Tasks:**
- Implement `tenant:restore[platform_id, backup_file]` task
- Require confirmation before restore
- Display data loss warning
- Drop existing schema
- Create new schema
- Restore from backup file via `pg_restore`
- Update platform status after restore

**Acceptance Criteria:**
- Restore requires explicit confirmation
- Warning clearly states existing data will be lost
- Backup file validated before restore
- Schema successfully recreated from backup
- Restore completes without errors
- Platform accessible after restore
- Rollback procedure documented if restore fails

#### Step 7.3: Automated Backup Job
**Tasks:**
- Create `app/jobs/better_together/tenant_backup_job.rb`
- Run daily via Sidekiq cron or whenever gem
- Query platforms where `last_backup_at < 24.hours.ago`
- Trigger backup for each platform
- Enqueue cleanup job after successful backup
- Send notification on backup failure
- Track backup metrics (duration, size)

**Acceptance Criteria:**
- Job runs automatically every 24 hours
- Only platforms needing backup are processed
- Backups complete successfully for all platforms
- Cleanup runs after each successful backup
- Failed backups notify administrators
- Metrics logged for monitoring
- Job handles large numbers of platforms efficiently

---

### Phase 8: Data Migration (Sprint 5)

#### Step 8.1: Host Platform Migration Rake Task
**Tasks:**
- Create `lib/tasks/better_together/tenant_migration.rake`
- Implement `tenant:migrate_host_to_schema` task
- Perform pre-flight checks:
  - Host platform exists
  - Schema provisioned successfully
  - No active background jobs
  - Backup exists within 24 hours
- Require `CONFIRM=yes` environment variable
- Use transaction wrapping data copy
- Execute `INSERT INTO #{schema_name}.#{table} SELECT * FROM public.#{table}`
- Verify row counts before and after
- Prompt before dropping PUBLIC tables
- Document rollback procedure in task description

**Acceptance Criteria:**
- Pre-flight checks prevent dangerous operations
- Confirmation required prevents accidental execution
- Transaction ensures atomic operation
- Row counts verified for data integrity
- PUBLIC tables only dropped after manual confirmation
- Task output clearly documents each step
- Rollback procedure tested and documented
- Can be executed on staging environment for testing

---

### Phase 9: Documentation (Sprint 5)

#### Step 9.1: Cross-Tenant Operations Guide
**Tasks:**
- Create `docs/implementation/multi_tenancy/cross_tenant_operations.md`
- Document iteration pattern over `Apartment.tenant_names`
- Explain performance implications
- Provide code examples for common operations
- Recommend Elasticsearch for global search
- Document qualified table name usage for PUBLIC access

**Acceptance Criteria:**
- Documentation includes working code examples
- Performance considerations clearly explained
- Elasticsearch integration path documented
- Examples cover common use cases (search, reporting, aggregation)
- Best practices highlighted
- Anti-patterns warned against

#### Step 9.2: Deployment Migration Guide
**Tasks:**
- Create `docs/deployment/multi_tenant_migration.md`
- Document deployment process step-by-step
- Include pre-migration checklist
- Document expected downtime windows
- Provide rollback procedures
- Include post-migration validation steps
- Document troubleshooting common issues

**Acceptance Criteria:**
- Guide covers complete deployment process
- Checklists ensure no steps missed
- Downtime estimates realistic
- Rollback procedures tested
- Validation steps verify successful migration
- Troubleshooting section comprehensive
- Safe for operations team to execute

#### Step 9.3: Monitoring and Alerting Guide
**Tasks:**
- Document provision success/failure monitoring
- Explain schema size tracking
- Provide backup monitoring procedures
- Document alert thresholds and responses
- Include dashboard configuration examples

**Acceptance Criteria:**
- Monitoring covers all critical metrics
- Alert thresholds appropriate for production
- Response procedures documented
- Dashboard examples provided
- Integration with existing monitoring systems documented

---

## Testing Strategy

### Unit Tests
- Platform model validations (subdomain format, schema name format)
- Schema name generation with collision retry
- TenantResolver matching logic (domain, subdomain, fallback)
- Provision status state transitions

### Integration Tests
- Schema provisioning (create, migrate, seed)
- Sidekiq middleware (client and server)
- ActionMailer tenant context switching
- Apartment elevator request routing

### Feature Tests
- Setup wizard platform creation flow
- Platform provisioning retry from admin panel
- Backup creation and restoration
- Cross-tenant search operations

### Performance Tests
- Elevator overhead per request (target: < 2ms)
- Concurrent platform provisioning
- Large-scale migration (100+ platforms)
- Backup/restore operations on large schemas

### Security Tests
- Tenant isolation (no cross-schema data leakage)
- Domain hijacking prevention
- Schema name injection attacks
- Backup file access controls

---

## Rollout Plan

### Development Environment
1. Install ros-apartment gem
2. Run migrations adding new columns
3. Test schema provisioning locally
4. Verify middleware integration
5. Test backup/restore operations

### Staging Environment
1. Deploy with ros-apartment enabled
2. Create test tenant platforms
3. Verify provisioning works end-to-end
4. Test migration of mock host data
5. Performance test with realistic data volumes
6. Security audit for tenant isolation

### Production Deployment
1. **Pre-deployment:**
   - Full database backup
   - Notify users of maintenance window
   - Scale up infrastructure if needed

2. **Deployment:**
   - Deploy application with ros-apartment
   - Run database migrations
   - Execute host platform migration task
   - Verify host platform accessible

3. **Post-deployment:**
   - Validate tenant isolation
   - Monitor provision success rates
   - Check background job processing
   - Verify email delivery with correct domains
   - Enable automated backups

4. **Rollback Plan:**
   - Restore database from pre-deployment backup
   - Revert application to previous version
   - Verify host platform accessible
   - Communicate status to users

---

## Success Metrics

### Technical Metrics
- **Provisioning Success Rate:** > 99%
- **Average Provision Time:** < 30 seconds
- **Elevator Overhead:** < 2ms per request
- **Failed Provision Recovery Time:** < 5 minutes
- **Backup Success Rate:** 100%
- **Schema Isolation:** 0 cross-tenant data leaks

### Operational Metrics
- **Platform Creation Time:** < 1 minute (including provisioning)
- **Backup Retention Compliance:** 100%
- **Failed Platform Count:** < 1% of total
- **Migration Downtime:** < 1 hour
- **Recovery Time Objective (RTO):** < 4 hours
- **Recovery Point Objective (RPO):** < 24 hours

### User Experience Metrics
- **Setup Wizard Completion Rate:** > 95%
- **Domain Configuration Success:** > 98%
- **User-Reported Tenant Isolation Issues:** 0
- **Platform Organizer Satisfaction:** > 4.5/5

---

## Risk Assessment

### High Risk
1. **Data Loss During Migration**
   - Mitigation: Full backups, transaction wrapping, row count verification
   - Contingency: Rollback procedure, restore from backup

2. **Cross-Tenant Data Leakage**
   - Mitigation: Comprehensive security testing, Pundit policy updates
   - Contingency: Immediate schema isolation audit, user notification

### Medium Risk
3. **Performance Degradation**
   - Mitigation: Performance testing, elevator overhead monitoring
   - Contingency: Schema caching, connection pooling optimization

4. **Failed Schema Provisioning**
   - Mitigation: Retry logic, error notifications, manual intervention
   - Contingency: Background retry queue, support team escalation

### Low Risk
5. **Backup Storage Costs**
   - Mitigation: Retention policy, compression, lifecycle rules
   - Contingency: Cost monitoring, storage tier optimization

6. **Migration Complexity**
   - Mitigation: Comprehensive documentation, staging environment testing
   - Contingency: Rollback procedures, support team training

---

## Dependencies

### Technical Dependencies
- **ros-apartment gem** (v3.4+) - Schema switching
- **PostgreSQL** (11+) - Schema support
- **Active Storage** - Backup storage
- **Sidekiq** - Background job processing
- **Redis** - Job queue and caching

### Team Dependencies
- **Backend Team** - Implementation and testing
- **DevOps Team** - Infrastructure and deployment
- **QA Team** - Security and performance testing
- **Support Team** - Documentation and user training

### External Dependencies
- **S3/MinIO** - Backup storage service
- **DNS Provider** - Custom domain routing
- **SSL Certificates** - HTTPS for custom domains

---

## Timeline Estimate

### Sprint 1 (2 weeks)
- Add ros-apartment gem and configuration
- Database schema changes
- Platform model enhancements
- TenantResolver and Apartment elevator

### Sprint 2 (2 weeks)
- Provisioning system implementation
- Sidekiq middleware integration
- Comprehensive testing

### Sprint 3 (2 weeks)
- ActionMailer tenant context
- Setup wizard updates
- Platform admin interface enhancements

### Sprint 4 (2 weeks)
- Backup and restore tooling
- Automated backup scheduling
- Performance optimization

### Sprint 5 (2 weeks)
- Host platform migration task
- Documentation completion
- Production deployment preparation

**Total Estimated Timeline:** 10 weeks (5 sprints)

---

## Appendix

### Glossary
- **Tenant:** A platform instance with isolated data in dedicated schema
- **Host Platform:** The primary platform instance that manages the deployment
- **Schema:** PostgreSQL namespace containing tables for a single tenant
- **Elevator:** Apartment middleware that determines tenant from request
- **Provisioning:** Process of creating schema, running migrations, and seeding data

### Related Documentation
- `docs/implementation/data_model/multi_tenancy_strategy.md` (to be created)
- `docs/implementation/multi_tenancy/cross_tenant_operations.md` (to be created)
- `docs/deployment/multi_tenant_migration.md` (to be created)
- `docs/development/timezone_handling_strategy.md` (existing)

### References
- [ros-apartment GitHub](https://github.com/rails-on-services/apartment)
- [PostgreSQL Schema Documentation](https://www.postgresql.org/docs/current/ddl-schemas.html)
- [Rails Multi-Database Guide](https://guides.rubyonrails.org/active_record_multiple_databases.html)
