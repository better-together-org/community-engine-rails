# Sitemap Generator Fixes with Multi-Locale Support Implementation Plan

## ⚠️ COLLABORATIVE REVIEW REQUIRED

**This implementation plan addresses critical security and functionality issues found in PR #1037. The plan must be reviewed before implementation begins.**

---

## Overview

This plan fixes 6 critical findings from the sitemap generator PR review and implements comprehensive multi-locale sitemap support with a sitemap index. The implementation addresses security vulnerabilities (missing privacy filtering), architectural issues (database availability during deployment), and missing test coverage/documentation.

### Problem Statement

**PR #1037 Review Findings:**
1. **CRITICAL SECURITY**: Missing privacy filtering - all Communities, Events, Posts, and Conversations are exposed in sitemap regardless of privacy settings
2. **DEPLOYMENT FAILURE RISK**: Rake task hooks into assets:precompile which runs before database is available during Docker builds
3. **MISSING TESTS**: No model spec, no factory, incomplete job test coverage
4. **NO DOCUMENTATION**: Violates PR policy requiring docs and diagrams for new features
5. **INCOMPLETE LOCALE SUPPORT**: Hardcoded to default locale only, ignoring es/fr/uk translations
6. **MISSING SITEMAP INDEX**: With 4 locales, need proper sitemap index for SEO best practices

### Success Criteria

- ✅ Only public resources appear in sitemaps (privacy filtering validated by tests)
- ✅ Sitemap generation works in Docker environment (gracefully handles missing database)
- ✅ One sitemap per locale (en, es, fr, uk) plus sitemap index
- ✅ Comprehensive test coverage (factory, model spec, enhanced job spec, request spec)
- ✅ Complete documentation with process flow diagram
- ✅ All existing tests pass after changes

## Stakeholder Analysis

### Primary Stakeholders
- **Platform Organizers**: Need SEO-optimized sitemaps for discoverability while protecting private community content
- **Community Organizers**: Need assurance that private community content doesn't leak into public sitemaps
- **End Users**: Benefit from better search engine indexing in their preferred language

### Secondary Stakeholders  
- **Developers**: Need clear documentation, proper test coverage, and maintainable code
- **DevOps**: Need deployment process that doesn't fail when database unavailable

