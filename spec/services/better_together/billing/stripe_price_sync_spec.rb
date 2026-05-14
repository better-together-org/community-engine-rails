# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::StripePriceSync do
  include ActiveJob::TestHelper

  let!(:plan) do
    create(
      :better_together_billing_plan,
      active: true
    ).tap { |p| p.update_columns(stripe_product_id: 'prod_sync_test', latest_stripe_event_id: nil) }
  end

  def build_event(id:, type:, object_data:)
    data = Struct.new(:object, keyword_init: true).new(object: object_data)
    Struct.new(:id, :type, :data, keyword_init: true).new(id: id, type: type, data: data)
  end

  describe '#call' do
    context 'with a price.updated event for a known plan' do
      let(:price_object) do
        Struct.new(:id, :active, keyword_init: true).new(
          id: plan.stripe_price_id,
          active: false
        )
      end
      let(:event) { build_event(id: 'evt_price_upd_1', type: 'price.updated', object_data: price_object) }

      it 'returns a synced result' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: true, plan:, reason: :synced)
      end

      it 'updates the plan active flag from the price object' do
        described_class.new.call(event:)

        expect(plan.reload.active).to be(false)
      end

      it 'writes sync tracking columns' do
        described_class.new.call(event:)
        plan.reload

        expect(plan.sync_source).to eq('stripe_webhook')
        expect(plan.latest_stripe_event_id).to eq('evt_price_upd_1')
        expect(plan.synced_to_stripe_at).to be_present
      end

      it 'does not overwrite CE-owned name or description' do
        original_name = plan.name
        described_class.new.call(event:)

        expect(plan.reload.name).to eq(original_name)
      end
    end

    context 'with a price.created event for a known plan' do
      let(:price_object) do
        Struct.new(:id, :active, keyword_init: true).new(
          id: plan.stripe_price_id,
          active: true
        )
      end
      let(:event) { build_event(id: 'evt_price_cre_1', type: 'price.created', object_data: price_object) }

      it 'returns a synced result' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: true, reason: :synced)
      end
    end

    context 'with a price.deleted event for a known plan' do
      let(:price_object) do
        Struct.new(:id, :active, keyword_init: true).new(
          id: plan.stripe_price_id,
          active: false
        )
      end
      let(:event) { build_event(id: 'evt_price_del_1', type: 'price.deleted', object_data: price_object) }

      it 'deactivates the plan' do
        described_class.new.call(event:)

        expect(plan.reload.active).to be(false)
      end

      it 'returns a deactivated reason' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: true, plan:, reason: :deactivated)
      end

      it 'writes sync tracking columns' do
        described_class.new.call(event:)
        plan.reload

        expect(plan.sync_source).to eq('stripe_webhook')
        expect(plan.latest_stripe_event_id).to eq('evt_price_del_1')
      end
    end

    context 'with a product.updated event for a known plan' do
      let(:product_object) do
        Struct.new(:id, :active, keyword_init: true).new(
          id: 'prod_sync_test',
          active: false
        )
      end
      let(:event) { build_event(id: 'evt_prod_upd_1', type: 'product.updated', object_data: product_object) }

      it 'syncs active from the product event' do
        described_class.new.call(event:)

        expect(plan.reload.active).to be(false)
      end

      it 'does not overwrite CE-owned name or description' do
        original_name = plan.name
        described_class.new.call(event:)

        expect(plan.reload.name).to eq(original_name)
      end

      it 'writes sync tracking columns' do
        described_class.new.call(event:)
        plan.reload

        expect(plan.sync_source).to eq('stripe_webhook')
        expect(plan.latest_stripe_event_id).to eq('evt_prod_upd_1')
      end
    end

    context 'with a product.created event for a known plan' do
      let(:product_object) do
        Struct.new(:id, :active, keyword_init: true).new(
          id: 'prod_sync_test',
          active: true
        )
      end
      let(:event) { build_event(id: 'evt_prod_cre_1', type: 'product.created', object_data: product_object) }

      it 'returns a synced result' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: true, reason: :synced)
      end
    end

    context 'when no plan matches the price id' do
      let(:unknown_price_object) do
        Struct.new(:id, :active, keyword_init: true).new(id: 'price_unknown_999', active: false)
      end
      let(:event) { build_event(id: 'evt_no_plan', type: 'price.updated', object_data: unknown_price_object) }

      it 'returns plan_not_found' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: false, reason: :plan_not_found)
      end
    end

    context 'when no plan matches the product id' do
      let(:unknown_product_object) do
        Struct.new(:id, :active, keyword_init: true).new(id: 'prod_unknown_999', active: false)
      end
      let(:event) { build_event(id: 'evt_no_prod_plan', type: 'product.updated', object_data: unknown_product_object) }

      it 'returns plan_not_found' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: false, reason: :plan_not_found)
      end
    end

    context 'when the event is a duplicate (latest_stripe_event_id already matches)' do
      before { plan.update_columns(latest_stripe_event_id: 'evt_already_seen') }

      let(:price_object) do
        Struct.new(:id, :active, keyword_init: true).new(id: plan.stripe_price_id, active: false)
      end
      let(:event) { build_event(id: 'evt_already_seen', type: 'price.updated', object_data: price_object) }

      it 'returns duplicate_event without updating the plan' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: false, reason: :duplicate_event)
        expect(plan.reload.active).to be(true) # unchanged
      end
    end

    context 'with an unhandled event type' do
      let(:event) do
        Struct.new(:id, :type, keyword_init: true).new(id: 'evt_other', type: 'invoice.created')
      end

      it 'returns unhandled_event_type' do
        result = described_class.new.call(event:)

        expect(result).to have_attributes(synced: false, reason: :unhandled_event_type)
      end
    end
  end
end
