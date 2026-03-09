# frozen_string_literal: true

# Extends report intake records with restorative-safety triage fields.
class EnhanceReportsForRestorativeSafety < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_reports, bulk: true do |t|
      t.string :category, null: false
      t.string :harm_level, null: false
      t.string :requested_outcome, null: false
      t.text :private_details
      t.boolean :consent_to_contact, null: false, default: true
      t.boolean :consent_to_restorative_process, null: false, default: false
      t.boolean :retaliation_risk, null: false, default: false
    end

    add_index :better_together_reports, :category
    add_index :better_together_reports, :harm_level
    add_index :better_together_reports, %i[reporter_id reportable_type reportable_id],
              unique: true,
              name: 'index_better_together_reports_uniqueness'
  end
end
