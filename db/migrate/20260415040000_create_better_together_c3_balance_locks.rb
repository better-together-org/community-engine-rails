# frozen_string_literal: true

# Creates C3::BalanceLock — an audit record for every locked C3 amount.
#
# Replaces the ad-hoc SecureRandom.uuid lock_ref returned by
# C3LockRequestsController: locks are now persisted, tied to a specific
# balance and source platform, and expire automatically after 24 hours
# via the C3::ExpireBalanceLocksJob.
#
# Status lifecycle: pending → settled | released | expired
class CreateBetterTogetherC3BalanceLocks < ActiveRecord::Migration[7.2]
  def change
    return if table_exists?(:better_together_c3_balance_locks)

    create_bt_table :c3_balance_locks do |t|
      # The balance that has been locked
      t.references :balance, type: :uuid, null: false,
                             foreign_key: { to_table: :better_together_c3_balances,
                                            on_delete: :cascade },
                             index: { name: 'idx_bt_c3_balance_locks_balance' }

      # Opaque reference returned to the locking party (peer platform or local caller)
      t.string :lock_ref, null: false
      t.index :lock_ref, unique: true, name: 'idx_bt_c3_balance_locks_ref'

      # Amount locked (stored as millitokens to avoid float rounding)
      t.bigint :millitokens, null: false

      # Caller-supplied reference identifying the agreement this lock is for
      t.string :agreement_ref

      # Which platform requested this lock (nil for local locks)
      t.references :source_platform, type: :uuid, null: true,
                                     foreign_key: { to_table: :better_together_platforms,
                                                    on_delete: :nullify },
                                     index: { name: 'idx_bt_c3_balance_locks_source_platform' }

      # pending: C3 is reserved; settled: C3 was transferred via settle_to!;
      # released: lock was explicitly cancelled; expired: 24h TTL elapsed
      t.string :status, null: false, default: 'pending'

      # Hard expiry — ExpireBalanceLocksJob runs every 15 minutes and releases
      # any lock whose expires_at has passed.
      t.datetime :expires_at, null: false
      t.datetime :settled_at
    end

    add_index :better_together_c3_balance_locks, %i[status expires_at],
              name: 'idx_bt_c3_balance_locks_expiry'
  end
end
