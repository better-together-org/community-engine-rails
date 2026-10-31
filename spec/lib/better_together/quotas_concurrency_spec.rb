# frozen_string_literal: true

require 'rails_helper'

# Real multi-threaded, multi-connection specs (not just `with_lock` reviewed by eye).
# `use_transactional_fixtures = false` in rails_helper.rb is necessary but not
# sufficient: ordinary (non-js/feature/system) examples still get DatabaseCleaner's
# `:transaction` strategy (rails_helper.rb's own global `before`), which wraps the
# example in its own open, uncommitted transaction on the main connection - invisible
# to any other connection checked out from the pool. The `:js` tag below is what
# actually makes commits from worker threads visible to each other and back to the
# main thread's reads: it switches that SAME global hook to the `:deletion` strategy.
#
# Do NOT call DatabaseCleaner.strategy=/.start/.clean directly in this file instead of
# tagging: the global `before`/`after` already call them, in that same hook, using
# whatever `.strategy` was set to at that point from metadata. A second manual
# `.start` call here fires the :transaction strategy's own belt-and-suspenders open
# transaction, immediately followed by this file's :deletion-strategy `.start` doing
# nothing to release it - left both open and unreleased, visible via
# `pg_stat_activity` as a connection stuck forever at "RELEASE SAVEPOINT
# active_record_N", deadlocking a later connection's INSERT against the same table.
# Reproduced and confirmed exactly this way during development; tagging instead of
# overriding avoids it entirely.
RSpec.describe BetterTogether::Quotas, :js do
  include AutomaticTestConfiguration

  before { configure_host_platform }

  let(:owner) { create(:better_together_person) }

  def balance
    quota = BetterTogether::Quota.find_by(owner:, quota_type: 'media_storage')
    BetterTogether::QuotaBalance.find_by(quota:, period_key: 'cumulative')
  end

  # Thread#value (not #join) so a raised exception inside a thread surfaces here
  # instead of being silently swallowed - a thread crashing invisibly would make
  # these specs pass for the wrong reason (less concurrent work actually happened).
  # Capped below the DB connection pool size (5 by default - see
  # spec/dummy/config/database.yml): the main thread already holds one connection,
  # so `count` + 1 must not exceed the pool or a worker thread times out waiting.
  def in_threads(count)
    count.times.map { |i| Thread.new { ActiveRecord::Base.connection_pool.with_connection { yield(i) } } }
               .each(&:value)
  end

  describe 'concurrent .settle! for the same owner+type' do
    it 'loses no updates to the materialized balance under real concurrent writers' do
      in_threads(4) do |i|
        described_class.settle!(
          type: 'media_storage', owner:, amount: 100,
          idempotency_key: "quotas_concurrency_spec:settle:#{i}"
        )
      end

      expect(balance.consumed).to eq(400)
    end

    it 'leaves exactly one QuotaUsage row per idempotency_key, none lost to the race' do
      in_threads(4) do |i|
        described_class.settle!(
          type: 'media_storage', owner:, amount: 100,
          idempotency_key: "quotas_concurrency_spec:rows:#{i}"
        )
      end

      table = BetterTogether::QuotaUsage.arel_table
      expect(BetterTogether::QuotaUsage.where(table[:idempotency_key].matches('quotas_concurrency_spec:rows:%')).count)
        .to eq(4)
    end
  end

  describe 'concurrent .settle! racing on the exact same idempotency_key' do
    it 'writes exactly one QuotaUsage row, backed by the DB unique index, not app logic alone' do
      in_threads(4) do
        described_class.settle!(
          type: 'media_storage', owner:, amount: 100,
          idempotency_key: 'quotas_concurrency_spec:same_key'
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        # find_or_create_by! can raise either under a genuine race between two threads
        # both missing the row at read time: RecordInvalid from the uniqueness
        # *validation* losing the race (reproduced directly - the first version of
        # this spec only rescued RecordNotUnique and flaked on this), RecordNotUnique
        # from the DB index itself if both somehow pass validation. Quotas.settle!
        # does not retry either, so the spec's job is only to assert the row count
        # stays exactly one afterward, not that every racing caller succeeds quietly.
        nil
      end

      expect(BetterTogether::QuotaUsage.where(idempotency_key: 'quotas_concurrency_spec:same_key').count)
        .to eq(1)
    end

    it 'only ever adds the amount to the balance once' do
      in_threads(4) do
        described_class.settle!(
          type: 'media_storage', owner:, amount: 100,
          idempotency_key: 'quotas_concurrency_spec:same_key_balance'
        )
      rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
        nil
      end

      expect(balance.consumed).to eq(100)
    end
  end

  describe 'concurrent .reserve! and the sweeper' do
    it 'does not let a reservation settling mid-sweep get double-counted out of reserved' do
      blob = ActiveStorage::Blob.create_and_upload!(io: StringIO.new('abc'), filename: 'a.txt',
                                                    content_type: 'text/plain')
      described_class.reserve!(
        type: 'media_storage', owner:, amount: 300,
        idempotency_key: 'quotas_concurrency_spec:reserve_sweep', ttl: 10.minutes, subject: blob
      )

      jobs = [
        proc { described_class.settle_reservations_for!(blob) },
        proc { BetterTogether::Quotas::ReservationSweeperJob.perform_now }
      ]
      jobs.map { |job| Thread.new { ActiveRecord::Base.connection_pool.with_connection(&job) } }
          .each(&:value)

      expect(balance.reserved).to eq(0)
    end
  end
end
