# frozen_string_literal: true

class RequireInvitationsForExistingCommunities < ActiveRecord::Migration[7.2]
  def up
    return unless table_exists?(:better_together_communities)

    unless column_exists?(:better_together_communities, :requires_invitation)
      add_column :better_together_communities, :requires_invitation, :boolean, default: true, null: false
    end

    if column_exists?(:better_together_communities, :requires_invitation)
      execute <<~SQL.squish
        UPDATE better_together_communities
        SET requires_invitation = TRUE
        WHERE requires_invitation IS DISTINCT FROM TRUE
      SQL
    end

    return unless column_exists?(:better_together_communities, :allow_membership_requests)

    execute <<~SQL.squish
      UPDATE better_together_communities
      SET allow_membership_requests = FALSE
      WHERE allow_membership_requests IS DISTINCT FROM FALSE
    SQL
  end

  def down
    return unless table_exists?(:better_together_communities)
    return unless column_exists?(:better_together_communities, :requires_invitation)

    remove_column :better_together_communities, :requires_invitation
  end
end
