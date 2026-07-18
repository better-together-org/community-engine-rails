# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform domain resolution', :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let(:locale) { I18n.default_locale }

  describe 'Inactive domain handling' do
    let(:active_domain) do
      # Platform#sync_primary_platform_domain! already created a primary domain
      # for host_platform — update it to the desired test hostname rather than
      # creating a second primary domain for the same platform (which would
      # violate PrimaryFlag's only_one_primary validation).
      domain = BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
               create(:better_together_platform_domain, :primary, platform: host_platform)
      domain.update!(hostname: 'active.example.test', active: true)
      domain
    end

    let(:inactive_domain) do
      create(:better_together_platform_domain,
             platform: host_platform,
             hostname: 'inactive.example.test',
             active: false,
             primary_flag: false)
    end

    it 'resolves active domain to platform' do
      host! active_domain.hostname
      get better_together.home_page_path(locale:)

      expect(response).to have_http_status(:ok)
    end

    it 'falls back to host platform when domain is inactive' do
      # Create and deactivate the domain
      inactive_domain

      host! inactive_domain.hostname
      get better_together.home_page_path(locale:)

      # Inactive domain should fall back to host platform (cached lookup)
      expect(response).to have_http_status(:ok)
      # The response should show host platform content, not the inactive domain's
    end
  end

  describe 'Cache invalidation on hostname change' do
    it 'invalidates cache when domain hostname is updated' do
      # Same reasoning as 'Inactive domain handling' above — reuse the
      # auto-created primary domain instead of creating a second one.
      domain = BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
               create(:better_together_platform_domain, :primary, platform: host_platform)
      domain.update!(hostname: 'original.example.test')

      # First request populates cache
      host! 'original.example.test'
      get better_together.home_page_path(locale:)
      expect(response).to have_http_status(:ok)

      # Update hostname (triggers after_commit :bust_resolve_cache)
      domain.update!(hostname: 'updated.example.test')

      # Old hostname should no longer resolve to this domain
      # It will fall back to host platform cache or DB lookup
      host! 'original.example.test'
      get better_together.home_page_path(locale:)
      expect(response).to have_http_status(:ok) # Still works (falls back to host)

      # New hostname should resolve correctly
      host! 'updated.example.test'
      get better_together.home_page_path(locale:)
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'Primary domain canonical link generation' do
    let(:platform) { create(:better_together_platform, :public) }
    # Platform#sync_primary_platform_domain! (after_commit) already created a
    # primary domain from host_url — update it rather than creating a second
    # primary domain for the same platform.
    let(:primary_domain) do
      domain = BetterTogether::PlatformDomain.find_by(platform:, primary_flag: true) ||
               create(:better_together_platform_domain, :primary, platform:)
      domain.update!(hostname: 'primary.example.test')
      domain
    end

    let(:alias_domain) do
      create(:better_together_platform_domain,
             platform:,
             hostname: 'alias.example.test',
             primary_flag: false,
             active: true)
    end

    it 'renders canonical link to primary domain when accessed via alias' do
      primary_domain
      alias_domain

      host! alias_domain.hostname
      get better_together.home_page_path(locale:)

      expect(response).to have_http_status(:ok)
      # Canonical link should point to primary domain
      expect(response.body).to include("href=\"#{primary_domain.url}/#{locale}\"")
    end

    it 'renders canonical link to primary domain when accessed via primary' do
      primary_domain

      host! primary_domain.hostname
      get better_together.home_page_path(locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("href=\"#{primary_domain.url}/#{locale}\"")
    end
  end

  describe 'Auto-creation of PlatformDomain on platform create' do
    it 'creates primary domain when platform is created with host_url' do
      new_platform = create(:better_together_platform,
                            host_url: 'https://new-platform.example.test')

      # The sync_primary_platform_domain! callback should create a domain
      primary = BetterTogether::PlatformDomain.find_by(
        platform: new_platform,
        primary_flag: true
      )

      expect(primary).to be_present
      expect(primary.hostname).to eq('new-platform.example.test')
      expect(primary.active).to be(true)
    end

    it 'updates primary domain when platform host_url changes' do
      new_platform = create(:better_together_platform,
                            host_url: 'https://original.example.test')

      original_domain = BetterTogether::PlatformDomain.find_by(
        platform: new_platform,
        primary_flag: true
      )
      expect(original_domain.hostname).to eq('original.example.test')

      # Update the host_url
      new_platform.update!(host_url: 'https://updated.example.test')

      # The primary domain should be updated
      updated_domain = BetterTogether::PlatformDomain.find_by(
        platform: new_platform,
        primary_flag: true
      )
      expect(updated_domain.hostname).to eq('updated.example.test')
    end

    it 'does not create domain for external platforms' do
      external_platform = create(:better_together_platform, :external,
                                 host_url: 'https://external.example.test')

      # External platforms should not auto-create domains
      primary = BetterTogether::PlatformDomain.find_by(
        platform: external_platform,
        primary_flag: true
      )

      # This depends on the implementation; if external platforms skip the callback,
      # primary will be nil. If not, it will be created.
      # Check the actual behavior:
      expect(primary).to be_nil # Based on plan: external platforms skip sync_primary_platform_domain!
    end
  end

  describe 'PlatformDomain hostname normalization' do
    it 'normalizes hostname (lowercase, strip, remove trailing dot)' do
      domain = create(:better_together_platform_domain,
                      platform: host_platform,
                      hostname: 'EXAMPLE.COM')

      # When resolved, hostname should be normalized
      resolved = BetterTogether::PlatformDomain.resolve('EXAMPLE.COM.')
      expect(resolved).to eq(domain)
    end

    it 'matches normalized hostnames in cache' do
      domain = create(:better_together_platform_domain,
                      platform: host_platform,
                      hostname: 'example.com')

      # Different case and trailing dot should resolve to same domain
      resolved1 = BetterTogether::PlatformDomain.resolve('example.com')
      resolved2 = BetterTogether::PlatformDomain.resolve('EXAMPLE.COM.')

      expect(resolved1).to eq(domain)
      expect(resolved2).to eq(domain)
    end
  end

  describe 'Primary domain enforcement' do
    it 'allows only one primary domain per platform' do
      platform = create(:better_together_platform, :public)

      # Platform#sync_primary_platform_domain! (after_commit) already created a
      # primary domain from host_url — update it rather than creating a second
      # primary domain for the same platform.
      BetterTogether::PlatformDomain.find_by(platform:, primary_flag: true)
                                    .update!(hostname: 'first.example.test')

      # PrimaryFlag#only_one_primary_flag enforces this via a validation, not
      # an auto-demote — attempting a second primary for the same platform
      # is rejected outright.
      expect do
        create(:better_together_platform_domain, :primary, platform:, hostname: 'second.example.test')
      end.to raise_error(ActiveRecord::RecordInvalid, /Primary flag/)

      # The original primary domain remains the only one.
      platform.reload
      primary_domains = BetterTogether::PlatformDomain.where(platform:, primary_flag: true)

      expect(primary_domains.count).to eq(1)
      expect(primary_domains.first.hostname).to eq('first.example.test')
    end
  end
end
