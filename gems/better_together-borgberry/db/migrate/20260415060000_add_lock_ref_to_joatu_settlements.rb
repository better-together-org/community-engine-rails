# frozen_string_literal: true

# Add lock_ref to joatu_settlements so that the Settlement lifecycle (complete!/cancel!)
# can tell C3::Balance#settle_to! / C3::Balance#unlock! which BalanceLock to finalise.
#
# Without this column, BalanceLock records created during Agreement#accept! would stay
# permanently 'pending' until the 24h expiry job ran — even after the exchange completed.
class AddLockRefToJoatuSettlements < ActiveRecord::Migration[7.2]
  def change
    return if column_exists?(:better_together_joatu_settlements, :lock_ref)

    add_column :better_together_joatu_settlements, :lock_ref, :string
    add_index :better_together_joatu_settlements, :lock_ref,
              name: 'idx_bt_joatu_settlements_lock_ref',
              where: 'lock_ref IS NOT NULL'
  end
end
