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

  def backfill_platform_memberships
    execute <<~SQL.squish
      UPDATE better_together_person_platform_memberships
      SET status = 'active'
      WHERE status = 'pending'
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
