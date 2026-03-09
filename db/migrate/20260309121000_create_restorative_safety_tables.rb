# frozen_string_literal: true

class CreateRestorativeSafetyTables < ActiveRecord::Migration[7.1]
  def change
    create_table :better_together_safety_cases, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :report, null: false, type: :uuid, foreign_key: { to_table: :better_together_reports }
      t.references :assigned_reviewer, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'submitted'
      t.string :lane, null: false
      t.string :closure_type
      t.string :category, null: false
      t.string :harm_level, null: false
      t.string :requested_outcome, null: false
      t.boolean :retaliation_risk, null: false, default: false
      t.boolean :consent_to_contact, null: false, default: true
      t.boolean :consent_to_restorative_process, null: false, default: false
      t.text :closure_summary
      t.datetime :review_at
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :better_together_safety_cases, :status
    add_index :better_together_safety_cases, :lane
    add_index :better_together_safety_cases, :created_at
    create_table :better_together_safety_actions, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :safety_case, null: false, type: :uuid, foreign_key: { to_table: :better_together_safety_cases }
      t.references :actor, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.references :approved_by, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :action_type, null: false
      t.string :status, null: false, default: 'active'
      t.text :reason, null: false
      t.text :details
      t.boolean :love_inclusivity_check, null: false, default: false
      t.boolean :solidarity_check, null: false, default: false
      t.boolean :accountability_check, null: false, default: false
      t.boolean :care_check, null: false, default: false
      t.text :values_review_notes
      t.boolean :requires_second_review, null: false, default: false
      t.datetime :review_at
      t.datetime :expires_at
      t.datetime :resolved_at
      t.timestamps
    end

    add_index :better_together_safety_actions, :action_type
    add_index :better_together_safety_actions, :status

    create_table :better_together_safety_notes, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :safety_case, null: false, type: :uuid, foreign_key: { to_table: :better_together_safety_cases }
      t.references :author, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :visibility, null: false, default: 'internal_only'
      t.text :body, null: false
      t.timestamps
    end

    add_index :better_together_safety_notes, :visibility

    create_table :better_together_safety_agreements, id: :uuid do |t|
      t.integer :lock_version, default: 0, null: false
      t.references :safety_case, null: false, type: :uuid, foreign_key: { to_table: :better_together_safety_cases }
      t.references :created_by, null: false, type: :uuid, foreign_key: { to_table: :better_together_people }
      t.string :status, null: false, default: 'proposed'
      t.text :summary, null: false
      t.text :commitments, null: false
      t.boolean :harmed_party_consented, null: false, default: false
      t.boolean :responsible_party_consented, null: false, default: false
      t.datetime :review_at
      t.datetime :completed_at
      t.timestamps
    end

    add_index :better_together_safety_agreements, :status
  end
end
