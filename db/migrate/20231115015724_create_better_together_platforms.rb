class CreateBetterTogetherPlatforms < ActiveRecord::Migration[7.0]
  def change
    create_bt_table :platforms do |t|
      # Using bt_emoji_string and bt_emoji_text for name and description
      t.bt_emoji_string :name
      t.bt_emoji_text :description

      # Adding a unique URL field
      t.string :url, null: false, unique: true

      # Adding a host field with a uniqueness constraint
      t.boolean :host, default: false, null: false
      t.index :host, unique: true, where: "host IS TRUE"
      t.string :time_zone, null: false
      
      # Adding privacy column
      t.string :privacy, null: false, default: 'public', limit: 50, index: { name: 'by_platform_privacy' }

      t.bt_references :community, target_table: :better_together_communities, null: true, index: { name: 'by_platform_community' }

      # Adding a unique index on url
      t.index :url, unique: true

      # Standard columns like lock_version and timestamps are added by create_bt_table
    end
  end
end
