# frozen_string_literal: true

require 'rails_helper'

# DOM contract for returning a store credit payment: the stable identifiers on a sale a steward is looking at.
RSpec.describe 'Billing credit refund DOM contract', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with offline payment fixtures'
  include_context 'with billing switched on'

  let(:locale) { I18n.default_locale }
  let(:order) { place_order(payment_method: 'store_credit') }
  let(:payment) { order.payments.sole }

  before do
    host_platform.billing_processor_settings.create!(processor: 'store_credit', enabled: true, acknowledge: true, purposes: %w[one_time])
    BetterTogether::Billing::Credit::Grant.call(platform: host_platform, holder: buyer, amount_cents: 6000, currency: 'USD',
                                                origin: 'steward_grant', actor: steward, idempotency_key: 'seed')
    sign_in steward_user
  end

  it 'exposes the return form on the sale, with an id per payment' do
    get "/#{locale}/billing/sales/#{order.id}"

    [ActionView::RecordIdentifier.dom_id(payment, :credit_refund), "billing-sale-credit-refund-form-#{payment.id}",
     "credit_refund_amount_#{payment.id}", "credit_refund_reason_#{payment.id}", "billing-sale-credit-refund-btn-#{payment.id}"].each do |id|
      expect(response.body).to include(%(id="#{id}")), "expected id=#{id.inspect} in the page"
    end
    expect(response.body).to include('billing-credit-refund')
  end
end
