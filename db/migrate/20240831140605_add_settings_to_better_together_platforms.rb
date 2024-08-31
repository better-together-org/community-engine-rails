class AddSettingsToBetterTogetherPlatforms < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_platforms, :settings, :jsonb, null: false, default: {}
  end
end
