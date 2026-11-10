# frozen_string_literal: true

require 'rails_helper'

# The tax registration screens keep stable ids that styling, tests and screenshots rely on.
RSpec.describe 'Billing tax registration DOM', type: :request do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:steward) { find_or_create_test_user("tax-dom-#{SecureRandom.hex(4)}@example.test", 'SecureTest123!@#', :platform_manager) }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  before { sign_in steward }

  it 'gives the list its ids', :aggregate_failures do
    registration = create(:better_together_billing_tax_registration, platform: host_platform)
    get better_together.billing_tax_registrations_path(locale:)
    page = Nokogiri::HTML(response.body)
    row_id = ActionView::RecordIdentifier.dom_id(registration)

    expect(page.at_css('#billing-tax-registrations-page')).to be_present
    expect(page.at_css('#billing-tax-registrations-table')).to be_present
    expect(page.at_css("##{row_id}-edit-link")).to be_present
    expect(page.at_css('#billing-tax-registration-new-link')).to be_present
  end

  it 'shows the empty note when there are none' do
    get better_together.billing_tax_registrations_path(locale:)

    expect(Nokogiri::HTML(response.body).at_css('#billing-tax-registrations-empty')).to be_present
  end

  it 'gives the form its ids', :aggregate_failures do
    get better_together.new_billing_tax_registration_path(locale:)
    page = Nokogiri::HTML(response.body)

    %w[form place status prices number from to submit].each do |part|
      expect(page.at_css("#billing-tax-registration-#{part}")).to be_present, "missing #billing-tax-registration-#{part}"
    end
  end

  it 'picks the place with the geography selects for country and state only', :aggregate_failures do
    get better_together.new_billing_tax_registration_path(locale:)
    page = Nokogiri::HTML(response.body)

    expect(page.at_css('#billing_tax_registration_country_select')).to be_present
    expect(page.at_css('#billing_tax_registration_state_select')).to be_present
    expect(page.at_css('#billing_tax_registration_settlement_select')).to be_nil
    expect(page.at_css('#billing_tax_registration_country_select_id')['name']).to eq('billing_tax_registration[country_id]')
  end

  it 'is linked from the payment methods page' do
    get better_together.billing_processor_settings_path(locale:)

    expect(Nokogiri::HTML(response.body).at_css('#billing-tax-registrations-link')).to be_present
  end
end
