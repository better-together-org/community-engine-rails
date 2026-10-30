# frozen_string_literal: true

require 'rails_helper'

module BetterTogether # :nodoc:
  RSpec.describe BillingHelper do
    describe '#billing_amount' do
      it 'formats a known currency with its curated symbol' do
        expect(helper.billing_amount(4_500, 'CAD')).to eq('CA$45.00')
        expect(helper.billing_amount(4_500, 'EUR')).to eq('€45.00')
      end

      it 'is case-insensitive on the currency code' do
        expect(helper.billing_amount(4_500, 'cad')).to eq('CA$45.00')
      end

      it 'falls back to the raw code for an uncurated currency' do
        expect(helper.billing_amount(4_500, 'SEK')).to eq('SEK 45.00')
      end

      it 'does not divide zero-decimal currencies by 100' do
        expect(helper.billing_amount(1_000, 'JPY')).to eq('JPY 1,000')
        expect(helper.billing_amount(5_000, 'KRW')).to eq('KRW 5,000')
      end

      it 'omits the unit when no currency is known instead of assuming one' do
        expect(helper.billing_amount(4_500, nil)).to eq('45.00')
      end
    end

    describe '#billing_interval_label' do
      it 'returns the localized label for a known interval' do
        expect(helper.billing_interval_label('month')).to eq('Monthly')
        expect(helper.billing_interval_label('year')).to eq('Yearly')
      end
    end

    describe '#billing_lookup_options' do
      subject(:options) do
        JSON.parse(helper.billing_lookup_options(kind: 'prices', scope_from: { product: '#product' }, preserve_selection: true))
      end

      before { helper.extend(BetterTogether::Engine.routes.url_helpers) }

      it 'points the SlimSelect controller at the lookup endpoint with the kind' do
        expect(options['ajax']).to include('params' => { 'kind' => 'prices' })
        expect(options['ajax']['url']).to end_with('/billing/processor_options')
      end

      it 'reads the processor, and any narrowing field, from the form at fetch time' do
        expect(options['ajax']['paramsFrom']).to eq('processor' => '#billing_plan_processor', 'product' => '#product')
      end

      it 'carries translated messages, so the controller holds no English' do
        expect(options['ajax']['errorText']).to eq(I18n.t('better_together.billing.plans.lookup_unavailable'))
        expect(options['requiredMessage']).to eq(I18n.t('better_together.billing.plans.select_required'))
        expect(options['ajax']['errorHeader']).to eq('X-Billing-Lookup-Error')
      end

      it 'keeps the chosen value when asked' do
        expect(options['preserveSelection']).to be(true)
      end
    end

    describe 'plan status helpers' do
      let(:plan) { build_stubbed(:better_together_billing_plan, sync_status: 'failed', sync_error: 'processor_unavailable') }

      it 'renders a badge with a stable id and class for the status' do
        badge = helper.billing_sync_badge(plan)

        expect(badge).to include('billing-plan-sync-status-badge', 'bg-danger', helper.dom_id(plan, :sync_status_badge))
      end

      it 'shows a translated, short reason, never raw processor text' do
        expect(helper.billing_sync_error(plan)).to eq(I18n.t('better_together.billing.plans.sync_errors.processor_unavailable'))
      end

      it 'falls back to the generic reason for an unknown code' do
        plan.sync_error = 'something_new'

        expect(helper.billing_sync_error(plan)).to eq(I18n.t('better_together.billing.plans.sync_errors.processor_error'))
      end

      it 'shows nothing when there is no error' do
        plan.sync_error = nil

        expect(helper.billing_sync_error(plan)).to be_nil
      end
    end
  end
end
