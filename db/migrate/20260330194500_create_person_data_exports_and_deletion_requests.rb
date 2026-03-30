# frozen_string_literal: true

class CreatePersonDataExportsAndDeletionRequests < ActiveRecord::Migration[7.2]
  def change
    create_table :better_together_person_data_exports, id: :uuid do |t|
      t.references :person, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'pending'
      t.string :format, null: false, default: 'json'
      t.datetime :requested_at, null: false
      t.datetime :started_at
      t.datetime :completed_at
      t.text :error_message
      t.timestamps
    end

    add_index :better_together_person_data_exports, %i[person_id requested_at], name: 'idx_bt_person_data_exports_person_requested'

    create_table :better_together_person_deletion_requests, id: :uuid do |t|
      t.references :person, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.references :reviewed_by, null: true, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'pending'
      t.datetime :requested_at, null: false
      t.datetime :resolved_at
      t.text :requested_reason
      t.text :reviewer_notes
      t.timestamps
    end

    add_index :better_together_person_deletion_requests, %i[person_id status], name: 'idx_bt_person_deletion_requests_person_status'
  end
end
