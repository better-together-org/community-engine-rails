# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ReconcileStripeBillableOwnerBillingScanJob do
  include ActiveJob::TestHelper

  describe 'queueing' do
    it 'uses the maintenance queue' do
      expect(described_class.new.queue_name).to eq('maintenance')
    end
  end

  describe '#perform' do
    let!(:community) { create(:better_together_community) }
    let!(:person) { create(:better_together_person) }

    before do
      Pay::Customer.create!(owner: community, processor: 'stripe', processor_id: 'cus_scan_community')
      Pay::Customer.create!(owner: person, processor: 'stripe', processor_id: 'cus_scan_person')
      Pay::Customer.create!(owner: community, processor: 'stripe', processor_id: nil)
      Pay::Customer.create!(owner: community, processor: 'fake_processor', processor_id: 'cus_ignore')
    end

    it 'enqueues one reconciliation job per eligible Stripe-backed owner' do
      described_class.perform_now

      reconciliation_jobs = enqueued_jobs.select do |job|
        job[:job] == BetterTogether::Billing::ReconcileStripeBillableOwnerBillingJob
      end

      expect(reconciliation_jobs.map { |job| job[:queue] }.uniq).to eq(['default'])
      expect(reconciliation_jobs.map { |job| job[:args] }).to contain_exactly(
        [community.class.name, community.id],
        [person.class.name, person.id]
      )
    end
  end
end
