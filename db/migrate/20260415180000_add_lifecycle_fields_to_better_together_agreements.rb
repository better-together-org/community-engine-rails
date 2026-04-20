# frozen_string_literal: true

class AddLifecycleFieldsToBetterTogetherAgreements < ActiveRecord::Migration[7.2]
  def change
    change_table :better_together_agreements, bulk: true do |t|
      t.string :lifecycle_state, null: false, default: 'active'
      t.boolean :requires_reacceptance, null: false, default: false
      t.text :change_summary
    end

    add_index :better_together_agreements, :lifecycle_state
  end
end
