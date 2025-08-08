# frozen_string_literal: true

module BetterTogether
  # Access control for conversations
  class ConversationPolicy < ApplicationPolicy
    def index?
      user.present?
    end

    def create?
      user.present?
    end

    def show?
      user.present? && record.participants.include?(agent)
    end

  class Scope < ApplicationPolicy::Scope
  end

  # Returns the people that the agent is permitted to message
  def permitted_participants
    if permitted_to?('manage_platform')
      BetterTogether::Person.all
    else
      role = BetterTogether::Role.find_by(identifier: 'platform_manager')
      manager_ids = BetterTogether::PersonPlatformMembership.where(role_id: role.id).pluck(:member_id)
      BetterTogether::Person.where(id: manager_ids)
                          .or(BetterTogether::Person.where("preferences @> ?", { receive_messages_from_members: true }.to_json))
                          .distinct
    end
  end
  end
end
