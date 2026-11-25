# frozen_string_literal: true

module BetterTogether
  module Communities
    # Gives each community creator who holds no active membership an explicit Organizer membership, so the
    # implicit creator access can later be removed without locking anyone out. Dry run unless apply: true.
    class CreatorMembershipBackfill
      Entry = Struct.new(:community_id, :community_name, :creator_id, :creator_name, :platform_manager, :status,
                         keyword_init: true)

      def self.call(apply: false)
        new(apply:).call
      end

      def initialize(apply: false)
        @apply = apply
      end

      def call
        candidates.map { |community| process(community) }
      end

      private

      def candidates
        Community.where.not(creator_id: nil).where.not(creator_membership_exists.arel.exists)
                 .includes(:creator).order(:created_at)
      end

      def creator_membership_exists
        communities = Community.arel_table
        memberships = PersonCommunityMembership.arel_table
        PersonCommunityMembership.active.where(memberships[:member_id].eq(communities[:creator_id]))
                                 .where(memberships[:joinable_id].eq(communities[:id]))
      end

      def process(community)
        creator = community.creator
        role = Role.find_default('community_organizer', platform: community.platform)
        status = role ? 'would_grant' : 'skipped_no_organizer_role'
        status = grant(community, creator, role) if @apply && role
        Entry.new(community_id: community.id, community_name: community.name, creator_id: creator&.id,
                  creator_name: creator&.name, platform_manager: platform_manager?(creator, community), status:)
      end

      def grant(community, creator, role)
        membership = community.person_community_memberships.find_or_initialize_by(member: creator, role:)
        membership.status = 'active'
        membership.skip_notifications = true
        membership.save!
        'granted'
      end

      def platform_manager?(creator, community)
        creator&.permitted_to?('manage_platform', community.platform) || false
      end
    end
  end
end
