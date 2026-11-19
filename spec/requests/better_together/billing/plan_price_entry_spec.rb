# frozen_string_literal: true

require 'rails_helper'

# A steward types a plan's price the way it is written (45.00), not in cents. The plan form converts it for the plan's
# currency, so currencies without cents take whole numbers, and shows the same figure again on edit.
RSpec.describe 'Billing plan price entry' do # rubocop:disable RSpec/DescribeClass
  include_context 'with clean billing processors'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:password) { 'SecureTest123!@#' }
  let(:manager) { find_or_create_test_user("plan-price-manager-#{SecureRandom.hex(4)}@example.test", password, :platform_manager) }
  let(:adapter) { BetterTogether::Billing::FakeAdapter.new(capabilities: %i[checkout plan_sync lookups]) }

  before do
    BetterTogether::Billing.register_processor(:fake, -> { adapter })
    sign_in manager
  end

  def plans_path = better_together.billing_plans_path(locale:)

  def create_plan(amount:, currency: 'USD', identifier: "price-#{SecureRandom.hex(3)}")
    post plans_path, params: { billing_plan: { identifier:, name: 'Priced', processor: 'fake', amount:, currency: } }
    BetterTogether::Billing::Plan.find_by(identifier:)
  end

  describe 'the form' do
    it 'asks for the price in whole and decimal units, not cents' do
      get better_together.new_billing_plan_path(locale:)

      expect(response.body).to include('name="billing_plan[amount]"')
      expect(response.body).not_to include('name="billing_plan[amount_cents]"')
    end

    it 'shows an existing price back as it would be written' do
      plan = create(:better_together_billing_plan, :unlinked, amount_cents: 12_345, currency: 'USD')

      get better_together.edit_billing_plan_path(plan, locale:)

      expect(Nokogiri::HTML(response.body).at_css('#billing_plan_amount')['value']).to eq('123.45')
    end

    it 'shows a zero-decimal price without decimals' do
      plan = create(:better_together_billing_plan, :unlinked, amount_cents: 500, currency: 'JPY')

      get better_together.edit_billing_plan_path(plan, locale:)

      expect(Nokogiri::HTML(response.body).at_css('#billing_plan_amount')['value']).to eq('500')
    end
  end

  describe 'creating' do
    it 'stores 45.00 as 4500 cents' do
      expect(create_plan(amount: '45.00')).to have_attributes(amount_cents: 4500, currency: 'USD')
    end

    it 'stores 45 as 4500 cents and 0.5 as 50' do
      expect(create_plan(amount: '45').amount_cents).to eq(4500)
      expect(create_plan(amount: '0.5').amount_cents).to eq(50)
    end

    it 'accepts a decimal comma' do
      expect(create_plan(amount: '45,50').amount_cents).to eq(4550)
    end

    it 'stores a zero-decimal currency as entered' do
      expect(create_plan(amount: '4500', currency: 'JPY').amount_cents).to eq(4500)
    end

    it 'refuses decimals for a zero-decimal currency, saying so' do
      expect { create_plan(amount: '45.5', currency: 'JPY') }.not_to change(BetterTogether::Billing::Plan, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('no more than 0 decimal places')
    end

    it 'refuses more than two decimals for other currencies' do
      create_plan(amount: '4.999')

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include('no more than 2 decimal places')
    end

    it 'refuses text, negatives and blanks, and keeps what was typed in the field' do
      %w[abc -5 1e3].each do |bad|
        create_plan(amount: bad)

        expect(response).to have_http_status(:unprocessable_content), "expected #{bad.inspect} to be refused"
        expect(response.body).to include('Amount must be a plain figure')
        expect(Nokogiri::HTML(response.body).at_css('#billing_plan_amount')['value']).to eq(bad)
      end

      create_plan(amount: '')
      expect(response).to have_http_status(:unprocessable_content)
    end

    it 'refuses a price too large to store' do
      create_plan(amount: '99999999999999999999')

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe 'editing' do
    let(:plan) { create(:better_together_billing_plan, :unlinked, amount_cents: 12_345, currency: 'USD') }

    it 'changes the price from a figure in dollars' do
      patch better_together.billing_plan_path(plan, locale:), params: { billing_plan: { amount: '99.99' } }

      expect(plan.reload.amount_cents).to eq(9999)
    end

    it 'leaves the price alone when the amount is not sent' do
      patch better_together.billing_plan_path(plan, locale:), params: { billing_plan: { name: 'Renamed' } }

      expect(plan.reload.amount_cents).to eq(12_345)
    end

    it 'converts with the currency chosen in the same request' do
      patch better_together.billing_plan_path(plan, locale:), params: { billing_plan: { amount: '800', currency: 'JPY' } }

      expect(plan.reload).to have_attributes(amount_cents: 800, currency: 'JPY')
    end

    it 'does not let a linked plan change its price' do
      linked = create(:better_together_billing_plan, amount_cents: 4500)

      patch better_together.billing_plan_path(linked, locale:), params: { billing_plan: { amount: '1.00' } }

      expect(linked.reload.amount_cents).to eq(4500)
    end
  end
end
