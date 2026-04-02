# frozen_string_literal: true

class AddPersonDeletionAuditsAndTombstones < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_people, bulk: true do |t|
      t.datetime :deleted_at
      t.datetime :anonymized_at
    end

    create_table :better_together_person_purge_audits, id: :uuid do |t|
      t.references :person, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.references :person_deletion_request, type: :uuid, foreign_key: { to_table: :better_together_person_deletion_requests }
      t.references :reviewed_by, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'running'
      t.string :user_email_snapshot
      t.string :person_identifier_snapshot
      t.string :person_name_snapshot
      t.text :requested_reason_snapshot
      t.text :reviewer_notes_snapshot
      t.jsonb :inventory_snapshot, null: false, default: {}
      t.jsonb :execution_snapshot, null: false, default: {}
      t.text :error_message
      t.datetime :requested_at
      t.datetime :reviewed_at
      t.datetime :started_at
      t.datetime :completed_at
      t.datetime :failed_at
      t.timestamps
    end

    add_index :better_together_person_purge_audits, :status
    add_index :better_together_person_purge_audits, :requested_at
  end
end
