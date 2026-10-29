# frozen_string_literal: true

require 'rails_helper'

RSpec.describe BetterTogether::Quotas do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:owner) { create(:better_together_person) }

  def balance
    quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
    BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative')
  end

  describe '.check!' do
    it 'is always permissive in shadow mode regardless of amount' do
      result = described_class.check!(type: 'media_storage', owner:, amount: 10**15)
      expect(result).to be true
    end

    it 'is permissive even against a quota row whose enforcement_mode is hard' do
      described_class.settle!(
        type: 'media_storage', owner:, amount: 1, idempotency_key: 'quotas_spec:seed'
      )
      BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
                           .update!(enforcement_mode: 'hard')

      expect(described_class.check!(type: 'media_storage', owner:, amount: 10**15)).to be true
    end
  end

  describe '.settle!' do
    it 'creates exactly one QuotaUsage row' do
      described_class.settle!(
        type: 'media_storage', owner:, amount: 500, idempotency_key: 'quotas_spec:settle:1'
      )

      expect(BetterTogether::QuotaUsage.where(idempotency_key: 'quotas_spec:settle:1').count).to eq(1)
    end

    it 'is idempotent on idempotency_key: calling twice writes only one row' do
      2.times do
        described_class.settle!(
          type: 'media_storage', owner:, amount: 500, idempotency_key: 'quotas_spec:settle:2'
        )
      end

      expect(BetterTogether::QuotaUsage.where(idempotency_key: 'quotas_spec:settle:2').count).to eq(1)
    end

    it 'is backed by a real DB-level unique index on idempotency_key, not just app logic' do
      connection = ActiveRecord::Base.connection
      expect(
        connection.indexes(:better_together_quota_usages).find { |i| i.columns == ['idempotency_key'] }
      ).to have_attributes(unique: true)
    end

    it 'creates a lazily-defaulted Quota row on first use' do
      expect do
        described_class.settle!(
          type: 'media_storage', owner:, amount: 500, idempotency_key: 'quotas_spec:settle:4'
        )
      end.to change(BetterTogether::Quota, :count).by(1)
    end

    it 'files usage under the period of occurred_at when given, not the current one' do
      usage = described_class.settle!(
        type: 'ai_translation_tokens', owner:, amount: 10, idempotency_key: 'quotas_spec:settle:period',
        occurred_at: Time.zone.local(2025, 3, 14, 12)
      )

      expect(usage.period_key).to eq('2025-03')
    end

    it 'adds a new row to the balance once, and an idempotent repeat not at all' do
      2.times do
        described_class.settle!(
          type: 'media_storage', owner:, amount: 500, idempotency_key: 'quotas_spec:settle:balance'
        )
      end
      described_class.settle!(
        type: 'media_storage', owner:, amount: 250, idempotency_key: 'quotas_spec:settle:balance:2'
      )

      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
      expect(BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative').consumed).to eq(750)
    end

    it 'skips logging when the type declares the subject does not count' do
      log = create(:ai_log_translation, status: 'failure')

      described_class.settle!(
        type: 'ai_translation_tokens', owner:, amount: 10, idempotency_key: 'quotas_spec:settle:5',
        subject: log
      )

      expect(BetterTogether::QuotaUsage.where(idempotency_key: 'quotas_spec:settle:5')).not_to exist
    end
  end

  describe '.reserve! and .settle_reservations_for!' do
    let(:blob) do
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new('abc'), filename: 'a.txt', content_type: 'text/plain')
    end

    it 'counts a held reservation as reserved until it is settled' do
      described_class.reserve!(
        type: 'media_storage', owner:, amount: 300, idempotency_key: 'quotas_spec:reserve:1', subject: blob
      )
      expect(balance.reserved).to eq(300)

      described_class.settle_reservations_for!(blob)

      expect(balance.reload.reserved).to eq(0)
      expect(BetterTogether::QuotaReservation.find_by(idempotency_key: 'quotas_spec:reserve:1'))
        .to be_status_settled
    end

    it 'stops counting a held reservation once it has expired' do
      described_class.reserve!(
        type: 'media_storage', owner:, amount: 300, idempotency_key: 'quotas_spec:reserve:2', ttl: 1.minute
      )
      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')

      travel 2.minutes do
        expect(BetterTogether::QuotaBalance.refresh_reserved!(quota, 'cumulative').reserved).to eq(0)
      end
    end
  end

  describe '.reverse!' do
    it 'writes a negative-amount row for a reversible type (media_storage)' do
      described_class.settle!(
        type: 'media_storage', owner:, amount: 500, idempotency_key: 'quotas_spec:reverse:settle'
      )
      usage = described_class.reverse!(
        type: 'media_storage', owner:, amount: 500, idempotency_key: 'quotas_spec:reverse:1'
      )

      expect(usage.amount).to eq(-500)
    end

    it 'raises NonReversibleQuotaError for a non-reversible type (ai_translation_tokens)' do
      expect do
        described_class.reverse!(
          type: 'ai_translation_tokens', owner:, amount: 10, idempotency_key: 'quotas_spec:reverse:2'
        )
      end.to raise_error(BetterTogether::Quotas::NonReversibleQuotaError)

      expect(BetterTogether::QuotaUsage.where(idempotency_key: 'quotas_spec:reverse:2')).not_to exist
    end
  end
end
