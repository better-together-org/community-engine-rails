# frozen_string_literal: true

# Adds community references to posts.
class AddCommunityToBetterTogetherPosts < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_posts)
    return if column_exists?(:better_together_posts, :community_id)

    change_table :better_together_posts do |t|
      t.bt_community null: true
    end

    backfill_posts_with_host_community
  end

  def down
    return unless table_exists?(:better_together_posts)
    return unless column_exists?(:better_together_posts, :community_id)

    remove_reference :better_together_posts, :community,
                     foreign_key: { to_table: :better_together_communities }
  end

  private

  def backfill_posts_with_host_community
    community_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'better_together_communities'
      self.inheritance_column = :_type_disabled
    end
    platform_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'better_together_platforms'
      self.inheritance_column = :_type_disabled
    end
    post_class = Class.new(ActiveRecord::Base) do
      self.table_name = 'better_together_posts'
      self.inheritance_column = :_type_disabled
    end

    host_community = community_class.find_by(host: true) ||
                     host_from_platform(community_class, platform_class)
    return unless host_community

    post_class.where(community_id: nil).update_all(community_id: host_community.id)
  end

  def host_from_platform(community_class, platform_class)
    platform_community_id = platform_class.where(host: true).limit(1).pluck(:community_id).first
    return unless platform_community_id

    community_class.find_by(id: platform_community_id)
  end
end
