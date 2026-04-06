# frozen_string_literal: true

class AddAllowMembershipRequestsToBetterTogetherCommunities < ActiveRecord::Migration[7.1]
  def change
    add_column :better_together_communities, :allow_membership_requests, :boolean, default: false, null: false
  end
end
