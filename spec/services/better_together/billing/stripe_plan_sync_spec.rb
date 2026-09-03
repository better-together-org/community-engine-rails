# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripePlanSync do
  include ActiveJob::TestHelper

  let!(:plan) do
    create(
      :better_together_billing_plan,
      identifier: 'test-plan',
      stripe_price_id: 'price_test_existing',
      amount_cents: 5000,
      currency: 'CAD',
      billing_interval: 'month'
    ).tap { |p| p.update_columns(stripe_product_id: nil) }
  end

  let(:stripe_product) do
    Struct.new(:id, keyword_init: true).new(id: 'prod_new_123')
  end

  let(:matching_stripe_price) do
    Struct.new(:id, :unit_amount, :currency, :type, :recurring, keyword_init: true).new(
      id: 'price_test_existing',
      unit_amount: 5000,
      currency: 'cad',
      type: 'recurring',
      recurring: Struct.new(:interval, keyword_init: true).new(interval: 'month')
    )
  end

  describe '#call' do
    context 'when plan has no stripe_price_id' do
      let(:plan_without_price) { build(:better_together_billing_plan, stripe_price_id: nil) }

      it 'returns no_stripe_price_id without calling Stripe' do
        expect(Stripe::Product).not_to receive(:create)

        result = described_class.new.call(plan: plan_without_price)

        expect(result).to have_attributes(synced: false, reason: :no_stripe_price_id)
      end
    end

    context 'when plan has no existing stripe_product_id' do
      before do
        allow(Stripe::Product).to receive(:create).and_return(stripe_product)
        allow(Stripe::Price).to receive(:retrieve).and_return(matching_stripe_price)
      end

      it 'creates a new Stripe Product' do
        described_class.new.call(plan:)

        expect(Stripe::Product).to have_received(:create).with(
          hash_including(name: plan.name, active: plan.active)
        )
      end

      it 'includes billing plan metadata on the product' do
        described_class.new.call(plan:)

        expect(Stripe::Product).to have_received(:create).with(
          hash_including(
            metadata: hash_including(
              bt_billing_plan_id: plan.id,
              bt_billing_plan_identifier: plan.identifier
            )
          )
        )
      end

      it 'returns a successful result' do
        result = described_class.new.call(plan:)

        expect(result).to have_attributes(
          synced: true,
          stripe_product_id: 'prod_new_123',
          stripe_price_id: 'price_test_existing',
          reason: :synced
        )
      end

      it 'writes sync tracking columns to the plan' do
        described_class.new.call(plan:)
        plan.reload

        expect(plan.stripe_product_id).to eq('prod_new_123')
        expect(plan.sync_source).to eq('ce_push')
        expect(plan.synced_to_stripe_at).to be_present
      end
    end

    context 'when plan already has a stripe_product_id' do
      let(:existing_product) { Struct.new(:id, keyword_init: true).new(id: 'prod_existing_123') }

      before do
        plan.update_columns(stripe_product_id: 'prod_existing_123')
        allow(Stripe::Product).to receive(:update).and_return(existing_product)
        allow(Stripe::Product).to receive(:create)
        allow(Stripe::Price).to receive(:retrieve).and_return(matching_stripe_price)
      end

      it 'updates the existing Stripe Product rather than creating a new one' do
        described_class.new.call(plan:)

        expect(Stripe::Product).to have_received(:update).with(
          'prod_existing_123',
          hash_including(name: plan.name)
        )
        expect(Stripe::Product).not_to have_received(:create)
      end
    end

    context 'when the existing Stripe Price does not match local values' do
      let(:mismatched_stripe_price) do
        Struct.new(:id, :unit_amount, :currency, :type, :recurring, keyword_init: true).new(
          id: 'price_test_existing',
          unit_amount: 1000, # different from plan.amount_cents (5000)
          currency: 'cad',
          type: 'recurring',
          recurring: Struct.new(:interval, keyword_init: true).new(interval: 'month')
        )
      end

      let(:new_stripe_price) do
        Struct.new(:id, :unit_amount, :currency, :type, :recurring, keyword_init: true).new(
          id: 'price_new_456',
          unit_amount: 5000,
          currency: 'cad',
          type: 'recurring',
          recurring: Struct.new(:interval, keyword_init: true).new(interval: 'month')
        )
      end

      before do
        allow(Stripe::Product).to receive(:create).and_return(stripe_product)
        allow(Stripe::Price).to receive_messages(retrieve: mismatched_stripe_price, update: true, create: new_stripe_price)
      end

      it 'archives the old price' do
        described_class.new.call(plan:)

        expect(Stripe::Price).to have_received(:update).with('price_test_existing', active: false)
      end

      it 'creates a replacement Stripe Price' do
        described_class.new.call(plan:)

        expect(Stripe::Price).to have_received(:create).with(
          hash_including(unit_amount: 5000, currency: 'cad')
        )
      end

      it 'updates the plan stripe_price_id to the new price' do
        described_class.new.call(plan:)

        expect(plan.reload.stripe_price_id).to eq('price_new_456')
      end
    end

    context 'when Stripe raises a StripeError' do
      before do
        allow(Stripe::Product).to receive(:create).and_raise(Stripe::StripeError.new('API error'))
      end

      it 'returns stripe_error without re-raising' do
        expect { described_class.new.call(plan:) }.not_to raise_error

        result = described_class.new.call(plan:)
        expect(result).to have_attributes(synced: false, reason: :stripe_error)
      end
    end
  end
end
