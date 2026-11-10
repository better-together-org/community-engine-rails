# frozen_string_literal: true

require 'rails_helper'

# The billing address step of checkout keeps stable ids that styling, tests and screenshots rely on.
RSpec.describe 'Billing checkout address DOM', type: :request do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("addr-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     currency: 'USD', amount_cents: 2500)
  end
  let(:page) { Nokogiri::HTML(response.body) }

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    BetterTogether::Billing::PurchaseAgreementSeeds.call(host_platform).each_value { |a| a.update!(lifecycle_state: 'active') }
    sign_in member
  end

  it 'shows the address section and its fields once a way to pay is chosen', :aggregate_failures do
    create_billing_address_for(member.person)
    get better_together.new_billing_checkout_path(locale:, plan_id: plan.id, payment_method: 'cash')

    %w[billing-checkout-address billing-checkout-address-select billing-checkout-new-address billing-checkout-address-line1
       billing-checkout-address-postal-code billing-checkout-make-default].each do |id|
      expect(page.at_css("##{id}")).to be_present, "missing ##{id}"
    end
  end

  it 'lists the buyer\'s own addresses, and only theirs' do
    mine = create_billing_address_for(member.person)
    theirs = create_billing_address_for(create(:better_together_person), settlement_name: 'Elsewhere')
    get better_together.new_billing_checkout_path(locale:, plan_id: plan.id, payment_method: 'cash')

    values = page.css('#billing-checkout-address-select option').pluck('value')
    expect(values).to include(mine.id, 'new')
    expect(values).not_to include(theirs.id)
  end

  it 'preselects the default billing address' do
    create_billing_address_for(member.person)
    chosen = create_billing_address_for(member.person, settlement_name: 'Gander')
    BetterTogether::Billing::DefaultAddress.set!(platform: host_platform, person: member.person, address: chosen, kind: 'billing')
    get better_together.new_billing_checkout_path(locale:, plan_id: plan.id, payment_method: 'cash')

    expect(page.at_css('#billing-checkout-address-select option[selected]')['value']).to eq(chosen.id)
  end
end
