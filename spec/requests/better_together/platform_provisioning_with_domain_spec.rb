# frozen_string_literal: true

require 'rails_helper'

# Converts the manually-validated flow from
# docs/production/multi_platform_deployment.md ("Validated Provisioning
# Walkthrough") into a permanent spec, so CI protects it going forward.
RSpec.describe 'Platform provisioning with domains', :skip_host_setup do
  # A host platform may already be seeded once per test-database worker
  # (see spec/support/automatic_test_configuration.rb's configure_host_platform,
  # used the same way by spec/requests/better_together/multi_platform_isolation_spec.rb)
  # — Platform's single_host_record validation means calling
  # TenantPlatformProvisioningService.call(host: true, ...) directly here would
  # collide with it. Reuse the existing host platform instead; this spec's own
  # coverage of TenantPlatformProvisioningService(host: true) already lives in
  # spec/services/better_together/tenant_platform_provisioning_service_spec.rb.
  let!(:host_platform) { configure_host_platform }

  let(:tenant_result) do
    BetterTogether::TenantPlatformProvisioningService.call(
      name: 'Tenant A', host_url: 'https://tenant-a.example.test', time_zone: 'UTC'
    )
  end

  let(:other_result) do
    BetterTogether::TenantPlatformProvisioningService.call(
      name: 'Tenant B', host_url: 'https://tenant-b.example.test', time_zone: 'UTC'
    )
  end

  let!(:tenant_platform) { tenant_result.platform }
  let!(:other_platform) { other_result.platform }

  # Attaches a fully custom domain to Tenant A, alongside the subdomain-style
  # primary domain auto-created by TenantPlatformProvisioningService.
  let!(:custom_domain) do
    BetterTogether::PlatformDomain.create!(
      platform: tenant_platform, hostname: 'app.customclientdomain.test',
      active: true, share_domain: false
    )
  end

  it 'provisions tenant platforms successfully, alongside the (reused) host platform' do
    expect(tenant_result).to be_success
    expect(other_result).to be_success
    expect(host_platform.host?).to be(true)
    expect(tenant_platform.host?).to be(false)
  end

  it 'does not mark the custom domain as primary — the subdomain from provisioning stays canonical' do
    expect(custom_domain.primary_flag?).to be(false)
  end

  describe 'hostname resolution (PlatformDomain.resolve, what PlatformContextMiddleware uses)' do
    it 'resolves the subdomain hostname to the tenant platform' do
      expect(BetterTogether::PlatformDomain.resolve('tenant-a.example.test').platform_id).to eq(tenant_platform.id)
    end

    it 'resolves the custom domain to the SAME tenant platform' do
      expect(BetterTogether::PlatformDomain.resolve('app.customclientdomain.test').platform_id)
        .to eq(tenant_platform.id)
    end

    it 'resolves an unrelated tenant hostname to its own platform, not Tenant A' do
      expect(BetterTogether::PlatformDomain.resolve('tenant-b.example.test').platform_id).to eq(other_platform.id)
    end
  end

  describe 'end-to-end request isolation across both of Tenant A\'s hostnames and an unrelated tenant' do
    let!(:page_on_tenant_a) do
      create(:better_together_page, platform: tenant_platform, privacy: 'public',
                                    published_at: 1.day.ago, slug: 'shared-slug')
    end

    let!(:page_on_tenant_b) do
      create(:better_together_page, platform: other_platform, privacy: 'public',
                                    published_at: 1.day.ago, slug: 'shared-slug')
    end

    it 'serves Tenant A\'s page when requested via its subdomain' do
      host! 'tenant-a.example.test'
      get better_together.render_page_path(path: 'shared-slug', locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
      expect_html_content(page_on_tenant_a.title)
      expect(response.body).not_to include(page_on_tenant_b.title)
    end

    it 'serves the SAME Tenant A page when requested via its custom domain' do
      host! 'app.customclientdomain.test'
      get better_together.render_page_path(path: 'shared-slug', locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
      expect_html_content(page_on_tenant_a.title)
      expect(response.body).not_to include(page_on_tenant_b.title)
    end

    it 'serves Tenant B\'s own page when requested via Tenant B\'s hostname, not Tenant A\'s' do
      host! 'tenant-b.example.test'
      get better_together.render_page_path(path: 'shared-slug', locale: I18n.default_locale)

      expect(response).to have_http_status(:ok)
      expect_html_content(page_on_tenant_b.title)
      expect(response.body).not_to include(page_on_tenant_a.title)
    end

    it 'isolates Page.for_platform scoping directly, matching the request-level assertions above' do
      expect(BetterTogether::Page.for_platform(tenant_platform).pluck(:id)).to include(page_on_tenant_a.id)
      expect(BetterTogether::Page.for_platform(tenant_platform).pluck(:id)).not_to include(page_on_tenant_b.id)
      expect(BetterTogether::Page.for_platform(other_platform).pluck(:id)).to include(page_on_tenant_b.id)
      expect(BetterTogether::Page.for_platform(other_platform).pluck(:id)).not_to include(page_on_tenant_a.id)
    end
  end
end
