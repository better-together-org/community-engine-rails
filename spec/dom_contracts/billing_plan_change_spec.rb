# frozen_string_literal: true

require 'rails_helper'

# DOM contract for changing plan: the stable identifiers on a subscription the payer is looking at.
RSpec.describe 'Billing plan change DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:term) { start_subscription }

  before do
    create(:better_together_billing_plan, processor: nil, processor_price_id: nil, processor_product_id: nil, billing_interval: 'month',
                                          amount_cents: 5000, currency: 'USD', accepted_payment_methods: %w[cash], listed: true)
    term
    sign_in buyer_user
  end

  it 'offers the choice of plan' do
    get "/#{locale}/billing/subscriptions/#{term.id}"

    %w[subscription-plan-change subscription-plan-change-form subscription-plan-change-select subscription-plan-change-btn].each do |id|
      expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page"
    end
  end

  it 'shows the waiting choice and a way to take it back' do
    BetterTogether::Billing::Subscriptions::ChangePlan.request(term: term, plan: BetterTogether::Billing::Plan.find_by!(amount_cents: 5000))

    get "/#{locale}/billing/subscriptions/#{term.id}"

    expect(response.body).to include('id="subscription-plan-change-pending"', 'id="subscription-plan-change-withdraw-btn"')
  end
end
