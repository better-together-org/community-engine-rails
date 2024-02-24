class CreateBetterTogetherWizardStepDefinitions < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :wizard_step_definitions do |t|
      t.string :name, null: false
      t.string :slug, null: false, index: { unique: true }
      t.text :description, null: false
      t.string :identifier, null: false, limit: 100, index: { unique: true }
      t.string :template
      t.string :form_class
      t.string :message, null: false, default: 'Please complete this next step.'
      t.integer :step_number, null: false
      t.bt_references :wizard, null: false, index: { name: 'by_step_definition_wizard' },
                               target_table: :better_together_wizards
      t.bt_protected
    end

    add_index :better_together_wizard_step_definitions, %i[wizard_id step_number], unique: true,
                                                                                   name: 'index_wizard_step_definitions_on_wizard_id_and_step_number'
  end
end
