# frozen_string_literal: true

require 'rails_helper'

# What changes when a platform switches a quota from recording to enforcing, and that nothing stored is ever reduced.
RSpec.describe BetterTogether::Quotas do
  include AutomaticTestConfiguration
  include ActiveJob::TestHelper

  let!(:host_platform) { configure_host_platform }
  let(:owner) { create(:better_together_person) }
  let(:limit) { 5 * (1024**3) }

  def quota = BetterTogether::Quota.find_by!(owner:, quota_type: 'media_storage')

  def reserve(amount, key, **) = described_class.reserve!(type: 'media_storage', owner:, amount:, idempotency_key: key, **)

  def harden!
    described_class.sync_limit!(type: 'media_storage', owner:)
    quota.update!(enforcement_mode: 'hard')
  end

  describe 'rows belong to their owner\'s platform' do
    it 'sets the platform on the quota, the usage and the reservation, whatever the request or job was running as' do
      other = create(:better_together_platform)
      member = create(:better_together_person, platform: other)
      Current.platform = host_platform

      described_class.settle!(type: 'media_storage', owner: member, amount: 10, idempotency_key: 'p:1')
      described_class.reserve!(type: 'media_storage', owner: member, amount: 10, idempotency_key: 'p:2')

      expect(BetterTogether::Quota.find_by!(owner: member, quota_type: 'media_storage').platform_id).to eq(other.id)
      expect(BetterTogether::QuotaUsage.find_by!(idempotency_key: 'p:1').platform_id).to eq(other.id)
      expect(BetterTogether::QuotaReservation.find_by!(idempotency_key: 'p:2').platform_id).to eq(other.id)
    ensure
      Current.platform = nil
    end

    it 'puts a platform\'s own usage on that platform' do
      described_class.settle!(type: 'media_storage', owner: host_platform, amount: 1, idempotency_key: 'p:3')

      expect(BetterTogether::QuotaUsage.find_by!(idempotency_key: 'p:3').platform_id).to eq(host_platform.id)
    end
  end

  describe 'a race for the same idempotency key' do
    it 'returns the row the other writer made instead of failing' do
      first = described_class.settle!(type: 'media_storage', owner:, amount: 5, idempotency_key: 'race:1')
      # The racing writer's first lookup misses (the other row is not committed yet); the retry finds it, as a fresh record.
      allow(BetterTogether::QuotaUsage).to receive(:find_by).and_call_original
      allow(BetterTogether::QuotaUsage).to receive(:find_by).with(idempotency_key: 'race:1').and_return(nil, BetterTogether::QuotaUsage.find(first.id))

      again = described_class.settle!(type: 'media_storage', owner:, amount: 5, idempotency_key: 'race:1')

      expect(again.id).to eq(first.id)
      expect(BetterTogether::QuotaUsage.where(idempotency_key: 'race:1').count).to eq(1)
      expect(BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative').consumed).to eq(5)
    end
  end

  describe '.reserve! in hard mode' do
    before { harden! }

    it 'refuses a hold that would pass the limit, and records nothing' do
      expect { reserve(limit + 1, 'big') }.to raise_error(described_class::QuotaExceeded)
      expect(BetterTogether::QuotaReservation.where(idempotency_key: 'big')).to be_empty
    end

    it 'counts the holds already in force, so two uploads for the last bytes cannot both be let through' do
      reserve(limit - 100, 'first')

      expect { reserve(200, 'second') }.to raise_error(described_class::QuotaExceeded)
      expect(reserve(100, 'third')).to be_persisted
    end

    it 'counts what is already used' do
      described_class.settle!(type: 'media_storage', owner:, amount: limit - 50, idempotency_key: 'used')

      expect { reserve(51, 'over') }.to raise_error(described_class::QuotaExceeded)
      expect(reserve(50, 'exact')).to be_persisted
    end

    it 'does not count a hold twice when the same request is repeated' do
      reserve(limit - 10, 'once')

      expect { reserve(limit - 10, 'once') }.not_to raise_error
      expect(BetterTogether::QuotaReservation.where(idempotency_key: 'once').count).to eq(1)
    end

    it 'does not count a hold that expired or was released' do
      reserve(limit, 'whole', ttl: 1.minute)
      travel_to(2.minutes.from_now) { expect(reserve(limit, 'next')).to be_persisted }
    end

    it 'checks and holds under the quota lock' do
      locked = false
      allow_any_instance_of(BetterTogether::Quota).to receive(:with_lock).and_wrap_original do |original, *args, &block| # rubocop:disable RSpec/AnyInstance
        original.call(*args) do
          locked = true
          block.call
        end
      end

      reserve(10, 'locked')

      expect(locked).to be(true)
    end

    it 'can record a hold without refusing it' do
      expect(reserve(limit * 2, 'recorded', enforce: false)).to be_persisted
    end
  end

  describe 'in the other modes' do
    %w[off shadow soft].each do |mode|
      it "never refuses a hold in #{mode} mode" do
        described_class.sync_limit!(type: 'media_storage', owner:)
        quota.update!(enforcement_mode: mode)

        expect(reserve(limit * 2, "mode:#{mode}")).to be_persisted
      end
    end
  end

  describe 'settling' do
    it 'never refuses: the work is done and the usage is a fact, even past a hard limit' do
      harden!

      expect { described_class.settle!(type: 'media_storage', owner:, amount: limit * 2, idempotency_key: 'done') }.not_to raise_error
      expect(BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative').consumed).to eq(limit * 2)
    end

    it 'leaves a downgraded owner\'s usage alone and refuses only new consumption' do
      harden!
      described_class.settle!(type: 'media_storage', owner:, amount: limit - 10, idempotency_key: 'kept')
      quota.update!(limit: 100) # the allowance went away

      expect(BetterTogether::QuotaUsage.where(quota:).sum(:amount)).to eq(limit - 10)
      expect { reserve(1, 'new') }.to raise_error(described_class::QuotaExceeded)
    end
  end

  describe 'holds that were never settled' do
    it 'are let go once their time ran out, and stop counting' do
      held = reserve(1_000, 'abandoned', ttl: 1.minute)

      travel_to(2.minutes.from_now) { described_class.expire_reservations! }

      expect(held.reload.status).to eq('expired')
      expect(BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative').reserved).to eq(0)
    end

    it 'are left alone while they are in force, and when already settled' do
      live = reserve(1_000, 'live', ttl: 1.hour)
      settled = reserve(500, 'settled', ttl: 1.minute)
      settled.update!(status: 'settled')

      travel_to(2.minutes.from_now) { described_class.expire_reservations! }

      expect(live.reload.status).to eq('held')
      expect(settled.reload.status).to eq('settled')
    end

    it 'are swept hourly by a job on the billing queue' do
      job = BetterTogether::Billing::ExpireQuotaReservationsJob

      expect(job.new.queue_name).to eq(BetterTogether::Billing::ApplicationJob.new.queue_name)
      held = reserve(1_000, 'job', ttl: 1.minute)
      travel_to(2.minutes.from_now) { job.perform_now }
      expect(held.reload.status).to eq('expired')
    end
  end

  describe 'the limit' do
    let(:provider) do
      Class.new do
        def amount(owner:, type:) = owner.is_a?(BetterTogether::Person) && type == 'media_storage' ? 1_000 : 0
        def pool?(**) = false
      end.new
    end

    after { BetterTogether::Quotas::Allowances.reset! }

    it 'is the default plus what every allowance provider adds, written when it is synced' do
      described_class.settle!(type: 'media_storage', owner:, amount: 1, idempotency_key: 'first')
      BetterTogether::Quotas::Allowances.register(:test, provider)

      described_class.sync_limit!(type: 'media_storage', owner:)

      expect(quota.limit).to eq(limit + 1_000)
    end

    it 'drops back when the allowance goes, with usage untouched' do
      BetterTogether::Quotas::Allowances.register(:test, provider)
      described_class.sync_limit!(type: 'media_storage', owner:)
      described_class.settle!(type: 'media_storage', owner:, amount: limit + 500, idempotency_key: 'big')
      BetterTogether::Quotas::Allowances.unregister(:test)

      described_class.sync_limit!(type: 'media_storage', owner:)

      expect(quota.limit).to eq(limit)
      expect(BetterTogether::QuotaUsage.where(quota:).sum(:amount)).to eq(limit + 500)
    end

    it 'starts a new quota at the effective limit, not the bare default' do
      BetterTogether::Quotas::Allowances.register(:test, provider)

      described_class.settle!(type: 'media_storage', owner:, amount: 1, idempotency_key: 'fresh')

      expect(quota.limit).to eq(limit + 1_000)
    end
  end

  describe 'a platform\'s enforcement' do
    it 'starts at shadow, and a steward can switch one quota type, which reaches every quota on the platform' do
      member = create(:better_together_person, platform: host_platform)
      described_class.settle!(type: 'media_storage', owner: member, amount: 1, idempotency_key: 'e:1')
      described_class.settle!(type: 'ai_translation_tokens', owner: member, amount: 1, idempotency_key: 'e:2')
      expect(host_platform.quota_enforcement_mode('media_storage')).to eq('shadow')

      host_platform.set_quota_enforcement!('media_storage', 'hard')

      expect(BetterTogether::Quota.find_by!(owner: member, quota_type: 'media_storage')).to be_enforcement_mode_hard
      expect(BetterTogether::Quota.find_by!(owner: member, quota_type: 'ai_translation_tokens')).to be_enforcement_mode_shadow
    end

    it 'applies to quotas made afterwards' do
      host_platform.set_quota_enforcement!('media_storage', 'soft')
      member = create(:better_together_person, platform: host_platform)

      described_class.settle!(type: 'media_storage', owner: member, amount: 1, idempotency_key: 'e:3')

      expect(BetterTogether::Quota.find_by!(owner: member, quota_type: 'media_storage')).to be_enforcement_mode_soft
    end

    it 'refuses an unknown mode or quota type' do
      expect { host_platform.set_quota_enforcement!('media_storage', 'strict') }.to raise_error(BetterTogether::Quotas::PlatformEnforcement::InvalidMode)
      expect { host_platform.set_quota_enforcement!('bogus', 'hard') }.to raise_error(BetterTogether::Quotas::PlatformEnforcement::InvalidMode)
    end
  end

  describe 'when recording goes wrong' do
    it 'logs, reports and counts the failure instead of passing silently' do
      allow(BetterTogether).to receive(:report_error)
      allow(Rails).to receive(:cache).and_return(ActiveSupport::Cache::MemoryStore.new)

      described_class.record_failure(StandardError.new('boom'), 'a hook')

      expect(BetterTogether).to have_received(:report_error)
      expect(described_class.failures_today).to eq(1)
    end
  end
end
