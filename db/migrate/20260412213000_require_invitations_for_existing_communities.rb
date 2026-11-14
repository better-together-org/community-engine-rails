# frozen_string_literal: true

# This migration originally forced requires_invitation=TRUE and
# allow_membership_requests=FALSE onto every existing community regardless
# of any value an admin had already explicitly configured — a real incident
# on communityengine.app: the host community had allow_membership_requests
# silently reset to false by this migration and required a manual admin fix
# afterward. Adding the requires_invitation column already seeds every row
# with its TRUE default via add_column; nothing further should force an
# existing explicit value (true or false) on either column.
class RequireInvitationsForExistingCommunities < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_communities)

    return if column_exists?(:better_together_communities, :requires_invitation)

    add_column :better_together_communities, :requires_invitation, :boolean, default: true, null: false
  end

  def down
    return unless table_exists?(:better_together_communities)
    return unless column_exists?(:better_together_communities, :requires_invitation)

    remove_column :better_together_communities, :requires_invitation
  end
end
