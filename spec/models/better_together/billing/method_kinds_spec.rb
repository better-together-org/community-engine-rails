# frozen_string_literal: true

require 'rails_helper'

# Store credit is a ledger inside Community Engine, not something a seller confirms by hand. Every place that used
# to ask "is this a method outside a vendor?" now asks the right question, and store credit is never treated as cash.
RSpec.describe 'Payment method kinds' do # rubocop:disable RSpec/DescribeClass
  include_context 'with store credit fixtures'

  let(:order) { place_order }

  it 'does not let an offline payment be opened for store credit, because there is no seller to confirm it' do
    payment = create(:better_together_billing_payment, order:, amount_cents: 4500, processor: 'store_credit')
    offline = BetterTogether::Billing::OfflinePayment.new(platform_id: host_platform.id, order:, payment:, processor: 'store_credit')

    expect(offline).not_to be_valid
    expect(offline.errors.details[:processor]).to include(a_hash_including(error: :not_an_offline_method))
  end

  it 'lets a purchase agreement be required for store credit, as for any method Community Engine settles itself' do
    requirement = host_platform.billing_agreement_requirements.new(agreement: create(:better_together_agreement), payment_method: 'store_credit')
    requirement.valid?

    expect(requirement.errors.details[:payment_method]).to be_empty
  end

  it 'lets a plan accept store credit, and lists it with the other methods that are not an online processor' do
    expect(build(:better_together_billing_plan, accepted_payment_methods: %w[store_credit])).to be_valid
    expect(BetterTogether::Billing::Plan.local_method?('store_credit')).to be(true)
  end

  it 'gives store credit a context only while a steward has it switched on, like any local method' do
    expect(BetterTogether::Billing::Configuration.context_for(host_platform, 'store_credit')).to be_present
    host_platform.billing_processor_settings.find_by!(processor: 'store_credit').update!(enabled: false)

    expect(BetterTogether::Billing::Configuration.context_for(host_platform, 'store_credit')).to be_nil
  end

  it 'does not treat a store credit payment as a processor payment' do
    payment = create(:better_together_billing_payment, order:, amount_cents: 4500, processor: 'store_credit')

    expect(payment).not_to be_remote
  end

  it 'keeps store credit out of the online processor choices on the plan form' do
    owner = host_platform
    helper = Object.new.extend(BetterTogether::BillingHelper)
    helper.define_singleton_method(:billing_owner) { owner }
    helper.define_singleton_method(:t) { |key, **| key.to_s.split('.').last }

    expect(helper.billing_processor_choices.map(&:last)).not_to include('store_credit')
    expect(helper.billing_offline_method_choices.map(&:last)).to include('store_credit')
  end

  it 'lists store credit among the payment methods a steward can configure' do
    expect(BetterTogether::Billing.processor_names).to include(:store_credit)
  end
end
