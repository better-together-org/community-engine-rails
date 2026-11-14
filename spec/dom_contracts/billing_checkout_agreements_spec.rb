# frozen_string_literal: true

require 'rails_helper'

# The agreement step of checkout keeps stable ids that styling, tests and screenshots rely on,
# including the state of each box after the form comes back with an error.
RSpec.describe 'Billing checkout agreements DOM', type: :request do # rubocop:disable RSpec/DescribeClass
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:member) { find_or_create_test_user("agreements-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#') }
  let(:plan) do
    create(:better_together_billing_plan, :unlinked, processor: nil, accepted_payment_methods: %w[cash], billing_interval: 'one_time',
                                                     currency: 'USD', amount_cents: 2500)
  end
  let(:page) { Nokogiri::HTML(response.body) }
  let(:identifiers) { %w[one_time_purchase_agreement offline_payment_terms] }

  before do
    host_platform.billing_processor_settings.create!(processor: 'cash', enabled: true, acknowledge: true,
                                                     settings: { 'instructions' => 'At the hall' })
    purchase_agreements_for(host_platform)
    sign_in member
  end

  it 'gives each agreement a review block, a viewer link and a box' do
    get better_together.new_billing_checkout_path(locale:, plan_id: plan.id, payment_method: 'cash')

    expect(page.at_css('#billing-agreement-review')).to be_present
    identifiers.each do |identifier|
      expect(page.at_css("#billing-agreement-view-#{identifier}.agreement-modal-link")).to be_present, "missing viewer for #{identifier}"
      expect(page.at_css("#billing-agreement-accept-#{identifier}.agreement-checkbox")).to be_present, "missing box for #{identifier}"
    end
  end

  it 'marks a box ticked and unlocked after an error only when the buyer ticked it', :aggregate_failures do
    ticks = { 'one_time_purchase_agreement' => '1' }
    post better_together.billing_checkout_path(locale:), params: { plan_id: plan.id, payment_method: 'cash' }.merge(ticks)

    ticked = page.at_css('#billing-agreement-accept-one_time_purchase_agreement')
    other = page.at_css('#billing-agreement-accept-offline_payment_terms')
    expect([ticked['checked'], ticked['data-better-together-agreement-enabled'], ticked['aria-disabled']]).to eq(%w[checked true false])
    expect([other['checked'], other['data-better-together-agreement-enabled'], other['aria-disabled']]).to eq([nil, nil, 'true'])
  end
end
