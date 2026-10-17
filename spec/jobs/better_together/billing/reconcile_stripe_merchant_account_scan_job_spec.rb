# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Billing::ReconcileStripeMerchantAccountScanJob do
  include ActiveJob::TestHelper

  describe 'queueing' do
    it 'uses the maintenance queue' do
      expect(described_class.new.queue_name).to eq('maintenance')
    end
  end

  describe '#perform' do
    let!(:eligible_account) do
      create(
        'better_together/billing/merchant_account',
        provider: 'stripe_connect',
        external_account_id: 'acct_scan_eligible'
      )
    end
    let!(:blank_external_id_account) do
      create(
        'better_together/billing/merchant_account',
        provider: 'stripe_connect',
        external_account_id: nil
      )
    end
    let!(:paypal_account) do
      create(
        'better_together/billing/merchant_account',
        :paypal
      )
    end

    it 'enqueues one refresh job per eligible Stripe merchant account' do
      described_class.perform_now

      reconciliation_jobs = enqueued_jobs.select do |job|
        job[:job] == BetterTogether::Billing::ReconcileStripeMerchantAccountJob
      end

      expect(reconciliation_jobs.map { |job| job[:queue] }.uniq).to eq(['default'])
      expect(reconciliation_jobs.map { |job| job[:args] }).to contain_exactly([eligible_account.id])
      expect(reconciliation_jobs.map { |job| job[:args] }).not_to include([blank_external_id_account.id], [paypal_account.id])
    end
  end
end
