# frozen_string_literal: true

# Creates wizards table
class CreateBetterTogetherWizards < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :wizards do |t|
      t.bt_identifier
      t.bt_protected
      t.bt_slug

      t.integer :max_completions, null: false, default: 0
      t.integer :current_completions, null: false, default: 0
      t.datetime :first_completed_at
      t.datetime :last_completed_at
      t.text :success_message, null: false, default: 'Thank you. You have successfully completed the wizard'
      t.string :success_path, null: false, default: '/'

      # timestamps and lock_version are automatically added
    end
  end
end
