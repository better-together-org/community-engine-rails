# frozen_string_literal: true

# Adds a per-item federation_visibility override to posts.
class AddFederationVisibilityToBetterTogetherPosts < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_posts)
    return if column_exists?(:better_together_posts, :federation_visibility)

    change_table :better_together_posts, &:bt_federation_visibility
  end

  def down
    return unless table_exists?(:better_together_posts)
    return unless column_exists?(:better_together_posts, :federation_visibility)

    remove_column :better_together_posts, :federation_visibility
  end
end
