# frozen_string_literal: true

class CreateBetterTogetherAddresses < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :addresses do |t|
      t.bt_label
      t.boolean :physical, default: true, null: false
      t.boolean :postal, default: false, null: false
      t.string :line1
      t.string :line2
      t.string :city_name
      t.string :state_province_name
      t.string :postal_code
      t.string :country_name
      t.bt_privacy('better_together_addresses')
      t.bt_references :contact_detail, null: false, foreign_key: { to_table: :better_together_contact_details }
    end
  end
end
