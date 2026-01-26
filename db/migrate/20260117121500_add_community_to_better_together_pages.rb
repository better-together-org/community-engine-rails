# frozen_string_literal: true

# Adds community references to pages.
class AddCommunityToBetterTogetherPages < ActiveRecord::Migration[7.2]
  def up
    change_table :better_together_pages do |t|
      t.bt_community null: true
    end

    backfill_pages_with_host_community
  end

  def down
    remove_reference :better_together_pages, :community,
                     foreign_key: { to_table: :better_together_communities }
  end

  private

  def backfill_pages_with_host_community
    host_community = BetterTogether::Community.find_by(host: true) || host_from_platform

    return unless host_community

    BetterTogether::Page.where(community_id: nil).update_all(community_id: host_community.id)
  end

  def host_from_platform
    platform_community_id = BetterTogether::Platform.where(host: true).limit(1).pluck(:community_id).first
    return unless platform_community_id

    BetterTogether::Community.find_by(id: platform_community_id)
  end
end
