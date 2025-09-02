# frozen_string_literal: true

class CreateBetterTogetherContentLinks < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :links, prefix: :better_together_content do |t|
      t.string :link_type, null: false, index: true
      t.string :url, null: false, index: true
      t.string :scheme
      t.string :host, index: true
      # Data re: the link itself
      t.boolean :external, index: true
      t.boolean :valid_link, index: true
      t.datetime :last_checked_at, index: true
      t.string :latest_status_code, index: true
      t.text :error_message
    end
  end
end
