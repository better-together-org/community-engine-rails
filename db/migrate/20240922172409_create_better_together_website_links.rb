# frozen_string_literal: true

class CreateBetterTogetherWebsiteLinks < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :website_links do |t|
      t.string :url, null: false
      t.bt_label
      t.bt_privacy
      t.bt_references :contact_detail, null: false, foreign_key: { to_table: :better_together_contact_details }
    end
  end
end
