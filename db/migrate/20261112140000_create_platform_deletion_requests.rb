# frozen_string_literal: true

# Requests from the last steward of a platform to have the platform removed by host stewards.
class CreatePlatformDeletionRequests < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:better_together_platform_deletion_requests)
      create_table :better_together_platform_deletion_requests, id: :uuid do |t|
        t.references :platform, null: false, type: :uuid, foreign_key: { to_table: :better_together_platforms },
                                index: { name: 'idx_bt_platform_deletion_requests_platform' }
        t.references :requested_by, null: false, type: :uuid, foreign_key: { to_table: :better_together_people },
                                    index: { name: 'idx_bt_platform_deletion_requests_requester' }
        t.references :reviewed_by, null: true, type: :uuid, foreign_key: { to_table: :better_together_people },
                                   index: { name: 'idx_bt_platform_deletion_requests_reviewer' }
        t.string :status, null: false, default: 'pending'
        t.datetime :requested_at, null: false
        t.datetime :resolved_at
        t.text :requested_reason
        t.text :reviewer_notes
        t.integer :lock_version, null: false, default: 0
        t.timestamps
      end
    end

    return if index_name_exists?(:better_together_platform_deletion_requests, 'idx_bt_platform_deletion_requests_pending')

    add_index :better_together_platform_deletion_requests, :platform_id, unique: true,
                                                                         where: "status = 'pending'",
                                                                         name: 'idx_bt_platform_deletion_requests_pending'
  end
end
