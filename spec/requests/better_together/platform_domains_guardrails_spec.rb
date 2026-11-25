# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform domain guardrails', :skip_host_setup do
  let(:locale) { I18n.default_locale }
  let(:setup) { managed_platform_setup }
  let(:managed_platform) { setup.managed_platform }
  let(:zone) { setup.operator_platform.primary_platform_domain.hostname }
  let(:domains_path) { better_together.platform_platform_domains_path(managed_platform, locale:) }

  before { host_on(managed_platform) }

  context 'as the managed platform steward' do
    before { sign_in_steward(setup.managed_steward) }

    it 'creates a requested subdomain inactive, even when active is submitted' do
      post domains_path, params: { platform_domain: { hostname: "club.#{zone}", active: '1', primary_flag: '1' } }

      domain = managed_platform.platform_domains.find_by!(hostname: "club.#{zone}")
      expect(domain).not_to be_active
      expect(domain).not_to be_primary
    end

    it 'rejects a hostname outside the allowed zones' do
      expect do
        post domains_path, params: { platform_domain: { hostname: 'club.elsewhere.test' } }
      end.not_to change(BetterTogether::PlatformDomain, :count)
    end

    it 'rejects a reserved name' do
      expect do
        post domains_path, params: { platform_domain: { hostname: "admin.#{zone}" } }
      end.not_to change(BetterTogether::PlatformDomain, :count)
    end

    it 'cannot activate a pending domain' do
      pending_domain = create(:better_together_platform_domain, platform: managed_platform,
                                                                hostname: "wait.#{zone}", active: false)

      patch better_together.platform_platform_domain_path(managed_platform, pending_domain, locale:),
            params: { platform_domain: { active: '1' } }

      expect(pending_domain.reload).not_to be_active
    end
  end

  context 'as the operator steward' do
    before do
      host_on(setup.operator_platform)
      sign_in_steward(setup.operator_steward)
    end

    it 'activates a pending domain the managed steward requested' do
      pending_domain = create(:better_together_platform_domain, platform: managed_platform,
                                                                hostname: "wait.#{zone}", active: false)

      patch better_together.platform_platform_domain_path(managed_platform, pending_domain, locale:),
            params: { platform_domain: { active: '1' } }

      expect(pending_domain.reload).to be_active
    end

    it 'may use a hostname outside the allowed zones' do
      post domains_path, params: { platform_domain: { hostname: 'club.elsewhere.test', active: '1' } }

      expect(managed_platform.platform_domains.find_by(hostname: 'club.elsewhere.test')).to be_active
    end
  end

  context 'when the operator association lacks the manage_settings scope' do
    let(:setup) { managed_platform_setup(scopes: %w[read]) }

    it 'does not make the operator steward an operator for domains' do
      host_on(setup.operator_platform)
      sign_in_steward(setup.operator_steward)

      get better_together.new_platform_platform_domain_path(managed_platform, locale:)

      expect(response).not_to have_http_status(:ok)
    end
  end
end
