# frozen_string_literal: true

# Adds the initial community-level membership request flag used by CE host apps.
class AddAllowMembershipRequestsToBetterTogetherCommunities < ActiveRecord::Migration[7.2]
  def change
    add_column :better_together_communities, :allow_membership_requests, :boolean, default: false, null: false
  end
end
