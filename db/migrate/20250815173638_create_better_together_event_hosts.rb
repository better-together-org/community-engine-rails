# frozen_string_literal: true

# creates a polymorphic join table between an event and its host
class CreateBetterTogetherEventHosts < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :event_hosts do |t|
      t.bt_references :event
      t.bt_references :host, polymorphic: true
    end
  end
end
