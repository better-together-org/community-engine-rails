# frozen_string_literal: true

module BetterTogether
  # Access control for conversations
  class ConversationPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    # Determines whether the current user can create a conversation.
    # When `participants:` are provided, ensures they are within the permitted set.
    def create?(participants: nil)
      return false unless user.present?

      return true if participants.nil?

      permitted = permitted_participants
      # Allow arrays of ids or Person records
      Array(participants).all? do |p|
        person_id = p.is_a?(::BetterTogether::Person) ? p.id : p
        permitted.exists?(id: person_id)
      end
    end

    def update?
      user.present? && record.creator == agent
    end

    def show?
      user.present? && record.participants.include?(agent)
    end

    def leave_conversation?
      user.present? && record.participants.size > 1
    end

    # Returns the people that the agent is permitted to message
    def permitted_participants
      if permitted_to?('manage_platform')
        BetterTogether::Person.includes(:string_translations).all
      else
        role = BetterTogether::Role.find_by(identifier: 'platform_manager')
        manager_ids = BetterTogether::PersonPlatformMembership.where(role_id: role.id).pluck(:member_id)
        # Include platform managers and any person who has explicitly opted in to receive messages
        opted_in = BetterTogether::Person.where(
          'preferences @> ?', { receive_messages_from_members: true }.to_json
        )

        BetterTogether::Person.includes(:string_translations).where(id: manager_ids).or(opted_in).distinct
      end
    end

    class Scope < ApplicationPolicy::Scope
    end
  end
end
