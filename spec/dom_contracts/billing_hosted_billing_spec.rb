# frozen_string_literal: true

require 'rails_helper'

# The stable ids the hosted billing pages carry, which the docs screenshots and other specs rely on.
RSpec.describe 'Hosted billing DOM contract', :skip_host_setup, type: :request do # rubocop:disable RSpec/DescribeClass, RSpecRails/InferredSpecType
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

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

  it 'gives the steward page a section and a state marker per agreement, and a form on an active one' do
    agreements.fetch('hosted_platform_billing_agreement').update!(lifecycle_state: 'active')
    user = create(:better_together_user, :confirmed, password:)
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') || create(:better_together_role, identifier: 'platform_steward')
    hosted.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    host! 'hosted.example.test'
    sign_in user

    get better_together.billing_hosted_billing_path(locale: :en)

    expect(response.body).to include('billing-hosted-billing-page', 'billing-hosted-billing-modes', 'billing-hosted-mode-billing',
                                     'billing-hosted-mode-local', 'billing-hosted-mode-merchant', 'billing-hosted-accept-form-billing',
                                     'billing-agreement-accept-hosted_platform_billing_agreement', 'billing-hosted-accept-billing',
                                     'billing-hosted-draft-local', 'billing-hosted-next-steps')
  end

  it 'gives the host page a table with a row, an agreement cell, a status and a suspend control per platform' do
    hosted
    host! 'host.example.test'
    sign_in find_or_create_test_user("dom-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager)

    get better_together.billing_hosted_platforms_path(locale: :en)

    expect(response.body).to include('billing-hosted-platforms-page', 'billing-hosted-platforms-table', "hosted_billing_platform_#{hosted.id}",
                                     "hosted_billing_platform_#{hosted.id}", "hosted_status_platform_#{hosted.id}",
                                     "hosted_suspend_platform_#{hosted.id}", "hosted_suspend_reason_platform_#{hosted.id}")
  end
end
