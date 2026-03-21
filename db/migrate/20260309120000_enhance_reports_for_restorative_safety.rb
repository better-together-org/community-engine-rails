# frozen_string_literal: true

# Extends report intake records with restorative-safety triage fields.
class EnhanceReportsForRestorativeSafety < ActiveRecord::Migration[7.1]
  def up
    add_safety_columns!
    backfill_existing_reports!
    enforce_required_fields!
    add_safety_indexes!
  end

  def down
    remove_index :better_together_reports, name: 'index_better_together_reports_uniqueness'
    remove_index :better_together_reports, :harm_level
    remove_index :better_together_reports, :category

    remove_column :better_together_reports, :retaliation_risk, :boolean
    remove_column :better_together_reports, :consent_to_restorative_process, :boolean
    remove_column :better_together_reports, :consent_to_contact, :boolean
    remove_column :better_together_reports, :private_details, :text
    remove_column :better_together_reports, :requested_outcome, :string
    remove_column :better_together_reports, :harm_level, :string
    remove_column :better_together_reports, :category, :string
  end

  private

  def add_safety_columns!
    change_table :better_together_reports, bulk: true do |t|
      t.string :category
      t.string :harm_level
      t.string :requested_outcome
      t.text :private_details
      t.boolean :consent_to_contact, null: false, default: true
      t.boolean :consent_to_restorative_process, null: false, default: false
      t.boolean :retaliation_risk, null: false, default: false
    end
  end

  def backfill_existing_reports!
    execute <<~SQL.squish
      UPDATE better_together_reports
      SET
        category = COALESCE(category, 'other'),
        harm_level = COALESCE(harm_level, 'medium'),
        requested_outcome = COALESCE(requested_outcome, 'content_review')
      WHERE
        category IS NULL
        OR harm_level IS NULL
        OR requested_outcome IS NULL
    SQL
  end

  def enforce_required_fields!
    change_column_null :better_together_reports, :category, false
    change_column_null :better_together_reports, :harm_level, false
    change_column_null :better_together_reports, :requested_outcome, false
  end

  def add_safety_indexes!
    add_index :better_together_reports, :category
    add_index :better_together_reports, :harm_level
    add_index :better_together_reports, %i[reporter_id reportable_type reportable_id],
              unique: true,
              name: 'index_better_together_reports_uniqueness'
  end
end
