# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing request log filtering' do # rubocop:disable RSpec/DescribeClass
  let(:filter) { ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters) }
  let(:checkout_params) do
    { 'plan_id' => 'plan-1', 'payment_method' => 'cash', 'make_default_billing' => '1',
      'billing_address' => { 'line1' => '1 Water St', 'line2' => 'Unit 2', 'postal_code' => 'A1A 1A1',
                             'city_name' => 'Corner Brook', 'state_province_name' => 'NL',
                             'country_name' => 'Canada' } }
  end
  let(:walk_up_params) do
    { 'plan_id' => 'plan-1', 'buyer_name' => 'Pat Buyer', 'buyer_email' => 'pat@example.test',
      'billing_address' => { 'line1' => '1 Water St', 'country_name' => 'Canada' } }
  end

  it 'filters every address field, flat or nested' do
    flat = %w[line1 line2 city_name state_province_name postal_code country_name].index_with { |_| 'x' }
    expect(filter.filter(flat).values.uniq).to eq(['[FILTERED]'])
    expect(filter.filter(checkout_params)['billing_address']).to eq('[FILTERED]')
  end

  it 'filters buyer details in walk-up params and keeps the rest readable' do
    filtered = filter.filter(walk_up_params)

    expect(filtered.slice('buyer_name', 'buyer_email', 'billing_address').values.uniq).to eq(['[FILTERED]'])
    expect(filtered['plan_id']).to eq('plan-1')
  end

  it 'filters offline payee settings and payment references' do
    filtered = filter.filter('billing_processor_setting' => { 'enabled' => '1', 'settings' => { 'email' => 'p@x.test' } },
                             'reference' => 'ETR-123')

    expect(filtered['billing_processor_setting']['settings']).to eq('[FILTERED]')
    expect(filtered['billing_processor_setting']['enabled']).to eq('1')
    expect(filtered['reference']).to eq('[FILTERED]')
  end
end
