# frozen_string_literal: true

require 'rails_helper'

# The public catalog: listed plans, readable without signing in, each with a way into checkout.
RSpec.describe BetterTogether::Billing::CatalogController do
  include_context 'with entitlement fixtures'
  include_context 'with billing switched on'

  let(:locale) { :en }
  let(:free_attrs) { { processor: nil, processor_price_id: nil, processor_product_id: nil, amount_cents: 0, accepted_payment_methods: [] } }
  let!(:monthly) { sub_plan.tap { |plan| plan.update!(listed: true) } }
  let!(:free) { create(:better_together_billing_plan, listed: true, **free_attrs) }
  let!(:hidden) { create(:better_together_billing_plan, listed: false, **free_attrs) }

  def checkout_for_price(price) = better_together.new_billing_checkout_path(price_id: price.id, locale:)
  def checkout_for(plan) = better_together.new_billing_checkout_path(plan_id: plan.id, locale:)

  describe 'choosing between prices' do
    let!(:annual) do
      create(:better_together_billing_price, product: monthly, platform: monthly.platform, kind: 'recurring', interval: 'year',
                                             amount_cents: 30_000, currency: 'USD')
    end

    it 'lists every active recurring price of a plan, each with its own way into checkout' do
      get better_together.billing_catalog_plan_path(monthly, locale:)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(monthly, :catalog_prices),
                                       checkout_for_price(monthly.current_price), checkout_for_price(annual))
    end

    it 'leaves out a price taken off sale' do
      annual.archive!

      get better_together.billing_catalog_plan_path(monthly, locale:)

      expect(response.body).not_to include(checkout_for_price(annual), ActionView::RecordIdentifier.dom_id(monthly, :catalog_prices))
    end

    it 'shows no chooser for a plan with one price' do
      get better_together.billing_catalog_plan_path(free, locale:)

      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(free, :catalog_prices))
    end

    it 'takes the buyer to checkout for the price they chose' do
      get checkout_for_price(annual)

      expect(response).to have_http_status(:found).or have_http_status(:ok)
    end
  end

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

    it 'shows a plan once, as a plan, and not again among the products' do
      get better_together.billing_catalog_path(locale:)

      expect(response.body).to include(ActionView::RecordIdentifier.dom_id(monthly, :catalog))
      expect(response.body).not_to include(better_together.billing_catalog_product_path(monthly, locale:))

      get better_together.billing_catalog_product_path(monthly, locale:)
      expect(response).to have_http_status(:not_found)
    end

    it 'leaves out a plan whose only recurring price was taken off sale, and its page is not found' do
      monthly.current_price.archive!

      get better_together.billing_catalog_path(locale:)
      expect(response.body).not_to include(ActionView::RecordIdentifier.dom_id(monthly, :catalog))

      get better_together.billing_catalog_plan_path(monthly, locale:)
      expect(response).to have_http_status(:not_found)
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

  describe 'plans limited to an audience' do
    let(:perk_attrs) { { processor: nil, processor_price_id: nil, processor_product_id: nil } }
    let!(:members_only) do
      create(:better_together_billing_plan, listed: true, restricted_to_members: true, name: 'Member price', **perk_attrs)
    end
    let!(:subscribers_only) do
      create(:better_together_billing_plan, listed: true, restricted_to_subscribers: true, name: 'Subscriber extras', **perk_attrs)
    end
    let(:card) { ->(plan) { ActionView::RecordIdentifier.dom_id(plan, :catalog) } }

    let(:make_member) do
      lambda do
        add_grant('membership_role', { 'joinable' => 'platform', 'role' => supporter_role.identifier }, plan: sub_plan)
        start_subscription
      end
    end

    it 'keeps them out of the catalog for a visitor, and does not reveal them by id' do
      get better_together.billing_catalog_path(locale:)
      expect(response.body).not_to include(card.call(members_only), card.call(subscribers_only))

      get better_together.billing_catalog_plan_path(members_only, locale:)
      expect(response).to have_http_status(:not_found)
    end

    it 'keeps them out for a signed-in person who is neither' do
      sign_in buyer_user

      get better_together.billing_catalog_path(locale:)

      expect(response.body).not_to include(card.call(members_only), card.call(subscribers_only))
    end

    it 'shows a members-only plan to a member' do
      make_member.call
      sign_in buyer_user

      get better_together.billing_catalog_path(locale:)
      expect(response.body).to include(card.call(members_only))

      get better_together.billing_catalog_plan_path(members_only, locale:)
      expect(response).to have_http_status(:ok)
    end

    it 'shows a subscribers-only plan to a subscriber' do
      make_entitlement(beneficiary: buyer)
      sign_in buyer_user

      get better_together.billing_catalog_path(locale:)

      expect(response.body).to include(card.call(subscribers_only))
    end

    it 'does not let a person who does not qualify start checkout for it by link' do
      sign_in buyer_user

      get better_together.new_billing_checkout_path(plan_id: members_only.id, locale:)

      expect(response).to have_http_status(:not_found)
    end

    it 'lets a member start checkout for it' do
      make_member.call
      sign_in buyer_user

      get better_together.new_billing_checkout_path(plan_id: members_only.id, locale:)

      expect(response).to have_http_status(:ok)
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
