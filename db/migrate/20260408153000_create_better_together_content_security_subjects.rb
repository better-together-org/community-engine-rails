# frozen_string_literal: true

class CreateBetterTogetherContentSecuritySubjects < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_content_security_subjects, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :subject, polymorphic: true, null: false, type: :uuid
      t.references :active_storage_blob, type: :uuid, foreign_key: { to_table: :active_storage_blobs }
      t.string :attachment_name, null: false
      t.string :content_id, null: false
      t.string :source_surface, null: false
      t.string :storage_ref, null: false
      t.string :lifecycle_state, null: false, default: 'pending_scan'
      t.string :aggregate_verdict, null: false, default: 'review_required'
      t.string :current_visibility_state, null: false, default: 'private'
      t.string :current_ai_ingestion_state, null: false, default: 'pending_review'
      t.datetime :released_at
      t.timestamps
    end

    add_index :better_together_content_security_subjects, :content_id,
              unique: true,
              name: 'index_bt_content_security_subjects_on_content_id'
    add_index :better_together_content_security_subjects,
              %i[subject_type subject_id attachment_name],
              unique: true,
              name: 'index_bt_content_security_subjects_on_subject_attachment'
    add_index :better_together_content_security_subjects, :lifecycle_state,
              name: 'index_bt_content_security_subjects_on_lifecycle_state'
    add_index :better_together_content_security_subjects, :aggregate_verdict,
              name: 'index_bt_content_security_subjects_on_aggregate_verdict'
  end
end
