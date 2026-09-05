# frozen_string_literal: true

# Enforce at the DB layer that a person can have at most one pending deletion
# request at a time. The model-level validate :single_active_request guard is
# susceptible to a TOCTOU race under concurrent requests; this partial unique
# index closes that gap.
class AddPendingUniqueIndexToPersonDeletionRequests < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :better_together_person_deletion_requests,
              :person_id,
              unique: true,
              where: "status = 'pending'",
              name: 'idx_bt_person_deletion_requests_one_pending_per_person',
              algorithm: :concurrently,
              if_not_exists: true
  end
end
