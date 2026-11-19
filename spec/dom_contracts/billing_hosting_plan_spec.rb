# frozen_string_literal: true

require 'rails_helper'

# The ids the hosting plan page promises, so screenshots and specs can point at them.
RSpec.describe 'Hosting plan page DOM contract', :skip_host_setup, type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:hosted) { create(:better_together_platform, :public) }
  let(:password) { 'SecureTest123!@#' }

  before do
    domain = BetterTogether::PlatformDomain.find_by(platform: hosted, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: hosted)
    domain.update!(hostname: 'hosted.example.test')
    host! 'hosted.example.test'
    user = create(:better_together_user, :confirmed, email: "steward-#{SecureRandom.hex(4)}@example.test", password:)
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') || create(:better_together_role, identifier: 'platform_steward')
    hosted.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    sign_in user
    quota_grant(amount: 5_000)
  end

  # A subscription the host sells, held for `owner` (the hosted platform unless said otherwise), with its access given.
  def hosted_term(owner: hosted)
    term = start_subscription(payer: create(:better_together_person))
    attrs = { beneficiary_type: owner.class.name, beneficiary_id: owner.id }
    term.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
    BetterTogether::Billing::Entitlement.where(pay_subscription_id: term.pay_subscription_id).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
    term
  end

  it 'carries a stable id on the plan, its details, renewal, usage and the billing link' do
    term = hosted_term
    entitlement = entitlement_for(term)

    get better_together.billing_hosting_plan_path(locale: :en)
    doc = Nokogiri::HTML(response.body)
    dom = ActionView::RecordIdentifier

    expect([dom.dom_id(entitlement, :hosting), dom.dom_id(term, :hosting_details), dom.dom_id(entitlement, :hosting_usage),
            'billing-hosting-plan-page', 'billing-hosting-plan-manage', 'billing-hosting-plan-billing-link'].map { |id| doc.at_css("##{id}") })
      .to all(be_present)
  end
end
