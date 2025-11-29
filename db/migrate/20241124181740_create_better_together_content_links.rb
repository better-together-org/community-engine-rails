# frozen_string_literal: true

# Migration to create the persistent links table used by the
# BetterTogether rich text link metrics system.
class CreateBetterTogetherContentLinks < ActiveRecord::Migration[7.1]
  # rubocop:disable Metrics/MethodLength
  def change
    create_bt_table :links, prefix: :better_together_content do |t|
      t.string :link_type, null: false, index: true
      t.string :url, null: false, index: true
      t.string :scheme
      t.string :host, index: true
      t.boolean :external, index: true
      t.boolean :valid_link, index: true
      t.datetime :last_checked_at, index: true
      t.string :latest_status_code, index: true
      t.text :error_message
    end
  end
  # rubocop:enable Metrics/MethodLength
end
