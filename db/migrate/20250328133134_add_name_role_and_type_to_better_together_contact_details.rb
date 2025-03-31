# frozen_string_literal: true

class AddNameRoleAndTypeToBetterTogetherContactDetails < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_contact_details do |t|
      t.string :type, null: false, default: 'BetterTogether::ContactDetail'
      t.string :name
      t.string :role
    end
  end
end
