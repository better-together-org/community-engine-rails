# frozen_string_literal: true

# Creates platforms table
class CreateBetterTogetherPlatforms < ActiveRecord::Migration[7.0]
  def change # rubocop:todo Metrics/MethodLength
    create_bt_table :platforms do |t|
      t.bt_identifier
      t.bt_host
      t.bt_protected
      t.bt_privacy('platform')
      t.bt_slug

      t.bt_references :community, target_table: :better_together_communities, null: true,
                                  index: { name: 'by_platform_community' }

      # Adding a unique URL field
      t.string :url, null: false, index: { unique: true }

      t.string :time_zone, null: false

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
