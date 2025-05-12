# frozen_string_literal: true

# Creats table for BetterTogether::Event

class CreateBetterTogetherEvents < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :events do |t|
      t.string :type, null: false, default: 'BetterTogether::Event'

      t.bt_creator
      t.bt_identifier
      t.bt_privacy

      t.datetime :starts_at, index: { name: 'bt_events_by_starts_at' }
      t.datetime :ends_at, index: { name: 'bt_events_by_ends_at' }

      t.decimal :duration_minutes
    end
  end
end
