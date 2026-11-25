# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Platform domain guardrails', :skip_host_setup do
  let(:locale) { I18n.default_locale }
  let(:hosted_platform) { create(:better_together_platform, type: 'BetterTogether::HostedPlatform') }
  let(:zone) { BetterTogether::Platform.find_by(host: true).primary_platform_domain.hostname }
  let(:steward_role) do
    BetterTogether::AccessControlBuilder.seed_data
    BetterTogether::Role.find_by!(identifier: 'platform_steward')
  end

  def steward_of(platform)
    user = create(:better_together_user, :confirmed)
    BetterTogether::PersonPlatformMembership.create!(
      joinable: platform, member: user.person, role: steward_role, status: 'active'
    )
    user
  end

  before { configure_host_platform }

  context 'as a hosted platform steward' do
    before do
      host! hosted_platform.platform_domains.find_by(primary: true).hostname
      login_as(steward_of(hosted_platform), scope: :user)
    end

    it 'creates a requested subdomain inactive, even when active is submitted' do
      post better_together.platform_platform_domains_path(hosted_platform, locale:),
           params: { platform_domain: { hostname: "club.#{zone}", active: '1', primary_flag: '1' } }

      domain = hosted_platform.platform_domains.find_by!(hostname: "club.#{zone}")
      expect(domain).not_to be_active
      expect(domain).not_to be_primary
    end

    it 'rejects a hostname outside the allowed zones' do
      expect do
        post better_together.platform_platform_domains_path(hosted_platform, locale:),
             params: { platform_domain: { hostname: 'club.elsewhere.test' } }
      end.not_to change(BetterTogether::PlatformDomain, :count)
    end

    it 'rejects a reserved name' do
      expect do
        post better_together.platform_platform_domains_path(hosted_platform, locale:),
             params: { platform_domain: { hostname: "admin.#{zone}" } }
      end.not_to change(BetterTogether::PlatformDomain, :count)
    end

    it 'cannot activate a pending domain' do
      pending_domain = create(:better_together_platform_domain, platform: hosted_platform,
                                                                hostname: "wait.#{zone}", active: false)

      patch better_together.platform_platform_domain_path(hosted_platform, pending_domain, locale:),
            params: { platform_domain: { active: '1' } }

      expect(pending_domain.reload).not_to be_active
    end
  end
end
