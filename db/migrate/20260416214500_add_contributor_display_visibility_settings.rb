# frozen_string_literal: true

class AddContributorDisplayVisibilitySettings < ActiveRecord::Migration[7.2]
  def up
    add_community_settings_column
    add_post_display_settings_column
  end

  def down
    remove_column :better_together_posts, :display_settings if column_exists?(:better_together_posts, :display_settings)
    remove_column :better_together_communities, :settings if column_exists?(:better_together_communities, :settings)
  end

  private

  def add_community_settings_column
    return if column_exists?(:better_together_communities, :settings)

    add_column :better_together_communities, :settings, :jsonb, default: {}, null: false
  end

  def add_post_display_settings_column
    return if column_exists?(:better_together_posts, :display_settings)

    add_column :better_together_posts, :display_settings, :jsonb, default: {}, null: false
  end
end
