# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::TaxRegistrationsController do
  include_context 'with clean billing processors'
  include_context 'with builtin billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:steward) { find_or_create_test_user("tax-steward-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:member) { find_or_create_test_user("tax-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:host_platform) { BetterTogether::Platform.find_by(host: true) }

  def index_path = better_together.billing_tax_registrations_path(locale:)

  def valid_params(**overrides)
    { billing_tax_registration: { country_iso: 'ca', region_code: 'nl', status: 'registered', prices_include_tax: '',
                                  registration_number: '123456789 RT0001' }.merge(overrides) }
  end

  describe 'who may reach it' do
    it 'sends a visitor to sign in' do
      get index_path

      expect(response).to have_http_status(:found)
    end

    it 'turns a signed-in non-steward away' do
      sign_in member

      get index_path

      expect(response).to have_http_status(:found)
      expect(response.body).not_to include('billing-tax-registrations-page')
    end
  end

  context 'when signed in as a steward' do
    before { sign_in steward }

    it 'lists the platform registrations only', :aggregate_failures do
      ours = create(:better_together_billing_tax_registration, platform: host_platform, country_iso: 'CA', region_code: 'NL')
      theirs = create(:better_together_billing_tax_registration, platform: create(:better_together_platform), country_iso: 'US')

      get index_path

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(ours))
      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(theirs))
    end

    it 'adds a registration, upcasing codes and never storing the number in clear', :aggregate_failures do
      expect { post index_path, params: valid_params }.to change(BetterTogether::Billing::TaxRegistration, :count).by(1)

      registration = BetterTogether::Billing::TaxRegistration.order(:created_at).last
      expect([registration.country_iso, registration.region_code, registration.platform_id, registration.seller_id])
        .to eq(['CA', 'NL', host_platform.id, nil])
      expect(registration.prices_include_tax).to be_nil
      expect(registration.registration_number).to eq('123456789 RT0001')
      expect(registration.read_attribute_before_type_cast(:registration_number)).not_to include('123456789')
    end

    it 'refuses a bad country code with a message' do
      post index_path, params: valid_params(country_iso: 'Canada')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('billing-tax-registration-errors')
    end

    it 'keeps the stored number when the field is left blank, and never echoes it', :aggregate_failures do
      registration = create(:better_together_billing_tax_registration, platform: host_platform, registration_number: 'SECRET-111')

      get better_together.edit_billing_tax_registration_path(registration, locale:)
      expect(response.body).not_to include('SECRET-111')

      patch better_together.billing_tax_registration_path(registration, locale:),
            params: valid_params(country_iso: 'CA', registration_number: '', prices_include_tax: 'true')

      expect(registration.reload.registration_number).to eq('SECRET-111')
      expect(registration.prices_include_tax).to be(true)
    end

    it 'cannot edit another platform\'s registration' do
      other = create(:better_together_billing_tax_registration, platform: create(:better_together_platform))

      get better_together.edit_billing_tax_registration_path(other, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end
end
