# frozen_string_literal: true

# Phase 4 — Invitation isolation.
#
# The Invitation STI base has no direct platform_id — only PlatformInvitation
# and CommunityInvitation exist as subtypes, both scoped via invitable_id.
# Adding platform_id to the base table enables direct platform scoping for
# admin queries without joining through invitable.
#
# Backfill logic:
#   - PlatformInvitation (invitable_type = 'BetterTogether::Platform'):
#       platform_id = invitable_id
#   - CommunityInvitation (invitable_type = 'BetterTogether::Community'):
#       platform_id = platforms.community_id match
#   - Other / unresolvable:
#       platform_id = host platform
class AddPlatformIdToInvitations < ActiveRecord::Migration[7.2]
  def up
    add_reference :better_together_invitations, :platform,
                  type: :uuid,
                  null: true,
                  foreign_key: { to_table: :better_together_platforms },
                  index: true

    host_platform_id = execute(
      "SELECT id FROM better_together_platforms WHERE host = TRUE LIMIT 1"
    ).first&.fetch('id')

    return unless host_platform_id

    # Platform invitations — invitable_id IS the platform_id
    execute <<~SQL
      UPDATE better_together_invitations
      SET    platform_id = invitable_id
      WHERE  invitable_type = 'BetterTogether::Platform'
        AND  platform_id IS NULL
    SQL

    # Community invitations — resolve via community → platform
    execute <<~SQL
      UPDATE better_together_invitations i
      SET    platform_id = p.id
      FROM   better_together_platforms p
      WHERE  i.invitable_type = 'BetterTogether::Community'
        AND  i.invitable_id   = p.community_id
        AND  i.platform_id IS NULL
    SQL

    # Anything else — assign to host platform
    execute <<~SQL
      UPDATE better_together_invitations
      SET    platform_id = '#{host_platform_id}'
      WHERE  platform_id IS NULL
    SQL
  end

  def down
    remove_reference :better_together_invitations, :platform, index: true, foreign_key: true
  end
end
