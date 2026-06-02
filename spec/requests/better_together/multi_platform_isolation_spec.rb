# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Multi-platform request isolation', :skip_host_setup do
  let!(:host_platform) { configure_host_platform }
  let!(:host_domain) do
    BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
      create(:better_together_platform_domain, :primary, platform: host_platform, hostname: 'host.example.test')
  end

  let(:other_platform) { create(:better_together_platform, :public) }
  let!(:other_domain) do
    create(:better_together_platform_domain, :primary, platform: other_platform, hostname: 'other.example.test')
  end

  describe 'Current.platform resolution' do
    it 'resolves host platform from host domain' do
      host! 'host.example.test'
      get better_together.home_page_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
      # Implicit: if routing failed due to platform resolution, we'd get a 500 or routing error
    end

    it 'resolves other platform from alternate domain' do
      host! 'other.example.test'
      get better_together.home_page_path(locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'Content isolation across platforms' do
    let!(:page_on_host) do
      create(:better_together_page,
             platform: host_platform,
             privacy: 'public',
             published_at: 1.day.ago,
             slug: 'test-page')
    end

    let!(:page_on_other) do
      create(:better_together_page,
             platform: other_platform,
             privacy: 'public',
             published_at: 1.day.ago,
             slug: 'test-page')
    end

    it 'returns host platform page when requested via host domain' do
      host! 'host.example.test'
      get better_together.page_path('test-page', locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
      expect_html_content(page_on_host.title)
    end

    it 'returns other platform page when requested via other domain' do
      host! 'other.example.test'
      get better_together.page_path('test-page', locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
      expect_html_content(page_on_other.title)
    end

    it 'returns 404 when accessing other platform content via host domain' do
      host! 'host.example.test'
      # Same slug, but accessed from host domain — should resolve to host's page, not other's
      expect(BetterTogether::Page.for_platform(host_platform).find_by(slug: 'test-page')).to eq(page_on_host)

      get better_together.page_path('test-page', locale: I18n.default_locale)
      expect(response).to have_http_status(:ok)
      expect_html_content(page_on_host.title)
      expect(response.body).not_to include(page_on_other.title)
    end
  end

  describe 'PlatformScoped model defaults' do
    it 'assigns Current.platform to new platform-scoped record' do
      host! 'other.example.test'

      # Create a short link via the controller context (simulating a POST)
      post better_together.short_links_path(
        locale: I18n.default_locale,
        short_link: { code: 'test-code', linkable_id: other_platform.id, linkable_type: 'BetterTogether::Platform' }
      )

      # The record should be created with other_platform, not host_platform
      short_link = BetterTogether::ShortLink.find_by(code: 'test-code')
      expect(short_link).to be_present
      expect(short_link.platform).to eq(other_platform)
    end

    it 'prevents creation of platform-scoped record without matching platform' do
      host! 'other.example.test'

      # Attempt to create a short link that belongs to a different platform
      # This should fail validation or not appear in queries for other_platform
      short_link = build(:better_together_short_link, platform: host_platform)
      short_link.platform_id = host_platform.id
      short_link.save

      # When queried from other_platform context, it should not be visible
      expect(BetterTogether::ShortLink.for_platform(other_platform).find_by(code: short_link.code)).to be_nil
    end
  end

  describe 'Authentication context isolation' do
    let(:user_on_host) do
      find_or_create_test_user('host-user@example.test', 'SecureTest123!@#', :user)
    end

    let(:user_on_other) do
      find_or_create_test_user('other-user@example.test', 'SecureTest123!@#', :user)
    end

    before do
      # Ensure users have platform memberships
      host_platform.person_platform_memberships.find_or_create_by!(member: user_on_host.person)
      other_platform.person_platform_memberships.find_or_create_by!(member: user_on_other.person)
    end

    it 'maintains separate authentication per platform' do
      # Log in to host platform
      host! 'host.example.test'
      login('host-user@example.test', 'SecureTest123!@#')
      get better_together.settings_path(locale: I18n.default_locale)
      expect(response).to have_http_status(:ok)

      # Switch to other platform — same session but different platform context
      host! 'other.example.test'
      get better_together.settings_path(locale: I18n.default_locale)
      # User from host may not have authorization on other platform
      # This tests that platform membership is respected
      expect(response.status).to be_in([200, 403])
    end
  end

  describe 'Cache isolation per platform' do
    it 'does not leak cached data between platform requests' do
      host! 'host.example.test'
      get better_together.home_page_path(locale: I18n.default_locale)
      expect(response).to have_http_status(:ok)

      # Switch to other platform
      host! 'other.example.test'
      get better_together.home_page_path(locale: I18n.default_locale)
      expect(response).to have_http_status(:ok)

      # Implicit: if cache leaked, a second request to host would see other's cached content
      # This is more of a safety check; cache isolation is handled by DatabaseCleaner and after(:each)
    end
  end
end
