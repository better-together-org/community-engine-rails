# frozen_string_literal: true

require 'rails_helper'

# A payer changes how later renewals of a subscription are paid.
RSpec.describe 'Billing subscription payment method change', type: :request do # rubocop:disable RSpec/DescribeClass, RSpecRails/InferredSpecType
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:term) { start_subscription }
  let(:service) { BetterTogether::Billing::Subscriptions::ChangeMethod }

  def change_path = better_together.change_method_billing_subscription_path(term, locale:)

  before do
    term
    sign_in buyer_user
  end

  it 'offers the other ways this plan can be renewed' do
    get better_together.billing_subscription_path(term, locale:)

    expect(response.body).to include('subscription-method-change-select', 'store_credit')
    expect(service.options(term).map(&:name)).to eq(%w[store_credit])
  end

  it 'moves later renewals to the chosen method' do
    patch change_path, params: { payment_method: 'store_credit' }

    expect(term.reload.payment_method).to eq('store_credit')
    expect(response).to redirect_to(better_together.billing_subscription_path(term, locale:))
  end

  it 'refuses the method it already has' do
    expect { service.call(term:, method: 'cash') }.to raise_error(service::Refused) { |e| expect(e.code).to eq(:unchanged) }
  end

  it 'refuses a method the plan does not offer' do
    patch change_path, params: { payment_method: 'etransfer' }

    expect(term.reload.payment_method).to eq('cash')
  end

  it 'turns another person away' do
    sign_in other_buyer_user

    patch change_path, params: { payment_method: 'store_credit' }

    expect(term.reload.payment_method).to eq('cash')
  end
end
