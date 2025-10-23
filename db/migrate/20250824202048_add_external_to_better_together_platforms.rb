class AddExternalToBetterTogetherPlatforms < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_platforms, :external, :boolean, default: false, null: false
    add_index :better_together_platforms, :external
  end
end
