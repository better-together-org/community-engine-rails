# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::PayExtensions::EncryptedBillingData do
  let(:platform) { create(:better_together_platform) }
  let(:owner) { create(:better_together_person) }
  let(:customer) do
    Pay::Customer.create!(owner:, platform:, processor: 'stripe', processor_id: 'cus_1',
                          data: { 'invoice_credit_balance' => { 'usd' => 1234 }, 'currency' => 'usd' },
                          object: { 'email' => 'private.person@example.test' })
  end

  describe Pay::Customer do
    it_behaves_like 'encrypts sensitive billing fields' do
      let(:saved_record) { customer }
      let(:encrypted_fields) do
        { data: { 'invoice_credit_balance' => { 'usd' => 1234 }, 'currency' => 'usd' },
          object: { 'email' => 'private.person@example.test' } }
      end
    end

    it 'keeps Pay store_accessor readers and writers working on the encrypted column' do
      expect(customer.reload.currency).to eq('usd')

      customer.currency = 'cad'
      customer.save!

      expect(customer.reload.currency).to eq('cad')
      expect(customer.encrypted_attribute?(:data)).to be(true)
    end

    it 'detects an in-place change to the hash' do
      customer.data['currency'] = 'eur'
      customer.save!

      expect(fresh(customer).data['currency']).to eq('eur')
    end
  end

  describe Pay::Subscription do
    it 'encrypts data, object and metadata' do
      subscription = described_class.create!(customer:, name: 'default', processor_id: 'sub_1', processor_plan: 'price_1',
                                             status: 'active', metadata: { 'note' => 'secret-note' },
                                             data: { 'k' => 'v' }, object: { 'o' => 'v' })

      %i[data object metadata].each { |name| expect(subscription.encrypted_attribute?(name)).to be(true) }
      expect(subscription.ciphertext_for(:metadata)).not_to include('secret-note')
    end
  end

  describe Pay::Charge do
    it 'encrypts data, object and metadata' do
      charge = described_class.create!(customer:, processor_id: 'ch_1', amount: 100, metadata: { 'm' => 'secret-note' },
                                       data: { 'last4' => '4242' }, object: { 'o' => 'v' })

      %i[data object metadata].each { |name| expect(charge.encrypted_attribute?(name)).to be(true) }
    end
  end

  describe Pay::PaymentMethod do
    it 'encrypts card details held in data' do
      method = described_class.create!(customer:, processor_id: 'pm_1', data: { 'last4' => '4242', 'brand' => 'Visa' })

      expect(method.encrypted_attribute?(:data)).to be(true)
      expect(method.ciphertext_for(:data)).not_to include('4242')
      expect(method.reload.last4).to eq('4242')
    end
  end

  describe Pay::Merchant do
    it 'encrypts data' do
      merchant = described_class.create!(owner:, platform:, processor: 'stripe', data: { 'onboarding_complete' => true })

      expect(merchant.encrypted_attribute?(:data)).to be(true)
      expect(merchant).to be_onboarding_complete
    end
  end

  def fresh(record) = record.class.find(record.id)
end
