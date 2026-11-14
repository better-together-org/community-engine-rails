# frozen_string_literal: true

require 'rails_helper'

# "Plan and usage": what a hosted platform's steward sees of the plan the platform is on with the host.
RSpec.describe 'Hosting plan page', :skip_host_setup do # rubocop:disable RSpec/DescribeClass, RSpecRails/InferredSpecType
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:hosted) { create(:better_together_platform, :public) }
  let!(:hosted_domain) do
    domain = BetterTogether::PlatformDomain.find_by(platform: hosted, primary_flag: true) ||
             create(:better_together_platform_domain, :primary, platform: hosted)
    domain.update!(hostname: 'hosted.example.test')
    domain
  end
  let(:hosted_steward) do
    user = create(:better_together_user, :confirmed, email: "hosted-steward-#{SecureRandom.hex(4)}@example.test", password:)
    role = BetterTogether::Role.find_by(identifier: 'platform_steward') || create(:better_together_role, identifier: 'platform_steward')
    hosted.person_platform_memberships.create!(member: user.person, role:, status: 'active')
    user
  end

  # A subscription the host sells, held for `owner` (the hosted platform unless said otherwise), with its access given.
  def hosted_term(owner: hosted)
    term = start_subscription(payer: create(:better_together_person))
    attrs = { beneficiary_type: owner.class.name, beneficiary_id: owner.id }
    term.update_columns(attrs) # rubocop:disable Rails/SkipsModelValidations
    BetterTogether::Billing::Entitlement.where(pay_subscription_id: term.pay_subscription_id).update_all(attrs) # rubocop:disable Rails/SkipsModelValidations
    term
  end

  def page_path = better_together.billing_hosting_plan_path(locale:)

  before { host! 'hosted.example.test' }

  it 'asks a visitor to sign in' do
    get page_path

    expect(response).to have_http_status(:found)
  end

  it 'turns a signed-in non-steward away' do
    sign_in create(:better_together_user, :confirmed, password:)

    get page_path

    expect(response.body).not_to include('billing-hosting-plan-page')
  end

  context 'when signed in as the hosted platform steward' do
    before do
      quota_grant(amount: 5_000)
      sign_in hosted_steward
    end

    it 'says there is no plan yet, and points to the plans' do
      get page_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-hosting-plan-page', 'billing-hosting-plan-none', 'billing-hosting-plan-see-plans')
    end

    it 'shows the plan held for the platform, when it renews and how much is used' do
      term = hosted_term
      entitlement = entitlement_for(term)

      get page_path

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(entitlement, :hosting),
                                       ActionView::RecordIdentifier.dom_id(term, :hosting_details),
                                       ActionView::RecordIdentifier.dom_id(entitlement, :hosting_usage), 'progressbar')
      expect_html_content(sub_plan.name)
    end

    it 'never shows a plan held for someone else' do
      term = hosted_term(owner: create(:better_together_person))

      get page_path

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(entitlement_for(term), :hosting))
    end
  end
end
