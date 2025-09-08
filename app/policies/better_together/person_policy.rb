# frozen_string_literal: true

module BetterTogether
  class PersonPolicy < ApplicationPolicy # rubocop:todo Style/Documentation
    def index?
      user.present? && permitted_to?('list_person')
    end

    def show?
      user.present? && (me? || permitted_to?('read_person'))
    end

    def create?
      user.present? && permitted_to?('create_person')
    end

    def new?
      create?
    end

    def update?
      user.present? && (me? || permitted_to?('update_person'))
    end

    def edit?
      update?
    end

    def destroy?
      user.present? && permitted_to?('delete_person')
    end

    def me?
      record === user.person # rubocop:todo Style/CaseEquality
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve # rubocop:todo Metrics/AbcSize, Metrics/MethodLength
        base_scope = scope.with_translations

        # Platform managers can see all people
        return base_scope if permitted_to?('manage_platform')

        # Unauthenticated users can only see public profiles
        return base_scope.privacy_public unless agent

        # Authenticated users can see:
        # 1. Their own profile
        # 2. Public profiles
        # 3. People in their shared communities (if those people have privacy_community or higher)
        # 4. People they have direct interactions with (blocked, conversations, etc.)

        people_table = scope.arel_table

        # Start with public profiles
        query = people_table[:privacy].eq('public')

        # Add own profile
        query = query.or(people_table[:id].eq(agent.id))

        # Add people in shared communities with community+ privacy
        if shared_community_member_ids.any?
          community_privacy_query = people_table[:privacy].in(%w[community public])
                                                          .and(people_table[:id].in(shared_community_member_ids))
          query = query.or(community_privacy_query)
        end

        # Add people with direct interactions (blocked users, conversation participants, etc.)
        query = query.or(people_table[:id].in(interaction_person_ids)) if interaction_person_ids.any?

        # Get IDs of people the current user has blocked or been blocked by
        blocked_ids = agent.person_blocks.pluck(:blocked_id)
        blocker_ids = BetterTogether::PersonBlock.where(blocked_id: agent.id).pluck(:blocker_id)
        excluded_ids = blocked_ids + blocker_ids

        query = query.and(people_table[:id].not_in(excluded_ids)) if excluded_ids.any?

        base_scope.where(query).distinct
      end

      private

      def shared_community_member_ids # rubocop:todo Metrics/MethodLength
        return @shared_community_member_ids if defined?(@shared_community_member_ids)

        @shared_community_member_ids = if agent.present?
                                         # Get people who are members of communities that the current person is also a member of # rubocop:disable Layout/LineLength
                                         agent_community_ids = agent.person_community_memberships.pluck(:joinable_id)
                                         if agent_community_ids.any?
                                           BetterTogether::PersonCommunityMembership
                                             .where(joinable_id: agent_community_ids)
                                             .where.not(member_id: agent.id)
                                             .pluck(:member_id)
                                             .uniq
                                         else
                                           []
                                         end
                                       else
                                         []
                                       end
      end

      def interaction_person_ids # rubocop:todo Metrics/MethodLength
        return @interaction_person_ids if defined?(@interaction_person_ids)

        @interaction_person_ids = if agent.present?
                                    ids = []

                                    # People in conversations with the current user, excluding blocked people
                                    if defined?(BetterTogether::Conversation) && defined?(BetterTogether::ConversationParticipant)
                                      conversation_ids = BetterTogether::ConversationParticipant
                                                         .where(person_id: agent.id)
                                                         .pluck(:conversation_id)
                                      if conversation_ids.any?
                                        participant_ids = BetterTogether::ConversationParticipant
                                                          .where(conversation_id: conversation_ids)
                                                          .where.not(person_id: agent.id)
                                                          .pluck(:person_id)
                                        ids.concat(participant_ids)
                                      end
                                    end

                                    ids.uniq
                                  else
                                    []
                                  end
      end
    end
  end
end