### Collaborative Decision Points
- Privacy filtering approach (approved: use `.privacy_public` scope)
- Multi-locale architecture (approved: one record per platform+locale combination)
- Sitemap index implementation (approved: use sitemap_generator's `create_index`)
- 404 vs fallback behavior (approved: 404 for missing/invalid locale)

## Implementation Priority Matrix

### Phase 1: Security & Database Fixes (CRITICAL - Immediate)
**Priority: CRITICAL** - Blocks PR merge, security vulnerability

1. **Add privacy filtering** - Prevent private content exposure
2. **Add database availability checks** - Prevent deployment failures
3. **Remove assets:precompile hook** - Database not available during build

### Phase 2: Multi-Locale Support (HIGH - Required for Feature Completion)
**Priority: HIGH** - Completes feature, SEO requirement

1. **Add locale column and update schema** - Enable per-locale sitemaps
2. **Update model for multi-locale** - Support platform+locale uniqueness
3. **Generate per-locale sitemaps** - One sitemap per language
4. **Generate sitemap index** - Aggregate locale sitemaps

### Phase 3: Testing & Documentation (HIGH - PR Merge Requirement)
**Priority: HIGH** - Required by project standards

1. **Create factory and model spec** - Test coverage for Sitemap model
2. **Enhance job and request specs** - Multi-locale and privacy validation
3. **System documentation** - Architecture, usage, troubleshooting
4. **Process flow diagram** - Visual representation of sitemap generation

## Detailed Implementation Steps

### Step 1: Update Configuration for All 4 Locales
**File**: `spec/dummy/config/application.rb` (line 38)

**Changes**:
```ruby
# Before
config.i18n.available_locales = %i[en es fr]

# After
config.i18n.available_locales = %i[en es fr uk]
```

**Rationale**: Enable Ukrainian locale support to match existing translation files.

---

### Step 2: Add Locale Column to Sitemaps Table
**File**: New migration `db/migrate/[timestamp]_add_locale_to_better_together_sitemaps.rb`

**Changes**:
```ruby
class AddLocaleToBetterTogetherSitemaps < ActiveRecord::Migration[7.1]
  def change
    # Add locale column
    add_column :better_together_sitemaps, :locale, :string, null: false, default: 'en'
    
    # Remove old unique index on platform_id only
    remove_index :better_together_sitemaps, name: 'unique_sitemaps_platform'
    
    # Add compound unique index on platform_id + locale
    add_index :better_together_sitemaps, 
              %i[platform_id locale], 
              unique: true, 
              name: 'unique_sitemaps_by_platform_and_locale'
  end
end
```

**Migration Command**: `bin/dc-run-dummy rails db:migrate`

**Rationale**: Support one sitemap record per platform+locale combination, following existing codebase patterns for locale-specific data.

---

### Step 3: Update Sitemap Model for Multi-Locale Support
**File**: `app/models/better_together/sitemap.rb`

**Changes**:
```ruby
# frozen_string_literal: true

module BetterTogether
  # Stores the generated sitemap in Active Storage for serving via S3
  class Sitemap < ApplicationRecord
    belongs_to :platform
    has_one_attached :file

    validates :platform_id, uniqueness: { scope: :locale }
    validates :locale, presence: true, 
                       inclusion: { in: I18n.available_locales.map(&:to_s) }

    # Find or create sitemap for a specific platform and locale
    def self.current(platform, locale = I18n.locale)
      find_or_create_by!(platform: platform, locale: locale.to_s)
    end
    
    # Find or create sitemap index for a platform
    def self.current_index(platform)
      find_or_create_by!(platform: platform, locale: 'index')
    end
  end
end
```

**Rationale**: 
- Validates locale is in available locales
- Platform+locale uniqueness ensures one sitemap per language
- `current_index` supports sitemap index file (locale: 'index')

---

### Step 4: Refactor Sitemap Configuration with Privacy Filtering
**File**: `config/sitemap.rb`

**Changes**:
```ruby
# frozen_string_literal: true

SitemapGenerator::Sitemap.default_host =
  "#{ENV.fetch('APP_PROTOCOL', 'http')}://#{ENV.fetch('APP_HOST', 'localhost:3000')}"

helpers = BetterTogether::Engine.routes.url_helpers

# Generate one sitemap per locale
I18n.available_locales.each do |locale|
  SitemapGenerator::Sitemap.public_path = Rails.root.join('tmp')
  SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/#{locale}/"
  
  SitemapGenerator::Sitemap.create do
    add helpers.home_page_path(locale: locale)

    add helpers.communities_path(locale: locale)
    BetterTogether::Community.privacy_public.find_each do |community|
      add helpers.community_path(community, locale: locale), lastmod: community.updated_at
    end

    # Conversations are private by nature - excluded from sitemap

    add helpers.posts_path(locale: locale)
    BetterTogether::Post.published.privacy_public.find_each do |post|
      add helpers.post_path(post, locale: locale), lastmod: post.updated_at
    end

    add helpers.events_path(locale: locale)
    BetterTogether::Event.privacy_public.find_each do |event|
      add helpers.event_path(event, locale: locale), lastmod: event.updated_at
    end

    BetterTogether::Page.published.privacy_public.find_each do |page|
      add helpers.render_page_path(path: page.slug, locale: locale), lastmod: page.updated_at
    end
  end
end

# Generate sitemap index referencing all locale sitemaps
SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
SitemapGenerator::Sitemap.create_index do
  I18n.available_locales.each do |locale|
    add "#{SitemapGenerator::Sitemap.default_host}/#{locale}/sitemap.xml.gz"
  end
end
```

**Rationale**:
- **Privacy filtering**: `.privacy_public` scope prevents private content exposure
- **Conversations removed**: Private by design, shouldn't be in public sitemap
- **Per-locale generation**: Each language gets its own sitemap file
- **Sitemap index**: SEO best practice for multi-locale sites

---

### Step 5: Update Rake Task for Resilience and Multi-Locale
**File**: `lib/tasks/sitemap.rake`

**Changes**:
```ruby
# frozen_string_literal: true

namespace :sitemap do
  desc 'Generate sitemap and upload to Active Storage'
  task refresh: :environment do
    # Check database availability
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
    rescue ActiveRecord::NoDatabaseError, PG::ConnectionBad => e
      puts "⏭️  Skipping sitemap generation (database not available: #{e.message})"
      next
    end
    
    # Check for host platform
    platform = BetterTogether::Platform.find_by(host: true)
    unless platform
      puts "⚠️  No host platform found, skipping sitemap generation"
      next
    end
    
    require 'sitemap_generator'
    
    begin
      SitemapGenerator::Sitemap.public_path = Rails.root.join('tmp')
      
      # Generate one sitemap per locale
      I18n.available_locales.each do |locale|
        SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/#{locale}/"
        load Rails.root.join('config/sitemap.rb')
        
        file_path = Rails.root.join('tmp', 'sitemaps', locale.to_s, 'sitemap.xml.gz')
        BetterTogether::Sitemap.current(platform, locale).file.attach(
          io: File.open(file_path),
          filename: "sitemap_#{locale}.xml.gz",
          content_type: 'application/gzip'
        )
        puts "✅ Sitemap generated for locale: #{locale}"
      end
      
      # Generate sitemap index
      SitemapGenerator::Sitemap.sitemaps_path = 'sitemaps/'
      load Rails.root.join('config/sitemap.rb') # Loads create_index block
      
      index_file_path = Rails.root.join('tmp', 'sitemaps', 'sitemap_index.xml.gz')
      BetterTogether::Sitemap.current_index(platform).file.attach(
        io: File.open(index_file_path),
        filename: 'sitemap_index.xml.gz',
        content_type: 'application/gzip'
      )
      puts "✅ Sitemap index generated successfully"
      
    rescue => e
      puts "❌ Sitemap generation failed: #{e.message}"
      puts e.backtrace.first(5)
    ensure
      # Cleanup tmp files
      FileUtils.rm_rf(Rails.root.join('tmp', 'sitemaps'))
    end
  end
end

# REMOVED: assets:precompile hook
# Reason: Database not available during Docker build asset precompilation
# Use post-deployment cron job or manual trigger instead
```

**Rationale**:
- **Database availability check**: Prevents deployment failures
- **Host platform check**: Gracefully skips if platform not yet created
- **Multi-locale loop**: Generates 4 locale sitemaps + 1 index
- **Error handling**: Try/rescue with backtrace for debugging
- **Cleanup**: Ensure block removes tmp files
- **Removed assets:precompile hook**: Database unavailable during build

---

### Step 6: Update Routes for Locale Scope and Index
**File**: `config/routes.rb`

**Changes**:
```ruby
BetterTogether::Engine.routes.draw do
  # Sitemap index (outside locale scope)
  get '/sitemap_index.xml.gz', to: 'sitemaps#index', as: :sitemap_index

  # Enable Omniauth for Devise
  devise_for :users, class_name: BetterTogether.user_class.to_s,
                     only: :omniauth_callbacks,
                     controllers: { omniauth_callbacks: 'better_together/users/omniauth_callbacks' }

  # Explicit route for OAuth failure callback
  get 'users/auth/failure', to: 'users/omniauth_callbacks#failure', as: :oauth_failure

  scope ':locale',
        locale: /#{I18n.available_locales.join('|')}/ do
    # Locale-specific sitemap (MOVED INTO LOCALE SCOPE)
    get '/sitemap.xml.gz', to: 'sitemaps#show', as: :sitemap
    
    # ... rest of routes
  end
end
```

**Rationale**:
- **Sitemap inside locale scope**: Routes become `/:locale/sitemap.xml.gz`
- **Index outside locale scope**: Single index at `/sitemap_index.xml.gz`
- **Locale constraint**: Only valid locales (en/es/fr/uk) match

---

### Step 7: Update SitemapsController with Locale Validation
**File**: `app/controllers/better_together/sitemaps_controller.rb`

**Changes**:
```ruby
# frozen_string_literal: true

module BetterTogether
  # Serves the generated sitemap stored in Active Storage
  class SitemapsController < ApplicationController
    def show
      # Validate locale parameter
      locale = params[:locale]&.to_sym
      unless locale.in?(I18n.available_locales)
        head :not_found
        return
      end
      
      sitemap = Sitemap.find_by(platform: helpers.host_platform, locale: locale.to_s)
      if sitemap&.file&.attached?
        redirect_to sitemap.file.url, allow_other_host: true # Allow S3/MinIO external URLs
      else
        head :not_found
      end
    end
    
    def index
      sitemap_index = Sitemap.find_by(platform: helpers.host_platform, locale: 'index')
      if sitemap_index&.file&.attached?
        redirect_to sitemap_index.file.url, allow_other_host: true # Allow S3/MinIO external URLs
      else
        head :not_found
      end
    end
  end
end
```

**Rationale**:
- **Locale validation**: Prevents enumeration attacks, returns 404 for invalid locales
- **404 behavior**: Missing sitemap = 404 (no fallback to default locale)
- **Index action**: Serves sitemap index file
- **allow_other_host comment**: Documents why external URLs allowed

---

### Step 8: Create Sitemap Factory
**File**: New `spec/factories/better_together/sitemaps.rb`

**Changes**:
```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory 'better_together/sitemap',
          class: 'BetterTogether::Sitemap',
          aliases: %i[better_together_sitemap sitemap] do
    id { SecureRandom.uuid }
    association :platform, factory: :better_together_platform
    locale { 'en' }
    
    trait :spanish do
      locale { 'es' }
    end
    
    trait :french do
      locale { 'fr' }
    end
    
    trait :ukrainian do
      locale { 'uk' }
    end
    
    trait :index do
      locale { 'index' }
    end
    
    trait :with_file do
      after(:create) do |sitemap|
        sitemap.file.attach(
          io: StringIO.new('test sitemap content'),
          filename: "sitemap_#{sitemap.locale}.xml.gz",
          content_type: 'application/gzip'
        )
      end
    end
  end
end
```

**Rationale**: Follows project factory patterns with UUID, aliases, traits for locales and file attachment.

---

### Step 9: Create Sitemap Model Spec
**File**: New `spec/models/better_together/sitemap_spec.rb`

**Changes**: See full spec in appendix below.

---

### Step 10: Update Layout Link Tags
**File**: `app/views/layouts/better_together/application.html.erb` (line 26)

**Changes**:
```erb
<%= csrf_meta_tags %>
<%= csp_meta_tag %>

<%# Primary sitemap index for search engines %>
<link rel="sitemap" type="application/xml" href="<%= sitemap_index_path %>">

<%# Current locale sitemap %>
<link rel="sitemap" type="application/xml" href="<%= sitemap_path(locale: I18n.locale) %>">

<%# Alternate locale sitemaps for SEO %>
<% I18n.available_locales.each do |locale| %>
  <% next if locale == I18n.locale %>
  <link rel="alternate" hreflang="<%= locale %>" href="<%= sitemap_path(locale: locale) %>">
<% end %>
```

**Rationale**:
- **Sitemap index**: Primary reference for search engines
- **Current locale sitemap**: Language-specific sitemap
- **Alternate links**: SEO best practice for multi-language sites

---

## Testing Strategy

### Unit Tests
- ✅ Model spec: Validations, associations, class methods
- ✅ Factory spec: Valid factory, traits

### Integration Tests
- ✅ Job spec: Multi-locale generation, privacy filtering, index generation
- ✅ Request spec: Locale routes, index route, 404 behavior, redirects

### Manual Testing
1. Run `bin/dc-run bundle exec rake sitemap:refresh` - verify 5 files created
2. Check database: 5 Sitemap records (4 locales + 1 index)
3. Access `http://localhost:3000/en/sitemap.xml.gz` - redirects to S3/MinIO
4. Access `http://localhost:3000/sitemap_index.xml.gz` - redirects to index
5. Verify privacy: Create private community, regenerate, confirm not in sitemap

---

## Deployment Considerations

### Pre-Deployment
- [ ] Run migrations: `bin/dc-run-dummy rails db:migrate`
- [ ] Review environment variables: `APP_PROTOCOL`, `APP_HOST`
- [ ] Ensure Active Storage configured (S3/MinIO)

### Post-Deployment
- [ ] Run initial sitemap generation: `rake sitemap:refresh`
- [ ] Set up cron job for periodic regeneration (daily/weekly)
- [ ] Update robots.txt to reference `/sitemap_index.xml.gz`
- [ ] Verify all locale sitemaps accessible

### Monitoring
- [ ] Check logs for "Sitemap generated" success messages
- [ ] Monitor Active Storage uploads
- [ ] Verify tmp file cleanup

---

## Risks & Mitigations

### Risk: Migration Fails
**Mitigation**: Test migration in development first, backup production database

### Risk: Sitemap Generation Timeout
**Mitigation**: Background job with retry logic, batch processing for large datasets

### Risk: S3/MinIO Upload Failures
**Mitigation**: Error handling with logs, manual retry capability

### Risk: Privacy Filtering Incomplete
**Mitigation**: Comprehensive test coverage, code review, security audit

---

## Success Metrics

- [ ] All tests pass (factory, model, job, request specs)
- [ ] Security scan shows no privacy leaks in sitemaps
- [ ] Deployment completes without database errors
- [ ] All 4 locale sitemaps + index accessible via URLs
- [ ] Search engines index content from all locale sitemaps
- [ ] Documentation complete with process diagram

---

## Timeline

- **Phase 1 (Security & Database)**: 1-2 hours
- **Phase 2 (Multi-Locale Support)**: 2-3 hours
- **Phase 3 (Testing & Documentation)**: 2-3 hours
- **Total Estimated Time**: 5-8 hours

---

## Appendix: Complete Test Specs

### Model Spec (spec/models/better_together/sitemap_spec.rb)

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Sitemap do
  describe 'Factory' do
    it 'has a valid factory' do
      sitemap = build(:better_together_sitemap)
      expect(sitemap).to be_valid
    end
    
    describe 'traits' do
      it 'creates spanish sitemap' do
        sitemap = create(:better_together_sitemap, :spanish)
        expect(sitemap.locale).to eq('es')
      end
      
      it 'creates sitemap index' do
        sitemap = create(:better_together_sitemap, :index)
        expect(sitemap.locale).to eq('index')
      end
      
      it 'creates sitemap with file attachment' do
        sitemap = create(:better_together_sitemap, :with_file)
        expect(sitemap.file).to be_attached
      end
    end
  end
  
  describe 'ActiveRecord associations' do
    it { is_expected.to belong_to(:platform) }
    it { is_expected.to have_one_attached(:file) }
  end
  
  describe 'Validations' do
    subject(:sitemap) { build(:better_together_sitemap) }
    
    it { is_expected.to validate_presence_of(:locale) }
    
    it 'validates locale is in available locales' do
      sitemap.locale = 'invalid'
      expect(sitemap).not_to be_valid
      expect(sitemap.errors[:locale]).to be_present
    end
    
    it 'validates uniqueness of platform_id scoped to locale' do
      platform = create(:better_together_platform)
      create(:better_together_sitemap, platform: platform, locale: 'en')
      
      duplicate = build(:better_together_sitemap, platform: platform, locale: 'en')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:platform_id]).to be_present
    end
    
    it 'allows different locales for same platform' do
      platform = create(:better_together_platform)
      create(:better_together_sitemap, platform: platform, locale: 'en')
      
      spanish = build(:better_together_sitemap, platform: platform, locale: 'es')
      expect(spanish).to be_valid
    end
  end
  
  describe '.current' do
    let(:platform) { create(:better_together_platform) }
    
    it 'finds existing sitemap for platform and locale' do
      existing = create(:better_together_sitemap, platform: platform, locale: 'en')
      result = described_class.current(platform, :en)
      expect(result).to eq(existing)
    end
    
    it 'creates new sitemap if none exists' do
      expect {
        described_class.current(platform, :es)
      }.to change(described_class, :count).by(1)
    end
    
    it 'uses current locale by default' do
      I18n.with_locale(:fr) do
        sitemap = described_class.current(platform)
        expect(sitemap.locale).to eq('fr')
      end
    end
  end
  
  describe '.current_index' do
    let(:platform) { create(:better_together_platform) }
    
    it 'finds existing sitemap index' do
      existing = create(:better_together_sitemap, platform: platform, locale: 'index')
      result = described_class.current_index(platform)
      expect(result).to eq(existing)
    end
    
    it 'creates new sitemap index if none exists' do
      expect {
        described_class.current_index(platform)
      }.to change(described_class, :count).by(1)
    end
    
    it 'creates sitemap with locale "index"' do
      sitemap_index = described_class.current_index(platform)
      expect(sitemap_index.locale).to eq('index')
    end
  end
end
```

---

## References

- PR #1037: https://github.com/better-together-org/community-engine-rails/pull/1037
- Sitemap Generator Gem: https://github.com/kjvarga/sitemap_generator
- Google Multi-Regional Sitemaps: https://developers.google.com/search/docs/specialty/international/managing-multi-regional-sites
- Project Documentation Standards: `docs/implementation/templates/system_documentation_template.md`
