# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::BackfillStripeProductIdsJob do
  include ActiveJob::TestHelper

  describe 'queueing' do
    it 'uses the default queue' do
      expect(described_class.new.queue_name).to eq('default')
    end
  end

  describe '#perform' do
    let!(:plan_needs_backfill) do
      create(:better_together_billing_plan).tap do |p|
        p.update_columns(stripe_product_id: nil)
      end
    end

    let!(:plan_already_synced) do
      create(:better_together_billing_plan).tap do |p|
        p.update_columns(stripe_product_id: 'prod_already_has_it')
      end
    end

    before { clear_enqueued_jobs }

    it 'enqueues SyncPlanToStripeJob for plans missing stripe_product_id' do
      described_class.perform_now

      sync_job_args = enqueued_jobs
                      .select { |j| j[:job] == BetterTogether::Billing::SyncPlanToStripeJob }
                      .map { |j| j[:args] }
                      .flatten

      expect(sync_job_args).to include(plan_needs_backfill.id)
    end

    it 'does not enqueue SyncPlanToStripeJob for plans that already have stripe_product_id' do
      described_class.perform_now

      sync_job_args = enqueued_jobs
                      .select { |j| j[:job] == BetterTogether::Billing::SyncPlanToStripeJob }
                      .map { |j| j[:args] }
                      .flatten

      expect(sync_job_args).not_to include(plan_already_synced.id)
    end

    it 'enqueues no jobs when all plans are already synced' do
      plan_needs_backfill.update_columns(stripe_product_id: 'prod_now_synced_too')

      described_class.perform_now

      sync_jobs = enqueued_jobs.select { |j| j[:job] == BetterTogether::Billing::SyncPlanToStripeJob }

      expect(sync_jobs).to be_empty
    end
  end
end
