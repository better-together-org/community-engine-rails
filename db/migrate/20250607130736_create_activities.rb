# frozen_string_literal: true

# Migration responsible for creating a table with activities
class CreateActivities < ActiveRecord::Migration[7.1]
  def change
    create_bt_table :activities do |t|
      t.bt_references :trackable, polymorphic: true, index: { name: 'bt_activities_by_trackable' }
      t.bt_references :owner, polymorphic: true, index: { name: 'bt_activities_by_owner' }
      t.string :key
      t.jsonb :parameters
      t.bt_references :recipient, polymorphic: true, index: { name: 'bt_activities_by_recipient' }
    end
  end
end
