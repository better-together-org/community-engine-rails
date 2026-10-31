# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas::ReservationSweeperJob do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:owner) { create(:better_together_person) }

  def balance
    quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
    BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative')
  end

  describe 'queueing' do
    it 'uses the maintenance queue' do
      expect(described_class.new.queue_name).to eq('maintenance')
    end
  end

  describe '#perform' do
    it 'expires a held reservation past its ttl' do
      BetterTogether::Quotas.reserve!(
        type: 'media_storage', owner:, amount: 300,
        idempotency_key: 'sweeper_spec:1', ttl: 1.minute
      )

      travel 2.minutes do
        described_class.perform_now
      end

      expect(BetterTogether::QuotaReservation.find_by(idempotency_key: 'sweeper_spec:1'))
        .to be_status_expired
    end

    it 'refreshes the balance so reserved no longer counts the expired amount' do
      BetterTogether::Quotas.reserve!(
        type: 'media_storage', owner:, amount: 300,
        idempotency_key: 'sweeper_spec:2', ttl: 1.minute
      )
      expect(balance.reserved).to eq(300)

      travel 2.minutes do
        described_class.perform_now
        expect(balance.reload.reserved).to eq(0)
      end
    end

    it 'leaves a still-live held reservation untouched' do
      BetterTogether::Quotas.reserve!(
        type: 'media_storage', owner:, amount: 300,
        idempotency_key: 'sweeper_spec:3', ttl: 10.minutes
      )

      described_class.perform_now

      expect(BetterTogether::QuotaReservation.find_by(idempotency_key: 'sweeper_spec:3'))
        .to be_status_held
    end

    it 'leaves an already-settled reservation untouched' do
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('abc'), filename: 'a.txt',
                                                    content_type: 'text/plain')
      BetterTogether::Quotas.reserve!(
        type: 'media_storage', owner:, amount: 300,
        idempotency_key: 'sweeper_spec:4', ttl: 1.minute, subject: blob
      )
      BetterTogether::Quotas.settle_reservations_for!(blob)

      travel(2.minutes) { described_class.perform_now }

      expect(BetterTogether::QuotaReservation.find_by(idempotency_key: 'sweeper_spec:4'))
        .to be_status_settled
    end
  end
end
