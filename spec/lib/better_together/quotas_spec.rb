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
    it 'never refuses in shadow mode, the default, regardless of amount, but says the limit would be passed' do
      decision = described_class.check!(type: 'media_storage', owner:, amount: 10**15)

      expect(decision).to have_attributes(allowed: true, exceeded: true, mode: 'shadow')
    end

    it 'says a small amount is fine' do
      decision = described_class.check!(type: 'media_storage', owner:, amount: 1)

      expect(decision).to have_attributes(allowed: true, exceeded: false, remaining: BetterTogether::Quotas::Types::MediaStorage::PERSON_DEFAULT_BYTES)
    end

    it 'refuses what would pass the limit in hard mode, and says how much is left' do
      described_class.settle!(type: 'media_storage', owner:, amount: 1, idempotency_key: 'quotas_spec:seed')
      BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage').update!(enforcement_mode: 'hard')

      expect { described_class.check!(type: 'media_storage', owner:, amount: 10**15) }
        .to raise_error(described_class::QuotaExceeded) { |error| expect(error.remaining).to eq(BetterTogether::Quotas::Types::MediaStorage::PERSON_DEFAULT_BYTES - 1) }
      expect(described_class.check!(type: 'media_storage', owner:, amount: 100)).to be_allowed
    end

    it 'warns but does not refuse in soft mode' do
      described_class.sync_limit!(type: 'media_storage', owner:)
      BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage').update!(enforcement_mode: 'soft')

      expect(described_class.check!(type: 'media_storage', owner:,
                                    amount: 10**15)).to have_attributes(allowed: true, exceeded: true,
                                                                        mode: 'soft')
    end

    it 'does not refuse when enforcement is off, or when the quota is suspended' do
      described_class.sync_limit!(type: 'media_storage', owner:)
      quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
      quota.update!(enforcement_mode: 'off')
      expect(described_class.check!(type: 'media_storage', owner:, amount: 10**15)).to be_allowed

      quota.update!(enforcement_mode: 'hard', status: 'suspended')
      expect(described_class.check!(type: 'media_storage', owner:, amount: 10**15)).to be_allowed
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
