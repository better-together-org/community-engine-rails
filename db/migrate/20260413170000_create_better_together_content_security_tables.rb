# frozen_string_literal: true

class CreateBetterTogetherContentSecurityTables < ActiveRecord::Migration[7.2]
  def change
    create_content_security_items_table
    create_content_security_scan_events_table
    create_content_security_findings_table
  end

  private

  def create_content_security_items_table
    create_bt_table :content_security_items do |t|
      t.uuid :blob_id, null: false
      t.references :attachable, polymorphic: true, null: false, type: :uuid, index: false
      t.references :safety_case, type: :uuid, foreign_key: { to_table: :better_together_safety_cases }
      t.string :attachment_name, null: false
      t.string :source_surface, null: false
      t.string :lifecycle_state, null: false, default: 'pending_scan'
      t.string :aggregate_verdict, null: false, default: 'pending_scan'
      t.string :scanner_name
      t.datetime :scanned_at
      t.datetime :released_at
      t.string :last_error_class
      t.text :last_error_summary
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_content_security_items,
              %i[attachable_type attachable_id attachment_name],
              unique: true,
              name: 'index_bt_content_security_items_on_attachment'
    add_index :better_together_content_security_items,
              %i[blob_id attachable_type attachable_id attachment_name],
              unique: true,
              name: 'index_bt_content_security_items_on_blob_attachment'
    add_index :better_together_content_security_items, :lifecycle_state
    add_foreign_key :better_together_content_security_items, :active_storage_blobs, column: :blob_id
  end

  def create_content_security_scan_events_table
    create_bt_table :content_security_scan_events do |t|
      t.references :item, null: false, type: :uuid, foreign_key: { to_table: :better_together_content_security_items }
      t.string :status, null: false, default: 'started'
      t.string :plane, null: false, default: 'technical'
      t.string :scanner_name, null: false
      t.string :scanner_version
      t.string :verdict
      t.string :signature_name
      t.string :error_class
      t.text :error_summary
      t.datetime :started_at, null: false
      t.datetime :finished_at
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_content_security_scan_events, :status
    add_index :better_together_content_security_scan_events, :plane
  end

  def create_content_security_findings_table
    create_bt_table :content_security_findings do |t|
      t.references :item, null: false, type: :uuid, foreign_key: { to_table: :better_together_content_security_items }
      t.references :scan_event, null: false, type: :uuid,
                                foreign_key: { to_table: :better_together_content_security_scan_events }
      t.references :safety_case, type: :uuid, foreign_key: { to_table: :better_together_safety_cases }
      t.string :plane, null: false, default: 'technical'
      t.string :finding_type, null: false
      t.string :rule_id
      t.string :severity, null: false
      t.string :confidence, null: false
      t.string :verdict, null: false
      t.text :evidence_summary
      t.datetime :detected_at, null: false
      t.jsonb :metadata, null: false, default: {}
    end

    add_index :better_together_content_security_findings, :plane
    add_index :better_together_content_security_findings, :verdict
  end
end
