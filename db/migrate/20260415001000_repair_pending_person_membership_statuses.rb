# frozen_string_literal: true

class RepairPendingPersonMembershipStatuses < ActiveRecord::Migration[7.2]
  def up
    backfill_platform_memberships
    backfill_non_request_community_memberships
    backfill_accepted_invitation_memberships
    backfill_fulfilled_membership_request_memberships
  end

  def down; end

  private

  # Only repair memberships on platforms that don't actually gate joining on an
  # invitation/request — mirroring backfill_non_request_community_memberships
  # below. A platform with allow_membership_requests=false (and no invitation
  # requirement) can't have a genuinely-pending request; any 'pending' row
  # there is the same missing-status-default artifact this migration exists to
  # fix. Platforms that DO gate membership must keep their pending rows pending
  # — flipping those would bypass a real approval step.
  def backfill_platform_memberships
    execute <<~SQL.squish
      UPDATE better_together_person_platform_memberships memberships
      SET status = 'active'
      FROM better_together_platforms platforms
      WHERE platforms.id = memberships.joinable_id
        AND memberships.status = 'pending'
        AND COALESCE((platforms.settings->>'allow_membership_requests')::boolean, FALSE) = FALSE
        AND COALESCE((platforms.settings->>'requires_invitation')::boolean, TRUE) = FALSE
    SQL
  end

  def backfill_non_request_community_memberships
    execute <<~SQL.squish
      UPDATE better_together_person_community_memberships memberships
      SET status = 'active'
      FROM better_together_communities communities
      WHERE communities.id = memberships.joinable_id
        AND memberships.status = 'pending'
        AND communities.allow_membership_requests = FALSE
    SQL
  end

  def backfill_accepted_invitation_memberships
    execute <<~SQL.squish
      UPDATE better_together_person_community_memberships memberships
      SET status = 'active'
      FROM better_together_invitations invitations
      WHERE invitations.invitable_type = 'BetterTogether::Community'
        AND invitations.invitable_id = memberships.joinable_id
        AND invitations.invitee_id = memberships.member_id
        AND invitations.status = 'accepted'
        AND memberships.status = 'pending'
    SQL
  end

  def backfill_fulfilled_membership_request_memberships
    execute <<~SQL.squish
      UPDATE better_together_person_community_memberships memberships
      SET status = 'active'
      FROM better_together_joatu_requests requests
      WHERE requests.type = 'BetterTogether::Joatu::MembershipRequest'
        AND requests.target_type = 'BetterTogether::Community'
        AND requests.target_id = memberships.joinable_id
        AND requests.creator_id = memberships.member_id
        AND requests.status = 'fulfilled'
        AND memberships.status = 'pending'
    SQL
  end
end
