# frozen_string_literal: true

module BetterTogether
  # Access control for conversations
  class ConversationPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present?
    end

    # Determines whether the current user can create a conversation.
    # When `participants:` are provided, ensures they are within the permitted set.
    def create?(participants: nil)
      return false unless user.present? && agent.present?

      return true if participants.nil?

      permitted = permitted_participants
      # Allow arrays of ids or Person records
      Array(participants).all? do |p|
        person_id = p.is_a?(::BetterTogether::Person) ? p.id : p
        permitted.exists?(id: person_id)
      end
    end

    def update?
      user.present? && agent.present? && record.creator == agent
    end

    def show?
      user.present? && agent.present? && record.participants.include?(agent)
    end

    def leave_conversation?
      user.present? && agent.present? && record.participants.size > 1
    end

    # Determines whether the current user can send a message in the conversation.
    # Requires authentication and conversation participation.
    def send_message?
      show? # Delegates to participant check
    end

    # Returns the people that the agent is permitted to message
    def permitted_participants
      return platform_people if admin_participant_access?

      admin_and_opted_in_participants
    end

    def new?
      user.present? && agent.present?
    end

    # Authorization scope for conversations
    class Scope < ApplicationPolicy::Scope
      def resolve
        scope.includes(participants: [
                         :string_translations,
                         :contact_detail,
                         { profile_image_attachment: :blob }
                       ])
      end
    end

    private

    def admin_participant_access?
      permitted_to?('list_person') ||
        permitted_to?('manage_platform_members') ||
        permitted_to?('manage_platform')
    end

    def platform_steward_ids
      BetterTogether::PersonPlatformMembership
        .active
        .where(joinable: platform)
        .joins(role: { role_resource_permissions: :resource_permission })
        .where(better_together_resource_permissions: {
                 identifier: %w[manage_platform_members manage_platform_settings manage_platform]
               })
        .distinct
        .pluck(:member_id)
    end

    def opted_in_participants
      platform_people.where(
        'preferences @> ?', { receive_messages_from_members: true }.to_json
      )
    end

    def admin_and_opted_in_participants
      platform_people
        .where(id: platform_steward_ids)
        .or(opted_in_participants)
        .distinct
    end

    def platform
      Current.platform || BetterTogether::Platform.find_by(host: true)
    end

    def platform_people
      BetterTogether::Person
        .includes(:string_translations)
        .where(id: current_platform_person_ids)
        .distinct
    end

    def current_platform_person_ids
      ids = BetterTogether::PersonPlatformMembership
            .active
            .where(joinable: platform)
            .pluck(:member_id)

      return ids unless platform&.host? && platform.community.present?

      host_community_ids = BetterTogether::PersonCommunityMembership
                           .where(joinable: platform.community)
                           .pluck(:member_id)

      ids | host_community_ids
    end
  end
end
