# frozen_string_literal: true

# Migration to add locale column to better_together_sitemaps table for multi-locale support
class AddLocaleToBetterTogetherSitemaps < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_sitemaps, :locale, :string, null: false, default: 'en'
    add_index :better_together_sitemaps, %i[platform_id locale], unique: true, name: 'index_sitemaps_on_platform_and_locale'

    # Remove old uniqueness index on platform_id only
    remove_index :better_together_sitemaps, :platform_id, if_exists: true
  end
end
