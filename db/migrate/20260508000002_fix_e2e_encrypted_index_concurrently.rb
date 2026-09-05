# frozen_string_literal: true

# The original migration (20260315020200) added an index on
# better_together_messages.e2e_encrypted without CONCURRENTLY, which takes an
# exclusive table lock on upgrade. This migration replaces it with a concurrent
# index so large deployments can apply the release without downtime.
class FixE2eEncryptedIndexConcurrently < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  OLD_INDEX = 'index_better_together_messages_on_e2e_encrypted'

  def up
    # Remove the blocking index created by the original migration if present.
    remove_index :better_together_messages, name: OLD_INDEX, if_exists: true

    # Re-add concurrently so no exclusive lock is held.
    add_index :better_together_messages,
              :e2e_encrypted,
              name: OLD_INDEX,
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :better_together_messages, name: OLD_INDEX, if_exists: true
    add_index :better_together_messages, :e2e_encrypted, if_not_exists: true
  end
end
