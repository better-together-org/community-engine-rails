# frozen_string_literal: true

class AddPersonDeletionAuditsAndTombstones < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_people, :deleted_at, :datetime unless column_exists?(:better_together_people, :deleted_at)
    add_column :better_together_people, :anonymized_at, :datetime unless column_exists?(:better_together_people, :anonymized_at)

    create_table :better_together_person_purge_audits, id: :uuid unless table_exists?(:better_together_person_purge_audits)

    ensure_reference :better_together_person_purge_audits, :person, :better_together_people
    ensure_reference :better_together_person_purge_audits, :person_deletion_request, :better_together_person_deletion_requests
    ensure_reference :better_together_person_purge_audits, :reviewed_by, :better_together_people
    ensure_column :better_together_person_purge_audits, :status, :string, null: false, default: 'running'
    ensure_column :better_together_person_purge_audits, :user_email_snapshot, :string
    ensure_column :better_together_person_purge_audits, :person_identifier_snapshot, :string
    ensure_column :better_together_person_purge_audits, :person_name_snapshot, :string
    ensure_column :better_together_person_purge_audits, :requested_reason_snapshot, :text
    ensure_column :better_together_person_purge_audits, :reviewer_notes_snapshot, :text
    ensure_column :better_together_person_purge_audits, :inventory_snapshot, :jsonb, null: false, default: {}
    ensure_column :better_together_person_purge_audits, :execution_snapshot, :jsonb, null: false, default: {}
    ensure_column :better_together_person_purge_audits, :error_message, :text
    ensure_column :better_together_person_purge_audits, :requested_at, :datetime
    ensure_column :better_together_person_purge_audits, :reviewed_at, :datetime
    ensure_column :better_together_person_purge_audits, :started_at, :datetime
    ensure_column :better_together_person_purge_audits, :completed_at, :datetime
    ensure_column :better_together_person_purge_audits, :failed_at, :datetime
    ensure_column :better_together_person_purge_audits, :created_at, :datetime, precision: 6, null: false
    ensure_column :better_together_person_purge_audits, :updated_at, :datetime, precision: 6, null: false

    add_index :better_together_person_purge_audits, :status unless index_exists?(:better_together_person_purge_audits, :status)
    add_index :better_together_person_purge_audits, :requested_at unless index_exists?(:better_together_person_purge_audits, :requested_at)
  end

  private

  def ensure_reference(table_name, reference_name, to_table)
    column_name = :"#{reference_name}_id"
    add_reference table_name, reference_name, type: :uuid unless column_exists?(table_name, column_name)

    return if foreign_key_exists?(table_name, to_table, column: column_name)

    add_foreign_key table_name, to_table, column: column_name
  end

  def ensure_column(table_name, column_name, type, **)
    return if column_exists?(table_name, column_name)

    add_column table_name, column_name, type, **
  end
end
