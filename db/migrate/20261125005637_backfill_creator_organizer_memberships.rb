# frozen_string_literal: true

# Gives every community creator who holds no active membership an explicit Organizer membership, so the
# implicit creator access removed from the policies cannot lock anyone out on deploy. Idempotent, silent.
# Fails closed: if any community cannot be granted (no Organizer role on its platform), the migration
# aborts rather than shipping policies that would deny its creator.
class BackfillCreatorOrganizerMemberships < ActiveRecord::Migration[7.2]
  def up
    return unless tables_ready?

    BetterTogether::PersonCommunityMembership.reset_column_information
    entries = BetterTogether::Communities::CreatorMembershipBackfill.call(apply: true)
    unresolved = entries.reject { |entry| entry.status == 'granted' }
    return if unresolved.empty?

    raise "Creator membership backfill could not grant #{unresolved.size} communit(ies) " \
          "(#{unresolved.map(&:community_id).first(10).join(', ')}): #{unresolved.map(&:status).uniq.join(', ')}"
  end

  def down
    # Irreversible by design: the memberships are indistinguishable from ones granted by hand.
  end

  private

  def tables_ready?
    %i[better_together_communities better_together_person_community_memberships better_together_roles]
      .all? { |table| table_exists?(table) } && column_exists?(:better_together_communities, :creator_id)
  end
end
