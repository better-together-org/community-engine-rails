# frozen_string_literal: true

# Adds external flag to platforms table to distinguish between
# internal Better Together platforms and external OAuth providers.
class AddExternalToBetterTogetherPlatforms < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_platforms, :external, :boolean, default: false, null: false
    add_index :better_together_platforms, :external
  end
end
