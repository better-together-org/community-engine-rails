# frozen_string_literal: true

require 'rails_helper'

# The public catalog: listed plans, readable without signing in, each with a way into checkout.
RSpec.describe BetterTogether::Billing::CatalogController do
  include_context 'with subscription fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:free_attrs) { { processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 0, accepted_payment_methods: [] } }
  let!(:monthly) { sub_plan.tap { |plan| plan.update!(listed: true) } }
  let!(:free) { create(:better_together_billing_plan, :one_time, listed: true, **free_attrs) }
  let!(:hidden) { create(:better_together_billing_plan, :one_time, listed: false, **free_attrs) }

  def checkout_for(plan) = better_together.new_billing_checkout_path(plan_id: plan.id, locale:)

  describe 'GET /:locale/billing/catalog' do
    it 'shows listed plans to a visitor who is not signed in, each with a button to buy' do
      get better_together.billing_catalog_path(locale:)

      expect(response).to have_http_status(:ok)
      expect_html_contents(monthly.name, free.name, 'US$30.00 a month', 'Free')
      expect(response.body).to include(checkout_for(monthly), checkout_for(free))
    end

    it 'leaves out a plan that is not listed' do
      get better_together.billing_catalog_path(locale:)

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(hidden, :catalog))
    end

    it 'leaves out a listed plan that is no longer active' do
      monthly.update!(active: false)

      get better_together.billing_catalog_path(locale:)

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(monthly, :catalog))
    end

    it 'says so when nothing is listed' do
      BetterTogether::Billing::Plan.update_all(listed: false) # rubocop:disable Rails/SkipsModelValidations

      get better_together.billing_catalog_path(locale:)

      expect(response.body).to include('billing-catalog-empty')
    end

    it 'is not found when billing is off for the platform' do
      allow(BetterTogether::Billing).to receive(:enabled?).and_return(false)

      get better_together.billing_catalog_path(locale:)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe 'GET /:locale/billing/catalog/:id' do
    it 'shows one listed plan with its buy button' do
      get better_together.billing_catalog_plan_path(monthly, locale:)

      expect(response).to have_http_status(:ok)
      expect_html_content(monthly.name)
      expect(response.body).to include(checkout_for(monthly))
    end

    it 'is not found for a plan that is not listed' do
      get better_together.billing_catalog_plan_path(hidden, locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'is not found for an id that is not a plan' do
      get better_together.billing_catalog_plan_path(SecureRandom.uuid, locale:)

      expect(response).to have_http_status(:not_found)
    end
  end
end
