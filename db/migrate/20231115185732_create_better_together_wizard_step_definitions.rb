# frozen_string_literal: true

# Creates wizard step definitions table
class CreateBetterTogetherWizardStepDefinitions < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :wizard_step_definitions do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_slug

      t.bt_references :wizard, null: false, index: { name: 'by_step_definition_wizard' },
                               target_table: :better_together_wizards

      t.string :template
      t.string :form_class
      t.string :message, null: false, default: 'Please complete this next step.'
      t.integer :step_number, null: false
    end

    add_index :better_together_wizard_step_definitions,
              %i[wizard_id step_number],
              unique: true,
              name: 'index_wizard_step_definitions_on_wizard_id_and_step_number'
  end
end
