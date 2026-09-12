# frozen_string_literal: true

module BetterTogether
  # Authorization for MessageRequest — only participants (sender/recipient) may access.
  class MessageRequestPolicy < ApplicationPolicy
    def index?
      user.present? && agent.present?
    end

    def create?
      user.present? && agent.present?
    end

    def show?
      participant?
    end

    def accept?
      user.present? && agent == record.recipient
    end

    def decline?
      accept?
    end

    class Scope < ApplicationPolicy::Scope # rubocop:todo Style/Documentation
      def resolve
        return scope.none unless user.present? && agent.present?

        scope.where(sender: agent).or(scope.where(recipient: agent))
      end
    end

    private

    def participant?
      user.present? && agent.present? &&
        (agent == record.sender || agent == record.recipient)
    end
  end
end
