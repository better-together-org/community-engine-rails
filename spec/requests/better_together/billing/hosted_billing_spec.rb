# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Hosted billing enablement', :skip_host_setup do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let!(:host_platform) { configure_host_platform }
  let(:hosted) { create(:better_together_platform, :public) }
  let!(:hosted_domain) do
    domain = BetterTogether::PlatformDomain.find_by(platform: hosted, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: hosted)
    domain.update!(hostname: 'hosted.example.test')
    domain
  end
  let!(:host_domain) do
    BetterTogether::PlatformDomain.find_by(platform: host_platform, primary_flag: true) ||
      create(:better_together_platform_domain, :primary, platform: host_platform, hostname: 'host.example.test')
  end
  let!(:agreements) { BetterTogether::Billing::HostedAgreementSeeds.call(host_platform) }
  let(:host_steward) { find_or_create_test_user("host-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:hosted_steward) do
    user = create(:better_together_user, :confirmed, email: "hosted-steward-#{SecureRandom.hex(4)}@example.test", password:)
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') || create(:better_together_role, identifier: 'platform_steward')
    hosted.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    user
  end

  def activate!(identifier) = agreements.fetch(identifier).update!(lifecycle_state: 'active')
  def hosted_page = better_together.billing_hosted_billing_path(locale:)

  describe 'the hosted platform steward page' do
    before { host! 'hosted.example.test' }

    it 'asks a visitor to sign in' do
      get hosted_page

      expect(response).to have_http_status(:found)
    end

    it 'shows the three agreements, drafts as not yet available' do
      sign_in hosted_steward

      get hosted_page

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-hosted-billing-page', 'billing-hosted-mode-billing', 'billing-hosted-mode-local',
                                       'billing-hosted-mode-merchant', 'billing-hosted-draft-billing', 'billing-hosted-merchant-unavailable')
    end

    it 'records acceptance for the platform, then unlocks the next step' do
      activate!('hosted_platform_billing_agreement')
      sign_in hosted_steward

      post hosted_page, params: { mode: 'billing', hosted_platform_billing_agreement: '1' }

      expect(response).to redirect_to(hosted_page)
      expect(BetterTogether::Billing::HostedBilling.accepted?(hosted, :billing)).to be true
      expect(BetterTogether::Billing::HostedBilling.permits?(hosted, :local)).to be false
    end

    it 'refuses without the box ticked' do
      activate!('hosted_platform_billing_agreement')
      sign_in hosted_steward

      post hosted_page, params: { mode: 'billing' }

      expect(BetterTogether::Billing::HostedBilling.accepted?(hosted, :billing)).to be false
    end

    it 'refuses the local agreement before the base one' do
      activate!('hosted_local_billing_agreement')
      sign_in hosted_steward

      post hosted_page, params: { mode: 'local', hosted_local_billing_agreement: '1' }

      expect(BetterTogether::Billing::HostedBilling.accepted?(hosted, :local)).to be false
    end

    it 'rejects an unknown mode' do
      sign_in hosted_steward

      post hosted_page, params: { mode: 'everything' }

      expect(response).to have_http_status(:not_found)
    end

    it 'turns a signed-in non-steward away' do
      sign_in create(:better_together_user, :confirmed, password:)

      get hosted_page

      expect(response.body).not_to include('billing-hosted-billing-page')
    end
  end

  describe 'on the host platform' do
    before { host! 'host.example.test' }

    it 'has no hosted steward page' do
      sign_in host_steward

      get hosted_page

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'the host status page' do
    let(:status_path) { better_together.billing_hosted_platforms_path(locale:) }

    before { host! 'host.example.test' }

    it 'lists hosted platforms with their agreement state' do
      hosted
      sign_in host_steward

      get status_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-hosted-platforms-table', "hosted_billing_platform_#{hosted.id}")
    end

    it 'suspends and resumes a platform, recording who and why' do
      sign_in host_steward

      patch better_together.suspend_billing_hosted_platform_path(hosted, locale:), params: { reason: 'Unpaid' }

      expect(BetterTogether::Billing::HostedBilling.suspended?(hosted.reload)).to be true

      patch better_together.resume_billing_hosted_platform_path(hosted, locale:)

      expect(BetterTogether::Billing::HostedBilling.suspended?(hosted.reload)).to be false
    end

    it 'needs a reason to suspend' do
      sign_in host_steward

      patch better_together.suspend_billing_hosted_platform_path(hosted, locale:), params: { reason: ' ' }

      expect(BetterTogether::Billing::HostedBilling.suspended?(hosted.reload)).to be false
    end

    it 'is closed to a hosted platform steward' do
      host! 'hosted.example.test'
      sign_in hosted_steward

      get status_path

      expect(response).to have_http_status(:not_found)
    end
  end
end
