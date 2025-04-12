# frozen_string_literal: true

# Creates files table. Later remamed to better_together_uploads to avoid class name conflict with ::File
class CreateBetterTogetherFiles < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :files do |t|
      t.bt_creator
      t.bt_identifier
      t.bt_privacy
      t.string :type, null: false, default: 'BetterTogether::File'
    end
  end
end
