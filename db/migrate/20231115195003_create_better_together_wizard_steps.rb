# frozen_string_literal: true

# Creates wizard steps table
class CreateBetterTogetherWizardSteps < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :wizard_steps do |t|
      t.bt_references :wizard, null: false, index: { name: 'by_step_wizard' }
      t.bt_references :creator, index: { name: 'by_step_creator' }, target_table: :better_together_people, null: true
      t.string :identifier, null: false, limit: 100, index: { name: 'by_step_identifier' }
      t.boolean :completed, default: false
      t.integer :step_number, null: false
    end

    add_index :better_together_wizard_steps, %i[wizard_id step_number],
              name: 'index_wizard_steps_on_wizard_id_and_step_number'

    add_index :better_together_wizard_steps,
              %i[wizard_id identifier creator_id],
              unique: true,
              name: 'index_unique_wizard_steps',
              where: 'completed IS FALSE'

    # Adding a foreign key on :identifier
    add_foreign_key :better_together_wizard_steps,
                    :better_together_wizard_step_definitions,
                    column: :identifier,
                    primary_key: :identifier
  end
end
