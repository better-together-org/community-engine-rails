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

    def update?
      user.present? && record.creator == agent
    end

    def show?
      user.present? && record.participants.include?(agent)
    end

    def leave_conversation?
      user.present? && record.participants.size > 1
    end

    class Scope < ApplicationPolicy::Scope
    end
  end
end
