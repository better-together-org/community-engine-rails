# frozen_string_literal: true

class AddPrimaryFlagToContactTypes < ActiveRecord::Migration[7.1]
  def change
    change_table :better_together_phone_numbers do |t|
      t.bt_primary_flag(parent_key: :contact_detail_id)
    end

    change_table :better_together_email_addresses do |t|
      t.bt_primary_flag(parent_key: :contact_detail_id)
    end

    change_table :better_together_addresses do |t|
      t.bt_primary_flag(parent_key: :contact_detail_id)
    end
  end
end
