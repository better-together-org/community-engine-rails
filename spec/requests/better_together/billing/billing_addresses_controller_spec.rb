# frozen_string_literal: true

require 'rails_helper'

# "My billing addresses": where tax is worked out from.
RSpec.describe BetterTogether::Billing::BillingAddressesController do
  include BetterTogether::BillingAddressHelpers

  include_context 'with orders fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:member) { find_or_create_test_user("address-member-#{SecureRandom.hex(4)}@example.test", password) }
  let(:stranger) { find_or_create_test_user("address-stranger-#{SecureRandom.hex(4)}@example.test", password) }
  let(:buyer) { member.person }
  let!(:first_address) { create_billing_address_for(buyer) }
  let!(:second_address) { create_billing_address_for(buyer) }

  def list_path = better_together.billing_billing_addresses_path(locale:)

  def default_for(person)
    person.billing_default_addresses.billing.find_by(platform: host_platform)&.address_id
  end

  it 'sends a visitor to sign in' do
    get list_path

    expect(response).to have_http_status(:found)
  end

  context 'when signed in' do
    before { sign_in member }

    it 'lists the person\'s own addresses and the form for a new one' do
      get list_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('billing-addresses-page', 'billing-addresses-list', 'billing-addresses-form',
                                       ActionView::RecordIdentifier.dom_id(first_address, :billing))
    end

    it 'never lists another person\'s address' do
      stranger_address = create_billing_address_for(stranger.person)

      get list_path

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(stranger_address, :billing))
    end

    it 'adds an address and can make it the default' do
      params = { line1: '7 Pine', postal_code: 'A1B 2C3', country_id: first_address.country_id, state_id: first_address.state_id }

      expect { post list_path, params: { billing_address: params, make_default_billing: '1' } }.to change { buyer.addresses.count }.by(1)

      expect(response).to redirect_to(list_path)
      expect(default_for(buyer)).to eq(buyer.addresses.find_by(line1: '7 Pine').id)
    end

    it 'refuses an address with no chosen country or state' do
      attempt = -> { post list_path, params: { billing_address: { line1: '7 Pine', postal_code: 'A1B 2C3' } } }
      expect(&attempt).not_to(change { buyer.addresses.count })

      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'makes another address the default' do
      patch better_together.default_billing_billing_address_path(second_address, locale:)

      expect(default_for(buyer)).to eq(second_address.id)
    end

    it 'does not make a stranger address the default' do
      stranger_address = create_billing_address_for(stranger.person)

      patch better_together.default_billing_billing_address_path(stranger_address, locale:)

      expect(default_for(buyer)).to be_nil
    end
  end

  it 'is a 404 while billing is not switched on' do
    sign_in member
    allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

    get list_path

    expect(response).to have_http_status(:not_found)
  end
end
