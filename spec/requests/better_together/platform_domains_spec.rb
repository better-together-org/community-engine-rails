# frozen_string_literal: true

require 'rails_helper'

# Specs for platform-admin domain management (subdomain aliases and custom domains).
# Nested under /host/platforms/:platform_id/platform_domains.
# All actions require manage_platform permission (enforced via route constraint + Pundit).
RSpec.describe 'BetterTogether::PlatformDomainsController', :as_platform_manager do
  let(:locale) { I18n.default_locale }
  let(:regular_user) { create(:better_together_user, :confirmed) }
  let(:platform_manager_user) do
    find_or_create_test_user('manager@example.test', 'SecureTest123!@#', :platform_steward)
  end
  let(:platform) do
    create(:better_together_platform,
           identifier: "platform-#{SecureRandom.hex(6)}",
           host_url: "http://platform-#{SecureRandom.hex(6)}.test")
  end

  # PlatformDomainPolicy is scoped to the specific target platform (a steward
  # of one platform cannot manage another's domains) — unlike the
  # :as_platform_manager auto-login, which only grants manager status on the
  # auto-created host platform. Explicitly grant it on this spec's own
  # platform, matching spec/requests/better_together/feature_access_grants_spec.rb.
  before do
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') ||
           BetterTogether::Role.find_by(identifier: 'platform_manager')

    platform.person_platform_memberships.find_or_create_by!(member: platform_manager_user.person, role:) do |membership|
      membership.status = 'active'
    end
  end

  def index_path
    platform_platform_domains_path(platform, locale:)
  end

  def new_path
    new_platform_platform_domain_path(platform, locale:)
  end

  def edit_path(domain)
    edit_platform_platform_domain_path(platform, domain, locale:)
  end

  def destroy_path(domain)
    platform_platform_domain_path(platform, domain, locale:)
  end

  # ---------------------------------------------------------------------------
  # GET index
  # ---------------------------------------------------------------------------
  describe 'GET /host/platforms/:platform_id/platform_domains' do
    it 'returns 200' do
      get index_path
      expect(response).to have_http_status(:ok)
    end

    it 'displays the platform\'s own domain hostname' do
      # Platform#sync_primary_platform_domain! already created a primary
      # domain from host_url — no need to create one explicitly.
      get index_path
      expect_html_content(platform.primary_platform_domain.hostname)
    end

    it 'does not show domains from other platforms' do
      other_platform = create(:better_together_platform,
                              identifier: "other-#{SecureRandom.hex(6)}",
                              host_url: "http://other-#{SecureRandom.hex(6)}.test")
      other_domain = other_platform.primary_platform_domain

      get index_path
      expect(response.body).not_to include(other_domain.hostname)
    end

    it 'redirects signed-in non-managers away from index' do
      sign_in regular_user

      get index_path

      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET new
  # ---------------------------------------------------------------------------
  describe 'GET /host/platforms/:platform_id/platform_domains/new' do
    it 'renders the new form' do
      get new_path
      expect(response).to have_http_status(:ok)
    end

    it 'includes the hostname field' do
      get new_path
      expect(response.body).to include('platform_domain[hostname]')
    end

    it 'redirects signed-in non-managers away from new' do
      sign_in regular_user

      get new_path

      expect(response).to have_http_status(:not_found)
    end
  end

  # ---------------------------------------------------------------------------
  # GET edit
  # ---------------------------------------------------------------------------
  describe 'GET /host/platforms/:platform_id/platform_domains/:id/edit' do
    let!(:domain) do
      create(:better_together_platform_domain, platform:, hostname: 'edit-me.example.test')
    end

    it 'renders the edit form' do
      get edit_path(domain)
      expect(response).to have_http_status(:ok)
    end

    it 'displays the domain hostname in the form' do
      get edit_path(domain)
      expect_html_content('edit-me.example.test')
    end
  end

  # ---------------------------------------------------------------------------
  # POST create
  # ---------------------------------------------------------------------------
  describe 'POST /host/platforms/:platform_id/platform_domains' do
    it 'creates a subdomain-shaped domain and redirects' do
      expect do
        post index_path, params: { platform_domain: { hostname: 'tenant-a.btsdev.test' } }
      end.to change(BetterTogether::PlatformDomain, :count).by(1)

      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response).to have_http_status(:ok)
    end

    it 'creates a custom-domain-shaped domain and redirects' do
      expect do
        post index_path, params: { platform_domain: { hostname: 'app.customclientdomain.test' } }
      end.to change(BetterTogether::PlatformDomain, :count).by(1)

      expect(response).to have_http_status(:see_other)
    end

    it 'rejects creation with a blank hostname' do
      expect do
        post index_path, params: { platform_domain: { hostname: '' } }
      end.not_to change(BetterTogether::PlatformDomain, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'rejects creation with a duplicate hostname' do
      create(:better_together_platform_domain, hostname: 'already-taken.example.test')

      expect do
        post index_path, params: { platform_domain: { hostname: 'already-taken.example.test' } }
      end.not_to change(BetterTogether::PlatformDomain, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # ---------------------------------------------------------------------------
  # PATCH update
  # ---------------------------------------------------------------------------
  describe 'PATCH /host/platforms/:platform_id/platform_domains/:id' do
    let!(:domain) do
      create(:better_together_platform_domain, platform:, hostname: 'original.example.test')
    end

    it 'updates the hostname and redirects' do
      patch platform_platform_domain_path(platform, domain, locale:),
            params: { platform_domain: { hostname: 'updated.example.test' } }

      expect(response).to have_http_status(:see_other)
      expect(domain.reload.hostname).to eq('updated.example.test')
    end

    it 'rejects update with a blank hostname' do
      patch platform_platform_domain_path(platform, domain, locale:),
            params: { platform_domain: { hostname: '' } }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  # ---------------------------------------------------------------------------
  # DELETE destroy
  # ---------------------------------------------------------------------------
  describe 'DELETE /host/platforms/:platform_id/platform_domains/:id' do
    let!(:domain) do
      create(:better_together_platform_domain, platform:, hostname: 'removable.example.test')
    end

    it 'destroys a non-primary domain and redirects' do
      expect do
        delete destroy_path(domain)
      end.to change(BetterTogether::PlatformDomain, :count).by(-1)

      expect(response).to have_http_status(:see_other)
    end

    it 'prevents deletion of the primary domain' do
      primary_domain = platform.primary_platform_domain

      expect do
        delete destroy_path(primary_domain)
      end.not_to change(BetterTogether::PlatformDomain, :count)

      expect(response).to have_http_status(:see_other)
      follow_redirect!
      expect(response.body).to include(
        I18n.t('better_together.platform_domains.cannot_destroy_primary')
      )
    end
  end

  # ---------------------------------------------------------------------------
  # Access control — unauthenticated user
  # ---------------------------------------------------------------------------
  describe 'access control' do
    context 'when not logged in' do
      before { logout }

      # These routes are behind an `authenticated :user` Devise constraint scoped
      # to platform managers. Unauthenticated requests do not match the constraint
      # and receive 404 (Not Found) rather than a sign-in redirect.
      it 'returns 404 for index (route constraint requires platform manager)' do
        get index_path
        expect(response).to have_http_status(:not_found)
      end

      it 'returns 404 for new (route constraint requires platform manager)' do
        get new_path
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
