# frozen_string_literal: true

class AddTypeToBetterTogetherRoles < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_roles do |t|
      t.string :type, null: false, default: 'BetterTogether::Role'
    end
  end
end
