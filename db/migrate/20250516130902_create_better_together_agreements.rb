# frozen_string_literal: true

# Creates better_together_agreements table
class CreateBetterTogetherAgreements < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :agreements do |t|
      t.bt_creator
      t.bt_identifier
      t.bt_protected
      t.bt_privacy
    end
  end
end
