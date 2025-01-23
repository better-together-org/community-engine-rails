# frozen_string_literal: true

class CreateBetterTogetherPhoneNumbers < ActiveRecord::Migration[7.1] # rubocop:todo Style/Documentation
  def change
    create_bt_table :phone_numbers do |t|
      t.string :number, null: false
      t.bt_label
      t.bt_privacy('better_together_phone_numbers')
      t.bt_references :contact_detail, null: false, foreign_key: { to_table: :better_together_contact_details }
    end
  end
end
